// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/screens/auth_gate.dart
// Camada: Apresentação e Telas (Screens)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa a porta de entrada reativa (AuthGate) e a máquina de estados finita
// do fluxo de autenticação e autorização por perfil do TransSaúde.
// Monitora a stream de estado da sessão do Firebase (authStateChanges), resolve o
// papel (UserRole) do usuário no Firestore e direciona a visualização para:
// 1. Splash de carregamento ('AuthGateCarregando');
// 2. Tela de login ('AuthGateDeslogado');
// 3. Destino operacional por perfil validado ('AuthGateAutenticado' -> Motorista, Admin ou Paciente);
// 4. Cards de feedback acessíveis com retry ou retorno ao login para falhas de
//    rede ('AuthGateErroTemporario'), perfil não cadastrado ('AuthGatePerfilInvalido')
//    e acesso não autorizado ('AuthGatePermissaoNegada').
//
// PARA QUE SERVE NO PROJETO:
// É o roteador reativo raiz do aplicativo, assegurando que nenhum usuário
// visualize rotas protegidas sem autenticação válida e perfil verificado,
// eliminando travamentos, flickering e estados intermediários inconsistentes.
//
// ONDE É USADO NO PROJETO:
// - lib/main.dart (widget associado à rota raiz '/' e tela inicial)
// - lib/routes/route_guard.dart (fallback seguro de rota no MaterialApp)
// - test/screens/auth_gate_test.dart (testes de máquina de estados da sessão)
//
// DE ONDE RECEBE DADOS:
// - AuthService (via FirebaseAuthService padrão ou mock injetado em testes)
// - Parâmetros opcionais roleResolver e authStateStream para injeção de dependência
//
// O QUE EXPORTA / EXPÕE:
// - sealed class AuthGateState e subtipos:
//   * AuthGateCarregando
//   * AuthGateDeslogado
//   * AuthGateAutenticado
//   * AuthGatePerfilInvalido
//   * AuthGateErroTemporario
//   * AuthGatePermissaoNegada
// - class AuthGate extends StatefulWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 3645a3d pela equipe na issue #28 (roteamento por perfil).
// Não provém de scaffold ou template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'dart:async' e 'package:flutter/material.dart'.
// Efeitos colaterais: escuta contínua de Stream com cancelamento de StreamSubscription
// no dispose(), e chamada forçada de logout em caso de violação de segurança ou perfil inválido.
// ============================================================================

// Importa a biblioteca de fluxos assíncronos dart:async para manipulação de StreamSubscription
import 'dart:async';

// Linha em branco separadora entre imports do core e framework visual
// Importa o framework visual e de componentes Material Design do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre framework e modelos/telas do projeto
// Importa a enumeração UserRole para tratamento dos privilégios de acesso
import '../models/user_role.dart';
// Importa a tela do motorista para renderização quando autenticado como motorista
import '../motorista.dart';
// Importa a tela do paciente para renderização quando autenticado como paciente
import '../paciente.dart';
// Importa o contrato e serviço de autenticação
import '../services/auth_service.dart';
// Importa o placeholder do módulo administrativo para admins autenticados
import 'admin_placeholder_screen.dart';
// Importa a tela de login para usuários deslogados
import 'login_screen.dart';

// Linha em branco separadora entre imports e máquina de estados
// Comentário original do autor mantido byte a byte:
/// Máquina de estados explícita do fluxo de entrada do aplicativo
// Declaração da classe selada AuthGateState representando o estado raiz
sealed class AuthGateState {
  // Construtor constante da classe selada
  const AuthGateState();
// Fecha o bloco de declaração de AuthGateState
}

// Linha em branco separadora entre classes de estados
// Comentário original do autor mantido byte a byte:
/// Estado inicial ou transitório de carregamento e resolução do perfil
// Estado que representa verificação assíncrona ou carregamento em andamento
class AuthGateCarregando extends AuthGateState {
  // Construtor constante de AuthGateCarregando
  const AuthGateCarregando();
// Fecha a classe AuthGateCarregando
}

// Linha em branco separadora entre classes de estados
// Comentário original do autor mantido byte a byte:
/// Estado em que não há usuário autenticado
// Estado representativo de ausência de credenciais válidas
class AuthGateDeslogado extends AuthGateState {
  // Mensagem opcional de feedback ao usuário deslogado
  final String? mensagem;
  // Construtor constante de AuthGateDeslogado com mensagem opcional
  const AuthGateDeslogado({this.mensagem});
// Fecha a classe AuthGateDeslogado
}

