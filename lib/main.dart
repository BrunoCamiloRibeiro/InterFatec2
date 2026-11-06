import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'Outdated/administrativo.dart';
import 'Outdated/login.dart';
import 'lista_pessoas.dart';
import 'paciente.dart';
import 'Outdated/register.dart';
import 'components/formulario_inicio_viagem.dart';
import 'motorista.dart';

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
      // Define a rota inicial para a tela de início da viagem
      initialRoute: '/',
      routes: {
        // Rota inicial exibindo a tela com o formulário de início de viagem
        '/': (context) => const TelaInicioViagem(),
        '/inicio-viagem': (context) => const TelaInicioViagem(),
        // Rota da tela do motorista com a lista de passageiros
        '/motorista': (context) => const Motorista(),
        '/lista-passageiros': (context) => const Motorista(),
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
        // Telas antigas arquivadas em Outdated (mantidas nas rotas para consulta dos devs)
        '/login': (context) => Login(),
        '/register': (context) => Register(),
        '/administrativo': (context) => Administrativo(),
        '/paciente': (context) => Paciente(),
        // Rota da tela de Gestão de Pessoas (CRUD - Issue #34)
        '/lista-pessoas': (context) => const ListaPessoas(),
        '/crud-pessoas': (context) => const ListaPessoas(),
      },
    );
  }
}
