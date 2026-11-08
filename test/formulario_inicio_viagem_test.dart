// ============================================================================
// ARQUIVO: test/formulario_inicio_viagem_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Suíte de testes unitários, de widget e de concorrência para o fluxo de
// início de viagem e para o componente FormularioInicioViagem
// (lib/components/formulario_inicio_viagem.dart). Cobre:
// 1. Validação pura de quilometragem e regras de negócio via ValidacaoViagem
//    (valores nulos, vazios, não-numéricos, retrocessos de KM, teto máximo).
// 2. Resolução da máquina de estados (EstadoViagem).
// 3. Filtragem de veículos em uso e placas reservadas em viagens ativas.
// 4. Teste de concorrência com duas sessões tentando iniciar o mesmo veículo.
// 5. Testes de widget nos diferentes estados de interface (carregando, vazio,
//    erro, seleção de veículo e atualização reativa via Stream).
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Testes Automatizados Unitários e de Widget (test/).
//
// ONDE É USADO:
// Executado pelo executor oficial de testes do Flutter (`flutter test`).
//
// DE ONDE RECEBE DADOS:
// - Mock de dados de veículos (VeiculoModel) e instâncias de ViagemService.
//
// O QUE EXPORTA / EXPÕE:
// - void main(): Ponto de entrada da suíte de testes.
//
// ORIGEM HISTÓRICA:
// Criado no commit 8d73cce (feat: implementar formulario de inicio de viagem
// e integracao na tela inicial).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart
// - package:flutter_test/flutter_test.dart
// - dart:async (StreamController)
// - Sem efeitos colaterais externos (ambiente hermético de testes).
// ============================================================================
// Importa utilitários assíncronos do Dart como StreamController
import 'dart:async';

// Importa os componentes de interface da biblioteca Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o framework de testes oficial do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o componente visual do formulário de início de viagem
import 'package:trans_saude/components/formulario_inicio_viagem.dart';
// Importa o modelo de dados representativo de veículos
import 'package:trans_saude/models/veiculo_model.dart';
// Importa o modelo de dados representativo de viagens
import 'package:trans_saude/models/viagem_model.dart';
// Importa a classe de validações e regras de negócio de viagens
import 'package:trans_saude/services/validacao_viagem.dart';
// Importa o serviço gerenciador de viagens
import 'package:trans_saude/services/viagem_service.dart';

