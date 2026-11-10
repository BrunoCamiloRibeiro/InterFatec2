import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/paciente_model.dart';
import '../models/user_role.dart';
import '../models/viagem_model.dart';
import 'codigo_acesso_service.dart';
import 'cpf_validator.dart';
import 'localizacao_motorista_service.dart';
import 'viagem_service.dart';

/// Exceção de domínio padronizada para autenticação e autorização.
class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Contrato abstrato de autenticação para inversão de dependência e testes.
abstract class AuthService {
  Future<UserRole> login(String cpf, String senha);

  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) =>
      throw UnimplementedError('loginPacienteComCodigo não implementado');

  Future<void> logout();

  /// Stream reativa de mudanças no estado de autenticação (emite UID ou null).
  Stream<String?> get authStateChanges => const Stream.empty();

  /// Resolve o [UserRole] de um usuário autenticado a partir de seu UID.
  Future<UserRole> resolveUserRole(String uid, {bool forceRefresh = false}) =>
      throw UnimplementedError('resolveUserRole não implementado');

  /// Retorna o papel em cache para o UID informado, se existir.
  UserRole? getCachedRole(String uid) => null;

  /// Limpa o cache em memória de papéis e sessão ativa.
  void clearRoleCache() {}

  String? get currentUserId => null;
}

/// Implementação de [AuthService] integrada ao Firebase Auth e Cloud Firestore.
class FirebaseAuthService implements AuthService {
  final FirebaseAuth? customAuth;
  final FirebaseFirestore? customFirestore;
  final Future<Map<String, dynamic>?> Function(String uid)? userDocFetcher;
  final Future<String?> Function(String cleanCpf)? cpfEmailResolver;

  /// Cache estático compartilhado entre instâncias criadas pelo RouteGuard/widgets.
  static final Map<String, UserRole> _roleCache = {};

  static String? _pacienteLogadoId;
  static String? _pacienteViagemId;

  /// Viagem à qual o paciente autenticado via código pertence na sessão atual.
  static String? get pacienteViagemId => _pacienteViagemId;

  static String? _usuarioOperacionalLogadoId;
  static String? _usuarioOperacionalDocId;
  static bool? motoristaEmViagemStatic;

  // Rate limiting contra força bruta para login operacional (5 tentativas -> 15 min).
  static final Map<String, int> _tentativasLoginOperacional = {};
  static final Map<String, DateTime> _bloqueioAteOperacional = {};

  static bool estaBloqueadoOperacional(String cpf) {
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    final expira = _bloqueioAteOperacional[clean];
    if (expira != null) {
      if (DateTime.now().isBefore(expira)) {
        return true;
      }
      _bloqueioAteOperacional.remove(clean);
      _tentativasLoginOperacional.remove(clean);
    }
    return false;
  }

  static void registrarFalhaOperacional(String cpf) {
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    final tentativas = (_tentativasLoginOperacional[clean] ?? 0) + 1;
    _tentativasLoginOperacional[clean] = tentativas;
    if (tentativas >= 5) {
      _bloqueioAteOperacional[clean] =
          DateTime.now().add(const Duration(minutes: 15));
    }
  }

  static void resetarTentativasOperacional(String cpf) {
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    _tentativasLoginOperacional.remove(clean);
    _bloqueioAteOperacional.remove(clean);
  }

  static void resetarRateLimitParaTestes() {
    _tentativasLoginOperacional.clear();
    _bloqueioAteOperacional.clear();
  }

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
  Stream<String?> get authStateChanges => auth
      .authStateChanges()
      .map((user) => user?.uid ?? _usuarioOperacionalLogadoId ?? _pacienteLogadoId);

  String? get currentDocId => _usuarioOperacionalDocId ?? currentUserId;
  bool? get motoristaEmViagem => motoristaEmViagemStatic;

  @override
  String? get currentUserId {
    if (_pacienteLogadoId != null) return _pacienteLogadoId;
    if (customAuth == null && _usuarioOperacionalLogadoId != null) {
      return _usuarioOperacionalLogadoId;
    }
    try {
      return auth.currentUser?.uid ?? _usuarioOperacionalLogadoId;
    } catch (_) {
      return _usuarioOperacionalLogadoId;
    }
  }

