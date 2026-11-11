import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'lista_pessoas.dart';
import 'lista_veiculos.dart';
import 'motorista.dart';
import 'paciente.dart';
import 'routes/route_guard.dart';
import 'screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

/// Widget raiz da aplicação TransSaúde com tema, rotas e guarda RBAC.
class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Transporte Saúde',
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
      // Rota inicial controlada pelo AuthGate reativo
      initialRoute: '/',
      // Guarda de rotas com validação de perfil (RBAC) para rotas protegidas
      onGenerateRoute: RouteGuard.onGenerateRoute,
      routes: {
        '/': (context) => const AuthGate(),
        '/paciente': (context) => const Paciente(),
        '/motorista': (context) => const Motorista(),
        '/lista-pessoas': (context) => const ListaPessoas(),
        '/veiculos': (context) => const Veiculos(),
      },
    );
  }
}
