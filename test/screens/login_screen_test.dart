// ============================================================================
// ARQUIVO: test/screens/login_screen_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Suíte de testes de widgets e comportamento para a tela de login oficial
// (lib/screens/login_screen.dart). Valida:
// 1. Renderização de todos os elementos essenciais (campos, ícones, textos e botões).
// 2. Aplicação automática de máscara de CPF (XXX.XXX.XXX-XX) durante digitação.
// 3. Alternância do botão de visibilidade da senha (mostrar/ocultar).
// 4. Validação de campos vazios impedindo submissão ao AuthService.
// 5. Validação de CPF incompleto (menos de 11 dígitos).
// 6. Estado de carregamento com bloqueio contra duplo clique e spinner giratório.
// 7. Apresentação de erros do serviço via banner visual e SnackBar.
// 8. Navegação bem-sucedida para rota de motorista (/motorista).
// 9. Navegação bem-sucedida para rota de administrador (/administrativo).
// 10. Robustez contra overflow em fontes ampliadas (textScaleFactor 2.0).
// 11. Conformidade estrita com diretrizes de acessibilidade de alvos de toque.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Testes Automatizados de Interface / Widgets (test/screens/).
//
// ONDE É USADO:
// Executado pelo executor oficial de testes do Flutter (`flutter test`).
//
// DE ONDE RECEBE DADOS:
// - Implementação FakeAuthService simulando o AuthService.
//
// O QUE EXPORTA / EXPÕE:
// - class FakeAuthService implements AuthService: Mock de autenticação.
// - Widget buildTestableWidget(...): Montador do widget para testes.
// - void main(): Ponto de entrada da suíte de testes.
//
// ORIGEM HISTÓRICA:
// Criado no commit 600ea8b (feat: implementar tela de login, rotas protegidas
// e gate de autenticação).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart
// - package:flutter_test/flutter_test.dart
// - dart:async (Completer)
// - Sem efeitos colaterais externos.
// ============================================================================
// Importa utilitários assíncronos do Dart como Completer
import 'dart:async';

// Importa os componentes de interface da biblioteca Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o framework oficial de testes de widgets do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o enum de papéis funcionais de usuários
import 'package:trans_saude/models/user_role.dart';
// Importa a tela LoginScreen sob teste
import 'package:trans_saude/screens/login_screen.dart';
// Importa a interface do serviço de autenticação e sua classe de exceção
import 'package:trans_saude/services/auth_service.dart';

// Classe mock que implementa AuthService para testar a tela de login isoladamente
class FakeAuthService implements AuthService {
  // Contador de chamadas ao método login
  int loginCalls = 0;
  // Armazena o último CPF informado para asserções
  String? lastCpf;
  // Armazena a última senha informada para asserções
  String? lastPassword;
  // Papel que deve ser retornado pelo login
  UserRole? roleToReturn;
  // Exceção a ser lançada para testar fluxos de erro
  Exception? exceptionToThrow;
  // Completer para pausar a execução assíncrona e testar estados de carregamento
  Completer<UserRole>? completer;

  // Construtor do mock com parâmetros opcionais
  FakeAuthService({this.roleToReturn, this.exceptionToThrow, this.completer});

  // Sobrescrita do método login
  @override
  Future<UserRole> login(String cpf, String senha) async {
    // Registra chamada
    loginCalls++;
    // Guarda CPF
    lastCpf = cpf;
    // Guarda senha
    lastPassword = senha;

    // Se houver completer pendente, retorna seu futuro
    if (completer != null) {
      return completer!.future;
    }

    // Se houver exceção configurada, lança-a
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    // Retorna o papel configurado ou padrão motorista
    return roleToReturn ?? UserRole.motorista;
  }

  // Sobrescrita do logout
  @override
  Future<void> logout() async {}

  // Sobrescrita do getter authStateChanges retornando stream vazia
  @override
  Stream<String?> get authStateChanges => const Stream.empty();

  // Sobrescrita do resolveUserRole
  @override
  Future<UserRole> resolveUserRole(
    String uid, {
    bool forceRefresh = false,
  }) async => roleToReturn ?? UserRole.motorista;

