// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/auth_service.dart
// Camada: Serviços / Autenticação e Controle de Acesso (RBAC)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa a camada completa de autenticação do sistema TransSaúde,
// fornecendo o contrato abstrato AuthService, a exceção de domínio padronizada
// AuthException e a implementação concreta FirebaseAuthService baseada no
// Firebase Authentication e Cloud Firestore. Inclui resolução de CPF para
// e-mail institucional, cache compartilhado de perfis (UserRole) em memória,
// tradução amigável de erros e controle de acesso restrito (RBAC).
//
// PARA QUE SERVE NO PROJETO:
// É o núcleo de segurança da aplicação (PR #59/#60): gerencia a sessão ativa,
// traduz o CPF digitado no login para as credenciais oficiais, valida se o
// usuário possui perfil permitido (Administrador ou Motorista) e expõe streams
// e caches consumidos pela guarda de rotas e pela máquina de estados visual.
//
// ONDE É USADO NO PROJETO:
// - lib/routes/route_guard.dart (validação e bloqueio de rotas não autorizadas)
// - lib/screens/auth_gate.dart (escuta da stream authStateChanges e despacho de telas)
// - lib/screens/login_screen.dart (submissão de formulário de login)
// - lib/motorista.dart e lib/screens/admin_placeholder_screen.dart (logout da sessão)
// - test/services/auth_service_test.dart e test/screens/auth_gate_test.dart
//
// DE ONDE RECEBE DADOS:
// SDKs 'firebase_auth' (sessão e tokens) e 'cloud_firestore' (coleção 'usuarios').
//
// O QUE EXPORTA / EXPÕE:
// - class AuthException implements Exception
// - abstract class AuthService
//   * Future<UserRole> login(String cpf, String senha)
//   * Future<void> logout()
//   * Stream<String?> get authStateChanges
//   * Future<UserRole> resolveUserRole(String uid, {bool forceRefresh})
//   * UserRole? getCachedRole(String uid)
//   * void clearRoleCache()
//   * String? get currentUserId
// - class FirebaseAuthService implements AuthService
//   * static String mapFirebaseAuthException(FirebaseAuthException e)
//
// ORIGEM HISTÓRICA:
// Implementado especificamente para a arquitetura de autenticação da PR #59
// e corrigido na PR #60 (cache compartilhado no RouteGuard).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'firebase_auth' e 'cloud_firestore'. Realiza chamadas de rede
// assíncronas aos servidores do Google Firebase e mantém estado de cache estático.
// ============================================================================

// ----------------------------------------------------------------------------
// IMPORTAÇÃO DE BIBLIOTECAS E PACOTES:
// - dart:async: Utilizada para Streams, StreamController e TimeoutException.
// - cloud_firestore: Leitura assíncrona de documentos de usuários no banco NoSQL.
// - firebase_auth: Autenticação de credenciais, gestão de sessão e listeners de estado.
// - user_role.dart: Enumeração com os perfis de acesso do sistema (admin, motorista, paciente).
// ----------------------------------------------------------------------------
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/paciente_model.dart';
import '../models/user_role.dart';
import '../models/viagem_model.dart';
import 'codigo_acesso_service.dart';
import 'localizacao_motorista_service.dart';
import 'viagem_service.dart';

// Linha em branco separadora entre imports e a classe de exceção
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
/// Exceção de domínio padronizada para autenticação e autorização
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE EXCEÇÃO: AuthException
// - O que a instrução faz: Declara a exceção especializada de domínio para falhas de login e permissão.
// - O que é o elemento: Classe de exceção que implementa a interface nativa 'Exception' do Dart SDK.
// - Papel no sistema: Padroniza as mensagens de erro em português para exibição direta ao usuário final,
//   isolando a interface de mensagens técnicas crípticas vindas de APIs externas.
// ----------------------------------------------------------------------------
class AuthException implements Exception {
  // --------------------------------------------------------------------------
  // ATRIBUTO: message
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Mensagem de erro em linguagem natural e amigável para exibição em SnackBars ou alertas.
  // --------------------------------------------------------------------------
  final String message;

  // --------------------------------------------------------------------------
  // ATRIBUTO: code
  // - O que é: Campo imutável opcional/anulável ('String?').
  // - Papel: Código identificador canônico da falha (ex.: 'permission-denied', 'access-denied').
  // --------------------------------------------------------------------------
  final String? code;

  // Linha em branco separadora entre atributos e construtor

  // --------------------------------------------------------------------------
  // CONSTRUTOR CONSTANTE: AuthException
  // - O que faz: Inicializa uma instância imutável de AuthException.
  // - Parâmetros: 'this.message' posicional obrigatório e 'this.code' nomeado opcional.
  // --------------------------------------------------------------------------
  const AuthException(this.message, {this.code});

  // Linha em branco separadora entre construtor e toString

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO MÉTODO: toString
  // - O que faz: Retorna diretamente o texto amigável da mensagem em vez do nome da classe.
  // --------------------------------------------------------------------------
  @override
  // Retorna o conteúdo textual da propriedade message
  String toString() => message;

// Fecha a declaração da classe AuthException
}