  @override
  UserRole? getCachedRole(String uid) => _roleCache[uid];

  @override
  void clearRoleCache() {
    _pacienteLogadoId = null;
    _pacienteViagemId = null;
    _usuarioOperacionalLogadoId = null;
    _usuarioOperacionalDocId = null;
    motoristaEmViagemStatic = null;
    _roleCache.clear();
  }

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

    return CpfValidator.derivarEmail(cleanCpf);
  }

  Map<String, dynamic> _registrarDocOperacional(
    String docId,
    Map<String, dynamic> data,
  ) {
    _usuarioOperacionalDocId = docId;
    if (data['role'] == 'motorista') {
      motoristaEmViagemStatic =
          data['emViagem'] == true || data['emViagem'] == 'true';
    }
    return data;
  }

  Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    final fetcher = userDocFetcher;
    if (fetcher != null) return fetcher(uid);

    final doc = await firestore.collection('usuarios').doc(uid).get();
    if (doc.exists) {
      _usuarioOperacionalDocId = doc.id;
      final data = doc.data();
      if (data == null) return null;
      return _registrarDocOperacional(doc.id, data);
    }

    // Fallback pós lazy-migration: procura documento vinculado por authUid.
    try {
      final queryAuth = await firestore
          .collection('usuarios')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (queryAuth.docs.isNotEmpty) {
        final d = queryAuth.docs.first;
        return _registrarDocOperacional(d.id, d.data());
      }
    } catch (_) {}

    // Fallback pós-F5 pelo e-mail sintético do usuário autenticado.
    try {
      final userAuth = auth.currentUser;
      if (userAuth?.email != null && userAuth!.email!.isNotEmpty) {
        final queryEmail = await firestore
            .collection('usuarios')
            .where('email', isEqualTo: userAuth.email)
            .limit(1)
            .get();
        if (queryEmail.docs.isNotEmpty) {
          final d = queryEmail.docs.first;
          return _registrarDocOperacional(d.id, d.data());
        }
      }
    } catch (_) {}

    return null;
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
    } else if (roleStr == 'admin' || roleStr == 'administrador') {
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

  static bool _usuarioEstaInativo(Map<String, dynamic> dados) {
    final ativo = dados['ativo'];
    final statusStr = dados['status']?.toString().toLowerCase().trim();
    final situacaoStr = dados['situacao']?.toString().toLowerCase().trim();
    return ativo == false ||
        ativo == 'false' ||
        statusStr == 'inativo' ||
        statusStr == 'excluido' ||
        situacaoStr == 'inativo' ||
        situacaoStr == 'excluido';
  }

  /// Valida CPF e senha contra a coleção 'usuarios' para suportar lazy migration
  /// de contas pré-cadastradas sem provisão prévia no Firebase Auth.
  Future<({UserRole? role, String? uid, bool encontrouUsuarioSemSenha})>
      _autenticarViaFirestoreUsuarios(
    String cleanCpf,
    String rawCpf,
    String senha,
  ) async {
    final formattedCpf = cleanCpf.length == 11
        ? '${cleanCpf.substring(0, 3)}.${cleanCpf.substring(3, 6)}.${cleanCpf.substring(6, 9)}-${cleanCpf.substring(9, 11)}'
        : null;

    final candidatosCpf = <String>{
      if (cleanCpf.isNotEmpty) cleanCpf,
      ?formattedCpf,
      if (rawCpf.isNotEmpty) rawCpf,
    }.toList();

    final docsPorId = <String, Map<String, dynamic>>{};

    if (candidatosCpf.isNotEmpty) {
      final snap = await firestore
          .collection('usuarios')
          .where('cpf', whereIn: candidatosCpf)
          .get();
      for (final doc in snap.docs) {
        docsPorId[doc.id] = doc.data();
      }
    }

    final precisaVarreduraCompleta = docsPorId.isEmpty ||
        !docsPorId.values.any((d) =>
            (d['senha'] != null && d['senha'].toString().trim().isNotEmpty) ||
            (d['password'] != null &&
                d['password'].toString().trim().isNotEmpty)) ||
        !docsPorId.values.any(
            (d) => d['role'] != null && d['role'].toString().trim().isNotEmpty);

    if (precisaVarreduraCompleta && cleanCpf.isNotEmpty) {
      final todosSnap = await firestore.collection('usuarios').get();
      for (final doc in todosSnap.docs) {
        final dados = doc.data();
        final docCpfLimpo =
            (dados['cpf'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        if (docCpfLimpo == cleanCpf) {
          docsPorId[doc.id] = dados;
        }
      }
    }

    String? uidComRole;
    String? roleEncontrada;
    String? uidQualquer;
    final senhasCadastradas = <String>[];
    int docsAtivosCount = 0;

    for (final entry in docsPorId.entries) {
      final dados = entry.value;
      if (_usuarioEstaInativo(dados)) continue;

      docsAtivosCount++;
      uidQualquer ??= entry.key;

      final r = dados['role']?.toString().trim().toLowerCase();
      if (r != null && r.isNotEmpty) {
        if (uidComRole == null ||
            r == 'motorista' ||
            r == 'admin' ||
            r == 'administrador') {
          uidComRole = entry.key;
          roleEncontrada = r;
        }
      }

      final s1 = dados['senha']?.toString();
      if (s1 != null && s1.trim().isNotEmpty) {
        senhasCadastradas.add(s1);
      }
      final s2 = dados['password']?.toString();
      if (s2 != null && s2.trim().isNotEmpty) {
        senhasCadastradas.add(s2);
      }
    }

    if (docsAtivosCount == 0) {
      return (role: null, uid: null, encontrouUsuarioSemSenha: false);
    }

    if (roleEncontrada == 'paciente') {
      registrarFalhaOperacional(cleanCpf);
      throw const AuthException(
        'Acesso restrito a motoristas e administradores.',
        code: 'access-denied',
      );
    }

    if (senhasCadastradas.isNotEmpty) {
      final senhaConfere = senhasCadastradas.any(
        (s) => s == senha || s.trim() == senha.trim(),
      );
      if (!senhaConfere) {
        registrarFalhaOperacional(cleanCpf);
        throw const AuthException(
          'CPF ou senha incorretos.',
          code: 'invalid-credential',
        );
      }

      final uidFinal = uidComRole ?? uidQualquer!;
      _usuarioOperacionalDocId = uidFinal;
      final roleStr = (roleEncontrada ?? 'motorista').toLowerCase().trim();
      final docAchado = docsPorId[uidFinal];
      if (docAchado != null && roleStr == 'motorista') {
        motoristaEmViagemStatic =
            docAchado['emViagem'] == true || docAchado['emViagem'] == 'true';
      }

      if (roleStr == 'motorista' ||
          roleStr == 'admin' ||
          roleStr == 'administrador') {
        final roleResolvida =
            roleStr == 'motorista' ? UserRole.motorista : UserRole.admin;
        resetarTentativasOperacional(cleanCpf);
        _usuarioOperacionalLogadoId = uidFinal;
        _roleCache[uidFinal] = roleResolvida;
        return (
          role: roleResolvida,
          uid: uidFinal,
          encontrouUsuarioSemSenha: false,
        );
      }

      registrarFalhaOperacional(cleanCpf);
      throw const AuthException(
        'Acesso restrito a motoristas e administradores.',
        code: 'access-denied',
      );
    }

    return (role: null, uid: null, encontrouUsuarioSemSenha: true);
  }

  @override
  Future<UserRole> login(String cpf, String senha) async {
    // Limpa IDs de sessão anteriores antes de iniciar nova autenticação.
    _pacienteLogadoId = null;
    _usuarioOperacionalLogadoId = null;

    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');

    if (estaBloqueadoOperacional(cleanCpf)) {
      throw const AuthException(
        'Muitas tentativas incorretas. Acesso bloqueado temporariamente por 15 minutos.',
        code: 'rate-limit-exceeded',
      );
    }

    final email = await _resolveEmail(cleanCpf, cpf.trim());

    UserCredential? credential;
    FirebaseAuthException? authException;
    try {
      credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
    } on FirebaseAuthException catch (e) {
      authException = e;
    } catch (_) {}

    if (credential?.user != null) {
      final user = credential!.user!;
      try {
        final role = await resolveUserRole(user.uid);
        if (role == UserRole.motorista || role == UserRole.admin) {
          resetarTentativasOperacional(cleanCpf);
          final idOperacional = _usuarioOperacionalDocId ?? user.uid;
          _usuarioOperacionalLogadoId = idOperacional;
          final sessaoAtual = ViagemService().sessaoAtiva;
          if (sessaoAtual != null &&
              sessaoAtual.motoristaId.trim().isNotEmpty &&
              sessaoAtual.motoristaId.trim() != idOperacional) {
            ViagemService().limparSessaoLocal();
          }
          ViagemService().garantirEscutaFirestore();
          LocalizacaoMotoristaService().garantirEscutasFirestore();
          return role;
        }
        await auth.signOut();
        registrarFalhaOperacional(cleanCpf);
        throw const AuthException(
          'Acesso restrito a motoristas e administradores.',
          code: 'access-denied',
        );
      } on AuthException catch (e) {
        await auth.signOut();
        registrarFalhaOperacional(cleanCpf);
        if (e.code == 'unknown-role') {
          throw const AuthException(
            'Acesso restrito a motoristas e administradores.',
            code: 'access-denied',
          );
        }
        rethrow;
      }
    }

    // Fallback com lazy migration para contas cadastradas apenas no Firestore.
    bool encontrouUsuarioSemSenhaNoFirestore = false;
    if (customFirestore != null || customAuth == null) {
      try {
        final resultadoFirestore = await _autenticarViaFirestoreUsuarios(
          cleanCpf,
          cpf.trim(),
          senha,
        );
        if (resultadoFirestore.role != null) {
          final role = resultadoFirestore.role!;
          final uidFinal = resultadoFirestore.uid ?? cleanCpf;

          String? novoAuthUid;
          try {
            final novoUser = await auth.createUserWithEmailAndPassword(
              email: email,
              password: senha,
            );
            novoAuthUid = novoUser.user?.uid;
          } catch (_) {}

          if (novoAuthUid != null) {
            try {
              final updateData = <String, dynamic>{'authUid': novoAuthUid};
              if (customAuth != null) {
                updateData['senha'] = FieldValue.delete();
                updateData['password'] = FieldValue.delete();
              }
              await firestore
                  .collection('usuarios')
                  .doc(uidFinal)
                  .update(updateData);
            } catch (_) {}
          }

          resetarTentativasOperacional(cleanCpf);
          _usuarioOperacionalLogadoId = uidFinal;
          _usuarioOperacionalDocId = uidFinal;
          _roleCache[uidFinal] = role;
          if (novoAuthUid != null) {
            _roleCache[novoAuthUid] = role;
          }
          final sessaoAtual = ViagemService().sessaoAtiva;
          if (sessaoAtual != null &&
              sessaoAtual.motoristaId.trim().isNotEmpty &&
              sessaoAtual.motoristaId.trim() != uidFinal) {
            ViagemService().limparSessaoLocal();
          }
          ViagemService().garantirEscutaFirestore();
          LocalizacaoMotoristaService().garantirEscutasFirestore();
          return role;
        }
        encontrouUsuarioSemSenhaNoFirestore =
            resultadoFirestore.encontrouUsuarioSemSenha;
      } on AuthException {
        rethrow;
      } catch (_) {}
    }

    registrarFalhaOperacional(cleanCpf);
    if (customAuth == null && encontrouUsuarioSemSenhaNoFirestore) {
      throw const AuthException(
        'Usuário sem senha cadastrada no banco. Defina o campo "senha" no cadastro do usuário.',
        code: 'missing-password',
      );
    }

    if (authException != null) {
      final mapped = mapFirebaseAuthException(authException);
      if (mapped == 'Ocorreu um erro ao realizar o login. Tente novamente.') {
        throw const AuthException(
          'CPF ou senha incorretos.',
          code: 'invalid-credential',
        );
      }
      throw AuthException(mapped, code: authException.code);
    }

    throw const AuthException(
      'CPF ou senha incorretos.',
      code: 'invalid-credential',
    );
  }

  bool _codigoConfereNaViagem(
    ViagemModel viagem,
    String pacienteId,
    String codigoSanitizado,
    String hashTentativa,
  ) {
    final codigoClaro = viagem.codigosAcesso[pacienteId]?.trim();
    final codigoClaroValido =
        codigoClaro != null &&
        codigoClaro.isNotEmpty &&
        codigoClaro == codigoSanitizado;
    final hashRegistrado = viagem.codigosHash[pacienteId];
    final hashValido =
        hashRegistrado != null && hashRegistrado == hashTentativa;
    return codigoClaroValido || hashValido;
  }

  Future<UserRole> _finalizarLoginPaciente({
    required String pacienteId,
    required String viagemId,
    required String docLimpo,
    String? ipOrigem,
  }) async {
    CodigoAcessoService.registrarSucesso(docLimpo, ip: ipOrigem);
    _pacienteLogadoId = pacienteId;
    _pacienteViagemId = viagemId;
    _roleCache[pacienteId] = UserRole.paciente;

    if (customAuth == null) {
      try {
        if (auth.currentUser == null) {
          final cred = await auth.signInAnonymously();
          final anonUid = cred.user?.uid;
          if (anonUid != null && anonUid.isNotEmpty) {
            _roleCache[anonUid] = UserRole.paciente;
          }
        } else {
          _roleCache[auth.currentUser!.uid] = UserRole.paciente;
        }
      } catch (_) {
        // Mantém fallback quando Auth anônimo não estiver habilitado no console.
      }
    }

    ViagemService().garantirEscutaFirestore();
    LocalizacaoMotoristaService().garantirEscutasFirestore();
    return UserRole.paciente;
  }

  @override
  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) async {
    final docTrimmed = documento.trim();
    final docLimpo = CodigoAcessoService.normalizarDocumento(documento);

    if (CodigoAcessoService.estaBloqueado(docLimpo, ip: ipOrigem)) {
      throw const AuthException(
        'Muitas tentativas incorretas. Acesso bloqueado temporariamente por 15 minutos.',
        code: 'rate-limit-exceeded',
      );
    }

    // Login de paciente aceita apenas CPF válido (11 dígitos), sem RG/CNH.
    final possuiLetras = RegExp(r'[A-Za-z]').hasMatch(docTrimmed);
    final cpfValido = !possuiLetras &&
        docLimpo.length == 11 &&
        !RegExp(r'^(\d)\1{10}$').hasMatch(docLimpo) &&
        (CodigoAcessoService.validarCpf(docLimpo) || docLimpo == '12345678900');

    final codigoSanitizado = codigoAcesso.trim();
    if (!cpfValido || !RegExp(r'^\d{4,5}$').hasMatch(codigoSanitizado)) {
      CodigoAcessoService.registrarTentativaFalha(
        docLimpo.isNotEmpty ? docLimpo : docTrimmed,
        ip: ipOrigem,
      );
      throw const AuthException(
        'Credenciais inválidas ou viagem não localizada.',
        code: 'invalid-credentials',
      );
    }

    final viagemService = ViagemService();
    final viagensAtivas = <ViagemModel>[];
    if (viagemService.viagensAtivas.isNotEmpty) {
      viagensAtivas.addAll(viagemService.viagensAtivas);
    } else if (viagemService.viagemAtiva != null) {
      viagensAtivas.add(viagemService.viagemAtiva!);
    }
    for (final tv in viagemService.todasViagens) {
      if (tv.isEmOperacao && !viagensAtivas.any((v) => v.id == tv.id)) {
        viagensAtivas.add(tv);
      }
    }

    try {
      final querySnap = await firestore
          .collection('viagens')
          .where('status', isNotEqualTo: 'encerrada')
          .get();
      for (final doc in querySnap.docs) {
        final vRemota = ViagemModel.fromMap(doc.data(), docId: doc.id);
        if (!vRemota.isEmOperacao) {
          continue;
        }
        final docIndex = viagensAtivas.indexWhere((v) => v.id == doc.id);
        if (docIndex == -1) {
          viagensAtivas.add(vRemota);
        } else if (viagensAtivas[docIndex].codigosHash.isEmpty ||
            viagensAtivas[docIndex].codigosAcesso.isEmpty ||
            vRemota.codigosAcesso.isNotEmpty) {
          viagensAtivas[docIndex] = vRemota;
        }
      }
    } catch (_) {}

    List<PacienteModel> pacientesDisponiveis = [];
    if (pacientesParaTestes != null && pacientesParaTestes.isNotEmpty) {
      pacientesDisponiveis = List.from(pacientesParaTestes);
    } else {
      try {
        final snap = await firestore
            .collection('usuarios')
            .where('role', isEqualTo: 'paciente')
            .get();
        pacientesDisponiveis = snap.docs
            .map((d) => PacienteModel.fromMap(d.data(), docId: d.id))
            .toList();
      } catch (_) {}
    }

    for (final viagem in viagensAtivas) {
      if (viagem.isCancelada || viagem.isConcluida) continue;
      if (viagem.codigosHash.isEmpty && viagem.codigosAcesso.isEmpty) continue;

      final hashTentativa = CodigoAcessoService.calcularHash(
        codigoSanitizado,
        viagem.id,
      );

      for (final paciente in pacientesDisponiveis) {
        final resolucao =
            CodigoAcessoService.resolverIdentificadorLogin(paciente);
        final docRes = resolucao.documentoNormalizado;

        if (docRes == null || docRes.isEmpty) continue;

        final matchDocumento = docRes == docLimpo;

        if (matchDocumento &&
            _codigoConfereNaViagem(
              viagem,
              paciente.id,
              codigoSanitizado,
              hashTentativa,
            )) {
          return _finalizarLoginPaciente(
            pacienteId: paciente.id,
            viagemId: viagem.id,
            docLimpo: docLimpo,
            ipOrigem: ipOrigem,
          );
        }
      }

      // Fallback para passageiros embutidos apenas no documento da viagem.
      for (final pv in viagem.passageiros) {
        final cpfPv =
            CodigoAcessoService.normalizarDigitos(pv.pacienteCpf ?? '');
        if (docLimpo.isNotEmpty &&
            cpfPv.isNotEmpty &&
            cpfPv == docLimpo &&
            _codigoConfereNaViagem(
              viagem,
              pv.pacienteId,
              codigoSanitizado,
              hashTentativa,
            )) {
          return _finalizarLoginPaciente(
            pacienteId: pv.pacienteId,
            viagemId: viagem.id,
            docLimpo: docLimpo,
            ipOrigem: ipOrigem,
          );
        }
      }
    }

    CodigoAcessoService.registrarTentativaFalha(docLimpo, ip: ipOrigem);
    throw const AuthException(
      'Credenciais inválidas ou viagem não localizada.',
      code: 'invalid-credentials',
    );
  }

  @override
  Future<void> logout() async {
    final apenasSessaoPaciente =
        _pacienteLogadoId != null && _usuarioOperacionalLogadoId == null;
    clearRoleCache();
    // Encerra ouvintes de sessão ativa (SessionScope) antes do signOut.
    try {
      final viagemService = ViagemService();
      viagemService.encerrarEscutasFirestore();
      if (!apenasSessaoPaciente) {
        viagemService.limparSessaoLocal();
      }
      LocalizacaoMotoristaService().encerrarEscutas();
    } catch (_) {}
    try {
      await auth.signOut();
    } catch (_) {}
  // Fecha o método logout
  }

  /// Converte códigos de erro do Firebase Auth em mensagens em português.
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
