import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/services/auth_service.dart';

class FakeUser implements User {
  @override
  final String uid;

  FakeUser({required this.uid});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  @override
  final User? user;

  FakeUserCredential({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  final User? currentUserOverride;
  final FirebaseAuthException? errorToThrow;
  String? lastSignedInEmail;
  String? lastSignedInPassword;
  bool signedOut = false;

  FakeFirebaseAuth({this.currentUserOverride, this.errorToThrow});

  @override
  User? get currentUser => currentUserOverride;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    lastSignedInEmail = email;
    lastSignedInPassword = password;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return FakeUserCredential(user: currentUserOverride);
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group(
    'AuthService - Mapeamento de Códigos de Erro FirebaseAuthException',
    () {
      final mapCases = {
        'invalid-credential': 'CPF ou senha incorretos.',
        'user-not-found': 'Usuário não encontrado.',
        'wrong-password': 'Senha incorreta.',
        'too-many-requests':
            'Muitas tentativas sem sucesso. Tente novamente mais tarde.',
        'network-request-failed':
            'Falha de conexão com a rede. Verifique sua internet.',
        'user-disabled':
            'Este usuário foi desabilitado. Contate o administrador.',
        'invalid-email': 'Formato de identificação inválido.',
        'unknown-error':
            'Ocorreu um erro ao realizar o login. Tente novamente.',
      };

      mapCases.forEach((code, expectedMessage) {
        test('código "$code" deve retornar "$expectedMessage"', () {
          final ex = FirebaseAuthException(code: code);
          expect(
            FirebaseAuthService.mapFirebaseAuthException(ex),
            expectedMessage,
          );
        });
      });

      test('login com FirebaseAuthException lança AuthException com mensagem mapeada', () async {
        final fakeAuth = FakeFirebaseAuth(
          errorToThrow: FirebaseAuthException(code: 'wrong-password'),
        );
        final service = FirebaseAuthService(
          auth: fakeAuth,
          userDocFetcher: (uid) async => null,
        );

        expect(
          () => service.login('123.456.789-01', '123456'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Senha incorreta.',
            ),
          ),
        );
      });
    },
  );

  group('AuthService - Resolução de Perfil e Autorização via CPF', () {
    test(
      'login com CPF resolve para motorista e autentica corretamente',
      () async {
        final fakeAuth = FakeFirebaseAuth(
          currentUserOverride: FakeUser(uid: 'mot123'),
        );
        final service = FirebaseAuthService(
          auth: fakeAuth,
          cpfEmailResolver: (cleanCpf) async => 'motorista@transsaude.com',
          userDocFetcher: (uid) async => {
            'cpf': '12345678901',
            'role': 'motorista',
            'nome': 'João Motorista',
          },
        );

        final role = await service.login('123.456.789-01', 'senha123');
        expect(role, UserRole.motorista);
        expect(fakeAuth.lastSignedInEmail, 'motorista@transsaude.com');
        expect(fakeAuth.signedOut, isFalse);
      },
    );

    test(
      'login com CPF sem e-mail customizado usa fallback institucional',
      () async {
        final fakeAuth = FakeFirebaseAuth(
          currentUserOverride: FakeUser(uid: 'mot123'),
        );
        final service = FirebaseAuthService(
          auth: fakeAuth,
          userDocFetcher: (uid) async => {
            'role': 'motorista',
            'nome': 'João Motorista',
          },
        );

        final role = await service.login('12345678901', 'senha123');
        expect(role, UserRole.motorista);
        expect(fakeAuth.lastSignedInEmail, '12345678901@transsaude.sp.gov.br');
        expect(fakeAuth.signedOut, isFalse);
      },
    );

    test('role "admin" com CPF retorna UserRole.admin', () async {
      final fakeAuth = FakeFirebaseAuth(
        currentUserOverride: FakeUser(uid: 'adm123'),
      );
      final service = FirebaseAuthService(
        auth: fakeAuth,
        userDocFetcher: (uid) async => {
          'role': 'admin',
          'nome': 'Gestor Admin',
        },
      );

      final role = await service.login('987.654.321-00', 'senhaAdmin123');
      expect(role, UserRole.admin);
      expect(fakeAuth.signedOut, isFalse);
    });

    test(
      'usuário sem documento no Firestore lança erro e executa signOut',
      () async {
        final fakeAuth = FakeFirebaseAuth(
          currentUserOverride: FakeUser(uid: 'sem_doc'),
        );
        final service = FirebaseAuthService(
          auth: fakeAuth,
          userDocFetcher: (uid) async => null,
        );

        expect(
          () => service.login('111.222.333-44', 'senha123'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Usuário não cadastrado ou sem permissão de acesso.',
            ),
          ),
        );
        await pumpEventQueue();
        expect(fakeAuth.signedOut, isTrue);
      },
    );

    test('usuário com role "paciente" lança erro e executa signOut', () async {
      final fakeAuth = FakeFirebaseAuth(
        currentUserOverride: FakeUser(uid: 'pac123'),
      );
      final service = FirebaseAuthService(
        auth: fakeAuth,
        userDocFetcher: (uid) async => {
          'role': 'paciente',
          'nome': 'Paciente da Silva',
        },
      );

      expect(
        () => service.login('555.666.777-88', 'senha123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Acesso restrito a motoristas e administradores.',
          ),
        ),
      );
      await pumpEventQueue();
      expect(fakeAuth.signedOut, isTrue);
    });

    test(
      'usuário com role desconhecido lança erro e executa signOut',
      () async {
        final fakeAuth = FakeFirebaseAuth(
          currentUserOverride: FakeUser(uid: 'desc123'),
        );
        final service = FirebaseAuthService(
          auth: fakeAuth,
          userDocFetcher: (uid) async => {
            'role': 'qualquer_outro',
            'nome': 'Desconhecido',
          },
        );

        expect(
          () => service.login('999.888.777-66', 'senha123'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Acesso restrito a motoristas e administradores.',
            ),
          ),
        );
        await pumpEventQueue();
        expect(fakeAuth.signedOut, isTrue);
      },
    );

