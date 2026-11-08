// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/transicao_paciente_service.dart
// Camada: Domínio / Regras de Negócio e Máquina de Estados Finita
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa a máquina de estados pura e determinística que rege o ciclo de vida
// do paciente no transporte de saúde (TFD), conforme especificado na Issue #19.
// Avalia transições de status (solicitar/desfazer carona, pronto/desfazer consulta,
// embarques pelo motorista), garantindo resolução de concorrência com precedência
// do motorista e janelas temporais estritas (300 s e 60 s).
//
// PARA QUE SERVE NO PROJETO:
// É a função pura 'podeTransitar(estado, acao, ator)', isolada de banco de dados
// e de interface gráfica. Permite testes unitários exaustivos com relógio injetável
// para validação de limites de tempo (299s, 300s, 301s, 59s, 60s, 61s) e garante
// que nenhuma regra de transição dependa de timers voláteis em memória.
//
// ONDE É USADO NO PROJETO:
// - lib/services/paciente_sync_service.dart (executada dentro de runTransaction)
// - test/services/transicao_paciente_service_test.dart
//
// DE ONDE RECEBE DADOS:
// Parâmetros em memória passados pelo chamador.
//
// O QUE EXPORTA / EXPÕE:
// - enum AcaoTransicao
// - class ResultadoTransicao
// - class TransicaoPacienteService
//   * static ResultadoTransicao podeTransitar(...)
// ============================================================================

import 'package:flutter/foundation.dart';
import '../models/janela_reversao_model.dart';

/// Enumeração de todas as ações operacionais do fluxo de transporte do paciente.
enum AcaoTransicao {
  /// Paciente avisa que foi de carona ou desistiu (abre janela de 300 s / 5 min).
  solicitarCancelamento,

  /// Paciente reverte a desistência dentro da janela de 300 s.
  desfazerCancelamento,

  /// Paciente avisa que a consulta acabou e está pronto (abre janela de 60 s / 1 min).
  sinalizarPronto,

  /// Paciente reverte a sinalização de pronto dentro da janela de 60 s.
  desfazerPronto,

  /// Motorista registra o embarque do passageiro no veículo para a ida.
  motoristaEmbarcarIda,

  /// Motorista registra o desembarque do paciente na unidade médica de destino.
  motoristaDesembarcarConsulta,

  /// Motorista registra o reembarque do paciente no veículo para retorno.
  motoristaReembarcarVolta,

  /// Motorista conclui o transporte municipal com o retorno finalizado.
  motoristaConcluirViagem,
}

/// Resultado imutável da avaliação da máquina de estados.
@immutable
class ResultadoTransicao {
  /// Se a transição é permitida pelas regras de negócio.
  final bool permitido;

  /// Novo código numérico de status após a transição (0 a 5).
  final int novoStatus;

  /// Novo valor da flag de prontidão de retorno após a consulta.
  final bool novoProntoRetorno;

  /// Duração em segundos da janela de reversão concedida (300 s, 60 s ou null).
  final int? duracaoJanelaSegundos;

  /// Nome semântico da ação passível de reversão ('cancelamento_carona', 'pronto_retorno' ou null).
  final String? acaoReversao;

  /// Mensagem explicativa em caso de recusa da transição.
  final String? motivoRecusa;

  const ResultadoTransicao.sucesso({
    required this.novoStatus,
    required this.novoProntoRetorno,
    this.duracaoJanelaSegundos,
    this.acaoReversao,
  })  : permitido = true,
        motivoRecusa = null;

  const ResultadoTransicao.recusado(this.motivoRecusa)
      : permitido = false,
        novoStatus = -1,
        novoProntoRetorno = false,
        duracaoJanelaSegundos = null,
        acaoReversao = null;
}

/// Serviço de domínio puro da máquina de estados do paciente.
class TransicaoPacienteService {
  /// Duração oficial da janela de reversão para cancelamento / carona (5 minutos).
  static const int janelaCancelamentoSegundos = 300;

  /// Duração oficial da janela de reversão para pronto de consulta (1 minuto).
  static const int janelaProntoSegundos = 60;