// Linha em branco separadora entre classes de estados
// Comentário original do autor mantido byte a byte:
/// Estado em que o usuário está autenticado e seu perfil foi validado
// Estado indicando sucesso na autenticação e confirmação de privilégio
class AuthGateAutenticado extends AuthGateState {
  // Papel do usuário validado no banco de dados
  final UserRole role;
  // Construtor constante recebendo o UserRole confirmado
  const AuthGateAutenticado(this.role);
// Fecha a classe AuthGateAutenticado
}

// Linha em branco separadora entre classes de estados
// Comentário original do autor mantido byte a byte:
/// Estado de erro em que o usuário não possui documento ou possui role inválido
// Estado indicando cadastro inexistente ou privilégio desconhecido
class AuthGatePerfilInvalido extends AuthGateState {
  // Mensagem explicativa do erro de perfil
  final String mensagem;
  // Construtor constante com mensagem padrão descritiva
  const AuthGatePerfilInvalido({
    this.mensagem = 'Perfil de usuário inválido ou não cadastrado no sistema.',
  });
// Fecha a classe AuthGatePerfilInvalido
}

// Linha em branco separadora entre classes de estados
// Comentário original do autor mantido byte a byte:
/// Estado de falha transitória de comunicação com a rede
// Estado indicando problema transitório de internet ou servidor
class AuthGateErroTemporario extends AuthGateState {
  // Mensagem explicativa da falha de conexão
  final String mensagem;
  // Construtor constante com mensagem amigável de orientação
  const AuthGateErroTemporario({
    this.mensagem = 'Falha de conexão com o servidor. Verifique sua rede e tente novamente.',
  });
// Fecha a classe AuthGateErroTemporario
}

// Linha em branco separadora entre classes de estados
// Comentário original do autor mantido byte a byte:
/// Estado de violação de regras de segurança (permission-denied)
// Estado indicando falta de autorização de leitura no Firestore
class AuthGatePermissaoNegada extends AuthGateState {
  // Mensagem explicativa da violação de acesso
  final String mensagem;
  // Construtor constante com mensagem de segurança informando encerramento
  const AuthGatePermissaoNegada({
    this.mensagem = 'Acesso não autorizado pelo servidor (permissão negada). Sua sessão foi encerrada.',
  });
// Fecha a classe AuthGatePermissaoNegada
}

