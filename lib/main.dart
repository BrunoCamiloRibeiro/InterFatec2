import 'package:flutter/material.dart';

import 'administrativo.dart';
import 'login.dart';
import 'motorista.dart';
import 'paciente.dart';
import 'register.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/paciente',
      routes: {
        '/': (context) => const Paciente(),
        '/paciente': (context) => const Paciente(),
        '/login': (context) => const Login(),
        '/register': (context) => const Register(),
        '/motorista': (context) => const Motorista(),
        '/administrativo': (context) => const Administrativo(),
      },
    );
  }
}
