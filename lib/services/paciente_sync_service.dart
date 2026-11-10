import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/janela_reversao_model.dart';
import '../models/paciente_model.dart';
import 'transicao_paciente_service.dart';

/// Resultado semântico de uma operação de transição de estado do passageiro.
@immutable
class ResultadoOperacaoPaciente {
  final bool sucesso;
  final PacienteModel? paciente;
  final String mensagem;
  final bool foiIdempotente;

  const ResultadoOperacaoPaciente.sucesso({
    required this.paciente,
    this.mensagem = 'Operação realizada com sucesso.',
    this.foiIdempotente = false,
  }) : sucesso = true;

  const ResultadoOperacaoPaciente.erro(
    this.mensagem, {
    this.paciente,
  })  : sucesso = false,
        foiIdempotente = false;
}

/// Camada de Serviço: orquestra transições de estado do paciente com
/// isolamento por viagem, UI otimista com rollback e transações ACID no Firestore.
class PacienteSyncService {
  static final PacienteSyncService _instancia = PacienteSyncService._interno();
  factory PacienteSyncService() => _instancia;
  PacienteSyncService._interno();

  /// Provedor opcional de relógio para testes determinísticos de janela temporal.
  DateTime Function()? relogioOverride;

  /// Hook de teste para simular gravação remota e falhas de rede/permissão.
  @visibleForTesting
  Future<void> Function(String pacienteId, Map<String, dynamic> dados)?
      executorRemotoOverride;

  // ===========================================================================
  // SEÇÃO: Repositório Local Isolado por Viagem e Streams Reativas
  // ===========================================================================
  final Map<String, PacienteModel> _pacientesMemoria = {};
  final Map<String, PacienteModel> _pacientesPorViagemMemoria = {};
  final Map<String, List<Map<String, dynamic>>> _historicoMemoria = {};
  final Map<String, StreamController<PacienteModel?>> _controllersMemoria = {};

  final StreamController<PacienteModel> _globalController =
      StreamController<PacienteModel>.broadcast();
  final StreamController<({String? viagemId, PacienteModel paciente})>
      _alteracoesPorViagemController =
      StreamController<({String? viagemId, PacienteModel paciente})>.broadcast();
  final StreamController<
          ({String pacienteId, String mensagem, PacienteModel estadoRevertido})>
      _falhasSincronizacaoController = StreamController<
          ({
            String pacienteId,
            String mensagem,
            PacienteModel estadoRevertido,
          })>.broadcast();
  final StreamController<
          ({
            String? viagemId,
            String pacienteId,
            String mensagem,
            PacienteModel estadoRevertido,
          })> _falhasPorViagemController = StreamController<
      ({
        String? viagemId,
        String pacienteId,
        String mensagem,
        PacienteModel estadoRevertido,
      })>.broadcast();

  int _totalGravacoesFirestore = 0;

  /// Total de gravações despachadas ao Firestore na jornada (auditoria FinOps).
  int get totalGravacoesFirestore => _totalGravacoesFirestore;

  Stream<PacienteModel> get alteracoesGlobaisStream => _globalController.stream;

  /// Stream segmentada por [viagemId] para isolar passageiros compartilhados entre viagens.
  Stream<({String? viagemId, PacienteModel paciente})>
      get alteracoesPorViagemStream => _alteracoesPorViagemController.stream;

  Stream<({String pacienteId, String mensagem, PacienteModel estadoRevertido})>
      get falhasSincronizacaoStream => _falhasSincronizacaoController.stream;

  Stream<
          ({
            String? viagemId,
            String pacienteId,
            String mensagem,
            PacienteModel estadoRevertido,
          })>
      get falhasPorViagemStream => _falhasPorViagemController.stream;

  DateTime _agoraUtc() =>
      (relogioOverride != null ? relogioOverride!() : DateTime.now()).toUtc();

