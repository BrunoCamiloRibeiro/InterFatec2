// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/screens/login_screen.dart
// Camada: Apresentação e Telas (Screens)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o formulário oficial de login e autenticação para motoristas e
// administradores do sistema TransSaúde. Fornece máscara e validação de CPF
// (formato 000.000.000-00), campo de senha com alternância de visibilidade,
// tratamento de acessibilidade semântica (Semantics, labels e botões de toque >= 48dp),
// validação de preenchimento, submissão assíncrona contra o AuthService e
// exibição de mensagens amigáveis em banner/SnackBar com redirecionamento para
// as rotas operacionais (/motorista ou /administrativo).
//
// PARA QUE SERVE NO PROJETO:
// É a interface primária de entrada dos servidores públicos e condutores do
// município, garantindo acesso seguro por credenciais funcionais (CPF e senha).
//
// ONDE É USADO NO PROJETO:
// - lib/main.dart (registrado na tabela de rotas estáticas '/login')
// - lib/screens/auth_gate.dart (renderizado quando o estado é AuthGateDeslogado)
// - lib/routes/route_guard.dart (redirecionamento quando o usuário não possui sessão)
// - test/screens/login_screen_test.dart (testes de widget e validação de login)
// - test/screens/auth_gate_test.dart (testes de transição de tela do AuthGate)
//
// DE ONDE RECEBE DADOS:
// - AuthService (via FirebaseAuthService padrão ou mock injetado em testes)
// - Textos digitados pelo usuário nos campos de CPF e Senha
//
// O QUE EXPORTA / EXPÕE:
// - class CpfInputFormatter extends TextInputFormatter
// - class LoginScreen extends StatefulWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit f4fb4bb pela equipe na issue #28 (tela de login para motoristas
// e administradores). Não provém de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart' e 'package:flutter/services.dart'.
// Efeitos colaterais: invoca authService.login() autenticando no Firebase e
// substitui a rota atual através de Navigator.pushReplacementNamed.
// ============================================================================

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o pacote de serviços do Flutter para TextInputFormatter e controle de digitação
import 'package:flutter/services.dart';

// Linha em branco separadora entre imports do framework e imports internos
// Importa a enumeração UserRole para direcionamento após login bem-sucedido
import '../models/user_role.dart';
// Importa o contrato e serviços de autenticação
import '../services/auth_service.dart';

// Linha em branco separadora entre imports e CpfInputFormatter
// Comentário original do autor mantido byte a byte:
/// Formatador de máscara para entrada de CPF no formato 000.000.000-00
// Declaração da classe formatadora de texto para aplicar a máscara do CPF
class CpfInputFormatter extends TextInputFormatter {
  // Sobrescreve o método formatEditUpdate para interceptar e formatar o texto digitado
  @override
  // Método invocado a cada alteração de caractere no campo de texto
  TextEditingValue formatEditUpdate(
    // Valor anterior antes da edição
    TextEditingValue oldValue,
    // Novo valor proposto após a digitação
    TextEditingValue newValue,
  // Abre o corpo do método formatEditUpdate
  ) {
    // Remove todos os caracteres não numéricos do novo texto
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Se a quantidade de dígitos ultrapassar 11, descarta a edição mantendo o valor anterior
    if (digits.length > 11) return oldValue;

    // Linha em branco separadora entre validação de comprimento e montagem da máscara
    // Cria buffer para concatenação eficiente de caracteres
    final buffer = StringBuffer();
    // Itera pelos dígitos numéricos aplicando os separadores de ponto e hífen
    for (int i = 0; i < digits.length; i++) {
      // Adiciona ponto após o 3º e 6º dígitos
      if (i == 3 || i == 6) buffer.write('.');
      // Adiciona hífen após o 9º dígito
      if (i == 9) buffer.write('-');
      // Adiciona o dígito numérico atual ao buffer
      buffer.write(digits[i]);
    // Fecha o laço de repetição for
    }

    // Linha em branco separadora entre laço de repetição e retorno
    // Converte o buffer montado para string formatada
    final formatted = buffer.toString();
    // Retorna novo TextEditingValue com o texto mascarado e cursor no final
    return TextEditingValue(
      // Texto com a máscara aplicada
      text: formatted,
      // Posiciona a seleção/cursor no final do texto formatado
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  // Fecha o método formatEditUpdate
  }
// Fecha a classe CpfInputFormatter
}

// Linha em branco separadora entre CpfInputFormatter e LoginScreen
// Comentário original do autor mantido byte a byte:
/// Tela oficial de login para motoristas e administradores do TransSaúde
// Declaração do widget StatefulWidget da tela de login
class LoginScreen extends StatefulWidget {
  // Instância do serviço de autenticação utilizada para login
  final AuthService authService;

