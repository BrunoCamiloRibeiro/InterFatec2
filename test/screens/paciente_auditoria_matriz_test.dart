// ============================================================================
// SUÍTE DE TESTES DE AUDITORIA E MATRIZ DE TRANSIÇÕES (Issue #19)
// Camada: Apresentação, Domínio e Concorrência
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/janela_reversao_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/paciente.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';

void main() {
  late PacienteSyncService syncService;

  setUp(() {
    syncService = PacienteSyncService();
  });

  group('Auditoria UX e Matriz de Testes (Issue #19)', () {
    testWidgets('T01: Trava de clique duplo impede abertura de múltiplos diálogos ou requisições', (tester) async {
      final paciente = PacienteModel(
        id: 'p_trava',
        nome: 'Carlos Teste',
        cpf: '123.456.789-00',
        telefone: '(17) 99999-0000',
        enderecoPaciente: 'Rua A, 1',
        localConsulta: 'Hospital Central',
        status: 0,
      );

      syncService.resetParaTestes([paciente]);

      await tester.pumpWidget(
        MaterialApp(
          home: Paciente(
            pacienteId: 'p_trava',
            syncServiceOverride: syncService,
            pacienteStreamOverride: syncService.ouvirPaciente('p_trava'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final botao = find.byKey(const Key('botao_fui_embora'));
      expect(botao, findsOneWidget);

      // Simula rajada rápida de duplo clique
      await tester.tap(botao);
      await tester.tap(botao, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Deve existir exatamente UM diálogo aberto na árvore de widgets
      expect(find.text('Tem certeza dessa ação?'), findsOneWidget);
    });

    testWidgets('T02: Mudança de status vinda do motorista em tempo real atualiza a tela do paciente', (tester) async {
      final streamController = StreamController<PacienteModel?>.broadcast();
      final pacienteInicial = PacienteModel(
        id: 'p_realtime',
        nome: 'Maria Realtime',
        cpf: '111.222.333-44',
        telefone: '(17) 98888-7777',
        enderecoPaciente: 'Rua B, 2',
        localConsulta: 'Hospital Base',
        status: 0, // Aguardando
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Paciente(
            pacienteId: 'p_realtime',
            pacienteStreamOverride: streamController.stream,
          ),
        ),
      );

      // Emite estado inicial (Aguardando Transporte)
      streamController.add(pacienteInicial);
      await tester.pumpAndSettle();
      expect(find.text('Aguardando Transporte'), findsOneWidget);

      // Motorista embarca o paciente presencialmente (status muda para 1)
      final pacienteEmbarcado = pacienteInicial.copyWith(status: 1);
      streamController.add(pacienteEmbarcado);
      await tester.pumpAndSettle();

      // UI do paciente reflete a mudança imediatamente
      expect(find.text('Embarcou para Ida'), findsOneWidget);

      await streamController.close();
    });

    test('T03: Contrato de Transições Proibidas rejeita mutações inválidas direto na API', () {
      // 1. Paciente tentando cancelar transporte já concluído (status 4)
      final resConcluido = TransicaoPacienteService.podeTransitar(
        statusAtual: 4,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.solicitarCancelamento,
        atorRole: 'paciente',
      );
      expect(resConcluido.permitido, isFalse);
      expect(resConcluido.motivoRecusa, contains('finalizado e concluído'));

      // 2. Paciente tentando cancelar quando já está cancelado (status 5)
      final resJaCancelado = TransicaoPacienteService.podeTransitar(
        statusAtual: 5,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.solicitarCancelamento,
        atorRole: 'paciente',
      );
      expect(resJaCancelado.permitido, isFalse);
      expect(resJaCancelado.motivoRecusa, contains('já se encontra cancelado'));

      // 3. Paciente tentando sinalizar pronto duas vezes seguidas
      final resDuploPronto = TransicaoPacienteService.podeTransitar(
        statusAtual: 2,
        prontoRetornoAtual: true,
        acao: AcaoTransicao.sinalizarPronto,
        atorRole: 'paciente',
      );
      expect(resDuploPronto.permitido, isFalse);
      expect(resDuploPronto.motivoRecusa, contains('já sinalizou que está pronto'));

      // 4. Perfil não autorizado (motorista tentando disparar ação exclusiva de paciente)
      final resMotoristaCancelando = TransicaoPacienteService.podeTransitar(
        statusAtual: 0,
        prontoRetornoAtual: false,
        acao: AcaoTransicao.solicitarCancelamento,
        atorRole: 'motorista',
      );
      expect(resMotoristaCancelando.permitido, isFalse);
      expect(resMotoristaCancelando.motivoRecusa, contains('Apenas o próprio paciente'));
    });

    test('T04: Recálculo de tempo restante baseado em expiraEm do servidor é resiliente a relógio local', () {
      final agoraServidor = DateTime.utc(2026, 11, 7, 20, 0, 0);
      final expiraServidor = DateTime.utc(2026, 11, 7, 20, 5, 0); // 300 segundos

      final janela = JanelaReversaoModel(
        acao: 'cancelamento_carona',
        iniciadoEm: agoraServidor,
        expiraEm: expiraServidor,
        estadoAnterior: 0,
      );

      // 1. Aos 100 segundos decorridos no servidor
      final tempo1 = janela.tempoRestante(agora: agoraServidor.add(const Duration(seconds: 100)));
      expect(tempo1.inSeconds, equals(200));

      // 2. Aos 299 segundos decorridos
      final tempo2 = janela.tempoRestante(agora: agoraServidor.add(const Duration(seconds: 299)));
      expect(tempo2.inSeconds, equals(1));
      expect(janela.estaAtiva(agora: agoraServidor.add(const Duration(seconds: 299))), isTrue);

      // 3. Aos 300 segundos decorridos (expirado)
      final tempo3 = janela.tempoRestante(agora: agoraServidor.add(const Duration(seconds: 300)));
      expect(tempo3.inSeconds, equals(0));
      expect(janela.estaAtiva(agora: agoraServidor.add(const Duration(seconds: 300))), isFalse);

      // 4. Aos 350 segundos decorridos (clamping em 0, nunca negativo)
      final tempo4 = janela.tempoRestante(agora: agoraServidor.add(const Duration(seconds: 350)));
      expect(tempo4.inSeconds, equals(0));
    });
  });
}
