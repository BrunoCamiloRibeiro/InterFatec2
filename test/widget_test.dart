import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/Outdated/administrativo.dart';
import 'package:trans_saude/Outdated/login.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/Outdated/paciente.dart';
import 'package:trans_saude/Outdated/register.dart';
import 'package:trans_saude/components/formulario_novo_veiculo.dart';

void main() {
  testWidgets('Tela do paciente carrega corretamente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Paciente()));
    expect(find.text('Painel Paciente'), findsOneWidget);
  });

  testWidgets('Tela de login carrega com dropdown e botões', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Login()));
    expect(find.text('Acesse sua Conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Registrar-se'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('Tela de registro carrega com campos e botão entrar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Register()));
    expect(find.text('Criar Nova Conta'), findsOneWidget);
    expect(find.text('CONFIRMAR SENHA'), findsOneWidget);
    expect(find.text('Cadastrar'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Tela administrativo carrega cards e botões', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Administrativo()));
    expect(find.text('Gestão de Transporte'), findsOneWidget);
    expect(find.text('Painel do Administrador'), findsOneWidget);
    expect(find.text('Novo Cadastro de Paciente'), findsOneWidget);
    expect(find.text('Salvar Paciente'), findsOneWidget);
  });

  testWidgets('Tela motorista carrega lista e footer de lugares e relatório', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Motorista()));
    expect(find.text('Lista de Passageiros'), findsOneWidget);
    expect(find.text('Lugares: 7 / 15'), findsOneWidget);
    expect(find.text('Gerar Relatório'), findsOneWidget);
  });

  testWidgets('Formulário de veículo valida placa duplicada e exibe sugestões', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? veiculoSalvo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormularioNovoVeiculo(
            placasExistentes: const ['ABC1D23', 'DEF4G56'],
            onSalvar: (v) => veiculoSalvo = v,
          ),
        ),
      ),
    );

    // Verifica renderização do modal
    expect(find.text('Novo Veículo'), findsOneWidget);
    expect(find.text('Placa *'), findsOneWidget);

    // 1. Tenta salvar com campos vazios (bloqueia)
    await tester.tap(find.text('Salvar Veículo'));
    await tester.pumpAndSettle();
    expect(find.text('Informe a placa'), findsOneWidget);
    expect(veiculoSalvo, isNull);

    // 2. Digita placa duplicada 'ABC1D23' (deve avisar e bloquear)
    await tester.enterText(find.widgetWithText(TextFormField, 'Placa *'), 'ABC1D23');
    await tester.pumpAndSettle();
    expect(find.text('Já existe outro veículo cadastrado com esta placa.'), findsOneWidget);

    await tester.tap(find.text('Salvar Veículo'));
    await tester.pumpAndSettle();
    expect(find.text('Esta placa já pertence a outro veículo'), findsOneWidget);
    expect(veiculoSalvo, isNull);

    // 3. Digita placa fora do padrão Mercosul/antigo (ex: 'XYZ99AA')
    // Deve avisar visualmente, mas NÃO bloquear o salvamento
    await tester.enterText(find.widgetWithText(TextFormField, 'Placa *'), 'XYZ99AA');
    await tester.pumpAndSettle();
    expect(
      find.text('Aviso: Formato fora do padrão Mercosul (ABC1D23) ou antigo (ABC1234).'),
      findsOneWidget,
    );

    // 4. Preenche marca e modelo
    await tester.enterText(find.widgetWithText(TextFormField, 'Marca *'), 'Renault');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Modelo *'), 'Master');
    await tester.pumpAndSettle();

    // Salva veículo com placa fora do padrão (não deve ser bloqueado)
    await tester.tap(find.text('Salvar Veículo'));
    await tester.pumpAndSettle();
    expect(veiculoSalvo, isNotNull);
    expect(veiculoSalvo?['placa'], 'XYZ99AA');
    expect(veiculoSalvo?['marca'], 'Renault');
    expect(veiculoSalvo?['modelo'], 'Master');
  });
}
