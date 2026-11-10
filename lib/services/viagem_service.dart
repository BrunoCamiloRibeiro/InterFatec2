import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/janela_reversao_model.dart';
import '../models/paciente_model.dart';
import '../models/sessao_veiculo_model.dart';
import '../models/user_role.dart';
import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import 'auth_service.dart';
import 'codigo_acesso_service.dart';
import 'localizacao_motorista_service.dart';
import 'paciente_sync_service.dart';
import 'validacao_viagem.dart';

// =============================================================================
// MODELOS DE RESULTADO (Result Pattern)
// =============================================================================

/// Resultado de operações administrativas de CRUD e gestão de Horários de Viagem.
class ResultadoOperacaoViagem {
  final bool sucesso;
  final ViagemModel? viagem;
  final String? mensagemErro;

  const ResultadoOperacaoViagem._({
    required this.sucesso,
    this.viagem,
    this.mensagemErro,
  });

  factory ResultadoOperacaoViagem.sucesso(ViagemModel viagem) =>
      ResultadoOperacaoViagem._(sucesso: true, viagem: viagem);

  factory ResultadoOperacaoViagem.erro(String mensagem) =>
      ResultadoOperacaoViagem._(sucesso: false, mensagemErro: mensagem);
}

/// Resultado da declaração de veículo e abertura de sessão pelo motorista.
class ResultadoDeclaracaoVeiculo {
  final bool sucesso;
  final SessaoVeiculoModel? sessao;
  final String? mensagemErro;

  const ResultadoDeclaracaoVeiculo._({
    required this.sucesso,
    this.sessao,
    this.mensagemErro,
  });

  factory ResultadoDeclaracaoVeiculo.sucesso(SessaoVeiculoModel sessao) =>
      ResultadoDeclaracaoVeiculo._(sucesso: true, sessao: sessao);

  factory ResultadoDeclaracaoVeiculo.erro(String mensagem) =>
      ResultadoDeclaracaoVeiculo._(sucesso: false, mensagemErro: mensagem);
}

/// Resultado da tentativa de iniciar ou vincular viagem a um veículo.
class ResultadoInicioViagem {
  final bool sucesso;
  final ViagemModel? viagem;
  final String? mensagemErro;

  const ResultadoInicioViagem._({
    required this.sucesso,
    this.viagem,
    this.mensagemErro,
  });

  factory ResultadoInicioViagem.sucesso(ViagemModel viagem) =>
      ResultadoInicioViagem._(sucesso: true, viagem: viagem);

  factory ResultadoInicioViagem.erro(String mensagem) =>
      ResultadoInicioViagem._(sucesso: false, mensagemErro: mensagem);
}

// =============================================================================
// SERVIÇO DE DOMÍNIO E PERSISTÊNCIA DE VIAGENS E FROTA
// =============================================================================

/// Serviço Singleton responsável pelo ciclo de vida das viagens, alocação
/// concorrente de veículos (transações ACID), streams reativas e CRUD do admin.
class ViagemService {
  static final ViagemService _instance = ViagemService._interno();
  factory ViagemService() => _instance;

  ViagemService._interno() {
    _inicializarDadosBase();
  }

  // ---------------------------------------------------------------------------
  // Estado em memória e Streams reativas (Observer / Broadcast)
  // ---------------------------------------------------------------------------
  SessaoVeiculoModel? _sessaoAtiva;
  ViagemModel? _viagemAtiva;
  final List<ViagemModel> _viagensAtivasMemoria = [];
  final List<ViagemModel> _todasViagensMemoria = [];
  final List<ViagemModel> _viagensConcluidasNaSessao = [];
  final List<VeiculoModel> _veiculosMemoria = [];

  final StreamController<SessaoVeiculoModel?> _sessaoAtivaController =
      StreamController<SessaoVeiculoModel?>.broadcast();
  final StreamController<List<ViagemModel>> _viagensAtivasController =
      StreamController<List<ViagemModel>>.broadcast();
  final StreamController<ViagemModel?> _viagemAtivaController =
      StreamController<ViagemModel?>.broadcast();
  final StreamController<List<VeiculoModel>> _veiculosController =
      StreamController<List<VeiculoModel>>.broadcast();
  final StreamController<List<ViagemModel>> _todasViagensController =
      StreamController<List<ViagemModel>>.broadcast();
  final StreamController<String> _errosSincronizacaoController =
      StreamController<String>.broadcast();

  bool _inicializado = false;
  bool _escutandoFirestore = false;
  bool _sessaoFinalizadaPeloMotorista = false;

  StreamSubscription<({String? viagemId, PacienteModel paciente})>?
      _subSyncPacientesInterno;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subVeiculosRemoto;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subPacientesRemoto;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subViagensRemoto;

  /// Cache cadastral de pacientes (dados de perfil apenas; status pertence a cada viagem).
  final Map<String, PacienteModel> _perfisPacientesPorId = {};

  /// Viagens com transação em voo no Firestore para evitar flickering por snapshots pré-commit.
  final Set<String> _viagensComEscritaEmVoo = {};

  /// Sessões ativas indexadas por motorista para isolamento de concorrência.
  final Map<String, SessaoVeiculoModel> _sessoesAtivasPorMotorista = {};

  int _totalGravacoesFirestoreJornada = 0;

  /// Hook de teste para simular erro de rede/permissão em mutações assíncronas.
  @visibleForTesting
  Future<void> Function(String operacao, Map<String, dynamic> payload)?
      executorPersistenciaRemotaOverride;

  // Getters públicos de estado e streams
  ViagemModel? get viagemAtiva => _viagemAtiva;
  SessaoVeiculoModel? get sessaoAtiva => _sessaoAtiva;
  Stream<SessaoVeiculoModel?> get sessaoAtivaStream =>
      _sessaoAtivaController.stream;
  List<ViagemModel> get viagensAtivas =>
      List.unmodifiable(_viagensAtivasMemoria);
  Stream<List<ViagemModel>> get viagensAtivasStream =>
      _viagensAtivasController.stream;
  Stream<ViagemModel?> get viagemAtivaStream => _viagemAtivaController.stream;
  Stream<List<VeiculoModel>> get veiculosStream => _veiculosController.stream;
  List<VeiculoModel> get todosVeiculos => List.unmodifiable(_veiculosMemoria);
  Stream<String> get errosSincronizacaoStream =>
      _errosSincronizacaoController.stream;
  int get totalGravacoesFirestoreJornada => _totalGravacoesFirestoreJornada;

  Stream<List<ViagemModel>> get todasViagensStream {
    _garantirEscutaFirestore();
    return _todasViagensController.stream;
  }

  List<ViagemModel> get todasViagens {
    _garantirEscutaFirestore();
    return List.unmodifiable(_todasViagensMemoria);
  }

  PacienteModel? obterPerfilCadastralPaciente(String pacienteId) =>
      _perfisPacientesPorId[pacienteId];

  // ===========================================================================
  // SEÇÃO: Construção e Sincronização de Passageiros por Viagem
  // ===========================================================================

  /// Consolida dados do passageiro na viagem com perfil cadastral e cache de memória.
  PacienteModel construirPacienteDaViagem(
    PassageiroViagemModel pv, {
    PacienteModel? fallbackCadastro,
    int? statusOverride,
    bool? prontoRetornoOverride,
    JanelaReversaoModel? janelaReversaoOverride,
    String? ultimaIdempotencyKey,
  }) {
    final pBase = fallbackCadastro ?? _perfisPacientesPorId[pv.pacienteId];
    return PacienteModel(
      id: pv.pacienteId,
      nome: pv.pacienteNome.isNotEmpty
          ? pv.pacienteNome
          : (pBase?.nome ?? ''),
      cpf: (pv.pacienteCpf != null && pv.pacienteCpf!.isNotEmpty)
          ? pv.pacienteCpf!
          : (pBase?.cpf ?? ''),
      telefone: (pv.pacienteTelefone != null && pv.pacienteTelefone!.isNotEmpty)
          ? pv.pacienteTelefone!
          : ((pBase != null && pBase.telefone.isNotEmpty)
                ? pBase.telefone
                : (pv.acompanhanteTelefone ?? '')),
      enderecoPaciente: pv.localOrigem.isNotEmpty
          ? pv.localOrigem
          : (pBase?.enderecoPaciente ?? ''),
      localSaida: pv.localOrigem.isNotEmpty
          ? pv.localOrigem
          : (pBase?.localSaida ?? ''),
      localConsulta: pv.localDestino.isNotEmpty
          ? pv.localDestino
          : (pBase?.localConsulta ?? ''),
      horarioConsulta: pv.horarioAtendimento.isNotEmpty
          ? pv.horarioAtendimento
          : (pBase?.horarioConsulta ?? ''),
      nomeAcompanhante:
          (pv.acompanhanteNome != null && pv.acompanhanteNome!.isNotEmpty)
              ? pv.acompanhanteNome
              : pBase?.nomeAcompanhante,
      cpfAcompanhante: pBase?.cpfAcompanhante,
      telAcompanhante:
          (pv.acompanhanteTelefone != null && pv.acompanhanteTelefone!.isNotEmpty)
              ? pv.acompanhanteTelefone
              : pBase?.telAcompanhante,
      rg: pBase?.rg,
      cnh: pBase?.cnh,
      status: statusOverride ?? pv.statusEmbarque,
      prontoRetorno: prontoRetornoOverride ?? pv.prontoRetorno,
      janelaReversao: janelaReversaoOverride ?? pv.janelaReversao,
      ultimaIdempotencyKey: ultimaIdempotencyKey ?? pBase?.ultimaIdempotencyKey,
    );
  }

  void _sincronizarPassageiroEmMemoriaPorViagem(
    String viagemId,
    PassageiroViagemModel pv,
  ) {
    if (viagemId.trim().isEmpty ||
        viagemId.startsWith('sessao_ativa_') ||
        pv.pacienteId.trim().isEmpty) {
      return;
    }
    final perfil = _perfisPacientesPorId[pv.pacienteId];
    final memAnterior = PacienteSyncService().obterPacienteMemoria(
      pv.pacienteId,
      viagemId: viagemId,
    );
    PacienteSyncService().sincronizarPassageiroDeViagemEmMemoria(
      viagemId,
      construirPacienteDaViagem(
        pv,
        fallbackCadastro: perfil ?? memAnterior,
        ultimaIdempotencyKey: memAnterior?.ultimaIdempotencyKey,
      ),
    );
  }

  /// Reconstrói a lista de [PacienteModel] da viagem (usado no relatório PDF e resumo).
  List<PacienteModel> obterPacientesParaViagemRelatorio(
    ViagemModel viagem, {
    List<PacienteModel>? pacientesInformados,
  }) {
    final mapaInformados = <String, PacienteModel>{
      if (pacientesInformados != null)
        for (final p in pacientesInformados) p.id: p,
    };
    if (viagem.passageiros.isNotEmpty) {
      return viagem.passageiros.map((pv) {
        final pInf = mapaInformados[pv.pacienteId];
        final pMem = PacienteSyncService().obterPacienteMemoria(
          pv.pacienteId,
          viagemId: viagem.id,
        );
        final pBase = pInf ?? pMem ?? _perfisPacientesPorId[pv.pacienteId];
        final st = resolverStatusEfetivoPassageiro(
          pv,
          viagemId: viagem.id,
          pacientesContexto: pacientesInformados,
        );
        return construirPacienteDaViagem(
          pv,
          fallbackCadastro: pBase,
          statusOverride: st,
          prontoRetornoOverride:
              pv.prontoRetorno || (pMem?.prontoRetorno ?? false),
          janelaReversaoOverride: pv.janelaReversao ?? pMem?.janelaReversao,
        );
      }).toList();
    }
    return pacientesInformados ?? const <PacienteModel>[];
  }

  /// Resolve o status efetivo de um passageiro (estritamente isolado por [viagemId] quando informado).
  int resolverStatusEfetivoPassageiro(
    PassageiroViagemModel p, {
    String? viagemId,
    List<PacienteModel>? pacientesContexto,
  }) {
    final possuiEscopo = viagemId != null && viagemId.trim().isNotEmpty;
    final pacSync = PacienteSyncService().obterPacienteMemoria(
      p.pacienteId,
      viagemId: viagemId,
    );
    if (possuiEscopo && pacSync != null) {
      return pacSync.status;
    }

    int statusEfetivo = p.statusEmbarque;
    if (!possuiEscopo && pacientesContexto != null) {
      final pacCtx =
          pacientesContexto.where((x) => x.id == p.pacienteId).firstOrNull;
      if (pacCtx != null) {
        if (pacCtx.status == 5 || statusEfetivo == 5) return 5;
        if (pacCtx.status > statusEfetivo &&
            !(statusEfetivo == 0 && pacCtx.status == 4)) {
          statusEfetivo = pacCtx.status;
        }
      }
    }
    if (!possuiEscopo && pacSync != null) {
      if (pacSync.status == 5 || statusEfetivo == 5) return 5;
      if (pacSync.status > statusEfetivo &&
          !(statusEfetivo == 0 && pacSync.status == 4)) {
        statusEfetivo = pacSync.status;
      }
    }
    return statusEfetivo;
  }

  /// Calcula assentos ocupados pelos pacientes em trânsito (status >= 1 e <= 3).
  int calcularLugaresPreenchidosComBaixa(
    ViagemModel viagem, {
    List<PacienteModel>? pacientesContexto,
  }) {
    if (viagem.passageiros.isNotEmpty) {
      int total = 0;
      for (final p in viagem.passageiros) {
        final st = resolverStatusEfetivoPassageiro(
          p,
          viagemId: viagem.id,
          pacientesContexto: pacientesContexto,
        );
        if (st >= 1 && st <= 3) {
          total += p.assentosOcupados;
        }
      }
      return total;
    }
    if (pacientesContexto != null && pacientesContexto.isNotEmpty) {
      final ids = viagem.passageirosIds.toSet();
      final lista = ids.isNotEmpty
          ? pacientesContexto.where((p) => ids.contains(p.id))
          : pacientesContexto;
      int total = 0;
      for (final p in lista) {
        if (p.status >= 1 && p.status <= 3) {
          total += (p.nomeAcompanhante != null &&
                  p.nomeAcompanhante!.trim().isNotEmpty)
              ? 2
              : 1;
        }
      }
      return total;
    }
    return 0;
  }

  /// Verifica se todos os pacientes não cancelados já retornaram (status == 4).
  bool todosPacientesVoltaram(
    ViagemModel viagem, {
    List<PacienteModel>? pacientesContexto,
  }) {
    if (viagem.passageiros.isNotEmpty) {
      final naoCancelados = viagem.passageiros.where((p) {
        final st = resolverStatusEfetivoPassageiro(
          p,
          viagemId: viagem.id,
          pacientesContexto: pacientesContexto,
        );
        return st != 5;
      }).toList();
      if (naoCancelados.isEmpty) return true;
      return naoCancelados.every((p) {
        final st = resolverStatusEfetivoPassageiro(
          p,
          viagemId: viagem.id,
          pacientesContexto: pacientesContexto,
        );
        return st == 4;
      });
    }
    if (pacientesContexto != null && pacientesContexto.isNotEmpty) {
      final ids = viagem.passageirosIds.toSet();
      final listaRef = ids.isNotEmpty
          ? pacientesContexto.where((p) => ids.contains(p.id)).toList()
          : pacientesContexto;
      final naoCancelados = listaRef.where((p) => p.status != 5).toList();
      if (naoCancelados.isEmpty) return true;
      return naoCancelados.every((p) => p.status == 4);
    }
    if (viagem.passageirosIds.isNotEmpty) {
      bool algumRegistrado = false;
      for (final id in viagem.passageirosIds) {
        final pacSync = PacienteSyncService().obterPacienteMemoria(
          id,
          viagemId: viagem.id,
        );
        if (pacSync != null) {
          algumRegistrado = true;
          if (pacSync.status != 4 && pacSync.status != 5) {
            return false;
          }
        } else {
          return false;
        }
      }
      if (algumRegistrado) return true;
    }
    return viagem.isConcluida;
  }

  // ===========================================================================
  // SEÇÃO: Helpers Internos de Infraestrutura e Estado de Sessão
  // ===========================================================================

  void _tratarFalhaFirestore(
    String operacao,
    Object erro, {
    VoidCallback? onRollback,
  }) {
    String codigo = 'unknown';
    String detalhe = erro.toString();
    if (erro is FirebaseException) {
      codigo = erro.code;
      detalhe = erro.message ?? erro.code;
    }
    debugPrint('Falha Firestore em [$operacao] ($codigo): $detalhe');
    if (onRollback != null &&
        (erro is FirebaseException ||
            codigo == 'unavailable' ||
            codigo == 'permission-denied' ||
            codigo == 'resource-exhausted' ||
            detalhe.contains('permission-denied') ||
            detalhe.contains('unavailable') ||
            detalhe.contains('resource-exhausted') ||
            executorPersistenciaRemotaOverride != null)) {
      onRollback();
    }
    if (!_errosSincronizacaoController.isClosed) {
      _errosSincronizacaoController.add(
        'Falha de sincronização ($codigo) em $operacao: $detalhe',
      );
    }
  }

