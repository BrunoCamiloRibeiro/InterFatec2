// ============================================================================
// ARQUIVO: test/lista_pessoas_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Suíte de testes de widgets e comportamento para a tela de Gestão de Pessoas
// (lib/lista_pessoas.dart - Issue #34). Testa:
// - Renderização inicial da tela com dados padrão sem colisão de chaves.
// - Exibição de cabeçalho, barra de busca e abas horizontais com contadores.
// - Filtragem pelas abas "Todos", "Pacientes", "Motoristas" e "Administradores".
// - Pesquisa reativa textual por Nome e por CPF.
// - Exibição do estado vazio com mensagem amigável quando nenhum registro combina.
// - Disparo do diálogo modal de inativação (exclusão lógica) com justificativa
//   de governança e atualização imediata da lista visual em memória.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Testes Automatizados de Interface / Widgets (test/).
//
// ONDE É USADO:
// Executado pelo executor oficial de testes do Flutter (`flutter test`).
//
// DE ONDE RECEBE DADOS:
// - Mocks de PacienteModel, MotoristaModel e AdminModel criados no arquivo de teste.
//
// O QUE EXPORTA / EXPÕE:
// - void main(): Ponto de entrada da suíte de testes.
//
// ORIGEM HISTÓRICA:
// Criado no commit 472aa0a (feat: criar tela de gestao de pessoas com busca
// e filtros por perfil - Issue #34).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart
// - package:flutter_test/flutter_test.dart
// - Sem efeitos colaterais externos.
// ============================================================================
// Importa a biblioteca de componentes visuais Material Design do Flutter
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/lista_pessoas.dart';
import 'package:trans_saude/models/admin_model.dart';
import 'package:trans_saude/models/motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';

