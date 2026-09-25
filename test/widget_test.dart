import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/paciente.dart';

void main() {
  testWidgets('Tela do paciente carrega corretamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Paciente()));
    expect(find.text('Painel Paciente'), findsOneWidget);
  });
}
