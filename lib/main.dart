import 'package:flutter/material.dart';

import 'administrativo.dart';
import 'login.dart';
import 'motorista.dart';
import 'paciente.dart';
import 'register.dart';

// main feita pelo aluno na véspera da entrega, sem const nenhum pq o prof não gosta
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
      initialRoute: '/login',
      routes: {
        '/': (context) => Login(),
        '/login': (context) => Login(),
        '/register': (context) => Register(),
        '/administrativo': (context) => Administrativo(),
        '/motorista': (context) => Motorista(),
        '/paciente': (context) => Paciente(),
      },
    );
  }
}
