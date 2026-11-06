import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/paciente.dart';
import 'package:trans_saude/routes/route_guard.dart';
import 'package:trans_saude/screens/admin_placeholder_screen.dart';
import 'package:trans_saude/screens/auth_gate.dart';
import 'package:trans_saude/screens/login_screen.dart';
import 'package:trans_saude/services/auth_service.dart';

class FakeGateAuthService implements AuthService {
  final StreamController<String?> _authStreamController =
      StreamController<String?>.broadcast();
  int logoutCalls = 0;
  int clearCacheCalls = 0;
  String? currentUserIdOverride;
  UserRole? cachedRoleOverride;

  @override
  Stream<String?> get authStateChanges => _authStreamController.stream;

  void emitAuthState(String? uid) {
    currentUserIdOverride = uid;
    _authStreamController.add(uid);
  }

  @override
  String? get currentUserId => currentUserIdOverride;

  @override
  UserRole? getCachedRole(String uid) => cachedRoleOverride;

  @override
  void clearRoleCache() {
    clearCacheCalls++;
    cachedRoleOverride = null;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    currentUserIdOverride = null;
    cachedRoleOverride = null;
  }

  @override
  Future<UserRole> login(String cpf, String senha) async {
    return cachedRoleOverride ?? UserRole.motorista;
  }

  @override
  Future<UserRole> resolveUserRole(
    String uid, {
    bool forceRefresh = false,
  }) async {
    return cachedRoleOverride ?? UserRole.motorista;
  }

  void dispose() {
    _authStreamController.close();
  }
}

