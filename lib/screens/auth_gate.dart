import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../motorista.dart';
import '../paciente.dart';
import '../services/auth_service.dart';
import 'admin_placeholder_screen.dart';
import 'login_screen.dart';

/// Máquina de estados explícita do fluxo de entrada e autorização do app.
sealed class AuthGateState {
  const AuthGateState();
}

class AuthGateCarregando extends AuthGateState {
  const AuthGateCarregando();
}

class AuthGateDeslogado extends AuthGateState {
  final String? mensagem;
  const AuthGateDeslogado({this.mensagem});
}

class AuthGateAutenticado extends AuthGateState {
  final UserRole role;
  const AuthGateAutenticado(this.role);
}

class AuthGatePerfilInvalido extends AuthGateState {
  final String mensagem;
  const AuthGatePerfilInvalido({
    this.mensagem = 'Perfil de usuário inválido ou não cadastrado no sistema.',
  });
}

class AuthGateErroTemporario extends AuthGateState {
  final String mensagem;
  const AuthGateErroTemporario({
    this.mensagem =
        'Falha de conexão com o servidor. Verifique sua rede e tente novamente.',
  });
}

class AuthGatePermissaoNegada extends AuthGateState {
  final String mensagem;
  const AuthGatePermissaoNegada({
    this.mensagem =
        'Acesso não autorizado pelo servidor (permissão negada). Sua sessão foi encerrada.',
  });
}

/// Portal reativo inicial: observa [AuthService.authStateChanges], resolve o
/// [UserRole] e despacha o usuário para sua tela ou card de erro adequado.
class AuthGate extends StatefulWidget {
  final AuthService? authService;
  final Future<UserRole> Function(String uid)? roleResolver;
  final Stream<String?>? authStateStream;

  const AuthGate({
    super.key,
    this.authService,
    this.roleResolver,
    this.authStateStream,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  StreamSubscription<String?>? _authSubscription;
  AuthGateState _state = const AuthGateCarregando();
  String? _currentUid;
  UserRole? _cachedRole;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? FirebaseAuthService();
    final stream = widget.authStateStream ?? _authService.authStateChanges;
    _authSubscription = stream.listen(_aoMudarEstadoAutenticacao);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _aoMudarEstadoAutenticacao(String? uid) async {
    if (!mounted) return;

    if (uid == null) {
      _currentUid = null;
      _cachedRole = null;
      _authService.clearRoleCache();
      // Preserva card de feedback se o logout foi disparado por violação de segurança/perfil.
      if (_state is AuthGatePerfilInvalido ||
          _state is AuthGatePermissaoNegada) {
        return;
      }
      setState(() => _state = const AuthGateDeslogado());
      return;
    }

    if (_currentUid == uid && _cachedRole != null) {
      setState(() => _state = AuthGateAutenticado(_cachedRole!));
      return;
    }

    _currentUid = uid;
    await _resolverPerfil(uid);
  }

  Future<void> _resolverPerfil(String uid) async {
    setState(() => _state = const AuthGateCarregando());

    try {
      final resolver =
          widget.roleResolver ?? (id) => _authService.resolveUserRole(id);
      final role = await resolver(uid);
      if (!mounted) return;

      _cachedRole = role;
      setState(() => _state = AuthGateAutenticado(role));
    } on AuthException catch (e) {
      if (!mounted) return;
      await _tratarErroResolucao(e);
    } catch (e) {
      if (!mounted) return;
      await _tratarErroResolucao(
        AuthException(
          'Ocorreu um erro ao carregar os dados de acesso.',
          code: e.toString(),
        ),
      );
    }
  }

  Future<void> _tratarErroResolucao(AuthException e) async {
    _cachedRole = null;

    if (e.code == 'unavailable') {
      // Erro transitório de rede: mantém a sessão para permitir retry sem novo login.
      setState(() => _state = AuthGateErroTemporario(mensagem: e.message));
      return;
    }

    await _authService.logout();
    if (!mounted) return;

    setState(() {
      _state = e.code == 'permission-denied'
          ? AuthGatePermissaoNegada(mensagem: e.message)
          : AuthGatePerfilInvalido(mensagem: e.message);
    });
  }

  void _tentarNovamente() {
    if (_currentUid != null) {
      _resolverPerfil(_currentUid!);
    } else {
      setState(() => _state = const AuthGateDeslogado());
    }
  }

  void _voltarAoLogin() {
    setState(() => _state = const AuthGateDeslogado());
  }

  Widget _buildSplash() {
    return const Scaffold(
      key: Key('splashCarregando'),
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_bus, size: 56, color: Colors.white),
            SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'TransSaúde',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFeedback({
    required Key key,
    required String titulo,
    required String mensagem,
    required IconData icone,
    required Color corIcone,
    required String textoBotao,
    required Key botaoKey,
    required VoidCallback onAcao,
  }) {
    return Scaffold(
      key: key,
      backgroundColor: const Color(0xFFF7F8FA),
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
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: corIcone.withValues(alpha: 0.12),
                        child: Icon(icone, size: 36, color: corIcone),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mensagem,
                        style: const TextStyle(
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
                        child: ElevatedButton(
                          key: botaoKey,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: onAcao,
                          child: Text(
                            textoBotao,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      AuthGateCarregando() => _buildSplash(),
      AuthGateDeslogado() => LoginScreen(authService: _authService),
      AuthGateAutenticado(:final role) => switch (role) {
        UserRole.motorista => const Motorista(),
        UserRole.admin => AdminPlaceholderScreen(authService: _authService),
        UserRole.paciente => Paciente(
          pacienteId: _currentUid ?? _authService.currentUserId,
        ),
      },
      AuthGatePerfilInvalido(:final mensagem) => _buildCardFeedback(
        key: const Key('telaPerfilInvalido'),
        titulo: 'Perfil Inválido',
        mensagem: mensagem,
        icone: Icons.no_accounts,
        corIcone: const Color(0xFFDC2626),
        textoBotao: 'Voltar ao Login',
        botaoKey: const Key('botaoVoltarLogin'),
        onAcao: _voltarAoLogin,
      ),
      AuthGateErroTemporario(:final mensagem) => _buildCardFeedback(
        key: const Key('telaErroTemporario'),
        titulo: 'Erro de Conexão',
        mensagem: mensagem,
        icone: Icons.cloud_off,
        corIcone: const Color(0xFFF59E0B),
        textoBotao: 'Tentar novamente',
        botaoKey: const Key('botaoTentarNovamente'),
        onAcao: _tentarNovamente,
      ),
      AuthGatePermissaoNegada(:final mensagem) => _buildCardFeedback(
        key: const Key('telaPermissaoNegada'),
        titulo: 'Acesso Negado',
        mensagem: mensagem,
        icone: Icons.security,
        corIcone: const Color(0xFFDC2626),
        textoBotao: 'Voltar ao Login',
        botaoKey: const Key('botaoVoltarLoginPermissao'),
        onAcao: _voltarAoLogin,
      ),
    };
  }
}