// Linha em branco separadora entre AuthException e a interface abstrata
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
/// Interface abstrata para injeção de dependência e testes
// ----------------------------------------------------------------------------
// DECLARAÇÃO DO CONTRATO ABSTRATO: AuthService
// - O que a instrução faz: Declara a interface formal para serviços de autenticação do sistema.
// - O que é o elemento: Classe abstrata pura ('abstract class') para inversão de dependência (DIP).
// - Papel no sistema: Permite substituir a implementação real por mocks ou fakes em testes unitários.
// ----------------------------------------------------------------------------
abstract class AuthService {
  // --------------------------------------------------------------------------
  // ASSINATURA DE MÉTODO: login
  // - O que faz: Autentica o usuário a partir de CPF e senha e retorna seu perfil (UserRole).
  // --------------------------------------------------------------------------
  Future<UserRole> login(String cpf, String senha);

  // --------------------------------------------------------------------------
  // ASSINATURA DE MÉTODO: loginPacienteComCodigo (Issue #65)
  // - O que faz: Autentica o paciente ou acompanhante através de CPF/documento
  //   e código de acesso dinâmico de 4 a 5 dígitos gerado no embarque.
  // --------------------------------------------------------------------------
  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) =>
      throw UnimplementedError('loginPacienteComCodigo não implementado');

  // --------------------------------------------------------------------------
  // ASSINATURA DE MÉTODO: logout
  // - O que faz: Encerra a sessão ativa e limpa dados de autenticação em memória.
  // --------------------------------------------------------------------------
  Future<void> logout();

  // Linha em branco separadora entre métodos e stream de estado
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Stream reativa de mudanças no estado de autenticação (emite UID do usuário ou null se deslogado)
  // ----------------------------------------------------------------------------
  // GETTER DE STREAM: authStateChanges
  // - O que faz: Emite eventos reativos de UID sempre que o usuário efetuar login ou logout.
  // ----------------------------------------------------------------------------
  Stream<String?> get authStateChanges => const Stream.empty();

  // Linha em branco separadora entre streams e métodos de resolução de papel
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Resolve o UserRole de um usuário autenticado a partir de seu UID
  // ----------------------------------------------------------------------------
  // MÉTODO: resolveUserRole
  // - O que faz: Consulta o perfil do usuário pelo UID, consultando cache ou banco de dados.
  // ----------------------------------------------------------------------------
  Future<UserRole> resolveUserRole(String uid, {bool forceRefresh = false}) =>
      // Lança erro caso a implementação concreta não forneça este método
      throw UnimplementedError('resolveUserRole não implementado');

  // Linha em branco separadora entre resolveUserRole e getCachedRole
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Retorna o role em cache para o UID informado, se existir
  // ----------------------------------------------------------------------------
  // MÉTODO: getCachedRole
  // - O que faz: Consulta síncrona em memória para evitar chamadas redundantes de rede.
  // ----------------------------------------------------------------------------
  UserRole? getCachedRole(String uid) => null;

  // Linha em branco separadora entre getCachedRole e clearRoleCache
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Limpa o cache de roles resolvidos
  // ----------------------------------------------------------------------------
  // MÉTODO: clearRoleCache
  // - O que faz: Purga as entradas mantidas no cache de papéis.
  // ----------------------------------------------------------------------------
  void clearRoleCache() {}

  String? get currentUserId => null;

// Fecha o contrato da interface abstrata AuthService
}

// Linha em branco separadora entre o contrato e a implementação oficial
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
/// Implementação oficial do AuthService baseada em Firebase Authentication e Cloud Firestore
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE CONCRETA: FirebaseAuthService
// - O que a instrução faz: Implementa as operações de autenticação reais consumindo os SDKs do Firebase.
// - O que é o elemento: Classe de serviço concreta que implementa o contrato 'AuthService'.
// ----------------------------------------------------------------------------
class FirebaseAuthService implements AuthService {
  // --------------------------------------------------------------------------
  // ATRIBUTO: customAuth
  // - O que é: Instância opcional de 'FirebaseAuth' para permitir injeção de dependência em testes.
  // --------------------------------------------------------------------------
  final FirebaseAuth? customAuth;

  // --------------------------------------------------------------------------
  // ATRIBUTO: customFirestore
  // - O que é: Instância opcional de 'FirebaseFirestore' para injeção de dependência.
  // --------------------------------------------------------------------------
  final FirebaseFirestore? customFirestore;

  // --------------------------------------------------------------------------
  // ATRIBUTO: userDocFetcher
  // - O que é: Função callback opcional que intercepta a busca de dados de usuário por UID.
  // --------------------------------------------------------------------------
  final Future<Map<String, dynamic>?> Function(String uid)? userDocFetcher;

  // --------------------------------------------------------------------------
  // ATRIBUTO: cpfEmailResolver
  // - O que é: Função callback opcional que intercepta a resolução de CPF para e-mail em testes.
  // --------------------------------------------------------------------------
  final Future<String?> Function(String cleanCpf)? cpfEmailResolver;