Widget buildGateTestApp({required AuthGate authGate}) {
  return MaterialApp(home: authGate);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AuthGate - Máquina de Estados e Roteamento Reativo', () {
    testWidgets(
      '1. Estado Deslogado: quando authStateChanges emite null, renderiza a tela de login',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        // Emite deslogado
        fakeAuth.emitAuthState(null);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Acesse sua Conta'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Estado Autenticado (motorista): renderiza diretamente a tela do motorista',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) async => UserRole.motorista,
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        fakeAuth.emitAuthState('uid_motorista_1');
        await tester.pumpAndSettle();

        expect(find.byType(Motorista), findsOneWidget);
        expect(find.text('Lista de Passageiros'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Estado Autenticado (admin): renderiza o placeholder administrativo com logout',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) async => UserRole.admin,
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        fakeAuth.emitAuthState('uid_admin_1');
        await tester.pumpAndSettle();

        expect(find.byType(AdminPlaceholderScreen), findsOneWidget);
        expect(
          find.text('Módulo Administrativo em Construção'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('botaoLogoutAdmin')), findsOneWidget);
      },
    );

    testWidgets(
      '4. Estado Autenticado (paciente): renderiza diretamente o painel do paciente',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) async => UserRole.paciente,
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        fakeAuth.emitAuthState('uid_paciente_1');
        await tester.pumpAndSettle();

        expect(find.byType(Paciente), findsOneWidget);
        expect(find.text('Painel do Paciente'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Estado Carregando: exibe splash com identidade visual e nunca exibe tela incorreta de relance',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);
        final completer = Completer<UserRole>();

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) => completer.future,
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        // Enquanto o resolver está pendente
        fakeAuth.emitAuthState('uid_em_processamento');
        await tester.pump();

        expect(find.byKey(const Key('splashCarregando')), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('TransSaúde'), findsOneWidget);

        // Nenhuma tela de perfil deve estar visível
        expect(find.byType(Motorista), findsNothing);
        expect(find.byType(AdminPlaceholderScreen), findsNothing);
        expect(find.byType(Paciente), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);

        // Conclui a resolução para motorista
        completer.complete(UserRole.motorista);
        await tester.pumpAndSettle();

        expect(find.byType(Motorista), findsOneWidget);
      },
    );

    testWidgets(
      '6. Transição Reativa: autenticado -> logout -> login com limpeza de cache',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) async => UserRole.motorista,
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        // Usuário loga
        fakeAuth.emitAuthState('uid_motorista_sessao');
        await tester.pumpAndSettle();
        expect(find.byType(Motorista), findsOneWidget);

        // Usuário desloga
        fakeAuth.emitAuthState(null);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(fakeAuth.clearCacheCalls, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      '7. Perfil Inválido: dispara signOut, exibe erro e permite voltar ao login',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) async => throw const AuthException(
                'Perfil de usuário inválido ou não cadastrado no sistema.',
                code: 'invalid-profile',
              ),
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        fakeAuth.emitAuthState('uid_corrompido');
        await tester.pumpAndSettle();

        expect(fakeAuth.logoutCalls, equals(1));
        expect(find.byKey(const Key('telaPerfilInvalido')), findsOneWidget);
        expect(find.text('Perfil Inválido'), findsOneWidget);

        // Clica em 'Voltar ao Login'
        await tester.tap(find.byKey(const Key('botaoVoltarLogin')));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets(
      '8. Erro Temporário (rede/unavailable): NÃO desloga, exibe aviso e botão Tentar novamente',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        bool deveFalhar = true;
        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) async {
                if (deveFalhar) {
                  throw const AuthException(
                    'Falha temporária de conexão com o servidor.',
                    code: 'unavailable',
                  );
                }
                return UserRole.motorista;
              },
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        fakeAuth.emitAuthState('uid_offline');
        await tester.pumpAndSettle();

        // Não deve ter deslogado!
        expect(fakeAuth.logoutCalls, equals(0));
        expect(find.byKey(const Key('telaErroTemporario')), findsOneWidget);
        expect(find.text('Erro de Conexão'), findsOneWidget);

        // Recupera a conexão e tenta novamente
        deveFalhar = false;
        await tester.tap(find.byKey(const Key('botaoTentarNovamente')));
        await tester.pumpAndSettle();

        // Consegue autenticar e abre a tela do motorista
        expect(find.byType(Motorista), findsOneWidget);
        expect(fakeAuth.logoutCalls, equals(0));
      },
    );

    testWidgets(
      '9. Violação de Regras (permission-denied): desloga e exibe erro explícito',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) async => throw const AuthException(
                'Acesso não autorizado pelo Firestore (permissão negada).',
                code: 'permission-denied',
              ),
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        fakeAuth.emitAuthState('uid_sem_permissao');
        await tester.pumpAndSettle();

        expect(fakeAuth.logoutCalls, equals(1));
        expect(find.byKey(const Key('telaPermissaoNegada')), findsOneWidget);
        expect(find.text('Acesso Negado'), findsOneWidget);
      },
    );
  });

  group('RouteGuard - Proteção de Rotas e Bloqueio de Acesso Cruzado', () {
    testWidgets(
      '10. Acesso Cruzado: motorista tentando acessar /administrativo é bloqueado e vai para /motorista',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);
        fakeAuth.currentUserIdOverride = 'mot_123';
        fakeAuth.cachedRoleOverride = UserRole.motorista;

        final route = RouteGuard.onGenerateRoute(
          const RouteSettings(name: '/administrativo'),
          authService: fakeAuth,
        );

        await tester.pumpWidget(
          MaterialApp(home: Navigator(onGenerateRoute: (settings) => route)),
        );
        await tester.pumpAndSettle();

        // Motorista é redirecionado para a tela legítima do motorista
        expect(find.byType(Motorista), findsOneWidget);
        expect(find.byType(AdminPlaceholderScreen), findsNothing);
      },
    );

    testWidgets(
      '11. Acesso Autorizado: admin acessando /administrativo abre AdminPlaceholderScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);
        fakeAuth.currentUserIdOverride = 'adm_123';
        fakeAuth.cachedRoleOverride = UserRole.admin;

        final route = RouteGuard.onGenerateRoute(
          const RouteSettings(name: '/administrativo'),
          authService: fakeAuth,
        );

        await tester.pumpWidget(
          MaterialApp(home: Navigator(onGenerateRoute: (settings) => route)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AdminPlaceholderScreen), findsOneWidget);
      },
    );

    testWidgets(
      '12. Acesso Não Autenticado: usuário deslogado tentando /motorista vai para LoginScreen',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);
        fakeAuth.currentUserIdOverride = null;
        fakeAuth.cachedRoleOverride = null;

        final route = RouteGuard.onGenerateRoute(
          const RouteSettings(name: '/motorista'),
          authService: fakeAuth,
        );

        await tester.pumpWidget(
          MaterialApp(home: Navigator(onGenerateRoute: (settings) => route)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets(
      '13. Logout em AdminPlaceholderScreen chama authService.logout e limpa a pilha de navegação',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/admin',
            routes: {
              '/': (context) => const Scaffold(body: Text('Tela Raiz Destino')),
              '/admin': (context) =>
                  AdminPlaceholderScreen(authService: fakeAuth),
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('botaoLogoutAdminCorpo')));
        await tester.pumpAndSettle();

        expect(fakeAuth.logoutCalls, equals(1));
        expect(find.text('Tela Raiz Destino'), findsOneWidget);
      },
    );

    testWidgets(
      '14. RouteGuard sem injeção: quando usuário autenticado não tem role em cache, redireciona para AuthGate',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);
        fakeAuth.currentUserIdOverride = 'usr_online_sem_cache';
        fakeAuth.cachedRoleOverride = null;

        final route = RouteGuard.onGenerateRoute(
          const RouteSettings(name: '/motorista'),
          authService: fakeAuth,
        );

        await tester.pumpWidget(
          MaterialApp(home: Navigator(onGenerateRoute: (settings) => route)),
        );
        await tester.pump();

        // Deve renderizar AuthGate (que exibe o splash durante carregamento)
        expect(find.byType(AuthGate), findsOneWidget);
      },
    );

    testWidgets(
      '15. AuthGate preserva card de Perfil Inválido mesmo quando logout emite null na stream',
      (WidgetTester tester) async {
        final fakeAuth = FakeGateAuthService();
        addTearDown(fakeAuth.dispose);

        await tester.pumpWidget(
          buildGateTestApp(
            authGate: AuthGate(
              authService: fakeAuth,
              roleResolver: (uid) async => throw const AuthException(
                'Perfil de usuário inválido ou não cadastrado no sistema.',
                code: 'invalid-profile',
              ),
              authStateStream: fakeAuth.authStateChanges,
            ),
          ),
        );

        fakeAuth.emitAuthState('uid_invalido_com_stream');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('telaPerfilInvalido')), findsOneWidget);

        // Simula a emissão de null decorrente de auth.signOut()
        fakeAuth.emitAuthState(null);
        await tester.pumpAndSettle();

        // O card de erro NÃO pode ter sido sobrescrito pelo login!
        expect(find.byKey(const Key('telaPerfilInvalido')), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);

        // Ao clicar no botão de voltar, aí sim retorna ao login
        await tester.tap(find.byKey(const Key('botaoVoltarLogin')));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}
