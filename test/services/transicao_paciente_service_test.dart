// ============================================================================
// SUÍTE DE TESTES UNITÁRIOS: transicao_paciente_service_test.dart
// Camada: Domínio / Regras de Negócio Puras
// Escopo: Validação da máquina de estados do paciente e janelas de reversão (Issue #19)
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/janela_reversao_model.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';

void main() {
  group('1. TransicaoPacienteService - Transições Básicas e Atores', () {
    test('1.1. Paciente pode solicitar cancelamento quando status == 0 (Aguardando)', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 0,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.solicitarCancelamento,
        atorRole: 'paciente',
      );

      expect(res.permitido, isTrue);
      expect(res.novoStatus, equals(5));
      expect(res.duracaoJanelaSegundos, equals(300));
      expect(res.acaoReversao, equals('cancelamento_carona'));
    });

    test('1.2. Motorista NÃO pode solicitar cancelamento em nome do paciente', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 0,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.solicitarCancelamento,
        atorRole: 'motorista',
      );

      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('Apenas o próprio paciente'));
    });

    test('1.3. Paciente NÃO pode solicitar cancelamento após conclusão (status == 4)', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 4,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.solicitarCancelamento,
        atorRole: 'paciente',
      );

      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('já foi finalizado e concluído'));
    });

    test('1.4. Paciente pode sinalizar pronto na consulta (status == 2)', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 2,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.sinalizarPronto,
        atorRole: 'paciente',
      );

      expect(res.permitido, isTrue);
      expect(res.novoStatus, equals(2));
      expect(res.novoProntoRetorno, isTrue);
      expect(res.duracaoJanelaSegundos, equals(60));
      expect(res.acaoReversao, equals('pronto_retorno'));
    });

    test('1.5. Paciente pode sinalizar pronto quando status == 0 (Aguardando)', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 0,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.sinalizarPronto,
        atorRole: 'paciente',
      );

      expect(res.permitido, isTrue);
      expect(res.novoProntoRetorno, isTrue);
      expect(res.duracaoJanelaSegundos, equals(60));
    });

    test('1.6. Motorista pode registrar embarque de ida (status 0 -> 1)', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 0,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.motoristaEmbarcarIda,
        atorRole: 'motorista',
      );

      expect(res.permitido, isTrue);
      expect(res.novoStatus, equals(1));
    });

    test('1.7. Embarque do motorista sobrescreve cancelamento pendente (precedência física)', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 5,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.motoristaEmbarcarIda,
        atorRole: 'motorista',
      );

      expect(res.permitido, isTrue);
      expect(res.novoStatus, equals(1));
    });
  });

  group('2. Validação Exata de Limites Temporais com Relógio Injetável (Issue #19)', () {
    final tZero = DateTime.utc(2026, 11, 7, 12, 0, 0);

    test('2.1. Cancelamento: aos 299s (dentro do prazo de 300s) -> Desfazer PERMITIDO', () {
      final janela = JanelaReversaoModel(
        acao: 'cancelamento_carona',
        iniciadoEm: tZero,
        expiraEm: tZero.add(const Duration(seconds: 300)),
        estadoAnterior: 0,
      );

      final tempo299s = tZero.add(const Duration(seconds: 299));
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 5,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.desfazerCancelamento,
        atorRole: 'paciente',
        janelaAtiva: janela,
        agora: tempo299s,
      );

      expect(res.permitido, isTrue);
      expect(res.novoStatus, equals(0));
    });

    test('2.2. Cancelamento: aos 300s (limite exato) -> Desfazer RECUSADO por expiração', () {
      final janela = JanelaReversaoModel(
        acao: 'cancelamento_carona',
        iniciadoEm: tZero,
        expiraEm: tZero.add(const Duration(seconds: 300)),
        estadoAnterior: 0,
      );

      final tempo300s = tZero.add(const Duration(seconds: 300));
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 5,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.desfazerCancelamento,
        atorRole: 'paciente',
        janelaAtiva: janela,
        agora: tempo300s,
      );

      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('expirou'));
    });

    test('2.3. Cancelamento: aos 301s (após o prazo) -> Desfazer RECUSADO por expiração', () {
      final janela = JanelaReversaoModel(
        acao: 'cancelamento_carona',
        iniciadoEm: tZero,
        expiraEm: tZero.add(const Duration(seconds: 300)),
        estadoAnterior: 0,
      );

      final tempo301s = tZero.add(const Duration(seconds: 301));
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 5,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.desfazerCancelamento,
        atorRole: 'paciente',
        janelaAtiva: janela,
        agora: tempo301s,
      );

      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('expirou'));
    });

    test('2.4. Pronto Consulta: aos 59s (dentro do prazo de 60s) -> Desfazer PERMITIDO', () {
      final janela = JanelaReversaoModel(
        acao: 'pronto_retorno',
        iniciadoEm: tZero,
        expiraEm: tZero.add(const Duration(seconds: 60)),
        estadoAnterior: 2,
      );

      final tempo59s = tZero.add(const Duration(seconds: 59));
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 2,
        prontoRetornoAtual: true,
        acao: AcaoTransicao.desfazerPronto,
        atorRole: 'paciente',
        janelaAtiva: janela,
        agora: tempo59s,
      );

      expect(res.permitido, isTrue);
      expect(res.novoStatus, equals(2));
      expect(res.novoProntoRetorno, isFalse);
    });

    test('2.5. Pronto Consulta: aos 60s (limite exato) -> Desfazer RECUSADO por expiração', () {
      final janela = JanelaReversaoModel(
        acao: 'pronto_retorno',
        iniciadoEm: tZero,
        expiraEm: tZero.add(const Duration(seconds: 60)),
        estadoAnterior: 2,
      );

      final tempo60s = tZero.add(const Duration(seconds: 60));
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 2,
        prontoRetornoAtual: true,
        acao: AcaoTransicao.desfazerPronto,
        atorRole: 'paciente',
        janelaAtiva: janela,
        agora: tempo60s,
      );

      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('expirou'));
    });

    test('2.6. Pronto Consulta: aos 61s (após o prazo) -> Desfazer RECUSADO por expiração', () {
      final janela = JanelaReversaoModel(
        acao: 'pronto_retorno',
        iniciadoEm: tZero,
        expiraEm: tZero.add(const Duration(seconds: 60)),
        estadoAnterior: 2,
      );

      final tempo61s = tZero.add(const Duration(seconds: 61));
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 2,
        prontoRetornoAtual: true,
        acao: AcaoTransicao.desfazerPronto,
        atorRole: 'paciente',
        janelaAtiva: janela,
        agora: tempo61s,
      );

      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('expirou'));
    });
  });
}
