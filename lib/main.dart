// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/main.dart
// Camada: Inicialização e Configuração Raiz do Aplicativo
//
// O QUE ESTE ARQUIVO FAZ:
// É o ponto de entrada oficial (entrypoint) do aplicativo TransSaúde. Executa
// a inicialização dos bindings do framework Flutter (WidgetsFlutterBinding),
// inicializa o Firebase Core com as opções da plataforma em execução
// (DefaultFirebaseOptions.currentPlatform) e instancia o widget raiz MyApp
// que configura o MaterialApp: título, desativação da faixa de debug, rota
// inicial reativa '/', guarda de rotas protegidas por perfil (RouteGuard) e
// tabela de rotas estáticas (login, formulários de teste, gestão de pessoas e legado).
//
// PARA QUE SERVE NO PROJETO:
// Orquestra a inicialização de todo o ecossistema do app, vinculando os serviços
// de infraestrutura da nuvem Google Firebase com a navegação e telas do Flutter.
//
// ONDE É USADO NO PROJETO:
// Ponto de entrada invocado automaticamente pela engine do Flutter na inicialização
// nos ambientes Android, iOS, Web e Desktop.
//
// DE ONDE RECEBE DADOS:
// - lib/firebase_options.dart (chaves de API e IDs de projeto por plataforma)
// - Rotas e componentes registrados nas demais camadas do projeto
//
// O QUE EXPORTA / EXPÕE:
// - void main() async: rotina principal de inicialização
// - class MyApp extends StatelessWidget: widget raiz do MaterialApp
//
// ORIGEM HISTÓRICA:
// Criado no commit inicial do scaffold (59a63c4) e mantido pela equipe em
// evolução contínua (issues #17, #28, #34; PRs #58, #59, #60).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:firebase_core/firebase_core.dart' e 'package:flutter/material.dart'.
// Efeitos colaterais: conexão de rede assíncrona ao Firebase Core na inicialização.
// ============================================================================

// Importa o cliente de inicialização da plataforma Firebase
import 'package:firebase_core/firebase_core.dart';
// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre pacotes do framework e imports do projeto
// Importa a tela administrativa legada arquivada
import 'Outdated/administrativo.dart';
// Importa a tela de registro legada arquivada
import 'Outdated/register.dart';
// Importa o formulário de início de viagem e tela hospedeira
import 'components/formulario_inicio_viagem.dart';
// Importa as opções de configuração do Firebase por plataforma
import 'firebase_options.dart';
// Importa a tela de gestão de pessoas
import 'lista_pessoas.dart';
// Importa a guarda de rotas por perfil de acesso
import 'routes/route_guard.dart';
// Importa o AuthGate reativo de autenticação
import 'screens/auth_gate.dart';
// Importa a tela oficial de login
import 'screens/login_screen.dart';

// Linha em branco separadora entre imports e função main
// Função principal assíncrona de inicialização do TransSaúde
void main() async {
  // Assegura que os bindings de canais nativos do Flutter estejam prontos
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa o Firebase com as opções da plataforma em execução
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,

    // Comentário original do autor mantido byte a byte:
    // Firebase foi importado estilo dezani pra cá, mas foi feito a options pra definir qual cara tá abrindo a sessão
  );
  // Inicializa a árvore de widgets renderizando a aplicação MyApp
  runApp(MyApp());
// Fecha a função main
}

// Linha em branco separadora entre main e MyApp
// Declaração do widget raiz StatelessWidget MyApp
class MyApp extends StatelessWidget {
  // Construtor constante com chave de identificação do widget
  MyApp({super.key});

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para configuração do MaterialApp
  @override
  // Constrói o MaterialApp raiz
  Widget build(BuildContext context) {
    return MaterialApp(
      // Desativa a faixa de depuração no canto superior direito
      debugShowCheckedModeBanner: false,
      // Título do aplicativo para a barra de tarefas do sistema
      title: 'Transporte Saúde',
      // Comentário original do autor mantido byte a byte:
      // Rota inicial controlada pelo AuthGate reativo
      // Rota inicial raiz apontando para o AuthGate
      initialRoute: '/',
      // Comentário original do autor mantido byte a byte:
      // Guarda de rotas com validação de perfil (RBAC) para rotas protegidas
      // Manipulador dinâmico de rotas para autorização por papel
      onGenerateRoute: RouteGuard.onGenerateRoute,
      // Tabela de rotas estáticas nomeadas da aplicação
      routes: {
        // Comentário original do autor mantido byte a byte:
        // Gate principal com máquina de estados de autenticação
        // Rota raiz direcionada ao AuthGate
        '/': (context) => const AuthGate(),
        // Comentário original do autor mantido byte a byte:
        // Rota mantida para acesso direto ao formulário inicial
        // Rota direta para abertura de viagem
        '/inicio-viagem': (context) => const TelaInicioViagem(),
        // Comentário original do autor mantido byte a byte:
        // Rota com o formulário no estado padrão
        // Rota de teste com formulário padrão
        '/formulario-normal': (context) => const Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: FormularioInicioViagem(),
        ),
        // Comentário original do autor mantido byte a byte:
        // Rota com o formulário no estado de lista de veículos vazia
        // Rota de teste simulando ausência de veículos disponíveis
        '/formulario-vazio': (context) => const Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: FormularioInicioViagem(forcarVeiculos: []),
        ),
        // Comentário original do autor mantido byte a byte:
        // Rota com o formulário exibindo mensagem de erro
        // Rota de teste simulando erro de servidor
        '/formulario-erro': (context) => const Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: FormularioInicioViagem(
            forcarErro: 'Falha de comunicação com o servidor da frota.',
          ),
        ),
        // Comentário original do autor mantido byte a byte:
        // Rota com o formulário exibindo mensagem de veículo em uso
        // Rota de teste simulando conflito de veículo ocupado
        '/formulario-veiculo-em-uso': (context) => const Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: FormularioInicioViagem(
            forcarErro:
                'O veículo ABC-1D23 já está em uso por outro motorista.',
          ),
        ),
        // Comentário original do autor mantido byte a byte:
        // Telas de autenticação e registro
        // Rota para a tela de login oficial
        '/login': (context) => LoginScreen(),
        // Rota para a tela de registro legada
        '/register': (context) => Register(),
        // Comentário original do autor mantido byte a byte:
        // Gestão de Pessoas (Issue #34)
        // Rota para o painel de listagem de pessoas
        '/lista-pessoas': (context) => const ListaPessoas(),
        // Comentário original do autor mantido byte a byte:
        // Telas antigas arquivadas em Outdated (mantidas com prefixo para consulta dos devs)
        // Rota para a tela administrativa antiga arquivada
        '/outdated-administrativo': (context) => Administrativo(),
      },
    );
  }
}