  // Linha em branco separadora entre atributo e construtor

  // Construtor com parâmetro opcional de authService para injeção de dependência em testes
  LoginScreen({super.key, AuthService? authService})
    // Inicializa authService com a instância repassada ou cria FirebaseAuthService padrão
    : authService = authService ?? FirebaseAuthService();

  // Linha em branco separadora entre construtor e createState

  // Cria o estado mutável associado a este widget
  @override
  // Instancia a classe de estado _LoginScreenState
  State<LoginScreen> createState() => _LoginScreenState();
// Fecha a classe LoginScreen
}

// Linha em branco separadora entre LoginScreen e _LoginScreenState
// Classe de estado privada que controla o formulário de login
class _LoginScreenState extends State<LoginScreen> {
  // Chave global para identificação e validação do formulário
  final _formKey = GlobalKey<FormState>();
  // Controlador de texto do campo de CPF
  final TextEditingController _cpfController = TextEditingController();
  // Controlador de texto do campo de senha
  final TextEditingController _senhaController = TextEditingController();

  // Linha em branco separadora entre controladores e variáveis de estado
  // Booleano para alternar a ocultação da senha (inicia oculta como true)
  bool _obscurePassword = true;
  // Indicador de carregamento durante a submissão assíncrona
  bool _isLoading = false;
  // Mensagem de erro para exibição em banner visual na interface
  String? _errorMessage;

  // Linha em branco separadora entre variáveis de estado e dispose

  // Ciclo de vida: descarte de controladores
  @override
  // Libera os recursos alocados pelos TextEditingControllers
  void dispose() {
    // Descarta o controlador de CPF
    _cpfController.dispose();
    // Descarta o controlador de senha
    _senhaController.dispose();
    // Executa a finalização da superclasse
    super.dispose();
  // Fecha o método dispose
  }

  // Linha em branco separadora entre dispose e _submit

  // Método assíncrono para validação e submissão das credenciais
  Future<void> _submit() async {
    // Interrompe se já houver uma submissão em andamento
    if (_isLoading) return;

    // Linha em branco separadora entre checagem de loading e validação de formulário
    // Dispara a validação síncrona dos campos do formulário
    final formValido = _formKey.currentState?.validate() ?? false;
    // Interrompe caso o formulário possua erros de validação
    if (!formValido) return;

    // Linha em branco separadora entre validação e atualização de estado
    // Atualiza o estado ativando o indicador de carregamento e limpando erros anteriores
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Linha em branco separadora entre setState e bloco de autenticação
    // Bloco de tentativa para submissão das credenciais ao serviço de autenticação
    try {
      // Executa o login passando o CPF e senha digitados
      final role = await widget.authService.login(
        _cpfController.text,
        _senhaController.text,
      );

      // Aborta caso o widget tenha sido desmontado da árvore durante a espera
      if (!mounted) return;

      // Se o usuário autenticado for motorista, redireciona para a tela do motorista
      if (role == UserRole.motorista) {
        Navigator.pushReplacementNamed(context, '/motorista');
      // Se o usuário for administrador, redireciona para a tela do administrador
      } else if (role == UserRole.admin) {
        Navigator.pushReplacementNamed(context, '/administrativo');
      // Fecha a checagem de perfil após login
      }
    // Captura erros de domínio AuthException
    } on AuthException catch (e) {
      // Aborta caso o widget tenha sido desmontado
      if (!mounted) return;
      // Atualiza o estado registrando a mensagem de erro e desativando o loading
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      // Exibe a mensagem de erro através de um SnackBar vermelho na parte inferior
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    // Captura outros erros inesperados
    } catch (_) {
      // Aborta caso o widget tenha sido desmontado
      if (!mounted) return;
      // Mensagem padrão de fallback para erros desconhecidos
      const fallbackMsg =
          'Ocorreu um erro ao realizar o login. Tente novamente.';
      // Atualiza o estado com a mensagem genérica de erro
      setState(() {
        _errorMessage = fallbackMsg;
        _isLoading = false;
      });
      // Exibe a mensagem genérica no SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(fallbackMsg),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    // Fecha o bloco catch
    }
  // Fecha o método _submit
  }

  // Linha em branco separadora entre _submit e build

