import 'dart:async';

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

  /// Stream reativa de mudanças no estado de autenticação (emite UID do usuário ou null se deslogado)
  Stream<String?> get authStateChanges => const Stream.empty();

  /// Resolve o UserRole de um usuário autenticado a partir de seu UID
  Future<UserRole> resolveUserRole(String uid, {bool forceRefresh = false}) =>
      throw UnimplementedError('resolveUserRole não implementado');

  /// Retorna o role em cache para o UID informado, se existir
  UserRole? getCachedRole(String uid) => null;

  /// Limpa o cache de roles resolvidos
  void clearRoleCache() {}

  /// Retorna o UID do usuário atualmente autenticado, se houver
  String? get currentUserId => null;
}

/// Implementação oficial do AuthService baseada em Firebase Authentication e Cloud Firestore
class FirebaseAuthService implements AuthService {
  final FirebaseAuth? customAuth;
  final FirebaseFirestore? customFirestore;
  final Future<Map<String, dynamic>?> Function(String uid)? userDocFetcher;
  final Future<String?> Function(String cleanCpf)? cpfEmailResolver;
  final Map<String, UserRole> _roleCache = {};

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

  @override
  Stream<String?> get authStateChanges =>
      auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUserId => auth.currentUser?.uid;

  @override
  UserRole? getCachedRole(String uid) => _roleCache[uid];

  @override
  void clearRoleCache() => _roleCache.clear();

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
  Future<UserRole> resolveUserRole(
    String uid, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _roleCache.containsKey(uid)) {
      return _roleCache[uid]!;
    }

    Map<String, dynamic>? data;
    try {
      data = await _fetchUserData(uid);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AuthException(
          'Permissão negada ao consultar perfil de usuário.',
          code: 'permission-denied',
        );
      }
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        throw const AuthException(
          'Falha temporária de conexão com o servidor.',
          code: 'unavailable',
        );
      }
      throw AuthException(
        'Erro ao consultar perfil de acesso: ${e.message}',
        code: e.code,
      );
    } on TimeoutException {
      throw const AuthException(
        'Tempo limite excedido ao consultar perfil.',
        code: 'unavailable',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('timeout') ||
          msg.contains('unavailable')) {
        throw const AuthException(
          'Falha temporária de conexão com o servidor.',
          code: 'unavailable',
        );
      }
      throw AuthException(
        'Erro ao consultar perfil de acesso. Tente novamente.',
      );
    }

    if (data == null) {
      throw const AuthException(
        'Usuário não cadastrado ou sem permissão de acesso.',
        code: 'user-not-registered',
      );
    }

    final roleRaw = data['role'];
    if (roleRaw == null || roleRaw.toString().trim().isEmpty) {
      throw const AuthException(
        'Perfil do usuário ausente no cadastro.',
        code: 'invalid-profile',
      );
    }

    final roleStr = roleRaw.toString().trim();
    final UserRole role;
    if (roleStr == 'motorista') {
      role = UserRole.motorista;
    } else if (roleStr == 'admin') {
      role = UserRole.admin;
    } else if (roleStr == 'paciente') {
      role = UserRole.paciente;
    } else {
      throw AuthException(
        'Perfil de usuário desconhecido ou inválido: $roleStr',
        code: 'unknown-role',
      );
    }

    _roleCache[uid] = role;
    return role;
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
      final role = await resolveUserRole(user.uid);

      if (role == UserRole.motorista) {
        return UserRole.motorista;
      } else if (role == UserRole.admin) {
        return UserRole.admin;
      } else {
        await auth.signOut();
        throw const AuthException(
          'Acesso restrito a motoristas e administradores.',
          code: 'access-denied',
        );
      }
    } on AuthException catch (e) {
      await auth.signOut();
      if (e.code == 'unknown-role') {
        throw const AuthException(
          'Acesso restrito a motoristas e administradores.',
          code: 'access-denied',
        );
      }
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
    clearRoleCache();
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
