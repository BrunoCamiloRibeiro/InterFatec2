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

  Widget criarTelaTeste() {
    return MaterialApp(
      home: ListaPessoas(
        mockPacientes: mockPacientes,
        mockMotoristas: mockMotoristas,
      ),
    );
  }

  group('ListaPessoas - Testes de Widget e Filtros (Issue #34)', () {
    testWidgets(
      'Carrega com dados padrão sem colisão de chaves (sem exceptions)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: ListaPessoas()));
        expect(tester.takeException(), isNull);
        expect(find.text('Gestão de Pessoas'), findsOneWidget);
        expect(find.text('Maria Silva Santos'), findsOneWidget);
        expect(find.text('João de Deus Pereira'), findsOneWidget);
      },
    );

    testWidgets('Carrega título, barra de busca e abas de filtro', (
      tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      expect(find.text('Gestão de Pessoas'), findsOneWidget);
      expect(find.text('Buscar por nome ou CPF...'), findsOneWidget);
      expect(find.text('Todos (3)'), findsOneWidget);
      expect(find.text('Pacientes (2)'), findsOneWidget);
      expect(find.text('Motoristas (1)'), findsOneWidget);
    });

    testWidgets('Exibe todos os registros na aba Todos', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(criarTelaTeste());

      expect(find.text('Carlos Drummond'), findsOneWidget);
      expect(find.text('Clarice Lispector'), findsOneWidget);
      expect(find.text('Machado de Assis'), findsOneWidget);
    });

    testWidgets('Filtra apenas pacientes ao selecionar a aba Pacientes', (
      tester,
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
      tester,
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
      (tester) async {
        final mockAdmins = [
          AdminModel(
            id: 'adm_teste',
            nome: 'Guimarães Rosa',
            cpf: '123.321.456-99',
            email: 'guimaraes@saude.sp.gov.br',
            telefone: '(14) 99888-7766',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: ListaPessoas(
              mockPacientes: mockPacientes,
              mockMotoristas: mockMotoristas,
              mockAdmins: mockAdmins,
            ),
          ),
        );

        expect(find.text('Administradores (1)'), findsOneWidget);
        await tester.tap(find.text('Administradores (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Guimarães Rosa'), findsOneWidget);
        expect(find.text('Carlos Drummond'), findsNothing);
        expect(find.text('Machado de Assis'), findsNothing);
      },
    );

    testWidgets('Busca textual por nome filtra a lista corretamente', (
      tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      await tester.enterText(find.byType(TextField), 'Clarice');
      await tester.pumpAndSettle();

      expect(find.text('Clarice Lispector'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Machado de Assis'), findsNothing);
    });

    testWidgets('Busca por CPF filtra a lista corretamente', (tester) async {
      await tester.pumpWidget(criarTelaTeste());

      await tester.enterText(find.byType(TextField), '999.888');
      await tester.pumpAndSettle();

      expect(find.text('Machado de Assis'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
    });

    testWidgets('Exibe estado vazio quando busca não encontra resultados', (
      tester,
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

    testWidgets('Diálogo de exclusão lógica abre e confirma', (
      tester,
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
  });
}