// Linha em branco separadora entre estados e o widget AuthGate
// Comentário original do autor mantido byte a byte:
/// Gate reativo de autenticação e autorização por perfil de usuário
// Declaração do widget StatefulWidget AuthGate
class AuthGate extends StatefulWidget {
  // Serviço de autenticação opcional para injeção de dependência em testes
  final AuthService? authService;
  // Função opcional para resolução customizada de perfil em testes
  final Future<UserRole> Function(String uid)? roleResolver;
  // Stream opcional para simulação de eventos de autenticação em testes
  final Stream<String?>? authStateStream;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante do widget AuthGate
  const AuthGate({
    // Chave única de identificação do widget
    super.key,
    // Parâmetro opcional de serviço de autenticação
    this.authService,
    // Parâmetro opcional de resolvedor de role
    this.roleResolver,
    // Parâmetro opcional de stream de autenticação
    this.authStateStream,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e createState

  // Cria o estado mutável associado a este widget
  @override
  // Instancia a classe de estado _AuthGateState
  State<AuthGate> createState() => _AuthGateState();
// Fecha a classe AuthGate
}

// Linha em branco separadora entre AuthGate e _AuthGateState
// Classe de estado privada que gerencia as transições de estado do AuthGate
class _AuthGateState extends State<AuthGate> {
  // Instância do serviço de autenticação inicializada no initState
  late final AuthService _authService;
  // Assinatura da stream de mudanças de autenticação
  StreamSubscription<String?>? _authSubscription;
  // Estado atual da máquina de estados do AuthGate
  AuthGateState _state = const AuthGateCarregando();
  // UID do usuário autenticado atualmente em memória
  String? _currentUid;
  // Papel em cache do usuário autenticado atualmente
  UserRole? _cachedRole;

  // Linha em branco separadora entre atributos e initState

  // Ciclo de vida: inicialização do estado do widget
  @override
  // Executa configuração inicial e disparo da escuta da sessão
  void initState() {
    // Executa a inicialização padrão da superclasse
    super.initState();
    // Resolve a instância do serviço de autenticação
    _authService = widget.authService ?? FirebaseAuthService();
    // Inicia a escuta da stream de autenticação
    _iniciarEscutaSessao();
  // Fecha o método initState
  }

  // Linha em branco separadora entre métodos de ciclo de vida

  // Método auxiliar para configurar o listener da stream de sessão
  void _iniciarEscutaSessao() {
    // Obtém a stream customizada repassada ou a nativa do serviço
    final stream = widget.authStateStream ?? _authService.authStateChanges;
    // Registra o callback assíncrono para eventos da stream
    _authSubscription = stream.listen(_aoMudarEstadoAutenticacao);
  // Fecha o método _iniciarEscutaSessao
  }

  // Linha em branco separadora entre métodos de ciclo de vida

  // Ciclo de vida: descarte do widget da árvore
  @override
  // Cancela a assinatura da stream para evitar vazamento de memória
  void dispose() {
    // Cancela o listener da stream
    _authSubscription?.cancel();
    // Executa a finalização da superclasse
    super.dispose();
  // Fecha o método dispose
  }

  // Linha em branco separadora entre métodos de ciclo de vida e tratadores de eventos

  // Tratador assíncrono invocado quando o estado da sessão de autenticação muda
  Future<void> _aoMudarEstadoAutenticacao(String? uid) async {
    // Aborta se o widget foi desmontado durante a espera
    if (!mounted) return;

    // Linha em branco separadora entre checagem de montagem e tratamento de deslogado
    // Se o UID recebido for nulo, indica que não há sessão ativa
    if (uid == null) {
      // Limpa a referência de UID atual
      _currentUid = null;
      // Limpa a referência de perfil em cache
      _cachedRole = null;
      // Purga o cache do serviço de autenticação
      _authService.clearRoleCache();
      // Comentários originais do autor mantidos byte a byte:
      // Se o usuário foi desconectado forçadamente por perfil inválido ou permissão negada,
      // preserva o estado de feedback para que a mensagem de erro não seja sobrescrita de relance.
      // Preserva o card de feedback em caso de desconexão forçada por erro de segurança
      if (_state is AuthGatePerfilInvalido ||
          _state is AuthGatePermissaoNegada) {
        return;
      // Fecha a checagem de preservação de estado de erro
      }
      // Atualiza o estado da máquina para Deslogado
      setState(() {
        _state = const AuthGateDeslogado();
      });
      // Finaliza o tratamento
      return;
    // Fecha o bloco if uid == null
    }

    // Linha em branco separadora entre deslogado e reaproveitamento de cache
    // Comentário original do autor mantido byte a byte:
    // Se o mesmo UID já tem role resolvido em cache, mantém autenticado sem refetch
    // Evita requisição repetida ao banco se o perfil do mesmo UID já estiver em memória
    if (_currentUid == uid && _cachedRole != null) {
      // Atualiza o estado imediatamente com o perfil em cache
      setState(() {
        _state = AuthGateAutenticado(_cachedRole!);
      });
      // Finaliza o tratamento
      return;
    // Fecha o bloco if de reaproveitamento de cache
    }

    // Linha em branco separadora entre cache e resolução de novo UID
    // Registra o novo UID ativo
    _currentUid = uid;
    // Dispara a consulta assíncrona do perfil
    await _resolverPerfil(uid);
  // Fecha o método _aoMudarEstadoAutenticacao
  }

  // Linha em branco separadora entre tratadores de eventos

  // Método assíncrono para consultar e resolver o UserRole do usuário no Firestore
  Future<void> _resolverPerfil(String uid) async {
    // Define o estado visual para carregando durante a busca
    setState(() {
      _state = const AuthGateCarregando();
    });

    // Linha em branco separadora entre setState e bloco try
    // Bloco de tentativa para resolução do papel
    try {
      // Seleciona a função de resolução customizada ou o método padrão do serviço
      final resolver =
          widget.roleResolver ?? (id) => _authService.resolveUserRole(id);
      // Aguarda a resolução assíncrona do perfil
      final role = await resolver(uid);

      // Aborta caso o widget tenha sido desmontado durante o await
      if (!mounted) return;

      // Armazena o perfil resolvido na variável local
      _cachedRole = role;
      // Atualiza a máquina de estados para Autenticado
      setState(() {
        _state = AuthGateAutenticado(role);
      });
    // Captura AuthException disparada durante a resolução
    } on AuthException catch (e) {
      // Aborta caso o widget tenha sido desmontado
      if (!mounted) return;
      // Direciona para o tratamento de falhas
      await _tratarErroResolucao(e);
    // Captura qualquer outro erro inesperado
    } catch (e) {
      // Aborta caso o widget tenha sido desmontado
      if (!mounted) return;
      // Encapsula o erro genérico em AuthException e trata
      await _tratarErroResolucao(
        AuthException(
          'Ocorreu um erro ao carregar os dados de acesso.',
          code: e.toString(),
        ),
      );
    // Fecha o bloco catch
    }
  // Fecha o método _resolverPerfil
  }

  // Linha em branco separadora entre _resolverPerfil e _tratarErroResolucao

  // Método assíncrono para mapear e tratar as falhas na resolução do perfil
  Future<void> _tratarErroResolucao(AuthException e) async {
    // Limpa o cache de papel
    _cachedRole = null;

    // Linha em branco separadora entre limpeza e classificação do erro
    // Avalia se o código da exceção corresponde a falha transitória de rede
    if (e.code == 'unavailable') {
      // Comentário original do autor mantido byte a byte:
      // Erro transitório de rede: NÃO deslogar, permitir retry
      // Atualiza para o estado de erro temporário mantendo a sessão para retry
      setState(() {
        _state = AuthGateErroTemporario(mensagem: e.message);
      });
    // Avalia se o código corresponde a permissão negada no Firestore
    } else if (e.code == 'permission-denied') {
      // Comentário original do autor mantido byte a byte:
      // Falha explícita de segurança: deslogar imediatamente
      // Desloga o usuário forçadamente no Firebase
      await _authService.logout();
      // Checa se o widget continua montado
      if (!mounted) return;
      // Atualiza o estado para permissão negada
      setState(() {
        _state = AuthGatePermissaoNegada(mensagem: e.message);
      });
    // Demais casos de erro de perfil inexistente ou inconsistente
    } else {
      // Comentário original do autor mantido byte a byte:
      // Perfil inexistente ou com dados inconsistentes: deslogar imediatamente
      // Desloga o usuário forçadamente no Firebase
      await _authService.logout();
      // Checa se o widget continua montado
      if (!mounted) return;
      // Atualiza o estado para perfil inválido
      setState(() {
        _state = AuthGatePerfilInvalido(mensagem: e.message);
      });
    // Fecha o bloco if/else de tratamento de erro
    }
  // Fecha o método _tratarErroResolucao
  }

  // Linha em branco separadora entre tratamento de erro e ações de botão

  // Callback acionado pelo botão 'Tentar novamente' no card de erro transitório
  void _tentarNovamente() {
    // Se o UID atual estiver memorizado, tenta resolver o perfil novamente
    if (_currentUid != null) {
      _resolverPerfil(_currentUid!);
    // Caso contrário, retorna ao estado deslogado
    } else {
      setState(() {
        _state = const AuthGateDeslogado();
      });
    // Fecha if de UID
    }
  // Fecha o método _tentarNovamente
  }

  // Linha em branco separadora entre ações de botão

  // Callback acionado pelo botão 'Voltar ao Login' nos cards de erro definitivo
  void _voltarAoLogin() {
    // Transiciona o estado para deslogado, exibindo a tela de LoginScreen
    setState(() {
      _state = const AuthGateDeslogado();
    });
  // Fecha o método _voltarAoLogin
  }

  // Linha em branco separadora entre ações de botão e construtores de tela

  // Constrói a tela de splash exibida durante a resolução do perfil
  Widget _buildSplash() {
    // Retorna Scaffold escuro com animação de progresso e identidade visual
    return const Scaffold(
      // Chave semântica para localização do splash em testes
      key: Key('splashCarregando'),
      // Cor de fundo azul marinho escuro oficial
      backgroundColor: Color(0xFF0F172A),
      // Centraliza o conteúdo da tela de splash
      body: Center(
        // Coluna com ícone de ônibus, indicador circular e título
        child: Column(
          // Ocupa o tamanho mínimo vertical necessário
          mainAxisSize: MainAxisSize.min,
          // Filhos da coluna
          children: [
            // Ícone temático de transporte sanitário
            Icon(Icons.directions_bus, size: 56, color: Colors.white),
            // Espaçamento vertical de 24 pontos
            SizedBox(height: 24),
            // Indicador de progresso circular branco
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            // Espaçamento vertical de 16 pontos
            SizedBox(height: 16),
            // Nome do aplicativo
            Text(
              'TransSaúde',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          // Fecha a lista de children
          ],
        // Fecha a Column
        ),
      // Fecha o Center
      ),
    // Fecha o Scaffold
    );
  // Fecha o método _buildSplash
  }

  // Linha em branco separadora entre construtores de tela

  // Método auxiliar reutilizável para renderização dos cards de feedback de erro
  Widget _buildCardFeedback({
    // Chave semântica da tela
    required Key key,
    // Título do card de erro
    required String titulo,
    // Mensagem descritiva da ocorrência
    required String mensagem,
    // Ícone representativo do tipo de erro
    required IconData icone,
    // Cor temática do ícone
    required Color corIcone,
    // Texto a ser exibido no botão de ação
    required String textoBotao,
    // Chave semântica do botão
    required Key botaoKey,
    // Ação a ser executada ao pressionar o botão
    required VoidCallback onAcao,
  // Abre o corpo do método _buildCardFeedback
  }) {
    // Retorna Scaffold com fundo claro
    return Scaffold(
      // Chave da tela
      key: key,
      // Fundo cinza suave
      backgroundColor: const Color(0xFFF7F8FA),
      // Área segura para manter margens com o sistema
      body: SafeArea(
        // Centraliza o card na tela
        child: Center(
          // Permite rolagem em telas compactas
          child: SingleChildScrollView(
            // Margens laterais de 24 pontos e verticais de 20 pontos
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            // Limita a largura em no máximo 420 pontos
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // Card com elevação sutil e contorno
              child: Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                // Preenchimento interno do card
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  // Coluna contendo avatar, título, mensagem e botão de ação
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar circular com a cor semântica do erro
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: corIcone.withValues(alpha: 0.12),
                        child: Icon(icone, size: 36, color: corIcone),
                      ),
                      // Espaçamento vertical de 20 pontos
                      const SizedBox(height: 20),
                      // Título do erro
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Espaçamento vertical de 12 pontos
                      const SizedBox(height: 12),
                      // Mensagem explicativa
                      Text(
                        mensagem,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Espaçamento vertical de 28 pontos
                      const SizedBox(height: 28),
                      // Botão de largura completa
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
  // Fecha o método _buildCardFeedback
  }

  // Linha em branco separadora entre métodos auxiliares e build

  // Sobrescrita do método build para chaveamento declarativo da máquina de estados
  @override
  // Renderiza a interface correspondente ao estado ativo da máquina de estados
  Widget build(BuildContext context) {
    // Avalia o estado _state através de pattern matching declarativo com switch
    return switch (_state) {
      // Estado carregando: renderiza splash animada
      AuthGateCarregando() => _buildSplash(),
      // Estado deslogado: renderiza a tela de login
      AuthGateDeslogado() => LoginScreen(authService: _authService),
      // Estado autenticado: avalia o papel confirmado para exibir a tela apropriada
      AuthGateAutenticado(:final role) => switch (role) {
        // Papel motorista: exibe a tela operacional do motorista
        UserRole.motorista => const Motorista(),
        // Papel administrador: exibe o painel de administração
        UserRole.admin => AdminPlaceholderScreen(authService: _authService),
        // Papel paciente: exibe a tela do paciente
        UserRole.paciente => const Paciente(),
      },
      // Estado perfil inválido: exibe card com instrução de retorno ao login
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
      // Estado erro temporário: exibe card de falha de conexão com botão de retry
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
      // Estado permissão negada: exibe card de bloqueio por regras de segurança
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
    // Fecha a expressão switch
    };
  // Fecha o método build
  }
// Fecha a classe _AuthGateState
}
