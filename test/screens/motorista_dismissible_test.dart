// ============================================================================
// SUÍTE DE TESTES: motorista_dismissible_test.dart
// Camada: Apresentação / Interação Mobile do Motorista
// Escopo: Validação de confirmDismiss, diálogo defensivo e regras de avanço (Issue #19)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';

void main() {
  late PacienteSyncService syncService;

  setUp(() {
    syncService = PacienteSyncService();
  });

  Widget buildMotoristaWidget(List<PacienteModel> pacientes) {
    syncService.resetParaTestes(pacientes);
    return MaterialApp(
      home: Motorista(
        syncServiceOverride: syncService,
        pacientesStreamOverride: Stream.value(pacientes),
      ),
    );
  }

  group('Motorista Dismissible & confirmDismiss (Issue #19)', () {
    testWidgets('1. Swipe endToStart no Status 0 abre diálogo ergonômico para "Embarcou para Ida"', (tester) async {
      final paciente = PacienteModel(
        id: 'p1',
        nome: 'Francisca da Silva',
        cpf: '507.750.348-60',
        telefone: '(17) 99876-5432',
        enderecoPaciente: 'Rua Quinze de Novembro, 480',
        localConsulta: 'Hospital de Base',
        status: 0,
      );

      await tester.pumpWidget(buildMotoristaWidget([paciente]));
      await tester.pumpAndSettle();

      // Desliza da direita para a esquerda (endToStart)
      final cardFinder = find.byKey(const ValueKey('p1'));
      expect(cardFinder, findsOneWidget);

      await tester.drag(cardFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Diálogo modal ergonômico com tipografia escaneável em 1s
      expect(find.text('PRÓXIMA ETAPA'), findsOneWidget);
      expect(find.text('Embarcou para Ida'), findsOneWidget);
      expect(find.text('Francisca da Silva'), findsAtLeast(1));
      expect(find.byKey(const Key('botao_cancelar_dialogo_motorista')), findsOneWidget);
      expect(find.byKey(const Key('botao_confirmar_dialogo_motorista')), findsOneWidget);

      // Clica em Cancelar
      await tester.tap(find.byKey(const Key('botao_cancelar_dialogo_motorista')));
      await tester.pumpAndSettle();

      // O diálogo fechou e o paciente continua no status 0
      expect(find.text('PRÓXIMA ETAPA'), findsNothing);
      expect(syncService.ouvirPaciente('p1'), emits(predicate<PacienteModel?>((p) => p?.status == 0)));
    });

    testWidgets('2. Confirmar no diálogo avança o status para "Embarcou para Ida" (Status 1)', (tester) async {
      final paciente = PacienteModel(
        id: 'p1',
        nome: 'Francisca da Silva',
        cpf: '507.750.348-60',
        telefone: '(17) 99876-5432',
        enderecoPaciente: 'Rua Quinze de Novembro, 480',
        localConsulta: 'Hospital de Base',
        status: 0,
      );

      await tester.pumpWidget(buildMotoristaWidget([paciente]));
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('p1'));
      await tester.drag(cardFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Clica em Confirmar (botão primário full-width)
      await tester.tap(find.byKey(const Key('botao_confirmar_dialogo_motorista')));
      await tester.pumpAndSettle();

      // SnackBar de confirmação semântica deve aparecer
      expect(find.text("Avanço para 'Embarcou para Ida' confirmado com sucesso."), findsOneWidget);
    });

    testWidgets('3. Bloqueio no Status 2 quando prontoRetorno == false: swipe é rejeitado e alerta é exibido', (tester) async {
      final pacienteEmConsulta = PacienteModel(
        id: 'p2',
        nome: 'João Santos',
        cpf: '123.456.789-00',
        telefone: '(17) 99999-1111',
        enderecoPaciente: 'Rua B, 20',
        localConsulta: 'AME Rio Preto',
        status: 2,
        prontoRetorno: false, // Ainda em atendimento médico!
      );

      await tester.pumpWidget(buildMotoristaWidget([pacienteEmConsulta]));
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('p2'));
      await tester.drag(cardFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Diálogo de confirmação NÃO deve abrir
      expect(find.text('PRÓXIMA ETAPA'), findsNothing);

      // Alerta de que o paciente ainda está em atendimento deve ser exibido
      expect(find.text('O paciente ainda está em atendimento médico.'), findsOneWidget);
    });

    testWidgets('4. No Status 2 com prontoRetorno == true, swipe avança obrigatoriamente para "Reembarcou para Volta" (Status 3)', (tester) async {
      final pacientePronto = PacienteModel(
        id: 'p3',
        nome: 'Maria Pereira',
        cpf: '333.444.555-66',
        telefone: '(17) 98888-2222',
        enderecoPaciente: 'Rua C, 30',
        localConsulta: 'Hospital Central',
        status: 2,
        prontoRetorno: true, // Já terminou a consulta!
      );

      await tester.pumpWidget(buildMotoristaWidget([pacientePronto]));
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('p3'));
      await tester.drag(cardFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Deve exibir a próxima etapa Reembarcou para Volta (Status 3), e NÃO Concluído (Status 4)
      expect(find.text('PRÓXIMA ETAPA'), findsOneWidget);
      expect(find.text('Reembarcou para Volta'), findsOneWidget);
      expect(find.text('Maria Pereira'), findsAtLeast(1));
    });

    testWidgets('5. Toque direto no card não abre diálogo (onTap desativado)', (tester) async {
      final paciente = PacienteModel(
        id: 'p4',
        nome: 'Carlos Eduardo',
        cpf: '777.888.999-00',
        telefone: '(17) 97777-3333',
        enderecoPaciente: 'Rua D, 40',
        localConsulta: 'Hospital Central',
        status: 0,
      );

      await tester.pumpWidget(buildMotoristaWidget([paciente]));
      await tester.pumpAndSettle();

      // Clica direto no card
      await tester.tap(find.byKey(const ValueKey('p4')));
      await tester.pumpAndSettle();

      // Nenhum diálogo deve ser aberto
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
