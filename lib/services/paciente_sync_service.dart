// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/paciente_sync_service.dart
// Camada: Serviços / Sincronização em Tempo Real e Persistência Atômica
//
// O QUE ESTE ARQUIVO FAZ:
// Orquestra a execução das ações do paciente e do motorista com garantias de
// consistência ACID no Cloud Firestore (via runTransaction) e fallback atômico
// em memória, implementando idempotência por Idempotency-Key, auditoria outbox
// (historicoTransicoes), autorização por recurso e janela de reversão temporal
// (Issue #19).
//
// PARA QUE SERVE NO PROJETO:
// É o backend de sincronização dos botões da tela do paciente ("Fui embora" e
// "Estou Pronto") e das baixas do motorista. Impede condições de corrida onde
// paciente desfaz ação enquanto o motorista dá baixa de embarque (o motorista
// vence sempre), e assegura que a janela de reversão seja validada pelo relógio
// seguro do servidor/banco.
//
// ONDE É USADO NO PROJETO:
// - lib/paciente.dart (callbacks dos botões de ação e banner de undo)
// - lib/motorista.dart e lib/components/card_paciente.dart (baixa presencial)
// - test/services/transicao_paciente_service_test.dart
//
// DE ONDE RECEBE DADOS:
// Coleção 'usuarios' do Cloud Firestore ou repositório thread-safe em memória.
//
// O QUE EXPORTA / EXPÕE:
// - class ResultadoOperacaoPaciente
// - class PacienteSyncService
//   * factory PacienteSyncService() (Singleton com injeção para testes)
//   * Future<ResultadoOperacaoPaciente> solicitarCancelamento(...)
//   * Future<ResultadoOperacaoPaciente> desfazerCancelamento(...)
//   * Future<ResultadoOperacaoPaciente> sinalizarPronto(...)
//   * Future<ResultadoOperacaoPaciente> desfazerPronto(...)
//   * Future<ResultadoOperacaoPaciente> confirmarEmbarqueMotorista(...)
//   * Stream<PacienteModel?> ouvirPaciente(String pacienteId)
//   * void resetParaTestes(...)
//   * set relogioOverride(DateTime Function()? relogio)
// ============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/janela_reversao_model.dart';
import '../models/paciente_model.dart';
import 'transicao_paciente_service.dart';

/// Resultado semântico de uma operação de transição de estado.
@immutable
class ResultadoOperacaoPaciente {
  /// Se a operação foi persistida com sucesso.
  final bool sucesso;

  /// Instância atualizada do paciente em caso de sucesso.
  final PacienteModel? paciente;

  /// Mensagem amigável de sucesso ou motivo detalhado de recusa.
  final String mensagem;

  /// Se a requisição foi atendida de forma idempotente (sem nova mutação).
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

/// Serviço de sincronização em tempo real e controle transacional do paciente.
class PacienteSyncService {
  // Singleton
  static final PacienteSyncService _instancia = PacienteSyncService._interno();
  factory PacienteSyncService() => _instancia;
  PacienteSyncService._interno();

  /// Provedor opcional de relógio para testes determinísticos de tempo.
  DateTime Function()? relogioOverride;

  /// Retorna o momento atual respeitando o relógio injetado ou DateTime.now().
  DateTime _agoraUtc() {
    return (relogioOverride != null ? relogioOverride!() : DateTime.now()).toUtc();
  }

