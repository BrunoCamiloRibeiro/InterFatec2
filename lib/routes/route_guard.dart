// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/routes/route_guard.dart
// Camada: Apresentação e Navegação / Rotas (Routes)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa o mecanismo central de proteção de rotas e controle de acesso
// baseado em papéis (Role-Based Access Control - RBAC) do Flutter. Intercepta
// solicitações de navegação do MaterialApp através do método onGenerateRoute,
// verifica se o usuário autenticado possui o papel (UserRole) exigido pela
// rota solicitada (/motorista, /administrativo, /paciente) e redireciona
// tentativas de acesso indevido para a tela apropriada ao seu privilégio ou
// para o fluxo de autenticação (AuthGate / LoginScreen), evitando telas em branco.
//
// PARA QUE SERVE NO PROJETO:
// Garante a segurança de navegação no aplicativo, impedindo que motoristas
// acessem áreas administrativas, que pacientes acessem controles operacionais
// ou que usuários deslogados naveguem em rotas restritas via URL ou push manual.
//
// ONDE É USADO NO PROJETO:
// - lib/main.dart (registrado em onGenerateRoute no MaterialApp principal)
// - test/screens/auth_gate_test.dart (testes de autorização e proteção de rotas)
//
// DE ONDE RECEBE DADOS:
// - RouteSettings fornecido pelo Navigator do Flutter com o nome da rota (/...)
// - AuthService (via FirebaseAuthService ou mock) para ler currentUserId e perfil em cache
//
// O QUE EXPORTA / EXPÕE:
// - class RouteGuard
//   * static Route<dynamic> onGenerateRoute(RouteSettings, {AuthService? authService})
//   * static MaterialPageRoute _redirecionarAcessoIndevido(...)
//
// ORIGEM HISTÓRICA:
// Criado no commit 3645a3d pela equipe do projeto na issue #28 (diferenciação
// de papéis de usuário) e aprimorado no commit 06fef7d (PR #60).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart'.
// Não possui efeitos colaterais de rede ou persistência: cria rotas dinâmicas em memória.
// ============================================================================

// Importa o framework visual e de navegação do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports do framework e imports internos
// Importa a enumeração UserRole para verificação de permissões do perfil
import '../models/user_role.dart';
// Importa a tela do motorista para renderização de sua rota protegida
import '../motorista.dart';
// Importa a tela do paciente para renderização de sua rota protegida
import '../paciente.dart';
// Importa a tela temporária do administrador para sua rota protegida
import '../screens/admin_placeholder_screen.dart';
// Importa a tela de AuthGate para redirecionamento de usuários em transição
import '../screens/auth_gate.dart';
// Importa a tela de Login para redirecionamento de usuários deslogados
import '../screens/login_screen.dart';
// Importa o contrato e serviços de autenticação
import '../services/auth_service.dart';

// Linha em branco separadora entre imports e RouteGuard
// Comentário original do autor mantido byte a byte:
/// Guarda de rotas centralizada para proteger rotas por perfil de acesso (RBAC)
// Declaração da classe RouteGuard responsável pelo controle de acesso em navegação
class RouteGuard {
  // Comentário original do autor mantido byte a byte:
  /// Gerador de rotas com controle de acesso para MaterialApp.onGenerateRoute
  // Método estático invocado pelo Navigator para construir a rota solicitada
  static Route<dynamic> onGenerateRoute(
    // Configurações da rota (contendo nome e argumentos passados)
    RouteSettings settings, {
    // Instância opcional de AuthService permitindo injeção de dependências em testes
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
      // Rota destinada exclusivamente a motoristas
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
      // Rota destinada exclusivamente a administradores
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
      // Rota destinada exclusivamente a pacientes
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
      // Caso padrão para qualquer rota não mapeada explicitamente (ex: '/')
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
  // Comentário original do autor mantido byte a byte:
  /// Redireciona para o destino legítimo do perfil atual ou para o login, evitando tela em branco
  // Método auxiliar privado que calcula o destino seguro em caso de acesso negado
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
// Fecha a classe RouteGuard
}
