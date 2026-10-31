import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/formulario_inicio_viagem.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/validacao_viagem.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  group('1. Validação Pura de Quilometragem e Negócio', () {
    const int ultimaKm = 85000;

    test('Rejeita quilometragem vazia ou nula', () {
      final resNulo = ValidacaoViagem.validarQuilometragem(
        valorDigitado: null,
        ultimaKmRegistrada: ultimaKm,
      );
      expect(resNulo.valido, isFalse);
      expect(resNulo.mensagemErro, contains('Informe a quilometragem'));

      final resVazio = ValidacaoViagem.validarQuilometragem(
        valorDigitado: '   ',
        ultimaKmRegistrada: ultimaKm,
      );
      expect(resVazio.valido, isFalse);
      expect(resVazio.mensagemErro, contains('Informe a quilometragem'));
    });

    test('Rejeita quilometragem não numérica ou com caracteres inválidos', () {
      final resTexto = ValidacaoViagem.validarQuilometragem(
        valorDigitado: 'abc850',
        ultimaKmRegistrada: ultimaKm,
      );
      expect(resTexto.valido, isFalse);
      expect(resTexto.mensagemErro, contains('número inteiro válido'));

      final resDecimal = ValidacaoViagem.validarQuilometragem(
        valorDigitado: '85000.5',
        ultimaKmRegistrada: ultimaKm,
      );
      expect(resDecimal.valido, isFalse);
      expect(resDecimal.mensagemErro, contains('número inteiro válido'));
    });

    test('Rejeita quilometragem inferior à última registrada do veículo', () {
      final resMenor = ValidacaoViagem.validarQuilometragem(
        valorDigitado: '84999',
        ultimaKmRegistrada: ultimaKm,
      );
      expect(resMenor.valido, isFalse);
      expect(
        resMenor.mensagemErro,
        contains('não pode ser menor que a última registrada'),
      );
    });

    test(
      'Rejeita quilometragem acima do teto de plausibilidade (+2000 km)',
      () {
        // Valida tentativa de inserção com acréscimo de 2001 km acima da última quilometragem
        final resAcima = ValidacaoViagem.validarQuilometragem(
          valorDigitado: '87001',
          ultimaKmRegistrada: ultimaKm,
          tetoMaximo: 2000,
        );
        expect(resAcima.valido, isFalse);
        expect(
          resAcima.mensagemErro,
          contains('acima do teto de plausibilidade'),
        );
      },
    );

    test('Aceita quilometragem válida igual ou superior dentro do teto', () {
      // Valida inserção com o mesmo valor da quilometragem registrada
      final resIgual = ValidacaoViagem.validarQuilometragem(
        valorDigitado: '85000',
        ultimaKmRegistrada: ultimaKm,
      );
      expect(resIgual.valido, isTrue);

      // Valida inserção com acréscimo dentro do limite permitido
      final resNormal = ValidacaoViagem.validarQuilometragem(
        valorDigitado: '85085',
        ultimaKmRegistrada: ultimaKm,
      );
      expect(resNormal.valido, isTrue);
      expect(resNormal.mensagemErro, isNull);
    });
  });

  group('2. Ciclo de Vida da Viagem e Máquina de Estados', () {
    test(
      'Calcula estado correto dependendo da viagem ativa e da interface',
      () {
        // Valida o estado viagemAtiva quando o indicador temViagemAtiva é verdadeiro
        expect(
          ValidacaoViagem.resolverEstadoMotorista(
            temViagemAtiva: true,
            modalFormularioAberto: false,
          ),
          equals(EstadoViagem.viagemAtiva),
        );

        // Valida o estado preenchendoFormulario quando não há viagem ativa e o modal está aberto
        expect(
          ValidacaoViagem.resolverEstadoMotorista(
            temViagemAtiva: false,
            modalFormularioAberto: true,
          ),
          equals(EstadoViagem.preenchendoFormulario),
        );

        // Valida o estado semViagem quando não há viagem ativa e o modal não está aberto
        expect(
          ValidacaoViagem.resolverEstadoMotorista(
            temViagemAtiva: false,
            modalFormularioAberto: false,
          ),
          equals(EstadoViagem.semViagem),
        );
      },
    );
  });

  group('3. Filtro de Veículos em Uso', () {
    final veiculos = [
      const VeiculoModel(
        id: 'v1',
        placa: 'ABC-1234',
        modelo: 'Spin',
        quilometragemAtual: 50000,
        emUso: false,
      ),
      const VeiculoModel(
        id: 'v2',
        placa: 'XYZ-5678',
        modelo: 'Master',
        quilometragemAtual: 120000,
        emUso: true,
      ),
      const VeiculoModel(
        id: 'v3',
        placa: 'DEF-9999',
        modelo: 'Cronos',
        quilometragemAtual: 30000,
        emUso: false,
      ),
    ];

    test('Exclui veículos marcados como emUso: true', () {
      final disponiveis = ValidacaoViagem.filtrarVeiculosDisponiveis(veiculos);
      expect(disponiveis.length, equals(2));
      expect(
        disponiveis.map((v) => v.placa),
        containsAll(['ABC-1234', 'DEF-9999']),
      );
      expect(disponiveis.map((v) => v.placa), isNot(contains('XYZ-5678')));
    });

    test('Exclui veículos com placas presentes em viagens ativas', () {
      final disponiveis = ValidacaoViagem.filtrarVeiculosDisponiveis(
        veiculos,
        placasEmUso: {'DEF-9999'},
      );
      expect(disponiveis.length, equals(1));
      expect(disponiveis.first.placa, equals('ABC-1234'));
    });
  });

  group('4. Concorrência: Duas Sessões Tentando Iniciar o Mesmo Veículo', () {
    late ViagemService service;

    setUp(() {
      service = ViagemService();
      service.resetParaTestes(
        veiculosIniciais: [
          const VeiculoModel(
            id: 'v_concorrencia',
            placa: 'CON-2026',
            modelo: 'Van Municipal',
            quilometragemAtual: 90000,
            emUso: false,
          ),
        ],
      );
    });

    test(
      'Apenas a primeira sessão obtém sucesso; a segunda é bloqueada com erro',
      () async {
        final veiculoAlvo = const VeiculoModel(
          id: 'v_concorrencia',
          placa: 'CON-2026',
          modelo: 'Van Municipal',
          quilometragemAtual: 90000,
          emUso: false,
        );

        // Primeira sessão envia solicitação de início de viagem
        final resSessao1 = await service.iniciarViagem(
          veiculo: veiculoAlvo,
          kmInicial: 90050,
          cidadeDestino: 'São José do Rio Preto',
          motoristaId: 'mot_carlos',
          motoristaNome: 'Carlos Silva',
        );

        expect(resSessao1.sucesso, isTrue);
        expect(resSessao1.viagem, isNotNull);
        expect(resSessao1.viagem!.veiculoPlaca, equals('CON-2026'));

        // Segunda sessão envia solicitação para o mesmo veículo com outro condutor
        final resSessao2 = await service.iniciarViagem(
          veiculo: veiculoAlvo,
          kmInicial: 90060,
          cidadeDestino: 'Mirassol',
          motoristaId: 'mot_marcos',
          motoristaNome: 'Marcos Oliveira',
        );

        expect(resSessao2.sucesso, isFalse);
        expect(resSessao2.mensagemErro, contains('já está em uso'));
      },
    );
  });

  group(
    '5. Componente Visual FormularioInicioViagem (Estados da Interface)',
    () {
      testWidgets(
        'Estado Carregando: exibe indicador de progresso e mensagem',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: FormularioInicioViagem(forcarCarregando: true),
              ),
            ),
          );

          expect(
            find.text('Carregando veículos disponíveis...'),
            findsOneWidget,
          );
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );

      testWidgets(
        'Estado Vazio: exibe alerta quando nenhum veículo está disponível',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: FormularioInicioViagem(forcarVeiculos: [])),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Nenhum veículo disponível no momento.'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Estado Erro: exibe mensagem quando ocorre falha ao buscar veículos',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: FormularioInicioViagem(
                  forcarErro: 'Falha de conexão com a central da frota.',
                ),
              ),
            ),
          );

          expect(
            find.text('Falha de conexão com a central da frota.'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Estado Normal: bloqueia KM até seleção e desbloqueia após escolha',
        (WidgetTester tester) async {
          final veiculoTeste = const VeiculoModel(
            id: 'v10',
            placa: 'TEST-100',
            modelo: 'Spin Saúde',
            quilometragemAtual: 45000,
            emUso: false,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FormularioInicioViagem(forcarVeiculos: [veiculoTeste]),
              ),
            ),
          );

          // Verifica a presença dos textos e do botão de início
          expect(find.text('Iniciar Viagem'), findsNWidgets(2));
          expect(find.byKey(const Key('botaoIniciarViagem')), findsOneWidget);
          expect(find.text('Veículo da Frota'), findsOneWidget);
          expect(find.text('Quilometragem Inicial'), findsOneWidget);

          // Verifica o texto de instrução exibido antes da escolha do veículo
          expect(find.text('Selecione o veículo acima'), findsOneWidget);

          // Abre o campo de seleção de veículos
          await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
          await tester.pumpAndSettle();

          // Seleciona o item correspondente ao veículo de teste
          await tester.tap(find.textContaining('TEST-100').last);
          await tester.pumpAndSettle();

          // Verifica a inserção automática e texto de referência da última quilometragem
          expect(find.text('45000'), findsOneWidget);
          expect(find.text('Última: 45000 km'), findsOneWidget);
        },
      );

      testWidgets(
        'Reação em Tempo Real: revoga seleção se veículo entrar em uso',
        (WidgetTester tester) async {
          final streamController =
              StreamController<List<VeiculoModel>>.broadcast();

          final veiculo1 = const VeiculoModel(
            id: 'v_reativo',
            placa: 'REA-1234',
            modelo: 'Ambulância UTI',
            quilometragemAtual: 32000,
            emUso: false,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FormularioInicioViagem(
                  veiculosStreamOverride: streamController.stream,
                ),
              ),
            ),
          );

          // Emite a lista com o veículo disponível através da Stream
          streamController.add([veiculo1]);
          await tester.pumpAndSettle();

          // Abre o dropdown e seleciona o veículo
          await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('REA-1234').last);
          await tester.pumpAndSettle();

          expect(find.text('32000'), findsOneWidget);

          // Emite uma nova lista vazia na Stream para simular alteração externa
          streamController.add([]);
          await tester.pumpAndSettle();

          // Verifica a exibição da mensagem de veículo em uso
          expect(
            find.textContaining('acabou de entrar em uso por outro motorista'),
            findsOneWidget,
          );

          await streamController.close();
        },
      );
    },
  );
}