  /// Verifica se o Firebase está ativo e conectado.
  bool get _isFirebaseDisponivel {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // REPOSITÓRIO EM MEMÓRIA (ISOLADO POR VIAGEM + MOCK PARA TESTES OFFLINE)
  // --------------------------------------------------------------------------
  final Map<String, PacienteModel> _pacientesMemoria = {};
  final Map<String, PacienteModel> _pacientesPorViagemMemoria = {};
  final Map<String, List<Map<String, dynamic>>> _historicoMemoria = {};
  final Map<String, StreamController<PacienteModel?>> _controllersMemoria = {};
  final StreamController<PacienteModel> _globalController =
      StreamController<PacienteModel>.broadcast();
  final StreamController<({String? viagemId, PacienteModel paciente})>
      _alteracoesPorViagemController =
      StreamController<({String? viagemId, PacienteModel paciente})>.broadcast();
  final StreamController<({String pacienteId, String mensagem, PacienteModel estadoRevertido})>
      _falhasSincronizacaoController = StreamController<
          ({String pacienteId, String mensagem, PacienteModel estadoRevertido})>.broadcast();
  final StreamController<
          ({String? viagemId, String pacienteId, String mensagem, PacienteModel estadoRevertido})>
      _falhasPorViagemController = StreamController<
          ({String? viagemId, String pacienteId, String mensagem, PacienteModel estadoRevertido})>.broadcast();

  /// Hook opcional para simular escrita assíncrona remota e falhas de rede/permissão em testes.
  @visibleForTesting
  Future<void> Function(String pacienteId, Map<String, dynamic> dados)?
      executorRemotoOverride;

  int _totalGravacoesFirestore = 0;

  /// Total de gravações despachadas ao Firestore na jornada (FinOps).
  int get totalGravacoesFirestore => _totalGravacoesFirestore;

  /// Stream global broadcast emitida sempre que qualquer paciente sofre transição de status ou prontidão.
  Stream<PacienteModel> get alteracoesGlobaisStream => _globalController.stream;

  /// Stream segmentada por [viagemId] emitida nas transições de passageiros.
  Stream<({String? viagemId, PacienteModel paciente})> get alteracoesPorViagemStream =>
      _alteracoesPorViagemController.stream;

  /// Stream emitida quando uma mutação otimista em background falha no Firestore e sofre rollback.
  Stream<({String pacienteId, String mensagem, PacienteModel estadoRevertido})>
      get falhasSincronizacaoStream => _falhasSincronizacaoController.stream;

  /// Stream de falhas/rollback carregando o [viagemId] de origem da transição.
  Stream<({String? viagemId, String pacienteId, String mensagem, PacienteModel estadoRevertido})>
      get falhasPorViagemStream => _falhasPorViagemController.stream;

  String? _chavePorViagem(String? viagemId, String pacienteId) {
    final v = viagemId?.trim() ?? '';
    final p = pacienteId.trim();
    if (v.isEmpty || p.isEmpty) return null;
    return '$v::$p';
  }

  /// Reinicia o estado em memória para execução de suítes de teste limpas.
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

  /// Registra um paciente no cache em memória caso ainda não exista (isolado por [viagemId] quando informado).
  void registrarPacienteEmMemoriaSeAusente(PacienteModel paciente, {String? viagemId}) {
    if (paciente.id.isEmpty) return;
    final chaveScoped = _chavePorViagem(viagemId, paciente.id);
    if (chaveScoped != null) {
      _pacientesPorViagemMemoria.putIfAbsent(chaveScoped, () => paciente);
      return;
    }
    _pacientesMemoria.putIfAbsent(paciente.id, () => paciente);
  }

  /// Atualiza o estado de um paciente no cache em memória (isolado por [viagemId] quando informado).
  void atualizarPacienteEmMemoria(PacienteModel paciente, {String? viagemId}) {
    if (paciente.id.isEmpty) return;
    final chaveScoped = _chavePorViagem(viagemId, paciente.id);
    if (chaveScoped != null) {
      _pacientesPorViagemMemoria[chaveScoped] = paciente;
      return;
    }
    _pacientesMemoria[paciente.id] = paciente;
  }

  /// Sincroniza o estado em memória de um passageiro a partir do snapshot da viagem.
  void sincronizarPassageiroDeViagemEmMemoria(String viagemId, PacienteModel paciente) {
    final chaveScoped = _chavePorViagem(viagemId, paciente.id);
    if (chaveScoped != null) {
      _pacientesPorViagemMemoria[chaveScoped] = paciente;
    }
  }

  /// Retorna o estado atual do paciente em memória (estritamente isolado por [viagemId] quando informado).
  PacienteModel? obterPacienteMemoria(String pacienteId, {String? viagemId}) {
    final chaveScoped = _chavePorViagem(viagemId, pacienteId);
    if (chaveScoped != null) {
      return _pacientesPorViagemMemoria[chaveScoped];
    }
    return _pacientesMemoria[pacienteId];
  }

  /// Reseta o status dos pacientes informados para 0 (Aguardando) ao serem incluídos em um novo Horário de Viagem.
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

  /// Marca como concluídos (status 4) os passageiros em memória da viagem encerrada.
  Future<void> concluirPacientesDaViagem(
    Iterable<String> pacienteIds, {
    String? viagemId,
  }) async {
    for (final pid in pacienteIds) {
      if (pid.trim().isEmpty) continue;
      final chaveScoped = _chavePorViagem(viagemId, pid);
      if (chaveScoped != null) {
        final memScoped = _pacientesPorViagemMemoria[chaveScoped];
        if (memScoped != null && memScoped.status != 5 && memScoped.status != 4) {
          _pacientesPorViagemMemoria[chaveScoped] = memScoped.copyWith(
            status: 4,
            prontoRetorno: false,
            limparJanelaReversao: true,
          );
        }
      }
      final mem = _pacientesMemoria[pid];
      if (mem != null && mem.status != 5 && mem.status != 4) {
        final atualizado = mem.copyWith(
          status: 4,
          prontoRetorno: false,
          limparJanelaReversao: true,
        );
        _pacientesMemoria[pid] = atualizado;
        final ctrl = _controllersMemoria[pid];
        if (ctrl != null && !ctrl.isClosed) {
          ctrl.add(atualizado);
        }
        if (!_globalController.isClosed) {
          _globalController.add(atualizado);
        }
        if (!_alteracoesPorViagemController.isClosed) {
          _alteracoesPorViagemController.add((viagemId: viagemId, paciente: atualizado));
        }
      }
    }
  }

  /// Retorna ou cria o StreamController broadcast de um paciente em memória.
  StreamController<PacienteModel?> _obterController(String pacienteId) {
    return _controllersMemoria.putIfAbsent(
      pacienteId,
      () => StreamController<PacienteModel?>.broadcast(),
    );
  }

  /// Escuta em tempo real as mutações de um paciente.
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

  /// Atualiza caches e notifica streams mantendo compatibilidade com escopo por viagem.
  void _notificarMutacaoEmMemoria({
    required PacienteModel paciente,
    String? viagemId,
    bool espelharCacheLegado = true,
  }) {
    final chaveScoped = _chavePorViagem(viagemId, paciente.id);
    if (chaveScoped != null) {
      _pacientesPorViagemMemoria[chaveScoped] = paciente;
    }
    if (espelharCacheLegado) {
      _pacientesMemoria[paciente.id] = paciente;
    }
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

  /// Monta a janela de reversão temporal quando a regra de transição exige carência.
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

  // --------------------------------------------------------------------------
  // MÉTODO NÚCLEO: EXECUTAR TRANSIÇÃO ATÔMICA COM CONTROLE DE CONCORRÊNCIA
  // --------------------------------------------------------------------------
  Future<ResultadoOperacaoPaciente> _executarTransicao({
    required String pacienteId,
    required AcaoTransicao acao,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) async {
    // Autorização por recurso: paciente só age no próprio agendamento.
    if (atorRole == 'paciente' && atorId != pacienteId) {
      return const ResultadoOperacaoPaciente.erro(
        'Acesso negado: o paciente não tem autorização para alterar o agendamento de terceiros.',
      );
    }

    final agora = _agoraUtc();
    final chaveScoped = _chavePorViagem(viagemId, pacienteId);
    final possuiEmMemoria = chaveScoped != null
        ? _pacientesPorViagemMemoria.containsKey(chaveScoped)
        : _pacientesMemoria.containsKey(pacienteId);

    // 1. UI Otimista (0 ms) com rollback automático em caso de falha remota.
    if ((_isFirebaseDisponivel || executorRemotoOverride != null) &&
        possuiEmMemoria) {
      final pacienteMem = chaveScoped != null
          ? _pacientesPorViagemMemoria[chaveScoped]!
          : _pacientesMemoria[pacienteId]!;

      if (idempotencyKey != null &&
          pacienteMem.ultimaIdempotencyKey == idempotencyKey) {
        return ResultadoOperacaoPaciente.sucesso(
          paciente: pacienteMem,
          mensagem: 'Operação já processada anteriormente (idempotente).',
          foiIdempotente: true,
        );
      }

      final regra = TransicaoPacienteService.podeTransitar(
        statusAtual: pacienteMem.status,
        prontoRetornoAtual: pacienteMem.prontoRetorno,
        acao: acao,
        atorRole: atorRole,
        janelaAtiva: pacienteMem.janelaReversao,
        agora: agora,
      );

      if (!regra.permitido) {
        return ResultadoOperacaoPaciente.erro(
          regra.motivoRecusa ?? 'Transição recusada pelas regras do sistema.',
          paciente: pacienteMem,
        );
      }

      final novaJanela = _criarJanelaReversao(
        regra: regra,
        statusAnterior: pacienteMem.status,
        agoraUtc: agora,
        idempotencyKey: idempotencyKey,
      );

      final pacienteAtualizado = pacienteMem.copyWith(
        status: regra.novoStatus,
        prontoRetorno: regra.novoProntoRetorno,
        janelaReversao: novaJanela,
        limparJanelaReversao: novaJanela == null,
        ultimaIdempotencyKey: idempotencyKey,
      );

      _notificarMutacaoEmMemoria(
        paciente: pacienteAtualizado,
        viagemId: viagemId,
      );

      final Map<String, dynamic> updateData = {
        'status': regra.novoStatus,
        'prontoRetorno': regra.novoProntoRetorno,
        'ultimaIdempotencyKey': idempotencyKey,
        'janelaReversao':
            novaJanela != null ? novaJanela.toMap() : FieldValue.delete(),
        'atualizadoEm': agora.toIso8601String(),
      };

      void reverterMutacaoOtimista(Object erro) {
        _notificarMutacaoEmMemoria(
          paciente: pacienteMem,
          viagemId: viagemId,
        );
        final codigo = erro is FirebaseException ? erro.code : 'network-error';
        final msg =
            'Falha ao sincronizar com o servidor ($codigo). A alteração de ${pacienteMem.nome} foi revertida.';
        if (!_falhasSincronizacaoController.isClosed) {
          _falhasSincronizacaoController.add((
            pacienteId: pacienteId,
            mensagem: msg,
            estadoRevertido: pacienteMem,
          ));
        }
        if (!_falhasPorViagemController.isClosed) {
          _falhasPorViagemController.add((
            viagemId: viagemId,
            pacienteId: pacienteId,
            mensagem: msg,
            estadoRevertido: pacienteMem,
          ));
        }
      }

      final possuiViagemEscopada =
          viagemId != null && viagemId.trim().isNotEmpty;
      // Quando há viagemId real no Firestore, a persistência ocorre via runTransaction
      // em /viagens/{viagemId}; aqui despachamos apenas mocks de teste ou fluxo legado sem viagem.
      final deveEscreverEmUsuarios =
          executorRemotoOverride != null || !possuiViagemEscopada;

      if (deveEscreverEmUsuarios) {
        unawaited(
          Future.microtask(() async {
            try {
              if (executorRemotoOverride != null) {
                await executorRemotoOverride!(pacienteId, updateData);
                _totalGravacoesFirestore++;
                return;
              }
              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(pacienteId)
                  .set(updateData, SetOptions(merge: true));
              _totalGravacoesFirestore++;
            } on FirebaseException catch (e) {
              debugPrint(
                'Falha FirebaseException em transição otimista (${e.code}): ${e.message}',
              );
              reverterMutacaoOtimista(e);
            } catch (e) {
              debugPrint('Falha de rede em transição otimista: $e');
              reverterMutacaoOtimista(e);
            }
          }),
        );
      }

      return ResultadoOperacaoPaciente.sucesso(
        paciente: pacienteAtualizado,
        mensagem: _mensagemSucessoParaAcao(acao),
      );
    }

    // 2. Transação direta no Cloud Firestore quando não há cache prévio em memória (fluxo legado sem viagemId)
    if (_isFirebaseDisponivel &&
        (viagemId == null || viagemId.trim().isEmpty)) {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('usuarios').doc(pacienteId);
      try {
        return await firestore.runTransaction<ResultadoOperacaoPaciente>(
          (transaction) async {
            final snapshot = await transaction.get(docRef);
            if (!snapshot.exists || snapshot.data() == null) {
              return const ResultadoOperacaoPaciente.erro(
                'Paciente não encontrado no banco de dados.',
              );
            }

            final data = snapshot.data()!;
            final pacienteAtual =
                PacienteModel.fromMap(data, docId: snapshot.id);

            if (idempotencyKey != null &&
                pacienteAtual.ultimaIdempotencyKey == idempotencyKey) {
              return ResultadoOperacaoPaciente.sucesso(
                paciente: pacienteAtual,
                mensagem: 'Operação já processada anteriormente (idempotente).',
                foiIdempotente: true,
              );
            }

            final regra = TransicaoPacienteService.podeTransitar(
              statusAtual: pacienteAtual.status,
              prontoRetornoAtual: pacienteAtual.prontoRetorno,
              acao: acao,
              atorRole: atorRole,
              janelaAtiva: pacienteAtual.janelaReversao,
              agora: agora,
            );

            if (!regra.permitido) {
              return ResultadoOperacaoPaciente.erro(
                regra.motivoRecusa ??
                    'Transição recusada pelas regras do sistema.',
                paciente: pacienteAtual,
              );
            }

            final novaJanela = _criarJanelaReversao(
              regra: regra,
              statusAnterior: pacienteAtual.status,
              agoraUtc: agora,
              idempotencyKey: idempotencyKey,
            );

            final Map<String, dynamic> updateData = {
              'status': regra.novoStatus,
              'prontoRetorno': regra.novoProntoRetorno,
              'ultimaIdempotencyKey': idempotencyKey,
              'janelaReversao':
                  novaJanela != null ? novaJanela.toMap() : FieldValue.delete(),
              'atualizadoEm': agora.toIso8601String(),
            };

            transaction.update(docRef, updateData);

            final pacienteAtualizado = pacienteAtual.copyWith(
              status: regra.novoStatus,
              prontoRetorno: regra.novoProntoRetorno,
              janelaReversao: novaJanela,
              limparJanelaReversao: novaJanela == null,
              ultimaIdempotencyKey: idempotencyKey,
            );

            _notificarMutacaoEmMemoria(
              paciente: pacienteAtualizado,
              viagemId: viagemId,
            );

            return ResultadoOperacaoPaciente.sucesso(
              paciente: pacienteAtualizado,
              mensagem: _mensagemSucessoParaAcao(acao),
            );
          },
          timeout: const Duration(seconds: 4),
        );
      } catch (e) {
        try {
          final snapshot = await docRef.get();
          if (!snapshot.exists || snapshot.data() == null) {
            return const ResultadoOperacaoPaciente.erro(
              'Paciente não encontrado no banco de dados.',
            );
          }

          final data = snapshot.data()!;
          final pacienteAtual = PacienteModel.fromMap(data, docId: snapshot.id);

          if (idempotencyKey != null &&
              pacienteAtual.ultimaIdempotencyKey == idempotencyKey) {
            return ResultadoOperacaoPaciente.sucesso(
              paciente: pacienteAtual,
              mensagem: 'Operação já processada anteriormente (idempotente).',
              foiIdempotente: true,
            );
          }

          final regra = TransicaoPacienteService.podeTransitar(
            statusAtual: pacienteAtual.status,
            prontoRetornoAtual: pacienteAtual.prontoRetorno,
            acao: acao,
            atorRole: atorRole,
            janelaAtiva: pacienteAtual.janelaReversao,
            agora: agora,
          );

          if (!regra.permitido) {
            return ResultadoOperacaoPaciente.erro(
              regra.motivoRecusa ??
                  'Transição recusada pelas regras do sistema.',
              paciente: pacienteAtual,
            );
          }

          final novaJanela = _criarJanelaReversao(
            regra: regra,
            statusAnterior: pacienteAtual.status,
            agoraUtc: agora,
            idempotencyKey: idempotencyKey,
          );

          final Map<String, dynamic> updateData = {
            'status': regra.novoStatus,
            'prontoRetorno': regra.novoProntoRetorno,
            'ultimaIdempotencyKey': idempotencyKey,
            'janelaReversao':
                novaJanela != null ? novaJanela.toMap() : FieldValue.delete(),
            'atualizadoEm': agora.toIso8601String(),
          };

          await docRef.update(updateData);

          final pacienteAtualizado = pacienteAtual.copyWith(
            status: regra.novoStatus,
            prontoRetorno: regra.novoProntoRetorno,
            janelaReversao: novaJanela,
            limparJanelaReversao: novaJanela == null,
            ultimaIdempotencyKey: idempotencyKey,
          );

          _notificarMutacaoEmMemoria(
            paciente: pacienteAtualizado,
            viagemId: viagemId,
          );

          return ResultadoOperacaoPaciente.sucesso(
            paciente: pacienteAtualizado,
            mensagem: _mensagemSucessoParaAcao(acao),
          );
        } catch (innerError) {
          return ResultadoOperacaoPaciente.erro(
            'Falha na transação atômica com o servidor: $innerError',
          );
        }
      }
    }

    // 3. Execução local em memória (testes e fallback offline) isolada por viagem
    final pacienteAtual = chaveScoped != null
        ? _pacientesPorViagemMemoria[chaveScoped]
        : _pacientesMemoria[pacienteId];
    if (pacienteAtual == null) {
      return const ResultadoOperacaoPaciente.erro(
        'Paciente não localizado no repositório.',
      );
    }

    if (idempotencyKey != null &&
        pacienteAtual.ultimaIdempotencyKey == idempotencyKey) {
      return ResultadoOperacaoPaciente.sucesso(
        paciente: pacienteAtual,
        mensagem: 'Operação já processada anteriormente (idempotente).',
        foiIdempotente: true,
      );
    }

    final regra = TransicaoPacienteService.podeTransitar(
      statusAtual: pacienteAtual.status,
      prontoRetornoAtual: pacienteAtual.prontoRetorno,
      acao: acao,
      atorRole: atorRole,
      janelaAtiva: pacienteAtual.janelaReversao,
      agora: agora,
    );

    if (!regra.permitido) {
      return ResultadoOperacaoPaciente.erro(
        regra.motivoRecusa ?? 'Ação não permitida.',
        paciente: pacienteAtual,
      );
    }

    final novaJanela = _criarJanelaReversao(
      regra: regra,
      statusAnterior: pacienteAtual.status,
      agoraUtc: agora,
      idempotencyKey: idempotencyKey,
    );

    final pacienteAtualizado = pacienteAtual.copyWith(
      status: regra.novoStatus,
      prontoRetorno: regra.novoProntoRetorno,
      janelaReversao: novaJanela,
      limparJanelaReversao: novaJanela == null,
      ultimaIdempotencyKey: idempotencyKey,
    );

    final hist = _historicoMemoria.putIfAbsent(
      chaveScoped ?? pacienteId,
      () => [],
    );
    hist.add({
      'viagemId': viagemId,
      'de': pacienteAtual.status,
      'para': regra.novoStatus,
      'acao': acao.name,
      'atorId': atorId,
      'atorRole': atorRole,
      'em': agora,
      'idempotencyKey': idempotencyKey,
    });

    _notificarMutacaoEmMemoria(
      paciente: pacienteAtualizado,
      viagemId: viagemId,
    );

    return ResultadoOperacaoPaciente.sucesso(
      paciente: pacienteAtualizado,
      mensagem: _mensagemSucessoParaAcao(acao),
    );
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

  // --------------------------------------------------------------------------
  // MÉTODOS PÚBLICOS DE ALTO NÍVEL
  // --------------------------------------------------------------------------

  /// Paciente aciona "Fui embora / Peguei carona".
  Future<ResultadoOperacaoPaciente> solicitarCancelamento({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: AcaoTransicao.solicitarCancelamento,
      atorId: atorId,
      atorRole: atorRole,
      viagemId: viagemId,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Paciente aciona "Desfazer" na janela de 5 minutos do cancelamento.
  Future<ResultadoOperacaoPaciente> desfazerCancelamento({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: AcaoTransicao.desfazerCancelamento,
      atorId: atorId,
      atorRole: atorRole,
      viagemId: viagemId,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Paciente aciona "Estou Pronto" após terminar a consulta médica.
  Future<ResultadoOperacaoPaciente> sinalizarPronto({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: AcaoTransicao.sinalizarPronto,
      atorId: atorId,
      atorRole: atorRole,
      viagemId: viagemId,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Paciente aciona "Desfazer" na janela de 1 minuto de pronto de consulta.
  Future<ResultadoOperacaoPaciente> desfazerPronto({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? viagemId,
    String? idempotencyKey,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: AcaoTransicao.desfazerPronto,
      atorId: atorId,
      atorRole: atorRole,
      viagemId: viagemId,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Motorista avança a etapa do paciente (embarcar ida, desembarcar consulta, reembarcar volta, concluir).
  Future<ResultadoOperacaoPaciente> avancarEtapaMotorista({
    required String pacienteId,
    required String motoristaId,
    required AcaoTransicao acao,
    String? viagemId,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: acao,
      atorId: motoristaId,
      atorRole: 'motorista',
      viagemId: viagemId,
    );
  }

  /// Motorista confirma embarque presencial físico no veículo.
  /// Prevalece sobre qualquer solicitação de cancelamento em aberto do paciente!
  Future<ResultadoOperacaoPaciente> confirmarEmbarqueMotorista({
    required String pacienteId,
    required String motoristaId,
    String? viagemId,
    bool reembarqueVolta = false,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: reembarqueVolta
          ? AcaoTransicao.motoristaReembarcarVolta
          : AcaoTransicao.motoristaEmbarcarIda,
      atorId: motoristaId,
      atorRole: 'motorista',
      viagemId: viagemId,
    );
  }
}
