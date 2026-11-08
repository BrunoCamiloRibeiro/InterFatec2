// ============================================================================
// SUÍTE DE TESTES DE INTERFACE: paciente_botoes_test.dart
// Camada: Apresentação / Telas
// Escopo: Validação dos botões da tela do paciente e pop-up de confirmação (Issue #19)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/janela_reversao_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/paciente.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';

void main() {
  late PacienteSyncService syncService;

  setUp(() {
    syncService = PacienteSyncService();
  });

  testWidgets('1. Clicar em Fui embora abre pop-up Tem certeza dessa ação?', (tester) async {
    final paciente = PacienteModel(
      id: 'p1',
      nome: 'Maria da Silva',
      cpf: '111.222.333-44',
      telefone: '(17) 99111-2222',
      enderecoPaciente: 'Rua das Flores, 10',
      localConsulta: 'Hospital de Base',
      status: 0,
    );

    syncService.resetParaTestes([paciente]);

    await tester.pumpWidget(
      MaterialApp(
        home: Paciente(
          pacienteId: 'p1',
          syncServiceOverride: syncService,
          pacienteStreamOverride: Stream.value(paciente),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Encontra o botão "Fui embora"
    final botaoFuiEmbora = find.byKey(const Key('botao_fui_embora'));
    expect(botaoFuiEmbora, findsOneWidget);

    // Toca no botão
    await tester.tap(botaoFuiEmbora);
    await tester.pumpAndSettle();

    // Deve exibir o diálogo com a pergunta exigida pela Issue #19
    expect(find.text('Tem certeza dessa ação?'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    // Clica em Cancelar
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Diálogo sumiu
    expect(find.text('Tem certeza dessa ação?'), findsNothing);
  });

  testWidgets('2. Confirmar Fui embora dispara cancelamento e exibe SnackBar com prazo', (tester) async {
    final paciente = PacienteModel(
      id: 'p1',
      nome: 'Maria da Silva',
      cpf: '111.222.333-44',
      telefone: '(17) 99111-2222',
      enderecoPaciente: 'Rua das Flores, 10',
      localConsulta: 'Hospital de Base',
      status: 0,
    );

    syncService.resetParaTestes([paciente]);

    await tester.pumpWidget(
      MaterialApp(
        home: Paciente(
          pacienteId: 'p1',
          syncServiceOverride: syncService,
          pacienteStreamOverride: syncService.ouvirPaciente('p1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Clica no botão "Fui embora"
    await tester.tap(find.byKey(const Key('botao_fui_embora')));
    await tester.pumpAndSettle();

    // Clica em Confirmar no pop-up
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // SnackBar deve informar o registro e o prazo de 5 minutos
    expect(find.textContaining('5 minutos para desfazer'), findsOneWidget);
  });

  testWidgets('3. Paciente na consulta (status 2) pode acionar Estou Pronto com pop-up', (tester) async {
    final pacienteNaConsulta = PacienteModel(
      id: 'p1',
      nome: 'Maria da Silva',
      cpf: '111.222.333-44',
      telefone: '(17) 99111-2222',
      enderecoPaciente: 'Rua das Flores, 10',
      localConsulta: 'Hospital de Base',
      status: 2, // Desembarcou para consulta
    );

    syncService.resetParaTestes([pacienteNaConsulta]);

    await tester.pumpWidget(
      MaterialApp(
        home: Paciente(
          pacienteId: 'p1',
          syncServiceOverride: syncService,
          pacienteStreamOverride: syncService.ouvirPaciente('p1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Clica no botão "Estou Pronto"
    final botaoPronto = find.byKey(const Key('botao_estou_pronto'));
    expect(botaoPronto, findsOneWidget);

    await tester.tap(botaoPronto);
    await tester.pumpAndSettle();

    // Confirma no pop-up
    expect(find.text('Tem certeza dessa ação?'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // SnackBar deve informar o aviso enviado e prazo de 1 minuto
    expect(find.textContaining('1 minuto para desfazer'), findsOneWidget);
  });

  testWidgets('4. Banner de Undo aparece quando janela está ativa e reverte a ação ao clicar em Desfazer', (tester) async {
    final agora = DateTime.now().toUtc();
    final pacienteCancelado = PacienteModel(
      id: 'p1',
      nome: 'Maria da Silva',
      cpf: '111.222.333-44',
      telefone: '(17) 99111-2222',
      enderecoPaciente: 'Rua das Flores, 10',
      localConsulta: 'Hospital de Base',
      status: 5,
      janelaReversao: JanelaReversaoModel(
        acao: 'cancelamento_carona',
        iniciadoEm: agora,
        expiraEm: agora.add(const Duration(minutes: 5)),
        estadoAnterior: 0,
      ),
    );

    syncService.resetParaTestes([pacienteCancelado]);

    await tester.pumpWidget(
      MaterialApp(
        home: Paciente(
          pacienteId: 'p1',
          syncServiceOverride: syncService,
          pacienteStreamOverride: syncService.ouvirPaciente('p1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Deve exibir o Banner de Reversão
    expect(find.text('Cancelamento Solicitado'), findsOneWidget);
    expect(find.byKey(const Key('botao_desfazer_reversao')), findsOneWidget);

    // Clica no botão Desfazer Cancelamento
    final botaoDesfazer = find.byKey(const Key('botao_desfazer_reversao'));
    await tester.ensureVisible(botaoDesfazer);
    await tester.tap(botaoDesfazer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // SnackBar deve confirmar a reversão
    expect(find.textContaining('Cancelamento desfeito com sucesso'), findsOneWidget);
  });
  testWidgets('5. Enquanto o timer estiver ativo, os botões Fui embora e Estou Pronto ficam inacessíveis e cinzas; ao desfazer voltam a ser clicáveis', (tester) async {
    final agora = DateTime.now().toUtc();
    final pacienteComTimer = PacienteModel(
      id: 'p1',
      nome: 'Maria da Silva',
      cpf: '111.222.333-44',
      telefone: '(17) 99111-2222',
      enderecoPaciente: 'Rua das Flores, 10',
      localConsulta: 'Hospital de Base',
      status: 2,
      prontoRetorno: true,
      janelaReversao: JanelaReversaoModel(
        acao: 'pronto_retorno',
        iniciadoEm: agora,
        expiraEm: agora.add(const Duration(minutes: 1)),
        estadoAnterior: 2,
      ),
    );

    syncService.resetParaTestes([pacienteComTimer]);

    await tester.pumpWidget(
      MaterialApp(
        home: Paciente(
          pacienteId: 'p1',
          syncServiceOverride: syncService,
          pacienteStreamOverride: syncService.ouvirPaciente('p1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verifica que o banner está na tela
    expect(find.byKey(const Key('botao_desfazer_reversao')), findsOneWidget);

    // 2. Os botões Fui embora e Estou Pronto devem existir mas estar DESABILITADOS (onPressed == null)
    final btnFuiEmbora = tester.widget<OutlinedButton>(find.byKey(const Key('botao_fui_embora')));
    expect(btnFuiEmbora.onPressed, isNull);

    final btnEstouPronto = tester.widget<ElevatedButton>(find.byKey(const Key('botao_estou_pronto')));
    expect(btnEstouPronto.onPressed, isNull);

    // 3. Clica no botão Desfazer do banner
    final botaoDesfazer = find.byKey(const Key('botao_desfazer_reversao'));
    await tester.ensureVisible(botaoDesfazer);
    await tester.tap(botaoDesfazer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 4. Após desfazer o aviso, o timer sumiu e o botão volta a ser clicável (onPressed != null)
    final btnFuiEmboraAposUndo = tester.widget<OutlinedButton>(find.byKey(const Key('botao_fui_embora')));
    expect(btnFuiEmboraAposUndo.onPressed, isNotNull);

    final btnEstouProntoAposUndo = tester.widget<ElevatedButton>(find.byKey(const Key('botao_estou_pronto')));
    expect(btnEstouProntoAposUndo.onPressed, isNotNull);
  });  testWidgets('6. Quando o paciente está na van (Status 1 ou Status 3), ambos os botões ficam cinzas e inacessíveis', (tester) async {
    // 6.1. Teste no Status 1 (Embarcou para Ida)
    final pacienteNaVanIda = PacienteModel(
      id: 'p1',
      nome: 'Francisca',
      cpf: '507.750.348-60',
      telefone: '(17) 99876-5432',
      enderecoPaciente: 'Rua Quinze de Novembro, 480',
      localConsulta: 'Hospital de Base',
      status: 1, // Embarcou para Ida
    );

    syncService.resetParaTestes([pacienteNaVanIda]);

    await tester.pumpWidget(
      MaterialApp(
        home: Paciente(
          pacienteId: 'p1',
          syncServiceOverride: syncService,
          pacienteStreamOverride: syncService.ouvirPaciente('p1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No status 1 (na van de ida), ambos os botões devem estar desabilitados (onPressed == null)
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('botao_fui_embora'))).onPressed, isNull);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('botao_estou_pronto'))).onPressed, isNull);

    // 6.2. Teste no Status 3 (Reembarcou para Volta)
    final pacienteNaVanVolta = pacienteNaVanIda.copyWith(status: 3);
    syncService.resetParaTestes([pacienteNaVanVolta]);

    await tester.pumpWidget(
      MaterialApp(
        home: Paciente(
          pacienteId: 'p1',
          syncServiceOverride: syncService,
          pacienteStreamOverride: syncService.ouvirPaciente('p1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No status 3 (na van de volta), ambos os botões também devem estar desabilitados (onPressed == null)
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('botao_fui_embora'))).onPressed, isNull);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('botao_estou_pronto'))).onPressed, isNull);
  });

  testWidgets('7. Acessibilidade e Blindagem Cognitiva: exibe rótulo explicativo quando botões estão desabilitados', (tester) async {
    final pacienteNaVan = PacienteModel(
      id: 'p1',
      nome: 'Francisca da Silva',
      cpf: '507.750.348-60',
      telefone: '(17) 99876-5432',
      enderecoPaciente: 'Rua Quinze de Novembro, 480',
      localConsulta: 'Hospital de Base',
      status: 1, // Embarcou para Ida
    );

    syncService.resetParaTestes([pacienteNaVan]);

    await tester.pumpWidget(
      MaterialApp(
        home: Paciente(
          pacienteId: 'p1',
          syncServiceOverride: syncService,
          pacienteStreamOverride: syncService.ouvirPaciente('p1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rótulo explicativo deve estar visível informando que está a caminho
    expect(find.byKey(const Key('mensagem_apoio_botoes_inativos')), findsOneWidget);
    expect(find.text('Você está a bordo da van a caminho da consulta médica.'), findsOneWidget);
  });
}