    test('método logout executa signOut no FirebaseAuth', () async {
      final fakeAuth = FakeFirebaseAuth();
      final service = FirebaseAuthService(auth: fakeAuth);

      await service.logout();
      expect(fakeAuth.signedOut, isTrue);
    });
  });

  group('AuthService - Resolução de Perfil de Usuário (Issue #28)', () {
    test('resolveUserRole retorna UserRole.motorista', () async {
      final service = FirebaseAuthService(
        userDocFetcher: (uid) async => {'role': 'motorista', 'nome': 'João'},
      );
      final role = await service.resolveUserRole('mot_1');
      expect(role, UserRole.motorista);
    });

    test('resolveUserRole retorna UserRole.admin', () async {
      final service = FirebaseAuthService(
        userDocFetcher: (uid) async => {'role': 'admin', 'nome': 'Gestor'},
      );
      final role = await service.resolveUserRole('adm_1');
      expect(role, UserRole.admin);
    });

    test('resolveUserRole retorna UserRole.paciente', () async {
      final service = FirebaseAuthService(
        userDocFetcher: (uid) async => {'role': 'paciente', 'nome': 'Maria'},
      );
      final role = await service.resolveUserRole('pac_1');
      expect(role, UserRole.paciente);
    });

    test(
      'documento ausente lança AuthException com code user-not-registered',
      () async {
        final service = FirebaseAuthService(
          userDocFetcher: (uid) async => null,
        );
        expect(
          () => service.resolveUserRole('sem_doc'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              'user-not-registered',
            ),
          ),
        );
      },
    );

    test(
      'campo role ausente lança AuthException com code invalid-profile',
      () async {
        final service = FirebaseAuthService(
          userDocFetcher: (uid) async => {'nome': 'Sem Role'},
        );
        expect(
          () => service.resolveUserRole('sem_role'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              'invalid-profile',
            ),
          ),
        );
      },
    );

    test(
      'role desconhecido lança AuthException com code unknown-role',
      () async {
        final service = FirebaseAuthService(
          userDocFetcher: (uid) async => {'role': 'perfil_alienigena'},
        );
        expect(
          () => service.resolveUserRole('desconhecido'),
          throwsA(
            isA<AuthException>().having((e) => e.code, 'code', 'unknown-role'),
          ),
        );
      },
    );

    test('erro temporário de rede no Firestore lança AuthException com code unavailable', () async {
      final service = FirebaseAuthService(
        userDocFetcher: (uid) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'The service is currently unavailable.',
        ),
      );
      expect(
        () => service.resolveUserRole('offline_uid'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
    });

    test('erro de permission-denied lança AuthException com code permission-denied', () async {
      final service = FirebaseAuthService(
        userDocFetcher: (uid) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
      );
      expect(
        () => service.resolveUserRole('denied_uid'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('cache armazena role e evita nova chamada ao fetcher', () async {
      int fetchCalls = 0;
      final service = FirebaseAuthService(
        userDocFetcher: (uid) async {
          fetchCalls++;
          return {'role': 'motorista'};
        },
      );

      final role1 = await service.resolveUserRole('uid_cached');
      final role2 = await service.resolveUserRole('uid_cached');
      expect(role1, UserRole.motorista);
      expect(role2, UserRole.motorista);
      expect(fetchCalls, equals(1));
      expect(service.getCachedRole('uid_cached'), equals(UserRole.motorista));

      final role3 = await service.resolveUserRole(
        'uid_cached',
        forceRefresh: true,
      );
      expect(role3, UserRole.motorista);
      expect(fetchCalls, equals(2));

      service.clearRoleCache();
      expect(service.getCachedRole('uid_cached'), isNull);
    });
  });
}
