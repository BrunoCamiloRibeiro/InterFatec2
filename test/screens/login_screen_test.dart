import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/screens/login_screen.dart';
import 'package:trans_saude/services/auth_service.dart';

class FakeAuthService implements AuthService {
  int loginCalls = 0;
  String? lastCpf;
  String? lastPassword;
  UserRole? roleToReturn;
  Exception? exceptionToThrow;
  Completer<UserRole>? completer;

  FakeAuthService({this.roleToReturn, this.exceptionToThrow, this.completer});

  @override
  Future<UserRole> login(String cpf, String senha) async {
    loginCalls++;
    lastCpf = cpf;
    lastPassword = senha;

    if (completer != null) {
      return completer!.future;
    }

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return roleToReturn ?? UserRole.motorista;
  }

  @override
  Future<void> logout() async {}
}

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

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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