  // Linha em branco separadora entre atributos de instância e cache estático
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Cache compartilhado em memória dos perfis resolvidos por UID.
  // ----------------------------------------------------------------------------
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Sendo estático, instâncias criadas dinamicamente pelo RouteGuard ou widgets
  // ----------------------------------------------------------------------------
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// compartilham o perfil autenticado na sessão sem redundância de requisições.
  // ----------------------------------------------------------------------------
  // ATRIBUTO ESTÁTICO: _roleCache
  // - O que é: Dicionário Map em memória persistido no ciclo de vida do aplicativo.
  // - Papel: Evita refazer leituras no Firestore a cada transição de rota pelo RouteGuard.
  // ----------------------------------------------------------------------------
  static final Map<String, UserRole> _roleCache = {};

  // Identificador da sessão ativa de paciente/acompanhante autenticado via código temporário
  static String? _pacienteLogadoId;

  // Identificador da sessão ativa de usuário operacional (motorista/admin) em homologação
  static String? _usuarioOperacionalLogadoId;

  // Identificador do documento do usuário na coleção 'usuarios' do Firestore (pode diferir do authUid)
  static String? _usuarioOperacionalDocId;

  // Estado de 'emViagem' do motorista autenticado lido do Firestore
  static bool? motoristaEmViagemStatic;

  // Controle de rate limiting e bloqueio contra ataques de força bruta (FASE 2)
  static final Map<String, int> _tentativasLoginOperacional = {};
  static final Map<String, DateTime> _bloqueioAteOperacional = {};

  /// Verifica se o CPF operacional está temporariamente bloqueado por exceder 5 tentativas falhas
  static bool estaBloqueadoOperacional(String cpf) {
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    final expira = _bloqueioAteOperacional[clean];
    if (expira != null) {
      if (DateTime.now().isBefore(expira)) {
        return true;
      } else {
        _bloqueioAteOperacional.remove(clean);
        _tentativasLoginOperacional.remove(clean);
      }
    }
    return false;
  }

  /// Registra uma tentativa falha de autenticação para o CPF operacional
  static void registrarFalhaOperacional(String cpf) {
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    final tentativas = (_tentativasLoginOperacional[clean] ?? 0) + 1;
    _tentativasLoginOperacional[clean] = tentativas;
    if (tentativas >= 5) {
      _bloqueioAteOperacional[clean] =
          DateTime.now().add(const Duration(minutes: 15));
    }
  }

  /// Reseta o contador de tentativas após sucesso na autenticação
  static void resetarTentativasOperacional(String cpf) {
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    _tentativasLoginOperacional.remove(clean);
    _bloqueioAteOperacional.remove(clean);
  }

  /// Utilitário de testes para purgar bloqueios e tentativas
  static void resetarRateLimitParaTestes() {
    _tentativasLoginOperacional.clear();
    _bloqueioAteOperacional.clear();
  }

  // Linha em branco separadora entre atributos e construtor

  // --------------------------------------------------------------------------
  // CONSTRUTOR PADRÃO: FirebaseAuthService
  // - O que faz: Inicializa o serviço permitindo injeção de dependências para testes ou produção.
  // --------------------------------------------------------------------------
  FirebaseAuthService({
    // Parâmetro opcional para injeção de FirebaseAuth
    FirebaseAuth? auth,
    // Parâmetro opcional para injeção de FirebaseFirestore
    FirebaseFirestore? firestore,
    // Parâmetro opcional para callback customizado de fetch de dados de usuário
    this.userDocFetcher,
    // Parâmetro opcional para callback customizado de resolução de CPF em e-mail
    this.cpfEmailResolver,
  // Inicializadores de campo para propriedades imutáveis
  }) : customAuth = auth,
       customFirestore = firestore;

  // Linha em branco separadora entre construtor e getters de instâncias

  // --------------------------------------------------------------------------
  // GETTER: auth
  // - Retorna a instância injetada de FirebaseAuth ou o singleton oficial 'FirebaseAuth.instance'.
  // --------------------------------------------------------------------------
  FirebaseAuth get auth => customAuth ?? FirebaseAuth.instance;

  // --------------------------------------------------------------------------
  // GETTER: firestore
  // - Retorna a instância injetada de FirebaseFirestore ou o singleton 'FirebaseFirestore.instance'.
  // --------------------------------------------------------------------------
  FirebaseFirestore get firestore =>
      customFirestore ?? FirebaseFirestore.instance;

  // Linha em branco separadora entre getters e membros sobrescritos

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO GETTER: authStateChanges
  // - O que faz: Transforma a stream de usuários do Firebase em uma stream reativa de UIDs.
  // --------------------------------------------------------------------------
  @override
  // Converte cada evento de User emitindo apenas sua String de identificador único (uid)
  Stream<String?> get authStateChanges => auth
      .authStateChanges()
      .map((user) => user?.uid ?? _usuarioOperacionalLogadoId ?? _pacienteLogadoId);

  // Linha em branco separadora entre membros da interface

  String? get currentDocId => _usuarioOperacionalDocId ?? currentUserId;

  bool? get motoristaEmViagem => motoristaEmViagemStatic;

  // Linha em branco separadora entre membros da interface

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO GETTER: currentUserId
  // - Retorna o UID do usuário atualmente autenticado no FirebaseAuth ou o ID do paciente logado.
  // --------------------------------------------------------------------------
  @override
  // Acessa _pacienteLogadoId, _usuarioOperacionalLogadoId ou currentUser.uid na instância de FirebaseAuth
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

