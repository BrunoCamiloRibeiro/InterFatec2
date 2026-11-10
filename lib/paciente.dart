import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'components/banner_reversao_paciente.dart';
import 'components/card_dados_consulta.dart';
import 'components/card_identificacao_paciente.dart';
import 'components/card_tracking_paciente.dart';
import 'models/localizacao_motorista_model.dart';
import 'models/paciente_model.dart';
import 'models/viagem_model.dart';
import 'services/auth_service.dart';
import 'services/paciente_sync_service.dart';
import 'services/viagem_service.dart';

/// Tela principal do Paciente: exibe identificação, dados da consulta,
/// ações com janela de reversão ("Estou Pronto" / "Fui embora") e rastreamento.
class Paciente extends StatefulWidget {
  final String? pacienteId;
  final Stream<PacienteModel?>? pacienteStreamOverride;
  final PacienteSyncService? syncServiceOverride;
  final Stream<List<LocalizacaoMotoristaModel>>? motoristasStreamOverride;

  const Paciente({
    super.key,
    this.pacienteId,
    this.pacienteStreamOverride,
    this.syncServiceOverride,
    this.motoristasStreamOverride,
  });

  @override
  State<Paciente> createState() => _PacienteState();
}

class _PacienteState extends State<Paciente> {
  late final PacienteSyncService _syncService;
  late Stream<PacienteModel?> _pacienteStream;
  StreamSubscription<List<ViagemModel>>? _viagensSub;
  StreamSubscription<({String? viagemId, PacienteModel paciente})>?
      _syncPorViagemSub;
  StreamSubscription<
    ({
      String? viagemId,
      String pacienteId,
      String mensagem,
      PacienteModel estadoRevertido,
    })
  >?
      _falhasSyncSub;
  bool _processandoAcao = false;

  @override
  void initState() {
    super.initState();
    _syncService = widget.syncServiceOverride ?? PacienteSyncService();
    _pacienteStream = _carregarPaciente();

    _viagensSub = ViagemService().todasViagensStream.listen((_) {
      if (mounted) setState(() {});
    });
    _syncPorViagemSub = _syncService.alteracoesPorViagemStream.listen((_) {
      if (mounted) setState(() {});
    });
    _falhasSyncSub = _syncService.falhasPorViagemStream.listen((falha) {
      final idViagem = falha.viagemId;
      if (idViagem != null && idViagem.isNotEmpty) {
        unawaited(
          ViagemService().atualizarStatusPassageiroNaViagem(
            viagemId: idViagem,
            pacienteId: falha.pacienteId,
            novoStatus: falha.estadoRevertido.status,
            prontoRetorno: falha.estadoRevertido.prontoRetorno,
            janelaReversao: falha.estadoRevertido.janelaReversao,
            limparJanelaReversao: falha.estadoRevertido.janelaReversao == null,
            persistirRemoto: false,
          ),
        );
      }
      if (mounted) {
        setState(() {});
        _exibirSnackBar(falha.mensagem, const Color(0xFFDC2626));
      }
    });
  }