  // Sobrescrita do getCachedRole
  @override
  UserRole? getCachedRole(String uid) => roleToReturn;

  // Sobrescrita do clearRoleCache
  @override
  void clearRoleCache() {}

  // Sobrescrita do currentUserId
  @override
  String? get currentUserId => null;
}

// Função auxiliar para construir o widget sob teste com rotas nomeadas mockadas
Widget buildTestableWidget({
  required AuthService authService,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    routes: {
      '/motorista': (context) =>
          const Scaffold(body: Center(child: Text('Rota Motorista'))),
      '/administrativo': (context) =>
          const Scaffold(body: Center(child: Text('Rota Administrativo'))),
    },
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: LoginScreen(authService: authService),
    ),
  );
}

// Ponto de entrada da suíte de testes da LoginScreen
void main() {
  // Inicializa bindings do Flutter
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // Configura viewport padrão de 360x640 para os testes de layout
  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Teste 1: Renderização de componentes
  testWidgets(
    '1. Renderiza campos de CPF, senha, ícone, textos e botão entrar',
    (WidgetTester tester) async {
      configureViewport(tester);
      final authService = FakeAuthService();

      await tester.pumpWidget(buildTestableWidget(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('Acesse sua Conta'), findsOneWidget);
      expect(find.text('Digite seus dados para entrar'), findsOneWidget);
      expect(find.byKey(const Key('campoCpf')), findsOneWidget);
      expect(find.byKey(const Key('campoSenha')), findsOneWidget);
      expect(find.byKey(const Key('botaoAlternarSenha')), findsOneWidget);
      expect(find.byKey(const Key('botaoEntrar')), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    },
  );

  // Teste 2: Máscara automática de CPF
  testWidgets('2. Aplica máscara de CPF automaticamente ao digitar', (
    WidgetTester tester,
  ) async {
    configureViewport(tester);
    final authService = FakeAuthService();

    await tester.pumpWidget(buildTestableWidget(authService: authService));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('campoCpf')), '12345678901');
    await tester.pumpAndSettle();

    final campoCpf = tester.widget<TextFormField>(
      find.byKey(const Key('campoCpf')),
    );
    expect(campoCpf.controller?.text, '123.456.789-01');
  });

  // Teste 3: Alternância de visibilidade da senha
  testWidgets('3. Alterna visibilidade da senha ao clicar no botão do olho', (
    WidgetTester tester,
  ) async {
    configureViewport(tester);
    final authService = FakeAuthService();

    await tester.pumpWidget(buildTestableWidget(authService: authService));
    await tester.pumpAndSettle();

    final campoSenhaAntes = tester.widget<EditableText>(
      find.byType(EditableText).last,
    );
    expect(campoSenhaAntes.obscureText, isTrue);

    await tester.tap(find.byKey(const Key('botaoAlternarSenha')));
    await tester.pumpAndSettle();

    final campoSenhaDepois = tester.widget<EditableText>(
      find.byType(EditableText).last,
    );
    expect(campoSenhaDepois.obscureText, isFalse);

    await tester.tap(find.byKey(const Key('botaoAlternarSenha')));
    await tester.pumpAndSettle();

    final campoSenhaFinal = tester.widget<EditableText>(
      find.byType(EditableText).last,
    );
    expect(campoSenhaFinal.obscureText, isTrue);
  });

  // Teste 4: Campos vazios
  testWidgets(
    '4. Campos vazios mostram mensagens de erro e NÃO chamam o AuthService',
    (WidgetTester tester) async {
      configureViewport(tester);
      final authService = FakeAuthService();

      await tester.pumpWidget(buildTestableWidget(authService: authService));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('botaoEntrar')));
      await tester.pumpAndSettle();

      expect(find.text('Informe o CPF.'), findsOneWidget);
      expect(find.text('Informe a senha.'), findsOneWidget);
      expect(authService.loginCalls, equals(0));
    },
  );

  // Teste 5: CPF incompleto
  testWidgets(
    '5. CPF incompleto com menos de 11 dígitos exibe erro de validação',
    (WidgetTester tester) async {
      configureViewport(tester);
      final authService = FakeAuthService();

      await tester.pumpWidget(buildTestableWidget(authService: authService));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campoCpf')), '123456');
      await tester.enterText(find.byKey(const Key('campoSenha')), '123456');

      await tester.tap(find.byKey(const Key('botaoEntrar')));
      await tester.pumpAndSettle();

      expect(
        find.text('Informe um CPF válido com 11 dígitos.'),
        findsOneWidget,
      );
      expect(authService.loginCalls, equals(0));
    },
  );

  // Teste 6: Estado de carregamento
  testWidgets(
    '6. Loading desabilita botão, exibe CircularProgressIndicator e impede duplo envio',
    (WidgetTester tester) async {
      configureViewport(tester);
      final completer = Completer<UserRole>();
      final authService = FakeAuthService(completer: completer);

      await tester.pumpWidget(buildTestableWidget(authService: authService));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campoCpf')), '12345678901');
      await tester.enterText(
        find.byKey(const Key('campoSenha')),
        'senhaSegura123',
      );

      await tester.tap(find.byKey(const Key('botaoEntrar')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);

      await tester.tap(find.byKey(const Key('botaoEntrar')));
      await tester.pump();

      expect(authService.loginCalls, equals(1));

      completer.complete(UserRole.motorista);
      await tester.pumpAndSettle();

      expect(find.text('Rota Motorista'), findsOneWidget);
      expect(authService.loginCalls, equals(1));
    },
  );

  // Teste 7: Exibição de erro
  testWidgets(
    '7. Erro de autenticação do serviço é exibido na tela no banner e SnackBar',
    (WidgetTester tester) async {
      configureViewport(tester);
      final authService = FakeAuthService(
        exceptionToThrow: const AuthException('CPF ou senha incorretos.'),
      );

      await tester.pumpWidget(buildTestableWidget(authService: authService));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campoCpf')), '12345678901');
      await tester.enterText(
        find.byKey(const Key('campoSenha')),
        'senhaIncorreta',
      );

      await tester.tap(find.byKey(const Key('botaoEntrar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mensagemErro')), findsOneWidget);
      expect(find.text('CPF ou senha incorretos.'), findsAtLeastNWidgets(1));
    },
  );

  // Teste 8: Login motorista
  testWidgets(
    '8. Autenticação bem-sucedida de motorista com CPF navega para /motorista',
    (WidgetTester tester) async {
      configureViewport(tester);
      final authService = FakeAuthService(roleToReturn: UserRole.motorista);

      await tester.pumpWidget(buildTestableWidget(authService: authService));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campoCpf')), '12345678901');
      await tester.enterText(find.byKey(const Key('campoSenha')), 'senha123');

      await tester.tap(find.byKey(const Key('botaoEntrar')));
      await tester.pumpAndSettle();

      expect(find.text('Rota Motorista'), findsOneWidget);
    },
  );

  // Teste 9: Login admin
  testWidgets(
    '9. Autenticação bem-sucedida de admin com CPF navega para /administrativo',
    (WidgetTester tester) async {
      configureViewport(tester);
      final authService = FakeAuthService(roleToReturn: UserRole.admin);

      await tester.pumpWidget(buildTestableWidget(authService: authService));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campoCpf')), '98765432100');
      await tester.enterText(
        find.byKey(const Key('campoSenha')),
        'senhaAdmin123',
      );

      await tester.tap(find.byKey(const Key('botaoEntrar')));
      await tester.pumpAndSettle();

      expect(find.text('Rota Administrativo'), findsOneWidget);
    },
  );

  // Teste 10: Sem overflow
  testWidgets(
    '10. Não ocorre RenderFlex overflow com textScaleFactor 2.0 em 360x640',
    (WidgetTester tester) async {
      configureViewport(tester);
      final authService = FakeAuthService();

      await tester.pumpWidget(
        buildTestableWidget(authService: authService, textScaleFactor: 2.0),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  // Teste 11: Acessibilidade
  testWidgets(
    '11. Acessibilidade: atende diretrizes de alvo de toque e rótulo semântico',
    (WidgetTester tester) async {
      configureViewport(tester);
      final authService = FakeAuthService();
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildTestableWidget(authService: authService));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    },
  );
}
