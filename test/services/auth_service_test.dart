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
}