/// ============================================================================
/// SUÍTE DE TESTES DE WIDGET: LISTA E GESTÃO DE PESSOAS (ISSUE #34)
/// ============================================================================
/// Valida as funcionalidades centrais da tela de Gestão de Pessoas (CRUD):
/// 1. Renderização inicial com contadores consolidados e prevenção de colisões.
/// 2. Filtragem polimórfica por papel (Abas: Todos, Pacientes, Motoristas, Admins).
/// 3. Busca em tempo real por nome e CPF com feedback de estado vazio.
/// 4. Disparo de ações contextuais: modal de cadastro, edição e exclusão lógica.
void main() {
  // Mocks de teste isolados para injeção direta no widget
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

  /// Helper para montar a tela de teste injetando dados controlados
  Widget criarTelaTeste({List<AdminModel>? mockAdmins}) {
    return MaterialApp(
      home: ListaPessoas(
        mockPacientes: mockPacientes,
        mockMotoristas: mockMotoristas,
        mockAdmins: mockAdmins,
      ),
    );
  }

  /// Configura o tamanho físico da viewport para testes com listas extensas
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
        // Arranjo: Viewport expandida para visualização de cards múltiplos
        configurarViewportLongo(tester);

        // Ação: Renderiza com a lista de teste injetada
        await tester.pumpWidget(criarTelaTeste());

        // Verificação: Nenhuma exceção de concorrência ou colisão de chaves
        expect(tester.takeException(), isNull);
        expect(find.text('Gestão de Pessoas'), findsOneWidget);
        expect(find.text('Carlos Drummond'), findsOneWidget);
        expect(find.text('Machado de Assis'), findsOneWidget);
      },
    );

    testWidgets('Carrega título, barra de busca e abas de filtro', (
      WidgetTester tester,
    ) async {
      // Ação: Monta a tela com dados mockados
      await tester.pumpWidget(criarTelaTeste());

      // Verificação: Elementos estruturais essenciais presentes na AppBar e cabeçalho
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

      // Ação: Monta a tela na aba padrão ('Todos')
      await tester.pumpWidget(criarTelaTeste());

      // Verificação: Todos os pacientes e motoristas são renderizados
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

      // Ação: Clica na aba Pacientes
      await tester.tap(find.text('Pacientes (2)'));
      await tester.pumpAndSettle();

      // Verificação: Apenas pacientes visíveis, motorista filtrado
      expect(find.text('Carlos Drummond'), findsOneWidget);
      expect(find.text('Clarice Lispector'), findsOneWidget);
      expect(find.text('Machado de Assis'), findsNothing);
    });

    testWidgets('Filtra apenas motoristas ao selecionar a aba Motoristas', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      // Ação: Clica na aba Motoristas
      await tester.tap(find.text('Motoristas (1)'));
      await tester.pumpAndSettle();

      // Verificação: Apenas motorista visível, pacientes ocultados
      expect(find.text('Machado de Assis'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Clarice Lispector'), findsNothing);
    });

    testWidgets(
      'Filtra apenas administradores ao selecionar a aba Administradores',
      (WidgetTester tester) async {
        // Arranjo: Mock pontual de administrador
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

        // Ação: Clica na aba Administradores
        expect(find.text('Administradores (1)'), findsOneWidget);
        await tester.tap(find.text('Administradores (1)'));
        await tester.pumpAndSettle();

        // Verificação: Exibe apenas o administrador
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

      // Ação: Digita busca parcial por nome
      await tester.enterText(find.byType(TextField), 'Clarice');
      await tester.pumpAndSettle();

      // Verificação: Apenas o registro correspondente permanece na lista
      expect(find.text('Clarice Lispector'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Machado de Assis'), findsNothing);
    });

    testWidgets('Busca por CPF filtra a lista corretamente', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      // Ação: Digita trecho do CPF formatado
      await tester.enterText(find.byType(TextField), '999.888');
      await tester.pumpAndSettle();

      // Verificação: Filtro localiza o motorista correspondente
      expect(find.text('Machado de Assis'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
    });

    testWidgets('Exibe estado vazio quando busca não encontra resultados', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(criarTelaTeste());

      // Ação: Digita termo sem correspondência
      await tester.enterText(find.byType(TextField), 'Inexistente XYZ');
      await tester.pumpAndSettle();

      // Verificação: Exibe mensagem amigável de estado vazio
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

      // Ação: Localiza o botão 'Excluir' do primeiro card e clica
      final botaoExcluir = find.text('Excluir').first;
      await tester.tap(botaoExcluir);
      await tester.pumpAndSettle();

      // Verificação: Diálogo explicativo de auditoria e governança é exibido
      expect(find.text('Excluir Registro'), findsOneWidget);
      expect(
        find.textContaining('Conforme as regras de governança e auditoria'),
        findsOneWidget,
      );

      // Ação: Confirma a exclusão lógica
      await tester.tap(find.text('Confirmar Exclusão'));
      await tester.pumpAndSettle();

      // Verificação: O registro é imediatamente removido da lista exibida
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Clarice Lispector'), findsOneWidget);
    });

    testWidgets(
      'Botão flutuante Novo abre diálogo de cadastro FormularioPessoa',
      (WidgetTester tester) async {
        await tester.pumpWidget(criarTelaTeste());

        // Ação: Clica no FloatingActionButton 'Novo'
        final botaoNovo = find.widgetWithText(FloatingActionButton, 'Novo');
        expect(botaoNovo, findsOneWidget);

        await tester.tap(botaoNovo);
        await tester.pumpAndSettle();

        // Verificação: Abre o modal de cadastro com título e botão correspondentes
        expect(find.text('Nova Pessoa'), findsOneWidget);
        expect(find.text('Cadastrar'), findsOneWidget);
      },
    );

    testWidgets(
      'Botão Editar no card abre formulário de edição com dados pré-carregados',
      (WidgetTester tester) async {
        await tester.pumpWidget(criarTelaTeste());

        // Ação: Clica no botão 'Editar' do primeiro card
        final botaoEditar = find.text('Editar').first;
        expect(botaoEditar, findsOneWidget);

        await tester.tap(botaoEditar);
        await tester.pumpAndSettle();

        // Verificação: Modal abre em modo de edição com o nome preenchido
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
