// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/routes/route_guard.dart
// Camada: Roteamento / Controle de Acesso Baseado em Papéis (RBAC)
//
// O QUE ESTE ARQUIVO FAZ:
// Intercepta e protege a navegação da aplicação através do gerador central
// 'onGenerateRoute', validando se o usuário autenticado possui o papel
// de acesso exigido (UserRole) para acessar as rotas nomeadas ('/motorista',
// '/administrativo' e '/paciente'). Caso o acesso seja indevido ou não autorizado,
// redireciona defensivamente para o destino legítimo do perfil ou para a tela de login.
//
// PARA QUE SERVE NO PROJETO:
// Garante a segurança de rotas da issue #28: impede que pacientes acessem o
// painel do motorista ou funções administrativas via manipulação direta de rotas
// ou deep linking, mantendo a integridade do isolamento de dados do TransSaúde.
//
// ONDE É USADO NO PROJETO:
// - lib/main.dart (registrado em MaterialApp.onGenerateRoute)
// - test/screens/auth_gate_test.dart (testes de transição de rotas e segurança)
//
// DE ONDE RECEBE DADOS:
// Parâmetros de navegação 'RouteSettings' do Flutter e perfil 'UserRole' obtido
// de forma síncrona do cache em memória do 'AuthService'.
//
// O QUE EXPORTA / EXPÕE:
// - class RouteGuard:
//   * static Route<dynamic> onGenerateRoute(RouteSettings settings, {AuthService? authService})
//
// ORIGEM HISTÓRICA:
// Criado no commit 3645a3d pela equipe do projeto na issue #28 (diferenciação
// de papéis de usuário) e aprimorado no commit 06fef7d (PR #60).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart'.
// Não possui efeitos colaterais de rede ou persistência: cria rotas dinâmicas em memória.
// ============================================================================

// ----------------------------------------------------------------------------
// IMPORTAÇÃO DE BIBLIOTECAS E COMPONENTES DE ROTA:
// - material.dart: Framework de componentes visuais, rotas e navegação do Flutter.
// - user_role.dart: Enum com os papéis do sistema (admin, motorista, paciente).
// - motorista.dart: Tela principal da operação do motorista.
// - paciente.dart: Tela principal de acompanhamento do paciente.
// - admin_placeholder_screen.dart: Painel temporário do administrador.
// - auth_gate.dart: Ponto de entrada e máquina de estados de autorização.
// - login_screen.dart: Formulário de autenticação por CPF e senha.
// - auth_service.dart: Interface e serviço de autenticação com cache de perfil.
// ----------------------------------------------------------------------------
import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../motorista.dart';
import '../paciente.dart';
import '../screens/admin_placeholder_screen.dart';
import '../screens/auth_gate.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';

// Linha em branco separadora entre imports e a classe RouteGuard
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
/// Guarda de rotas centralizada para proteger rotas por perfil de acesso (RBAC)
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE GUARDA DE ROTAS: RouteGuard
// - O que a instrução faz: Declara o interceptador de roteamento do sistema TransSaúde.
// - O que é o elemento: Classe utilitária com métodos estáticos puros para resolução de rotas.
// - Papel no sistema: Atua como middleware de navegação do MaterialApp, validando credenciais.
// ----------------------------------------------------------------------------
class RouteGuard {
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Gerador de rotas com controle de acesso para MaterialApp.onGenerateRoute
  // ----------------------------------------------------------------------------
  // MÉTODO ESTÁTICO: onGenerateRoute
  // - O que faz: Constrói a rota correspondente avaliando o perfil de acesso do usuário.
  // - Parâmetros: 'settings' (nome da rota e argumentos) e 'authService' (opcional para testes).
  // - Retorno: Instância de 'Route<dynamic>' (geralmente MaterialPageRoute).
  // ----------------------------------------------------------------------------
  static Route<dynamic> onGenerateRoute(
    // Configurações da rota solicitada pelo Navigator
    RouteSettings settings, {
    // Dependência de autenticação injetável para testes
    AuthService? authService,
  // Abre o corpo do método onGenerateRoute
  }) {
    // Resolve o serviço de autenticação padrão se não tiver sido injetado
    final service = authService ?? FirebaseAuthService();
    // Recupera o identificador do usuário autenticado atual
    final uid = service.currentUserId;
    // Consulta o perfil mantido em cache se o UID existir
    final role = uid != null ? service.getCachedRole(uid) : null;

    // Linha em branco separadora entre resolução de credenciais e avaliação da rota
    // Avalia o nome da rota solicitada via switch
    switch (settings.name) {
      // ----------------------------------------------------------------------
      // ROTA: /motorista
      // - Exige perfil 'UserRole.motorista'.
      // ----------------------------------------------------------------------
      case '/motorista':
        // Valida se o perfil autenticado é exatamente motorista
        if (role == UserRole.motorista) {
          // Constrói a rota com a tela do motorista
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Motorista(),
          );
        // Fecha if de validação de motorista
        }
        // Redireciona caso o papel não coincida
        return _redirecionarAcessoIndevido(role, settings, service);

      // Linha em branco separadora entre casos de rotas
      // ----------------------------------------------------------------------
      // ROTA: /administrativo
      // - Exige perfil 'UserRole.admin'.
      // ----------------------------------------------------------------------
      case '/administrativo':
        // Valida se o perfil autenticado é exatamente admin
        if (role == UserRole.admin) {
          // Constrói a rota com a tela do administrador
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AdminPlaceholderScreen(authService: service),
          );
        // Fecha if de validação de admin
        }
        // Redireciona caso o papel não coincida
        return _redirecionarAcessoIndevido(role, settings, service);

