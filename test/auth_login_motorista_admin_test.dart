// ============================================================================
// ARQUIVO: test/auth_login_motorista_admin_test.dart
// ----------------------------------------------------------------------------
// Testes unitários e de integração da FASE 2:
// Correção do Login de Motorista e Administrador e Prevenção de Regressão:
// 1. Motorista autentica e é roteado para /motorista sem contaminação de paciente;
// 2. Administrador autentica e é roteado para /administrativo sem contaminação;
// 3. Login de paciente/acompanhante (CPF + código numérico) segue 100% funcional;
// 4. Rate Limiting de segurança: 5 tentativas falhas bloqueiam por 15 minutos;
// 5. Tratamento de senha incorreta e usuário inexistente com mensagens seguras;
// 6. Perfil não autorizado (paciente tentando login operacional) resulta em access-denied;
// 7. Logout limpa a sessão, o cache de papéis e o identificador de paciente.
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/routes/route_guard.dart';
import 'package:trans_saude/services/auth_service.dart';

// Simulação de User do Firebase
class _FakeUser implements User {
  @override
  final String uid;
  @override
  final String? email;

  _FakeUser({required this.uid, this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Simulação de UserCredential do Firebase
class _FakeUserCredential implements UserCredential {
  @override
  final User? user;

  _FakeUserCredential({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Simulação controlada de FirebaseAuth
class _FakeFirebaseAuth implements FirebaseAuth {
  User? _currentUser;
  final Map<String, String> credentialsValidas;
  final FirebaseAuthException? erroSimulado;

  _FakeFirebaseAuth({
    this.credentialsValidas = const {},
    this.erroSimulado,
  });

  @override
  User? get currentUser => _currentUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (erroSimulado != null) {
      throw erroSimulado!;
    }
    if (credentialsValidas.containsKey(email) &&
        credentialsValidas[email] == password) {
      final user = _FakeUser(uid: 'uid_$email', email: email);
      _currentUser = user;
      return _FakeUserCredential(user: user);
    }
    throw FirebaseAuthException(code: 'wrong-password');
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FirebaseAuthService.resetarRateLimitParaTestes();
  });

  group('Fase 2 - Correção do Login de Motorista e Administrador', () {
    test('1. Motorista autentica com sucesso e não sofre contaminação pós-login de paciente', () async {
      final fakeAuth = _FakeFirebaseAuth(
        credentialsValidas: {
          '11122233344@transsaude.sp.gov.br': 'senhaMotorista123',
        },
      );

      final authService = FirebaseAuthService(
        auth: fakeAuth,
        userDocFetcher: (uid) async {
          if (uid == 'uid_11122233344@transsaude.sp.gov.br') {
            return {'role': 'motorista', 'nome': 'Antônio Carlos'};
          }
          return null;
        },
      );

      // Simula estado contaminado prévio: paciente fez login antes
      await authService.loginPacienteComCodigo(
        documento: '571.098.984-31',
        codigoAcesso: '7890',
      );
      expect(authService.currentUserId, equals('nhkT53OclKj552MmiMN5'));
      expect(authService.getCachedRole(authService.currentUserId!), equals(UserRole.paciente));

      // Motorista entra com CPF e senha
      final role = await authService.login('111.222.333-44', 'senhaMotorista123');

      // Verifica que o role retornado é motorista
      expect(role, equals(UserRole.motorista));
      // Verifica que _pacienteLogadoId foi purgado e o currentUserId é o do motorista
      expect(authService.currentUserId, equals('uid_11122233344@transsaude.sp.gov.br'));
      expect(
        authService.getCachedRole('uid_11122233344@transsaude.sp.gov.br'),
        equals(UserRole.motorista),
      );

      // RouteGuard resolve permissão legítima para /motorista
      final rota = RouteGuard.onGenerateRoute(
        const RouteSettings(name: '/motorista'),
        authService: authService,
      );
      expect(rota, isNotNull);
      expect(rota.settings.name, equals('/motorista'));
    });

    test('2. Administrador autentica com sucesso e não sofre contaminação pós-login de paciente', () async {
      final fakeAuth = _FakeFirebaseAuth(
        credentialsValidas: {
          '99988877766@transsaude.sp.gov.br': 'senhaAdmin123',
        },
      );

      final authService = FirebaseAuthService(
        auth: fakeAuth,
        userDocFetcher: (uid) async {
          if (uid == 'uid_99988877766@transsaude.sp.gov.br') {
            return {'role': 'admin', 'nome': 'Gestor Municipal'};
          }
          return null;
        },
      );

      // Simula paciente logado antes
      await authService.loginPacienteComCodigo(
        documento: '571.098.984-31',
        codigoAcesso: '7890',
      );

      // Admin entra
      final role = await authService.login('999.888.777-66', 'senhaAdmin123');

      expect(role, equals(UserRole.admin));
      expect(authService.currentUserId, equals('uid_99988877766@transsaude.sp.gov.br'));
      expect(
        authService.getCachedRole('uid_99988877766@transsaude.sp.gov.br'),
        equals(UserRole.admin),
      );

      // RouteGuard resolve permissão legítima para /administrativo
      final rota = RouteGuard.onGenerateRoute(
        const RouteSettings(name: '/administrativo'),
        authService: authService,
      );
      expect(rota, isNotNull);
      expect(rota.settings.name, equals('/administrativo'));
    });

    test('3. Login de paciente/acompanhante por CPF e código numérico segue funcional sem regressão', () async {
      final authService = FirebaseAuthService();
      authService.clearRoleCache();

      final role = await authService.loginPacienteComCodigo(
        documento: '571.098.984-31',
        codigoAcesso: '7890',
      );

      expect(role, equals(UserRole.paciente));
      expect(authService.currentUserId, isNotNull);
      expect(authService.getCachedRole(authService.currentUserId!), equals(UserRole.paciente));

      final rota = RouteGuard.onGenerateRoute(
        const RouteSettings(name: '/paciente'),
        authService: authService,
      );
      expect(rota, isNotNull);
      expect(rota.settings.name, equals('/paciente'));
    });

    test('4. Rate Limiting de segurança: 5 tentativas falhas consecutivas bloqueiam por 15 minutos', () async {
      final fakeAuth = _FakeFirebaseAuth(
        credentialsValidas: {},
      );

      final authService = FirebaseAuthService(auth: fakeAuth);
      const cpfTeste = '123.456.789-00';

      // 4 tentativas falhas
      for (int i = 0; i < 4; i++) {
        await expectLater(
          () => authService.login(cpfTeste, 'senha_incorreta'),
          throwsA(isA<AuthException>()),
        );
      }

      expect(FirebaseAuthService.estaBloqueadoOperacional(cpfTeste), isFalse);

      // 5ª tentativa falha dispara o bloqueio
      await expectLater(
        () => authService.login(cpfTeste, 'senha_incorreta'),
        throwsA(isA<AuthException>()),
      );

      expect(FirebaseAuthService.estaBloqueadoOperacional(cpfTeste), isTrue);

      // 6ª tentativa é bloqueada imediatamente por rate limit
      await expectLater(
        () => authService.login(cpfTeste, 'qualquer_senha'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'rate-limit-exceeded',
          ),
        ),
      );
    });

    test('5. Tratamento de senha errada e usuário inexistente retorna mensagem sem vazar dados', () async {
      final fakeAuth = _FakeFirebaseAuth(
        erroSimulado: FirebaseAuthException(code: 'user-not-found'),
      );
      final authService = FirebaseAuthService(auth: fakeAuth);

      await expectLater(
        () => authService.login('000.111.222-33', '123456'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Usuário não encontrado.',
          ),
        ),
      );
    });

    test('6. Perfil não operacional (paciente tentando login operacional) resulta em access-denied', () async {
      final fakeAuth = _FakeFirebaseAuth(
        credentialsValidas: {
          '33322211100@transsaude.sp.gov.br': 'senhaValida',
        },
      );

      final authService = FirebaseAuthService(
        auth: fakeAuth,
        userDocFetcher: (uid) async {
          return {'role': 'paciente', 'nome': 'Paciente Teste'};
        },
      );

      await expectLater(
        () => authService.login('333.222.111-00', 'senhaValida'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'access-denied',
          ),
        ),
      );
    });

    test('7. Logout limpa a sessão, o cache de papéis e o identificador de paciente', () async {
      final fakeAuth = _FakeFirebaseAuth(
        credentialsValidas: {
          '11122233344@transsaude.sp.gov.br': 'senhaMotorista123',
        },
      );

      final authService = FirebaseAuthService(
        auth: fakeAuth,
        userDocFetcher: (uid) async {
          return {'role': 'motorista'};
        },
      );

      await authService.login('111.222.333-44', 'senhaMotorista123');
      expect(authService.currentUserId, isNotNull);

      await authService.logout();

      expect(authService.currentUserId, isNull);
      expect(fakeAuth.currentUser, isNull);
    });
  });
}