  /// Avalia a transição de estado requisitada de forma pura e determinística.
  ///
  /// Parâmetros:
  /// - [statusAtual]: Código numérico atual do paciente (0 a 5).
  /// - [prontoRetornoAtual]: Se o paciente já havia sinalizado estar pronto.
  /// - [acao]: Ação que se deseja executar.
  /// - [atorRole]: Perfil de quem executa ('paciente', 'motorista', 'admin').
  /// - [janelaAtiva]: Metadados da janela de reversão corrente, se houver.
  /// - [agora]: Timestamp de referência UTC (injetável para testes determinísticos).
  static ResultadoTransicao podeTransitar({
    required int statusAtual,
    required bool prontoRetornoAtual,
    required AcaoTransicao acao,
    required String atorRole,
    JanelaReversaoModel? janelaAtiva,
    DateTime? agora,
  }) {
    final momentoAtual = (agora ?? DateTime.now()).toUtc();
    final roleNormalizada = atorRole.toLowerCase().trim();

    // ------------------------------------------------------------------------
    // 1. AÇÃO: solicitarCancelamento ("Fui embora / Carona")
    // ------------------------------------------------------------------------
    if (acao == AcaoTransicao.solicitarCancelamento) {
      if (roleNormalizada != 'paciente' && roleNormalizada != 'admin') {
        return const ResultadoTransicao.recusado(
          'Apenas o próprio paciente ou um administrador podem solicitar cancelamento.',
        );
      }
      if (statusAtual == 4) {
        return const ResultadoTransicao.recusado(
          'Não é possível cancelar: o transporte já foi finalizado e concluído.',
        );
      }
      if (statusAtual == 5) {
        return const ResultadoTransicao.recusado(
          'O agendamento já se encontra cancelado.',
        );
      }
      // Permitido para qualquer status ativo do agendamento (0, 1, 2, 3)
      return const ResultadoTransicao.sucesso(
        novoStatus: 5,
        novoProntoRetorno: false,
        duracaoJanelaSegundos: janelaCancelamentoSegundos,
        acaoReversao: 'cancelamento_carona',
      );
    }

    // ------------------------------------------------------------------------
    // 2. AÇÃO: desfazerCancelamento ("Desfazer" na janela de carona)
    // ------------------------------------------------------------------------
    if (acao == AcaoTransicao.desfazerCancelamento) {
      if (roleNormalizada != 'paciente' && roleNormalizada != 'admin') {
        return const ResultadoTransicao.recusado(
          'Apenas o próprio paciente ou um administrador podem desfazer o cancelamento.',
        );
      }
      if (statusAtual != 5) {
        return const ResultadoTransicao.recusado(
          'Ação de desfazer cancelamento é inválida para o status atual.',
        );
      }
      if (janelaAtiva == null || janelaAtiva.acao != 'cancelamento_carona') {
        return const ResultadoTransicao.recusado(
          'Não existe janela de reversão ativa para esta ação.',
        );
      }
      if (!janelaAtiva.estaAtiva(agora: momentoAtual)) {
        return const ResultadoTransicao.recusado(
          'A janela de reversão de 5 minutos já expirou no servidor.',
        );
      }
      // Reverte para o status anterior armazenado (normalmente 0)
      return ResultadoTransicao.sucesso(
        novoStatus: janelaAtiva.estadoAnterior,
        novoProntoRetorno: false,
      );
    }

    // ------------------------------------------------------------------------
    // 3. AÇÃO: sinalizarPronto ("Estou Pronto" pós-consulta)
    // ------------------------------------------------------------------------
    if (acao == AcaoTransicao.sinalizarPronto) {
      if (roleNormalizada != 'paciente' && roleNormalizada != 'admin') {
        return const ResultadoTransicao.recusado(
          'Apenas o próprio paciente ou um administrador podem sinalizar prontidão.',
        );
      }
      if (statusAtual == 4) {
        return const ResultadoTransicao.recusado(
          'Não é possível sinalizar prontidão: o transporte já foi concluído.',
        );
      }
      if (statusAtual == 5) {
        return const ResultadoTransicao.recusado(
          'Não é possível sinalizar prontidão: o agendamento foi cancelado.',
        );
      }
      if (prontoRetornoAtual) {
        return const ResultadoTransicao.recusado(
          'Você já sinalizou que está pronto para o retorno.',
        );
      }
      return ResultadoTransicao.sucesso(
        novoStatus: (statusAtual == 0 || statusAtual == 1) ? 2 : statusAtual,
        novoProntoRetorno: true,
        duracaoJanelaSegundos: janelaProntoSegundos,
        acaoReversao: 'pronto_retorno',
      );
    }

    // ------------------------------------------------------------------------
    // 4. AÇÃO: desfazerPronto ("Desfazer" na janela de pronto)
    // ------------------------------------------------------------------------
    if (acao == AcaoTransicao.desfazerPronto) {
      if (roleNormalizada != 'paciente' && roleNormalizada != 'admin') {
        return const ResultadoTransicao.recusado(
          'Apenas o próprio paciente ou um administrador podem desfazer a prontidão.',
        );
      }
      if (statusAtual != 2 || !prontoRetornoAtual) {
        return const ResultadoTransicao.recusado(
          'O paciente não possui sinalização de prontidão ativa para ser revertida.',
        );
      }
      if (janelaAtiva == null || janelaAtiva.acao != 'pronto_retorno') {
        return const ResultadoTransicao.recusado(
          'Não existe janela de reversão ativa para esta ação.',
        );
      }
      if (!janelaAtiva.estaAtiva(agora: momentoAtual)) {
        return const ResultadoTransicao.recusado(
          'A janela de reversão de 1 minuto já expirou no servidor.',
        );
      }
      return const ResultadoTransicao.sucesso(
        novoStatus: 2,
        novoProntoRetorno: false,
      );
    }

    // ------------------------------------------------------------------------
    // 5. AÇÃO: motoristaEmbarcarIda (Embarque presencial na van)
    // - Regra de Ouro: O embarque físico pelo motorista tem precedência absoluta.
    // - Se o paciente estiver em janela de cancelamento, a presença física na van
    //   anula o cancelamento e consolida o status como Embarcou (1).
    // ------------------------------------------------------------------------
    if (acao == AcaoTransicao.motoristaEmbarcarIda) {
      if (roleNormalizada != 'motorista' && roleNormalizada != 'admin') {
        return const ResultadoTransicao.recusado(
          'Apenas o motorista responsável ou administrador podem registrar embarque.',
        );
      }
      if (statusAtual == 1) {
        return const ResultadoTransicao.recusado(
          'O passageiro já consta como embarcado para a viagem.',
        );
      }
      if (statusAtual == 3 || statusAtual == 4) {
        return const ResultadoTransicao.recusado(
          'Passageiro já se encontra em estágio avançado da viagem.',
        );
      }
      // Permitido para status 0 ou status 5 (anula cancelamento pendente por presença física)
      return const ResultadoTransicao.sucesso(
        novoStatus: 1,
        novoProntoRetorno: false,
      );
    }

    // ------------------------------------------------------------------------
    // 6. AÇÃO: motoristaDesembarcarConsulta (Entrega no hospital/clínica)
    // ------------------------------------------------------------------------
    if (acao == AcaoTransicao.motoristaDesembarcarConsulta) {
      if (roleNormalizada != 'motorista' && roleNormalizada != 'admin') {
        return const ResultadoTransicao.recusado(
          'Apenas o motorista responsável pode registrar desembarque na consulta.',
        );
      }
      if (statusAtual != 1) {
        return const ResultadoTransicao.recusado(
          'Desembarque permitido apenas após o embarque de ida.',
        );
      }
      return const ResultadoTransicao.sucesso(
        novoStatus: 2,
        novoProntoRetorno: false,
      );
    }

    // ------------------------------------------------------------------------
    // 7. AÇÃO: motoristaReembarcarVolta (Embarque para retorno ao município)
    // ------------------------------------------------------------------------
    if (acao == AcaoTransicao.motoristaReembarcarVolta) {
      if (roleNormalizada != 'motorista' && roleNormalizada != 'admin') {
        return const ResultadoTransicao.recusado(
          'Apenas o motorista responsável pode registrar o reembarque de volta.',
        );
      }
      if (statusAtual != 2) {
        return const ResultadoTransicao.recusado(
          'Reembarque de volta permitido apenas após desembarque na consulta.',
        );
      }
      return const ResultadoTransicao.sucesso(
        novoStatus: 3,
        novoProntoRetorno: false,
      );
    }

    // ------------------------------------------------------------------------
    // 8. AÇÃO: motoristaConcluirViagem (Entrega final em domicílio)
    // ------------------------------------------------------------------------
    if (acao == AcaoTransicao.motoristaConcluirViagem) {
      if (roleNormalizada != 'motorista' && roleNormalizada != 'admin') {
        return const ResultadoTransicao.recusado(
          'Apenas o motorista responsável pode registrar a conclusão da viagem.',
        );
      }
      if (statusAtual != 3) {
        return const ResultadoTransicao.recusado(
          'Conclusão permitida apenas após o reembarque de retorno.',
        );
      }
      return const ResultadoTransicao.sucesso(
        novoStatus: 4,
        novoProntoRetorno: false,
      );
    }

    return const ResultadoTransicao.recusado('Ação de transição desconhecida.');
  }
}
