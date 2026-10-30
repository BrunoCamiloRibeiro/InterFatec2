import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'Outdated/administrativo.dart';
import 'Outdated/login.dart';
import 'Outdated/paciente.dart';
import 'Outdated/register.dart';
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
      // Abre direto na tela do motorista
      initialRoute: '/motorista',
      routes: {
        '/': (context) => Motorista(),
        '/motorista': (context) => Motorista(),
        // Telas antigas arquivadas em Outdated (mantidas nas rotas para consulta dos devs)
        '/login': (context) => Login(),
        '/register': (context) => Register(),
        '/administrativo': (context) => Administrativo(),
        '/paciente': (context) => Paciente(),
      },
    );
  }
}
