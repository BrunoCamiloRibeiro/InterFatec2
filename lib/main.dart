import 'package:flutter/material.dart';

import 'Outdated/administrativo.dart';
import 'Outdated/login.dart';
import 'Outdated/paciente.dart';
import 'Outdated/register.dart';
import 'motorista.dart';
import 'lista_veiculos.dart';

void main() {
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
      initialRoute: '/veiculos',
      routes: {
        '/': (context) => Motorista(),
        '/motorista': (context) => Motorista(),
        // Telas antigas arquivadas em Outdated (mantidas nas rotas para consulta dos devs)
        '/login': (context) => Login(),
        '/register': (context) => Register(),
        '/administrativo': (context) => Administrativo(),
        '/paciente': (context) => Paciente(),
        '/veiculos': (context) => Veiculos(),
      },
    );
  }
}
