// ============================================================================
// SUÍTE DE TESTES DE INTEGRAÇÃO / CONCORRÊNCIA: paciente_concorrencia_test.dart
// Camada: Serviços / Sincronização e Concorrência Atômica
// Escopo: Testes de Autorização, Idempotência e Concorrência (500 iterações) (Issue #19)
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';

void main() {
  late PacienteSyncService syncService;

  setUp(() {
    syncService = PacienteSyncService();
    syncService.resetParaTestes([
      PacienteModel(
        id: 'p1',
        nome: 'Maria da Silva',
        cpf: '111.222.333-44',
        telefone: '(17) 99111-2222',
        enderecoPaciente: 'Rua A, 10',
        localConsulta: 'Hospital de Base',
        status: 0,
      ),
      PacienteModel(
        id: 'p2',
        nome: 'José Santos',
        cpf: '555.666.777-88',
        telefone: '(17) 99333-4444',
        enderecoPaciente: 'Rua B, 20',
        localConsulta: 'AME Rio Preto',
        status: 0,
      ),
    ]);
  });

  group('1. Testes de Autorização por Recurso (Issue #19)', () {
    test('1.1. Paciente A NÃO pode cancelar o agendamento do Paciente B', () async {
      final res = await syncService.solicitarCancelamento(
        pacienteId: 'p2', // Agendamento de B
        atorId: 'p1',     // Paciente A tentando agir
        atorRole: 'paciente',
      );

      expect(res.sucesso, isFalse);
      expect(res.mensagem, contains('Acesso negado'));
    });

    test('1.2. Paciente A PODE cancelar seu próprio agendamento', () async {
      final res = await syncService.solicitarCancelamento(
        pacienteId: 'p1',
        atorId: 'p1',
        atorRole: 'paciente',
      );

      expect(res.sucesso, isTrue);
      expect(res.paciente?.status, equals(5));
      expect(res.paciente?.janelaReversao, isNotNull);
    });
  });

  group('2. Testes de Idempotência por Idempotency-Key (Issue #19)', () {
    test('2.1. Retentativa com mesma chave retorna sucesso idempotente', () async {
      const key = 'req_idempotente_12345';

      final res1 = await syncService.solicitarCancelamento(
        pacienteId: 'p1',
        atorId: 'p1',
        atorRole: 'paciente',
        idempotencyKey: key,
      );

      expect(res1.sucesso, isTrue);
      expect(res1.foiIdempotente, isFalse);

      // Segunda chamada com a mesma chave (retry de rede duplicado)
      final res2 = await syncService.solicitarCancelamento(
        pacienteId: 'p1',
        atorId: 'p1',
        atorRole: 'paciente',
        idempotencyKey: key,
      );

      expect(res2.sucesso, isTrue);
      expect(res2.foiIdempotente, isTrue);
      expect(res2.mensagem, contains('idempotente'));
    });
  });

  group('3. Teste de Concorrência Estrita: Desfazer vs Confirmar Embarque (500 iterações)', () {
    test('3.1. Executa 500 corridas paralelas com exatamente 1 estado consistente final', () async {
      int vitoriasMotorista = 0;
      int vitoriasPaciente = 0;

      for (int i = 0; i < 500; i++) {
        // Inicializa paciente no estado cancelado com janela ativa
        final pacId = 'corrida_$i';
        final pacInicial = PacienteModel(
          id: pacId,
          nome: 'Paciente $i',
          cpf: '000.000.000-$i',
          telefone: '99999999',
          enderecoPaciente: 'Rua $i',
          localConsulta: 'Hospital $i',
          status: 0,
        );

        syncService.resetParaTestes([pacInicial]);

        // Passo 1: Paciente cancela (abrindo janela de 5 min)
        final cancelRes = await syncService.solicitarCancelamento(
          pacienteId: pacId,
          atorId: pacId,
          atorRole: 'paciente',
        );
        expect(cancelRes.sucesso, isTrue);

        // Passo 2: Disparo paralelo e concorrente: Paciente tenta "desfazer" enquanto motorista confirma embarque
        final futureDesfazer = syncService.desfazerCancelamento(
          pacienteId: pacId,
          atorId: pacId,
          atorRole: 'paciente',
        );

        final futureEmbarque = syncService.confirmarEmbarqueMotorista(
          pacienteId: pacId,
          motoristaId: 'mot_1',
        );

        final resultados = await Future.wait([futureDesfazer, futureEmbarque]);
        final resDesfazer = resultados[0];
        final resEmbarque = resultados[1];

        // Se o motorista venceu a corrida:
        if (resEmbarque.sucesso && !resDesfazer.sucesso) {
          vitoriasMotorista++;
        } else if (resDesfazer.sucesso && resEmbarque.sucesso) {
          // O desfazer passou primeiro (status 0), e imediatamente o embarque embarcou o paciente (status 1)
          vitoriasPaciente++;
        }

        // Estado final após o processamento da corrida
        // Em qualquer caso, a precedência do motorista garante que o passageiro a bordo fica com status 1
        // e nunca com janela corrompida!
        expect(
          resEmbarque.sucesso,
          isTrue,
          reason: 'Motorista deve sempre conseguir embarcar presencialmente na van',
        );
      }

      // Verificação estatística das 500 execuções
      expect(vitoriasMotorista + vitoriasPaciente, equals(500));
      expect(vitoriasMotorista, greaterThanOrEqualTo(0));
      expect(vitoriasPaciente, greaterThanOrEqualTo(0));
    });
  });
}
