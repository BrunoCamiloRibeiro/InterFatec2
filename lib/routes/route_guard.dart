import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../motorista.dart';
import '../paciente.dart';
import '../screens/admin_placeholder_screen.dart';
import '../screens/auth_gate.dart';
import '../screens/gerenciador_viagens_screen.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';

/// Guarda de rotas centralizada para proteger rotas por perfil de acesso (RBAC).
class RouteGuard {
  /// Gerador de rotas com controle de acesso para MaterialApp.onGenerateRoute.
  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    AuthService? authService,
  }) {
    final service = authService ?? FirebaseAuthService();
    final uid = service.currentUserId;
    final role = uid != null ? service.getCachedRole(uid) : null;

    switch (settings.name) {
      case '/motorista':
        if (role == UserRole.motorista) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Motorista(),
          );
        }
        return _redirecionarAcessoIndevido(role, settings, service);

      case '/administrativo':
        if (role == UserRole.admin) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AdminPlaceholderScreen(authService: service),
          );
        }
        return _redirecionarAcessoIndevido(role, settings, service);

      case '/gerenciador-horarios':
      case '/gerenciador-viagens':
        if (role == UserRole.admin) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => GerenciadorViagensScreen(authServiceOverride: service),
          );
        }
        return _redirecionarAcessoIndevido(role, settings, service);

      case '/paciente':
        if (role == UserRole.paciente) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Paciente(pacienteId: service.currentUserId),
          );
        }
        return _redirecionarAcessoIndevido(role, settings, service);

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AuthGate(authService: service),
        );
    }
  }

  /// Redireciona para o destino legítimo do perfil atual ou para o login, evitando tela em branco.
  static MaterialPageRoute _redirecionarAcessoIndevido(
    UserRole? role,
    RouteSettings settings,
    AuthService service,
  ) {
    final Widget destino = switch (role) {
      UserRole.motorista => const Motorista(),
      UserRole.admin => AdminPlaceholderScreen(authService: service),
      UserRole.paciente => Paciente(pacienteId: service.currentUserId),
      null => service.currentUserId != null
          ? AuthGate(authService: service)
          : LoginScreen(authService: service),
    };

    return MaterialPageRoute(settings: settings, builder: (_) => destino);
  }
}
