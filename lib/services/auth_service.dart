import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';

/// Exceção de domínio padronizada para autenticação e autorização
class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Interface abstrata para injeção de dependência e testes
abstract class AuthService {
  Future<UserRole> login(String cpf, String senha);
  Future<void> logout();
}

/// Implementação oficial do AuthService baseada em Firebase Authentication e Cloud Firestore
class FirebaseAuthService implements AuthService {
  final FirebaseAuth? customAuth;
  final FirebaseFirestore? customFirestore;
  final Future<Map<String, dynamic>?> Function(String uid)? userDocFetcher;
  final Future<String?> Function(String cleanCpf)? cpfEmailResolver;

  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.userDocFetcher,
    this.cpfEmailResolver,
  }) : customAuth = auth,
       customFirestore = firestore;

  FirebaseAuth get auth => customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore =>
      customFirestore ?? FirebaseFirestore.instance;

  Future<String> _resolveEmail(String cleanCpf, String rawCpf) async {
    final resolver = cpfEmailResolver;
    if (resolver != null) {
      final resolved = await resolver(cleanCpf);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }

    try {
      final query = await firestore
          .collection('usuarios')
          .where('cpf', whereIn: [cleanCpf, rawCpf])
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final email = query.docs.first.data()['email']?.toString();
        if (email != null && email.isNotEmpty) {
          return email;
        }
      }
    } catch (_) {}

    return '$cleanCpf@transsaude.sp.gov.br';
  }

  Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    final fetcher = userDocFetcher;
    if (fetcher != null) {
      return fetcher(uid);
    }
    final doc = await firestore.collection('usuarios').doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return doc.data();
  }

  @override
  Future<UserRole> login(String cpf, String senha) async {
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');
    final email = await _resolveEmail(cleanCpf, cpf.trim());

    UserCredential credential;
    try {
      credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(mapFirebaseAuthException(e), code: e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
        'Ocorreu um erro ao realizar o login. Tente novamente.',
      );
    }

    final user = credential.user;
    if (user == null) {
      throw const AuthException(
        'Falha na identificação do usuário autenticado.',
      );
    }

    try {
      final data = await _fetchUserData(user.uid);

      if (data == null) {
        await auth.signOut();
        throw const AuthException(
          'Usuário não cadastrado ou sem permissão de acesso.',
          code: 'user-not-registered',
        );
      }

      final roleStr = data['role']?.toString();

      if (roleStr == 'motorista') {
        return UserRole.motorista;
      } else if (roleStr == 'admin') {
        return UserRole.admin;
      } else {
        await auth.signOut();
        throw const AuthException(
          'Acesso restrito a motoristas e administradores.',
          code: 'access-denied',
        );
      }
    } on AuthException {
      rethrow;
    } catch (_) {
      await auth.signOut();
      throw const AuthException(
        'Erro ao consultar perfil de acesso. Tente novamente.',
      );
    }
  }

  @override
  Future<void> logout() async {
    await auth.signOut();
  }

  /// Mapeamento de erros de infraestrutura do Firebase para mensagens amigáveis em português
  static String mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'CPF ou senha incorretos.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'too-many-requests':
        return 'Muitas tentativas sem sucesso. Tente novamente mais tarde.';
      case 'network-request-failed':
        return 'Falha de conexão com a rede. Verifique sua internet.';
      case 'user-disabled':
        return 'Este usuário foi desabilitado. Contate o administrador.';
      case 'invalid-email':
        return 'Formato de identificação inválido.';
      default:
        return 'Ocorreu um erro ao realizar o login. Tente novamente.';
    }
  }
}
