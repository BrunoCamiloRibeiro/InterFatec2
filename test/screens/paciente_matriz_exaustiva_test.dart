// ============================================================================
// SUÍTE DE TESTES EXAUSTIVOS: MATRIZ DE ESTADOS E AÇÕES PROIBIDAS (ISSUE #19)
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/estado_tela_paciente.dart';
import 'package:trans_saude/models/janela_reversao_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';

void main() {
  group('1. Matriz de Estados Selados (MapeadorEstadoPaciente)', () {
    final basePaciente = PacienteModel(
      id: 'p_test',
      nome: 'João da Silva',
      cpf: '123.456.789-00',
      telefone: '(17) 99123-4567',
      enderecoPaciente: 'Rua Central, 100',
      localConsulta: 'Hospital de Base',
      localSaida: 'Residência',
      horarioConsulta: '14:00',
      status: 0,
    );

    test('1.1. Status 0 (Aguardando) mapeia para EstadoAguardandoTransporte', () {
      final estado = MapeadorEstadoPaciente.resolver(basePaciente.copyWith(status: 0));
      expect(estado, isA<EstadoAguardandoTransporte>());
    });

    test('1.2. Status 1 (Embarcou Ida) mapeia para EstadoEmTransitoIda', () {
      final estado = MapeadorEstadoPaciente.resolver(basePaciente.copyWith(status: 1));
      expect(estado, isA<EstadoEmTransitoIda>());
    });

    test('1.3. Status 2 (Na Consulta sem pronto) mapeia para EstadoNaConsultaMedica', () {
      final estado = MapeadorEstadoPaciente.resolver(basePaciente.copyWith(status: 2, prontoRetorno: false));
      expect(estado, isA<EstadoNaConsultaMedica>());
    });

    test('1.4. Status 2 (Na Consulta com pronto ativo) mapeia para EstadoAguardandoRetornoVan', () {
      final estado = MapeadorEstadoPaciente.resolver(basePaciente.copyWith(status: 2, prontoRetorno: true));
      expect(estado, isA<EstadoAguardandoRetornoVan>());
    });

    test('1.5. Status 3 (Reembarcou Volta) mapeia para EstadoEmTransitoRetorno', () {
      final estado = MapeadorEstadoPaciente.resolver(basePaciente.copyWith(status: 3));
      expect(estado, isA<EstadoEmTransitoRetorno>());
    });

    test('1.6. Status 4 (Concluído) mapeia para EstadoViagemConcluida', () {
      final estado = MapeadorEstadoPaciente.resolver(basePaciente.copyWith(status: 4));
      expect(estado, isA<EstadoViagemConcluida>());
    });

    test('1.7. Status 5 com janela de 5 min ativa mapeia para EstadoCanceladoReversivel', () {
      final agora = DateTime.utc(2026, 11, 8, 12, 0, 0);
      final janela = JanelaReversaoModel(
        acao: 'cancelamento_carona',
        iniciadoEm: agora,
        expiraEm: agora.add(const Duration(minutes: 5)),
        estadoAnterior: 0,
      );
      final estado = MapeadorEstadoPaciente.resolver(
        basePaciente.copyWith(status: 5, janelaReversao: janela),
        agora: agora.add(const Duration(seconds: 120)),
      );
      expect(estado, isA<EstadoCanceladoReversivel>());
    });

    test('1.8. Status 5 com janela expirada mapeia para EstadoCanceladoDefinitivo', () {
      final agora = DateTime.utc(2026, 11, 8, 12, 0, 0);
      final janela = JanelaReversaoModel(
        acao: 'cancelamento_carona',
        iniciadoEm: agora,
        expiraEm: agora.add(const Duration(minutes: 5)),
        estadoAnterior: 0,
      );
      final estado = MapeadorEstadoPaciente.resolver(
        basePaciente.copyWith(status: 5, janelaReversao: janela),
        agora: agora.add(const Duration(seconds: 301)),
      );
      expect(estado, isA<EstadoCanceladoDefinitivo>());
    });
  });

  group('2. Validação Cruzada: Status x Ação Proibida na API', () {
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
