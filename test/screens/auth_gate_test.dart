// ============================================================================
// ARQUIVO: test/screens/auth_gate_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Suíte de testes automatizados de widget e roteamento reativo para o componente
// AuthGate (lib/screens/auth_gate.dart) e guarda de rotas RouteGuard
// (lib/routes/route_guard.dart). Cobre:
// - Transição de estados da máquina de autenticação: deslogado -> splash -> perfil.
// - Redirecionamento baseado no papel resolvido (motorista, admin, paciente).
// - Exibição de tela de splash estilizada durante carregamento sem renderizar
//   telas incorretas antecipadamente.
// - Fluxo de logout e limpeza de cache de perfil.
// - Tratamento e preservação de erros: perfil inválido, falha temporária de rede
//   (com botão Tentar Novamente), permissão negada.
// - Proteção de rotas nomeadas pelo RouteGuard contra acesso indevido/cruzado
//   (ex: motorista tentando acessar rota /administrativo).
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Testes Automatizados de Interface / Widgets (test/screens/).
//
// ONDE É USADO:
// Executado pelo executor oficial de testes do Flutter (`flutter test`).
//
// DE ONDE RECEBE DADOS:
// - Implementação simulada FakeGateAuthService implementando AuthService.
//
// O QUE EXPORTA / EXPÕE:
// - class FakeGateAuthService implements AuthService: Mock de autenticação.
// - Widget buildGateTestApp({required AuthGate authGate}): Helper para montagem.
// - void main(): Ponto de entrada da suíte de testes.
//
// ORIGEM HISTÓRICA:
// Criado no commit 600ea8b (feat: implementar tela de login, rotas protegidas
// e gate de autenticação).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart
// - package:flutter_test/flutter_test.dart
// - dart:async (Completer, StreamController)
// - Sem efeitos colaterais externos.
// ============================================================================
// Importa utilitários assíncronos do Dart como Completer e StreamController
import 'dart:async';

// Importa os componentes de interface da biblioteca Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o framework oficial de testes de widgets do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o enum de papéis funcionais de usuários
import 'package:trans_saude/models/user_role.dart';
// Importa a tela principal do motorista
import 'package:trans_saude/motorista.dart';
// Importa a tela principal do paciente
import 'package:trans_saude/paciente.dart';
// Importa a classe de guarda e interceptação de rotas protegidas
import 'package:trans_saude/routes/route_guard.dart';
// Importa a tela temporária do módulo administrativo
import 'package:trans_saude/screens/admin_placeholder_screen.dart';
// Importa o componente AuthGate sob teste
import 'package:trans_saude/screens/auth_gate.dart';
// Importa a tela oficial de login
import 'package:trans_saude/screens/login_screen.dart';
// Importa a interface do serviço de autenticação e exceção personalizada
import 'package:trans_saude/services/auth_service.dart';

// Classe mock que implementa a interface AuthService para simular o Firebase Auth
class FakeGateAuthService implements AuthService {
  // Controlador de stream broadcast para emitir alterações de autenticação (UID do usuário)
  final StreamController<String?> _authStreamController =
      StreamController<String?>.broadcast();
  // Contador de chamadas ao método logout
  int logoutCalls = 0;
  // Contador de chamadas ao método clearRoleCache
  int clearCacheCalls = 0;
  // Identificador de usuário configurável para sobrescrita em testes
  String? currentUserIdOverride;
  // Papel de usuário em cache configurável para sobrescrita em testes
  UserRole? cachedRoleOverride;

  // Sobrescrita do getter authStateChanges retornando o stream do controlador
  @override
  Stream<String?> get authStateChanges => _authStreamController.stream;

  // Emite um novo estado de autenticação para a stream
  void emitAuthState(String? uid) {
    // Atualiza o ID corrente simulado
    currentUserIdOverride = uid;
    // Adiciona o UID na stream
    _authStreamController.add(uid);
  }

  // Getter do ID do usuário autenticado no momento
  @override
  String? get currentUserId => currentUserIdOverride;

  // Retorna o papel em cache configurado para testes
  @override
  UserRole? getCachedRole(String uid) => cachedRoleOverride;

  // Limpa o cache simulado de perfis
  @override
  void clearRoleCache() {
    // Incrementa contador de chamadas
    clearCacheCalls++;
    // Reseta o papel em cache
    cachedRoleOverride = null;
  }

  // Simula o encerramento da sessão
  @override
  Future<void> logout() async {
    // Incrementa contador de chamadas de logout
    logoutCalls++;
    // Reseta o usuário autenticado
    currentUserIdOverride = null;
    // Reseta o papel em cache
    cachedRoleOverride = null;
  }

  // Simula a operação de login retornando o papel mockado
  @override
  Future<UserRole> login(String cpf, String senha) async {
    // Retorna o papel configurado ou padrão motorista
    return cachedRoleOverride ?? UserRole.motorista;
  }