  @override
  void dispose() {
    _viagensSub?.cancel();
    _syncPorViagemSub?.cancel();
    _falhasSyncSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Paciente oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pacienteId != widget.pacienteId ||
        oldWidget.pacienteStreamOverride != widget.pacienteStreamOverride) {
      _pacienteStream = _carregarPaciente();
    }
  }

  void _exibirSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor));
  }

  /// Executa diálogo de confirmação + transição otimista com rollback e feedback visual.
  Future<void> _confirmarEEfetuarAcaoPaciente(
    PacienteModel paciente, {
    String? mensagemConfirmacao,
    Color corBotaoConfirmar = const Color(0xFF0F172A),
    required String prefixoIdempotencia,
    required Color corSucesso,
    required int statusFallback,
    required bool prontoFallback,
    required Future<ResultadoOperacaoPaciente> Function(
      String? viagemId,
      String key,
    )
        executar,
  }) async {
    if (mensagemConfirmacao != null) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tem certeza dessa ação?'),
          content: Text(mensagemConfirmacao),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: corBotaoConfirmar,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    setState(() => _processandoAcao = true);
    try {
      final (viagemAtual, _) =
          _localizarViagemEPassageiro(paciente.id, cpf: paciente.cpf);
      final idViagem = viagemAtual?.id;
      if (idViagem != null) {
        _syncService.registrarPacienteEmMemoriaSeAusente(
          paciente,
          viagemId: idViagem,
        );
      }

      final key =
          '${paciente.id}_${prefixoIdempotencia}_${DateTime.now().millisecondsSinceEpoch}';
      final res = await executar(idViagem, key);

      if (res.sucesso && idViagem != null) {
        unawaited(
          ViagemService().atualizarStatusPassageiroNaViagem(
            viagemId: idViagem,
            pacienteId: paciente.id,
            novoStatus: res.paciente?.status ?? statusFallback,
            prontoRetorno: res.paciente?.prontoRetorno ?? prontoFallback,
            janelaReversao: res.paciente?.janelaReversao,
            limparJanelaReversao: res.paciente?.janelaReversao == null,
            persistirRemoto: false,
          ),
        );
      }

      if (!mounted) return;
      _exibirSnackBar(
        res.mensagem,
        res.sucesso ? corSucesso : Colors.black87,
      );
    } catch (e) {
      if (!mounted) return;
      _exibirSnackBar('Falha ao processar: $e', const Color(0xFFDC2626));
    } finally {
      if (mounted) {
        setState(() => _processandoAcao = false);
      }
    }
  }

  Future<void> _solicitarCancelamentoComConfirmacao(PacienteModel paciente) {
    return _confirmarEEfetuarAcaoPaciente(
      paciente,
      mensagemConfirmacao:
          'Deseja realmente informar que foi embora ou pegou carona? '
          'Você terá até 5 minutos para desfazer esta ação antes da consolidação.',
      corBotaoConfirmar: const Color(0xFFB83227),
      prefixoIdempotencia: 'cancel',
      corSucesso: const Color(0xFFB83227),
      statusFallback: 5,
      prontoFallback: false,
      executar: (viagemId, key) => _syncService.solicitarCancelamento(
        pacienteId: paciente.id,
        atorId: paciente.id,
        atorRole: 'paciente',
        viagemId: viagemId,
        idempotencyKey: key,
      ),
    );
  }

  Future<void> _sinalizarProntoComConfirmacao(PacienteModel paciente) {
    return _confirmarEEfetuarAcaoPaciente(
      paciente,
      mensagemConfirmacao:
          'Deseja avisar ao motorista que sua consulta médica terminou e você está pronto para o retorno? '
          'Você terá até 1 minuto para desfazer este aviso.',
      corBotaoConfirmar: const Color(0xFF0F172A),
      prefixoIdempotencia: 'pronto',
      corSucesso: const Color(0xFF16A34A),
      statusFallback: paciente.status,
      prontoFallback: true,
      executar: (viagemId, key) => _syncService.sinalizarPronto(
        pacienteId: paciente.id,
        atorId: paciente.id,
        atorRole: 'paciente',
        viagemId: viagemId,
        idempotencyKey: key,
      ),
    );
  }

  Future<void> _executarDesfazer(PacienteModel paciente) async {
    final janela = paciente.janelaReversao;
    if (janela == null) return;

    await _confirmarEEfetuarAcaoPaciente(
      paciente,
      prefixoIdempotencia: 'undo',
      corSucesso: const Color(0xFF2563EB),
      statusFallback: paciente.status,
      prontoFallback: paciente.prontoRetorno,
      executar: (viagemId, key) => (janela.acao == 'cancelamento_carona')
          ? _syncService.desfazerCancelamento(
              pacienteId: paciente.id,
              atorId: paciente.id,
              atorRole: 'paciente',
              viagemId: viagemId,
              idempotencyKey: key,
            )
          : _syncService.desfazerPronto(
              pacienteId: paciente.id,
              atorId: paciente.id,
              atorRole: 'paciente',
              viagemId: viagemId,
              idempotencyKey: key,
            ),
    );
  }

  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _documentoEstaInativo(Map<String, dynamic> dados) {
    final ativo = dados['ativo'];
    final status = dados['status']?.toString().toLowerCase().trim();
    final situacao = dados['situacao']?.toString().toLowerCase().trim();
    return ativo == false ||
        ativo == 'false' ||
        status == 'inativo' ||
        situacao == 'inativo' ||
        status == 'excluido' ||
        situacao == 'excluido';
  }

  (ViagemModel?, PassageiroViagemModel?) _localizarViagemEPassageiro(
    String pacienteId, {
    String? cpf,
  }) {
    final cpfLimpo = cpf?.replaceAll(RegExp(r'\D'), '') ?? '';
    final viagens = ViagemService().todasViagens;
    final idViagemAuth = FirebaseAuthService.pacienteViagemId?.trim();
    final ordenadas = [
      if (idViagemAuth != null && idViagemAuth.isNotEmpty)
        ...viagens.where((v) => v.id == idViagemAuth),
      ...viagens.where(
        (v) => v.id != idViagemAuth && v.isAtiva && !v.isCancelada && !v.isConcluida,
      ),
      ...viagens.where(
        (v) =>
            v.id != idViagemAuth && v.isPlanejada && !v.isCancelada && !v.isConcluida,
      ),
      ...viagens.where(
        (v) => v.id != idViagemAuth && !v.isAtiva && !v.isPlanejada,
      ),
    ];

    for (final v in ordenadas) {
      for (final p in v.passageiros) {
        if (p.pacienteId == pacienteId) return (v, p);
        if (cpfLimpo.isNotEmpty && p.pacienteCpf != null) {
          final pCpfLimpo = p.pacienteCpf!.replaceAll(RegExp(r'\D'), '');
          if (pCpfLimpo == cpfLimpo) return (v, p);
        }
      }
    }
    return (null, null);
  }

  PacienteModel _enriquecerComDadosViagem(PacienteModel paciente) {
    final (viagemEncontrada, pv) =
        _localizarViagemEPassageiro(paciente.id, cpf: paciente.cpf);
    if (pv == null) return paciente;

    final pMem = viagemEncontrada != null
        ? _syncService.obterPacienteMemoria(
            pv.pacienteId,
            viagemId: viagemEncontrada.id,
          )
        : null;
    final usarEstadoViagem =
        widget.pacienteStreamOverride == null && viagemEncontrada != null;

    final localConsultaVazio = paciente.localConsulta.trim().isEmpty ||
        paciente.localConsulta.trim() == 'Local da consulta não informado';
    final acompNomeVazio = paciente.nomeAcompanhante == null ||
        paciente.nomeAcompanhante!.trim().isEmpty;
    final acompTelVazio = paciente.telAcompanhante == null ||
        paciente.telAcompanhante!.trim().isEmpty;

    return PacienteModel(
      id: paciente.id,
      nome: (paciente.nome.trim().isEmpty ||
                  paciente.nome == 'Paciente sem nome') &&
              pv.pacienteNome.trim().isNotEmpty
          ? pv.pacienteNome.trim()
          : paciente.nome,
      cpf: (paciente.cpf.trim().isEmpty || paciente.cpf == '000.000.000-00') &&
              pv.pacienteCpf != null &&
              pv.pacienteCpf!.trim().isNotEmpty
          ? pv.pacienteCpf!.trim()
          : paciente.cpf,
      telefone: paciente.telefone,
      enderecoPaciente: paciente.enderecoPaciente,
      localConsulta: localConsultaVazio && pv.localDestino.trim().isNotEmpty
          ? pv.localDestino.trim()
          : paciente.localConsulta,
      localSaida:
          paciente.localSaida.trim().isEmpty && pv.localOrigem.trim().isNotEmpty
              ? pv.localOrigem.trim()
              : paciente.localSaida,
      horarioConsulta: paciente.horarioConsulta.trim().isEmpty &&
              pv.horarioAtendimento.trim().isNotEmpty
          ? pv.horarioAtendimento.trim()
          : paciente.horarioConsulta,
      status: usarEstadoViagem
          ? (pMem?.status ?? pv.statusEmbarque)
          : paciente.status,
      nomeAcompanhante: acompNomeVazio &&
              pv.acompanhanteNome != null &&
              pv.acompanhanteNome!.trim().isNotEmpty
          ? pv.acompanhanteNome!.trim()
          : paciente.nomeAcompanhante,
      telAcompanhante: acompTelVazio &&
              pv.acompanhanteTelefone != null &&
              pv.acompanhanteTelefone!.trim().isNotEmpty
          ? pv.acompanhanteTelefone!.trim()
          : paciente.telAcompanhante,
      cpfAcompanhante: paciente.cpfAcompanhante,
      rg: paciente.rg,
      cnh: paciente.cnh,
      role: paciente.role,
      ativo: paciente.ativo,
      criadoEm: paciente.criadoEm,
      prontoRetorno: usarEstadoViagem
          ? (pMem?.prontoRetorno ?? pv.prontoRetorno)
          : paciente.prontoRetorno,
      janelaReversao: usarEstadoViagem
          ? (pMem?.janelaReversao ?? pv.janelaReversao)
          : paciente.janelaReversao,
      ultimaIdempotencyKey: paciente.ultimaIdempotencyKey,
    );
  }

  PacienteModel? _buscarPacienteEmViagem(String docId) {
    final (viagem, pv) = _localizarViagemEPassageiro(docId);
    if (pv == null) return null;
    final pMem = viagem != null
        ? _syncService.obterPacienteMemoria(pv.pacienteId, viagemId: viagem.id)
        : null;
    final modelo = PacienteModel(
      id: pv.pacienteId,
      nome: pv.pacienteNome,
      cpf: pv.pacienteCpf ?? '000.000.000-00',
      telefone: pv.pacienteTelefone ?? 'Telefone não informado',
      enderecoPaciente: 'Endereço não informado',
      localConsulta: pv.localDestino.trim().isNotEmpty
          ? pv.localDestino.trim()
          : 'Local da consulta não informado',
      localSaida: pv.localOrigem.trim(),
      horarioConsulta: pv.horarioAtendimento.trim(),
      status: pMem?.status ?? pv.statusEmbarque,
      nomeAcompanhante: pv.acompanhanteNome,
      telAcompanhante: pv.acompanhanteTelefone,
      prontoRetorno: pMem?.prontoRetorno ?? pv.prontoRetorno,
      janelaReversao: pMem?.janelaReversao ?? pv.janelaReversao,
    );
    if (viagem != null) {
      _syncService.registrarPacienteEmMemoriaSeAusente(
        modelo,
        viagemId: viagem.id,
      );
    }
    return modelo;
  }

  PacienteModel _processarDocumentoUsuario(String docId, Map<String, dynamic> dados) {
    final base = PacienteModel.fromMap(dados, docId: docId);
    final (viagemBase, _) = _localizarViagemEPassageiro(base.id, cpf: base.cpf);
    final enriquecido = _enriquecerComDadosViagem(base);
    _syncService.registrarPacienteEmMemoriaSeAusente(
      enriquecido,
      viagemId: viagemBase?.id,
    );
    return enriquecido;
  }

  Stream<PacienteModel?> _carregarPaciente() {
    if (widget.pacienteStreamOverride != null) {
      return widget.pacienteStreamOverride!;
    }
    if (!_isFirebaseDisponivel()) return Stream.value(null);

    final idParam = widget.pacienteId?.trim();
    final idAuth = FirebaseAuthService().currentUserId?.trim();
    final docIdAlvo = (idParam != null && idParam.isNotEmpty)
        ? idParam
        : ((idAuth != null && idAuth.isNotEmpty) ? idAuth : null);

    if (docIdAlvo != null && docIdAlvo.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('usuarios')
          .doc(docIdAlvo)
          .snapshots()
          .map((doc) {
            if (doc.exists && doc.data() != null) {
              if (_documentoEstaInativo(doc.data()!)) return null;
              return _processarDocumentoUsuario(doc.id, doc.data()!);
            }
            return _buscarPacienteEmViagem(docIdAlvo);
          });
    }

    return FirebaseFirestore.instance
        .collection('usuarios')
        .where('role', isEqualTo: 'paciente')
        .snapshots()
        .map((snapshot) {
          for (final doc in snapshot.docs) {
            if (_documentoEstaInativo(doc.data())) continue;
            return _processarDocumentoUsuario(doc.id, doc.data());
          }
          return null;
        });
  }

  String? _resolverMensagemApoio(PacienteModel paciente, bool temTimerAtivo) {
    if (temTimerAtivo) {
      return paciente.janelaReversao?.acao == 'cancelamento_carona'
          ? 'Cancelamento em andamento. Você pode desfazer no banner acima.'
          : 'Prontidão sinalizada. Você pode desfazer no banner acima.';
    }
    return switch (paciente.status) {
      1 => 'Você está a bordo da van a caminho da consulta médica.',
      3 => 'Você está a bordo da van retornando para sua residência.',
      2 when paciente.prontoRetorno =>
        'Motorista já avisado. Aguarde o veículo no ponto de encontro.',
      4 => 'Transporte concluído com sucesso. Tenha um ótimo dia!',
      5 => 'Agendamento cancelado.',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PacienteModel?>(
      stream: _pacienteStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final rawPaciente = snapshot.data;
        final paciente =
            rawPaciente != null ? _enriquecerComDadosViagem(rawPaciente) : null;

        if (paciente == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(title: const Text('Painel do Paciente')),
            body: const Center(
              child: Text(
                'Nenhum dado de paciente encontrado.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        final bool temTimerAtivo = paciente.janelaReversao != null &&
            paciente.janelaReversao!.estaAtiva() &&
            ((paciente.janelaReversao!.acao == 'cancelamento_carona' &&
                    paciente.status == 5) ||
                (paciente.janelaReversao!.acao == 'pronto_retorno' &&
                    paciente.status == 2 &&
                    paciente.prontoRetorno));

        // Dentro da van (status 1 ou 3), ambos os botões ficam bloqueados.
        final bool fuiEmboraHabilitado = !temTimerAtivo &&
            !_processandoAcao &&
            (paciente.status == 0 || paciente.status == 2);

        final bool estouProntoHabilitado = !temTimerAtivo &&
            !_processandoAcao &&
            !paciente.prontoRetorno &&
            paciente.status == 2;

        final String? mensagemApoio =
            _resolverMensagemApoio(paciente, temTimerAtivo);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 2,
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
              'Painel do Paciente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                key: const Key('botaoLogoutPaciente'),
                icon: const Icon(Icons.logout),
                color: Colors.white,
                tooltip: 'Sair da conta',
                onPressed: () async {
                  await FirebaseAuthService().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardIdentificacaoPaciente(
                    nome: paciente.nome,
                    cpf: paciente.cpf,
                    status: paciente.status,
                  ),
                  const SizedBox(height: 16),
                  CardDadosConsulta(
                    localConsulta: paciente.localConsulta,
                    horarioConsulta: paciente.horarioConsulta,
                    localSaida: paciente.localSaida,
                    enderecoPaciente: paciente.enderecoPaciente,
                    nomeAcompanhante: paciente.nomeAcompanhante,
                  ),
                  const SizedBox(height: 16),
                  if (temTimerAtivo && paciente.janelaReversao != null)
                    BannerReversaoPaciente(
                      janela: paciente.janelaReversao!,
                      carregando: _processandoAcao,
                      onDesfazer: () => _executarDesfazer(paciente),
                    ),
                  _construirBotoesAcao(
                    paciente: paciente,
                    fuiEmboraHabilitado: fuiEmboraHabilitado,
                    estouProntoHabilitado: estouProntoHabilitado,
                  ),
                  if (mensagemApoio != null) ...[
                    const SizedBox(height: 10),
                    _construirBannerMensagemApoio(mensagemApoio),
                  ],
                  const SizedBox(height: 16),
                  CardTrackingPaciente(
                    motoristasStreamOverride: widget.motoristasStreamOverride,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construirBotoesAcao({
    required PacienteModel paciente,
    required bool fuiEmboraHabilitado,
    required bool estouProntoHabilitado,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              key: const Key('botao_fui_embora'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: fuiEmboraHabilitado
                      ? const Color(0xFFB83227)
                      : Colors.grey.shade400,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: fuiEmboraHabilitado
                    ? const Color(0xFFFFFDF8)
                    : const Color(0xFFF1F5F9),
              ),
              icon: Icon(
                Icons.cancel_outlined,
                color: fuiEmboraHabilitado
                    ? const Color(0xFFB83227)
                    : Colors.grey.shade400,
                size: 18,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Fui embora',
                  style: TextStyle(
                    color: fuiEmboraHabilitado
                        ? const Color(0xFFB83227)
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              onPressed: fuiEmboraHabilitado
                  ? () => _solicitarCancelamentoComConfirmacao(paciente)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              key: const Key('botao_estou_pronto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: estouProntoHabilitado
                    ? const Color(0xFF0F172A)
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: estouProntoHabilitado ? 2 : 0,
              ),
              icon: const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: Colors.white,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  paciente.prontoRetorno ? 'Pronto (Avisado)' : 'Estou Pronto',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              onPressed: estouProntoHabilitado
                  ? () => _sinalizarProntoComConfirmacao(paciente)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirBannerMensagemApoio(String mensagemApoio) {
    return Container(
      key: const Key('mensagem_apoio_botoes_inativos'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                mensagemApoio,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
