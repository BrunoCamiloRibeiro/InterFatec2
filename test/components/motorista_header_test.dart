import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/motorista_header.dart';

void main() {
  group('MotoristaHeader - Testes de Widget', () {
    testWidgets('1. Renderiza o título da viagem formatado', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MotoristaHeader(tituloViagem: 'Viagem #42')),
        ),
      );

      expect(find.text('Viagem #42'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets(
      '2. Setas ficam visualmente desabilitadas quando o callback é nulo',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MotoristaHeader(
                tituloViagem: 'Viagem #1',
                onAnterior: null,
                onProxima: null,
              ),
            ),
          ),
        );

        final iconButtonAnterior = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.arrow_back_ios_new),
        );
        final iconButtonProxima = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.arrow_forward_ios),
        );

        expect(iconButtonAnterior.onPressed, isNull);
        expect(iconButtonProxima.onPressed, isNull);

        final iconAnterior = tester.widget<Icon>(
          find.byIcon(Icons.arrow_back_ios_new),
        );
        final iconProxima = tester.widget<Icon>(
          find.byIcon(Icons.arrow_forward_ios),
        );

        expect(iconAnterior.color, Colors.grey[400]);
        expect(iconProxima.color, Colors.grey[400]);
      },
    );

    testWidgets('3. Callbacks onAnterior e onProxima são chamados ao tocar', (
      tester,
    ) async {
      int anteriorContador = 0;
      int proximaContador = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MotoristaHeader(
              tituloViagem: 'Viagem #2',
              onAnterior: () => anteriorContador++,
              onProxima: () => proximaContador++,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Viagem anterior'));
      await tester.pump();
      expect(anteriorContador, 1);
      expect(proximaContador, 0);

      await tester.tap(find.byTooltip('Próxima viagem'));
      await tester.pump();
      expect(anteriorContador, 1);
      expect(proximaContador, 1);
    });

    testWidgets('4. Sem overflow com textScaleFactor 2.0 e largura de 360dp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: MotoristaHeader(
                  tituloViagem:
                      'Viagem 999 - Titulo Muito Longo Para Testar Ellipsis Sem Overflow',
                  motoristaNome: 'Carlos Roberto Pereira',
                  destino: 'Hospital de Base Rio Preto',
                  veiculo: 'Van Sprinter Mercedes ABC-1234',
                  saida: '06:30',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MotoristaHeader), findsOneWidget);
    });

    testWidgets(
      '5. Atende a diretriz de acessibilidade androidTapTargetGuideline',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: MotoristaHeader(
                  tituloViagem: 'Viagem #1',
                  onAnterior: () {},
                  onProxima: () {},
                ),
              ),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      },
    );

    testWidgets(
      '6. Não renderiza linha secundária quando campos opcionais não são passados',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: MotoristaHeader(tituloViagem: 'Viagem #1')),
          ),
        );

        expect(find.byType(Divider), findsNothing);
        expect(find.byIcon(Icons.person_outline), findsNothing);
        expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      },
    );

    testWidgets(
      '7. Renderiza linha secundária quando campos opcionais são passados',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MotoristaHeader(
                tituloViagem: 'Viagem #1',
                motoristaNome: 'João Silva',
                destino: 'Barretos',
                veiculo: 'Spin XYZ-9876',
                saida: '07:00',
              ),
            ),
          ),
        );

        expect(find.byType(Divider), findsOneWidget);
        expect(find.text('João Silva'), findsOneWidget);
        expect(find.text('Barretos'), findsOneWidget);
        expect(find.text('Spin XYZ-9876'), findsOneWidget);
        expect(find.text('07:00'), findsOneWidget);
      },
    );
  });
}
