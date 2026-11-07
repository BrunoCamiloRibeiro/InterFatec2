// ============================================================================
// TESTE DE INTERFACE WEB EM TAMANHO DE CELULAR (VIEWPORT MOBILE 360DP)
// ----------------------------------------------------------------------------
// Repositório: BrunoCamiloRibeiro/InterFatec2
// Contexto: Issue #65 - Verificação de responsividade Web em dimensões de celular
//           sem estouros de layout (RenderFlex overflow) e com suporte ao teclado.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/screens/login_screen.dart';
import 'package:trans_saude/services/auth_service.dart';

class FakeMobileWebAuthService implements AuthService {
  int loginPacienteCalls = 0;
  String? ultimoDocumento;
  String? ultimoCodigo;
  UserRole roleToReturn = UserRole.paciente;

  @override
  Future<UserRole> login(String cpf, String senha) async => UserRole.motorista;

  @override
  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) async {
    loginPacienteCalls++;
    ultimoDocumento = documento;
    ultimoCodigo = codigoAcesso;
    return roleToReturn;
  }

  @override
  Future<void> logout() async {}

  @override
  Stream<String?> get authStateChanges => const Stream.empty();

  @override
  Future<UserRole> resolveUserRole(String uid, {bool forceRefresh = false}) async =>
      roleToReturn;

  @override
  UserRole? getCachedRole(String uid) => roleToReturn;

  @override
  void clearRoleCache() {}

  @override
  String? get currentUserId => 'mock_user_mobile_web';
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildApp(FakeMobileWebAuthService authService) {
    return MaterialApp(
      routes: {
        '/login': (_) => LoginScreen(authService: authService),
        '/motorista': (_) => const Scaffold(body: Text('Tela Motorista')),
        '/admin': (_) => const Scaffold(body: Text('Tela Admin')),
        '/paciente': (_) => const Scaffold(body: Text('Tela Paciente')),
      },
      home: LoginScreen(authService: authService),
    );
  }

  group('LoginScreen - Responsividade Web no Tamanho de Celular (360x640)', () {
    testWidgets('1. Renderiza formulário de Motorista e alterna para Paciente sem overflow em 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeMobileWebAuthService();
      await tester.pumpWidget(buildApp(fakeAuth));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Nenhum erro de overflow deve ocorrer na tela de motorista');
      expect(find.text('Acesse sua Conta'), findsOneWidget);
      expect(find.byKey(const Key('botaoModoPaciente')), findsOneWidget);

      // Alterna para acesso do Paciente
      await tester.tap(find.byKey(const Key('botaoModoPaciente')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Nenhum erro de overflow deve ocorrer na tela do paciente');
      expect(find.text('Acesso do Paciente'), findsOneWidget);
      expect(find.byKey(const Key('campoDocumentoPaciente')), findsOneWidget);
      expect(find.byKey(const Key('campoCodigoAcesso')), findsOneWidget);
      expect(find.byKey(const Key('botaoAcessarViagem')), findsOneWidget);
      expect(find.byKey(const Key('botaoVoltarMotorista')), findsOneWidget);
    });

    testWidgets('2. Executa fluxo de login do paciente em tela mobile web e redireciona para /paciente', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeMobileWebAuthService();
      await tester.pumpWidget(buildApp(fakeAuth));
      await tester.pumpAndSettle();

      // Muda para acesso do Paciente
      await tester.tap(find.byKey(const Key('botaoModoPaciente')));
      await tester.pumpAndSettle();

      // Preenche os dados
      await tester.enterText(find.byKey(const Key('campoDocumentoPaciente')), '529.982.247-25');
      await tester.enterText(find.byKey(const Key('campoCodigoAcesso')), '4821');
      await tester.pumpAndSettle();

      // Clica em acessar viagem
      await tester.tap(find.byKey(const Key('botaoAcessarViagem')));
      await tester.pumpAndSettle();

      expect(fakeAuth.loginPacienteCalls, equals(1));
      expect(fakeAuth.ultimoDocumento, equals('529.982.247-25'));
      expect(fakeAuth.ultimoCodigo, equals('4821'));

      // Redirecionamento verificado
      expect(find.text('Tela Paciente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Simula teclado aberto reduzindo altura para 360x380: sem estouro visual', (tester) async {
      // Simula viewport com teclado virtual aberto no navegador mobile
      tester.view.physicalSize = const Size(360, 380);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeMobileWebAuthService();
      await tester.pumpWidget(buildApp(fakeAuth));
      await tester.pumpAndSettle();

      // Alterna para paciente rolando até o botão se necessário
      await tester.ensureVisible(find.byKey(const Key('botaoModoPaciente')));
      await tester.tap(find.byKey(const Key('botaoModoPaciente')));
      await tester.pumpAndSettle();

      // Verifica que o scroll acomoda o conteúdo confortavelmente
      expect(tester.takeException(), isNull, reason: 'SingleChildScrollView previne overflow com teclado ativo');

      // Rola o scroll para garantir interatividade de ponta a ponta
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
