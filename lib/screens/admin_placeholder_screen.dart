// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/screens/admin_placeholder_screen.dart
// Camada: Apresentação / Telas de Interface (Screens / UI)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o módulo administrativo do sistema TransSaúde. Abre diretamente no
// Gerenciador de Horários e Grade Diária de Viagens (Issue #65), incorporando
// menu lateral retrátil (Drawer) com atalhos para Gestão de Pessoas (CRUD),
// frotas de veículos e encerramento seguro de sessão.
//
// ONDE É USADO NO PROJETO:
// - lib/routes/route_guard.dart (renderizado na rota '/administrativo')
// - lib/screens/auth_gate.dart (direcionado quando o usuário autenticado é admin)
// - test/screens/auth_gate_test.dart (testes de máquina de estados e logout)
// ============================================================================

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'gerenciador_viagens_screen.dart';

/// Painel Administrativo Oficial do TransSaúde
/// Redireciona diretamente para o Gerenciador de Horários com Drawer lateral
class AdminPlaceholderScreen extends StatelessWidget {
  final AuthService authService;

  AdminPlaceholderScreen({super.key, AuthService? authService})
      : authService = authService ?? FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    return GerenciadorViagensScreen(
      authServiceOverride: authService,
    );
  }
}
