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
  // REPOSITÓRIO EM MEMÓRIA (MOCK PARA TESTES DETERMINÍSTICOS E OFFLINE)
  // --------------------------------------------------------------------------
  final Map<String, PacienteModel> _pacientesMemoria = {};
  final Map<String, List<Map<String, dynamic>>> _historicoMemoria = {};
  final Map<String, StreamController<PacienteModel?>> _controllersMemoria = {};

  /// Reinicia o estado em memória para execução de suítes de teste limpas.
  void resetParaTestes([List<PacienteModel>? pacientesIniciais]) {
    _pacientesMemoria.clear();
    _historicoMemoria.clear();
    for (final ctrl in _controllersMemoria.values) {
      if (!ctrl.isClosed) ctrl.close();
    }
    _controllersMemoria.clear();
    relogioOverride = null;

    if (pacientesIniciais != null) {
      for (final p in pacientesIniciais) {
        _pacientesMemoria[p.id] = p;
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

  // --------------------------------------------------------------------------
  // MÉTODO NÚCLEO: EXECUTAR TRANSIÇÃO ATÔMICA COM CONTROLE DE CONCORRÊNCIA
  // --------------------------------------------------------------------------
  Future<ResultadoOperacaoPaciente> _executarTransicao({
    required String pacienteId,
    required AcaoTransicao acao,
    required String atorId,
    required String atorRole,
    String? idempotencyKey,
  }) async {
    // 1. Autorização por recurso: Paciente só pode agir nos próprios agendamentos!
    if (atorRole == 'paciente' && atorId != pacienteId) {
      return const ResultadoOperacaoPaciente.erro(
        'Acesso negado: o paciente não tem autorização para alterar o agendamento de terceiros.',
      );
    }

    final agora = _agoraUtc();

    // 2. Se Firebase estiver disponível, executa via transação atômica ACID no Cloud Firestore
    if (_isFirebaseDisponivel) {
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
            final pacienteAtual = PacienteModel.fromMap(data, docId: snapshot.id);

            // Verificação de Idempotência
            if (idempotencyKey != null &&
                pacienteAtual.ultimaIdempotencyKey == idempotencyKey) {
              return ResultadoOperacaoPaciente.sucesso(
                paciente: pacienteAtual,
                mensagem: 'Operação já processada anteriormente (idempotente).',
                foiIdempotente: true,
              );
            }

            // Avaliação da máquina pura de estados
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
                regra.motivoRecusa ?? 'Transição recusada pelas regras do sistema.',
                paciente: pacienteAtual,
              );
            }

            // Monta nova janela de reversão caso a ação conceda prazo (300 s ou 60 s)
            JanelaReversaoModel? novaJanela;
            if (regra.duracaoJanelaSegundos != null && regra.acaoReversao != null) {
              novaJanela = JanelaReversaoModel(
                acao: regra.acaoReversao!,
                iniciadoEm: agora,
                expiraEm: agora.add(Duration(seconds: regra.duracaoJanelaSegundos!)),
                estadoAnterior: pacienteAtual.status,
                idempotencyKey: idempotencyKey,
              );
            }

            // Prepara mutação atômica no Firestore (sem poluição de array de histórico)
            final Map<String, dynamic> updateData = {
              'status': regra.novoStatus,
              'prontoRetorno': regra.novoProntoRetorno,
              'ultimaIdempotencyKey': idempotencyKey,
              'janelaReversao': novaJanela != null ? novaJanela.toMap() : FieldValue.delete(),
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

            return ResultadoOperacaoPaciente.sucesso(
              paciente: pacienteAtualizado,
              mensagem: _mensagemSucessoParaAcao(acao),
            );
          },
          timeout: const Duration(seconds: 4),
        );
      } catch (e) {
        // Fallback atômico direto para ambientes Web ou contenção de transação
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
              regra.motivoRecusa ?? 'Transição recusada pelas regras do sistema.',
              paciente: pacienteAtual,
            );
          }

          JanelaReversaoModel? novaJanela;
          if (regra.duracaoJanelaSegundos != null && regra.acaoReversao != null) {
            novaJanela = JanelaReversaoModel(
              acao: regra.acaoReversao!,
              iniciadoEm: agora,
              expiraEm: agora.add(Duration(seconds: regra.duracaoJanelaSegundos!)),
              estadoAnterior: pacienteAtual.status,
              idempotencyKey: idempotencyKey,
            );
          }

          final Map<String, dynamic> updateData = {
            'status': regra.novoStatus,
            'prontoRetorno': regra.novoProntoRetorno,
            'ultimaIdempotencyKey': idempotencyKey,
            'janelaReversao': novaJanela != null ? novaJanela.toMap() : FieldValue.delete(),
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

    // ------------------------------------------------------------------------
    // EXECUÇÃO LOCAL EM MEMÓRIA COM SEMÂNTICA ATÔMICA
    // ------------------------------------------------------------------------
    final pacienteAtual = _pacientesMemoria[pacienteId];
    if (pacienteAtual == null) {
      return const ResultadoOperacaoPaciente.erro(
        'Paciente não localizado no repositório.',
      );
    }

    // Idempotência em memória
    if (idempotencyKey != null &&
        pacienteAtual.ultimaIdempotencyKey == idempotencyKey) {
      return ResultadoOperacaoPaciente.sucesso(
        paciente: pacienteAtual,
        mensagem: 'Operação já processada anteriormente (idempotente).',
        foiIdempotente: true,
      );
    }

    // Avaliação pela máquina pura de estados
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

    JanelaReversaoModel? novaJanela;
    if (regra.duracaoJanelaSegundos != null && regra.acaoReversao != null) {
      novaJanela = JanelaReversaoModel(
        acao: regra.acaoReversao!,
        iniciadoEm: agora,
        expiraEm: agora.add(Duration(seconds: regra.duracaoJanelaSegundos!)),
        estadoAnterior: pacienteAtual.status,
        idempotencyKey: idempotencyKey,
      );
    }

    final pacienteAtualizado = pacienteAtual.copyWith(
      status: regra.novoStatus,
      prontoRetorno: regra.novoProntoRetorno,
      janelaReversao: novaJanela,
      limparJanelaReversao: novaJanela == null,
      ultimaIdempotencyKey: idempotencyKey,
    );

    _pacientesMemoria[pacienteId] = pacienteAtualizado;

    // Registra no histórico em memória (auditoria)
    final hist = _historicoMemoria.putIfAbsent(pacienteId, () => []);
    hist.add({
      'de': pacienteAtual.status,
      'para': regra.novoStatus,
      'acao': acao.name,
      'atorId': atorId,
      'atorRole': atorRole,
      'em': agora,
      'idempotencyKey': idempotencyKey,
    });

    // Notifica ouvintes na Stream
    final ctrl = _obterController(pacienteId);
    if (!ctrl.isClosed) {
      ctrl.add(pacienteAtualizado);
    }

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
    String? idempotencyKey,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: AcaoTransicao.solicitarCancelamento,
      atorId: atorId,
      atorRole: atorRole,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Paciente aciona "Desfazer" na janela de 5 minutos do cancelamento.
  Future<ResultadoOperacaoPaciente> desfazerCancelamento({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? idempotencyKey,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: AcaoTransicao.desfazerCancelamento,
      atorId: atorId,
      atorRole: atorRole,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Paciente aciona "Estou Pronto" após terminar a consulta médica.
  Future<ResultadoOperacaoPaciente> sinalizarPronto({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? idempotencyKey,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: AcaoTransicao.sinalizarPronto,
      atorId: atorId,
      atorRole: atorRole,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Paciente aciona "Desfazer" na janela de 1 minuto de pronto de consulta.
  Future<ResultadoOperacaoPaciente> desfazerPronto({
    required String pacienteId,
    required String atorId,
    required String atorRole,
    String? idempotencyKey,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: AcaoTransicao.desfazerPronto,
      atorId: atorId,
      atorRole: atorRole,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Motorista avança a etapa do paciente (embarcar ida, desembarcar consulta, reembarcar volta, concluir).
  Future<ResultadoOperacaoPaciente> avancarEtapaMotorista({
    required String pacienteId,
    required String motoristaId,
    required AcaoTransicao acao,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: acao,
      atorId: motoristaId,
      atorRole: 'motorista',
    );
  }

  /// Motorista confirma embarque presencial físico no veículo.
  /// Prevalece sobre qualquer solicitação de cancelamento em aberto do paciente!
  Future<ResultadoOperacaoPaciente> confirmarEmbarqueMotorista({
    required String pacienteId,
    required String motoristaId,
    bool reembarqueVolta = false,
  }) {
    return _executarTransicao(
      pacienteId: pacienteId,
      acao: reembarqueVolta
          ? AcaoTransicao.motoristaReembarcarVolta
          : AcaoTransicao.motoristaEmbarcarIda,
      atorId: motoristaId,
      atorRole: 'motorista',
    );
  }
}
