import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'Outdated/administrativo.dart';
import 'Outdated/register.dart';
import 'components/formulario_inicio_viagem.dart';
import 'firebase_options.dart';
import 'lista_pessoas.dart';
import 'routes/route_guard.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,

    // Firebase foi importado estilo dezani pra cá, mas foi feito a options pra definir qual cara tá abrindo a sessão
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Transporte Saúde',
      // Rota inicial controlada pelo AuthGate reativo
      initialRoute: '/',
      // Guarda de rotas com validação de perfil (RBAC) para rotas protegidas
      onGenerateRoute: RouteGuard.onGenerateRoute,
      routes: {
        // Gate principal com máquina de estados de autenticação
        '/': (context) => const AuthGate(),
        // Rota mantida para acesso direto ao formulário inicial
        '/inicio-viagem': (context) => const TelaInicioViagem(),
        // Rota com o formulário no estado padrão
        '/formulario-normal': (context) => const Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: FormularioInicioViagem(),
        ),
        // Rota com o formulário no estado de lista de veículos vazia
        '/formulario-vazio': (context) => const Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: FormularioInicioViagem(forcarVeiculos: []),
        ),
        // Rota com o formulário exibindo mensagem de erro
        '/formulario-erro': (context) => const Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: FormularioInicioViagem(
            forcarErro: 'Falha de comunicação com o servidor da frota.',
          ),
        ),
        // Rota com o formulário exibindo mensagem de veículo em uso
        '/formulario-veiculo-em-uso': (context) => const Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          body: FormularioInicioViagem(
            forcarErro:
                'O veículo ABC-1D23 já está em uso por outro motorista.',
          ),
        ),
        // Telas de autenticação e registro
        '/login': (context) => LoginScreen(),
        '/register': (context) => Register(),
        // Gestão de Pessoas (Issue #34)
        '/lista-pessoas': (context) => const ListaPessoas(),
        // Telas antigas arquivadas em Outdated (mantidas com prefixo para consulta dos devs)
        '/outdated-administrativo': (context) => Administrativo(),
      },
    );
  }
}
