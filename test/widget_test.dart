import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/Outdated/administrativo.dart';
import 'package:trans_saude/Outdated/login.dart';
import 'package:trans_saude/Outdated/paciente.dart';
import 'package:trans_saude/Outdated/register.dart';
import 'package:trans_saude/components/formulario_inicio_viagem.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';

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

  testWidgets(
    'Tela de início de viagem (inicial) carrega com campos e botão iniciar',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaInicioViagem()));
      await tester.pumpAndSettle();

      expect(find.text('Início da Viagem'), findsOneWidget);
      expect(find.text('Veículo da Frota'), findsOneWidget);
      expect(find.text('Quilometragem Inicial'), findsOneWidget);
      expect(find.byKey(const Key('botaoIniciarViagem')), findsOneWidget);
    },
  );

  testWidgets(
    'Ao iniciar viagem na tela inicial, navega para a tela do motorista',
    (WidgetTester tester) async {
      final veiculoTeste = const VeiculoModel(
        id: 'veic_rapido',
        placa: 'BRA-2E19',
        modelo: 'Spin 7L',
        quilometragemAtual: 50000,
        emUso: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => Scaffold(
              body: FormularioInicioViagem(
                forcarVeiculos: [veiculoTeste],
                onViagemIniciada: (viagem) {
                  Navigator.of(context)
                      .pushReplacementNamed('/motorista', arguments: viagem);
                },
              ),
            ),
            '/motorista': (context) => const Motorista(),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Abre o menu dropdown e seleciona o veículo informado
      await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('BRA-2E19').last);
      await tester.pumpAndSettle();

      // Clica no botão para iniciar a viagem
      await tester.tap(find.byKey(const Key('botaoIniciarViagem')));
      await tester.pumpAndSettle();

      // Verifica a renderização da tela de passageiros e da identificação do veículo
      expect(find.text('Lista de Passageiros'), findsOneWidget);
      expect(find.textContaining('BRA-2E19'), findsOneWidget);
    },
  );

  testWidgets(
    'Tela motorista com viagem ativa abre lista de passageiros e popup do formulario de encerramento',
    (WidgetTester tester) async {
      final viagemEmAndamento = ViagemModel(
        id: 'viagem_ativa_teste',
        motoristaId: 'mot_teste',
        motoristaNome: 'Carlos Motorista',
        veiculoId: 'veic_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin 1.8 LTZ',
        kmInicial: 85420,
        cidadeDestino: 'São José do Rio Preto',
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
      );

      await tester.pumpWidget(
        MaterialApp(home: Motorista(viagemInicial: viagemEmAndamento)),
      );
      expect(find.text('Lista de Passageiros'), findsOneWidget);
      expect(find.text('Gerar Relatório'), findsOneWidget);

      await tester.tap(find.text('Gerar Relatório'));
      await tester.pumpAndSettle();

      expect(find.text('Formulário de Encerramento'), findsOneWidget);
      expect(find.text('Retorno'), findsOneWidget);
      expect(find.text('Km Retorno'), findsOneWidget);
      expect(find.text('Km Rodado'), findsOneWidget);
    },
  );
}
