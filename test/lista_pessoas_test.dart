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
// Importa o framework oficial de testes de widgets do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa a tela ListaPessoas sob teste
import 'package:trans_saude/lista_pessoas.dart';
// Importa o modelo de administradores
import 'package:trans_saude/models/admin_model.dart';
// Importa o modelo de motoristas
import 'package:trans_saude/models/motorista_model.dart';
// Importa o modelo de pacientes
import 'package:trans_saude/models/paciente_model.dart';

// Função principal de entrada da suíte de testes de ListaPessoas
void main() {
  // Lista de pacientes simulados para os testes de widget
  final mockPacientes = [
    // Primeiro paciente mockado
    PacienteModel(
      id: 'p1',
      nome: 'Carlos Drummond',
      cpf: '111.222.333-44',
      telefone: '(14) 99111-2222',
      enderecoPaciente: 'Rua Poeta, 10',
      localConsulta: 'Hospital das Clínicas',
    ),
    // Segundo paciente mockado
    PacienteModel(
      id: 'p2',
      nome: 'Clarice Lispector',
      cpf: '555.666.777-88',
      telefone: '(14) 99333-4444',
      enderecoPaciente: 'Av. Estrela, 50',
      localConsulta: 'AME Bauru',
    ),
  ];

  // Lista de motoristas simulados para os testes de widget
  final mockMotoristas = [
    // Primeiro motorista mockado
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

  // Função auxiliar que cria o widget da tela de teste com mocks injetados
  Widget criarTelaTeste() {
    // Retorna MaterialApp envolvendo a tela ListaPessoas
    return MaterialApp(
      // Configura a tela inicial com pacientes e motoristas de teste
      home: ListaPessoas(
        mockPacientes: mockPacientes,
        mockMotoristas: mockMotoristas,
      ),
    );
  }

  // Agrupamento dos testes de widget e de filtros da tela ListaPessoas
  group('ListaPessoas - Testes de Widget e Filtros (Issue #34)', () {
    // Testa o carregamento padrão da tela sem lançar exceções de layout ou chave
    testWidgets(
      'Carrega com dados padrão sem colisão de chaves (sem exceptions)',
      (tester) async {
        // Configura viewport de 800x1200 pixels
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        // Registra restauração de dimensões ao término
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Renderiza a tela sem mocks explícitos para exercitar os dados estáticos padrão
        await tester.pumpWidget(const MaterialApp(home: ListaPessoas()));
        // Assegura que nenhuma exceção foi capturada
        expect(tester.takeException(), isNull);
        // Valida que o título da tela está presente
        expect(find.text('Gestão de Pessoas'), findsOneWidget);
        // Valida presença de paciente padrão
        expect(find.text('Maria Silva Santos'), findsOneWidget);
        // Valida presença de motorista padrão
        expect(find.text('João de Deus Pereira'), findsOneWidget);
      },
    );

    // Testa se o cabeçalho, a barra de busca e as abas com contadores são renderizados
    testWidgets('Carrega título, barra de busca e abas de filtro', (
      tester,
    ) async {
      // Monta o widget de teste
      await tester.pumpWidget(criarTelaTeste());

      // Valida o título na AppBar
      expect(find.text('Gestão de Pessoas'), findsOneWidget);
      // Valida o texto placeholder do campo de busca
      expect(find.text('Buscar por nome ou CPF...'), findsOneWidget);
      // Valida o contador total da aba Todos
      expect(find.text('Todos (3)'), findsOneWidget);
      // Valida o contador da aba Pacientes
      expect(find.text('Pacientes (2)'), findsOneWidget);
      // Valida o contador da aba Motoristas
      expect(find.text('Motoristas (1)'), findsOneWidget);
    });

    // Testa a exibição completa de todos os registros na aba padrão Todos
    testWidgets('Exibe todos os registros na aba Todos', (tester) async {
      // Configura dimensões de viewport
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Renderiza a tela
      await tester.pumpWidget(criarTelaTeste());

      // Valida presença de Carlos Drummond
      expect(find.text('Carlos Drummond'), findsOneWidget);
      // Valida presença de Clarice Lispector
      expect(find.text('Clarice Lispector'), findsOneWidget);
      // Valida presença de Machado de Assis
      expect(find.text('Machado de Assis'), findsOneWidget);
    });

    // Testa a filtragem exclusiva de pacientes ao tocar na aba Pacientes
    testWidgets('Filtra apenas pacientes ao selecionar a aba Pacientes', (
      tester,
    ) async {
      // Monta a tela
      await tester.pumpWidget(criarTelaTeste());

      // Clica na aba Pacientes
      // Toca no chip de Pacientes
      await tester.tap(find.text('Pacientes (2)'));
      await tester.pumpAndSettle();

      // Valida que apenas os pacientes estão visíveis
      expect(find.text('Carlos Drummond'), findsOneWidget);
      expect(find.text('Clarice Lispector'), findsOneWidget);
      // Valida que o motorista Machado de Assis foi ocultado
      expect(find.text('Machado de Assis'), findsNothing);
    });

    // Testa a filtragem exclusiva de motoristas ao tocar na aba Motoristas
    testWidgets('Filtra apenas motoristas ao selecionar a aba Motoristas', (
      tester,
    ) async {
      // Monta a tela
      await tester.pumpWidget(criarTelaTeste());

      // Clica na aba Motoristas
      // Toca no chip de Motoristas
      await tester.tap(find.text('Motoristas (1)'));
      await tester.pumpAndSettle();

      // Valida que o motorista Machado de Assis é exibido
      expect(find.text('Machado de Assis'), findsOneWidget);
      // Valida que os pacientes não são exibidos
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Clarice Lispector'), findsNothing);
    });

    // Testa a filtragem exclusiva de administradores ao tocar na aba Administradores
    testWidgets(
      'Filtra apenas administradores ao selecionar a aba Administradores',
      (tester) async {
        // Administrador de teste adicional
        final mockAdmins = [
          AdminModel(
            id: 'adm_teste',
            nome: 'Guimarães Rosa',
            cpf: '123.321.456-99',
            email: 'guimaraes@saude.sp.gov.br',
            telefone: '(14) 99888-7766',
          ),
        ];

        // Monta a tela incluindo administradores
        await tester.pumpWidget(
          MaterialApp(
            home: ListaPessoas(
              mockPacientes: mockPacientes,
              mockMotoristas: mockMotoristas,
              mockAdmins: mockAdmins,
            ),
          ),
        );

        // Valida aba Administradores
        expect(find.text('Administradores (1)'), findsOneWidget);
        // Toca no chip de administradores
        await tester.tap(find.text('Administradores (1)'));
        await tester.pumpAndSettle();

        // Valida exibição de Guimarães Rosa
        expect(find.text('Guimarães Rosa'), findsOneWidget);
        // Valida ausência de outros perfis
        expect(find.text('Carlos Drummond'), findsNothing);
        expect(find.text('Machado de Assis'), findsNothing);
      },
    );

    // Testa se a busca por nome filtra a lista corretamente
    testWidgets('Busca textual por nome filtra a lista corretamente', (
      tester,
    ) async {
      // Monta a tela
      await tester.pumpWidget(criarTelaTeste());

      // Digita 'Clarice' no campo de busca
      await tester.enterText(find.byType(TextField), 'Clarice');
      await tester.pumpAndSettle();

      // Valida que apenas Clarice Lispector permaneceu
      expect(find.text('Clarice Lispector'), findsOneWidget);
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Machado de Assis'), findsNothing);
    });

    // Testa se a busca por CPF filtra a lista corretamente
    testWidgets('Busca por CPF filtra a lista corretamente', (tester) async {
      // Monta a tela
      await tester.pumpWidget(criarTelaTeste());

      // Digita dígitos do CPF de Machado de Assis
      await tester.enterText(find.byType(TextField), '999.888');
      await tester.pumpAndSettle();

      // Valida que Machado de Assis foi localizado
      expect(find.text('Machado de Assis'), findsOneWidget);
      // Valida que os demais foram filtrados
      expect(find.text('Carlos Drummond'), findsNothing);
    });

    // Testa a exibição do estado vazio quando nenhum registro combina com o texto
    testWidgets('Exibe estado vazio quando busca não encontra resultados', (
      tester,
    ) async {
      // Monta a tela
      await tester.pumpWidget(criarTelaTeste());

      // Digita termo inexistente
      await tester.enterText(find.byType(TextField), 'Inexistente XYZ');
      await tester.pumpAndSettle();

      // Valida mensagem amigável de estado vazio
      expect(find.text('Nenhuma pessoa encontrada'), findsOneWidget);
      expect(
        find.text('Tente buscar com outro nome ou número de CPF.'),
        findsOneWidget,
      );
    });

    // Testa o fluxo completo de abertura do diálogo de inativação e remoção visual do registro
    testWidgets('Diálogo de inativação (exclusão lógica) abre e confirma', (
      tester,
    ) async {
      // Monta a tela
      await tester.pumpWidget(criarTelaTeste());

      // Localiza o botão 'Inativar' do primeiro card
      // Obtém o botão Inativar do primeiro item
      final botaoInativar = find.text('Inativar').first;
      await tester.tap(botaoInativar);
      await tester.pumpAndSettle();

      // Confirma que abriu o alerta explicativo com a justificativa de governança
      // Valida título do diálogo
      expect(find.text('Inativar Registro'), findsOneWidget);
      // Valida mensagem com justificativa de governança e auditoria
      expect(
        find.textContaining('Conforme as regras de governança e auditoria'),
        findsOneWidget,
      );

      // Clica em Confirmar Inativação
      // Confirma a ação no diálogo modal
      await tester.tap(find.text('Confirmar Inativação'));
      await tester.pumpAndSettle();

      // Registro do Carlos foi inativado da lista
      // Valida que o registro foi removido visualmente da tela
      expect(find.text('Carlos Drummond'), findsNothing);
      expect(find.text('Clarice Lispector'), findsOneWidget);
    // Fechamento do testWidgets
    });
  // Fechamento do grupo
  });
// Fechamento da função main
}
