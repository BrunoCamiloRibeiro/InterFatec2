// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/screens/admin_placeholder_screen.dart
// Camada: Apresentação / Telas de Interface (Screens / UI)
//
// O QUE ESTE ARQUIVO FAZ:
// Painel Administrativo Oficial do TransSaúde.
// Herda e disponibiliza diretamente o Gerenciador de Horários e Grade Diária de
// Viagens (GerenciadorViagensScreen), com menu lateral retrátil (Drawer) para
// Gestão de Pessoas (CRUD), frota e encerramento de sessão.
// Mantido para compatibilidade com o histórico de rotas e testes automatizados.
// ============================================================================

import '../services/auth_service.dart';
import 'gerenciador_viagens_screen.dart';

/// Painel Administrativo Oficial do TransSaúde
class AdminPlaceholderScreen extends GerenciadorViagensScreen {
  AdminPlaceholderScreen({super.key, AuthService? authService})
      : super(authServiceOverride: authService);
}
