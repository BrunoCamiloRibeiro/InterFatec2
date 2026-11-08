// ============================================================================
// ARQUIVO: test/components/motorista_header_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Suíte de testes de widget para o componente visual MotoristaHeader
// (lib/components/motorista_header.dart). Valida a formatação e exibição do
// título da viagem, comportamento de setas de navegação (habilitadas vs
// desabilitadas), disparo de callbacks onAnterior/onProxima, robustez contra
// quebra de layout/overflow em cenários de alta densidade de escala de texto
// (textScaleFactor 2.0 em 360dp), conformidade com diretrizes de acessibilidade
// de toque (androidTapTargetGuideline) e renderização condicional da linha de
// detalhes secundários.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Testes Automatizados de Interface / Widgets (test/components/).
//
// ONDE É USADO:
// Executado pelo executor oficial de testes do Flutter (`flutter test`).
//
// DE ONDE RECEBE DADOS:
// - Dados e mocks declarados diretamente nos casos de teste (strings, callbacks).
// - Componente testado: lib/components/motorista_header.dart.
//
// O QUE EXPORTA / EXPÕE:
// - void main(): Ponto de entrada da suíte de testes.
//
// ORIGEM HISTÓRICA:
// Criado pela equipe no commit 23644b1 (Issue #13 / componente visual do header
// de viagens com seletor de setas).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart
// - package:flutter_test/flutter_test.dart
// - Sem efeitos colaterais externos (execução hermética no ambiente de testes).
// ============================================================================
// Importa os componentes e widgets da biblioteca Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o framework oficial de testes de widgets do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o componente visual MotoristaHeader sob teste
import 'package:trans_saude/components/motorista_header.dart';

