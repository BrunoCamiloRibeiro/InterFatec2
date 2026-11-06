import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/formulario_pessoa.dart';
import 'package:trans_saude/lista_pessoas.dart';

void main() {
  Widget criarAppTeste(Widget filho) {
    return MaterialApp(home: Scaffold(body: filho));
  }

  group('1. Validações e Estados de Interface (Modo Criação)', () {
    testWidgets(
      'Modo Criação: Exibe campos base e validação de campos obrigatórios',
      (WidgetTester tester) async {
        await tester.pumpWidget(criarAppTeste(const FormularioPessoa()));

        expect(find.text('Nova Pessoa'), findsOneWidget);
        expect(find.text('Cadastrar'), findsOneWidget);

        // Clica em cadastrar com campos vazios para disparar validação
        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Informe o nome completo'), findsOneWidget);
        expect(find.textContaining('CPF inválido'), findsOneWidget);
      },
    );
  });

  group('2. Alternância Dinâmica de Perfil (Paciente, Motorista, Admin)', () {
    testWidgets(
      'Alterna perfil dinamicamente entre Paciente, Motorista e Admin',
      (WidgetTester tester) async {
        await tester.pumpWidget(criarAppTeste(const FormularioPessoa()));

        // Inicialmente em Paciente: campos de consulta visíveis
        expect(find.text('Local da Consulta Médica'), findsOneWidget);
        expect(find.text('Número da CNH'), findsNothing);

        // Seleciona Motorista
        await tester.tap(find.text('Motorista'));
        await tester.pumpAndSettle();

        expect(find.text('Número da CNH'), findsOneWidget);
        expect(find.text('Modelo do Veículo'), findsOneWidget);
        expect(find.text('Placa'), findsOneWidget);
        expect(find.text('Local da Consulta Médica'), findsNothing);

        // Seleciona Administrador
        await tester.tap(find.text('Administrador'));
        await tester.pumpAndSettle();

        expect(find.text('E-mail Corporativo/Admin'), findsOneWidget);
        expect(find.text('Número da CNH'), findsNothing);
      },
    );
  });

  group('3. Modo Edição e Preservação de Campos (Update)', () {
    testWidgets(
      'Modo Edição: Pré-carrega dados da pessoa e permite atualizar',
      (WidgetTester tester) async {
        const pessoaMock = PessoaItem(
          id: 'pac_teste_1',
          nome: 'Maria da Silva',
          cpf: '529.982.247-25',
          telefone: '(14) 99876-5432',
          role: 'paciente',
          badgeLabel: 'Paciente',
          badgeCor: Color(0xFF2563EB),
          detalheExtra: 'Consulta: AME Bauru',
        );

        PessoaItem? pessoaRetornada;

        await tester.pumpWidget(
          criarAppTeste(
            FormularioPessoa(
              pessoaParaEditar: pessoaMock,
              onSalvo: (p) => pessoaRetornada = p,
            ),
          ),
        );

        expect(find.text('Editar Pessoa'), findsOneWidget);
        expect(find.text('Salvar Alterações'), findsOneWidget);
        expect(find.text('Maria da Silva'), findsOneWidget);
        expect(find.text('529.982.247-25'), findsOneWidget);
        expect(find.text('AME Bauru'), findsOneWidget);

        // Edita o nome
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Maria da Silva'),
          'Maria da Silva Santos Alterada',
        );
        await tester.pumpAndSettle();

        // Salva alterações
        await tester.tap(find.text('Salvar Alterações'));
        await tester.pumpAndSettle();

        expect(pessoaRetornada, isNotNull);
        expect(pessoaRetornada!.nome, equals('Maria da Silva Santos Alterada'));
        expect(pessoaRetornada!.id, equals('pac_teste_1'));
      },
    );

    testWidgets(
      'Modo Edição Motorista: Preserva CNH, modelo e placa do veículo',
      (WidgetTester tester) async {
        PessoaItem? pessoaRetornada;

        const motoristaOriginal = PessoaItem(
          id: 'mot_teste_1',
          nome: 'Marcos Silveira',
          cpf: '529.982.247-25',
          telefone: '(14) 99887-7665',
          role: 'motorista',
          badgeLabel: 'Motorista',
          badgeCor: Color(0xFF0F172A),
          cnh: '12345678901',
          veiculoModelo: 'Renault Master',
          veiculoPlaca: 'ABC1D23',
          detalheExtra: 'Veículo: Renault Master (ABC1D23)',
        );

        await tester.pumpWidget(
          criarAppTeste(
            FormularioPessoa(
              pessoaParaEditar: motoristaOriginal,
              onSalvo: (p) => pessoaRetornada = p,
            ),
          ),
        );

        // Verifica se os campos de CNH e Veículo foram pré-carregados
        expect(find.text('12345678901'), findsOneWidget);
        expect(find.text('Renault Master'), findsOneWidget);
        expect(find.text('ABC1D23'), findsOneWidget);

        // Modifica apenas o nome do motorista
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Marcos Silveira'),
          'Marcos Silveira Atualizado',
        );
        await tester.pumpAndSettle();

        // Salva
        await tester.tap(find.text('Salvar Alterações'));
        await tester.pumpAndSettle();

        expect(pessoaRetornada, isNotNull);
        expect(pessoaRetornada!.nome, equals('Marcos Silveira Atualizado'));
        expect(pessoaRetornada!.cnh, equals('12345678901'));
        expect(pessoaRetornada!.veiculoModelo, equals('Renault Master'));
        expect(pessoaRetornada!.veiculoPlaca, equals('ABC1D23'));
        expect(
          pessoaRetornada!.detalheExtra,
          contains('Renault Master (ABC1D23)'),
        );
      },
    );
  });

  group('4. Submissão e Callbacks de Sucesso', () {
    testWidgets(
      'Criação com sucesso aciona callback onSalvo com nova PessoaItem',
      (WidgetTester tester) async {
        PessoaItem? novaPessoa;

        await tester.pumpWidget(
          criarAppTeste(FormularioPessoa(onSalvo: (p) => novaPessoa = p)),
        );

        // Preenche dados válidos (CPF com dígitos verificadores matematicamente válidos)
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'João Batista Ferreira',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '52998224725');
        await tester.enterText(find.byType(TextFormField).at(2), '14998877665');
        await tester.enterText(
          find.byType(TextFormField).at(3),
          'Hospital das Clínicas',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        expect(novaPessoa, isNotNull);
        expect(novaPessoa!.nome, equals('João Batista Ferreira'));
        expect(novaPessoa!.role, equals('paciente'));
        expect(novaPessoa!.detalheExtra, contains('Hospital das Clínicas'));
      },
    );
  });
}
