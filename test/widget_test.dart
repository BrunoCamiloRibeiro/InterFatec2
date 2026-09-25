import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/administrativo.dart';
import 'package:trans_saude/login.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/paciente.dart';
import 'package:trans_saude/register.dart';

void main() {
  testWidgets('Tela do paciente carrega corretamente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Paciente()));
    expect(find.text('Painel Paciente'), findsOneWidget);
  });

  testWidgets('Tela de login carrega com dropdown e botões', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Login()));
    expect(find.text('Acesse sua Conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Registrar-se'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('Tela de registro carrega com campos e botão entrar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Register()));
    expect(find.text('Criar Nova Conta'), findsOneWidget);
    expect(find.text('CONFIRMAR SENHA'), findsOneWidget);
    expect(find.text('Cadastrar'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Tela administrativo carrega cards e botões', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Administrativo()));
    expect(find.text('Gestão de Transporte'), findsOneWidget);
    expect(find.text('Painel do Administrador'), findsOneWidget);
    expect(find.text('Novo Cadastro de Paciente'), findsOneWidget);
    expect(find.text('Salvar Paciente'), findsOneWidget);
  });

  testWidgets('Tela motorista carrega lista e botão gerar lista para assinar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Motorista()));
    expect(find.text('Lista de Passageiros'), findsOneWidget);
    expect(find.text('Maria das Dores Silva'), findsOneWidget);
    expect(find.text('Gerar lista para assinar'), findsOneWidget);
  });
}
