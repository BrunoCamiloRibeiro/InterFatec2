// ============================================================================
// SUÍTE DE TESTES DE WIDGET: banner_reversao_paciente_test.dart
// Camada: Apresentação / Componentes Visuais
// Escopo: Banner de contagem regressiva e ação de Desfazer (Issue #19)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/banner_reversao_paciente.dart';
import 'package:trans_saude/models/janela_reversao_model.dart';

void main() {
  testWidgets('1. Renderiza banner com contagem regressiva para cancelamento (300 s)', (tester) async {
    final agora = DateTime.utc(2026, 11, 7, 12, 0, 0);
    final janela = JanelaReversaoModel(
      acao: 'cancelamento_carona',
      iniciadoEm: agora,
      expiraEm: agora.add(const Duration(seconds: 300)),
      estadoAnterior: 0,
    );

    bool desfez = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerReversaoPaciente(
            janela: janela,
            relogio: () => agora,
            onDesfazer: () => desfez = true,
          ),
        ),
      ),
    );

    expect(find.text('Cancelamento Solicitado'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.byKey(const Key('botao_desfazer_reversao')), findsOneWidget);

    // Toca no botão de desfazer
    await tester.tap(find.byKey(const Key('botao_desfazer_reversao')));
    await tester.pump();

    expect(desfez, isTrue);
  });

  testWidgets('2. Renderiza aviso de Expirado quando a janela passou do tempo limite', (tester) async {
    final tZero = DateTime.utc(2026, 11, 7, 12, 0, 0);
    final janela = JanelaReversaoModel(
      acao: 'cancelamento_carona',
      iniciadoEm: tZero,
      expiraEm: tZero.add(const Duration(seconds: 300)),
      estadoAnterior: 0,
    );

    // Relógio simulando 301 segundos após o início
    final tempo301s = tZero.add(const Duration(seconds: 301));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerReversaoPaciente(
            janela: janela,
            relogio: () => tempo301s,
            onDesfazer: () {},
          ),
        ),
      ),
    );

    expect(find.text('Expirado'), findsOneWidget);
    // Botão deve estar desabilitado
    final botao = tester.widget<ElevatedButton>(find.byKey(const Key('botao_desfazer_reversao')));
    expect(botao.onPressed, isNull);
  });

  testWidgets('3. Exibe indicador de loading quando carregando == true', (tester) async {
    final agora = DateTime.utc(2026, 11, 7, 12, 0, 0);
    final janela = JanelaReversaoModel(
      acao: 'pronto_retorno',
      iniciadoEm: agora,
      expiraEm: agora.add(const Duration(seconds: 60)),
      estadoAnterior: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerReversaoPaciente(
            janela: janela,
            carregando: true,
            relogio: () => agora,
            onDesfazer: () {},
          ),
        ),
      ),
    );

    expect(find.text('Revertendo...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
