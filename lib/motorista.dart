import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trans_saude/models/motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/localizacao_motorista_service.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

import 'components/card_paciente.dart';
import 'components/dialogo_confirmacao_motorista.dart';
import 'components/footer_pacientes.dart';
import 'components/formulario_inicio_viagem.dart';
import 'components/motorista_header.dart';

/// Camada de Apresentação: tela operacional do motorista.
/// Exibe o formulário de escolha de veículo quando `emViagem == false` e,
/// quando `emViagem == true`, lista os passageiros da viagem ativa em foco.
class Motorista extends StatefulWidget {
  final ViagemModel? viagemInicial;
  final ViagemService? viagemServiceOverride;
  final Stream<List<PacienteModel>>? pacientesStreamOverride;
  final PacienteSyncService? syncServiceOverride;

  const Motorista({
    super.key,
    this.viagemInicial,
    this.viagemServiceOverride,
    this.pacientesStreamOverride,
    this.syncServiceOverride,
  });

  @override
  State<Motorista> createState() => _MotoristaState();
}

class _MotoristaState extends State<Motorista> {
  late final ViagemService _viagemService;
  late final PacienteSyncService _syncService;

  StreamSubscription<ViagemModel?>? _subViagemAtiva;
  StreamSubscription<List<ViagemModel>>? _subViagensAtivas;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subMotorista;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subVeiculosFirestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subViagensFirestore;
  StreamSubscription<({String? viagemId, PacienteModel paciente})>?
      _subSyncPacientes;
  StreamSubscription<
          ({
            String? viagemId,
            String pacienteId,
            String mensagem,
            PacienteModel estadoRevertido,
          })>?
      _subFalhasSync;
  StreamSubscription<String>? _subErrosViagem;

  List<VeiculoModel> _veiculosFrota = [];
  List<ViagemModel> _viagensAtivas = [];
  ViagemModel? _viagemAtiva;
  int _indiceViagemAtual = 0;

  int _capacidadeMotoristaDoc = 0;
  int _capacidadeVeiculo = 0;
  String _placaMotoristaDoc = '';

  String? _motoristaId;
  String _motoristaNome = '';
  bool? _emViagemFirestore;

  final Set<String> _pacientesGerandoCodigo = {};
  Timer? _timeoutCarregamentoViagem;
  DateTime? _inicioViagemOptimistaEm;
  bool _argumentosRotaProcessados = false;

  // ===========================================================================
  // SEÇÃO: Ciclo de Vida e Listeners Reativos
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _viagemService = widget.viagemServiceOverride ?? ViagemService();
    _syncService = widget.syncServiceOverride ?? PacienteSyncService();

    final idMotSessao = _obterIdMotoristaSessao();
    final sessaoMem = _viagemService.sessaoAtiva;
    final sessaoDeOutroMotorista = sessaoMem != null &&
        sessaoMem.motoristaId.trim().isNotEmpty &&
        idMotSessao.trim().isNotEmpty &&
        sessaoMem.motoristaId.trim() != idMotSessao.trim();
    if (sessaoDeOutroMotorista) {
      _viagemService.limparSessaoLocal();
    } else if (_isFirebaseDisponivel() &&
        widget.viagemInicial == null &&
        FirebaseAuthService.motoristaEmViagemStatic == false &&
        _viagemService.viagemAtiva != null) {
      _viagemService.limparSessaoLocal();
    }

    _viagemAtiva = widget.viagemInicial;
    _viagensAtivas = _viagemService.viagensAtivas;
    if (_viagensAtivas.isNotEmpty && _viagemAtiva == null) {
      _viagemAtiva = _viagensAtivas.first;
    }
    _viagemAtiva ??= _viagemService.viagemAtiva;

    if (widget.viagemInicial != null || widget.pacientesStreamOverride != null) {
      _emViagemFirestore = true;
    } else if (_viagemAtiva != null &&
        (!_isFirebaseDisponivel() ||
            FirebaseAuthService.motoristaEmViagemStatic != false)) {
      _emViagemFirestore = true;
    } else {
      _emViagemFirestore = FirebaseAuthService.motoristaEmViagemStatic;
    }
    _veiculosFrota = List<VeiculoModel>.from(_viagemService.todosVeiculos);

    if (_viagemAtiva == null && _emViagemFirestore == true) {
      final idMotInicial = _obterIdMotoristaSessao();
      if (idMotInicial.isNotEmpty) {
        _viagemService.restaurarSessaoMotoristaSeAtiva(
          motoristaId: idMotInicial,
          motoristaNome: _motoristaNome,
          frota: _veiculosFrota,
        );
        if (_viagemService.viagemAtiva != null) {
          _viagemAtiva = _viagemService.viagemAtiva;
          _viagensAtivas = _viagemService.viagensAtivas;
          _emViagemFirestore = true;
        }
      }
    }

    if (_emViagemFirestore == true && !_temViagemAtiva) {
      _iniciarTimeoutCarregamentoViagem();
    }
    _capacidadeVeiculo = _resolverCapacidadeVeiculo();
    _atualizarTransmissaoGpsMotorista();