  // Simula a resolução do papel no banco Firestore
  @override
  Future<UserRole> resolveUserRole(
    String uid, {
    bool forceRefresh = false,
  }) async {
    // Retorna o papel configurado ou padrão motorista
    return cachedRoleOverride ?? UserRole.motorista;
  }

  // Descarta o controlador de stream ao finalizar o teste
  void dispose() {
    // Fecha o controlador
    _authStreamController.close();
  }
}

// Constrói o aplicativo de teste envolvendo o AuthGate
Widget buildGateTestApp({required AuthGate authGate}) {
  // Retorna MaterialApp com a tela informada
  return MaterialApp(home: authGate);
}

// Ponto de entrada da suíte de testes do AuthGate
void main() {
  // Garante a inicialização das bindings de teste antes de executar os casos
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // Grupo 1: Testes da máquina de estados do AuthGate
  group('AuthGate - Máquina de Estados e Roteamento Reativo', () {
    // Caso de teste 1: Estado deslogado
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
        // Emite null simulando usuário sem sessão ativa
        fakeAuth.emitAuthState(null);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Acesse sua Conta'), findsOneWidget);
      },
    );

    // Caso de teste 2: Autenticado como motorista
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

    // Caso de teste 3: Autenticado como admin
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

    // Caso de teste 4: Autenticado como paciente
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

    // Caso de teste 5: Estado de carregamento com splash
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
        // Emite UID mantendo o futuro do completer pendente
        fakeAuth.emitAuthState('uid_em_processamento');
        await tester.pump();

        expect(find.byKey(const Key('splashCarregando')), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('TransSaúde'), findsOneWidget);

        // Nenhuma tela de perfil deve estar visível
        // Valida que nenhuma tela definitiva apareceu prematuramente
        expect(find.byType(Motorista), findsNothing);
        expect(find.byType(AdminPlaceholderScreen), findsNothing);
        expect(find.byType(Paciente), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);

        // Conclui a resolução para motorista
        // Conclui o futuro com perfil motorista
        completer.complete(UserRole.motorista);
        await tester.pumpAndSettle();

        expect(find.byType(Motorista), findsOneWidget);
      },
    );

    // Caso de teste 6: Transição reativa e limpeza de cache
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
        // Emite sessão de motorista
        fakeAuth.emitAuthState('uid_motorista_sessao');
        await tester.pumpAndSettle();
        expect(find.byType(Motorista), findsOneWidget);

        // Usuário desloga
        // Emite logout
        fakeAuth.emitAuthState(null);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(fakeAuth.clearCacheCalls, greaterThanOrEqualTo(1));
      },
    );

    // Caso de teste 7: Perfil corrompido ou inválido
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
        // Toca no botão de voltar
        await tester.tap(find.byKey(const Key('botaoVoltarLogin')));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    // Caso de teste 8: Erro temporário de rede
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
        // Assegura que logout não foi acionado
        expect(fakeAuth.logoutCalls, equals(0));
        expect(find.byKey(const Key('telaErroTemporario')), findsOneWidget);
        expect(find.text('Erro de Conexão'), findsOneWidget);

        // Recupera a conexão e tenta novamente
        // Simula recuperação de sinal e clica em Tentar novamente
        deveFalhar = false;
        await tester.tap(find.byKey(const Key('botaoTentarNovamente')));
        await tester.pumpAndSettle();

        // Consegue autenticar e abre a tela do motorista
        // Valida que autenticou com sucesso
        expect(find.byType(Motorista), findsOneWidget);
        expect(fakeAuth.logoutCalls, equals(0));
      },
    );

    // Caso de teste 9: Permissão negada no Firestore
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

  // Grupo 2: Testes de proteção de rotas com RouteGuard
  group('RouteGuard - Proteção de Rotas e Bloqueio de Acesso Cruzado', () {
    // Caso de teste 10: Bloqueio de acesso cruzado
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
        // Valida redirecionamento
        expect(find.byType(Motorista), findsOneWidget);
        expect(find.byType(AdminPlaceholderScreen), findsNothing);
      },
    );

    // Caso de teste 11: Acesso autorizado de administrador
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

    // Caso de teste 12: Acesso não autenticado
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

    // Caso de teste 13: Logout no AdminPlaceholderScreen
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

    // Caso de teste 14: RouteGuard sem cache redireciona para AuthGate
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
        // Valida que o AuthGate foi acionado para resolver o perfil
        expect(find.byType(AuthGate), findsOneWidget);
      },
    );

    // Caso de teste 15: Preservação do card de erro de perfil inválido
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
        // Emite null após logout
        fakeAuth.emitAuthState(null);
        await tester.pumpAndSettle();

        // O card de erro NÃO pode ter sido sobrescrito pelo login!
        // Garante que o card de erro permaneceu ativo
        expect(find.byKey(const Key('telaPerfilInvalido')), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);

        // Ao clicar no botão de voltar, aí sim retorna ao login
        // Ao clicar em voltar, retorna ao login
        await tester.tap(find.byKey(const Key('botaoVoltarLogin')));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}