  // Linha em branco separadora entre membros da interface

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO MÉTODO: getCachedRole
  // - O que faz: Recupera de forma síncrona o UserRole associado ao UID informado no cache em memória.
  // --------------------------------------------------------------------------
  @override
  // Consulta a chave UID no mapa estático de cache
  UserRole? getCachedRole(String uid) => _roleCache[uid];

  // Linha em branco separadora entre membros da interface

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO MÉTODO: clearRoleCache
  // - O que faz: Remove todos os registros de perfis mantidos no cache estático.
  // --------------------------------------------------------------------------
  @override
  // Esvazia o mapa estático de cache e reseta a sessão do paciente
  void clearRoleCache() {
    _pacienteLogadoId = null;
    _usuarioOperacionalLogadoId = null;
    _usuarioOperacionalDocId = null;
    motoristaEmViagemStatic = null;
    _roleCache.clear();
  }

  // Linha em branco separadora entre métodos de cache e resolução de e-mail

  // --------------------------------------------------------------------------
  // MÉTODO PRIVADO: _resolveEmail
  // - O que faz: Descobre o endereço de e-mail associado ao CPF informado para autenticação.
  // - Estratégia de resolução:
  //   1) Invoca 'cpfEmailResolver' customizado se fornecido;
  //   2) Consulta na coleção 'usuarios' do Firestore onde cpf == cleanCpf ou rawCpf;
  //   3) Aplica fallback sintético com o domínio oficial '@transsaude.sp.gov.br'.
  // --------------------------------------------------------------------------
  Future<String> _resolveEmail(String cleanCpf, String rawCpf) async {
    // Guarda referência local para o resolvedor customizado se tiver sido injetado
    final resolver = cpfEmailResolver;
    // Se existir resolvedor customizado, invoca para resolver
    if (resolver != null) {
      // Aguarda o retorno da resolução customizada
      final resolved = await resolver(cleanCpf);
      // Se retornou um e-mail válido não vazio, retorna-o
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      // Fecha validação do retorno resolvido
      }
    // Fecha checagem do resolvedor injetado
    }

    // Linha em branco separadora entre resolver customizado e consulta ao Firestore
    // Bloco de tentativa para consultar o e-mail cadastrado na coleção 'usuarios' do Firestore
    try {
      // Executa consulta buscando documentos onde o campo 'cpf' coincide com cleanCpf ou rawCpf
      final query = await firestore
          .collection('usuarios')
          .where('cpf', whereIn: [cleanCpf, rawCpf])
          .limit(1)
          .get();

      // Verifica se a consulta retornou ao menos um documento correspondente
      if (query.docs.isNotEmpty) {
        // Extrai o campo 'email' do primeiro documento encontrado
        final email = query.docs.first.data()['email']?.toString();
        // Se o e-mail existir e não for vazio, retorna o endereço oficial cadastrado
        if (email != null && email.isNotEmpty) {
          return email;
        // Fecha validação do e-mail
        }
      // Fecha verificação de documento encontrado
      }
    // Captura qualquer exceção de rede ou permissão sem propagar erro
    } catch (_) {}