    _registrarListenersServico();
    if (_isFirebaseDisponivel()) {
      _viagemService.garantirEscutaFirestore();
      LocalizacaoMotoristaService().garantirEscutasFirestore();
      _ouvirDadosMotorista();
      _ouvirVeiculosEViagensFirestore();
    }
  }

  void _registrarListenersServico() {
    _subViagemAtiva = _viagemService.viagemAtivaStream.listen((viagem) {
      if (!mounted) return;
      if (viagem != null && viagem.isEmOperacao) {
        _cancelarTimeoutCarregamentoViagem();
      }
      setState(() {
        if (viagem == null) {
          _viagemAtiva = null;
        } else if (_viagensAtivas.length <= 1 ||
            _viagemAtiva == null ||
            _viagemAtiva!.id == viagem.id ||
            !_viagensAtivas.any((v) => v.id == _viagemAtiva!.id)) {
          // Mantém o índice selecionado quando o motorista navega entre viagens.
          _viagemAtiva = viagem;
        } else {
          _viagensAtivas = _viagensAtivas
              .map((v) => v.id == viagem.id ? viagem : v)
              .toList();
        }
        _capacidadeVeiculo = _resolverCapacidadeVeiculo();
      });
      _atualizarTransmissaoGpsMotorista();
    });

    _subViagensAtivas = _viagemService.viagensAtivasStream.listen((viagens) {
      if (!mounted) return;
      final ativas = viagens
          .where(
            (v) =>
                v.id.startsWith('sessao_ativa_') ||
                (!v.isCancelada &&
                    !v.isConcluida &&
                    !_viagemService.todosPacientesVoltaram(v)),
          )
          .toList();
      if (ativas.any((v) => v.isEmOperacao)) {
        _cancelarTimeoutCarregamentoViagem();
      }
      setState(() {
        _selecionarViagemPreservandoId(ativas);
        _capacidadeVeiculo = _resolverCapacidadeVeiculo();
      });
      _atualizarTransmissaoGpsMotorista();
    });

    _subSyncPacientes = _syncService.alteracoesPorViagemStream.listen((evento) {
      final idViagemEvento = evento.viagemId?.trim();
      if (idViagemEvento != null &&
          idViagemEvento.isNotEmpty &&
          _viagemAtiva != null &&
          _viagemAtiva!.id != idViagemEvento) {
        return;
      }
      if (mounted) setState(() {});
    });

    _subFalhasSync = _syncService.falhasPorViagemStream.listen((falha) {
      final idViagemAlvo = falha.viagemId ?? _viagemAtiva?.id;
      if (idViagemAlvo != null && !idViagemAlvo.startsWith('sessao_ativa_')) {
        _viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: idViagemAlvo,
          pacienteId: falha.pacienteId,
          novoStatus: falha.estadoRevertido.status,
          prontoRetorno: falha.estadoRevertido.prontoRetorno,
          janelaReversao: falha.estadoRevertido.janelaReversao,
          limparJanelaReversao: falha.estadoRevertido.janelaReversao == null,
          persistirRemoto: false,
        );
      }
      unawaited(HapticFeedback.heavyImpact());
      unawaited(SystemSound.play(SystemSoundType.alert));
      if (!mounted) return;
      setState(() {
        _selecionarViagemPreservandoId(_viagemService.viagensAtivas);
      });
      _exibirSnackBar(falha.mensagem, const Color(0xFFB83227));
    });

    _subErrosViagem =
        _viagemService.errosSincronizacaoStream.listen((mensagemErro) {
      unawaited(HapticFeedback.heavyImpact());
      unawaited(SystemSound.play(SystemSoundType.alert));
      if (!mounted) return;
      setState(() {
        _selecionarViagemPreservandoId(_viagemService.viagensAtivas);
        _capacidadeVeiculo = _resolverCapacidadeVeiculo();
      });
      final ativa = _viagemAtiva;
      if (ativa != null && !ativa.id.startsWith('sessao_ativa_')) {
        for (final pv in ativa.passageiros) {
          _syncService.sincronizarPassageiroDeViagemEmMemoria(
            ativa.id,
            _viagemService.construirPacienteDaViagem(pv),
          );
        }
      }
      _exibirSnackBar(mensagemErro, const Color(0xFFB83227));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosRotaProcessados) return;
    _argumentosRotaProcessados = true;

    if (_viagemAtiva == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is ViagemModel && !args.isConcluida && !args.isCancelada) {
        _cancelarTimeoutCarregamentoViagem();
        _viagemAtiva = args;
        _emViagemFirestore = true;
        FirebaseAuthService.motoristaEmViagemStatic = true;
        if (_viagensAtivas.isEmpty) {
          _viagensAtivas = [args];
        }
        _capacidadeVeiculo = _resolverCapacidadeVeiculo();
      }
    }
  }

  @override
  void dispose() {
    _cancelarTimeoutCarregamentoViagem();
    LocalizacaoMotoristaService().pararTransmissaoGpsMotorista();
    _subViagemAtiva?.cancel();
    _subViagensAtivas?.cancel();
    _subMotorista?.cancel();
    _subVeiculosFirestore?.cancel();
    _subViagensFirestore?.cancel();
    _subSyncPacientes?.cancel();
    _subFalhasSync?.cancel();
    _subErrosViagem?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // SEÇÃO: Controle de Sessão do Veículo, GPS e Listeners Firestore
  // ===========================================================================

  String _obterIdMotoristaSessao() =>
      _motoristaId ??
      FirebaseAuthService().currentDocId ??
      FirebaseAuthService().currentUserId ??
      '';

  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool get _temViagemAtiva {
    if (widget.pacientesStreamOverride != null) return true;
    if (_viagemAtiva != null && _viagemAtiva!.isEmOperacao) return true;
    if (_viagensAtivas.isNotEmpty &&
        _viagensAtivas.any((v) => v.isEmOperacao)) {
      return true;
    }
    if (_viagemService.viagemAtiva != null &&
        _viagemService.viagemAtiva!.isEmOperacao) {
      return true;
    }
    return false;
  }

  void _selecionarViagemPreservandoId(
    List<ViagemModel> ativas, {
    String? idPreferido,
  }) {
    _viagensAtivas = ativas;
    if (ativas.isEmpty) {
      _indiceViagemAtual = 0;
      _viagemAtiva = _viagemService.viagemAtiva;
      return;
    }
    final alvoId = idPreferido ?? _viagemAtiva?.id;
    if (alvoId != null && alvoId.isNotEmpty) {
      final idx = ativas.indexWhere((v) => v.id == alvoId);
      if (idx != -1) {
        _indiceViagemAtual = idx;
        _viagemAtiva = ativas[idx];
        return;
      }
    }
    if (_indiceViagemAtual >= ativas.length || _indiceViagemAtual < 0) {
      _indiceViagemAtual = ativas.length - 1;
    }
    _viagemAtiva = ativas[_indiceViagemAtual];
  }

  void _resetarEstadoParaNovaViagem(String idMot) {
    _inicioViagemOptimistaEm = null;
    final idsVeiculosParaLiberar = _veiculosFrota
        .where((veic) => veic.motoristaAtualId == idMot && veic.emUso)
        .map((veic) => veic.id)
        .toList();
    setState(() {
      _emViagemFirestore = false;
      FirebaseAuthService.motoristaEmViagemStatic = false;
      _viagemAtiva = null;
      _viagensAtivas = [];
      _indiceViagemAtual = 0;
      for (int i = 0; i < _veiculosFrota.length; i++) {
        final veic = _veiculosFrota[i];
        if (veic.motoristaAtualId == idMot && veic.emUso) {
          _veiculosFrota[i] = veic.copyWith(
            emUso: false,
            limparMotorista: true,
          );
        }
      }
    });
    if (idMot.isNotEmpty && _isFirebaseDisponivel()) {
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(idMot)
          .update({'emViagem': false}).catchError((_) {});
      for (final vid in idsVeiculosParaLiberar) {
        FirebaseFirestore.instance
            .collection('veiculos')
            .doc(vid)
            .update({'emUso': false, 'motoristaAtualId': null})
            .catchError((_) {});
      }
    }
  }

  void _iniciarTimeoutCarregamentoViagem() {
    _timeoutCarregamentoViagem?.cancel();
    _timeoutCarregamentoViagem = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      if (!_temViagemAtiva && _emViagemFirestore == true) {
        _resetarEstadoParaNovaViagem(_obterIdMotoristaSessao());
      }
    });
  }

  void _cancelarTimeoutCarregamentoViagem() {
    _timeoutCarregamentoViagem?.cancel();
    _timeoutCarregamentoViagem = null;
  }

  void _aoEncerrarViagemMotorista() {
    if (!mounted) return;
    _cancelarTimeoutCarregamentoViagem();
    _inicioViagemOptimistaEm = null;
    setState(() {
      _emViagemFirestore = false;
      FirebaseAuthService.motoristaEmViagemStatic = false;
      _viagemAtiva = null;
      _viagensAtivas = [];
      _indiceViagemAtual = 0;
      _capacidadeVeiculo = _resolverCapacidadeVeiculo();
    });
    _atualizarTransmissaoGpsMotorista();
  }

  void _atualizarTransmissaoGpsMotorista() {
    final v = _viagemAtiva;
    final sessao = _viagemService.sessaoAtiva;
    final emTransito = (v != null && v.isEmOperacao) ||
        (sessao != null && sessao.status == 'ativa');
    if (emTransito) {
      String? authUid;
      try {
        authUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
      final docLogado = _motoristaId ??
          FirebaseAuthService().currentDocId ??
          FirebaseAuthService().currentUserId;
      final idMot = (authUid != null && authUid.trim().isNotEmpty)
          ? authUid.trim()
          : ((docLogado != null && docLogado.trim().isNotEmpty)
                ? docLogado.trim()
                : ((v != null &&
                          v.motoristaId.isNotEmpty &&
                          v.motoristaId != 'motorista_atual')
                      ? v.motoristaId
                      : 'motorista_atual'));
      final nomeMot = _motoristaNome.trim().isNotEmpty
          ? _motoristaNome.trim()
          : ((sessao != null && sessao.motoristaNome.trim().isNotEmpty)
                ? sessao.motoristaNome.trim()
                : ((v != null &&
                          v.motoristaNome.trim().isNotEmpty &&
                          v.motoristaNome != 'Motorista da Saúde')
                      ? v.motoristaNome.trim()
                      : 'Motorista Municipal'));
      final veiculoSessao = _resolverVeiculoSessaoAtual();
      final placaSessao = _resolverPlacaVeiculoSessao();
      final modeloSessao = (veiculoSessao != null &&
              veiculoSessao.modelo.trim().isNotEmpty)
          ? veiculoSessao.modelo.trim()
          : ((sessao != null && sessao.veiculoModelo.trim().isNotEmpty)
                ? sessao.veiculoModelo.trim()
                : (v?.veiculoModelo ?? ''));
      LocalizacaoMotoristaService().iniciarTransmissaoGpsMotorista(
        motoristaId: idMot,
        motoristaNome: nomeMot,
        veiculoPlaca: placaSessao,
        veiculoModelo: modeloSessao,
        cidadeDestino: v?.cidadeDestino ?? '',
        viagemId: v?.id ?? sessao?.id ?? '',
      );
    } else {
      LocalizacaoMotoristaService().pararTransmissaoGpsMotorista();
    }
  }

  void _ouvirVeiculosEViagensFirestore() {
    _subVeiculosFirestore?.cancel();
    _subVeiculosFirestore = FirebaseFirestore.instance
        .collection('veiculos')
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        final frota = snapshot.docs
            .map((d) => VeiculoModel.fromMap(d.data(), docId: d.id))
            .toList();
        final idMot = _obterIdMotoristaSessao();
        final precisaRestaurar = _viagemAtiva == null ||
            _viagemAtiva!.id.startsWith('sessao_ativa_');
        if (_emViagemFirestore == true && precisaRestaurar && idMot.isNotEmpty) {
          _viagemService.restaurarSessaoMotoristaSeAtiva(
            motoristaId: idMot,
            motoristaNome: _motoristaNome,
            frota: frota,
          );
        }
        setState(() {
          _veiculosFrota = frota;
          if (_emViagemFirestore == true &&
              (_viagemAtiva == null ||
                  _viagemAtiva!.id.startsWith('sessao_ativa_')) &&
              _viagemService.viagemAtiva != null) {
            _selecionarViagemPreservandoId(_viagemService.viagensAtivas);
            _cancelarTimeoutCarregamentoViagem();
          }
          _capacidadeVeiculo = _resolverCapacidadeVeiculo();
        });
      },
      onError: (_) {},
    );

    _subViagensFirestore?.cancel();
    _subViagensFirestore = FirebaseFirestore.instance
        .collection('viagens')
        .where('status', isNotEqualTo: 'encerrada')
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        final todas = snapshot.docs
            .map((d) => ViagemModel.fromMap(d.data(), docId: d.id))
            .toList();

        _viagemService.sincronizarViagensRemotas(todas);

        final idMot = _obterIdMotoristaSessao();
        final precisaRestaurar = _viagemAtiva == null ||
            _viagemAtiva!.id.startsWith('sessao_ativa_');
        if (_emViagemFirestore == true && precisaRestaurar && idMot.isNotEmpty) {
          _viagemService.restaurarSessaoMotoristaSeAtiva(
            motoristaId: idMot,
            motoristaNome: _motoristaNome,
            frota: _veiculosFrota,
          );
        }

        if (_emViagemFirestore == true &&
            (_viagemAtiva != null || _viagemService.viagemAtiva != null)) {
          _cancelarTimeoutCarregamentoViagem();
          setState(() {
            _selecionarViagemPreservandoId(_viagemService.viagensAtivas);
            _capacidadeVeiculo = _resolverCapacidadeVeiculo();
          });
          _atualizarTransmissaoGpsMotorista();
        }
      },
      onError: (_) {},
    );
  }

  void _ouvirDadosMotorista() {
    String? authUid;
    try {
      authUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    final docIdLogado = FirebaseAuthService().currentDocId;
    final idOperacional = FirebaseAuthService().currentUserId;
    final candidatos = <String>[
      if (docIdLogado != null && docIdLogado.trim().isNotEmpty)
        docIdLogado.trim(),
      if (authUid != null && authUid.trim().isNotEmpty) authUid.trim(),
      if (idOperacional != null && idOperacional.trim().isNotEmpty)
        idOperacional.trim(),
    ];
    if (candidatos.isEmpty) return;

    void escutarDocumento(String docIdAlvo, {String? fallbackUid}) {
      _subMotorista?.cancel();
      _subMotorista = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(docIdAlvo)
          .snapshots()
          .listen(
        (docSelecionado) {
          if (!mounted) return;
          if (!docSelecionado.exists || docSelecionado.data() == null) {
            if (fallbackUid != null &&
                fallbackUid.isNotEmpty &&
                fallbackUid != docIdAlvo) {
              escutarDocumento(fallbackUid);
            }
            return;
          }

          final motorista = MotoristaModel.fromMap(
            docSelecionado.data()!,
            docId: docSelecionado.id,
          );
          final idResolvido =
              motorista.id.isNotEmpty ? motorista.id : docSelecionado.id;

          final sessaoMem = _viagemService.sessaoAtiva;
          if (sessaoMem != null &&
              sessaoMem.motoristaId.trim().isNotEmpty &&
              sessaoMem.motoristaId.trim() != idResolvido) {
            _viagemService.limparSessaoLocal();
            _viagemAtiva = null;
            _viagensAtivas = [];
          }

          setState(() {
            _capacidadeMotoristaDoc = motorista.capacidadeVeiculo;
            _placaMotoristaDoc = motorista.veiculoPlaca;
            _motoristaId = idResolvido;
            if (motorista.nome.trim().isNotEmpty) {
              _motoristaNome = motorista.nome.trim();
            }

            final emJanelaOptimista = _inicioViagemOptimistaEm != null &&
                DateTime.now().difference(_inicioViagemOptimistaEm!) <
                    const Duration(seconds: 6);
            if (motorista.emViagem) {
              _inicioViagemOptimistaEm = null;
              _emViagemFirestore = true;
              FirebaseAuthService.motoristaEmViagemStatic = true;
              _viagemService.garantirEscutaFirestore();
            } else if (!emJanelaOptimista) {
              _inicioViagemOptimistaEm = null;
              _emViagemFirestore = false;
              FirebaseAuthService.motoristaEmViagemStatic = false;
              _cancelarTimeoutCarregamentoViagem();
              if (_viagemAtiva != null || _viagemService.sessaoAtiva != null) {
                _viagemService.limparSessaoLocal();
                _viagemAtiva = null;
                _viagensAtivas = [];
                _indiceViagemAtual = 0;
              }
            }

            if (_emViagemFirestore == true &&
                (_viagemAtiva == null ||
                    _viagemAtiva!.id.startsWith('sessao_ativa_')) &&
                _motoristaId != null &&
                _motoristaId!.isNotEmpty) {
              _viagemService.restaurarSessaoMotoristaSeAtiva(
                motoristaId: _motoristaId!,
                motoristaNome: _motoristaNome,
                frota: _veiculosFrota,
              );
              if (_viagemService.viagemAtiva != null) {
                _selecionarViagemPreservandoId(_viagemService.viagensAtivas);
                _cancelarTimeoutCarregamentoViagem();
              }
            }
            if (_emViagemFirestore == true && !_temViagemAtiva) {
              _iniciarTimeoutCarregamentoViagem();
            } else if (_emViagemFirestore == false) {
              _cancelarTimeoutCarregamentoViagem();
            }
            _capacidadeVeiculo = _resolverCapacidadeVeiculo();
          });
          _atualizarTransmissaoGpsMotorista();
        },
        onError: (_) {
          if (!mounted) return;
          if (fallbackUid != null &&
              fallbackUid.isNotEmpty &&
              fallbackUid != docIdAlvo) {
            escutarDocumento(fallbackUid);
          }
        },
      );
    }

    final fallback = (authUid != null &&
            authUid.trim().isNotEmpty &&
            authUid.trim() != candidatos.first)
        ? authUid.trim()
        : null;
    escutarDocumento(candidatos.first, fallbackUid: fallback);
  }
  // Fechamento do método _ouvirDadosMotorista

  // ===========================================================================
  // SEÇÃO: Resolução de Capacidade, Códigos e Passageiros da Viagem em Foco
  // ===========================================================================

  String _normalizarPlaca(String placa) =>
      placa.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  VeiculoModel? _resolverVeiculoSessaoAtual() {
    final listaVeiculos = _veiculosFrota.isNotEmpty
        ? _veiculosFrota
        : _viagemService.todosVeiculos;
    final sessao = _viagemService.sessaoAtiva;

    // 1. Prioriza o veículo da sessão ativa declarada pelo motorista logado.
    if (sessao != null) {
      final vidSessao = sessao.veiculoId.trim();
      final placaSessao = _normalizarPlaca(sessao.veiculoPlaca);
      for (final v in listaVeiculos) {
        if ((vidSessao.isNotEmpty && v.id == vidSessao) ||
            (placaSessao.isNotEmpty && _normalizarPlaca(v.placa) == placaSessao)) {
          return v;
        }
      }
    }

    // 2. Procura na frota o veículo atualmente ocupado por este motorista.
    final idsCondutor = <String>{
      if (_motoristaId != null && _motoristaId!.trim().isNotEmpty)
        _motoristaId!.trim(),
      if (FirebaseAuthService().currentDocId?.trim().isNotEmpty == true)
        FirebaseAuthService().currentDocId!.trim(),
      if (FirebaseAuthService().currentUserId?.trim().isNotEmpty == true)
        FirebaseAuthService().currentUserId!.trim(),
    };
    if (idsCondutor.isNotEmpty) {
      for (final v in listaVeiculos) {
        final motVeic = v.motoristaAtualId?.trim() ?? '';
        if (v.emUso && motVeic.isNotEmpty && idsCondutor.contains(motVeic)) {
          return v;
        }
      }
    }

    // 3. Fallback para viagem inicial/em foco quando não há sessão explícita.
    final viagemRef = widget.viagemInicial ?? _viagemAtiva;
    if (viagemRef != null) {
      final vid = viagemRef.veiculoId.trim();
      final vplaca = _normalizarPlaca(viagemRef.veiculoPlaca);
      for (final v in listaVeiculos) {
        if ((vid.isNotEmpty && v.id == vid) ||
            (vplaca.isNotEmpty && _normalizarPlaca(v.placa) == vplaca)) {
          return v;
        }
      }
    }

    // 4. Fallback pela placa habitual do cadastro do motorista.
    if (_placaMotoristaDoc.trim().isNotEmpty) {
      final placaDoc = _normalizarPlaca(_placaMotoristaDoc);
      for (final v in listaVeiculos) {
        if (_normalizarPlaca(v.placa) == placaDoc) {
          return v;
        }
      }
    }
    return null;
  }

  String _resolverPlacaVeiculoSessao() {
    final placaSessao = _viagemService.sessaoAtiva?.veiculoPlaca.trim() ?? '';
    if (placaSessao.isNotEmpty) return placaSessao;
    final veicAtual = _resolverVeiculoSessaoAtual();
    if (veicAtual != null && veicAtual.placa.trim().isNotEmpty) {
      return veicAtual.placa.trim();
    }
    if (widget.viagemInicial?.veiculoPlaca.trim().isNotEmpty == true) {
      return widget.viagemInicial!.veiculoPlaca.trim();
    }
    if (_placaMotoristaDoc.trim().isNotEmpty) {
      return _placaMotoristaDoc.trim();
    }
    return _viagemAtiva?.veiculoPlaca.trim() ?? '';
  }

  int _resolverCapacidadeVeiculo() {
    final veicAtual = _resolverVeiculoSessaoAtual();
    if (veicAtual != null && veicAtual.capacidade > 0) {
      return veicAtual.capacidade;
    }
    if (_capacidadeMotoristaDoc > 0) return _capacidadeMotoristaDoc;
    final listaVeiculos = _veiculosFrota.isNotEmpty
        ? _veiculosFrota
        : _viagemService.todosVeiculos;
    if (listaVeiculos.isNotEmpty) {
      final emUso =
          listaVeiculos.where((v) => v.emUso && v.capacidade > 0).firstOrNull;
      if (emUso != null) return emUso.capacidade;
      if (listaVeiculos.first.capacidade > 0) return listaVeiculos.first.capacidade;
    }
    return 7;
  }

  void _garantirCodigosPacientesNaViagemAtiva(List<PacienteModel> pacientes) {
    final viagem = _viagemAtiva;
    if (viagem == null ||
        viagem.id.isEmpty ||
        viagem.id.startsWith('sessao_ativa_') ||
        !viagem.isEmOperacao ||
        pacientes.isEmpty) {
      return;
    }

    final faltantes = <PacienteModel>[];
    for (final p in pacientes) {
      if (p.id.isEmpty) continue;
      final codigoExistente = viagem.codigosAcesso[p.id]?.trim() ?? '';
      final chaveControle = '${viagem.id}_${p.id}';
      if (codigoExistente.isEmpty &&
          !_pacientesGerandoCodigo.contains(chaveControle)) {
        _pacientesGerandoCodigo.add(chaveControle);
        faltantes.add(p);
      }
    }
    if (faltantes.isEmpty) return;

    Future.microtask(() async {
      final gerados = <String, String>{};
      try {
        for (final p in faltantes) {
          gerados[p.id] = await _viagemService.gerarOuObterCodigoAcesso(
            viagemId: viagem.id,
            pacienteId: p.id,
          );
        }
        if (mounted &&
            gerados.isNotEmpty &&
            _viagemAtiva != null &&
            _viagemAtiva!.id == viagem.id) {
          setState(() {
            final novosCodigos =
                Map<String, String>.from(_viagemAtiva!.codigosAcesso)
                  ..addAll(gerados);
            _viagemAtiva = _viagemAtiva!.copyWith(codigosAcesso: novosCodigos);
          });
        }
      } finally {
        for (final p in faltantes) {
          _pacientesGerandoCodigo.remove('${viagem.id}_${p.id}');
        }
      }
    });
  }

  /// Stream de passageiros exibidos para a viagem ativa (sem misturar dados de outros agendamentos).
  Stream<List<PacienteModel>> carregarPacientes() {
    if (widget.pacientesStreamOverride != null) {
      return widget.pacientesStreamOverride!;
    }
    return Stream.value(_mapearPassageirosLocaisDaViagemAtiva());
  }

  List<PacienteModel> _mapearPassageirosLocaisDaViagemAtiva() {
    final viagem = _viagemAtiva;
    if (viagem == null ||
        viagem.isConcluida ||
        viagem.isCancelada ||
        _viagemService.todosPacientesVoltaram(viagem) ||
        viagem.passageiros.isEmpty) {
      return const <PacienteModel>[];
    }
    return viagem.passageiros.map<PacienteModel>((pv) {
      final pMem = _syncService.obterPacienteMemoria(
        pv.pacienteId,
        viagemId: viagem.id,
      );
      final perfil = _viagemService.obterPerfilCadastralPaciente(pv.pacienteId);
      final modelo = _viagemService.construirPacienteDaViagem(
        pv,
        fallbackCadastro: perfil,
        statusOverride: pMem?.status ?? pv.statusEmbarque,
        prontoRetornoOverride: pMem?.prontoRetorno ?? pv.prontoRetorno,
        janelaReversaoOverride: pMem?.janelaReversao ?? pv.janelaReversao,
      );
      _syncService.registrarPacienteEmMemoriaSeAusente(
        modelo,
        viagemId: viagem.id,
      );
      return modelo;
    }).toList();
  }

  int _contarAssentosOcupados(List<PacienteModel> pacientes) {
    int preenchidos = 0;
    for (final p in pacientes.where((p) => p.status == 1 || p.status == 3)) {
      preenchidos += (p.nomeAcompanhante?.isNotEmpty == true) ? 2 : 1;
    }
    return preenchidos;
  }

  // ===========================================================================
  // SEÇÃO: Ações Operacionais (Deslize de Status e Logout)
  // ===========================================================================

  void _exibirSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: cor,
          content: Text(
            mensagem,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _efetuarLogout() async {
    await FirebaseAuthService().logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<bool> _tratarDeslizeCardPaciente(
    DismissDirection direction,
    PacienteModel paciente,
  ) async {
    if (direction != DismissDirection.endToStart || paciente.status >= 4) {
      return false;
    }

    // Regra de domínio: reembarque da volta (2 -> 3) exige que o paciente esteja pronto.
    if (paciente.status == 2 && !paciente.prontoRetorno) {
      _exibirSnackBar(
        'O paciente ainda está em atendimento médico.',
        const Color(0xFFD97706),
      );
      return false;
    }

    final (int proximoStatus, AcaoTransicao acao) = switch (paciente.status) {
      0 => (1, AcaoTransicao.motoristaEmbarcarIda),
      1 => (2, AcaoTransicao.motoristaDesembarcarConsulta),
      2 => (3, AcaoTransicao.motoristaReembarcarVolta),
      3 => (4, AcaoTransicao.motoristaConcluirViagem),
      _ => (-1, AcaoTransicao.motoristaEmbarcarIda),
    };
    if (proximoStatus == -1) return false;

    final (proximoStatusNome, proximoStatusCor, proximoStatusIcone) =
        PacienteModel.dadosStatus(proximoStatus);

    final confirmou = await exibirDialogoConfirmacaoMotorista(
      context: context,
      nomePaciente: paciente.nome,
      proximoStatusNome: proximoStatusNome,
      proximoStatusCor: proximoStatusCor,
      proximoStatusIcone: proximoStatusIcone,
      localDestino: (proximoStatus == 1 || proximoStatus == 2)
          ? paciente.localConsulta
          : paciente.enderecoPaciente,
    );
    if (!confirmou) return false;

    final idViagemAlvo = _viagemAtiva?.id;
    _syncService.registrarPacienteEmMemoriaSeAusente(
      paciente,
      viagemId: idViagemAlvo,
    );
    final resultado = await _syncService.avancarEtapaMotorista(
      pacienteId: paciente.id,
      motoristaId: _motoristaId ?? 'motorista',
      acao: acao,
      viagemId: idViagemAlvo,
    );
    if (!mounted) return false;

    if (resultado.sucesso) {
      if (idViagemAlvo != null && !idViagemAlvo.startsWith('sessao_ativa_')) {
        unawaited(
          _viagemService.atualizarStatusPassageiroNaViagem(
            viagemId: idViagemAlvo,
            pacienteId: paciente.id,
            novoStatus: proximoStatus,
            prontoRetorno: resultado.paciente?.prontoRetorno,
            janelaReversao: resultado.paciente?.janelaReversao,
            limparJanelaReversao: resultado.paciente?.janelaReversao == null,
          ),
        );
      }
      if (widget.pacientesStreamOverride == null) {
        setState(() {
          _selecionarViagemPreservandoId(
            _viagemService.viagensAtivas,
            idPreferido: idViagemAlvo,
          );
          _capacidadeVeiculo = _resolverCapacidadeVeiculo();
        });
      }
      if (proximoStatus >= 1 &&
          proximoStatus < 4 &&
          _viagemAtiva != null &&
          _viagemAtiva!.id == idViagemAlvo &&
          !_viagemAtiva!.id.startsWith('sessao_ativa_') &&
          !_viagemAtiva!.isConcluida) {
        final idViagemCodigo = _viagemAtiva!.id;
        unawaited(
          _viagemService
              .gerarOuObterCodigoAcesso(
                viagemId: idViagemCodigo,
                pacienteId: paciente.id,
              )
              .then((codigo) {
            if (!mounted ||
                _viagemAtiva == null ||
                _viagemAtiva!.id != idViagemCodigo ||
                _viagemAtiva!.id.startsWith('sessao_ativa_') ||
                _viagemAtiva!.isConcluida) {
              return;
            }
            setState(() {
              final novosCodigos = Map<String, String>.from(
                _viagemAtiva!.codigosAcesso,
              )..[paciente.id] = codigo;
              final novosPassageiros = _viagemAtiva!.passageiros
                  .map(
                    (pv) => pv.pacienteId == paciente.id
                        ? pv.copyWith(statusEmbarque: proximoStatus)
                        : pv,
                  )
                  .toList();
              _viagemAtiva = _viagemAtiva!.copyWith(
                codigosAcesso: novosCodigos,
                passageiros: novosPassageiros,
              );
            });
          }),
        );
      }
      _exibirSnackBar(
        "Avanço para '$proximoStatusNome' confirmado com sucesso.",
        const Color(0xFF16A34A),
      );
    } else {
      _exibirSnackBar(resultado.mensagem, const Color(0xFFB83227));
    }

    // Sempre retorna false para o Dismissible não remover o card da árvore;
    // a atualização visual vem da Stream/estado da viagem.
    return false;
  }

  // ===========================================================================
  // SEÇÃO: Construção da Interface (Widgets)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_emViagemFirestore == false &&
        widget.viagemInicial == null &&
        widget.pacientesStreamOverride == null) {
      return _construirTelaFormularioInicio();
    }
    if (!_temViagemAtiva && _emViagemFirestore == true) {
      return _construirTelaCarregamentoViagem();
    }
    if (!_temViagemAtiva) {
      return _construirTelaFormularioInicio();
    }

    return StreamBuilder<List<PacienteModel>>(
      key: widget.pacientesStreamOverride == null
          ? ValueKey('stream_viagem_${_viagemAtiva?.id ?? "vazio"}')
          : null,
      initialData: widget.pacientesStreamOverride != null
          ? null
          : _mapearPassageirosLocaisDaViagemAtiva(),
      stream: carregarPacientes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Erro ao carregar os pacientes.')),
          );
        }

        final List<PacienteModel> pacientes =
            widget.pacientesStreamOverride != null
                ? (snapshot.data ?? [])
                : _mapearPassageirosLocaisDaViagemAtiva();

        _garantirCodigosPacientesNaViagemAtiva(pacientes);
        final preenchidos = _contarAssentosOcupados(pacientes);

        final placaSessao = _resolverPlacaVeiculoSessao();
        final placaViagem = _viagemAtiva?.veiculoPlaca.trim() ?? '';
        final veiculoViagemHeader = placaViagem.isNotEmpty &&
                _normalizarPlaca(placaViagem) != _normalizarPlaca(placaSessao)
            ? placaViagem
            : null;
        final motViagemHeader = _viagemAtiva?.motoristaNome.trim() ?? '';
        final motoristaHeader = (motViagemHeader.isNotEmpty &&
                motViagemHeader != 'motorista_atual')
            ? motViagemHeader
            : null;
        final destinoHeader = (_viagensAtivas.length <= 1 &&
                (_viagemAtiva?.cidadeDestino.trim().isNotEmpty == true))
            ? _viagemAtiva!.cidadeDestino.trim()
            : null;
        final saidaRaw = _viagemAtiva?.nomeHorario?.trim() ?? '';
        final saidaHeader = saidaRaw.isNotEmpty ? saidaRaw : null;

        return Scaffold(
          appBar: _construirAppBarEmViagem(),
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MotoristaHeader(
                  tituloViagem: _viagensAtivas.length > 1
                      ? 'Viagem ${_indiceViagemAtual + 1} de ${_viagensAtivas.length} (${_viagemAtiva?.cidadeDestino ?? ""})'
                      : (_viagemAtiva != null && _viagemAtiva!.id.isNotEmpty
                            ? 'Viagem ${_viagemAtiva!.id}'
                            : 'Viagem 1'),
                  motoristaNome: motoristaHeader,
                  destino: destinoHeader,
                  veiculo: veiculoViagemHeader,
                  saida: saidaHeader,
                  onAnterior: _viagensAtivas.length > 1 && _indiceViagemAtual > 0
                      ? () => setState(() {
                          _indiceViagemAtual--;
                          _viagemAtiva = _viagensAtivas[_indiceViagemAtual];
                          _capacidadeVeiculo = _resolverCapacidadeVeiculo();
                        })
                      : null,
                  onProxima: _viagensAtivas.length > 1 &&
                          _indiceViagemAtual < _viagensAtivas.length - 1
                      ? () => setState(() {
                          _indiceViagemAtual++;
                          _viagemAtiva = _viagensAtivas[_indiceViagemAtual];
                          _capacidadeVeiculo = _resolverCapacidadeVeiculo();
                        })
                      : null,
                ),
                const SizedBox(height: 12),
                for (final paciente in pacientes)
                  _construirCardPassageiro(paciente),
              ],
            ),
          ),
          bottomNavigationBar: FooterPacientes(
            lugaresPreenchidos: preenchidos,
            lugaresTotais: _capacidadeVeiculo > 0 ? _capacidadeVeiculo : 7,
            viagem: _viagemAtiva,
            viagens: _viagensAtivas,
            pacientes: pacientes,
            motoristaId: _obterIdMotoristaSessao(),
            onViagemEncerrada: _aoEncerrarViagemMotorista,
          ),
        );
      },
    );
  }

  Widget _construirTelaCarregamentoViagem() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Carregando viagem ativa...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  key: const Key('botaoCancelarCarregandoViagem'),
                  onPressed: () {
                    _cancelarTimeoutCarregamentoViagem();
                    _resetarEstadoParaNovaViagem(_obterIdMotoristaSessao());
                  },
                  child: const Text(
                    'Iniciar nova viagem',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirTelaFormularioInicio() {
    final idMotoristaSessao = _obterIdMotoristaSessao();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Início da Viagem',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            key: const Key('botaoLogoutMotorista'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sair da conta',
            onPressed: _efetuarLogout,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: FormularioInicioViagem(
              motoristaId: idMotoristaSessao.isNotEmpty
                  ? idMotoristaSessao
                  : 'motorista_atual',
              motoristaNome: _motoristaNome.isNotEmpty
                  ? _motoristaNome
                  : 'Motorista da Saúde',
              onViagemIniciada: (novaViagem) {
                _cancelarTimeoutCarregamentoViagem();
                _inicioViagemOptimistaEm = DateTime.now();
                setState(() {
                  _emViagemFirestore = true;
                  FirebaseAuthService.motoristaEmViagemStatic = true;
                  _viagemAtiva = novaViagem;
                  _viagensAtivas = _viagemService.viagensAtivas.isNotEmpty
                      ? _viagemService.viagensAtivas
                      : [novaViagem];
                  _indiceViagemAtual = 0;
                  _capacidadeVeiculo = _resolverCapacidadeVeiculo();
                });
                _atualizarTransmissaoGpsMotorista();
              },
            ),
          ),
        ),
      ),
    );
  }

  AppBar _construirAppBarEmViagem() {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      foregroundColor: Colors.white,
      elevation: 2,
      titleSpacing: 4,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: Colors.white,
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacementNamed('/');
          }
        },
      ),
      title: const Text(
        'Lista de Passageiros',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        if (_viagemAtiva != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width < 360 ? 115 : 150,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Em Viagem: ${_resolverPlacaVeiculoSessao()}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        IconButton(
          key: const Key('botaoLogoutMotorista'),
          icon: const Icon(Icons.logout),
          color: Colors.white,
          tooltip: 'Sair da conta',
          onPressed: _efetuarLogout,
        ),
      ],
    );
  }

  Widget _construirCardPassageiro(PacienteModel paciente) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(paciente.id.isNotEmpty ? paciente.id : paciente.nome),
        // Permite apenas deslize da direita para a esquerda para avançar status.
        direction:
            (paciente.status < 4) ? DismissDirection.endToStart : DismissDirection.none,
        background: Container(),
        secondaryBackground: Container(
          padding: const EdgeInsets.only(right: 16),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_forward, color: Colors.white, size: 50),
              Text('Avançar', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        confirmDismiss: (direction) =>
            _tratarDeslizeCardPaciente(direction, paciente),
        child: CardPaciente(
          nomePaciente: paciente.nome,
          enderecoPaciente: paciente.enderecoPaciente,
          telPaciente: paciente.telefone,
          localConsulta: paciente.localConsulta,
          localSaida: paciente.localSaida,
          status: paciente.status,
          nomeAcompanhante: paciente.nomeAcompanhante,
          telAcompanhante: paciente.telAcompanhante,
          prontoRetorno: paciente.prontoRetorno,
          janelaReversao: paciente.janelaReversao,
          codigoAcesso: _viagemAtiva?.codigosAcesso[paciente.id],
        ),
      ),
    );
  }
}