  bool get _isFirebaseDisponivel {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Chave composta que evita vazamento de status de um paciente entre viagens distintas.
  String? _chavePorViagem(String? viagemId, String pacienteId) {
    final v = viagemId?.trim() ?? '';
    final p = pacienteId.trim();
    if (v.isEmpty || p.isEmpty) return null;
    return '$v::$p';
  }

  /// Reinicia caches e hooks em memória para isolamento entre casos de teste.
  void resetParaTestes([List<PacienteModel>? pacientesIniciais]) {
    _pacientesMemoria.clear();
    _pacientesPorViagemMemoria.clear();
    _historicoMemoria.clear();
    for (final ctrl in _controllersMemoria.values) {
      if (!ctrl.isClosed) ctrl.close();
    }
    _controllersMemoria.clear();
    relogioOverride = null;
    executorRemotoOverride = null;
    _totalGravacoesFirestore = 0;

    if (pacientesIniciais != null) {
      for (final p in pacientesIniciais) {
        _pacientesMemoria[p.id] = p;
      }
    }
  }

  void registrarPacienteEmMemoriaSeAusente(
    PacienteModel paciente, {
    String? viagemId,
  }) {
    if (paciente.id.isEmpty) return;
    final chaveScoped = _chavePorViagem(viagemId, paciente.id);
    if (chaveScoped != null) {
      _pacientesPorViagemMemoria.putIfAbsent(chaveScoped, () => paciente);
      return;
    }
    _pacientesMemoria.putIfAbsent(paciente.id, () => paciente);
  }

  void atualizarPacienteEmMemoria(
    PacienteModel paciente, {
    String? viagemId,
  }) {
    if (paciente.id.isEmpty) return;
    final chaveScoped = _chavePorViagem(viagemId, paciente.id);
    if (chaveScoped != null) {
      _pacientesPorViagemMemoria[chaveScoped] = paciente;
      return;
    }
    _pacientesMemoria[paciente.id] = paciente;
  }

  void sincronizarPassageiroDeViagemEmMemoria(
    String viagemId,
    PacienteModel paciente,
  ) {
    final chaveScoped = _chavePorViagem(viagemId, paciente.id);
    if (chaveScoped != null) {
      _pacientesPorViagemMemoria[chaveScoped] = paciente;
    }
  }

  /// Obtém o snapshot em memória do paciente (escopado por [viagemId] quando informado).
  PacienteModel? obterPacienteMemoria(String pacienteId, {String? viagemId}) {
    final chaveScoped = _chavePorViagem(viagemId, pacienteId);
    if (chaveScoped != null) {
      return _pacientesPorViagemMemoria[chaveScoped];
    }
    return _pacientesMemoria[pacienteId];
  }

  /// Reseta o status para 0 (Aguardando) ao incluir passageiros em uma nova viagem.
  void resetarStatusPacientesParaNovaViagem(
    Iterable<String> pacienteIds, {
    String? viagemId,
  }) {
    for (final pid in pacienteIds) {
      if (pid.trim().isEmpty) continue;
      final chaveScoped = _chavePorViagem(viagemId, pid);
      if (chaveScoped != null) {
        final memScoped = _pacientesPorViagemMemoria[chaveScoped];
        if (memScoped != null && memScoped.status != 0) {
          _pacientesPorViagemMemoria[chaveScoped] = memScoped.copyWith(
            status: 0,
            prontoRetorno: false,
            limparJanelaReversao: true,
          );
        }
      }
      final mem = _pacientesMemoria[pid];
      if (mem != null && mem.status != 0) {
        final resetado = mem.copyWith(
          status: 0,
          prontoRetorno: false,
          limparJanelaReversao: true,
        );
        _pacientesMemoria[pid] = resetado;
        final ctrl = _controllersMemoria[pid];
        if (ctrl != null && !ctrl.isClosed) {
          ctrl.add(resetado);
        }
        if (!_globalController.isClosed) {
          _globalController.add(resetado);
        }
        if (!_alteracoesPorViagemController.isClosed) {
          _alteracoesPorViagemController.add((viagemId: viagemId, paciente: resetado));
        }
      }
    }
  }

  StreamController<PacienteModel?> _obterController(String pacienteId) {
    return _controllersMemoria.putIfAbsent(
      pacienteId,
      () => StreamController<PacienteModel?>.broadcast(),
    );
  }

  /// Escuta em tempo real alterações cadastrais/operacionais de um paciente.
  Stream<PacienteModel?> ouvirPaciente(String pacienteId) {
    if (_isFirebaseDisponivel) {
      return FirebaseFirestore.instance
          .collection('usuarios')
          .doc(pacienteId)
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return PacienteModel.fromMap(doc.data()!, docId: doc.id);
      });
    }

