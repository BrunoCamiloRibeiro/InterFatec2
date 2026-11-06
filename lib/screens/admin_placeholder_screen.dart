import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Tela provisória (placeholder) do painel administrativo
/// Exibe aviso claro de funcionalidade em desenvolvimento e permite logout seguro
class AdminPlaceholderScreen extends StatelessWidget {
  final AuthService authService;

  AdminPlaceholderScreen({super.key, AuthService? authService})
    : authService = authService ?? FirebaseAuthService();

  Future<void> _logout(BuildContext context) async {
    await authService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Painel Administrativo'),
        actions: [
          IconButton(
            key: const Key('botaoLogoutAdmin'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sair da conta',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: Color(0xFFE2E8F0),
                        child: Icon(
                          Icons.admin_panel_settings,
                          size: 40,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Módulo Administrativo em Construção',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Esta funcionalidade está sendo implementada pela equipe. Utilize o botão abaixo para encerrar a sessão.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          key: const Key('botaoLogoutAdminCorpo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            'Encerrar Sessão',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => _logout(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
