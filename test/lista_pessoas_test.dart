import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/lista_pessoas.dart';
import 'package:trans_saude/models/admin_model.dart';
import 'package:trans_saude/models/motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';

void main() {
  final mockPacientes = [
    PacienteModel(
      id: 'p1',
      nome: 'Carlos Drummond',
      cpf: '111.222.333-44',
      telefone: '(14) 99111-2222',
      enderecoPaciente: 'Rua Poeta, 10',
      localConsulta: 'Hospital das Clínicas',
    ),
    PacienteModel(
      id: 'p2',
      nome: 'Clarice Lispector',
      cpf: '555.666.777-88',
      telefone: '(14) 99333-4444',
      enderecoPaciente: 'Av. Estrela, 50',
      localConsulta: 'AME Bauru',
    ),
  ];

  final mockMotoristas = [
    MotoristaModel(
      id: 'm1',
      nome: 'Machado de Assis',
      cpf: '999.888.777-66',
      telefone: '(14) 99555-6666',
      email: 'machado@saude.gov.br',
      cnh: '12345678901',
      veiculoModelo: 'Spin 7L',
      veiculoPlaca: 'ABC-1234',
    ),
  ];

  Widget criarTelaTeste({List<AdminModel>? mockAdmins}) {
    return MaterialApp(
      home: ListaPessoas(
        mockPacientes: mockPacientes,
        mockMotoristas: mockMotoristas,
        mockAdmins: mockAdmins,
      ),
    );
  }

  void configurarViewportLongo(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('1. Carga Inicial e Renderização da Lista', () {
    testWidgets(
      'Carrega com dados padrão sem colisão de chaves (sem exceptions)',
      (WidgetTester tester) async {
        configurarViewportLongo(tester);

        await tester.pumpWidget(const MaterialApp(home: ListaPessoas()));
        expect(tester.takeException(), isNull);
        expect(find.text('Gestão de Pessoas'), findsOneWidget);
        expect(find.text('Maria Silva Santos'), findsOneWidget);
        expect(find.text('João de Deus Pereira'), findsOneWidget);
      },
    );

    testWidgets('Carrega título, barra de busca e abas de filtro', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      expect(find.text('Gestão de Pessoas'), findsOneWidget);
      expect(find.text('Buscar por nome ou CPF...'), findsOneWidget);
      expect(find.text('Todos (3)'), findsOneWidget);
      expect(find.text('Pacientes (2)'), findsOneWidget);
      expect(find.text('Motoristas (1)'), findsOneWidget);
    });

    testWidgets('Exibe todos os registros na aba Todos', (
      WidgetTester tester,
    ) async {
      configurarViewportLongo(tester);

      await tester.pumpWidget(criarTelaTeste());

      expect(find.text('Carlos Drummond'), findsOneWidget);
      expect(find.text('Clarice Lispector'), findsOneWidget);
      expect(find.text('Machado de Assis'), findsOneWidget);
    });
  });

  group('2. Filtros por Papel (Abas)', () {
    testWidgets('Filtra apenas pacientes ao selecionar a aba Pacientes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      // Clica na aba Pacientes
      await tester.tap(find.text('Pacientes (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Carlos Drummond'), findsOneWidget);
      expect(find.text('Clarice Lispector'), findsOneWidget);
      expect(find.text('Machado de Assis'), findsNothing);
    });

    testWidgets('Filtra apenas motoristas ao selecionar a aba Motoristas', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      // Clica na aba Motoristas
      await tester.tap(find.text('Motoristas (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Machado de Assis'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Clarice Lispector'), findsNothing);
    });

    testWidgets(
      'Filtra apenas administradores ao selecionar a aba Administradores',
      (WidgetTester tester) async {
        final mockAdmins = [
          AdminModel(
            id: 'adm_teste',
            nome: 'Guimarães Rosa',
            cpf: '123.321.456-99',
            email: 'guimaraes@saude.sp.gov.br',
            telefone: '(14) 99888-7766',
          ),
        ];

        await tester.pumpWidget(criarTelaTeste(mockAdmins: mockAdmins));

        expect(find.text('Administradores (1)'), findsOneWidget);
        await tester.tap(find.text('Administradores (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Guimarães Rosa'), findsOneWidget);
        expect(find.text('Carlos Drummond'), findsNothing);
        expect(find.text('Machado de Assis'), findsNothing);
      },
    );
  });

  group('3. Busca Textual por Nome e CPF', () {
    testWidgets('Busca textual por nome filtra a lista corretamente', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      await tester.enterText(find.byType(TextField), 'Clarice');
      await tester.pumpAndSettle();

      expect(find.text('Clarice Lispector'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Machado de Assis'), findsNothing);
    });

    testWidgets('Busca por CPF filtra a lista corretamente', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      await tester.enterText(find.byType(TextField), '999.888');
      await tester.pumpAndSettle();

      expect(find.text('Machado de Assis'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
    });

    testWidgets('Exibe estado vazio quando busca não encontra resultados', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      await tester.enterText(find.byType(TextField), 'Inexistente XYZ');
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma pessoa encontrada'), findsOneWidget);
      expect(
        find.text('Tente buscar com outro nome ou número de CPF.'),
        findsOneWidget,
      );
    });
  });

  group('4. Ações de Gestão (Cadastro, Edição e Exclusão Lógica)', () {
    testWidgets('Diálogo de exclusão lógica abre e confirma', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      // Localiza o botão 'Excluir' do primeiro card
      final botaoExcluir = find.text('Excluir').first;
      await tester.tap(botaoExcluir);
      await tester.pumpAndSettle();

      // Confirma que abriu o alerta explicativo com a justificativa de governança
      expect(find.text('Excluir Registro'), findsOneWidget);
      expect(
        find.textContaining('Conforme as regras de governança e auditoria'),
        findsOneWidget,
      );

      // Clica em Confirmar Exclusão
      await tester.tap(find.text('Confirmar Exclusão'));
      await tester.pumpAndSettle();

      // Registro do Carlos foi excluído da lista
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Clarice Lispector'), findsOneWidget);
    });

    testWidgets(
      'Botão flutuante Novo abre diálogo de cadastro FormularioPessoa',
      (WidgetTester tester) async {
        await tester.pumpWidget(criarTelaTeste());

        final botaoNovo = find.widgetWithText(FloatingActionButton, 'Novo');
        expect(botaoNovo, findsOneWidget);

        await tester.tap(botaoNovo);
        await tester.pumpAndSettle();

        expect(find.text('Nova Pessoa'), findsOneWidget);
        expect(find.text('Cadastrar'), findsOneWidget);
      },
    );

    testWidgets(
      'Botão Editar no card abre formulário de edição com dados pré-carregados',
      (WidgetTester tester) async {
        await tester.pumpWidget(criarTelaTeste());

        final botaoEditar = find.text('Editar').first;
        expect(botaoEditar, findsOneWidget);

        await tester.tap(botaoEditar);
        await tester.pumpAndSettle();

        expect(find.text('Editar Pessoa'), findsOneWidget);
        expect(find.text('Salvar Alterações'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Carlos Drummond'),
          findsOneWidget,
        );
      },
    );
  });
}
