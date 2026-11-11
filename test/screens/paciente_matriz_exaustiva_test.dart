// ============================================================================
// SUÍTE DE TESTES EXAUSTIVOS: TRANSIÇÕES PROIBIDAS (ISSUE #19)
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';

void main() {
  group('Validação Cruzada: Status x Ação Proibida na API', () {
    test('2.1. Quando Status == 5 (Cancelado), sinalizarPronto é terminantemente recusado', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 5,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.sinalizarPronto,
        atorRole: 'paciente',
      );
      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('cancelado'));
    });

    test('2.2. Quando Status == 4 (Concluído), solicitarCancelamento é terminantemente recusado', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 4,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.solicitarCancelamento,
        atorRole: 'paciente',
      );
      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('concluído'));
    });

    test('2.3. Quando Status == 4 (Concluído), sinalizarPronto é recusado', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 4,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.sinalizarPronto,
        atorRole: 'paciente',
      );
      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('concluído'));
    });

    test('2.4. Desfazer cancelamento recusado se status != 5', () {
      final res = TransicaoPacienteService.podeTransitar(
        statusAtual: 0,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.desfazerCancelamento,
        atorRole: 'paciente',
      );
      expect(res.permitido, isFalse);
      expect(res.motivoRecusa, contains('inválida'));
    });
  });
}
