// ============================================================================
// ARQUIVO: test/widget_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Suíte principal de testes de widgets do projeto TransSaúde. Testa:
// - Renderização inicial básica das telas legadas do protótipo
//   (Paciente, Login, Register, Administrativo).
// - Renderização da tela de início de viagem (TelaInicioViagem) com seus campos
//   e botão de início.
// - Fluxo de navegação: seleção de veículo no dropdown e transição para a tela
//   do motorista com o veículo selecionado.
// - Renderização da tela do motorista com viagem ativa em andamento e abertura
//   do diálogo modal do formulário de encerramento da viagem.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Testes Automatizados de Interface / Widgets (test/widget_test.dart).
//
// ONDE É USADO:
// Executado pelo executor oficial de testes do Flutter (`flutter test`).
//
// DE ONDE RECEBE DADOS:
// - Mocks de VeiculoModel e ViagemModel criados inline nos testes.
//
// O QUE EXPORTA / EXPÕE:
// - void main(): Ponto de entrada da suíte de testes.
//
// ORIGEM HISTÓRICA:
// Arquivo originado do scaffold do Flutter (commit e34c23d) e evoluído pela equipe
// para cobrir os fluxos do motorista e início de viagem (commit 8d73cce).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart
// - package:flutter_test/flutter_test.dart
// - Sem efeitos colaterais externos.
// ============================================================================
// Importa a biblioteca de componentes visuais Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o framework oficial de testes do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa a tela administrativa legada
import 'package:trans_saude/Outdated/administrativo.dart';
// Importa a tela de login legada
import 'package:trans_saude/Outdated/login.dart';
// Importa a tela de paciente legada
import 'package:trans_saude/Outdated/paciente.dart';
// Importa a tela de registro legada
import 'package:trans_saude/Outdated/register.dart';
// Importa o componente e tela de início de viagem
import 'package:trans_saude/components/formulario_inicio_viagem.dart';
// Importa o modelo de dados representativo de veículos
import 'package:trans_saude/models/veiculo_model.dart';
// Importa o modelo de dados representativo de viagens
import 'package:trans_saude/models/viagem_model.dart';
// Importa a tela principal do motorista
import 'package:trans_saude/motorista.dart';

// Ponto de entrada da suíte principal de testes de widgets
void main() {
  // Teste de carregamento da tela de paciente legada
  testWidgets('Tela do paciente carrega corretamente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Paciente()));
    expect(find.text('Painel Paciente'), findsOneWidget);
  });

  // Teste de carregamento da tela de login legada
  testWidgets('Tela de login carrega com dropdown e botões', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Login()));
    expect(find.text('Acesse sua Conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Registrar-se'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  // Teste de carregamento da tela de registro legada
  testWidgets('Tela de registro carrega com campos e botão entrar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Register()));
    expect(find.text('Criar Nova Conta'), findsOneWidget);
    expect(find.text('CONFIRMAR SENHA'), findsOneWidget);
    expect(find.text('Cadastrar'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  // Teste de carregamento da tela administrativa legada
  testWidgets('Tela administrativo carrega cards e botões', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Administrativo()));
    expect(find.text('Gestão de Transporte'), findsOneWidget);
    expect(find.text('Painel do Administrador'), findsOneWidget);
    expect(find.text('Novo Cadastro de Paciente'), findsOneWidget);
    expect(find.text('Salvar Paciente'), findsOneWidget);
  });

  // Teste de carregamento da tela inicial de início de viagem
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

  // Teste do fluxo de transição: selecionar veículo e iniciar viagem
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
      // Abre o menu suspenso de veículos
      await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('BRA-2E19').last);
      await tester.pumpAndSettle();

      // Clica no botão para iniciar a viagem
      // Inicia a viagem
      await tester.tap(find.byKey(const Key('botaoIniciarViagem')));
      await tester.pumpAndSettle();

      // Verifica a renderização da tela de passageiros e da identificação do veículo
      // Valida que navegou para a tela de motorista exibindo a placa
      expect(find.text('Lista de Passageiros'), findsOneWidget);
      expect(find.textContaining('BRA-2E19'), findsOneWidget);
    },
  );

  // Teste da tela de motorista com viagem ativa e abertura do formulário de encerramento
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

      // Pergunta de confirmação obrigatória antes de emitir o relatório final
      expect(
        find.text('Você tem certeza que quer finalizar a viagem?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Sim, finalizar'));
      await tester.pumpAndSettle();

      expect(find.text('Formulário de Encerramento'), findsOneWidget);
      expect(find.text('Retorno'), findsOneWidget);
      expect(find.text('Km Retorno'), findsOneWidget);
      expect(find.text('Km Rodado'), findsOneWidget);
    },
  );
}