  String _obterInicioDoDiaOperacionalIso([DateTime? referencia]) {
    final ref = referencia ?? DateTime.now();
    return DateTime(ref.year, ref.month, ref.day).toIso8601String();
  }

  String _normalizarPlacaInterna(String placa) =>
      placa.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  String _normalizarTextoRota(String valor) {
    return valor
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÂÃ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊ]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÔÕ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛ]'), 'U')
        .replaceAll('Ç', 'C');
  }

  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } on FirebaseException catch (e) {
      debugPrint('Firebase indisponível (${e.code})');
      return false;
    } catch (_) {
      return false;
    }
  }

  void _emitirStreamsViagens() {
    if (!_todasViagensController.isClosed) {
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }
    if (!_viagensAtivasController.isClosed) {
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
    if (!_viagemAtivaController.isClosed) {
      _viagemAtivaController.add(_viagemAtiva);
    }
  }

  void _restaurarSnapshotSessao({
    required int indiceVeiculo,
    required VeiculoModel? veiculoAnterior,
    required String motoristaId,
    required SessaoVeiculoModel? sessaoAnterior,
    required ViagemModel? viagemAtivaAnterior,
    required List<ViagemModel> viagensAtivasAnteriores,
    required List<ViagemModel> todasViagensAnteriores,
  }) {
    if (indiceVeiculo != -1 && veiculoAnterior != null) {
      _veiculosMemoria[indiceVeiculo] = veiculoAnterior;
    }
    if (motoristaId.isNotEmpty) {
      _sessoesAtivasPorMotorista.remove(motoristaId);
    }
    _sessaoAtiva = sessaoAnterior;
    _viagemAtiva = viagemAtivaAnterior;
    _viagensAtivasMemoria
      ..clear()
      ..addAll(viagensAtivasAnteriores);
    _todasViagensMemoria
      ..clear()
      ..addAll(todasViagensAnteriores);
    _sessaoAtivaController.add(_sessaoAtiva);
    _emitirStreamsViagens();
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );
  }

  Future<void> _aplicarOcupacaoVeiculoNaTransacao(
    Transaction transaction, {
    required VeiculoModel veiculo,
    required int kmInicial,
    required String motoristaId,
    required String mensagemConflito,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('veiculos').doc(veiculo.id);
    final docSnap = await transaction.get(docRef);
    if (docSnap.exists) {
      final dados = docSnap.data() ?? {};
      final emUsoRemoto = dados['emUso'] == true;
      final motoristaOcupando = dados['motoristaAtualId'];
      if (emUsoRemoto &&
          motoristaOcupando != null &&
          motoristaOcupando != motoristaId) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'aborted',
          message: mensagemConflito,
        );
      }
    }

    transaction.set(docRef, {
      'emUso': true,
      'motoristaAtualId': motoristaId,
      'quilometragemAtual': kmInicial,
      'status': 'emViagem',
    }, SetOptions(merge: true));

    if (motoristaId.isNotEmpty) {
      FirebaseAuthService.motoristaEmViagemStatic = true;
      final motoristaRef =
          FirebaseFirestore.instance.collection('usuarios').doc(motoristaId);
      transaction.set(motoristaRef, {'emViagem': true}, SetOptions(merge: true));
    }
  }

  void _registrarViagemConcluidaParaRelatorio(
    ViagemModel concluida, {
    required Map<String, String> codigosOriginais,
    ViagemModel? referenciaSessao,
  }) {
    final idxConcl = _viagensConcluidasNaSessao.indexWhere(
      (vc) => vc.id == concluida.id,
    );
    final enriquecida = _enriquecerViagemParaRelatorio(
      concluida.copyWith(codigosAcesso: codigosOriginais),
      referenciaSessao: referenciaSessao,
    );
    if (idxConcl == -1) {
      _viagensConcluidasNaSessao.add(enriquecida);
    } else {
      _viagensConcluidasNaSessao[idxConcl] = enriquecida;
    }
  }

  // ===========================================================================
  // SEÇÃO: Escuta em Tempo Real no Firestore
  // ===========================================================================

  void _inicializarDadosBase() {
    _subSyncPacientesInterno ??=
        PacienteSyncService().alteracoesPorViagemStream.listen((evento) {
      // Eventos já escopados por viagemId são persistidos pelo chamador;
      // aqui mantemos compatibilidade apenas com fluxo legado sem viagemId.
      if (evento.viagemId != null && evento.viagemId!.trim().isNotEmpty) {
        return;
      }
      final p = evento.paciente;
      atualizarStatusPassageiroNaViagem(
        viagemId: '',
        pacienteId: p.id,
        novoStatus: p.status,
        prontoRetorno: p.prontoRetorno,
        janelaReversao: p.janelaReversao,
        limparJanelaReversao: p.janelaReversao == null,
        persistirRemoto: false,
      );
    });
    if (_inicializado) {
      _garantirEscutaFirestore();
      return;
    }
    _garantirEscutaFirestore();
    _inicializado = true;
  }

  void _garantirEscutaFirestore() {
    if (_escutandoFirestore || !_isFirebaseDisponivel()) return;
    _escutandoFirestore = true;
    try {
      _subVeiculosRemoto?.cancel();
      _subVeiculosRemoto = FirebaseFirestore.instance
          .collection('veiculos')
          .snapshots()
          .listen((snap) {
        _veiculosMemoria
          ..clear()
          ..addAll(snap.docs.map((d) => VeiculoModel.fromMap(d.data(), docId: d.id)));
        if (!_veiculosController.isClosed) {
          _veiculosController
              .add(ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria));
        }
      }, onError: (Object e) {
        _tratarFalhaFirestore('escutar_veiculos', e);
      });

      _subPacientesRemoto?.cancel();
      _subPacientesRemoto = FirebaseFirestore.instance
          .collection('usuarios')
          .where('role', isEqualTo: 'paciente')
          .snapshots()
          .listen((snap) {
        for (final d in snap.docs) {
          _perfisPacientesPorId[d.id] =
              PacienteModel.fromMap(d.data(), docId: d.id);
        }
      }, onError: (Object e) {
        _tratarFalhaFirestore('escutar_pacientes', e);
      });

      // Listener passivo (nunca escreve no Firestore para evitar loops reentrantes).
      _subViagensRemoto?.cancel();
      _subViagensRemoto = FirebaseFirestore.instance
          .collection('viagens')
          .snapshots()
          .listen((snap) {
        final viagensCarregadas = <ViagemModel>[];
        for (final d in snap.docs) {
          var v = ViagemModel.fromMap(d.data(), docId: d.id);
          if ((v.isAtiva || v.isPlanejada) && !v.isCancelada && !v.isConcluida) {
            final (codigos, hashes, alterou) = _sincronizarCodigosDaViagem(
              viagemId: v.id,
              passageiros: v.passageiros,
              passageirosIds: v.passageirosIds,
              codigosExistentes: v.codigosAcesso,
              hashesExistentes: v.codigosHash,
            );
            if (alterou) {
              v = v.copyWith(codigosAcesso: codigos, codigosHash: hashes);
            }
          }
          viagensCarregadas.add(v);
        }
        sincronizarViagensRemotas(viagensCarregadas);
      }, onError: (Object e) {
        _tratarFalhaFirestore('escutar_viagens', e);
      });
    } catch (e) {
      _escutandoFirestore = false;
      _tratarFalhaFirestore('garantir_escuta_firestore', e);
    }
  }

  /// Cancela os listeners ativos do Firestore ao encerrar a sessão.
  void encerrarEscutasFirestore() {
    _subVeiculosRemoto?.cancel();
    _subVeiculosRemoto = null;
    _subPacientesRemoto?.cancel();
    _subPacientesRemoto = null;
    _subViagensRemoto?.cancel();
    _subViagensRemoto = null;
    _escutandoFirestore = false;
  }

  /// Limpa apenas o estado local da sessão do condutor atual (usado em troca/logout).
  void limparSessaoLocal() {
    _sessaoFinalizadaPeloMotorista = false;
    final motId = _sessaoAtiva?.motoristaId.trim() ?? '';
    if (motId.isNotEmpty) {
      _sessoesAtivasPorMotorista.remove(motId);
    }
    _sessaoAtiva = null;
    _viagemAtiva = null;
    _viagensAtivasMemoria.clear();
    _viagensConcluidasNaSessao.clear();
    if (!_sessaoAtivaController.isClosed) {
      _sessaoAtivaController.add(null);
    }
    _emitirStreamsViagens();
  }

  Stream<List<VeiculoModel>> carregarVeiculosDisponiveis({String? motoristaId}) {
    if (_isFirebaseDisponivel()) {
      try {
        return FirebaseFirestore.instance
            .collection('veiculos')
            .snapshots()
            .map((snapshot) {
          final base = snapshot.docs.isEmpty
              ? _veiculosMemoria
              : snapshot.docs
                  .map((doc) => VeiculoModel.fromMap(doc.data(), docId: doc.id))
                  .toList();
          return ValidacaoViagem.filtrarVeiculosDisponiveis(
            base,
            motoristaPermitidoId: motoristaId,
          );
        });
      } catch (e) {
        _tratarFalhaFirestore('carregar_veiculos_disponiveis', e);
      }
    }

    Future.microtask(() {
      if (!_veiculosController.isClosed) {
        _veiculosController.add(
          ValidacaoViagem.filtrarVeiculosDisponiveis(
            _veiculosMemoria,
            motoristaPermitidoId: motoristaId,
          ),
        );
      }
    });
    return _veiculosController.stream;
  }

  // ===========================================================================
  // SEÇÃO: Elegibilidade de Viagens, Sessão e Relatório
  // ===========================================================================

  bool _viagemElegivelParaSessao(
    ViagemModel v, {
    required String motoristaId,
    required String veiculoId,
    required String veiculoPlaca,
    String? cidadeDestino,
    String? sessaoId,
  }) {
    if (v.isCancelada || v.isConcluida) return false;
    if (v.id.startsWith('sessao_ativa_')) return false;
    if (todosPacientesVoltaram(v)) return false;

    final motViagem = v.motoristaId.trim();
    final motAlvo = motoristaId.trim();
    if (motViagem.isNotEmpty &&
        motAlvo.isNotEmpty &&
        motViagem != motAlvo &&
        motViagem != 'motorista_atual') {
      return false;
    }

    final veicViagem = v.veiculoId.trim();
    final veicAlvo = veiculoId.trim();
    final placaViagem = _normalizarPlacaInterna(v.veiculoPlaca);
    final placaAlvo = _normalizarPlacaInterna(veiculoPlaca);
    final vinculadaAoMotorista = motViagem.isNotEmpty &&
        (motViagem == motAlvo || motViagem == 'motorista_atual');
    final vinculadaAoVeiculo =
        (veicViagem.isNotEmpty && veicViagem == veicAlvo) ||
        (placaViagem.isNotEmpty && placaViagem == placaAlvo);

    final sessaoViagem = v.sessaoId?.trim() ?? '';
    final sessaoAlvo = sessaoId?.trim() ?? '';
    if (sessaoViagem.isNotEmpty &&
        sessaoAlvo.isNotEmpty &&
        sessaoViagem != sessaoAlvo &&
        v.isAtiva &&
        !vinculadaAoMotorista &&
        !vinculadaAoVeiculo) {
      return false;
    }

    if (veicViagem.isNotEmpty && veicAlvo.isNotEmpty && veicViagem != veicAlvo) {
      final outroEmUso = _veiculosMemoria.any(
        (vm) => vm.id == veicViagem && vm.emUso && vm.motoristaAtualId != motAlvo,
      );
      if (v.isPlanejada ||
          outroEmUso ||
          (sessaoViagem.isNotEmpty && !vinculadaAoMotorista)) {
        return false;
      }
    }

    if (placaViagem.isNotEmpty &&
        placaAlvo.isNotEmpty &&
        placaViagem != placaAlvo) {
      final outroEmUso = _veiculosMemoria.any(
        (vm) =>
            _normalizarPlacaInterna(vm.placa) == placaViagem &&
            vm.emUso &&
            vm.motoristaAtualId != motAlvo,
      );
      if (v.isPlanejada ||
          outroEmUso ||
          (sessaoViagem.isNotEmpty && !vinculadaAoMotorista)) {
        return false;
      }
    }

    if (cidadeDestino != null &&
        cidadeDestino.trim().isNotEmpty &&
        v.cidadeDestino.trim().isNotEmpty) {
      final rotaViagem = _normalizarTextoRota(v.cidadeDestino);
      final rotaAlvo = _normalizarTextoRota(cidadeDestino);
      final destinoCombina = rotaViagem == rotaAlvo ||
          (rotaViagem.length >= 3 && rotaAlvo.contains(rotaViagem)) ||
          (rotaAlvo.length >= 3 && rotaViagem.contains(rotaAlvo));
      if (!destinoCombina && !vinculadaAoMotorista && !vinculadaAoVeiculo) {
        return false;
      }
    }

    return true;
  }

  /// Retorna as viagens ativas filtradas especificamente para um motorista ou sessão.
  List<ViagemModel> obterViagensAtivasPorMotorista(
    String motoristaId, {
    String? veiculoId,
  }) {
    final sessaoMot = _sessoesAtivasPorMotorista[motoristaId];
    final vid = veiculoId ?? sessaoMot?.veiculoId ?? '';
    final sid = sessaoMot?.id ?? '';
    return _todasViagensMemoria.where((v) {
      if (v.isCancelada || v.isConcluida || todosPacientesVoltaram(v)) {
        return false;
      }
      if (sid.isNotEmpty && v.sessaoId == sid) return true;
      if (vid.isNotEmpty && v.veiculoId == vid && v.isAtiva) return true;
      if (motoristaId.isNotEmpty && v.motoristaId == motoristaId && v.isAtiva) {
        return true;
      }
      return false;
    }).toList();
  }

  ViagemModel _enriquecerViagemParaRelatorio(
    ViagemModel v, {
    ViagemModel? referenciaSessao,
  }) {
    final sessao = _sessaoAtiva;
    final conclSessao =
        _viagensConcluidasNaSessao.where((vc) => vc.id == v.id).firstOrNull;
    String primeiroNaoVazio(
      String a,
      String? b,
      String? c,
      String? d,
    ) {
      if (a.isNotEmpty) return a;
      if (b != null && b.isNotEmpty) return b;
      if (c != null && c.isNotEmpty) return c;
      return d ?? '';
    }

    final kmIni = v.kmInicial > 0
        ? v.kmInicial
        : ((conclSessao?.kmInicial ?? 0) > 0
              ? conclSessao!.kmInicial
              : ((sessao?.kmInicial ?? 0) > 0
                    ? sessao!.kmInicial
                    : (referenciaSessao?.kmInicial ?? 0)));

    return v.copyWith(
      veiculoId: primeiroNaoVazio(
        v.veiculoId,
        conclSessao?.veiculoId,
        sessao?.veiculoId,
        referenciaSessao?.veiculoId,
      ),
      veiculoPlaca: primeiroNaoVazio(
        v.veiculoPlaca,
        conclSessao?.veiculoPlaca,
        sessao?.veiculoPlaca,
        referenciaSessao?.veiculoPlaca,
      ),
      veiculoModelo: primeiroNaoVazio(
        v.veiculoModelo,
        conclSessao?.veiculoModelo,
        sessao?.veiculoModelo,
        referenciaSessao?.veiculoModelo,
      ),
      kmInicial: kmIni,
      motoristaNome: primeiroNaoVazio(
        v.motoristaNome,
        conclSessao?.motoristaNome,
        sessao?.motoristaNome,
        referenciaSessao?.motoristaNome,
      ),
      codigosAcesso: <String, String>{
        ...?conclSessao?.codigosAcesso,
        ...v.codigosAcesso,
      },
    );
  }

  /// Retorna as viagens reais operadas na sessão para geração do relatório PDF.
  List<ViagemModel> obterViagensParaRelatorio({
    List<ViagemModel>? viagensExplicitas,
    ViagemModel? viagemUnica,
  }) {
    final informadas = <ViagemModel>[
      ...?viagensExplicitas,
      ?viagemUnica,
      ..._viagensAtivasMemoria,
      ?_viagemAtiva,
    ];
    final refSessao = viagemUnica ?? _viagemAtiva ?? informadas.firstOrNull;
    final reais = <String, ViagemModel>{};
    for (final v in [..._viagensConcluidasNaSessao, ...informadas]) {
      if (v.id.isNotEmpty && !v.id.startsWith('sessao_ativa_')) {
        final emTodas =
            _todasViagensMemoria.where((tv) => tv.id == v.id).firstOrNull;
        reais[v.id] = _enriquecerViagemParaRelatorio(
          emTodas ?? v,
          referenciaSessao: refSessao,
        );
      }
    }
    if (reais.isNotEmpty) return reais.values.toList();

    final unicas = <String, ViagemModel>{};
    for (final v in informadas) {
      if (v.id.isNotEmpty) {
        unicas[v.id] = _enriquecerViagemParaRelatorio(
          v,
          referenciaSessao: refSessao,
        );
      }
    }
    return unicas.values.toList();
  }

  ViagemModel _criarPlaceholderSessaoAtiva(
    SessaoVeiculoModel sessao, {
    String cidadeDestino = '',
  }) {
    return ViagemModel(
      id: 'sessao_ativa_${sessao.veiculoId}',
      motoristaId: '',
      motoristaNome: '',
      veiculoId: sessao.veiculoId,
      veiculoPlaca: sessao.veiculoPlaca,
      veiculoModelo: sessao.veiculoModelo,
      kmInicial: sessao.kmInicial,
      cidadeDestino: cidadeDestino,
      dataHoraInicio: sessao.dataHoraInicio,
      status: 'ativa',
      sessaoId: sessao.id,
    );
  }

  /// Sincroniza a lista em memória com um snapshot de viagens vindo do Firestore.
  void sincronizarViagensRemotas(List<ViagemModel> viagensCarregadas) {
    final processadas = <ViagemModel>[];
    for (var v in viagensCarregadas) {
      if (v.id.startsWith('sessao_ativa_')) continue;
      if (_viagensComEscritaEmVoo.contains(v.id)) {
        final localEmVoo =
            _todasViagensMemoria.where((lv) => lv.id == v.id).firstOrNull;
        if (localEmVoo != null) {
          processadas.add(localEmVoo);
          continue;
        }
      }
      for (final pv in v.passageiros) {
        _sincronizarPassageiroEmMemoriaPorViagem(v.id, pv);
      }
      if (!v.isPlanejada &&
          !v.isCancelada &&
          !v.isConcluida &&
          v.passageiros.isNotEmpty &&
          v.passageiros.any((p) => p.statusEmbarque > 0) &&
          todosPacientesVoltaram(v)) {
        final codigosOriginais = Map<String, String>.from(v.codigosAcesso);
        v = v.copyWith(
          status: 'encerrada',
          dataHoraFim: v.dataHoraFim ?? DateTime.now(),
          codigosAcesso: const {},
        );
        if (_sessaoAtiva != null &&
            !_viagensConcluidasNaSessao.any((vc) => vc.id == v.id)) {
          _registrarViagemConcluidaParaRelatorio(
            v,
            codigosOriginais: codigosOriginais,
          );
        }
      }
      processadas.add(v);
    }

    _todasViagensMemoria
      ..clear()
      ..addAll(processadas);
    if (!_todasViagensController.isClosed) {
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    bool atualizouAtiva = false;
    for (int i = _viagensAtivasMemoria.length - 1; i >= 0; i--) {
      final atualMem = _viagensAtivasMemoria[i];
      if (atualMem.id.startsWith('sessao_ativa_')) continue;
      final vRemota =
          processadas.where((v) => v.id == atualMem.id).firstOrNull;
      if (vRemota == null) continue;

      if (vRemota.isCancelada ||
          vRemota.isConcluida ||
          todosPacientesVoltaram(vRemota)) {
        if (vRemota.isConcluida &&
            !_viagensConcluidasNaSessao.any((vc) => vc.id == vRemota.id)) {
          _registrarViagemConcluidaParaRelatorio(
            vRemota,
            codigosOriginais: {
              ...atualMem.codigosAcesso,
              ...vRemota.codigosAcesso,
            },
            referenciaSessao: atualMem,
          );
        }
        final idRemovido = atualMem.id;
        _viagensAtivasMemoria.removeAt(i);
        atualizouAtiva = true;
        if (_viagemAtiva?.id == idRemovido) {
          _selecionarProximaOuPlaceholder(cidadeFallback: vRemota.cidadeDestino);
        }
      } else {
        final pertenceSessaoAtual = _sessaoAtiva != null &&
            _viagemElegivelParaSessao(
              vRemota,
              motoristaId: _sessaoAtiva!.motoristaId,
              veiculoId: _sessaoAtiva!.veiculoId,
              veiculoPlaca: _sessaoAtiva!.veiculoPlaca,
              sessaoId: _sessaoAtiva!.id,
            );
        final vComVeiculo = pertenceSessaoAtual
            ? vRemota.copyWith(
                veiculoId: _sessaoAtiva!.veiculoId,
                veiculoPlaca: _sessaoAtiva!.veiculoPlaca,
                veiculoModelo: _sessaoAtiva!.veiculoModelo,
                kmInicial: _sessaoAtiva!.kmInicial,
                status: 'ativa',
              )
            : vRemota;
        _viagensAtivasMemoria[i] = vComVeiculo;
        atualizouAtiva = true;
        if (_viagemAtiva?.id == vRemota.id) {
          _viagemAtiva = vComVeiculo;
          if (!_viagemAtivaController.isClosed) {
            _viagemAtivaController.add(_viagemAtiva);
          }
        }
      }
    }

    if (_sessaoAtiva != null) {
      final destinoSessao = _viagemAtiva?.cidadeDestino ?? '';
      final novasAbertas = processadas.where(
        (v) =>
            _viagemElegivelParaSessao(
              v,
              motoristaId: _sessaoAtiva!.motoristaId,
              veiculoId: _sessaoAtiva!.veiculoId,
              veiculoPlaca: _sessaoAtiva!.veiculoPlaca,
              cidadeDestino: destinoSessao,
              sessaoId: _sessaoAtiva!.id,
            ) &&
            !_viagensAtivasMemoria.any((va) => va.id == v.id),
      );
      for (final na in novasAbertas) {
        _viagensAtivasMemoria
            .removeWhere((va) => va.id.startsWith('sessao_ativa_'));
        _viagensAtivasMemoria.add(
          na.copyWith(
            veiculoId: _sessaoAtiva!.veiculoId,
            veiculoPlaca: _sessaoAtiva!.veiculoPlaca,
            veiculoModelo: _sessaoAtiva!.veiculoModelo,
            kmInicial: _sessaoAtiva!.kmInicial,
            status: 'ativa',
            sessaoId: _sessaoAtiva!.id,
          ),
        );
        atualizouAtiva = true;
      }
      if (atualizouAtiva &&
          (_viagemAtiva == null ||
              _viagemAtiva!.id.startsWith('sessao_ativa_')) &&
          _viagensAtivasMemoria.isNotEmpty) {
        _viagemAtiva = _viagensAtivasMemoria.first;
        if (!_viagemAtivaController.isClosed) {
          _viagemAtivaController.add(_viagemAtiva);
        }
      }
    }

    if (atualizouAtiva && !_viagensAtivasController.isClosed) {
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
  }

  /// Restaura a sessão de veículo ativa ao reabrir a tela do motorista.
  void restaurarSessaoMotoristaSeAtiva({
    required String motoristaId,
    required String motoristaNome,
    List<VeiculoModel>? frota,
  }) {
    final idMotLimpo = motoristaId.trim();
    if (idMotLimpo.isEmpty) return;
    if (_sessaoAtiva != null &&
        _sessaoAtiva!.motoristaId.trim().isNotEmpty &&
        _sessaoAtiva!.motoristaId.trim() != idMotLimpo) {
      limparSessaoLocal();
    }
    if (_sessaoFinalizadaPeloMotorista) return;
    if (_sessaoAtiva != null &&
        _viagemAtiva != null &&
        _viagemAtiva!.isAtiva &&
        !_viagemAtiva!.id.startsWith('sessao_ativa_')) {
      return;
    }

    final listaVeiculos =
        (frota != null && frota.isNotEmpty) ? frota : _veiculosMemoria;
    VeiculoModel? veiculoEmUso = listaVeiculos.where((v) {
      if (!v.emUso) return false;
      final motVeiculo = v.motoristaAtualId?.trim() ?? '';
      return motVeiculo.isNotEmpty && motVeiculo == idMotLimpo;
    }).firstOrNull;

    ViagemModel? viagemDoMotorista;
    if (veiculoEmUso == null) {
      viagemDoMotorista = _todasViagensMemoria.where((v) {
        if (v.isCancelada || v.isConcluida || todosPacientesVoltaram(v)) {
          return false;
        }
        final mot = v.motoristaId.trim();
        final motNome = v.motoristaNome.trim().toLowerCase();
        final motNomeAlvo = motoristaNome.trim().toLowerCase();
        final vinculadoAoMotorista = (mot.isNotEmpty &&
                (mot == idMotLimpo || mot == 'motorista_atual')) ||
            (motNomeAlvo.isNotEmpty &&
                motNome.isNotEmpty &&
                motNome == motNomeAlvo);
        if (!vinculadoAoMotorista) return false;

        if (v.veiculoId.isNotEmpty) {
          final veicOcupadoPorOutro = listaVeiculos.any(
            (vm) =>
                vm.id == v.veiculoId &&
                vm.emUso &&
                (vm.motoristaAtualId?.trim() ?? '').isNotEmpty &&
                vm.motoristaAtualId!.trim() != idMotLimpo,
          );
          if (veicOcupadoPorOutro) return false;
        }
        return true;
      }).firstOrNull;

      if (viagemDoMotorista != null) {
        veiculoEmUso = listaVeiculos.where((v) {
              if (v.emUso &&
                  (v.motoristaAtualId?.trim() ?? '').isNotEmpty &&
                  v.motoristaAtualId!.trim() != idMotLimpo) {
                return false;
              }
              return (viagemDoMotorista!.veiculoId.isNotEmpty &&
                      v.id == viagemDoMotorista.veiculoId) ||
                  (viagemDoMotorista.veiculoPlaca.isNotEmpty &&
                      _normalizarPlacaInterna(v.placa) ==
                          _normalizarPlacaInterna(
                            viagemDoMotorista.veiculoPlaca,
                          ));
            }).firstOrNull ??
            VeiculoModel(
              id: viagemDoMotorista.veiculoId.isNotEmpty
                  ? viagemDoMotorista.veiculoId
                  : 'veiculo_${viagemDoMotorista.id}',
              placa: viagemDoMotorista.veiculoPlaca.isNotEmpty
                  ? viagemDoMotorista.veiculoPlaca
                  : 'TFD',
              modelo: viagemDoMotorista.veiculoModelo.isNotEmpty
                  ? viagemDoMotorista.veiculoModelo
                  : 'Veículo Municipal',
              quilometragemAtual: viagemDoMotorista.kmInicial,
              emUso: true,
              motoristaAtualId: idMotLimpo,
            );
      }
    } else {
      viagemDoMotorista = _todasViagensMemoria.where((v) {
        if (v.isCancelada || v.isConcluida || todosPacientesVoltaram(v)) {
          return false;
        }
        final motViagem = v.motoristaId.trim();
        if (motViagem.isNotEmpty &&
            motViagem != idMotLimpo &&
            motViagem != 'motorista_atual') {
          return false;
        }
        final vinculadoAoMotorista =
            (motViagem.isNotEmpty &&
                (motViagem == idMotLimpo || motViagem == 'motorista_atual')) ||
            (motoristaNome.trim().isNotEmpty &&
                v.motoristaNome.trim().toLowerCase() ==
                    motoristaNome.trim().toLowerCase());
        final vinculadoAoVeiculo =
            (v.veiculoId.isNotEmpty && v.veiculoId == veiculoEmUso!.id) ||
            (v.veiculoPlaca.isNotEmpty &&
                _normalizarPlacaInterna(v.veiculoPlaca) ==
                    _normalizarPlacaInterna(veiculoEmUso!.placa));
        return vinculadoAoMotorista || vinculadoAoVeiculo;
      }).firstOrNull;
    }

    if (veiculoEmUso == null) return;

    final sessaoIdRestaurada = (viagemDoMotorista?.sessaoId != null &&
            viagemDoMotorista!.sessaoId!.isNotEmpty)
        ? viagemDoMotorista.sessaoId!
        : 'sessao_${veiculoEmUso.id}';

    _sessaoAtiva ??= SessaoVeiculoModel(
      id: sessaoIdRestaurada,
      motoristaId: idMotLimpo,
      motoristaNome: motoristaNome,
      veiculoId: veiculoEmUso.id,
      veiculoPlaca: veiculoEmUso.placa,
      veiculoModelo: veiculoEmUso.modelo,
      kmInicial: veiculoEmUso.quilometragemAtual,
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
    );
    _sessoesAtivasPorMotorista[idMotLimpo] = _sessaoAtiva!;
    if (!_sessaoAtivaController.isClosed) {
      _sessaoAtivaController.add(_sessaoAtiva);
    }

    _viagensAtivasMemoria
        .removeWhere((va) => va.id.startsWith('sessao_ativa_'));
    for (final base in _todasViagensMemoria) {
      if (!_viagemElegivelParaSessao(
        base,
        motoristaId: idMotLimpo,
        veiculoId: veiculoEmUso.id,
        veiculoPlaca: veiculoEmUso.placa,
        sessaoId: _sessaoAtiva!.id,
      )) {
        continue;
      }

      final vAtivada = base.copyWith(
        motoristaId:
            base.motoristaId.isNotEmpty ? base.motoristaId : idMotLimpo,
        motoristaNome:
            base.motoristaNome.isNotEmpty ? base.motoristaNome : motoristaNome,
        veiculoId: veiculoEmUso.id,
        veiculoPlaca: veiculoEmUso.placa,
        veiculoModelo: veiculoEmUso.modelo,
        kmInicial: veiculoEmUso.quilometragemAtual,
        status: 'ativa',
        sessaoId: _sessaoAtiva!.id,
      );
      if (!_viagensAtivasMemoria.any((va) => va.id == vAtivada.id)) {
        _viagensAtivasMemoria.add(vAtivada);
      }
    }

    if (_viagensAtivasMemoria.isEmpty) {
      if (viagemDoMotorista != null) {
        _viagensAtivasMemoria.add(
          viagemDoMotorista.copyWith(
            motoristaId: viagemDoMotorista.motoristaId.isNotEmpty
                ? viagemDoMotorista.motoristaId
                : idMotLimpo,
            motoristaNome: viagemDoMotorista.motoristaNome.isNotEmpty
                ? viagemDoMotorista.motoristaNome
                : motoristaNome,
            status: 'ativa',
            sessaoId: _sessaoAtiva!.id,
          ),
        );
      } else {
        _viagensAtivasMemoria.add(_criarPlaceholderSessaoAtiva(_sessaoAtiva!));
      }
    }

    _viagemAtiva = _viagensAtivasMemoria.first;
    if (!_viagemAtivaController.isClosed) {
      _viagemAtivaController.add(_viagemAtiva);
    }
    if (!_viagensAtivasController.isClosed) {
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
  }

  // ===========================================================================
  // SEÇÃO: Códigos de Acesso de Pacientes
  // ===========================================================================

  (Map<String, String>, Map<String, String>, bool) _sincronizarCodigosDaViagem({
    required String viagemId,
    required List<PassageiroViagemModel> passageiros,
    required List<String> passageirosIds,
    required Map<String, String> codigosExistentes,
    required Map<String, String> hashesExistentes,
  }) {
    final mapaCodigos = Map<String, String>.from(codigosExistentes);
    final mapaHashes = Map<String, String>.from(hashesExistentes);
    bool alterou = false;

    final idsPacientes = <String>{
      ...passageiros
          .map((p) => p.pacienteId)
          .where((id) => id.trim().isNotEmpty),
      ...passageirosIds.where((id) => id.trim().isNotEmpty),
      ...mapaCodigos.keys.where((id) => id.trim().isNotEmpty),
    };

    for (final pid in idsPacientes) {
      final codigoAtual = mapaCodigos[pid]?.trim() ?? '';
      if (codigoAtual.isEmpty) {
        final novoCodigo =
            CodigoAcessoService.gerarCodigoUnicoNaViagem(mapaCodigos.values);
        mapaCodigos[pid] = novoCodigo;
        mapaHashes[pid] = CodigoAcessoService.calcularHash(novoCodigo, viagemId);
        alterou = true;
      } else {
        final hashEsperado =
            CodigoAcessoService.calcularHash(codigoAtual, viagemId);
        if (mapaHashes[pid] != hashEsperado) {
          mapaHashes[pid] = hashEsperado;
          alterou = true;
        }
      }
    }

    return (mapaCodigos, mapaHashes, alterou);
  }

  /// Gera ou recupera código numérico único (4–5 dígitos) e hash SHA-256 para o paciente.
  Future<String> gerarOuObterCodigoAcesso({
    required String viagemId,
    required String pacienteId,
  }) async {
    final viagemIndex =
        _viagensAtivasMemoria.indexWhere((v) => v.id == viagemId);
    final todasIndex = _todasViagensMemoria.indexWhere((v) => v.id == viagemId);
    final ViagemModel? viagem = viagemIndex != -1
        ? _viagensAtivasMemoria[viagemIndex]
        : (todasIndex != -1
              ? _todasViagensMemoria[todasIndex]
              : (_viagemAtiva?.id == viagemId ? _viagemAtiva : null));

    void propagarEmMemoria(ViagemModel atualizada) {
      if (viagemIndex != -1) {
        _viagensAtivasMemoria[viagemIndex] = atualizada;
        _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      }
      if (todasIndex != -1) {
        _todasViagensMemoria[todasIndex] = atualizada;
        _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
      }
      if (_viagemAtiva?.id == viagemId) {
        _viagemAtiva = atualizada;
        _viagemAtivaController.add(_viagemAtiva);
      }
    }

    if (viagem != null &&
        viagem.codigosAcesso.containsKey(pacienteId) &&
        viagem.codigosAcesso[pacienteId]!.trim().isNotEmpty) {
      final codigoExistente = viagem.codigosAcesso[pacienteId]!.trim();
      final hashEsperado =
          CodigoAcessoService.calcularHash(codigoExistente, viagemId);
      if (viagem.codigosHash[pacienteId] != hashEsperado) {
        final mapaHashes = Map<String, String>.from(viagem.codigosHash)
          ..[pacienteId] = hashEsperado;
        propagarEmMemoria(viagem.copyWith(codigosHash: mapaHashes));
        if (_isFirebaseDisponivel()) {
          unawaited(
            FirebaseFirestore.instance
                .collection('viagens')
                .doc(viagemId)
                .set({
                  'codigosAcesso': {pacienteId: codigoExistente},
                  'codigosHash': {pacienteId: hashEsperado},
                }, SetOptions(merge: true))
                .catchError((Object e) {
                  _tratarFalhaFirestore('sincronizar_hash_codigo_acesso', e);
                }),
          );
        }
      }
      return codigoExistente;
    }

    final codigosExistentes =
        viagem?.codigosAcesso.values ?? const <String>[];
    final novoCodigo =
        CodigoAcessoService.gerarCodigoUnicoNaViagem(codigosExistentes);
    final novoHash = CodigoAcessoService.calcularHash(novoCodigo, viagemId);

    if (viagem != null) {
      final mapaCodigos = Map<String, String>.from(viagem.codigosAcesso)
        ..[pacienteId] = novoCodigo;
      final mapaHashes = Map<String, String>.from(viagem.codigosHash)
        ..[pacienteId] = novoHash;
      propagarEmMemoria(
        viagem.copyWith(codigosAcesso: mapaCodigos, codigosHash: mapaHashes),
      );
    }

    if (_isFirebaseDisponivel()) {
      _totalGravacoesFirestoreJornada++;
      unawaited(
        FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagemId)
            .set({
              'codigosAcesso': {pacienteId: novoCodigo},
              'codigosHash': {pacienteId: novoHash},
            }, SetOptions(merge: true))
            .catchError((Object e) {
              _tratarFalhaFirestore('gerar_codigo_acesso', e);
            }),
      );
    }

    return novoCodigo;
  }

  // ===========================================================================
  // SEÇÃO: Ciclo de Vida do Motorista (Declaração, Início, Atualização e Fim)
  // ===========================================================================

  /// Registra veículo e KM inicial pelo motorista, abrindo a Sessão de Veículo.
  Future<ResultadoDeclaracaoVeiculo> declararVeiculo({
    required VeiculoModel veiculo,
    required int kmInicial,
    required String motoristaId,
    required String motoristaNome,
    String? cidadeDestino,
  }) async {
    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: kmInicial.toString(),
      ultimaKmRegistrada: veiculo.quilometragemAtual,
    );
    if (!validacaoKm.valido) {
      return ResultadoDeclaracaoVeiculo.erro(validacaoKm.mensagemErro!);
    }

    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculo.id);
    VeiculoModel? veiculoSnapshotAnterior;
    if (index != -1) {
      final veicMem = _veiculosMemoria[index];
      if (veicMem.emUso &&
          veicMem.motoristaAtualId != null &&
          veicMem.motoristaAtualId != motoristaId) {
        return ResultadoDeclaracaoVeiculo.erro(
          'O veículo ${veiculo.placa} já está em uso por outro motorista.',
        );
      }
      veiculoSnapshotAnterior = veicMem;
      _veiculosMemoria[index] = veicMem.copyWith(
        emUso: true,
        motoristaAtualId: motoristaId,
        quilometragemAtual: kmInicial,
      );
    }

    final sessaoAnterior = _sessaoAtiva;
    final viagemAtivaAnterior = _viagemAtiva;
    final viagensAtivasAnteriores = List<ViagemModel>.from(_viagensAtivasMemoria);
    final todasViagensAnteriores = List<ViagemModel>.from(_todasViagensMemoria);

    final novaSessao = SessaoVeiculoModel(
      id: 'sessao_${DateTime.now().millisecondsSinceEpoch}_${motoristaId.isNotEmpty ? motoristaId : veiculo.id}',
      motoristaId: motoristaId,
      motoristaNome: motoristaNome,
      veiculoId: veiculo.id,
      veiculoPlaca: veiculo.placa,
      veiculoModelo: veiculo.modelo,
      kmInicial: kmInicial,
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
    );

    _sessaoFinalizadaPeloMotorista = false;
    _sessaoAtiva = novaSessao;
    if (motoristaId.isNotEmpty) {
      _sessoesAtivasPorMotorista[motoristaId] = novaSessao;
    }
    _sessaoAtivaController.add(_sessaoAtiva);
    _veiculosController
        .add(ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria));

    _viagensConcluidasNaSessao.clear();
    _viagensAtivasMemoria
        .removeWhere((va) => va.id.startsWith('sessao_ativa_'));

    final viagensAbertas = _todasViagensMemoria.where(
      (v) => _viagemElegivelParaSessao(
        v,
        motoristaId: motoristaId,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        cidadeDestino: cidadeDestino,
        sessaoId: novaSessao.id,
      ),
    );

    final viagensIdsSessao = <String>[];
    final viagensAtivadasParaPersistir = <ViagemModel>[];
    for (final v in viagensAbertas) {
      final (codigosSinc, hashesSinc, _) = _sincronizarCodigosDaViagem(
        viagemId: v.id,
        passageiros: v.passageiros,
        passageirosIds: v.passageirosIds,
        codigosExistentes: v.codigosAcesso,
        hashesExistentes: v.codigosHash,
      );
      final vAtivada = v.copyWith(
        sessaoId: novaSessao.id,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        veiculoModelo: veiculo.modelo,
        kmInicial: kmInicial,
        status: 'ativa',
        codigosAcesso: codigosSinc,
        codigosHash: hashesSinc,
      );
      final idxAtiva = _viagensAtivasMemoria.indexWhere((va) => va.id == v.id);
      if (idxAtiva == -1) {
        _viagensAtivasMemoria.add(vAtivada);
      } else {
        _viagensAtivasMemoria[idxAtiva] = vAtivada;
      }
      for (final pv in vAtivada.passageiros) {
        if (PacienteSyncService().obterPacienteMemoria(
              pv.pacienteId,
              viagemId: vAtivada.id,
            ) ==
            null) {
          _sincronizarPassageiroEmMemoriaPorViagem(vAtivada.id, pv);
        }
      }
      viagensAtivadasParaPersistir.add(vAtivada);
      viagensIdsSessao.add(vAtivada.id);
      final idx = _todasViagensMemoria.indexWhere((tv) => tv.id == v.id);
      if (idx != -1) _todasViagensMemoria[idx] = vAtivada;
    }

    if (viagensIdsSessao.isNotEmpty) {
      _sessaoAtiva = _sessaoAtiva!.copyWith(viagensIds: viagensIdsSessao);
      if (motoristaId.isNotEmpty) {
        _sessoesAtivasPorMotorista[motoristaId] = _sessaoAtiva!;
      }
      _sessaoAtivaController.add(_sessaoAtiva);
    }

    final viagensDestaSessao = _viagensAtivasMemoria
        .where((va) => va.sessaoId == novaSessao.id || va.veiculoId == veiculo.id)
        .toList();
    if (viagensDestaSessao.isNotEmpty) {
      _viagemAtiva = viagensDestaSessao.first;
      _emitirStreamsViagens();
    }

    if (executorPersistenciaRemotaOverride != null || _isFirebaseDisponivel()) {
      final sessaoParaPersistir = _sessaoAtiva!;
      void rollback() => _restaurarSnapshotSessao(
            indiceVeiculo: index,
            veiculoAnterior: veiculoSnapshotAnterior,
            motoristaId: motoristaId,
            sessaoAnterior: sessaoAnterior,
            viagemAtivaAnterior: viagemAtivaAnterior,
            viagensAtivasAnteriores: viagensAtivasAnteriores,
            todasViagensAnteriores: todasViagensAnteriores,
          );

      unawaited(
        Future.microtask(() async {
          try {
            if (executorPersistenciaRemotaOverride != null) {
              await executorPersistenciaRemotaOverride!(
                'declarar_veiculo',
                sessaoParaPersistir.toMap(),
              );
              _totalGravacoesFirestoreJornada +=
                  2 + viagensAtivadasParaPersistir.length;
              return;
            }
            await FirebaseFirestore.instance.runTransaction(
              (tx) => _aplicarOcupacaoVeiculoNaTransacao(
                tx,
                veiculo: veiculo,
                kmInicial: kmInicial,
                motoristaId: motoristaId,
                mensagemConflito:
                    'O veículo ${veiculo.placa} foi colocado em uso por outro motorista.',
              ),
            );
            _totalGravacoesFirestoreJornada += 2;

            await FirebaseFirestore.instance
                .collection('sessoes_veiculo')
                .doc(novaSessao.id)
                .set(sessaoParaPersistir.toMap());
            _totalGravacoesFirestoreJornada++;

            for (final va in viagensAtivadasParaPersistir) {
              await FirebaseFirestore.instance
                  .collection('viagens')
                  .doc(va.id)
                  .set(va.toMap(), SetOptions(merge: true));
              _totalGravacoesFirestoreJornada++;
            }
          } catch (e) {
            _tratarFalhaFirestore('declarar_veiculo', e, onRollback: rollback);
          }
        }),
      );
    }

    return ResultadoDeclaracaoVeiculo.sucesso(_sessaoAtiva!);
  }

  /// Adiciona uma nova viagem ativa à sessão de veículo do motorista.
  Future<ResultadoInicioViagem> criarOuAdicionarViagemNaSessao({
    required String cidadeDestino,
    List<String> passageirosIds = const [],
    String? idCustomizado,
  }) async {
    if (_sessaoAtiva == null) {
      return ResultadoInicioViagem.erro(
        'Nenhuma sessão de veículo ativa. Declare o veículo antes de criar viagens.',
      );
    }

    final validacaoCidade = ValidacaoViagem.validarCidade(cidadeDestino);
    if (!validacaoCidade.valido) {
      return ResultadoInicioViagem.erro(validacaoCidade.mensagemErro!);
    }

    final sessao = _sessaoAtiva!;
    final novaViagem = ViagemModel(
      id: idCustomizado ??
          'viagem_${DateTime.now().millisecondsSinceEpoch}_${_viagensAtivasMemoria.length + 1}',
      motoristaId: sessao.motoristaId,
      motoristaNome: sessao.motoristaNome,
      veiculoId: sessao.veiculoId,
      veiculoPlaca: sessao.veiculoPlaca,
      veiculoModelo: sessao.veiculoModelo,
      kmInicial: sessao.kmInicial,
      cidadeDestino: cidadeDestino,
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
      passageirosIds: passageirosIds,
      sessaoId: sessao.id,
    );

    _viagensAtivasMemoria.add(novaViagem);
    _todasViagensMemoria.add(novaViagem);
    _viagemAtiva = novaViagem;
    _emitirStreamsViagens();

    _sessaoAtiva = _sessaoAtiva!.copyWith(
      viagensIds: [..._sessaoAtiva!.viagensIds, novaViagem.id],
    );
    _sessaoAtivaController.add(_sessaoAtiva);

    if (executorPersistenciaRemotaOverride != null || _isFirebaseDisponivel()) {
      final idsAtualizados = List<String>.from(_sessaoAtiva!.viagensIds);
      unawaited(
        Future.microtask(() async {
          try {
            if (executorPersistenciaRemotaOverride != null) {
              await executorPersistenciaRemotaOverride!(
                'criar_viagem_sessao',
                novaViagem.toMap(),
              );
              _totalGravacoesFirestoreJornada += 2;
              return;
            }
            await FirebaseFirestore.instance
                .collection('viagens')
                .doc(novaViagem.id)
                .set(novaViagem.toMap());
            _totalGravacoesFirestoreJornada++;

            await FirebaseFirestore.instance
                .collection('sessoes_veiculo')
                .doc(sessao.id)
                .set({'viagensIds': idsAtualizados}, SetOptions(merge: true));
            _totalGravacoesFirestoreJornada++;
          } on FirebaseException catch (e) {
            _tratarFalhaFirestore(
              'criar_viagem_sessao',
              e,
              onRollback: () {
                _viagensAtivasMemoria.removeWhere((v) => v.id == novaViagem.id);
                _todasViagensMemoria.removeWhere((v) => v.id == novaViagem.id);
                if (_viagemAtiva?.id == novaViagem.id) {
                  _viagemAtiva = _viagensAtivasMemoria.firstOrNull;
                }
                _emitirStreamsViagens();
              },
            );
          } catch (e) {
            _tratarFalhaFirestore('criar_viagem_sessao', e);
          }
        }),
      );
    }

    return ResultadoInicioViagem.sucesso(novaViagem);
  }

  /// Valida odômetro/cidade, reserva o veículo via transação ACID e ativa as viagens elegíveis.
  Future<ResultadoInicioViagem> iniciarViagem({
    required VeiculoModel veiculo,
    required int kmInicial,
    required String cidadeDestino,
    required String motoristaId,
    required String motoristaNome,
  }) async {
    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: kmInicial.toString(),
      ultimaKmRegistrada: veiculo.quilometragemAtual,
    );
    if (!validacaoKm.valido) {
      return ResultadoInicioViagem.erro(validacaoKm.mensagemErro!);
    }

    final validacaoCidade = ValidacaoViagem.validarCidade(cidadeDestino);
    if (!validacaoCidade.valido) {
      return ResultadoInicioViagem.erro(validacaoCidade.mensagemErro!);
    }

    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculo.id);
    VeiculoModel? veiculoSnapshotAnterior;
    if (index != -1) {
      final veicMem = _veiculosMemoria[index];
      if (veicMem.emUso &&
          veicMem.motoristaAtualId != null &&
          veicMem.motoristaAtualId != motoristaId) {
        return ResultadoInicioViagem.erro(
          'O veículo ${veiculo.placa} já está em uso por outro motorista.',
        );
      }
      veiculoSnapshotAnterior = veicMem;
      _veiculosMemoria[index] = veicMem.copyWith(
        emUso: true,
        motoristaAtualId: motoristaId,
        quilometragemAtual: kmInicial,
      );
    }

    final sessaoAnterior = _sessaoAtiva;
    final viagemAtivaAnterior = _viagemAtiva;
    final viagensAtivasAnteriores = List<ViagemModel>.from(_viagensAtivasMemoria);
    final todasViagensAnteriores = List<ViagemModel>.from(_todasViagensMemoria);

    _sessaoFinalizadaPeloMotorista = false;
    if (_sessaoAtiva == null ||
        _sessaoAtiva!.veiculoId != veiculo.id ||
        (_sessaoAtiva!.motoristaId.trim().isNotEmpty &&
            motoristaId.trim().isNotEmpty &&
            _sessaoAtiva!.motoristaId.trim() != motoristaId.trim())) {
      _sessaoAtiva = SessaoVeiculoModel(
        id: 'sessao_${DateTime.now().millisecondsSinceEpoch}_${motoristaId.isNotEmpty ? motoristaId : veiculo.id}',
        motoristaId: motoristaId,
        motoristaNome: motoristaNome,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        veiculoModelo: veiculo.modelo,
        kmInicial: kmInicial,
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
      );
      _sessaoAtivaController.add(_sessaoAtiva);
    }
    final sessaoCorrente = _sessaoAtiva!;
    if (motoristaId.isNotEmpty) {
      _sessoesAtivasPorMotorista[motoristaId] = sessaoCorrente;
    }

    _viagensConcluidasNaSessao.clear();
    _viagensAtivasMemoria.removeWhere(
      (va) =>
          va.id.startsWith('sessao_ativa_') ||
          va.isCancelada ||
          va.isConcluida ||
          todosPacientesVoltaram(va),
    );

    final viagensExistentesParaPersistir = <ViagemModel>[];
    for (int i = 0; i < _todasViagensMemoria.length; i++) {
      final base = _todasViagensMemoria[i];
      if (!_viagemElegivelParaSessao(
        base,
        motoristaId: motoristaId,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        cidadeDestino: cidadeDestino,
        sessaoId: sessaoCorrente.id,
      )) {
        continue;
      }

      final (codigosSinc, hashesSinc, _) = _sincronizarCodigosDaViagem(
        viagemId: base.id,
        passageiros: base.passageiros,
        passageirosIds: base.passageirosIds,
        codigosExistentes: base.codigosAcesso,
        hashesExistentes: base.codigosHash,
      );
      final vAtivada = base.copyWith(
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        veiculoModelo: veiculo.modelo,
        kmInicial: kmInicial,
        status: 'ativa',
        sessaoId: sessaoCorrente.id,
        codigosAcesso: codigosSinc,
        codigosHash: hashesSinc,
      );
      _todasViagensMemoria[i] = vAtivada;
      viagensExistentesParaPersistir.add(vAtivada);
      for (final pv in vAtivada.passageiros) {
        if (PacienteSyncService().obterPacienteMemoria(
              pv.pacienteId,
              viagemId: vAtivada.id,
            ) ==
            null) {
          _sincronizarPassageiroEmMemoriaPorViagem(vAtivada.id, pv);
        }
      }

      final idxAtiva =
          _viagensAtivasMemoria.indexWhere((va) => va.id == vAtivada.id);
      if (idxAtiva != -1) {
        _viagensAtivasMemoria[idxAtiva] = vAtivada;
      } else {
        _viagensAtivasMemoria.add(vAtivada);
      }
    }

    final viagensDestaSessao = _viagensAtivasMemoria
        .where((va) => va.sessaoId == sessaoCorrente.id || va.veiculoId == veiculo.id)
        .toList();

    final ViagemModel novaViagem;
    if (viagensDestaSessao.isNotEmpty) {
      novaViagem = viagensDestaSessao.first;
    } else {
      // Placeholder local de sessão quando o admin ainda não cadastrou viagens na rota.
      novaViagem = _criarPlaceholderSessaoAtiva(
        sessaoCorrente,
        cidadeDestino: cidadeDestino,
      );
      _viagensAtivasMemoria.add(novaViagem);
    }

    _viagemAtiva = novaViagem;
    _emitirStreamsViagens();
    _veiculosController
        .add(ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria));

    if (executorPersistenciaRemotaOverride != null || _isFirebaseDisponivel()) {
      void rollback() => _restaurarSnapshotSessao(
            indiceVeiculo: index,
            veiculoAnterior: veiculoSnapshotAnterior,
            motoristaId: motoristaId,
            sessaoAnterior: sessaoAnterior,
            viagemAtivaAnterior: viagemAtivaAnterior,
            viagensAtivasAnteriores: viagensAtivasAnteriores,
            todasViagensAnteriores: todasViagensAnteriores,
          );

      unawaited(
        Future.microtask(() async {
          try {
            if (executorPersistenciaRemotaOverride != null) {
              await executorPersistenciaRemotaOverride!(
                'iniciar_viagem',
                novaViagem.toMap(),
              );
              _totalGravacoesFirestoreJornada +=
                  1 + viagensExistentesParaPersistir.length;
              return;
            }
            await FirebaseFirestore.instance.runTransaction(
              (tx) => _aplicarOcupacaoVeiculoNaTransacao(
                tx,
                veiculo: veiculo,
                kmInicial: kmInicial,
                motoristaId: motoristaId,
                mensagemConflito:
                    'O veículo ${veiculo.placa} foi colocado em uso por outro motorista. Escolha outro veículo.',
              ),
            );
            _totalGravacoesFirestoreJornada += 2;

            for (final vp in viagensExistentesParaPersistir) {
              await FirebaseFirestore.instance
                  .collection('viagens')
                  .doc(vp.id)
                  .set(vp.toMap(), SetOptions(merge: true));
              _totalGravacoesFirestoreJornada++;
            }
          } catch (e) {
            _tratarFalhaFirestore('iniciar_viagem', e, onRollback: rollback);
          }
        }),
      );
    }

    return ResultadoInicioViagem.sucesso(novaViagem);
  }

  /// Atualiza o status de um passageiro dentro de uma viagem específica.
  /// Quando todos os pacientes não cancelados da viagem atingem status == 4,
  /// a viagem passa atomicamente para 'encerrada' e invalida os códigos de acesso.
  Future<void> atualizarStatusPassageiroNaViagem({
    required String viagemId,
    required String pacienteId,
    required int novoStatus,
    bool? prontoRetorno,
    JanelaReversaoModel? janelaReversao,
    bool limparJanelaReversao = false,
    bool persistirRemoto = true,
  }) async {
    if (pacienteId.isEmpty) return;

    final todasViagensSnapshot = List<ViagemModel>.from(_todasViagensMemoria);
    final viagensAtivasSnapshot = List<ViagemModel>.from(_viagensAtivasMemoria);
    final viagemAtivaSnapshot = _viagemAtiva;
    final hasExplicitViagem = viagemId.trim().isNotEmpty;

    final viagensParaPersistir = <ViagemModel>[];
    bool alterouTodas = false;
    for (int i = 0; i < _todasViagensMemoria.length; i++) {
      final v = _todasViagensMemoria[i];
      final corresponde = hasExplicitViagem
          ? v.id == viagemId
          : (!v.isCancelada &&
                !v.isConcluida &&
                (v.passageiros.any((p) => p.pacienteId == pacienteId) ||
                    v.passageirosIds.contains(pacienteId)));
      if (!corresponde) continue;

      final codigosAntes = Map<String, String>.from(v.codigosAcesso);
      final att = _aplicarAtualizacaoPassageiroNoModelo(
        v,
        pacienteId: pacienteId,
        novoStatus: novoStatus,
        prontoRetorno: prontoRetorno,
        janelaReversao: janelaReversao,
        limparJanelaReversao: limparJanelaReversao,
      );
      if (att == null) continue;

      if (att.isConcluida &&
          _sessaoAtiva != null &&
          !_viagensConcluidasNaSessao.any((vc) => vc.id == att.id)) {
        _registrarViagemConcluidaParaRelatorio(
          att,
          codigosOriginais: codigosAntes,
          referenciaSessao: v,
        );
      }
      _todasViagensMemoria[i] = att;
      viagensParaPersistir.add(att);
      alterouTodas = true;
    }
    if (alterouTodas) {
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    bool alterouAtivas = false;
    for (int i = _viagensAtivasMemoria.length - 1; i >= 0; i--) {
      final v = _viagensAtivasMemoria[i];
      final corresponde = hasExplicitViagem
          ? v.id == viagemId
          : (v.passageiros.any((p) => p.pacienteId == pacienteId) ||
                v.passageirosIds.contains(pacienteId));
      if (!corresponde) continue;

      final codigosAntes = Map<String, String>.from(v.codigosAcesso);
      final att = _aplicarAtualizacaoPassageiroNoModelo(
        v,
        pacienteId: pacienteId,
        novoStatus: novoStatus,
        prontoRetorno: prontoRetorno,
        janelaReversao: janelaReversao,
        limparJanelaReversao: limparJanelaReversao,
      );
      if (att == null) continue;

      if (att.isConcluida) {
        _registrarViagemConcluidaParaRelatorio(
          att,
          codigosOriginais: codigosAntes,
          referenciaSessao: v,
        );
        _viagensAtivasMemoria.removeAt(i);
      } else {
        _viagensAtivasMemoria[i] = att;
      }
      alterouAtivas = true;
      if (!viagensParaPersistir.any((vp) => vp.id == att.id)) {
        viagensParaPersistir.add(att);
      }
    }

    final correspondeViagemAtiva = _viagemAtiva != null &&
        (hasExplicitViagem
            ? _viagemAtiva!.id == viagemId
            : (_viagemAtiva!.passageiros.any((p) => p.pacienteId == pacienteId) ||
                  _viagemAtiva!.passageirosIds.contains(pacienteId)));

    if (correspondeViagemAtiva) {
      final vAntes = _viagemAtiva!;
      final codigosAntes = Map<String, String>.from(vAntes.codigosAcesso);
      final att = _aplicarAtualizacaoPassageiroNoModelo(
        vAntes,
        pacienteId: pacienteId,
        novoStatus: novoStatus,
        prontoRetorno: prontoRetorno,
        janelaReversao: janelaReversao,
        limparJanelaReversao: limparJanelaReversao,
      );
      if (att != null) {
        if (att.isConcluida) {
          _registrarViagemConcluidaParaRelatorio(
            att,
            codigosOriginais: codigosAntes,
            referenciaSessao: vAntes,
          );
          if (_selecionarProximaOuPlaceholder(cidadeFallback: att.cidadeDestino)) {
            alterouAtivas = true;
          }
        } else {
          _viagemAtiva = att;
        }
        _viagemAtivaController.add(_viagemAtiva);
        if (!viagensParaPersistir.any((vp) => vp.id == att.id)) {
          viagensParaPersistir.add(att);
        }
      }
    } else if (alterouAtivas &&
        _viagemAtiva != null &&
        !_viagensAtivasMemoria.any((va) => va.id == _viagemAtiva!.id)) {
      _selecionarProximaOuPlaceholder();
      _viagemAtivaController.add(_viagemAtiva);
    }

    if (alterouAtivas) {
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }

    void reverterStatusPassageiro() {
      _todasViagensMemoria
        ..clear()
        ..addAll(todasViagensSnapshot);
      _viagensAtivasMemoria
        ..clear()
        ..addAll(viagensAtivasSnapshot);
      _viagemAtiva = viagemAtivaSnapshot;
      for (final vp in viagensParaPersistir) {
        final vOrig =
            todasViagensSnapshot.where((tv) => tv.id == vp.id).firstOrNull ??
            viagensAtivasSnapshot.where((va) => va.id == vp.id).firstOrNull;
        final pOrig = vOrig?.passageiros
            .where((p) => p.pacienteId == pacienteId)
            .firstOrNull;
        if (vOrig != null && pOrig != null) {
          _sincronizarPassageiroEmMemoriaPorViagem(vOrig.id, pOrig);
        }
      }
      _emitirStreamsViagens();
    }

    if (persistirRemoto &&
        viagensParaPersistir.isNotEmpty &&
        (executorPersistenciaRemotaOverride != null || _isFirebaseDisponivel())) {
      final idsEmVoo = viagensParaPersistir
          .map((vp) => vp.id)
          .where((id) => !id.startsWith('sessao_ativa_'))
          .toList();
      _viagensComEscritaEmVoo.addAll(idsEmVoo);
      unawaited(
        _persistirStatusPassageiroNoFirestore(
          viagensParaPersistir: viagensParaPersistir,
          pacienteId: pacienteId,
          idsEmVoo: idsEmVoo,
          onRollback: reverterStatusPassageiro,
        ),
      );
    }
  }

  ViagemModel? _aplicarAtualizacaoPassageiroNoModelo(
    ViagemModel v, {
    required String pacienteId,
    required int novoStatus,
    bool? prontoRetorno,
    JanelaReversaoModel? janelaReversao,
    bool limparJanelaReversao = false,
  }) {
    final List<PassageiroViagemModel> basePassageiros;
    if (v.passageiros.isNotEmpty) {
      basePassageiros = v.passageiros;
    } else if (v.passageirosIds.contains(pacienteId)) {
      basePassageiros = [
        for (int idx = 0; idx < v.passageirosIds.length; idx++)
          PassageiroViagemModel(
            pacienteId: v.passageirosIds[idx],
            pacienteNome:
                _perfisPacientesPorId[v.passageirosIds[idx]]?.nome ??
                    PacienteSyncService()
                        .obterPacienteMemoria(
                          v.passageirosIds[idx],
                          viagemId: v.id,
                        )
                        ?.nome ??
                    '',
            localDestino: v.cidadeDestino,
            ordemEmbarque: idx + 1,
            statusEmbarque:
                PacienteSyncService()
                    .obterPacienteMemoria(
                      v.passageirosIds[idx],
                      viagemId: v.id,
                    )
                    ?.status ??
                0,
          ),
      ];
    } else {
      return null;
    }
    bool mudou = false;
    final novosPassageiros = <PassageiroViagemModel>[];
    PassageiroViagemModel? passageiroModificado;

    for (final p in basePassageiros) {
      if (p.pacienteId == pacienteId) {
        final bool novoPronto = prontoRetorno ??
            ((novoStatus >= 3 || novoStatus == 0) ? false : p.prontoRetorno);
        final bool deveLimparJanela =
            limparJanelaReversao || (novoStatus != 2 && novoStatus != 5);
        final JanelaReversaoModel? novaJanela =
            deveLimparJanela ? null : (janelaReversao ?? p.janelaReversao);

        final mudouPassageiro = p.statusEmbarque != novoStatus ||
            p.prontoRetorno != novoPronto ||
            p.janelaReversao != novaJanela;

        if (mudouPassageiro) {
          mudou = true;
          final atualizadoP = p.copyWith(
            statusEmbarque: novoStatus,
            prontoRetorno: novoPronto,
            janelaReversao: novaJanela,
            limparJanelaReversao: novaJanela == null,
          );
          passageiroModificado = atualizadoP;
          novosPassageiros.add(atualizadoP);
        } else {
          novosPassageiros.add(p);
        }
      } else {
        novosPassageiros.add(p);
      }
    }

    if (!mudou) return null;
    if (passageiroModificado != null) {
      _sincronizarPassageiroEmMemoriaPorViagem(v.id, passageiroModificado);
    }

    var atualizada = v.copyWith(passageiros: novosPassageiros);
    if (!atualizada.isCancelada &&
        !atualizada.isConcluida &&
        todosPacientesVoltaram(atualizada)) {
      atualizada = atualizada.copyWith(
        status: 'encerrada',
        dataHoraFim: DateTime.now(),
        codigosAcesso: const {},
      );
    }
    return atualizada;
  }

  /// Seleciona a próxima viagem ativa ou cria placeholder de sessão; retorna true se inseriu placeholder.
  bool _selecionarProximaOuPlaceholder({String cidadeFallback = ''}) {
    if (_viagensAtivasMemoria.isNotEmpty) {
      _viagemAtiva = _viagensAtivasMemoria.first;
      return false;
    }
    if (_sessaoAtiva != null) {
      final ph = _criarPlaceholderSessaoAtiva(
        _sessaoAtiva!,
        cidadeDestino: cidadeFallback,
      );
      _viagensAtivasMemoria.add(ph);
      _viagemAtiva = ph;
      return true;
    }
    _viagemAtiva = null;
    return false;
  }

  Future<void> _persistirStatusPassageiroNoFirestore({
    required List<ViagemModel> viagensParaPersistir,
    required String pacienteId,
    required List<String> idsEmVoo,
    required VoidCallback onRollback,
  }) async {
    try {
      for (final vp in viagensParaPersistir) {
        if (vp.id.startsWith('sessao_ativa_')) continue;
        try {
          final dados = <String, dynamic>{
            'passageiros': vp.passageiros.map((p) => p.toMap()).toList(),
            'status': vp.status,
          };
          if (vp.isConcluida) {
            dados['dataHoraFim'] =
                (vp.dataHoraFim ?? DateTime.now()).toIso8601String();
            dados['codigosAcesso'] = <String, dynamic>{};
          }
          if (executorPersistenciaRemotaOverride != null) {
            await executorPersistenciaRemotaOverride!(
              'atualizar_status_passageiro_viagem',
              dados,
            );
            _totalGravacoesFirestoreJornada++;
            continue;
          }

          final pLocal =
              vp.passageiros.where((p) => p.pacienteId == pacienteId).firstOrNull;
          final docRef =
              FirebaseFirestore.instance.collection('viagens').doc(vp.id);
          await FirebaseFirestore.instance.runTransaction((tx) async {
            final snap = await tx.get(docRef);
            if (!snap.exists || snap.data() == null || pLocal == null) {
              tx.set(docRef, dados, SetOptions(merge: true));
              return;
            }
            final remoto = ViagemModel.fromMap(snap.data()!, docId: snap.id);
            final basePassageiros =
                remoto.passageiros.isNotEmpty ? remoto.passageiros : vp.passageiros;
            bool encontrou = false;
            final passageirosMerged = basePassageiros.map((p) {
              if (p.pacienteId == pacienteId) {
                encontrou = true;
                return pLocal;
              }
              return p;
            }).toList();
            if (!encontrou) passageirosMerged.add(pLocal);

            final ativos =
                passageirosMerged.where((p) => p.statusEmbarque != 5).toList();
            final todosConcluidos =
                ativos.isEmpty || ativos.every((p) => p.statusEmbarque == 4);

            final updateDados = <String, dynamic>{
              'passageiros': passageirosMerged.map((p) => p.toMap()).toList(),
              'atualizadoEm': FieldValue.serverTimestamp(),
            };
            if (!remoto.isCancelada &&
                !remoto.isConcluida &&
                passageirosMerged.isNotEmpty &&
                todosConcluidos) {
              updateDados['status'] = 'encerrada';
              updateDados['dataHoraFim'] =
                  (vp.dataHoraFim ?? DateTime.now()).toIso8601String();
              updateDados['codigosAcesso'] = <String, dynamic>{};
            }
            tx.update(docRef, updateDados);
          });
          _totalGravacoesFirestoreJornada++;
        } catch (e) {
          _tratarFalhaFirestore(
            'atualizar_status_passageiro_viagem',
            e,
            onRollback: onRollback,
          );
        }
      }
    } finally {
      _viagensComEscritaEmVoo.removeAll(idsEmVoo);
    }
  }

  /// Finaliza a jornada do motorista, liberando veículo/sessão.
  /// A viagem em si só muda para 'encerrada' quando todos os pacientes não cancelados tiverem retornado (status == 4).
  Future<void> encerrarViagem({
    String? viagemId,
    ViagemModel? viagemExplicita,
    int? kmFinal,
    int? kmRodado,
    List<PacienteModel>? pacientes,
  }) async {
    final idAlvo = viagemExplicita?.id ?? viagemId ?? _viagemAtiva?.id;
    if (idAlvo == null || idAlvo.isEmpty) return;

    final index = _viagensAtivasMemoria.indexWhere((v) => v.id == idAlvo);
    final tvIdxInicial = _todasViagensMemoria.indexWhere((tv) => tv.id == idAlvo);

    final ViagemModel? viagem = index != -1
        ? _viagensAtivasMemoria[index]
        : (tvIdxInicial != -1
              ? _todasViagensMemoria[tvIdxInicial]
              : (_viagemAtiva?.id == idAlvo ? _viagemAtiva : viagemExplicita));
    if (viagem == null) return;

    final ehPlaceholderSessao = viagem.id.startsWith('sessao_ativa_');
    final veiculoId = viagem.veiculoId.isNotEmpty
        ? viagem.veiculoId
        : (_sessaoAtiva?.veiculoId ?? '');
    final agoraFim = DateTime.now();

    final passageirosSincronizados = viagem.passageiros.map((p) {
      final st = resolverStatusEfetivoPassageiro(
        p,
        viagemId: viagem.id,
        pacientesContexto: pacientes,
      );
      return p.copyWith(statusEmbarque: st);
    }).toList();

    final kmFinalCalculado = kmFinal ?? viagem.kmFinal;
    final kmRodadoCalculado = kmRodado ??
        viagem.kmRodado ??
        ((kmFinalCalculado != null && kmFinalCalculado >= viagem.kmInicial)
            ? (kmFinalCalculado - viagem.kmInicial)
            : null);

    final todosVoltaram = viagem.isConcluida ||
        ((viagem.passageiros.isNotEmpty || viagem.passageirosIds.isNotEmpty) &&
            todosPacientesVoltaram(
              viagem.copyWith(passageiros: passageirosSincronizados),
              pacientesContexto: pacientes,
            ));

    final ViagemModel viagemAtualizada = viagem.copyWith(
      status: todosVoltaram ? 'encerrada' : 'ativa',
      motoristaId: '',
      motoristaNome: '',
      removerSessaoId: true,
      kmFinal: kmFinalCalculado,
      kmRodado: kmRodadoCalculado,
      dataHoraFim: todosVoltaram ? (viagem.dataHoraFim ?? agoraFim) : null,
      passageiros:
          passageirosSincronizados.isNotEmpty ? passageirosSincronizados : null,
      codigosAcesso: todosVoltaram ? const {} : viagem.codigosAcesso,
    );

    if (index != -1) {
      _viagensAtivasMemoria.removeAt(index);
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }

    if (!ehPlaceholderSessao) {
      final tvIdx = _todasViagensMemoria.indexWhere((tv) => tv.id == idAlvo);
      if (tvIdx != -1) {
        _todasViagensMemoria[tvIdx] = viagemAtualizada;
      } else {
        _todasViagensMemoria.add(viagemAtualizada);
      }
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    if (_viagemAtiva?.id == idAlvo) {
      _viagemAtiva =
          _viagensAtivasMemoria.isNotEmpty ? _viagensAtivasMemoria.first : null;
      _viagemAtivaController.add(_viagemAtiva);
    }

    final sessaoIdAlvo = (viagem.sessaoId?.trim().isNotEmpty == true)
        ? viagem.sessaoId!.trim()
        : (_sessaoAtiva?.id ?? '');
    final motViagem = viagem.motoristaId.trim();
    final motSessaoPorMapa = _sessoesAtivasPorMotorista.entries
            .where(
              (e) =>
                  (sessaoIdAlvo.isNotEmpty && e.value.id == sessaoIdAlvo) ||
                  (veiculoId.isNotEmpty && e.value.veiculoId == veiculoId),
            )
            .map((e) => e.key.trim())
            .where((k) => k.isNotEmpty)
            .firstOrNull ??
        '';
    final motVeiculoMemoria = _veiculosMemoria
            .where((vm) => vm.id == veiculoId)
            .map((vm) => vm.motoristaAtualId?.trim() ?? '')
            .where((m) => m.isNotEmpty && m != 'motorista_atual')
            .firstOrNull ??
        '';
    final motSessaoAtual = _sessaoAtiva?.motoristaId.trim() ?? '';
    final idMotoristaSessao =
        (motViagem.isNotEmpty && motViagem != 'motorista_atual')
            ? motViagem
            : (motSessaoPorMapa.isNotEmpty
                  ? motSessaoPorMapa
                  : (motVeiculoMemoria.isNotEmpty
                        ? motVeiculoMemoria
                        : motSessaoAtual));
    final nomeMotoristaSessao = viagem.motoristaNome.trim().isNotEmpty
        ? viagem.motoristaNome.trim()
        : (_sessoesAtivasPorMotorista[idMotoristaSessao]?.motoristaNome ??
              _sessaoAtiva?.motoristaNome ??
              '');

    final aindaTemViagensDaSessao = _viagensAtivasMemoria.any((va) {
      if (sessaoIdAlvo.isNotEmpty && va.sessaoId == sessaoIdAlvo) return true;
      if (veiculoId.isNotEmpty &&
          va.veiculoId == veiculoId &&
          (idMotoristaSessao.isEmpty ||
              va.motoristaId.isEmpty ||
              va.motoristaId == idMotoristaSessao)) {
        return true;
      }
      return false;
    });
    final sessaoFinalizada =
        _viagensAtivasMemoria.isEmpty || !aindaTemViagensDaSessao;
    final sessaoIdEncerrada = sessaoIdAlvo.isNotEmpty ? sessaoIdAlvo : null;

    if (sessaoFinalizada) {
      final ehSessaoPrincipal = _sessaoAtiva == null ||
          sessaoIdEncerrada == null ||
          _sessaoAtiva!.id == sessaoIdEncerrada ||
          _sessaoAtiva!.veiculoId == veiculoId ||
          (idMotoristaSessao.isNotEmpty &&
              _sessaoAtiva!.motoristaId == idMotoristaSessao);
      if (idMotoristaSessao.isNotEmpty) {
        _sessoesAtivasPorMotorista.remove(idMotoristaSessao);
      }
      if (ehSessaoPrincipal) {
        _sessaoFinalizadaPeloMotorista = true;
        _sessaoAtiva = _sessaoAtiva?.copyWith(
          status: 'encerrada',
          kmFinal: kmFinalCalculado,
          kmRodado: kmRodadoCalculado,
          dataHoraFim: agoraFim,
        );
        _sessaoAtivaController.add(_sessaoAtiva);
        _sessaoAtiva = null;
        if (_viagemAtiva != null &&
            (sessaoIdEncerrada != null &&
                    _viagemAtiva!.sessaoId == sessaoIdEncerrada ||
                _viagemAtiva!.veiculoId == veiculoId)) {
          _viagemAtiva = null;
          _viagemAtivaController.add(null);
        }
      }

      final veicIndex = _veiculosMemoria.indexWhere((v) => v.id == veiculoId);
      if (veicIndex != -1) {
        final veicAtual = _veiculosMemoria[veicIndex];
        final motVeic = veicAtual.motoristaAtualId?.trim() ?? '';
        if (motVeic.isEmpty ||
            idMotoristaSessao.isEmpty ||
            motVeic == idMotoristaSessao ||
            motVeic == 'motorista_atual') {
          _veiculosMemoria[veicIndex] = veicAtual.copyWith(
            emUso: false,
            limparMotorista: true,
            quilometragemAtual:
                kmFinalCalculado ?? veicAtual.quilometragemAtual,
          );
        }
      }
      _veiculosController
          .add(ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria));
    }

    if (_isFirebaseDisponivel()) {
      final motSessaoReal =
          (idMotoristaSessao.isNotEmpty &&
                  idMotoristaSessao != 'motorista_atual')
              ? idMotoristaSessao
              : '';
      final idMotoristaParaLiberar = motSessaoReal.isNotEmpty
          ? motSessaoReal
          : (FirebaseAuthService().currentDocId ??
                FirebaseAuthService().currentUserId ??
                '');
      final nomeMotoristaParaLiberar = nomeMotoristaSessao.isNotEmpty
          ? nomeMotoristaSessao
          : 'Motorista';

      unawaited(
        _persistirEncerramentoNoFirestore(
          viagem: viagem,
          viagemAtualizada: viagemAtualizada,
          ehPlaceholderSessao: ehPlaceholderSessao,
          todosVoltaram: todosVoltaram,
          passageirosSincronizados: passageirosSincronizados,
          veiculoId: veiculoId,
          kmFinalCalculado: kmFinalCalculado,
          kmRodadoCalculado: kmRodadoCalculado,
          agoraFim: agoraFim,
          sessaoFinalizada: sessaoFinalizada,
          sessaoIdEncerrada: sessaoIdEncerrada,
          idMotoristaParaLiberar: idMotoristaParaLiberar,
          nomeMotoristaParaLiberar: nomeMotoristaParaLiberar,
        ),
      );
    }
  }

  Future<void> _persistirEncerramentoNoFirestore({
    required ViagemModel viagem,
    required ViagemModel viagemAtualizada,
    required bool ehPlaceholderSessao,
    required bool todosVoltaram,
    required List<PassageiroViagemModel> passageirosSincronizados,
    required String veiculoId,
    required int? kmFinalCalculado,
    required int? kmRodadoCalculado,
    required DateTime agoraFim,
    required bool sessaoFinalizada,
    required String? sessaoIdEncerrada,
    required String idMotoristaParaLiberar,
    required String nomeMotoristaParaLiberar,
  }) async {
    try {
      if (!ehPlaceholderSessao) {
        final dadosViagem = <String, dynamic>{
          'status': viagemAtualizada.status,
          'motoristaId': '',
          'motoristaNome': '',
          'sessaoId': null,
          if (!todosVoltaram) 'veiculoId': '',
          if (todosVoltaram)
            'dataHoraFim':
                (viagemAtualizada.dataHoraFim ?? agoraFim).toIso8601String(),
          if (todosVoltaram) 'codigosAcesso': <String, dynamic>{},
          if (passageirosSincronizados.isNotEmpty)
            'passageiros':
                passageirosSincronizados.map((p) => p.toMap()).toList(),
          'kmFinal': ?kmFinalCalculado,
          'kmRodado': ?kmRodadoCalculado,
        };

        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagem.id)
            .set(dadosViagem, SetOptions(merge: true));
        _totalGravacoesFirestoreJornada++;

        await _registrarSnapshotHomologado(
          viagem: viagem,
          viagemAtualizada: viagemAtualizada,
          passageirosSincronizados: passageirosSincronizados,
          veiculoId: veiculoId,
          kmFinalCalculado: kmFinalCalculado,
          kmRodadoCalculado: kmRodadoCalculado,
          agoraFim: agoraFim,
          idMotoristaParaLiberar: idMotoristaParaLiberar,
          nomeMotoristaParaLiberar: nomeMotoristaParaLiberar,
        );
      }

      if (sessaoFinalizada) {
        if (sessaoIdEncerrada != null && sessaoIdEncerrada.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('sessoes_veiculo')
              .doc(sessaoIdEncerrada)
              .set({
                'status': 'encerrada',
                'dataHoraFim': agoraFim.toIso8601String(),
                'kmFinal': ?kmFinalCalculado,
                'kmRodado': ?kmRodadoCalculado,
              }, SetOptions(merge: true));
          _totalGravacoesFirestoreJornada++;
        }

        if (veiculoId.isNotEmpty) {
          final veicRef =
              FirebaseFirestore.instance.collection('veiculos').doc(veiculoId);
          await FirebaseFirestore.instance.runTransaction((tx) async {
            final snap = await tx.get(veicRef);
            if (!snap.exists) {
              tx.set(veicRef, {
                'emUso': false,
                'motoristaAtualId': null,
                'quilometragemAtual': ?kmFinalCalculado,
              }, SetOptions(merge: true));
              return;
            }
            final dados = snap.data() ?? {};
            final motAtual =
                dados['motoristaAtualId']?.toString().trim() ?? '';
            if (motAtual.isEmpty ||
                idMotoristaParaLiberar.isEmpty ||
                motAtual == idMotoristaParaLiberar ||
                motAtual == 'motorista_atual') {
              tx.set(veicRef, {
                'emUso': false,
                'motoristaAtualId': null,
                'quilometragemAtual': ?kmFinalCalculado,
              }, SetOptions(merge: true));
            }
          });
          _totalGravacoesFirestoreJornada++;
        }

        if (idMotoristaParaLiberar.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(idMotoristaParaLiberar)
              .set({'emViagem': false}, SetOptions(merge: true));
          _totalGravacoesFirestoreJornada++;
          LocalizacaoMotoristaService()
              .removerOuInativarMotorista(idMotoristaParaLiberar);
        }
      }
    } catch (e) {
      _tratarFalhaFirestore('encerrar_viagem', e);
    }
  }

  Future<void> _registrarSnapshotHomologado({
    required ViagemModel viagem,
    required ViagemModel viagemAtualizada,
    required List<PassageiroViagemModel> passageirosSincronizados,
    required String veiculoId,
    required int? kmFinalCalculado,
    required int? kmRodadoCalculado,
    required DateTime agoraFim,
    required String idMotoristaParaLiberar,
    required String nomeMotoristaParaLiberar,
  }) async {
    try {
      final strParaHash =
          '${viagem.id}:$kmFinalCalculado:$kmRodadoCalculado:${agoraFim.toIso8601String()}';
      final hashSha256 = sha256.convert(utf8.encode(strParaHash)).toString();

      await FirebaseFirestore.instance
          .collection('viagens_homologadas')
          .doc(viagem.id)
          .set({
            'viagemId': viagem.id,
            'cidadeDestino': viagemAtualizada.cidadeDestino,
            'motoristaId': idMotoristaParaLiberar,
            'motoristaNome': nomeMotoristaParaLiberar,
            'veiculoId': veiculoId,
            'veiculoPlaca': viagemAtualizada.veiculoPlaca,
            'veiculoModelo': viagemAtualizada.veiculoModelo,
            'kmInicial': viagem.kmInicial,
            'kmFinal': kmFinalCalculado,
            'kmRodado': kmRodadoCalculado,
            'dataHoraInicio': viagem.dataHoraInicio.toIso8601String(),
            'dataHoraFim': agoraFim.toIso8601String(),
            'passageiros':
                passageirosSincronizados.map((p) => p.toMap()).toList(),
            'status': 'homologada',
            'autor': nomeMotoristaParaLiberar,
            'hashIntegridade': hashSha256,
            'homologadoEm': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _totalGravacoesFirestoreJornada++;
    } catch (e) {
      // Falha no snapshot de auditoria não bloqueia a liberação do motorista/veículo.
      debugPrint('Aviso: falha na persistência do snapshot homologado ($e)');
    }
  }

  /// Encerra em lote todas as viagens ativas vinculadas à sessão atual do condutor.
  Future<void> encerrarTodasViagens({
    int? kmFinal,
    int? kmRodado,
    List<ViagemModel>? viagensExplicitas,
    List<PacienteModel>? pacientes,
    String? motoristaId,
  }) async {
    final sessaoAlvo = (motoristaId != null &&
            motoristaId.trim().isNotEmpty &&
            _sessoesAtivasPorMotorista.containsKey(motoristaId.trim()))
        ? _sessoesAtivasPorMotorista[motoristaId.trim()]
        : _sessaoAtiva;
    final idMotoristaDaSessaoAntes = (motoristaId?.trim().isNotEmpty == true)
        ? motoristaId!.trim()
        : (sessaoAlvo?.motoristaId ?? '');
    final sessaoIdAlvo = sessaoAlvo?.id ?? '';
    final veiculoIdAlvo = sessaoAlvo?.veiculoId ?? '';
    if (motoristaId == null ||
        _sessaoAtiva == null ||
        _sessaoAtiva!.motoristaId.trim().isEmpty ||
        _sessaoAtiva!.motoristaId.trim() == idMotoristaDaSessaoAntes) {
      _sessaoFinalizadaPeloMotorista = true;
    }
    final mapaParaEncerrar = <String, ViagemModel>{};

    bool pertenceAoCondutor(ViagemModel v) {
      final motV = v.motoristaId.trim();
      final sessV = v.sessaoId?.trim() ?? '';
      if (idMotoristaDaSessaoAntes.isNotEmpty &&
          motV.isNotEmpty &&
          motV != 'motorista_atual' &&
          motV != idMotoristaDaSessaoAntes) {
        return false;
      }
      if (sessaoIdAlvo.isNotEmpty && sessV.isNotEmpty && sessV != sessaoIdAlvo) {
        return false;
      }
      if (veiculoIdAlvo.isNotEmpty &&
          v.veiculoId.isNotEmpty &&
          v.veiculoId != veiculoIdAlvo) {
        return false;
      }
      return true;
    }

    if (viagensExplicitas != null && viagensExplicitas.isNotEmpty) {
      for (final v in viagensExplicitas) {
        if (v.id.isNotEmpty) mapaParaEncerrar[v.id] = v;
      }
    } else {
      for (final vc in _viagensConcluidasNaSessao) {
        if (vc.id.isNotEmpty && pertenceAoCondutor(vc)) {
          mapaParaEncerrar[vc.id] = vc;
        }
      }
      for (final v in _viagensAtivasMemoria) {
        if (v.id.isNotEmpty && pertenceAoCondutor(v)) {
          mapaParaEncerrar[v.id] = v;
        }
      }
      if (_viagemAtiva != null &&
          _viagemAtiva!.id.isNotEmpty &&
          pertenceAoCondutor(_viagemAtiva!)) {
        mapaParaEncerrar[_viagemAtiva!.id] = _viagemAtiva!;
      }
    }

    final refViagem = mapaParaEncerrar.values.firstOrNull;
    if (refViagem != null) {
      final placaRef = _normalizarPlacaInterna(refViagem.veiculoPlaca);
      for (final tv in _todasViagensMemoria) {
        if (tv.isCancelada || tv.isConcluida) continue;
        if (!pertenceAoCondutor(tv)) continue;
        final mesmoVeiculo =
            (refViagem.veiculoId.isNotEmpty &&
                tv.veiculoId == refViagem.veiculoId) ||
            (placaRef.isNotEmpty &&
                _normalizarPlacaInterna(tv.veiculoPlaca) == placaRef);
        if (tv.isAtiva && mesmoVeiculo) {
          mapaParaEncerrar[tv.id] = tv;
        }
      }
    }

    if (mapaParaEncerrar.isNotEmpty) {
      for (final v in mapaParaEncerrar.values.toList()) {
        await encerrarViagem(
          viagemId: v.id,
          viagemExplicita: v,
          kmFinal: kmFinal,
          kmRodado: kmRodado,
          pacientes: pacientes,
        );
      }
    } else if (sessaoAlvo != null) {
      if (idMotoristaDaSessaoAntes.isNotEmpty) {
        _sessoesAtivasPorMotorista.remove(idMotoristaDaSessaoAntes);
      }
      if (veiculoIdAlvo.isNotEmpty) {
        final veicIdx = _veiculosMemoria.indexWhere((v) => v.id == veiculoIdAlvo);
        if (veicIdx != -1) {
          final veicAtual = _veiculosMemoria[veicIdx];
          final motVeic = veicAtual.motoristaAtualId?.trim() ?? '';
          if (motVeic.isEmpty ||
              idMotoristaDaSessaoAntes.isEmpty ||
              motVeic == idMotoristaDaSessaoAntes ||
              motVeic == 'motorista_atual') {
            _veiculosMemoria[veicIdx] = veicAtual.copyWith(
              emUso: false,
              limparMotorista: true,
              quilometragemAtual: kmFinal ?? veicAtual.quilometragemAtual,
            );
            _veiculosController
                .add(ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria));
          }
        }
        if (_isFirebaseDisponivel()) {
          unawaited(
            FirebaseFirestore.instance
                .collection('veiculos')
                .doc(veiculoIdAlvo)
                .set({
                  'emUso': false,
                  'motoristaAtualId': null,
                  'quilometragemAtual': ?kmFinal,
                }, SetOptions(merge: true))
                .catchError((_) {}),
          );
        }
      }
      if (_sessaoAtiva?.id == sessaoAlvo.id) {
        _sessaoAtiva = null;
        _sessaoAtivaController.add(null);
      }
    }

    _viagensConcluidasNaSessao.clear();
    if (motoristaId == null ||
        idMotoristaDaSessaoAntes.isEmpty ||
        idMotoristaDaSessaoAntes ==
            (FirebaseAuthService().currentDocId ??
                FirebaseAuthService().currentUserId ??
                idMotoristaDaSessaoAntes)) {
      FirebaseAuthService.motoristaEmViagemStatic = false;
    }

    final motSessaoReal =
        (idMotoristaDaSessaoAntes.trim().isNotEmpty &&
                idMotoristaDaSessaoAntes.trim() != 'motorista_atual')
            ? idMotoristaDaSessaoAntes.trim()
            : '';
    final motRefReal =
        (refViagem != null &&
                refViagem.motoristaId.trim().isNotEmpty &&
                refViagem.motoristaId.trim() != 'motorista_atual')
            ? refViagem.motoristaId.trim()
            : '';
    final idMotoristaFinal = motSessaoReal.isNotEmpty
        ? motSessaoReal
        : (motRefReal.isNotEmpty
              ? motRefReal
              : (FirebaseAuthService().currentDocId ??
                    FirebaseAuthService().currentUserId ??
                    ''));
    if (_isFirebaseDisponivel() && idMotoristaFinal.isNotEmpty) {
      unawaited(
        FirebaseFirestore.instance
            .collection('usuarios')
            .doc(idMotoristaFinal)
            .set({'emViagem': false}, SetOptions(merge: true))
            .catchError((_) {}),
      );
      LocalizacaoMotoristaService()
          .removerOuInativarMotorista(idMotoristaFinal);
    }

    if ((viagensExplicitas == null && motoristaId == null) &&
        (_viagensAtivasMemoria.isNotEmpty ||
            _viagemAtiva != null ||
            _sessaoAtiva != null)) {
      _viagensAtivasMemoria.clear();
      _viagemAtiva = null;
      _sessaoAtiva = null;
      _viagensAtivasController.add(const <ViagemModel>[]);
      _viagemAtivaController.add(null);
      _sessaoAtivaController.add(null);
    } else if (_viagensAtivasMemoria.isEmpty &&
        (_viagemAtiva != null || _sessaoAtiva != null)) {
      _viagemAtiva = null;
      _sessaoAtiva = null;
      _viagemAtivaController.add(null);
      _sessaoAtivaController.add(null);
    }
  }

  // ===========================================================================
  // SEÇÃO: Migração de Viagens Legadas
  // ===========================================================================

  /// Migra viagens legadas (sem `sessaoId`) para o modelo `SessaoVeiculoModel -> N Viagens`.
  Future<Map<String, dynamic>> migrarViagensLegadasParaSessao() async {
    final viagensMigradas = <String>[];
    final sessoesCriadas = <String>[];

    for (int i = 0; i < _viagensAtivasMemoria.length; i++) {
      if (_viagensAtivasMemoria[i].sessaoId != null) continue;
      final v = _viagensAtivasMemoria[i];
      final sessaoId = _sessaoAtiva?.id ?? 'sessao_migrada_${v.id}';
      if (_sessaoAtiva == null) {
        _sessaoAtiva = SessaoVeiculoModel(
          id: sessaoId,
          motoristaId: v.motoristaId,
          motoristaNome: v.motoristaNome,
          veiculoId: v.veiculoId,
          veiculoPlaca: v.veiculoPlaca,
          veiculoModelo: v.veiculoModelo,
          kmInicial: v.kmInicial,
          dataHoraInicio: v.dataHoraInicio,
          status: v.status,
          viagensIds: [v.id],
        );
        sessoesCriadas.add(sessaoId);
      }
      _viagensAtivasMemoria[i] = v.copyWith(sessaoId: sessaoId);
      if (!viagensMigradas.contains(v.id)) viagensMigradas.add(v.id);
    }

    if (_viagemAtiva != null && _viagemAtiva!.sessaoId == null) {
      if (_sessaoAtiva == null) {
        _sessaoAtiva = SessaoVeiculoModel(
          id: 'sessao_migrada_${DateTime.now().millisecondsSinceEpoch}',
          motoristaId: _viagemAtiva!.motoristaId,
          motoristaNome: _viagemAtiva!.motoristaNome,
          veiculoId: _viagemAtiva!.veiculoId,
          veiculoPlaca: _viagemAtiva!.veiculoPlaca,
          veiculoModelo: _viagemAtiva!.veiculoModelo,
          kmInicial: _viagemAtiva!.kmInicial,
          dataHoraInicio: _viagemAtiva!.dataHoraInicio,
          status: _viagemAtiva!.status,
          viagensIds: [_viagemAtiva!.id],
        );
        sessoesCriadas.add(_sessaoAtiva!.id);
      }
      _viagemAtiva = _viagemAtiva!.copyWith(sessaoId: _sessaoAtiva!.id);
      if (!viagensMigradas.contains(_viagemAtiva!.id)) {
        viagensMigradas.add(_viagemAtiva!.id);
      }
    }

    if (_isFirebaseDisponivel()) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('viagens')
            .where('status', isEqualTo: 'ativa')
            .where(
              'dataHoraInicio',
              isGreaterThanOrEqualTo: _obterInicioDoDiaOperacionalIso(),
            )
            .get();

        for (final doc in snap.docs) {
          final dados = doc.data();
          if (dados['sessaoId'] == null ||
              dados['sessaoId'].toString().isEmpty) {
            final novaSessaoId = 'sessao_migrada_${doc.id}';
            final novaSessao = SessaoVeiculoModel(
              id: novaSessaoId,
              motoristaId: (dados['motoristaId'] ?? '').toString(),
              motoristaNome: (dados['motoristaNome'] ?? '').toString(),
              veiculoId: (dados['veiculoId'] ?? '').toString(),
              veiculoPlaca: (dados['veiculoPlaca'] ?? '').toString(),
              veiculoModelo: (dados['veiculoModelo'] ?? '').toString(),
              kmInicial: (dados['kmInicial'] is num)
                  ? (dados['kmInicial'] as num).toInt()
                  : 0,
              dataHoraInicio: DateTime.now(),
              status: 'ativa',
              viagensIds: [doc.id],
            );

            await FirebaseFirestore.instance
                .collection('sessoes_veiculo')
                .doc(novaSessaoId)
                .set(novaSessao.toMap());
            await FirebaseFirestore.instance
                .collection('viagens')
                .doc(doc.id)
                .update({'sessaoId': novaSessaoId});

            viagensMigradas.add(doc.id);
            sessoesCriadas.add(novaSessaoId);
          }
        }
      } catch (e) {
        _tratarFalhaFirestore('migrar_viagens_legadas', e);
      }
    }

    return {
      'sucesso': true,
      'totalViagensMigradas': viagensMigradas.length,
      'viagensIds': viagensMigradas,
      'sessoesCriadas': sessoesCriadas,
    };
  }

  Future<void> reverterMigracaoParaTestes({
    required List<String> viagensIds,
  }) async {
    for (int i = 0; i < _viagensAtivasMemoria.length; i++) {
      if (viagensIds.contains(_viagensAtivasMemoria[i].id)) {
        _viagensAtivasMemoria[i] =
            _viagensAtivasMemoria[i].copyWith(removerSessaoId: true);
      }
    }
    if (_viagemAtiva != null && viagensIds.contains(_viagemAtiva!.id)) {
      _viagemAtiva = _viagemAtiva!.copyWith(removerSessaoId: true);
    }
    _sessaoAtiva = null;
    if (_isFirebaseDisponivel()) {
      try {
        for (final id in viagensIds) {
          await FirebaseFirestore.instance
              .collection('viagens')
              .doc(id)
              .update({'sessaoId': FieldValue.delete()});
        }
      } catch (e) {
        _tratarFalhaFirestore('reverter_migracao', e);
      }
    }
  }

  // ===========================================================================
  // SEÇÃO: Gestão e CRUD de Horários / Viagens (Administrativo)
  // ===========================================================================

  Stream<List<ViagemModel>> listarViagensPorDataStream(DateTime data) {
    final dataAlvo = DateTime(data.year, data.month, data.day);
    return todasViagensStream.map((lista) {
      return lista.where((v) {
        final dv = v.dataOperacional;
        return dv.year == dataAlvo.year &&
            dv.month == dataAlvo.month &&
            dv.day == dataAlvo.day;
      }).toList();
    });
  }

  List<ViagemModel> obterViagensPorData(DateTime data) {
    final dataAlvo = DateTime(data.year, data.month, data.day);
    return _todasViagensMemoria.where((v) {
      final dv = v.dataOperacional;
      return dv.year == dataAlvo.year &&
          dv.month == dataAlvo.month &&
          dv.day == dataAlvo.day;
    }).toList();
  }

  List<ViagemModel> listarViagensDoMotorista(String motoristaId, DateTime data) {
    final dataAlvo = DateTime(data.year, data.month, data.day);
    return _todasViagensMemoria.where((v) {
      final dv = v.dataOperacional;
      return dv.year == dataAlvo.year &&
          dv.month == dataAlvo.month &&
          dv.day == dataAlvo.day &&
          v.motoristaId == motoristaId &&
          !v.isCancelada;
    }).toList();
  }

  /// Valida regras compartilhadas de criação e atualização de Horário de Viagem.
  String? _validarDadosHorario({
    required DateTime data,
    required String horario,
    required String cidadeDestino,
    required String motoristaId,
    required String veiculoId,
    required int totalAssentosOcupados,
    required int? capacidadeVeiculo,
    required List<PassageiroViagemModel> passageiros,
    String? viagemIdAtual,
  }) {
    final validacaoCidade = ValidacaoViagem.validarCidade(cidadeDestino);
    if (!validacaoCidade.valido) return validacaoCidade.mensagemErro;

    final dataAlvo = DateTime(data.year, data.month, data.day);
    final viagensDoDia = obterViagensPorData(dataAlvo);

    if (motoristaId.trim().isNotEmpty) {
      final resMot = ValidacaoViagem.validarConflitoMotorista(
        motoristaId: motoristaId,
        data: data,
        horario: horario,
        viagensDoDia: viagensDoDia,
        viagemIdAtual: viagemIdAtual,
      );
      if (!resMot.valido) return resMot.mensagemErro;
    }

    if (veiculoId.trim().isNotEmpty) {
      final resVeic = ValidacaoViagem.validarConflitoVeiculo(
        veiculoId: veiculoId,
        data: data,
        horario: horario,
        viagensDoDia: viagensDoDia,
        viagemIdAtual: viagemIdAtual,
      );
      if (!resVeic.valido) return resVeic.mensagemErro;
    }

    if (capacidadeVeiculo != null && capacidadeVeiculo > 0) {
      final resCap = ValidacaoViagem.validarCapacidade(
        totalPassageirosComAcompanhantes: totalAssentosOcupados,
        capacidadeVeiculo: capacidadeVeiculo,
      );
      if (!resCap.valido) return resCap.mensagemErro;
    }

    for (final p in passageiros) {
      final resAcomp = ValidacaoViagem.validarAcompanhante(
        acompanhanteNome: p.acompanhanteNome,
        pacienteId: p.pacienteId,
      );
      if (!resAcomp.valido) return resAcomp.mensagemErro;

      final resPac = ValidacaoViagem.validarConflitoPaciente(
        pacienteId: p.pacienteId,
        data: dataAlvo,
        horario: horario,
        viagensDoDia: viagensDoDia,
        viagemIdAtual: viagemIdAtual,
      );
      if (!resPac.valido) return resPac.mensagemErro;

      final resHorario = ValidacaoViagem.validarCompatibilidadeHorarioConsulta(
        horarioSaida: horario,
        horarioAtendimento: p.horarioAtendimento,
      );
      if (!resHorario.valido) return resHorario.mensagemErro;
    }

    return null;
  }

  /// Cria um novo Horário de Saída no gerenciador diário (somente Administrador).
  Future<ResultadoOperacaoViagem> criarHorarioViagem({
    required DateTime data,
    required String horario,
    String veiculoId = '',
    String veiculoPlaca = '',
    String veiculoModelo = '',
    int capacidadeVeiculo = 0,
    String motoristaId = '',
    String motoristaNome = '',
    required String cidadeDestino,
    List<PassageiroViagemModel> passageiros = const [],
    String? observacoes,
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      return ResultadoOperacaoViagem.erro(
        'Apenas administradores possuem permissão para criar novos Horários.',
      );
    }

    final totalAssentos =
        passageiros.fold<int>(0, (acc, p) => acc + p.assentosOcupados);
    final erroValidacao = _validarDadosHorario(
      data: data,
      horario: horario,
      cidadeDestino: cidadeDestino,
      motoristaId: motoristaId,
      veiculoId: veiculoId,
      totalAssentosOcupados: totalAssentos,
      capacidadeVeiculo: capacidadeVeiculo,
      passageiros: passageiros,
    );
    if (erroValidacao != null) {
      return ResultadoOperacaoViagem.erro(erroValidacao);
    }

    final dataAlvo = DateTime(data.year, data.month, data.day);
    DateTime dataHoraInicioViagem = dataAlvo;
    final match = RegExp(r'(\d{1,2})[:hH](\d{2})').firstMatch(horario);
    if (match != null) {
      final h = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      if (h != null && m != null) {
        dataHoraInicioViagem = DateTime(data.year, data.month, data.day, h, m);
      }
    }

    final idNovaViagem =
        'horario_${dataAlvo.year}_${dataAlvo.month}_${dataAlvo.day}_${DateTime.now().millisecondsSinceEpoch}';
    final listaPassageirosIds = passageiros
        .expand((p) => [p.pacienteId, if (p.acompanhanteId != null) p.acompanhanteId!])
        .where((id) => id.isNotEmpty)
        .toList();
    final (codigosGerados, hashesGerados, _) = _sincronizarCodigosDaViagem(
      viagemId: idNovaViagem,
      passageiros: passageiros,
      passageirosIds: listaPassageirosIds,
      codigosExistentes: const {},
      hashesExistentes: const {},
    );

    final novaViagem = ViagemModel(
      id: idNovaViagem,
      motoristaId: motoristaId,
      motoristaNome: motoristaNome,
      veiculoId: veiculoId,
      veiculoPlaca: veiculoPlaca,
      veiculoModelo: veiculoModelo,
      kmInicial: 0,
      cidadeDestino: cidadeDestino,
      nomeHorario: horario,
      dataViagem: dataAlvo,
      dataHoraInicio: dataHoraInicioViagem,
      status: 'planejada',
      observacoes: observacoes,
      passageiros: passageiros,
      passageirosIds: listaPassageirosIds,
      codigosAcesso: codigosGerados,
      codigosHash: hashesGerados,
    );

    PacienteSyncService().resetarStatusPacientesParaNovaViagem(
      passageiros.where((p) => p.statusEmbarque == 0).map((p) => p.pacienteId),
      viagemId: novaViagem.id,
    );
    for (final pv in novaViagem.passageiros) {
      _sincronizarPassageiroEmMemoriaPorViagem(novaViagem.id, pv);
    }
    _todasViagensMemoria.add(novaViagem);
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(novaViagem.id)
            .set(novaViagem.toMap());
        _totalGravacoesFirestoreJornada++;
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore(
          'criar_horario_viagem',
          e,
          onRollback: () {
            _todasViagensMemoria.removeWhere((v) => v.id == novaViagem.id);
            _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
          },
        );
      } catch (e) {
        _tratarFalhaFirestore('criar_horario_viagem', e);
      }
    }

    return ResultadoOperacaoViagem.sucesso(novaViagem);
  }

  /// Atualiza os dados de um Horário de Viagem existente (somente Administrador).
  Future<ResultadoOperacaoViagem> atualizarHorarioViagem({
    required ViagemModel viagem,
    int? capacidadeVeiculo,
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      return ResultadoOperacaoViagem.erro(
        'Apenas administradores possuem permissão para atualizar Horários.',
      );
    }

    final index = _todasViagensMemoria.indexWhere((v) => v.id == viagem.id);
    if (index == -1) {
      return ResultadoOperacaoViagem.erro('Horário não encontrado.');
    }

    final existente = _todasViagensMemoria[index];
    if (existente.isConcluida) {
      return ResultadoOperacaoViagem.erro(
        'Não é possível editar uma viagem que já foi concluída.',
      );
    }

    final erroValidacao = _validarDadosHorario(
      data: viagem.dataOperacional,
      horario: viagem.tituloHorario,
      cidadeDestino: viagem.cidadeDestino,
      motoristaId: viagem.motoristaId,
      veiculoId: viagem.veiculoId,
      totalAssentosOcupados: viagem.totalAssentosOcupados,
      capacidadeVeiculo: capacidadeVeiculo,
      passageiros: viagem.passageiros,
      viagemIdAtual: viagem.id,
    );
    if (erroValidacao != null) {
      return ResultadoOperacaoViagem.erro(erroValidacao);
    }

    final idsAtuais = viagem.passageiros.map((p) => p.pacienteId).toSet();
    final mapaCodigosPreservados = <String, String>{
      ...existente.codigosAcesso,
      ...viagem.codigosAcesso,
    }..removeWhere((id, _) => !idsAtuais.contains(id));
    final mapaHashesPreservados = <String, String>{
      ...existente.codigosHash,
      ...viagem.codigosHash,
    }..removeWhere((id, _) => !idsAtuais.contains(id));

    final listaPassageirosIds = viagem.passageiros
        .expand((p) => [p.pacienteId, if (p.acompanhanteId != null) p.acompanhanteId!])
        .where((id) => id.isNotEmpty)
        .toList();

    final (codigosSinc, hashesSinc, _) = _sincronizarCodigosDaViagem(
      viagemId: viagem.id,
      passageiros: viagem.passageiros,
      passageirosIds: listaPassageirosIds,
      codigosExistentes: mapaCodigosPreservados,
      hashesExistentes: mapaHashesPreservados,
    );

    final viagemAtualizada = viagem.copyWith(
      codigosAcesso: codigosSinc,
      codigosHash: hashesSinc,
      passageirosIds: listaPassageirosIds,
    );

    _aplicarAtualizacaoHorarioEmMemoria(
      index: index,
      viagemAtualizada: viagemAtualizada,
    );

    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagem.id)
            .set(viagemAtualizada.toMap(), SetOptions(merge: true));
        _totalGravacoesFirestoreJornada++;
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore(
          'atualizar_horario_viagem',
          e,
          onRollback: () {
            _todasViagensMemoria[index] = existente;
            _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
          },
        );
      } catch (e) {
        _tratarFalhaFirestore('atualizar_horario_viagem', e);
      }
    }

    return ResultadoOperacaoViagem.sucesso(viagemAtualizada);
  }

  void _aplicarAtualizacaoHorarioEmMemoria({
    required int index,
    required ViagemModel viagemAtualizada,
  }) {
    PacienteSyncService().resetarStatusPacientesParaNovaViagem(
      viagemAtualizada.passageiros
          .where((p) => p.statusEmbarque == 0)
          .map((p) => p.pacienteId),
      viagemId: viagemAtualizada.id,
    );
    for (final pv in viagemAtualizada.passageiros) {
      _sincronizarPassageiroEmMemoriaPorViagem(viagemAtualizada.id, pv);
    }
    _todasViagensMemoria[index] = viagemAtualizada;
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    final ativaIndex =
        _viagensAtivasMemoria.indexWhere((v) => v.id == viagemAtualizada.id);
    if (ativaIndex != -1) {
      _viagensAtivasMemoria[ativaIndex] = viagemAtualizada;
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
    if (_viagemAtiva?.id == viagemAtualizada.id) {
      _viagemAtiva = viagemAtualizada;
      _viagemAtivaController.add(_viagemAtiva);
    }
  }

  /// Cancela logicamente (preferencial) ou exclui um Horário de Viagem.
  Future<ResultadoOperacaoViagem> cancelarOuExcluirHorarioViagem(
    String viagemId, {
    bool softDelete = true,
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      return ResultadoOperacaoViagem.erro(
        'Apenas administradores possuem permissão para cancelar ou excluir Horários.',
      );
    }

    final index = _todasViagensMemoria.indexWhere((v) => v.id == viagemId);
    if (index == -1) {
      return ResultadoOperacaoViagem.erro('Horário não encontrado.');
    }

    final viagem = _todasViagensMemoria[index];
    final ViagemModel resultadoModelo;

    if (softDelete) {
      resultadoModelo = viagem.copyWith(
        status: 'cancelada',
        codigosAcesso: const {},
      );
      _todasViagensMemoria[index] = resultadoModelo;
    } else {
      resultadoModelo = _todasViagensMemoria.removeAt(index);
    }
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    final ativaIndex = _viagensAtivasMemoria.indexWhere((v) => v.id == viagemId);
    if (ativaIndex != -1) {
      _viagensAtivasMemoria.removeAt(ativaIndex);
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
    if (_viagemAtiva?.id == viagemId) {
      _viagemAtiva =
          _viagensAtivasMemoria.isNotEmpty ? _viagensAtivasMemoria.first : null;
      _viagemAtivaController.add(_viagemAtiva);
    }

    if (_isFirebaseDisponivel()) {
      final operacao =
          softDelete ? 'cancelar_horario_viagem' : 'excluir_horario_viagem';
      try {
        final docRef =
            FirebaseFirestore.instance.collection('viagens').doc(viagemId);
        if (softDelete) {
          await docRef.set(resultadoModelo.toMap(), SetOptions(merge: true));
        } else {
          await docRef.delete();
        }
        _totalGravacoesFirestoreJornada++;
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore(
          operacao,
          e,
          onRollback: () {
            if (softDelete) {
              _todasViagensMemoria[index] = viagem;
            } else {
              _todasViagensMemoria.insert(index, resultadoModelo);
            }
            _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
          },
        );
      } catch (e) {
        _tratarFalhaFirestore(operacao, e);
      }
    }

    return ResultadoOperacaoViagem.sucesso(resultadoModelo);
  }

  /// Duplica todas as viagens ativas/planejadas de [dataOrigem] para [dataDestino].
  Future<List<ViagemModel>> duplicarViagensDeOutroDia({
    required DateTime dataOrigem,
    required DateTime dataDestino,
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      throw Exception('Apenas administradores podem duplicar Horários.');
    }

    final dataOrigemFmt =
        DateTime(dataOrigem.year, dataOrigem.month, dataOrigem.day);
    final dataDestinoFmt =
        DateTime(dataDestino.year, dataDestino.month, dataDestino.day);

    final viagensOrigem = _todasViagensMemoria.where((v) {
      final dv = v.dataOperacional;
      return dv.year == dataOrigemFmt.year &&
          dv.month == dataOrigemFmt.month &&
          dv.day == dataOrigemFmt.day &&
          !v.isCancelada;
    }).toList();

    final duplicadas = <ViagemModel>[];

    for (int i = 0; i < viagensOrigem.length; i++) {
      final vo = viagensOrigem[i];
      final novaHora = DateTime(
        dataDestinoFmt.year,
        dataDestinoFmt.month,
        dataDestinoFmt.day,
        vo.dataHoraInicio.hour,
        vo.dataHoraInicio.minute,
      );

      final idDuplicada =
          'horario_${dataDestinoFmt.year}_${dataDestinoFmt.month}_${dataDestinoFmt.day}_${DateTime.now().millisecondsSinceEpoch}_$i';
      final (codigosDup, hashesDup, _) = _sincronizarCodigosDaViagem(
        viagemId: idDuplicada,
        passageiros: vo.passageiros,
        passageirosIds: vo.passageirosIds,
        codigosExistentes: const {},
        hashesExistentes: const {},
      );

      final passageirosResetados =
          vo.passageiros.map((p) => p.copyWith(statusEmbarque: 0)).toList();
      PacienteSyncService().resetarStatusPacientesParaNovaViagem(
        passageirosResetados.map((p) => p.pacienteId),
        viagemId: idDuplicada,
      );

      final novaViagem = ViagemModel(
        id: idDuplicada,
        motoristaId: '',
        motoristaNome: '',
        veiculoId: vo.veiculoId,
        veiculoPlaca: vo.veiculoPlaca,
        veiculoModelo: vo.veiculoModelo,
        kmInicial: 0,
        cidadeDestino: vo.cidadeDestino,
        nomeHorario: vo.nomeHorario,
        dataViagem: dataDestinoFmt,
        dataHoraInicio: novaHora,
        status: 'planejada',
        observacoes: vo.observacoes,
        passageiros: passageirosResetados,
        passageirosIds: List.from(vo.passageirosIds),
        codigosAcesso: codigosDup,
        codigosHash: hashesDup,
        sessaoId: null,
      );

      _todasViagensMemoria.add(novaViagem);
      duplicadas.add(novaViagem);
      for (final pv in novaViagem.passageiros) {
        _sincronizarPassageiroEmMemoriaPorViagem(novaViagem.id, pv);
      }

      if (_isFirebaseDisponivel()) {
        try {
          await FirebaseFirestore.instance
              .collection('viagens')
              .doc(novaViagem.id)
              .set(novaViagem.toMap());
          _totalGravacoesFirestoreJornada++;
        } on FirebaseException catch (e) {
          _tratarFalhaFirestore(
            'duplicar_viagens_dia',
            e,
            onRollback: () {
              _todasViagensMemoria.removeWhere((v) => v.id == novaViagem.id);
              duplicadas.removeWhere((v) => v.id == novaViagem.id);
              _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
            },
          );
        } catch (e) {
          _tratarFalhaFirestore('duplicar_viagens_dia', e);
        }
      }
    }

    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    return duplicadas;
  }

  /// Reordena a sequência de embarque dos passageiros de um Horário de Viagem.
  Future<ResultadoOperacaoViagem> reordenarPassageiros(
    String viagemId,
    List<PassageiroViagemModel> novosPassageiros, {
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      return ResultadoOperacaoViagem.erro(
        'Apenas administradores podem reordenar a ordem de embarque.',
      );
    }

    final index = _todasViagensMemoria.indexWhere((v) => v.id == viagemId);
    if (index == -1) {
      return ResultadoOperacaoViagem.erro('Horário não encontrado.');
    }
    final viagemAnterior = _todasViagensMemoria[index];

    final reordenados = <PassageiroViagemModel>[
      for (int i = 0; i < novosPassageiros.length; i++)
        novosPassageiros[i].copyWith(ordemEmbarque: i + 1),
    ];

    final viagemAtualizada = viagemAnterior.copyWith(
      passageiros: reordenados,
      passageirosIds: reordenados
          .expand((p) => [p.pacienteId, if (p.acompanhanteId != null) p.acompanhanteId!])
          .where((id) => id.isNotEmpty)
          .toList(),
    );

    _aplicarAtualizacaoHorarioEmMemoria(
      index: index,
      viagemAtualizada: viagemAtualizada,
    );

    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagemId)
            .set(viagemAtualizada.toMap(), SetOptions(merge: true));
        _totalGravacoesFirestoreJornada++;
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore(
          'reordenar_passageiros',
          e,
          onRollback: () {
            _todasViagensMemoria[index] = viagemAnterior;
            _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
          },
        );
      } catch (e) {
        _tratarFalhaFirestore('reordenar_passageiros', e);
      }
    }

    return ResultadoOperacaoViagem.sucesso(viagemAtualizada);
  }

  // ===========================================================================
  // SEÇÃO: Suporte a Testes Unitários Determinísticos
  // ===========================================================================

  /// Restaura caches internos e notifica as streams para execução isolada de testes.
  void resetParaTestes({
    List<VeiculoModel>? veiculosIniciais,
    ViagemModel? viagemAtivaInicial,
    SessaoVeiculoModel? sessaoAtivaInicial,
    List<ViagemModel>? viagensAtivasIniciais,
    List<ViagemModel>? todasViagensIniciais,
  }) {
    _sessaoFinalizadaPeloMotorista = false;
    _sessoesAtivasPorMotorista.clear();
    _perfisPacientesPorId.clear();
    _viagensComEscritaEmVoo.clear();
    _totalGravacoesFirestoreJornada = 0;
    executorPersistenciaRemotaOverride = null;
    _sessaoAtiva = sessaoAtivaInicial;
    if (sessaoAtivaInicial != null &&
        sessaoAtivaInicial.motoristaId.isNotEmpty) {
      _sessoesAtivasPorMotorista[sessaoAtivaInicial.motoristaId] =
          sessaoAtivaInicial;
    }
    _sessaoAtivaController.add(_sessaoAtiva);
    _viagensConcluidasNaSessao.clear();

    _viagensAtivasMemoria.clear();
    if (viagensAtivasIniciais != null) {
      _viagensAtivasMemoria.addAll(viagensAtivasIniciais);
    } else if (viagemAtivaInicial != null) {
      _viagensAtivasMemoria.add(viagemAtivaInicial);
    }

    _todasViagensMemoria.clear();
    if (todasViagensIniciais != null) {
      _todasViagensMemoria.addAll(todasViagensIniciais);
    } else if (viagensAtivasIniciais != null) {
      _todasViagensMemoria.addAll(viagensAtivasIniciais);
    } else if (viagemAtivaInicial != null) {
      _todasViagensMemoria.add(viagemAtivaInicial);
    }

    _viagemAtiva = viagemAtivaInicial ??
        (_viagensAtivasMemoria.isNotEmpty ? _viagensAtivasMemoria.first : null);

    for (final v in _todasViagensMemoria) {
      for (final pv in v.passageiros) {
        _sincronizarPassageiroEmMemoriaPorViagem(v.id, pv);
      }
    }
    for (final v in _viagensAtivasMemoria) {
      for (final pv in v.passageiros) {
        if (PacienteSyncService().obterPacienteMemoria(
              pv.pacienteId,
              viagemId: v.id,
            ) ==
            null) {
          _sincronizarPassageiroEmMemoriaPorViagem(v.id, pv);
        }
      }
    }
    _emitirStreamsViagens();

    _veiculosMemoria.clear();
    if (veiculosIniciais != null) {
      _veiculosMemoria.addAll(veiculosIniciais);
    } else {
      _inicializado = false;
      _inicializarDadosBase();
    }
    _veiculosController
        .add(ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria));
  }
}