// Função principal de entrada da suíte de testes de widgets do MotoristaHeader
void main() {
  // Agrupa todos os testes de unidade e widget relacionados ao MotoristaHeader
  group('MotoristaHeader - Testes de Widget', () {
    // Caso de teste 1: checa a renderização do título da viagem e a presença dos ícones de navegação
    testWidgets('1. Renderiza o título da viagem formatado', (tester) async {
      // Monta o widget MotoristaHeader envolto em MaterialApp e Scaffold
      await tester.pumpWidget(
        // Cria a árvore de aplicação básica para os testes
        const MaterialApp(
          // Define a tela inicial com o componente MotoristaHeader
          home: Scaffold(body: MotoristaHeader(tituloViagem: 'Viagem #42')),
        // Fechamento do MaterialApp
        ),
      // Fechamento do pumpWidget
      );

      // Valida que o texto exato com o título da viagem foi renderizado uma vez
      expect(find.text('Viagem #42'), findsOneWidget);
      // Valida que o ícone de seta para voltar foi renderizado
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      // Valida que o ícone de seta para avançar foi renderizado
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    // Fechamento do testWidgets 1
    });

    // Caso de teste 2: valida o estilo desabilitado das setas quando os callbacks são nulos
    testWidgets(
      // Descrição do caso de teste
      '2. Setas ficam visualmente desabilitadas quando o callback é nulo',
      // Função assíncrona de teste recebendo o tester
      (tester) async {
        // Constrói o widget com callbacks explicitamente nulos
        await tester.pumpWidget(
          // Cria a aplicação de teste
          const MaterialApp(
            // Define o Scaffold com o widget desabilitado
            home: Scaffold(
              // Corpo contendo o MotoristaHeader sem callbacks
              body: MotoristaHeader(
                // Título da viagem
                tituloViagem: 'Viagem #1',
                // Callback anterior nulo
                onAnterior: null,
                // Callback próximo nulo
                onProxima: null,
              // Fechamento do MotoristaHeader
              ),
            // Fechamento do Scaffold
            ),
          // Fechamento do MaterialApp
          ),
        // Fechamento do pumpWidget
        );

        // Obtém a instância do IconButton da seta anterior
        final iconButtonAnterior = tester.widget<IconButton>(
          // Localiza o botão contendo o ícone de retorno
          find.widgetWithIcon(IconButton, Icons.arrow_back_ios_new),
        // Fechamento da busca
        );
        // Obtém a instância do IconButton da seta próxima
        final iconButtonProxima = tester.widget<IconButton>(
          // Localiza o botão contendo o ícone de avanço
          find.widgetWithIcon(IconButton, Icons.arrow_forward_ios),
        // Fechamento da busca
        );

        // Garante que o callback onPressed do botão anterior é nulo
        expect(iconButtonAnterior.onPressed, isNull);
        // Garante que o callback onPressed do botão próximo é nulo
        expect(iconButtonProxima.onPressed, isNull);

        // Obtém a instância do widget Icon da seta anterior
        final iconAnterior = tester.widget<Icon>(
          // Localiza pelo ícone de retorno
          find.byIcon(Icons.arrow_back_ios_new),
        // Fechamento da busca
        );
        // Obtém a instância do widget Icon da seta próxima
        final iconProxima = tester.widget<Icon>(
          // Localiza pelo ícone de avanço
          find.byIcon(Icons.arrow_forward_ios),
        // Fechamento da busca
        );

        // Assegura que o ícone anterior está estilizado em cinza claro desabilitado
        expect(iconAnterior.color, Colors.grey[400]);
        // Assegura que o ícone próximo está estilizado em cinza claro desabilitado
        expect(iconProxima.color, Colors.grey[400]);
      // Fechamento do testWidgets 2
      },
    // Fechamento da chamada de teste 2
    );

    // Caso de teste 3: checa o acionamento dos callbacks ao tocar nos botões de navegação
    testWidgets('3. Callbacks onAnterior e onProxima são chamados ao tocar', (
      // Parâmetro do testador
      tester,
    // Função assíncrona
    ) async {
      // Contador para chamadas de retrocesso
      int anteriorContador = 0;
      // Contador para chamadas de avanço
      int proximaContador = 0;

      // Monta o widget configurando callbacks de incremento
      await tester.pumpWidget(
        // Aplicação de teste
        MaterialApp(
          // Tela com Scaffold
          home: Scaffold(
            // Header com callbacks ativos
            body: MotoristaHeader(
              // Título
              tituloViagem: 'Viagem #2',
              // Incrementa o contador anterior
              onAnterior: () => anteriorContador++,
              // Incrementa o contador próximo
              onProxima: () => proximaContador++,
            // Fechamento do MotoristaHeader
            ),
          // Fechamento do Scaffold
          ),
        // Fechamento do MaterialApp
        ),
      // Fechamento do pumpWidget
      );

      // Toca no botão identificado pelo tooltip 'Viagem anterior'
      await tester.tap(find.byTooltip('Viagem anterior'));
      // Executa um pump para processar o clique
      await tester.pump();
      // Valida que o callback anterior foi executado uma vez
      expect(anteriorContador, 1);
      // Valida que o callback próximo não foi executado
      expect(proximaContador, 0);

      // Toca no botão identificado pelo tooltip 'Próxima viagem'
      await tester.tap(find.byTooltip('Próxima viagem'));
      // Executa um pump para processar o clique
      await tester.pump();
      // Valida que o callback anterior manteve a contagem
      expect(anteriorContador, 1);
      // Valida que o callback próximo foi acionado
      expect(proximaContador, 1);
    // Fechamento do testWidgets 3
    });

    // Caso de teste 4: checa ausência de quebra de layout com escala de texto aumentada
    testWidgets('4. Sem overflow com textScaleFactor 2.0 e largura de 360dp', (
      // Parâmetro tester
      tester,
    // Função assíncrona
    ) async {
      // Simula uma tela compacta de 360x640 pixels físicos
      tester.view.physicalSize = const Size(360, 640);
      // Define a proporção de pixels para 1.0
      tester.view.devicePixelRatio = 1.0;
      // Registra limpeza do ambiente para restaurar configurações originais de tela
      addTearDown(() {
        // Restaura o tamanho físico padrão do tester
        tester.view.resetPhysicalSize();
        // Restaura a proporção de pixels padrão
        tester.view.resetDevicePixelRatio();
      // Fechamento do addTearDown
      });

      // Renderiza o componente com escala de fonte duplicada (acessibilidade)
      await tester.pumpWidget(
        // Configura o MediaQuery com textScaler de 2.0
        MediaQuery(
          // Dados customizados de tela
          data: const MediaQueryData(
            // Tamanho de tela de 360x640
            size: Size(360, 640),
            // Escala linear dobrada para teste de robustez de tipografia
            textScaler: TextScaler.linear(2.0),
          // Fechamento do MediaQueryData
          ),
          // Aplicação de teste
          child: const MaterialApp(
            // Scaffold com preenchimento lateral
            home: Scaffold(
              // Preenchimento de 16 pixels
              body: Padding(
                // Margem interna de 16 pixels
                padding: EdgeInsets.all(16),
                // Header com dados extensos para forçar quebra de linha/ellipsis
                child: MotoristaHeader(
                  // Título muito longo
                  tituloViagem:
                      'Viagem 999 - Titulo Muito Longo Para Testar Ellipsis Sem Overflow',
                  // Nome do motorista
                  motoristaNome: 'Carlos Roberto Pereira',
                  // Destino
                  destino: 'Hospital de Base Rio Preto',
                  // Modelo do veículo
                  veiculo: 'Van Sprinter Mercedes ABC-1234',
                  // Horário de saída
                  saida: '06:30',
                // Fechamento do MotoristaHeader
                ),
              // Fechamento do Padding
              ),
            // Fechamento do Scaffold
            ),
          // Fechamento do MaterialApp
          ),
        // Fechamento do MediaQuery
        ),
      // Fechamento do pumpWidget
      );

      // Aguarda estabilização completa das animações e layouts
      await tester.pumpAndSettle();

      // Assegura que nenhuma exceção de RenderFlex overflow foi lançada
      expect(tester.takeException(), isNull);
      // Valida que o widget foi renderizado com sucesso
      expect(find.byType(MotoristaHeader), findsOneWidget);
    // Fechamento do testWidgets 4
    });

    // Caso de teste 5: valida a conformidade com as diretrizes de acessibilidade do Android
    testWidgets(
      // Descrição do teste
      '5. Atende a diretriz de acessibilidade androidTapTargetGuideline',
      // Função assíncrona
      (tester) async {
        // Habilita a árvore de semântica para verificação de acessibilidade
        final SemanticsHandle handle = tester.ensureSemantics();

        // Renderiza o componente com callbacks ativos
        await tester.pumpWidget(
          // Aplicação de teste
          MaterialApp(
            // Scaffold com o componente centralizado
            home: Scaffold(
              // Centralização
              body: Center(
                // Componente MotoristaHeader
                child: MotoristaHeader(
                  // Título
                  tituloViagem: 'Viagem #1',
                  // Callback anterior
                  onAnterior: () {},
                  // Callback próximo
                  onProxima: () {},
                // Fechamento do MotoristaHeader
                ),
              // Fechamento do Center
              ),
            // Fechamento do Scaffold
            ),
          // Fechamento do MaterialApp
          ),
        // Fechamento do pumpWidget
        );

        // Valida que todos os alvos de toque atendem a diretriz mínima de 48x48dp do Android
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        // Libera o manipulador de semântica
        handle.dispose();
      // Fechamento do testWidgets 5
      },
    // Fechamento do teste 5
    );

    // Caso de teste 6: valida que a linha secundária não é renderizada quando omitida
    testWidgets(
      // Descrição do teste
      '6. Não renderiza linha secundária quando campos opcionais não são passados',
      // Função assíncrona
      (tester) async {
        // Constrói o widget fornecendo apenas o título obrigatório
        await tester.pumpWidget(
          // Aplicação de teste
          const MaterialApp(
            // Scaffold simples
            home: Scaffold(body: MotoristaHeader(tituloViagem: 'Viagem #1')),
          // Fechamento do MaterialApp
          ),
        // Fechamento do pumpWidget
        );

        // Valida que o divisor horizontal de separação não existe na árvore
        expect(find.byType(Divider), findsNothing);
        // Valida que o ícone de motorista não existe
        expect(find.byIcon(Icons.person_outline), findsNothing);
        // Valida que o ícone de localização não existe
        expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      // Fechamento do testWidgets 6
      },
    // Fechamento do teste 6
    );

    // Caso de teste 7: valida a renderização correta da linha secundária quando informada
    testWidgets(
      // Descrição do teste
      '7. Renderiza linha secundária quando campos opcionais são passados',
      // Função assíncrona
      (tester) async {
        // Constrói o widget com todos os detalhes complementares preenchidos
        await tester.pumpWidget(
          // Aplicação de teste
          const MaterialApp(
            // Scaffold com o header completo
            home: Scaffold(
              // Header com informações de motorista, destino, veículo e saída
              body: MotoristaHeader(
                // Título
                tituloViagem: 'Viagem #1',
                // Nome do condutor
                motoristaNome: 'João Silva',
                // Destino
                destino: 'Barretos',
                // Veículo
                veiculo: 'Spin XYZ-9876',
                // Horário previsto de partida
                saida: '07:00',
              // Fechamento do MotoristaHeader
              ),
            // Fechamento do Scaffold
            ),
          // Fechamento do MaterialApp
          ),
        // Fechamento do pumpWidget
        );

        // Valida a presença do divisor que separa o título dos detalhes
        expect(find.byType(Divider), findsOneWidget);
        // Valida a exibição do nome do motorista
        expect(find.text('João Silva'), findsOneWidget);
        // Valida a exibição do destino
        expect(find.text('Barretos'), findsOneWidget);
        // Valida a exibição do modelo e placa do veículo
        expect(find.text('Spin XYZ-9876'), findsOneWidget);
        // Valida a exibição do horário de saída
        expect(find.text('07:00'), findsOneWidget);
      // Fechamento do testWidgets 7
      },
    // Fechamento do teste 7
    );
  // Fechamento do grupo de testes
  });
// Fechamento da função main
}