  // Sobrescrita do método build para montagem visual da tela de login
  @override
  // Constrói a árvore de widgets da tela de login
  Widget build(BuildContext context) {
    // Retorna Scaffold com fundo cinza suave
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      // Área segura para respeitar barras do sistema
      body: SafeArea(
        // Centraliza o card de login
        child: Center(
          // Permite rolagem em telas menores
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            // Restringe a largura máxima do card para no máximo 420 pontos
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // Card com elevação sutil e bordas arredondadas
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                // Preenchimento interno do card
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  // Formulário gerenciado pela chave _formKey
                  child: Form(
                    key: _formKey,
                    // Coluna esticada horizontalmente
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar centralizado com ícone do aplicativo
                        Center(
                          child: CircleAvatar(
                            radius: 35,
                            backgroundColor: const Color(0xFF0F172A),
                            child: const Icon(
                              Icons.directions_bus,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Espaçamento vertical de 18 pontos
                        const SizedBox(height: 18),
                        // Título principal do card
                        const Text(
                          'Acesse sua Conta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        // Espaçamento vertical de 6 pontos
                        const SizedBox(height: 6),
                        // Subtítulo descritivo
                        const Text(
                          'Digite seus dados para entrar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        // Espaçamento vertical de 24 pontos
                        const SizedBox(height: 24),
                        // Exibe banner de erro condicionalmente caso _errorMessage não seja nulo
                        if (_errorMessage != null) ...[
                          // Container de banner de erro com fundo avermelhado suave
                          Container(
                            key: const Key('mensagemErro'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF87171),
                              ),
                            ),
                            // Linha contendo ícone de alerta e mensagem explicativa
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
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
                          ),
                          // Espaçamento vertical de 16 pontos abaixo do banner
                          const SizedBox(height: 16),
                        ],
                        // Rótulo textual em maiúsculas para o campo de CPF
                        const Text(
                          'CPF',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        // Espaçamento vertical de 6 pontos
                        const SizedBox(height: 6),
                        // Semantics para acessibilidade no leitor de tela
                        Semantics(
                          label: 'Campo de CPF',
                          textField: true,
                          // Campo de entrada de texto para o CPF
                          child: TextFormField(
                            key: const Key('campoCpf'),
                            controller: _cpfController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            // Formatadores de entrada: somente dígitos e máscara 000.000.000-00
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CpfInputFormatter(),
                            ],
                            // Decoração do campo com ícone de crachá e bordas suaves
                            decoration: InputDecoration(
                              labelText: 'CPF',
                              hintText: '000.000.000-00',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: Color(0xFF64748B),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0F172A),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            // Validação do campo de CPF
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) {
                                return 'Informe o CPF.';
                              }
                              final digits = raw.replaceAll(RegExp(r'\D'), '');
                              if (digits.length != 11) {
                                return 'Informe um CPF válido com 11 dígitos.';
                              }
                              return null;
                            },
                          ),
                        ),
                        // Espaçamento vertical de 16 pontos entre os campos
                        const SizedBox(height: 16),
                        // Rótulo textual em maiúsculas para o campo de Senha
                        const Text(
                          'SENHA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        // Espaçamento vertical de 6 pontos
                        const SizedBox(height: 6),
                        // Semantics para acessibilidade no campo de senha
                        Semantics(
                          label: 'Campo de senha',
                          textField: true,
                          // Campo de entrada de texto para a senha
                          child: TextFormField(
                            key: const Key('campoSenha'),
                            controller: _senhaController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: _isLoading
                                ? null
                                : (_) => _submit(),
                            // Decoração do campo com ícone de cadeado e alternância de visibilidade
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              hintText: '••••••••',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF64748B),
                              ),
                              // Botão sufixo para mostrar ou ocultar senha com Semantics
                              suffixIcon: Semantics(
                                label: _obscurePassword
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
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
                                  tooltip: _obscurePassword
                                      ? 'Mostrar senha'
                                      : 'Ocultar senha',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0F172A),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            // Validação de senha obrigatória
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Informe a senha.';
                              }
                              return null;
                            },
                          ),
                        ),
                        // Espaçamento vertical de 24 pontos antes do botão de submissão
                        const SizedBox(height: 24),
                        // Semantics para o botão Entrar
                        Semantics(
                          label: 'Entrar',
                          button: true,
                          child: ElevatedButton(
                            key: const Key('botaoEntrar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.6),
                              disabledForegroundColor: Colors.white70,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
