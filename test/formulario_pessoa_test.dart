import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/formulario_pessoa.dart';
import 'package:trans_saude/lista_pessoas.dart';

/// ============================================================================
/// SUÍTE DE TESTES DE WIDGET: FORMULÁRIO DE CADASTRO E EDIÇÃO (ISSUE #34)
/// ============================================================================
/// Valida o ciclo completo do formulário polimórfico de pessoas:
/// 1. Validação de obrigatoriedade e máscaras na criação de novo registro.
/// 2. Alternância de campos contextuais conforme o perfil (Paciente, Motorista, Admin).
/// 3. Pré-carregamento e preservação de campos específicos (CNH) na edição.
/// 4. Submissão bem-sucedida e emissão de callbacks com modelos tipados.
void main() {
  /// Helper puro para envolver widgets de teste sob um MaterialApp com Scaffold
  Widget criarAppTeste(Widget filho) {
    return MaterialApp(home: Scaffold(body: filho));
  }

  group('1. Validações e Estados de Interface (Modo Criação)', () {
    testWidgets(
      'Modo Criação: Exibe campos base e validação de campos obrigatórios',
      (WidgetTester tester) async {
        // Arranjo: Renderiza formulário em modo criação (sem pessoa prévia)
        await tester.pumpWidget(criarAppTeste(const FormularioPessoa()));

        // Verificação inicial de títulos e botões de ação
        expect(find.text('Nova Pessoa'), findsOneWidget);
        expect(find.text('Cadastrar'), findsOneWidget);

        // Ação: Clica em cadastrar com campos vazios para disparar validação do Form
        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        // Verificação: Exibição das mensagens de erro nos campos obrigatórios
        expect(find.textContaining('Informe o nome completo'), findsOneWidget);
        expect(find.textContaining('CPF inválido'), findsOneWidget);
      },
    );
  });

  group('2. Alternância Dinâmica de Perfil (Paciente, Motorista, Admin)', () {
    testWidgets(
      'Alterna perfil dinamicamente entre Paciente, Motorista e Admin',
      (WidgetTester tester) async {
        // Arranjo: Renderiza formulário em estado inicial
        await tester.pumpWidget(criarAppTeste(const FormularioPessoa()));

        // Verificação de perfil padrão (Paciente): exibe campo de consulta médica
        expect(find.text('Local da Consulta Médica'), findsOneWidget);
        expect(find.text('Número da CNH'), findsNothing);

        // Ação: Seleciona o perfil de Motorista
        await tester.tap(find.text('Motorista'));
        await tester.pumpAndSettle();

        // Verificação: Exibe campo de CNH; não exibe campos de modelo e placa de veículo; esconde campos de consulta
        expect(find.text('Número da CNH'), findsOneWidget);
        expect(find.text('Modelo do Veículo'), findsNothing);
        expect(find.text('Placa'), findsNothing);
        expect(find.text('Local da Consulta Médica'), findsNothing);

        // Ação: Seleciona o perfil de Administrador
        await tester.tap(find.text('Administrador'));
        await tester.pumpAndSettle();

        // Verificação: Exibe campo de e-mail institucional; esconde campos de motorista
        expect(find.text('E-mail Corporativo/Admin'), findsOneWidget);
        expect(find.text('Número da CNH'), findsNothing);
      },
    );
  });

  group('3. Modo Edição e Preservação de Campos (Update)', () {
    testWidgets(
      'Modo Edição: Pré-carrega dados da pessoa e permite atualizar',
      (WidgetTester tester) async {
        // Arranjo: Cria mock de paciente para edição
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

        // Renderiza o formulário com dados pré-carregados
        await tester.pumpWidget(
          criarAppTeste(
            FormularioPessoa(
              pessoaParaEditar: pessoaMock,
              onSalvo: (p) => pessoaRetornada = p,
            ),
          ),
        );

        // Verificação: Confirma pré-população dos campos na interface
        expect(find.text('Editar Pessoa'), findsOneWidget);
        expect(find.text('Salvar Alterações'), findsOneWidget);
        expect(find.text('Maria da Silva'), findsOneWidget);
        expect(find.text('529.982.247-25'), findsOneWidget);
        expect(find.text('AME Bauru'), findsOneWidget);

        // Ação: Altera o nome do paciente
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Maria da Silva'),
          'Maria da Silva Santos Alterada',
        );
        await tester.pumpAndSettle();

        // Submete a atualização
        await tester.tap(find.text('Salvar Alterações'));
        await tester.pumpAndSettle();

        // Verificação: Objeto de retorno deve refletir a alteração mantendo o mesmo ID
        expect(pessoaRetornada, isNotNull);
        expect(pessoaRetornada!.nome, equals('Maria da Silva Santos Alterada'));
        expect(pessoaRetornada!.id, equals('pac_teste_1'));
      },
    );

    testWidgets(
      'Modo Edição Motorista: Não exibe campos de veículo/placa e preserva CNH e dados existentes',
      (WidgetTester tester) async {
        // Arranjo: Mock de motorista com dados de veículo e habilitação
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
          detalheExtra: 'CNH: 12345678901',
        );

        await tester.pumpWidget(
          criarAppTeste(
            FormularioPessoa(
              pessoaParaEditar: motoristaOriginal,
              onSalvo: (p) => pessoaRetornada = p,
            ),
          ),
        );

        // Verificação: Garante que o campo de CNH veio pré-carregado e não há campos de veículo/placa
        expect(find.text('12345678901'), findsOneWidget);
        expect(find.text('Modelo do Veículo'), findsNothing);
        expect(find.text('Placa'), findsNothing);

        // Ação: Modifica apenas o nome, sem tocar nos campos de veículo
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Marcos Silveira'),
          'Marcos Silveira Atualizado',
        );
        await tester.pumpAndSettle();

        // Submete as alterações
        await tester.tap(find.text('Salvar Alterações'));
        await tester.pumpAndSettle();

        // Verificação: Dados essenciais do veículo pré-existente e CNH são preservados
        expect(pessoaRetornada, isNotNull);
        expect(pessoaRetornada!.nome, equals('Marcos Silveira Atualizado'));
        expect(pessoaRetornada!.cnh, equals('12345678901'));
        expect(pessoaRetornada!.veiculoModelo, equals('Renault Master'));
        expect(pessoaRetornada!.veiculoPlaca, equals('ABC1D23'));
        expect(
          pessoaRetornada!.detalheExtra,
          contains('12345678901'),
        );
      },
    );
  });

  group('4. Submissão e Callbacks de Sucesso', () {
    testWidgets(
      'Criação com sucesso aciona callback onSalvo com nova PessoaItem',
      (WidgetTester tester) async {
        // Arranjo: Captura da instância emitida após salvar
        PessoaItem? novaPessoa;

        await tester.pumpWidget(
          criarAppTeste(FormularioPessoa(onSalvo: (p) => novaPessoa = p)),
        );

        // Ação: Preenche dados válidos (com CPF atendendo o algoritmo de Módulo 11)
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

        // Dispara criação do registro
        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        // Verificação: Callback executado com os dados formatados corretamente
        expect(novaPessoa, isNotNull);
        expect(novaPessoa!.nome, equals('João Batista Ferreira'));
        expect(novaPessoa!.role, equals('paciente'));
        expect(novaPessoa!.detalheExtra, contains('Hospital das Clínicas'));
      },
    );

    testWidgets(
      'Criação de motorista com sucesso cadastra apenas com CNH sem campos de veículo e placa',
      (WidgetTester tester) async {
        PessoaItem? novoMotorista;

        await tester.pumpWidget(
          criarAppTeste(FormularioPessoa(onSalvo: (p) => novoMotorista = p)),
        );

        // Ação: Seleciona Motorista
        await tester.tap(find.text('Motorista'));
        await tester.pumpAndSettle();

        // Verificação: Garante ausência dos campos de veículo e placa
        expect(find.text('Modelo do Veículo'), findsNothing);
        expect(find.text('Placa'), findsNothing);

        // Preenche dados do motorista
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Antônio Carlos Ferreira',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '52998224725');
        await tester.enterText(find.byType(TextFormField).at(2), '14997776655');
        await tester.enterText(find.byType(TextFormField).at(3), '01234567890');
        await tester.pumpAndSettle();

        // Dispara criação
        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        expect(novoMotorista, isNotNull);
        expect(novoMotorista!.nome, equals('Antônio Carlos Ferreira'));
        expect(novoMotorista!.role, equals('motorista'));
        expect(novoMotorista!.cnh, equals('01234567890'));
        expect(novoMotorista!.veiculoModelo, isNull);
        expect(novoMotorista!.veiculoPlaca, isNull);
        expect(novoMotorista!.detalheExtra, equals('CNH: 01234567890'));
      },
    );
  });

  group('5. Gestão de Acompanhante no Cadastro de Paciente', () {
    testWidgets(
      'Ativação de acompanhante exibe campos adicionais e valida obrigatoriedade do nome',
      (WidgetTester tester) async {
        await tester.pumpWidget(criarAppTeste(const FormularioPessoa()));

        // Inicialmente campos de acompanhante não aparecem
        expect(find.byKey(const Key('checkboxAcompanhante')), findsOneWidget);
        expect(find.byKey(const Key('campoNomeAcompanhante')), findsNothing);

        // Rola até o checkbox e marca a opção de acompanhante
        await tester.ensureVisible(find.byKey(const Key('checkboxAcompanhante')));
        await tester.tap(find.byKey(const Key('checkboxAcompanhante')));
        await tester.pumpAndSettle();

        // Agora os campos devem estar visíveis
        expect(find.byKey(const Key('campoNomeAcompanhante')), findsOneWidget);
        expect(find.byKey(const Key('campoCpfAcompanhante')), findsOneWidget);
        expect(find.byKey(const Key('campoTelAcompanhante')), findsOneWidget);

        // Preenche dados do paciente
        await tester.enterText(find.byType(TextFormField).at(0), 'Paciente Com Acomp');
        await tester.enterText(find.byType(TextFormField).at(1), '52998224725');
        await tester.enterText(find.byType(TextFormField).at(2), '14998877665');
        await tester.pumpAndSettle();

        // Tenta cadastrar sem nome de acompanhante
        await tester.ensureVisible(find.text('Cadastrar'));
        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Informe o nome do acompanhante'), findsOneWidget);
      },
    );

    testWidgets(
      'Criação de paciente com acompanhante preenchido emite dados no callback',
      (WidgetTester tester) async {
        PessoaItem? pacienteSalvo;

        await tester.pumpWidget(
          criarAppTeste(FormularioPessoa(onSalvo: (p) => pacienteSalvo = p)),
        );

        // Preenche dados do paciente
        await tester.enterText(find.byType(TextFormField).at(0), 'Lúcia de Fátima');
        await tester.enterText(find.byType(TextFormField).at(1), '52998224725');
        await tester.enterText(find.byType(TextFormField).at(2), '14998877665');
        await tester.enterText(find.byType(TextFormField).at(3), 'Hospital de Base');
        await tester.pumpAndSettle();

        // Ativa acompanhante
        await tester.ensureVisible(find.byKey(const Key('checkboxAcompanhante')));
        await tester.tap(find.byKey(const Key('checkboxAcompanhante')));
        await tester.pumpAndSettle();

        // Preenche campos do acompanhante
        await tester.ensureVisible(find.byKey(const Key('campoNomeAcompanhante')));
        await tester.enterText(find.byKey(const Key('campoNomeAcompanhante')), 'Roberto de Fátima');
        await tester.ensureVisible(find.byKey(const Key('campoCpfAcompanhante')));
        await tester.enterText(find.byKey(const Key('campoCpfAcompanhante')), '52998224725');
        await tester.ensureVisible(find.byKey(const Key('campoTelAcompanhante')));
        await tester.enterText(find.byKey(const Key('campoTelAcompanhante')), '14991122334');
        await tester.pumpAndSettle();

        // Cadastra
        await tester.ensureVisible(find.text('Cadastrar'));
        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        expect(pacienteSalvo, isNotNull);
        expect(pacienteSalvo!.nome, equals('Lúcia de Fátima'));
        expect(pacienteSalvo!.nomeAcompanhante, equals('Roberto de Fátima'));
        expect(pacienteSalvo!.cpfAcompanhante, equals('529.982.247-25'));
        expect(pacienteSalvo!.telAcompanhante, equals('(14) 99112-2334'));
        expect(pacienteSalvo!.detalheExtra, contains('Acomp: Roberto de Fátima'));
      },
    );

    testWidgets(
      'Modo edição pré-carrega acompanhante existente',
      (WidgetTester tester) async {
        const pacienteMock = PessoaItem(
          id: 'pac_com_acomp',
          nome: 'Clara Nunes',
          cpf: '529.982.247-25',
          telefone: '(14) 99876-5432',
          role: 'paciente',
          badgeLabel: 'Paciente',
          badgeCor: Color(0xFF2563EB),
          nomeAcompanhante: 'Carlos Nunes',
          cpfAcompanhante: '529.982.247-25',
          telAcompanhante: '(14) 99888-7766',
        );

        await tester.pumpWidget(
          criarAppTeste(FormularioPessoa(pessoaParaEditar: pacienteMock)),
        );

        expect(find.text('Carlos Nunes'), findsOneWidget);
        expect(find.byKey(const Key('checkboxAcompanhante')), findsOneWidget);
      },
    );
  });

  group('6. Responsividade Mobile (360x640)', () {
    testWidgets(
      'Renderiza formulário com seção de acompanhante expandida em 360x640 sem overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(criarAppTeste(const FormularioPessoa()));

        // Ativa acompanhante no celular rolando até ele
        await tester.ensureVisible(find.byKey(const Key('checkboxAcompanhante')));
        await tester.tap(find.byKey(const Key('checkboxAcompanhante')));
        await tester.pumpAndSettle();

        // Rola até o botão cadastrar
        await tester.ensureVisible(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        expect(find.text('Cadastrar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('7. Campo de Horário da Consulta no Criar e Editar Paciente', () {
    testWidgets(
      'Exibe e salva o Horário da Consulta (HH:mm) na criação e edição de paciente',
      (WidgetTester tester) async {
        PessoaItem? criado;
        await tester.pumpWidget(
          criarAppTeste(FormularioPessoa(onSalvo: (p) => criado = p)),
        );

        expect(find.byKey(const Key('campoHorarioConsultaPessoa')), findsOneWidget);
        expect(find.text('Horário da Consulta'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField).at(0), 'Helena Souza');
        await tester.enterText(find.byType(TextFormField).at(1), '52998224725');
        await tester.enterText(find.byType(TextFormField).at(2), '17991112222');
        await tester.enterText(find.byType(TextFormField).at(3), 'HB Rio Preto');
        await tester.enterText(
          find.byKey(const Key('campoHorarioConsultaPessoa')),
          '1430',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Cadastrar'));
        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();

        expect(criado, isNotNull);
        expect(criado!.horarioConsulta, equals('14:30'));
        expect(criado!.detalheExtra, contains('14:30'));

        // Testa edição preservando e alterando o Horário da Consulta
        PessoaItem? editado;
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: Scaffold(
              body: FormularioPessoa(
                key: UniqueKey(),
                pessoaParaEditar: criado,
                onSalvo: (p) => editado = p,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('14:30'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('campoHorarioConsultaPessoa')),
          '0915',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Salvar Alterações'));
        await tester.tap(find.text('Salvar Alterações'));
        await tester.pumpAndSettle();

        expect(editado, isNotNull);
        expect(editado!.horarioConsulta, equals('09:15'));
      },
    );
  });
}