// Função principal de entrada da suíte de testes do formulário de início de viagem
void main() {
  // Grupo 1: Testes unitários puros de validação de quilometragem e regras de negócio
  group('1. Validação Pura de Quilometragem e Negócio', () {
    // Constante com a última quilometragem registrada para uso nos testes
    const int ultimaKm = 85000;

    // Caso de teste: Rejeição de valores vazios ou nulos de quilometragem
    test('Rejeita quilometragem vazia ou nula', () {
      // Valida passagem de valor nulo
      final resNulo = ValidacaoViagem.validarQuilometragem(
        // Valor nulo
        valorDigitado: null,
        // Quilometragem base
        ultimaKmRegistrada: ultimaKm,
      // Fechamento da chamada
      );
      // Assegura que o resultado é inválido
      expect(resNulo.valido, isFalse);
      // Assegura que a mensagem de erro orienta o preenchimento
      expect(resNulo.mensagemErro, contains('Informe a quilometragem'));

      // Valida passagem de string apenas com espaços em branco
      final resVazio = ValidacaoViagem.validarQuilometragem(
        // Espaços em branco
        valorDigitado: '   ',
        // Quilometragem base
        ultimaKmRegistrada: ultimaKm,
      // Fechamento da chamada
      );
      // Assegura que o resultado é inválido
      expect(resVazio.valido, isFalse);
      // Assegura a mensagem de erro
      expect(resVazio.mensagemErro, contains('Informe a quilometragem'));
    // Fechamento do teste
    });

    // Caso de teste: Rejeição de caracteres não numéricos ou formato decimal
    test('Rejeita quilometragem não numérica ou com caracteres inválidos', () {
      // Valida string alfanumérica
      final resTexto = ValidacaoViagem.validarQuilometragem(
        // Texto com letras e números
        valorDigitado: 'abc850',
        // Quilometragem base
        ultimaKmRegistrada: ultimaKm,
      // Fechamento da chamada
      );
      // Assegura resultado inválido
      expect(resTexto.valido, isFalse);
      // Assegura mensagem exigindo número inteiro válido
      expect(resTexto.mensagemErro, contains('número inteiro válido'));

      // Valida número com casa decimal
      final resDecimal = ValidacaoViagem.validarQuilometragem(
        // Valor com ponto flutuante
        valorDigitado: '85000.5',
        // Quilometragem base
        ultimaKmRegistrada: ultimaKm,
      // Fechamento da chamada
      );
      // Assegura resultado inválido
      expect(resDecimal.valido, isFalse);
      // Assegura mensagem exigindo número inteiro
      expect(resDecimal.mensagemErro, contains('número inteiro válido'));
    // Fechamento do teste
    });

    // Caso de teste: Rejeição de quilometragem inferior à última registrada (retrocesso)
    test('Rejeita quilometragem inferior à última registrada do veículo', () {
      // Valida quilometragem 1 km menor que a registrada
      final resMenor = ValidacaoViagem.validarQuilometragem(
        // Valor 84999 (menor que 85000)
        valorDigitado: '84999',
        // Quilometragem base
        ultimaKmRegistrada: ultimaKm,
      // Fechamento da chamada
      );
      // Assegura resultado inválido
      expect(resMenor.valido, isFalse);
      // Assegura mensagem proibindo retrocesso de odômetro
      expect(
        resMenor.mensagemErro,
        contains('não pode ser menor que a última registrada'),
      // Fechamento do contains
      );
    // Fechamento do teste
    });

    // Caso de teste: Rejeição de quilometragem excessiva acima do teto de plausibilidade
    test(
      // Descrição do caso de teste
      'Rejeita quilometragem acima do teto de plausibilidade (+2000 km)',
      // Função do teste
      () {
        // Valida tentativa de inserção com acréscimo de 2001 km acima da última quilometragem
        // Tenta acréscimo de 2001 km ultrapassando o teto máximo configurado de 2000 km
        final resAcima = ValidacaoViagem.validarQuilometragem(
          // Valor 87001
          valorDigitado: '87001',
          // Quilometragem base 85000
          ultimaKmRegistrada: ultimaKm,
          // Teto configurado
          tetoMaximo: 2000,
        // Fechamento da chamada
        );
        // Assegura que o resultado é inválido
        expect(resAcima.valido, isFalse);
        // Assegura que o erro alerta para o teto de plausibilidade
        expect(
          resAcima.mensagemErro,
          contains('acima do teto de plausibilidade'),
        // Fechamento do contains
        );
      // Fechamento da função
      },
    // Fechamento do teste
    );

    // Caso de teste: Aceitação de quilometragem igual ou superior dentro do teto permitido
    test('Aceita quilometragem válida igual ou superior dentro do teto', () {
      // Valida inserção com o mesmo valor da quilometragem registrada
      // Valida odômetro inalterado desde a última chegada
      final resIgual = ValidacaoViagem.validarQuilometragem(
        // Mesmo valor 85000
        valorDigitado: '85000',
        // Quilometragem base
        ultimaKmRegistrada: ultimaKm,
      // Fechamento da chamada
      );
      // Assegura que o resultado é aceito como válido
      expect(resIgual.valido, isTrue);

      // Valida inserção com acréscimo dentro do limite permitido
      // Valida odômetro com acréscimo plausível de 85 km
      final resNormal = ValidacaoViagem.validarQuilometragem(
        // Valor 85085
        valorDigitado: '85085',
        // Quilometragem base
        ultimaKmRegistrada: ultimaKm,
      // Fechamento da chamada
      );
      // Assegura que o resultado é aceito como válido
      expect(resNormal.valido, isTrue);
      // Assegura que a mensagem de erro é nula
      expect(resNormal.mensagemErro, isNull);
    // Fechamento do teste
    });
  // Fechamento do grupo 1
  });

  // Grupo 2: Testes da máquina de estados da viagem
  group('2. Ciclo de Vida da Viagem e Máquina de Estados', () {
    // Caso de teste da resolução dos estados do motorista
    test(
      // Descrição do teste
      'Calcula estado correto dependendo da viagem ativa e da interface',
      // Função do teste
      () {
        // Valida o estado viagemAtiva quando o indicador temViagemAtiva é verdadeiro
        // Checa estado quando há viagem em andamento
        expect(
          ValidacaoViagem.resolverEstadoMotorista(
            // Possui viagem ativa
            temViagemAtiva: true,
            // Modal fechado
            modalFormularioAberto: false,
          ),
          equals(EstadoViagem.viagemAtiva),
        );

        // Valida o estado preenchendoFormulario quando não há viagem ativa e o modal está aberto
        // Checa estado durante abertura do formulário
        expect(
          ValidacaoViagem.resolverEstadoMotorista(
            // Não possui viagem ativa
            temViagemAtiva: false,
            // Modal aberto
            modalFormularioAberto: true,
          ),
          equals(EstadoViagem.preenchendoFormulario),
        );

        // Valida o estado semViagem quando não há viagem ativa e o modal não está aberto
        // Checa estado ocioso sem viagem e sem formulário
        expect(
          ValidacaoViagem.resolverEstadoMotorista(
            // Não possui viagem ativa
            temViagemAtiva: false,
            // Modal fechado
            modalFormularioAberto: false,
          ),
          equals(EstadoViagem.semViagem),
        );
      // Fechamento da função
      },
    // Fechamento do teste
    );
  // Fechamento do grupo 2
  });

  // Grupo 3: Testes de filtragem de veículos disponíveis
  group('3. Filtro de Veículos em Uso', () {
    // Lista de veículos de teste com situações variadas de uso
    final veiculos = [
      // Veículo v1 disponível
      const VeiculoModel(
        id: 'v1',
        placa: 'ABC-1234',
        modelo: 'Spin',
        quilometragemAtual: 50000,
        emUso: false,
      ),
      // Veículo v2 em uso
      const VeiculoModel(
        id: 'v2',
        placa: 'XYZ-5678',
        modelo: 'Master',
        quilometragemAtual: 120000,
        emUso: true,
      ),
      // Veículo v3 disponível
      const VeiculoModel(
        id: 'v3',
        placa: 'DEF-9999',
        modelo: 'Cronos',
        quilometragemAtual: 30000,
        emUso: false,
      ),
    // Fechamento da lista
    ];

    // Testa exclusão de veículos marcados diretamente com flag emUso: true
    test('Exclui veículos marcados como emUso: true', () {
      // Filtra os veículos disponíveis
      final disponiveis = ValidacaoViagem.filtrarVeiculosDisponiveis(veiculos);
      // Assegura que restaram exatamente 2 veículos
      expect(disponiveis.length, equals(2));
      // Assegura que os veículos disponíveis são ABC-1234 e DEF-9999
      expect(
        disponiveis.map((v) => v.placa),
        containsAll(['ABC-1234', 'DEF-9999']),
      );
      // Assegura que XYZ-5678 foi excluído da lista
      expect(disponiveis.map((v) => v.placa), isNot(contains('XYZ-5678')));
    // Fechamento do teste
    });

    // Testa exclusão de veículos com placas constantes em viagens ativas
    test('Exclui veículos com placas presentes em viagens ativas', () {
      // Filtra informando que a placa DEF-9999 está associada a uma viagem ativa externa
      final disponiveis = ValidacaoViagem.filtrarVeiculosDisponiveis(
        veiculos,
        placasEmUso: {'DEF-9999'},
      );
      // Assegura que apenas 1 veículo permaneceu disponível
      expect(disponiveis.length, equals(1));
      // Assegura que o único veículo restante é ABC-1234
      expect(disponiveis.first.placa, equals('ABC-1234'));
    // Fechamento do teste
    });
  // Fechamento do grupo 3
  });

  // Grupo 4: Teste de concorrência entre sessões simultâneas
  group('4. Concorrência: Duas Sessões Tentando Iniciar o Mesmo Veículo', () {
    // Instância do serviço de viagens sob teste
    late ViagemService service;

    // Configuração inicial executada antes de cada teste do grupo
    setUp(() {
      // Instancia o ViagemService
      service = ViagemService();
      // Reseta o estado em memória fornecendo um veículo inicial
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
    // Fechamento do setUp
    });

    // Valida que apenas a primeira requisição inicia a viagem e a segunda falha com conflito
    test(
      'Apenas a primeira sessão obtém sucesso; a segunda é bloqueada com erro',
      () async {
        // Modelo do veículo alvo disputado
        final veiculoAlvo = const VeiculoModel(
          id: 'v_concorrencia',
          placa: 'CON-2026',
          modelo: 'Van Municipal',
          quilometragemAtual: 90000,
          emUso: false,
        );

        // Primeira sessão envia solicitação de início de viagem
        // Dispara início da viagem pela primeira sessão
        final resSessao1 = await service.iniciarViagem(
          veiculo: veiculoAlvo,
          kmInicial: 90050,
          cidadeDestino: 'São José do Rio Preto',
          motoristaId: 'mot_carlos',
          motoristaNome: 'Carlos Silva',
        );

        // Assegura que a primeira sessão teve sucesso
        expect(resSessao1.sucesso, isTrue);
        // Assegura que a viagem foi criada
        expect(resSessao1.viagem, isNotNull);
        // Assegura a placa correta
        expect(resSessao1.viagem!.veiculoPlaca, equals('CON-2026'));

        // Segunda sessão envia solicitação para o mesmo veículo com outro condutor
        // Dispara tentativa concorrente com o mesmo veículo por outro condutor
        final resSessao2 = await service.iniciarViagem(
          veiculo: veiculoAlvo,
          kmInicial: 90060,
          cidadeDestino: 'Mirassol',
          motoristaId: 'mot_marcos',
          motoristaNome: 'Marcos Oliveira',
        );

        // Assegura que a segunda tentativa foi rejeitada
        expect(resSessao2.sucesso, isFalse);
        // Assegura mensagem explicando que o veículo já está em uso
        expect(resSessao2.mensagemErro, contains('já está em uso'));
      // Fechamento da função
      },
    // Fechamento do teste
    );
  // Fechamento do grupo 4
  });

  // Grupo 5: Testes visuais e de interação com o componente FormularioInicioViagem
  group(
    '5. Componente Visual FormularioInicioViagem (Estados da Interface)',
    () {
      // Testa o estado de carregamento exibindo spinner
      testWidgets(
        'Estado Carregando: exibe indicador de progresso e mensagem',
        (WidgetTester tester) async {
          // Renderiza o componente com a flag de carregamento forçada
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: FormularioInicioViagem(forcarCarregando: true),
              ),
            ),
          );

          // Valida a presença da mensagem informativa de busca
          expect(
            find.text('Carregando veículos disponíveis...'),
            findsOneWidget,
          );
          // Valida a presença do CircularProgressIndicator
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Fechamento do testWidgets
        },
      );

      // Testa o estado vazio quando não há veículos cadastrados ou disponíveis
      testWidgets(
        'Estado Vazio: exibe alerta quando nenhum veículo está disponível',
        (WidgetTester tester) async {
          // Renderiza o componente forçando uma lista vazia de veículos
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: FormularioInicioViagem(forcarVeiculos: [])),
            ),
          );
          // Aguarda estabilização
          await tester.pumpAndSettle();

          // Valida mensagem informativa de ausência de veículos disponíveis
          expect(
            find.text('Nenhum veículo disponível no momento.'),
            findsOneWidget,
          );
        // Fechamento do testWidgets
        },
      );

      // Testa o estado de erro apresentando mensagem de falha de conexão
      testWidgets(
        'Estado Erro: exibe mensagem quando ocorre falha ao buscar veículos',
        (WidgetTester tester) async {
          // Renderiza o formulário forçando uma mensagem de erro
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: FormularioInicioViagem(
                  forcarErro: 'Falha de conexão com a central da frota.',
                ),
              ),
            ),
          );

          // Valida que o erro forçado foi exibido na tela
          expect(
            find.text('Falha de conexão com a central da frota.'),
            findsOneWidget,
          );
        // Fechamento do testWidgets
        },
      );

      // Testa o fluxo normal de desbloqueio de campos ao selecionar um veículo
      testWidgets(
        'Estado Normal: bloqueia KM até seleção e desbloqueia após escolha',
        (WidgetTester tester) async {
          // Veículo de teste para seleção
          final veiculoTeste = const VeiculoModel(
            id: 'v10',
            placa: 'TEST-100',
            modelo: 'Spin Saúde',
            quilometragemAtual: 45000,
            emUso: false,
          );

          // Renderiza o formulário com o veículo de teste
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FormularioInicioViagem(forcarVeiculos: [veiculoTeste]),
              ),
            ),
          );

          // Verifica a presença dos textos e do botão de início
          // Valida títulos e botões na tela
          expect(find.text('Iniciar Viagem'), findsNWidgets(2));
          expect(find.byKey(const Key('botaoIniciarViagem')), findsOneWidget);
          expect(find.text('Veículo da Frota'), findsOneWidget);
          expect(find.text('Quilometragem Inicial'), findsOneWidget);

          // Verifica o texto de instrução exibido antes da escolha do veículo
          // Valida dica antes da seleção
          expect(find.text('Selecione o veículo acima'), findsOneWidget);

          // Abre o campo de seleção de veículos
          // Toca no campo dropdown
          await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
          await tester.pumpAndSettle();

          // Seleciona o item correspondente ao veículo de teste
          // Seleciona a opção do veículo TEST-100
          await tester.tap(find.textContaining('TEST-100').last);
          await tester.pumpAndSettle();

          // Verifica a inserção automática e texto de referência da última quilometragem
          // Valida preenchimento automático da quilometragem do veículo
          expect(find.text('45000'), findsOneWidget);
          expect(find.text('Última: 45000 km'), findsOneWidget);
        // Fechamento do testWidgets
        },
      );

      // Testa a reação reativa da interface caso o veículo selecionado seja ocupado externamente
      testWidgets(
        'Reação em Tempo Real: revoga seleção se veículo entrar em uso',
        (WidgetTester tester) async {
          // Controlador da stream reativa de veículos
          final streamController =
              StreamController<List<VeiculoModel>>.broadcast();

          // Veículo disponível inicial
          final veiculo1 = const VeiculoModel(
            id: 'v_reativo',
            placa: 'REA-1234',
            modelo: 'Ambulância UTI',
            quilometragemAtual: 32000,
            emUso: false,
          );

          // Monta o widget com a stream customizada conectada
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
          // Emite o veículo disponível
          streamController.add([veiculo1]);
          await tester.pumpAndSettle();

          // Abre o dropdown e seleciona o veículo
          // Seleciona o veículo no dropdown
          await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('REA-1234').last);
          await tester.pumpAndSettle();

          // Valida KM preenchido
          expect(find.text('32000'), findsOneWidget);

          // Emite uma nova lista vazia na Stream para simular alteração externa
          // Simula que outro motorista ocupou o veículo emitindo lista vazia
          streamController.add([]);
          await tester.pumpAndSettle();

          // Verifica a exibição da mensagem de veículo em uso
          // Valida que a interface alertou a indisponibilidade imediata do veículo
          expect(
            find.textContaining('acabou de entrar em uso por outro motorista'),
            findsOneWidget,
          );

          // Fecha o controller
          await streamController.close();
        // Fechamento do testWidgets
        },
      );
    // Fechamento do grupo 5
    },
  );
// Fechamento da função main
}