    final ctrl = _obterController(pacienteId);
    final valorAtual = _pacientesMemoria[pacienteId];
    return Stream<PacienteModel?>.multi((listener) {
      listener.add(valorAtual);
      final sub = ctrl.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = () => sub.cancel();
    });
  }

  void _notificarMutacaoEmMemoria({
    required PacienteModel paciente,
    String? viagemId,
  }) {
    final chaveScoped = _chavePorViagem(viagemId, paciente.id);
    if (chaveScoped != null) {
      _pacientesPorViagemMemoria[chaveScoped] = paciente;
    }
    _pacientesMemoria[paciente.id] = paciente;

    final ctrl = _controllersMemoria[paciente.id];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(paciente);
    }
    if (!_globalController.isClosed) {
      _globalController.add(paciente);
    }
    if (!_alteracoesPorViagemController.isClosed) {
      _alteracoesPorViagemController.add((
        viagemId: viagemId,
        paciente: paciente,
      ));
    }
  }

  void _emitirRollbackOtimista({
    required PacienteModel estadoAnterior,
    required Object erro,
    String? viagemId,
  }) {
    _notificarMutacaoEmMemoria(
      paciente: estadoAnterior,
      viagemId: viagemId,
    );
    final codigo = erro is FirebaseException ? erro.code : 'network-error';
    final msg =
        'Falha ao sincronizar com o servidor ($codigo). A alteração de ${estadoAnterior.nome} foi revertida.';
    if (!_falhasSincronizacaoController.isClosed) {
      _falhasSincronizacaoController.add((
        pacienteId: estadoAnterior.id,
        mensagem: msg,
        estadoRevertido: estadoAnterior,
      ));
    }
    if (!_falhasPorViagemController.isClosed) {
      _falhasPorViagemController.add((
        viagemId: viagemId,
        pacienteId: estadoAnterior.id,
        mensagem: msg,
        estadoRevertido: estadoAnterior,
      ));
    }
  }

  // ===========================================================================
  // SEÇÃO: Máquina de Estados, Idempotência e Transações Atômicas
  // ===========================================================================
  JanelaReversaoModel? _criarJanelaReversao({
    required ResultadoTransicao regra,
    required int statusAnterior,
    required DateTime agoraUtc,
    String? idempotencyKey,
  }) {
    if (regra.duracaoJanelaSegundos == null || regra.acaoReversao == null) {
      return null;
    }
    return JanelaReversaoModel(
      acao: regra.acaoReversao!,
      iniciadoEm: agoraUtc,
      expiraEm: agoraUtc.add(Duration(seconds: regra.duracaoJanelaSegundos!)),
      estadoAnterior: statusAnterior,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Aplica idempotência e regras puras de domínio sobre [pacienteAtual],
  /// devolvendo o novo modelo e payload de persistência ou o motivo da recusa.
  ({
    ResultadoOperacaoPaciente? encerramentoAntecipado,
    PacienteModel? atualizado,
    Map<String, dynamic>? updateData,
    int? novoStatus,
  }) _avaliarTransicao({
    required PacienteModel pacienteAtual,
    required AcaoTransicao acao,
    required String atorRole,
    required DateTime agoraUtc,
    String? idempotencyKey,
    String motivoRecusaPadrao = 'Transição recusada pelas regras do sistema.',
  }) {
    if (idempotencyKey != null &&
        pacienteAtual.ultimaIdempotencyKey == idempotencyKey) {
      return (
        encerramentoAntecipado: ResultadoOperacaoPaciente.sucesso(
          paciente: pacienteAtual,
          mensagem: 'Operação já processada anteriormente (idempotente).',
          foiIdempotente: true,
        ),
        atualizado: null,
        updateData: null,
        novoStatus: null,
      );
    }

    final regra = TransicaoPacienteService.podeTransitar(
      statusAtual: pacienteAtual.status,
      prontoRetornoAtual: pacienteAtual.prontoRetorno,
      acao: acao,
      atorRole: atorRole,
      janelaAtiva: pacienteAtual.janelaReversao,
      agora: agoraUtc,
    );

    if (!regra.permitido) {
      return (
        encerramentoAntecipado: ResultadoOperacaoPaciente.erro(
          regra.motivoRecusa ?? motivoRecusaPadrao,
          paciente: pacienteAtual,
        ),
        atualizado: null,
        updateData: null,
        novoStatus: null,
      );
    }

    final novaJanela = _criarJanelaReversao(
      regra: regra,
      statusAnterior: pacienteAtual.status,
      agoraUtc: agoraUtc,
      idempotencyKey: idempotencyKey,
    );

    final pacienteAtualizado = pacienteAtual.copyWith(
      status: regra.novoStatus,
      prontoRetorno: regra.novoProntoRetorno,
      janelaReversao: novaJanela,
      limparJanelaReversao: novaJanela == null,
      ultimaIdempotencyKey: idempotencyKey,
    );

    final updateData = <String, dynamic>{
      'status': regra.novoStatus,
      'prontoRetorno': regra.novoProntoRetorno,
      'ultimaIdempotencyKey': idempotencyKey,
      'janelaReversao':
          novaJanela != null ? novaJanela.toMap() : FieldValue.delete(),
      'atualizadoEm': agoraUtc.toIso8601String(),
    };

    return (
      encerramentoAntecipado: null,
      atualizado: pacienteAtualizado,
      updateData: updateData,
      novoStatus: regra.novoStatus,
    );
  }

  /// Orquestra a transição escolhendo entre:
  /// 1) UI otimista em memória com persistência assíncrona / rollback;
  /// 2) Transação direta em `/usuarios/{id}` no fluxo legado sem viagem;
  /// 3) Execução local determinística (testes offline).
  Future<ResultadoOperacaoPaciente> _executarTransicao({
    required String pacienteId,
    required AcaoTransicao acao,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) async {
    // Autorização por recurso: paciente só pode alterar o próprio estado.
    if (atorRole == 'paciente' && atorId != pacienteId) {
      return const ResultadoOperacaoPaciente.erro(
        'Acesso negado: o paciente não tem autorização para alterar o agendamento de terceiros.',
      );
    }

    final agora = _agoraUtc();
    final chaveScoped = _chavePorViagem(viagemId, pacienteId);
    final pacienteMem = obterPacienteMemoria(pacienteId, viagemId: viagemId);

    // 1. UI Otimista (< 16ms) com rollback caso a gravação remota falhe.
    if ((_isFirebaseDisponivel || executorRemotoOverride != null) &&
        pacienteMem != null) {
      return _executarTransicaoOtimista(
        pacienteMem: pacienteMem,
        acao: acao,
        atorRole: atorRole,
        agora: agora,
        viagemId: viagemId,
        idempotencyKey: idempotencyKey,
      );
    }

    // 2. Transação direta no Cloud Firestore quando não há cache prévio (fluxo legado sem viagemId).
    if (_isFirebaseDisponivel &&
        (viagemId == null || viagemId.trim().isEmpty)) {
      return _executarTransicaoDiretaFirestore(
        pacienteId: pacienteId,
        acao: acao,
        atorRole: atorRole,
        agora: agora,
        viagemId: viagemId,
        idempotencyKey: idempotencyKey,
      );
    }

    // 3. Execução local em memória (testes offline) com auditoria em historicoMemoria.
    if (pacienteMem == null) {
      return const ResultadoOperacaoPaciente.erro(
        'Paciente não localizado no repositório.',
      );
    }

    final avaliacao = _avaliarTransicao(
      pacienteAtual: pacienteMem,
      acao: acao,
      atorRole: atorRole,
      agoraUtc: agora,
      idempotencyKey: idempotencyKey,
      motivoRecusaPadrao: 'Ação não permitida.',
    );
    if (avaliacao.encerramentoAntecipado != null) {
      return avaliacao.encerramentoAntecipado!;
    }

    final pacienteAtualizado = avaliacao.atualizado!;
    _historicoMemoria.putIfAbsent(chaveScoped ?? pacienteId, () => []).add({
      'viagemId': viagemId,
      'de': pacienteMem.status,
      'para': avaliacao.novoStatus,
      'acao': acao.name,
      'atorId': atorId,
      'atorRole': atorRole,
      'em': agora,
      'idempotencyKey': idempotencyKey,
    });

    _notificarMutacaoEmMemoria(paciente: pacienteAtualizado, viagemId: viagemId);
    return ResultadoOperacaoPaciente.sucesso(
      paciente: pacienteAtualizado,
      mensagem: _mensagemSucessoParaAcao(acao),
    );
  }

  Future<ResultadoOperacaoPaciente> _executarTransicaoOtimista({
    required PacienteModel pacienteMem,
    required AcaoTransicao acao,
    required String atorRole,
    required DateTime agora,
    String? viagemId,
    String? idempotencyKey,
  }) async {
    final avaliacao = _avaliarTransicao(
      pacienteAtual: pacienteMem,
      acao: acao,
      atorRole: atorRole,
      agoraUtc: agora,
      idempotencyKey: idempotencyKey,
    );
    if (avaliacao.encerramentoAntecipado != null) {
      return avaliacao.encerramentoAntecipado!;
    }

    final pacienteAtualizado = avaliacao.atualizado!;
    final updateData = avaliacao.updateData!;
    _notificarMutacaoEmMemoria(paciente: pacienteAtualizado, viagemId: viagemId);

    final possuiViagemEscopada =
        viagemId != null && viagemId.trim().isNotEmpty;
    // Quando há viagemId real, a persistência ocorre em `/viagens/{viagemId}` via ViagemService.
    final deveEscreverEmUsuarios =
        executorRemotoOverride != null || !possuiViagemEscopada;

    if (deveEscreverEmUsuarios) {
      unawaited(
        Future.microtask(() async {
          try {
            if (executorRemotoOverride != null) {
              await executorRemotoOverride!(pacienteMem.id, updateData);
              _totalGravacoesFirestore++;
              return;
            }
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(pacienteMem.id)
                .set(updateData, SetOptions(merge: true));
            _totalGravacoesFirestore++;
          } on FirebaseException catch (e) {
            debugPrint(
              'Falha FirebaseException em transição otimista (${e.code}): ${e.message}',
            );
            _emitirRollbackOtimista(
              estadoAnterior: pacienteMem,
              erro: e,
              viagemId: viagemId,
            );
          } catch (e) {
            debugPrint('Falha de rede em transição otimista: $e');
            _emitirRollbackOtimista(
              estadoAnterior: pacienteMem,
              erro: e,
              viagemId: viagemId,
            );
          }
        }),
      );
    }

    return ResultadoOperacaoPaciente.sucesso(
      paciente: pacienteAtualizado,
      mensagem: _mensagemSucessoParaAcao(acao),
    );
  }

  Future<ResultadoOperacaoPaciente> _executarTransicaoDiretaFirestore({
    required String pacienteId,
    required AcaoTransicao acao,
    required String atorRole,
    required DateTime agora,
    String? viagemId,
    String? idempotencyKey,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('usuarios').doc(pacienteId);

    ({ResultadoOperacaoPaciente resultado, Map<String, dynamic>? updateData})
        avaliarSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return (
          resultado: const ResultadoOperacaoPaciente.erro(
            'Paciente não encontrado no banco de dados.',
          ),
          updateData: null,
        );
      }
      final pacienteAtual =
          PacienteModel.fromMap(snapshot.data()!, docId: snapshot.id);
      final avaliacao = _avaliarTransicao(
        pacienteAtual: pacienteAtual,
        acao: acao,
        atorRole: atorRole,
        agoraUtc: agora,
        idempotencyKey: idempotencyKey,
      );
      if (avaliacao.encerramentoAntecipado != null) {
        return (
          resultado: avaliacao.encerramentoAntecipado!,
          updateData: null,
        );
      }
      return (
        resultado: ResultadoOperacaoPaciente.sucesso(
          paciente: avaliacao.atualizado!,
          mensagem: _mensagemSucessoParaAcao(acao),
        ),
        updateData: avaliacao.updateData,
      );
    }

    try {
      final res = await firestore.runTransaction<ResultadoOperacaoPaciente>(
        (transaction) async {
          final snapshot = await transaction.get(docRef);
          final saida = avaliarSnapshot(snapshot);
          if (saida.updateData != null) {
            transaction.update(docRef, saida.updateData!);
          }
          return saida.resultado;
        },
        timeout: const Duration(seconds: 4),
      );
      if (res.sucesso && !res.foiIdempotente && res.paciente != null) {
        _notificarMutacaoEmMemoria(paciente: res.paciente!, viagemId: viagemId);
      }
      return res;
    } catch (_) {
      try {
        final snapshot = await docRef.get();
        final saida = avaliarSnapshot(snapshot);
        if (saida.updateData != null) {
          await docRef.update(saida.updateData!);
          if (saida.resultado.paciente != null) {
            _notificarMutacaoEmMemoria(
              paciente: saida.resultado.paciente!,
              viagemId: viagemId,
            );
          }
        }
        return saida.resultado;
      } catch (innerError) {
        return ResultadoOperacaoPaciente.erro(
          'Falha na transação atômica com o servidor: $innerError',
        );
      }
    }
  }

  static String _mensagemSucessoParaAcao(AcaoTransicao acao) {
    return switch (acao) {
      AcaoTransicao.solicitarCancelamento =>
        'Aviso de cancelamento registrado. Você tem até 5 minutos para desfazer.',
      AcaoTransicao.desfazerCancelamento =>
        'Cancelamento desfeito com sucesso! Seu transporte segue ativo.',
      AcaoTransicao.sinalizarPronto =>
        'Aviso de término enviado ao motorista! Você tem até 1 minuto para desfazer.',
      AcaoTransicao.desfazerPronto =>
        'Aviso de prontidão cancelado com sucesso.',
      AcaoTransicao.motoristaEmbarcarIda =>
        'Embarque para a ida confirmado a bordo do veículo.',
      AcaoTransicao.motoristaDesembarcarConsulta =>
        'Desembarque no local de consulta confirmado.',
      AcaoTransicao.motoristaReembarcarVolta =>
        'Reembarque para a viagem de volta confirmado.',
      AcaoTransicao.motoristaConcluirViagem =>
        'Transporte do passageiro concluído com sucesso.',
    };
  }

  // ===========================================================================
  // SEÇÃO: API Pública de Ações (Paciente e Motorista)
  // ===========================================================================

  /// Paciente aciona "Fui embora / Peguei carona".
  Future<ResultadoOperacaoPaciente> solicitarCancelamento({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) =>
      _executarTransicao(
        pacienteId: pacienteId,
        acao: AcaoTransicao.solicitarCancelamento,
        atorId: atorId,
        atorRole: atorRole,
        viagemId: viagemId,
        idempotencyKey: idempotencyKey,
      );

  /// Paciente desfaz o cancelamento dentro da janela de 5 minutos.
  Future<ResultadoOperacaoPaciente> desfazerCancelamento({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) =>
      _executarTransicao(
        pacienteId: pacienteId,
        acao: AcaoTransicao.desfazerCancelamento,
        atorId: atorId,
        atorRole: atorRole,
        viagemId: viagemId,
        idempotencyKey: idempotencyKey,
      );

  /// Paciente sinaliza "Estou Pronto" após encerrar a consulta médica.
  Future<ResultadoOperacaoPaciente> sinalizarPronto({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) =>
      _executarTransicao(
        pacienteId: pacienteId,
        acao: AcaoTransicao.sinalizarPronto,
        atorId: atorId,
        atorRole: atorRole,
        viagemId: viagemId,
        idempotencyKey: idempotencyKey,
      );

  /// Paciente desfaz o aviso "Estou Pronto" dentro da janela de 1 minuto.
  Future<ResultadoOperacaoPaciente> desfazerPronto({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) =>
      _executarTransicao(
        pacienteId: pacienteId,
        acao: AcaoTransicao.desfazerPronto,
        atorId: atorId,
        atorRole: atorRole,
        viagemId: viagemId,
        idempotencyKey: idempotencyKey,
      );

  /// Motorista avança a etapa operacional do passageiro dentro da viagem.
  Future<ResultadoOperacaoPaciente> avancarEtapaMotorista({
    required String pacienteId,
    required String motoristaId,
    required AcaoTransicao acao,
    String? viagemId,
  }) =>
      _executarTransicao(
        pacienteId: pacienteId,
        acao: acao,
        atorId: motoristaId,
        atorRole: 'motorista',
        viagemId: viagemId,
      );

  /// Motorista confirma embarque presencial (prevalece sobre cancelamento em aberto).
  Future<ResultadoOperacaoPaciente> confirmarEmbarqueMotorista({
    required String pacienteId,
    required String motoristaId,
    String? viagemId,
    bool reembarqueVolta = false,
  }) =>
      _executarTransicao(
        pacienteId: pacienteId,
        acao: reembarqueVolta
            ? AcaoTransicao.motoristaReembarcarVolta
            : AcaoTransicao.motoristaEmbarcarIda,
        atorId: motoristaId,
        atorRole: 'motorista',
        viagemId: viagemId,
      );
}
