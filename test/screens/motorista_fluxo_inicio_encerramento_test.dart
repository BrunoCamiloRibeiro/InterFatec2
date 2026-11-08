import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  setUp(() {
    ViagemService().resetParaTestes(
      veiculosIniciais: const [
        VeiculoModel(
          id: 'v1',
          placa: 'ABC-1D23',
          modelo: 'Chevrolet Spin 1.8 LTZ',
          capacidade: 7,
          quilometragemAtual: 85420,
          emUso: false,
        ),
      ],
    );
  });

  tearDown(() {
    ViagemService().resetParaTestes();
  });

  group('Fluxo do Motorista: Início de Viagem e Finalização com Confirmação', () {
    testWidgets(
      '1. Primeiro acesso do dia exibe FormularioInicioViagem para escolher veículo e KM inicial',
      (tester) async {
        // Inicializa o serviço sem viagem ativa
        expect(ViagemService().viagemAtiva, isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Motorista(),
          ),
        );
        // Processa microtask de carga de veículos
        await tester.pump();
        await tester.pumpAndSettle();

        // Deve exibir o formulário de início e seleção de veículo
        expect(find.text('Início da Viagem'), findsOneWidget);
        expect(find.text('Veículo da Frota'), findsOneWidget);
        expect(find.text('Quilometragem Inicial'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<VeiculoModel>), findsOneWidget);
        expect(find.byKey(const Key('campoKmInicial')), findsOneWidget);
        expect(find.byKey(const Key('botaoIniciarViagem')), findsOneWidget);

        // Não deve exibir a lista de passageiros enquanto não iniciar
        expect(find.text('Lista de Passageiros'), findsNothing);
      },
    );

    testWidgets(
      '2. Após iniciar viagem, exibe a Lista de Passageiros e NÃO exibe mais o formulário inicial',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Motorista(),
          ),
        );
        // Processa microtask de carga de veículos
        await tester.pump();
        await tester.pumpAndSettle();

        // Abre o dropdown de veículos da frota padrão (Poloni)
        await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
        await tester.pumpAndSettle();

        // Seleciona o primeiro veículo disponível na lista
        await tester.tap(find.textContaining('Spin').first);
        await tester.pumpAndSettle();

        // Inicia a viagem
        await tester.tap(find.byKey(const Key('botaoIniciarViagem')));
        await tester.pumpAndSettle();

        // Agora deve estar na Lista de Passageiros com a badge da viagem
        expect(find.text('Lista de Passageiros'), findsOneWidget);
        expect(find.text('Gerar Relatório'), findsOneWidget);

        // O formulário de início NÃO deve mais estar na tela
        expect(find.text('Veículo da Frota'), findsNothing);
      },
    );

    testWidgets(
      '3. Clicar em "Gerar Relatório" pergunta se tem certeza; se cancelar, continua na viagem',
      (tester) async {
        final viagemAtiva = ViagemModel(
          id: 'v_teste_123',
          motoristaId: 'mot_01',
          motoristaNome: 'João Motorista',
          veiculoId: 'veic_01',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Spin',
          kmInicial: 10000,
          cidadeDestino: 'São José do Rio Preto',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(viagemInicial: viagemAtiva),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lista de Passageiros'), findsOneWidget);

        // Clica para gerar relatório
        await tester.tap(find.text('Gerar Relatório'));
        await tester.pumpAndSettle();

        // Deve exibir a pergunta de confirmação
        expect(find.byKey(const Key('dialogConfirmarFinalizacaoViagem')), findsOneWidget);
        expect(
          find.text('Você tem certeza que quer finalizar a viagem?'),
          findsOneWidget,
        );

        // Cancela a finalização
        await tester.tap(find.byKey(const Key('botaoCancelarFinalizacao')));
        await tester.pumpAndSettle();

        // Permanece na Lista de Passageiros com a viagem ainda ativa
        expect(find.text('Lista de Passageiros'), findsOneWidget);
        expect(find.text('Formulário de Encerramento'), findsNothing);
      },
    );

    testWidgets(
      '4. Clicar em "Gerar Relatório", confirmar e finalizar a viagem reseta a tela para o FormularioInicioViagem',
      (tester) async {
        final viagemService = ViagemService();
        final veiculoTeste = const VeiculoModel(
          id: 'veic_encerramento_01',
          placa: 'XYZ-9876',
          modelo: 'Spin LTZ',
          quilometragemAtual: 50000,
          capacidade: 7,
          emUso: false,
        );

        // Inicia a viagem no serviço
        await viagemService.iniciarViagem(
          veiculo: veiculoTeste,
          kmInicial: 50000,
          cidadeDestino: 'Barretos',
          motoristaId: 'mot_teste',
          motoristaNome: 'Carlos',
        );

        expect(viagemService.viagemAtiva, isNotNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Motorista(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lista de Passageiros'), findsOneWidget);

        // Clica para gerar relatório
        await tester.tap(find.text('Gerar Relatório'));
        await tester.pumpAndSettle();

        // Confirma que tem certeza que deseja finalizar a viagem
        expect(
          find.text('Você tem certeza que quer finalizar a viagem?'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('botaoConfirmarFinalizacao')));
        await tester.pumpAndSettle();

        // Abre o Formulário de Encerramento
        expect(find.text('Formulário de Encerramento'), findsOneWidget);

        // Preenche retorno e clica em Confirmar
        await tester.enterText(find.widgetWithText(TextField, '00:00'), '18:30');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 85650'), '50200');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 230'), '200');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Viagem deve estar encerrada no serviço
        expect(viagemService.viagemAtiva, isNull);

        // A tela do motorista deve ter resetado para o formulário de início de viagem
        expect(find.text('Início da Viagem'), findsOneWidget);
        expect(find.text('Veículo da Frota'), findsOneWidget);
        expect(find.byKey(const Key('campoKmInicial')), findsOneWidget);
      },
    );
  });
}