      // Linha em branco separadora entre casos de rotas
      // ----------------------------------------------------------------------
      // ROTA: /paciente
      // - Exige perfil 'UserRole.paciente'.
      // ----------------------------------------------------------------------
      case '/paciente':
        // Valida se o perfil autenticado é exatamente paciente
        if (role == UserRole.paciente) {
          // Constrói a rota com a tela do paciente
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Paciente(),
          );
        // Fecha if de validação de paciente
        }
        // Redireciona caso o papel não coincida
        return _redirecionarAcessoIndevido(role, settings, service);

      // Linha em branco separadora entre casos e fallback padrão
      // ----------------------------------------------------------------------
      // ROTA PADRÃO / NÃO MAPEADA:
      // - Direciona para o AuthGate para resolução reativa de estado.
      // ----------------------------------------------------------------------
      default:
        // Constrói rota direcionando para o AuthGate para resolução reativa
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AuthGate(authService: service),
        );
    // Fecha o bloco switch
    }
  // Fecha o método onGenerateRoute
  }

  // Linha em branco separadora entre onGenerateRoute e _redirecionarAcessoIndevido
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  /// Redireciona para o destino legítimo do perfil atual ou para o login, evitando tela em branco
  // ----------------------------------------------------------------------------
  // MÉTODO ESTÁTICO PRIVADO: _redirecionarAcessoIndevido
  // - Calcula o destino seguro com base no perfil atual para evitar erros 404 ou telas em branco.
  // ----------------------------------------------------------------------------
  static MaterialPageRoute _redirecionarAcessoIndevido(
    // Perfil atual resolvido do usuário
    UserRole? role,
    // Configurações da rota original
    RouteSettings settings,
    // Serviço de autenticação para repasse de dependência
    AuthService service,
  // Abre o corpo do método _redirecionarAcessoIndevido
  ) {
    // Determina o widget de destino através de expressão switch sobre o papel
    final Widget destino = switch (role) {
      // Se for motorista, devolve a tela do motorista
      UserRole.motorista => const Motorista(),
      // Se for administrador, devolve a tela do administrador
      UserRole.admin => AdminPlaceholderScreen(authService: service),
      // Se for paciente, devolve a tela do paciente
      UserRole.paciente => const Paciente(),
      // Se não houver papel em cache, verifica se há sessão ativa
      null =>
        // Se houver usuário autenticado no Firebase, direciona ao AuthGate
        service.currentUserId != null
            ? AuthGate(authService: service)
            // Caso contrário, direciona à tela de login
            : LoginScreen(authService: service),
    // Fecha a expressão switch
    };

    // Linha em branco separadora entre resolução do widget de destino e retorno da rota
    // Retorna a rota navegando para o widget de destino calculado
    return MaterialPageRoute(settings: settings, builder: (_) => destino);
  // Fecha o método _redirecionarAcessoIndevido
  }

// Fecha a declaração da classe RouteGuard
}
