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
// que configura o MaterialApp: título, tema visual, rota inicial reativa '/',
// guarda de rotas protegidas por perfil (RouteGuard) e tabela de rotas estáticas
// (login, gestão de frotas e veículos, gestão de pessoas, previews e painéis).
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
// evolução contínua (issues #17, #19, #28, #33, #34, #65; PRs #58, #59, #60, #63, #64, #66, #67).
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
// Importa a tela de gestão de veículos
import 'lista_veiculos.dart';
// Importa o formulário de início de viagem e tela hospedeira
import 'components/formulario_inicio_viagem.dart';
// Importa as opções de configuração do Firebase por plataforma
import 'firebase_options.dart';
// Importa a tela de gestão de pessoas
import 'lista_pessoas.dart';
// Importa a tela oficial do paciente (Issue #18 e #19)
import 'paciente.dart';
// Importa a tela oficial do motorista
import 'motorista.dart';
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
      // Tema visual consistente e uniforme em todo o aplicativo
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
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
        // Gate principal com maquina de estados de autenticacao
        '/auth-gate': (context) => const AuthGate(),
        // Rota direta para a tela do paciente (Issue #19)
        '/paciente': (context) => const Paciente(),
        // Rota direta para a tela do motorista
        '/motorista': (context) => const Motorista(),
        '/lista-passageiros': (context) => const Motorista(),
        // Comentário original do autor mantido byte a byte:
        // Rota mantida para acesso direto ao formulário inicial
        // Rota direta para abertura de viagem
        '/inicio-viagem': (context) => const TelaInicioViagem(),
        // Comentário original do autor mantido byte a byte:
        // Telas de autenticação e registro
        // Rota para a tela de login oficial (Motorista / Gestão)
        '/login': (context) => LoginScreen(),
        // Rota para a tela de login oficial (Paciente / Acompanhante)
        '/login-paciente': (context) => LoginScreen(modoInicial: 1),
        // Gestão de Pessoas (Issue #34)
        // Rota para o painel de listagem de pessoas
        '/lista-pessoas': (context) => const ListaPessoas(),
        '/crud-pessoas': (context) => const ListaPessoas(),
        // Rota para a tela de gestão de veículos (Issue #33)
        '/veiculos': (context) => const Veiculos(),
        '/lista-veiculos': (context) => const Veiculos(),
      },
    );
  }
}