    // Linha em branco separadora entre consulta no Firestore e fallback padrão
    // Retorna o e-mail gerado sinteticamente com o domínio municipal oficial
    return '$cleanCpf@transsaude.sp.gov.br';
  // Fecha o método _resolveEmail
  }

  // Linha em branco separadora entre _resolveEmail e _fetchUserData

  // --------------------------------------------------------------------------
  // MÉTODO PRIVADO: _fetchUserData
  // - O que faz: Recupera os dados do documento do usuário na coleção 'usuarios' pelo seu UID.
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    // Guarda referência para o fetcher injetado se houver
    final fetcher = userDocFetcher;
    // Caso tenha sido fornecido um fetcher de teste, invoca-o prioritariamente
    if (fetcher != null) {
      return fetcher(uid);
    // Fecha checagem do fetcher
    }
    // Busca o documento correspondente na coleção 'usuarios' do Firestore
    final doc = await firestore.collection('usuarios').doc(uid).get();
    // Se o documento existir no banco, retorna os dados
    if (doc.exists) {
      final data = doc.data();
      _usuarioOperacionalDocId = doc.id;
      if (data != null && data['role'] == 'motorista') {
        motoristaEmViagemStatic = data['emViagem'] == true || data['emViagem'] == 'true';
      }
      return data;
    }
    // Fallback após lazy migration: busca por authUid associado
    try {
      final queryAuth = await firestore
          .collection('usuarios')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (queryAuth.docs.isNotEmpty) {
        final d = queryAuth.docs.first;
        _usuarioOperacionalDocId = d.id;
        final data = d.data();
        if (data['role'] == 'motorista') {
          motoristaEmViagemStatic = data['emViagem'] == true || data['emViagem'] == 'true';
        }
        return data;
      }
    } catch (_) {}
    // Retorna nulo se o documento não for encontrado
    return null;
  // Fecha o método _fetchUserData
  }

  // Linha em branco separadora entre _fetchUserData e resolveUserRole

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO MÉTODO: resolveUserRole
  // - O que faz: Determina com segurança o UserRole associado ao UID autenticado.
  // - Tratamento de falhas: Traduz exceções de permissão e falhas de rede para AuthException.
  // --------------------------------------------------------------------------
  @override
  // Método assíncrono para identificar o UserRole associado ao UID informado
  Future<UserRole> resolveUserRole(
    String uid, {
    bool forceRefresh = false,
  // Abre o corpo do método resolveUserRole
  }) async {
    // Se forceRefresh não foi solicitado e já existe role em cache para o UID, retorna do cache
    if (!forceRefresh && _roleCache.containsKey(uid)) {
      return _roleCache[uid]!;
    // Fecha checagem de cache
    }

    // Linha em branco separadora entre cache e busca de dados
    // Declara variável para receber os dados retornados do Firestore
    Map<String, dynamic>? data;
    // Bloco de tratamento de erros ao buscar dados do usuário
    try {
      // Executa a busca assíncrona dos dados do usuário
      data = await _fetchUserData(uid);
    // Captura exceções específicas da plataforma Firebase
    } on FirebaseException catch (e) {
      // Trata erro de permissão negada de leitura
      if (e.code == 'permission-denied') {
        throw const AuthException(
          'Permissão negada ao consultar perfil de usuário.',
          code: 'permission-denied',
        );
      // Fecha verificação de permission-denied
      }
      // Trata erro de indisponibilidade de serviço ou falha de rede
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        throw const AuthException(
          'Falha temporária de conexão com o servidor.',
          code: 'unavailable',
        );
      // Fecha verificação de indisponibilidade
      }
      // Lança AuthException genérica com o código original do Firebase
      throw AuthException(
        'Erro ao consultar perfil de acesso: ${e.message}',
        code: e.code,
      );
    // Captura estouro de tempo limite
    } on TimeoutException {
      // Lança AuthException reportando tempo limite excedido
      throw const AuthException(
        'Tempo limite excedido ao consultar perfil.',
        code: 'unavailable',
      );
    // Captura qualquer outro erro inesperado
    } catch (e) {
      // Se já for uma AuthException, propaga imediatamente
      if (e is AuthException) rethrow;
      // Converte mensagem de erro para minúsculas para análise heurística
      final msg = e.toString().toLowerCase();
      // Checa termos indicativos de problemas de infraestrutura de rede
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('timeout') ||
          msg.contains('unavailable')) {
        // Lança exceção de falha temporária de conexão
        throw const AuthException(
          'Falha temporária de conexão com o servidor.',
          code: 'unavailable',
        );
      // Fecha checagem de erros de conexão
      }
      // Lança exceção genérica orientando tentar novamente
      throw AuthException(
        'Erro ao consultar perfil de acesso. Tente novamente.',
      );
    // Fecha bloco catch
    }

    // Linha em branco separadora entre captura de erros e validação do documento
    // Verifica se os dados retornados do usuário são nulos
    if (data == null) {
      // Lança erro reportando usuário não cadastrado
      throw const AuthException(
        'Usuário não cadastrado ou sem permissão de acesso.',
        code: 'user-not-registered',
      );
    // Fecha checagem de dados nulos
    }

    // Linha em branco separadora entre dados nulos e validação do campo role
    // Extrai o campo bruto 'role' do documento
    final roleRaw = data['role'];
    // Verifica se o campo 'role' é nulo ou string em branco
    if (roleRaw == null || roleRaw.toString().trim().isEmpty) {
      // Lança exceção reportando perfil ausente
      throw const AuthException(
        'Perfil do usuário ausente no cadastro.',
        code: 'invalid-profile',
      );
    // Fecha checagem de perfil ausente
    }

    // Linha em branco separadora entre validação e parse do role
    // Converte e remove espaços do valor de role
    final roleStr = roleRaw.toString().trim();
    // Declara variável tipada para armazenar o UserRole resolvido
    final UserRole role;
    // Compara se o papel é de motorista
    if (roleStr == 'motorista') {
      role = UserRole.motorista;
    // Compara se o papel é de administrador
    } else if (roleStr == 'admin' || roleStr == 'administrador') {
      role = UserRole.admin;
    // Compara se o papel é de paciente
    } else if (roleStr == 'paciente') {
      role = UserRole.paciente;
    // Caso não seja nenhum papel reconhecido, lança exceção de role desconhecido
    } else {
      throw AuthException(
        'Perfil de usuário desconhecido ou inválido: $roleStr',
        code: 'unknown-role',
      );
    // Fecha else de papel desconhecido
    }

    // Linha em branco separadora entre atribuição do role e salvamento no cache
    // Salva o papel no cache estático da sessão
    _roleCache[uid] = role;
    // Retorna o perfil resolvido
    return role;
  // Fecha o método resolveUserRole
  }

  // Linha em branco separadora entre resolveUserRole e login

  // --------------------------------------------------------------------------
  // MÉTODO PRIVADO: _autenticarViaFirestoreUsuarios
  // - O que faz: Valida CPF e senha diretamente contra a coleção 'usuarios'
  //   do Cloud Firestore quando o registro possui o campo 'senha' (padrão
  //   utilizado no banco 'trans-saude3'), sincronizando qualquer alteração
  //   manual ou via sistema imediatamente.
  // --------------------------------------------------------------------------
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
      final ativo = dados['ativo'];
      final statusStr = dados['status']?.toString().toLowerCase().trim();
      final situacaoStr = dados['situacao']?.toString().toLowerCase().trim();
      final isInativo = ativo == false ||
          ativo == 'false' ||
          statusStr == 'inativo' ||
          statusStr == 'excluido' ||
          situacaoStr == 'inativo' ||
          situacaoStr == 'excluido';

      if (isInativo) continue;

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
      if (roleStr == 'motorista') {
        resetarTentativasOperacional(cleanCpf);
        _usuarioOperacionalLogadoId = uidFinal;
        _roleCache[uidFinal] = UserRole.motorista;
        return (role: UserRole.motorista, uid: uidFinal, encontrouUsuarioSemSenha: false);
      } else if (roleStr == 'admin' || roleStr == 'administrador') {
        resetarTentativasOperacional(cleanCpf);
        _usuarioOperacionalLogadoId = uidFinal;
        _roleCache[uidFinal] = UserRole.admin;
        return (role: UserRole.admin, uid: uidFinal, encontrouUsuarioSemSenha: false);
      } else {
        registrarFalhaOperacional(cleanCpf);
        throw const AuthException(
          'Acesso restrito a motoristas e administradores.',
          code: 'access-denied',
        );
      }
    }

    return (role: null, uid: null, encontrouUsuarioSemSenha: true);
  }

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO MÉTODO: login
  // - O que faz: Autentica o usuário por CPF e senha com lazy migration para FirebaseAuth.
  // - Regra de negócio: Apenas 'motorista' e 'admin' têm permissão de acesso a este módulo.
  // --------------------------------------------------------------------------
  @override
  Future<UserRole> login(String cpf, String senha) async {
    // 1. Reseta os IDs de sessão para evitar contaminação entre perfis
    _pacienteLogadoId = null;
    _usuarioOperacionalLogadoId = null;

    // Sanitiza o CPF removendo caracteres não numéricos
    final cleanCpf = cpf.replaceAll(RegExp(r'\D'), '');

    // 2. Proteção contra ataques de força bruta (Rate Limiting de 5 tentativas)
    if (estaBloqueadoOperacional(cleanCpf)) {
      throw const AuthException(
        'Muitas tentativas incorretas. Acesso bloqueado temporariamente por 15 minutos.',
        code: 'rate-limit-exceeded',
      );
    }

    // Resolve o e-mail correspondente ao CPF ($cleanCpf@transsaude.sp.gov.br)
    final email = await _resolveEmail(cleanCpf, cpf.trim());

    // 3. Tenta autenticar nativamente no Firebase Authentication
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

    // Se a autenticação nativa do Firebase Authentication teve sucesso
    if (credential?.user != null) {
      final user = credential!.user!;
      try {
        final role = await resolveUserRole(user.uid);
        if (role == UserRole.motorista) {
          resetarTentativasOperacional(cleanCpf);
          _usuarioOperacionalLogadoId = _usuarioOperacionalDocId ?? user.uid;
          return UserRole.motorista;
        } else if (role == UserRole.admin) {
          resetarTentativasOperacional(cleanCpf);
          _usuarioOperacionalLogadoId = _usuarioOperacionalDocId ?? user.uid;
          return UserRole.admin;
        } else {
          await auth.signOut();
          registrarFalhaOperacional(cleanCpf);
          throw const AuthException(
            'Acesso restrito a motoristas e administradores.',
            code: 'access-denied',
          );
        }
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

    // 4. Se o usuário ainda não existir no Auth (ou falhou nativamente), valida contra o Firestore (Lazy Migration)
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

          // Lazy Migration no Login:
          // Cria o usuário nativo no Firebase Authentication com credenciais oficiais criptografadas
          String? novoAuthUid;
          try {
            final novoUser = await auth.createUserWithEmailAndPassword(
              email: email,
              password: senha,
            );
            novoAuthUid = novoUser.user?.uid;
          } catch (_) {
            // Em testes ou ambientes sem Auth ativo, não interrompe o fluxo
          }

          // Apaga as chaves 'senha' e 'password' do documento em usuarios e associa authUid
          try {
            final updateData = <String, dynamic>{
              'senha': FieldValue.delete(),
              'password': FieldValue.delete(),
            };
            if (novoAuthUid != null) {
              updateData['authUid'] = novoAuthUid;
            }
            await firestore
                .collection('usuarios')
                .doc(uidFinal)
                .update(updateData);
          } catch (_) {}

          resetarTentativasOperacional(cleanCpf);
          _usuarioOperacionalLogadoId = uidFinal;
          _usuarioOperacionalDocId = uidFinal;
          _roleCache[uidFinal] = role;
          if (novoAuthUid != null) {
            _roleCache[novoAuthUid] = role;
          }
          return role;
        }
        encontrouUsuarioSemSenhaNoFirestore =
            resultadoFirestore.encontrouUsuarioSemSenha;
      } on AuthException {
        rethrow;
      } catch (_) {}
    }

    // 5. Se não autenticou nem no Auth nem no Firestore
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

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO MÉTODO: loginPacienteComCodigo (Issue #65)
  // - O que faz: Autentica o paciente ou acompanhante através de CPF/documento
  //   e código de acesso dinâmico de 4 a 5 dígitos gerado no embarque.
  // --------------------------------------------------------------------------
  @override
  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) async {
    // 1. Normalização do identificador (extração de dígitos ou sanitização alfanumérica)
    final docLimpo = CodigoAcessoService.normalizarDocumento(documento);

    // 2. Proteção contra força bruta (Rate Limiting por CPF e/ou IP)
    if (CodigoAcessoService.estaBloqueado(
      docLimpo,
      ip: ipOrigem,
    )) {
      throw const AuthException(
        'Muitas tentativas incorretas. Acesso bloqueado temporariamente por 15 minutos.',
        code: 'rate-limit-exceeded',
      );
    }

    // 3. Validação estrita do código de acesso: deve ter exatamente entre 4 e 5 dígitos numéricos
    final codigoSanitizado = codigoAcesso.trim();
    if (!RegExp(r'^\d{4,5}$').hasMatch(codigoSanitizado)) {
      CodigoAcessoService.registrarTentativaFalha(
        docLimpo,
        ip: ipOrigem,
      );
      throw const AuthException(
        'Credenciais inválidas ou viagem não localizada.',
        code: 'invalid-credentials',
      );
    }

    // 4. Varredura de viagens ativas e planejadas para validação do código/hash
    final viagemService = ViagemService();
    final viagensAtivas = <ViagemModel>[];
    if (viagemService.viagensAtivas.isNotEmpty) {
      viagensAtivas.addAll(viagemService.viagensAtivas);
    } else if (viagemService.viagemAtiva != null) {
      viagensAtivas.add(viagemService.viagemAtiva!);
    }
    for (final tv in viagemService.todasViagens) {
      if ((tv.isAtiva || tv.isPlanejada) &&
          !tv.isCancelada &&
          !tv.isConcluida &&
          !viagensAtivas.any((v) => v.id == tv.id)) {
        viagensAtivas.add(tv);
      }
    }

    // Busca remota no Firestore para viagens ativas ou planejadas (multi-dispositivo e homologação)
    try {
      final querySnap = await firestore
          .collection('viagens')
          .get();
      for (final doc in querySnap.docs) {
        final vRemota = ViagemModel.fromMap(doc.data(), docId: doc.id);
        if ((!vRemota.isAtiva && !vRemota.isPlanejada) ||
            vRemota.isCancelada ||
            vRemota.isConcluida) {
          continue;
        }
        final docIndex = viagensAtivas.indexWhere((v) => v.id == doc.id);
        if (docIndex == -1) {
          viagensAtivas.add(vRemota);
        } else {
          // Sincroniza se o Firestore possuir códigos/hashes mais completos ou editados manualmente
          if (viagensAtivas[docIndex].codigosHash.isEmpty ||
              viagensAtivas[docIndex].codigosAcesso.isEmpty ||
              vRemota.codigosAcesso.isNotEmpty) {
            viagensAtivas[docIndex] = vRemota;
          }
        }
      }
    } catch (_) {}

    // Carrega a base de pacientes ativos para conferência de documentos e acompanhantes
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

    // 5. Itera sobre as viagens procurando correspondência por hash ou código em claro
    for (final viagem in viagensAtivas) {
      if (viagem.isCancelada || viagem.isConcluida) continue;
      // Se a viagem não possui nem hashes nem códigos de acesso, prossegue
      if (viagem.codigosHash.isEmpty && viagem.codigosAcesso.isEmpty) continue;

      // Calcula o hash da tentativa usando o ID da viagem como salt criptográfico
      final hashTentativa = CodigoAcessoService.calcularHash(
        codigoSanitizado,
        viagem.id,
      );

      for (final paciente in pacientesDisponiveis) {
        // Aplica a ordem estrita de resolução do identificador
        final resolucao =
            CodigoAcessoService.resolverIdentificadorLogin(paciente);
        String? docRes = resolucao.documentoNormalizado;

        // Fallback para pacientes cadastrados cujo CPF de 11 dígitos foi digitado manualmente
        // no formulário administrativo sem dígito verificador Mod-11 estrito (desde que não seja sequência repetida)
        if ((resolucao.tipo == 'ignorado' || docRes == null) &&
            docLimpo.isNotEmpty &&
            !RegExp(r'^(\d)\1{10}$').hasMatch(docLimpo)) {
          final cpfPacLimpo = CodigoAcessoService.normalizarDigitos(paciente.cpf);
          final cpfAcompLimpo = CodigoAcessoService.normalizarDigitos(paciente.cpfAcompanhante ?? '');
          if (cpfPacLimpo.isNotEmpty && cpfPacLimpo == docLimpo) {
            docRes = cpfPacLimpo;
          } else if (cpfAcompLimpo.isNotEmpty && cpfAcompLimpo == docLimpo) {
            docRes = cpfAcompLimpo;
          }
        }

        if (docRes == null || docRes.isEmpty) {
          continue;
        }

        // Verifica se o identificador digitado coincide com o documento resolvido
        final matchDocumento = docRes == docLimpo ||
            (docLimpo.isNotEmpty &&
                CodigoAcessoService.normalizarDigitos(docRes) == docLimpo) ||
            docRes.trim().toUpperCase() == documento.trim().toUpperCase();

        if (matchDocumento) {
          // Verifica se o código em claro ou o hash calculado coincidem com os registros da viagem
          final codigoClaro = viagem.codigosAcesso[paciente.id]?.trim();
          final codigoClaroValido =
              codigoClaro != null && codigoClaro.isNotEmpty && codigoClaro == codigoSanitizado;
          final hashRegistrado = viagem.codigosHash[paciente.id];
          final hashValido = hashRegistrado != null && hashRegistrado == hashTentativa;
          if (codigoClaroValido || hashValido) {
            // Sucesso! Registra na proteção contra força bruta
            CodigoAcessoService.registrarSucesso(
              docLimpo,
              ip: ipOrigem,
            );

            // Vincula o papel de paciente no cache estático de RBAC
            _pacienteLogadoId = paciente.id;
            _roleCache[paciente.id] = UserRole.paciente;
            return UserRole.paciente;
          }
        }
      }

      // Verifica também os passageiros embutidos diretamente na viagem (caso não listado na consulta anterior)
      for (final pv in viagem.passageiros) {
        final cpfPv = CodigoAcessoService.normalizarDigitos(pv.pacienteCpf ?? '');
        final matchPv = docLimpo.isNotEmpty && cpfPv.isNotEmpty && cpfPv == docLimpo;
        if (matchPv) {
          final codigoClaro = viagem.codigosAcesso[pv.pacienteId]?.trim();
          final codigoClaroValido =
              codigoClaro != null && codigoClaro.isNotEmpty && codigoClaro == codigoSanitizado;
          final hashRegistrado = viagem.codigosHash[pv.pacienteId];
          final hashValido = hashRegistrado != null && hashRegistrado == hashTentativa;
          if (codigoClaroValido || hashValido) {
            CodigoAcessoService.registrarSucesso(
              docLimpo,
              ip: ipOrigem,
            );
            _pacienteLogadoId = pv.pacienteId;
            _roleCache[pv.pacienteId] = UserRole.paciente;
            return UserRole.paciente;
          }
        }
      }
    }

    // 7. Se não encontrar nenhuma viagem/hash coincidente, registra tentativa falha e lança erro genérico
    CodigoAcessoService.registrarTentativaFalha(
      docLimpo,
      ip: ipOrigem,
    );
    throw const AuthException(
      'Credenciais inválidas ou viagem não localizada.',
      code: 'invalid-credentials',
    );
  }

  // Linha em branco separadora entre login e logout

  // --------------------------------------------------------------------------
  // SOBRESCRITA DO MÉTODO: logout
  // - O que faz: Encerra a sessão no FirebaseAuth e limpa o cache estático em memória.
  // --------------------------------------------------------------------------
  @override
  // Método assíncrono para desconectar o usuário e purgar credenciais
  Future<void> logout() async {
    // Limpa o cache estático em memória de perfis e reseta sessão de paciente
    clearRoleCache();
    // Encerra ouvintes de sessão ativa (SessionScope) para evitar vazamento de cotas após logout
    try {
      ViagemService().encerrarEscutasFirestore();
      LocalizacaoMotoristaService().encerrarEscutas();
    } catch (_) {}
    // Executa o logout no FirebaseAuth
    try {
      await auth.signOut();
    } catch (_) {}
  // Fecha o método logout
  }

  // Linha em branco separadora entre logout e mapeamento de exceções
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Mapeamento de erros de infraestrutura do Firebase para mensagens amigáveis em português
  // ----------------------------------------------------------------------------
  // MÉTODO ESTÁTICO: mapFirebaseAuthException
  // - O que faz: Converte códigos técnicos de erro do Firebase Auth em frases legíveis em português.
  // ----------------------------------------------------------------------------
  static String mapFirebaseAuthException(FirebaseAuthException e) {
    // Avalia o código do erro através de uma instrução switch
    switch (e.code) {
      // Credencial inválida (login ou senha incorretos)
      case 'invalid-credential':
        return 'CPF ou senha incorretos.';
      // Usuário não cadastrado no Firebase Auth
      case 'user-not-found':
        return 'Usuário não encontrado.';
      // Senha informada não confere
      case 'wrong-password':
        return 'Senha incorreta.';
      // Bloqueio temporário por excesso de tentativas incorretas
      case 'too-many-requests':
        return 'Muitas tentativas sem sucesso. Tente novamente mais tarde.';
      // Problema de conectividade com a rede de internet
      case 'network-request-failed':
        return 'Falha de conexão com a rede. Verifique sua internet.';
      // Conta desativada pela administração
      case 'user-disabled':
        return 'Este usuário foi desabilitado. Contate o administrador.';
      // E-mail gerado com formato inválido
      case 'invalid-email':
        return 'Formato de identificação inválido.';
      // Caso padrão para qualquer outro código não mapeado
      default:
        return 'Ocorreu um erro ao realizar o login. Tente novamente.';
    // Fecha a instrução switch
    }
  // Fecha o método mapFirebaseAuthException
  }

// Fecha a declaração da classe FirebaseAuthService
}
