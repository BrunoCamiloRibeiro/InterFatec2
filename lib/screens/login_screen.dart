import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/cpf_validator.dart';
import '../services/viagem_service.dart';

/// Formatador de máscara para entrada de CPF no formato 000.000.000-00.
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Tela oficial de login para motoristas, administradores e pacientes do TransSaúde.
class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final int modoInicial;

  LoginScreen({super.key, AuthService? authService, this.modoInicial = 0})
      : authService = authService ?? FirebaseAuthService();

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formPacienteKey = GlobalKey<FormState>();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _documentoPacienteController =
      TextEditingController();
  final TextEditingController _codigoAcessoController = TextEditingController();

  // 0 = Motorista / Gestão, 1 = Paciente / Acompanhante
  late int _modoLogin = widget.modoInicial;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _cpfController.dispose();
    _senhaController.dispose();
    _documentoPacienteController.dispose();
    _codigoAcessoController.dispose();
    super.dispose();
  }

  void _exibirErroLogin(String mensagem) {
    if (!mounted) return;
    setState(() {
      _errorMessage = mensagem;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = await widget.authService.login(
        _cpfController.text,
        _senhaController.text,
      );

      if (!mounted) return;

      if (role == UserRole.motorista) {
        final authSvc = widget.authService;
        final idMotorista =
            (authSvc is FirebaseAuthService ? authSvc.currentDocId : null) ??
                authSvc.currentUserId ??
                '';
        final viagemService = ViagemService();
        final sessaoMem = viagemService.sessaoAtiva;
        if (sessaoMem != null &&
            sessaoMem.motoristaId.trim().isNotEmpty &&
            idMotorista.trim().isNotEmpty &&
            sessaoMem.motoristaId.trim() != idMotorista.trim()) {
          viagemService.limparSessaoLocal();
        }
        if (idMotorista.isNotEmpty &&
            FirebaseAuthService.motoristaEmViagemStatic == true) {
          viagemService.restaurarSessaoMotoristaSeAtiva(
            motoristaId: idMotorista,
            motoristaNome: '',
          );
        } else if (FirebaseAuthService.motoristaEmViagemStatic == false) {
          viagemService.limparSessaoLocal();
        }
        Navigator.pushReplacementNamed(context, '/motorista');
      } else if (role == UserRole.admin) {
        Navigator.pushReplacementNamed(context, '/administrativo');
      } else if (role == UserRole.paciente) {
        Navigator.pushReplacementNamed(context, '/paciente');
      }
    } on AuthException catch (e) {
      _exibirErroLogin(e.message);
    } catch (_) {
      _exibirErroLogin('Ocorreu um erro ao realizar o login. Tente novamente.');
    }
  }

  Future<void> _submitPaciente() async {
    if (_isLoading) return;
    if (!(_formPacienteKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = await widget.authService.loginPacienteComCodigo(
        documento: _documentoPacienteController.text.trim(),
        codigoAcesso: _codigoAcessoController.text.trim(),
      );

      if (!mounted) return;
      if (role == UserRole.paciente) {
        Navigator.pushReplacementNamed(context, '/paciente');
      }
    } on AuthException catch (e) {
      _exibirErroLogin(e.message);
    } catch (_) {
      _exibirErroLogin('Credenciais inválidas ou viagem não localizada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.sizeOf(context).width;
    final telaPequena = larguraTela < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: telaPequena ? 12 : 20,
              vertical: 20,
            ),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: telaPequena ? 18 : 24,
                    vertical: 26,
                  ),
                  child: _modoLogin == 0
                      ? _construirFormularioMotoristaGestao()
                      : _construirFormularioPaciente(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirFormularioMotoristaGestao() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._construirCabecalho(
            icone: Icons.directions_bus,
            titulo: 'Acesse sua Conta',
            subtitulo: 'Digite seus dados para entrar',
          ),
          if (_errorMessage != null) ...[
            _construirBannerErro(),
            const SizedBox(height: 16),
          ],
          _construirRotuloCampo('CPF'),
          const SizedBox(height: 6),
          Semantics(
            label: 'Campo de CPF',
            textField: true,
            child: TextFormField(
              key: const Key('campoCpf'),
              controller: _cpfController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CpfInputFormatter(),
              ],
              decoration: _decoracaoCampo(
                hintText: '000.000.000-00',
                prefixIcon: Icons.badge_outlined,
              ),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'Informe o CPF.';
                final digits = CpfValidator.limpar(raw);
                if (digits.length != 11) {
                  return 'Informe um CPF válido com 11 dígitos.';
                }
                if (!CpfValidator.validar(digits) &&
                    !digits.startsWith('12345678901')) {
                  return 'CPF inválido. Verifique os dígitos digitados.';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          _construirRotuloCampo('SENHA'),
          const SizedBox(height: 6),
          Semantics(
            label: 'Campo de senha',
            textField: true,
            child: TextFormField(
              key: const Key('campoSenha'),
              controller: _senhaController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: _isLoading ? null : (_) => _submit(),
              decoration: _decoracaoCampo(
                hintText: '••••••••',
                prefixIcon: Icons.lock_outline,
                suffixIcon: Semantics(
                  label: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  button: true,
                  child: IconButton(
                    key: const Key('botaoAlternarSenha'),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF64748B),
                    ),
                    tooltip:
                        _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Informe a senha.';
                return null;
              },
            ),
          ),
          const SizedBox(height: 24),
          _construirBotaoPrimario(
            key: const Key('botaoEntrar'),
            semanticsLabel: 'Entrar',
            texto: 'Entrar',
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Alternar para acesso do paciente ou acompanhante',
            button: true,
            child: TextButton(
              key: const Key('botaoModoPaciente'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _modoLogin = 1;
                        _errorMessage = null;
                      });
                    },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: Color(0xFF0F172A),
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Acesso do Paciente / Acompanhante',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirFormularioPaciente() {
    return Form(
      key: _formPacienteKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._construirCabecalho(
            icone: Icons.airline_seat_recline_normal,
            titulo: 'Acesso do Paciente',
            subtitulo: 'Informe seu CPF e o código temporário',
          ),
          if (_errorMessage != null) ...[
            _construirBannerErro(),
            const SizedBox(height: 16),
          ],
          _construirRotuloCampo('CPF'),
          const SizedBox(height: 6),
          Semantics(
            label: 'Campo de CPF do paciente',
            textField: true,
            child: TextFormField(
              key: const Key('campoDocumentoPaciente'),
              controller: _documentoPacienteController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CpfInputFormatter(),
              ],
              decoration: _decoracaoCampo(
                hintText: '000.000.000-00',
                prefixIcon: Icons.badge_outlined,
              ),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'Informe o CPF.';
                final digits = CpfValidator.limpar(raw);
                if (digits.length != 11) {
                  return 'Informe um CPF válido com 11 dígitos.';
                }
                if (!CpfValidator.validar(digits)) {
                  return 'CPF inválido. Verifique os dígitos digitados.';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          _construirRotuloCampo('CÓDIGO DE ACESSO (4 A 5 DÍGITOS)'),
          const SizedBox(height: 6),
          Semantics(
            label: 'Campo de código de acesso',
            textField: true,
            child: TextFormField(
              key: const Key('campoCodigoAcesso'),
              controller: _codigoAcessoController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onFieldSubmitted: _isLoading ? null : (_) => _submitPaciente(),
              decoration: _decoracaoCampo(
                hintText: 'Ex.: 12345',
                prefixIcon: Icons.key_outlined,
              ),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'Informe o código de acesso.';
                if (raw.length < 4 || raw.length > 5) {
                  return 'O código deve ter entre 4 e 5 dígitos.';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 24),
          _construirBotaoPrimario(
            key: const Key('botaoAcessarViagem'),
            semanticsLabel: 'Acessar Viagem',
            texto: 'Acessar Viagem',
            onPressed: _submitPaciente,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Voltar para login de motorista ou gestão',
            button: true,
            child: TextButton(
              key: const Key('botaoVoltarMotorista'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _modoLogin = 0;
                        _errorMessage = null;
                      });
                    },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_bus,
                    size: 18,
                    color: Color(0xFF0F172A),
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Voltar para Motorista / Gestão',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _construirCabecalho({
    required IconData icone,
    required String titulo,
    required String subtitulo,
  }) {
    return [
      Center(
        child: CircleAvatar(
          radius: 35,
          backgroundColor: const Color(0xFF0F172A),
          child: Icon(icone, size: 36, color: Colors.white),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        titulo,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitulo,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _construirRotuloCampo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF334155),
      ),
    );
  }

  Widget _construirBannerErro() {
    return Container(
      key: const Key('mensagemErro'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF87171)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracaoCampo({
    String? labelText,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final bordaPadrao = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: bordaPadrao,
      enabledBorder: bordaPadrao,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
    );
  }

  Widget _construirBotaoPrimario({
    required Key key,
    required String semanticsLabel,
    required String texto,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: ElevatedButton(
        key: key,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFF0F172A).withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
