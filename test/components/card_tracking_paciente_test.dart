// ============================================================================
// TESTES DO COMPONENTE: CardTrackingPaciente & LocalizacaoMotoristaService
// ----------------------------------------------------------------------------
// Repositório: BrunoCamiloRibeiro/InterFatec2
// Contexto: Issue #65 / Rastreamento de Motoristas no Painel do Paciente
//
// OBJETIVO DOS TESTES:
// 1. Garantir que o mapa e painel de rastreamento exibam a localização de todos
//    os motoristas com viagens ativas no momento para qualquer paciente;
// 2. Garantir que a alternância entre motoristas em trânsito funcione por chips;
// 3. Garantir o tratamento elegante quando não houver viagens ativas;
// 4. Garantir que o componente NÃO tente estimar tempo (ETA) nem calcule rotas,
//    obedecendo rigorosamente à especificação do projeto;
// 5. Garantir que os botões de controle de zoom (+, -, centralizar) respondam;
// 6. Testar a integração do CardTrackingPaciente na tela principal do Paciente.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/card_tracking_paciente.dart';
import 'package:trans_saude/models/localizacao_motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/paciente.dart';
import 'package:trans_saude/services/localizacao_motorista_service.dart';

void main() {
  group('CardTrackingPaciente - Testes de Componente e Rastreamento de Motoristas', () {
    late StreamController<List<LocalizacaoMotoristaModel>> streamController;

    setUp(() {
      streamController = StreamController<List<LocalizacaoMotoristaModel>>.broadcast();
    });

    tearDown(() async {
      await streamController.close();
    });

    testWidgets('1. Exibe estado amigável quando nenhum motorista está ativo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardTrackingPaciente(
              motoristasStreamOverride: streamController.stream,
            ),
          ),
        ),
      );

      // Emite lista vazia de motoristas ativos
      streamController.add([]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica elementos do cabeçalho
      expect(find.text('Localização dos Motoristas'), findsOneWidget);
      expect(find.text('Sem viagens ativas'), findsOneWidget);

      // Verifica texto de instrução informando ausência de viagens ativas
      expect(
        find.textContaining('Nenhum motorista com viagem ativa no momento'),
        findsOneWidget,
      );

      // Garante que NENHUM texto de estimativa de tempo ou rota exista
      expect(find.textContaining('ETA'), findsNothing);
      expect(find.textContaining('tempo estimado'), findsNothing);
      expect(find.textContaining('minutos para chegada'), findsNothing);
    });

    testWidgets('2. Exibe pins e dados de todos os motoristas ativos no momento', (tester) async {
      final motorista1 = LocalizacaoMotoristaModel(
        id: 'loc1',
        motoristaId: 'm1',
        motoristaNome: 'Antônio Carlos',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin 1.8 LTZ',
        cidadeDestino: 'BARRETOS',
        latitude: -20.6120,
        longitude: -48.9100,
        ultimaAtualizacao: DateTime(2026, 11, 8, 8, 30),
        emViagem: true,
      );

      final motorista2 = LocalizacaoMotoristaModel(
        id: 'loc2',
        motoristaId: 'm2',
        motoristaNome: 'Carlos Eduardo',
        veiculoPlaca: 'BRA-2E45',
        veiculoModelo: 'Master Minibus',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        latitude: -20.7800,
        longitude: -49.5200,
        ultimaAtualizacao: DateTime(2026, 11, 8, 8, 32),
        emViagem: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardTrackingPaciente(
              motoristasStreamOverride: streamController.stream,
            ),
          ),
        ),
      );

      // Emite dois motoristas com viagens ativas
      streamController.add([motorista1, motorista2]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Indicador de cabeçalho mostra 2 motoristas em trânsito
      expect(find.text('2 em trânsito'), findsOneWidget);

      // Verifica presença dos chips de seleção para ambos os condutores
      expect(find.text('Antônio • ABC-1D23'), findsOneWidget);
      expect(find.text('Carlos • BRA-2E45'), findsOneWidget);

      // Detalhes do primeiro motorista selecionado por padrão
      expect(find.text('Antônio Carlos'), findsOneWidget);
      expect(find.text('ABC-1D23'), findsOneWidget);
      expect(find.text('Destino: BARRETOS'), findsOneWidget);

      // Alterna seleção para o segundo motorista via clique no chip
      await tester.tap(find.text('Carlos • BRA-2E45'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Detalhes agora mostram o segundo motorista
      expect(find.text('Carlos Eduardo'), findsOneWidget);
      expect(find.text('BRA-2E45'), findsOneWidget);
      expect(find.text('Destino: SÃO JOSÉ DO RIO PRETO'), findsOneWidget);

      // Controles de zoom e centralização
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      // Dispara zoom in e zoom out
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Garante novamente a ausência estrita de estimativa de rota e tempo
      expect(find.textContaining('ETA'), findsNothing);
      expect(find.textContaining('calcular rota'), findsNothing);
      expect(find.textContaining('tempo restante'), findsNothing);
    });

    testWidgets('3. Integração na tela Paciente exibe mapa de motoristas ativos', (tester) async {
      final motorista = LocalizacaoMotoristaModel(
        id: 'loc1',
        motoristaId: 'm1',
        motoristaNome: 'Antônio Carlos',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin 1.8 LTZ',
        cidadeDestino: 'BARRETOS',
        latitude: -20.6120,
        longitude: -48.9100,
        ultimaAtualizacao: DateTime(2026, 11, 8, 8, 30),
        emViagem: true,
      );

      final pacienteTeste = PacienteModel(
        id: 'p1',
        nome: 'Maria da Silva',
        cpf: '123.456.789-00',
        telefone: '(17) 99123-4567',
        enderecoPaciente: 'Rua das Flores, 125',
        localConsulta: 'Hospital de Amor',
        localSaida: 'Residência',
        horarioConsulta: '14:30',
        status: 0,
        criadoEm: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Paciente(
            pacienteStreamOverride: Stream.value(pacienteTeste),
            motoristasStreamOverride: Stream.value([motorista]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica dados do paciente
      expect(find.text('Maria da Silva'), findsOneWidget);

      // Verifica se o mapa de tracking está renderizado na tela do paciente
      expect(find.text('Localização dos Motoristas'), findsOneWidget);
      expect(find.text('1 em trânsito'), findsOneWidget);
      expect(find.text('Antônio • ABC-1D23'), findsOneWidget);
      expect(find.text('Destino: BARRETOS'), findsOneWidget);
    });

    test('4. LocalizacaoMotoristaService inicializa e persiste dados mock e atualizações', () async {
      final service = LocalizacaoMotoristaService();
      service.redefinirParaTestes();

      expect(service.motoristasAtivos.length, 0);

      await service.atualizarLocalizacaoMotorista(
        motoristaId: 'm_teste',
        motoristaNome: 'Condutor Teste',
        veiculoPlaca: 'TEST-1234',
        veiculoModelo: 'Van Municipal',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        latitude: -20.8113,
        longitude: -49.3758,
      );

      expect(service.motoristasAtivos.length, 1);
      final mot = service.motoristasAtivos.first;
      expect(mot.motoristaNome, 'Condutor Teste');
      expect(mot.veiculoPlaca, 'TEST-1234');
      expect(mot.latitude, -20.8113);
      expect(mot.longitude, -49.3758);
      expect(mot.emViagem, true);

      // Inativação de motorista ao encerrar viagem
      service.removerOuInativarMotorista('m_teste');
      expect(service.motoristasAtivos.length, 0);
    });

    testWidgets('5. Renderiza FlutterMap com tiles reais e controles de GPS do dispositivo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardTrackingPaciente(
              motoristasStreamOverride: streamController.stream,
            ),
          ),
        ),
      );

      streamController.add([]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica presença da API de mapa (FlutterMap) e TileLayer
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);

      // Verifica controles de GPS do dispositivo
      expect(find.textContaining('GPS'), findsWidgets);
      expect(find.byIcon(Icons.directions_bus_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });
  });
}
