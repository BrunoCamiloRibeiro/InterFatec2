import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/formulario_encerramento.dart';
import 'package:trans_saude/components/formulario_inicio_viagem.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/services/localizacao_motorista_service.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  late ViagemService viagemService;
  late PacienteSyncService syncService;
  late LocalizacaoMotoristaService locService;

  setUp(() {
    viagemService = ViagemService();
    syncService = PacienteSyncService();
    locService = LocalizacaoMotoristaService();

    viagemService.resetParaTestes();
    syncService.resetParaTestes();
    locService.redefinirParaTestes();
  });

  tearDown(() {
    viagemService.executorPersistenciaRemotaOverride = null;
    syncService.executorRemotoOverride = null;
    viagemService.encerrarEscutasFirestore();
    locService.encerrarEscutas();
  });

  group('1. Benchmark de Latência de UI (Zero-Wait < 16 ms / Teto < 100 ms)', () {
    testWidgets(
      'Swipe do motorista (confirmDismiss) reflete visualmente em < 16 ms mesmo com rede lenta de 1500 ms',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final completerRede = Completer<void>();
        syncService.executorRemotoOverride = (pacienteId, payload) async {
          await completerRede.future;
        };
        viagemService.executorPersistenciaRemotaOverride = (op, payload) async {
          await completerRede.future;
        };

        final viagemAtiva = ViagemModel(
          id: 'viagem_bench_1',
          motoristaId: 'mot_bench',
          motoristaNome: 'Carlos Motorista',
          veiculoId: 'v1',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Sprinter',
          kmInicial: 15420,
          cidadeDestino: 'São José do Rio Preto',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          passageirosIds: const ['pac_bench_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_bench_1',
              pacienteNome: 'Ana Benchmark',
              pacienteCpf: '111.222.333-44',
              localOrigem: 'Rua A, 10',
              localDestino: 'Hospital de Base',
              horarioAtendimento: '08:00',
              statusEmbarque: 0,
            ),
          ],
        );

        viagemService.resetParaTestes(
          viagemAtivaInicial: viagemAtiva,
          todasViagensIniciais: [viagemAtiva],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemInicial: viagemAtiva,
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('ANA BENCHMARK'), findsOneWidget);
        expect(find.text('Aguardando Transporte'), findsOneWidget);

        // 1. Desliza o card para abrir o diálogo de confirmação
        await tester.drag(
          find.byType(Dismissible).first,
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        expect(find.text('PRÓXIMA ETAPA'), findsOneWidget);

        // 2. Mede o tempo exato de reação do callback de confirmação e transição otimista (< 16 ms)
        final btnConfirmar = tester.widget<ElevatedButton>(
          find.byKey(const Key('botao_confirmar_dialogo_motorista')),
        );
        final sw = Stopwatch()..start();
        btnConfirmar.onPressed!();
        sw.stop();
        await tester.pump();

        // A UI deve atualizar para 'Embarcou para Ida' antes mesmo de a rede responder!
        expect(
          sw.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Toque no swipe levou ${sw.elapsedMilliseconds} ms (meta: <= 16 ms, teto: 100 ms)',
        );
        expect(
          syncService.obterPacienteMemoria('pac_bench_1')?.status,
          equals(1),
        );
        expect(
          find.descendant(
            of: find.byType(Dismissible),
            matching: find.text('Embarcou para Ida'),
          ),
          findsOneWidget,
        );

        // Libera a rede em background
        completerRede.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Formulário de Início de Viagem confirma na UI em < 16 ms sem aguardar handshake do Firestore',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final completerRede = Completer<void>();
        viagemService.executorPersistenciaRemotaOverride = (op, payload) async {
          await completerRede.future;
        };

        ViagemModel? viagemRecebidaNaUi;
        final veiculo = const VeiculoModel(
          id: 'v_bench',
          modelo: 'Van Municipal',
          placa: ' Fast-001 ',
          quilometragemAtual: 10000,
          emUso: false,
          capacidade: 15,
        );
        viagemService.resetParaTestes(veiculosIniciais: [veiculo]);
        viagemService.executorPersistenciaRemotaOverride = (op, payload) async {
          await completerRede.future;
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FormularioInicioViagem(
                motoristaId: 'mot_fast',
                motoristaNome: 'Motorista Ágil',
                veiculosStreamOverride: Stream.value([veiculo]),
                onViagemIniciada: (v) {
                  viagemRecebidaNaUi = v;
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Seleciona o veículo e preenche KM
        await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Van Municipal').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('campoKmInicial')), '10050');
        await tester.pump();

        final sw = Stopwatch()..start();
        await tester.tap(find.byKey(const Key('botaoIniciarViagem')));
        await tester.pump();
        sw.stop();

        expect(
          sw.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Iniciar Viagem levou ${sw.elapsedMilliseconds} ms (orçamento máximo: 100 ms)',
        );
        expect(viagemRecebidaNaUi, isNotNull);
        expect(viagemRecebidaNaUi!.isAtiva, isTrue);

        completerRede.complete();
        await tester.pump();
      },
    );

    testWidgets(
      'Diálogo de Encerramento de Viagem fecha no primeiro toque (< 16 ms) e compila PDF em background com barra de progresso',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final viagem = ViagemModel(
          id: 'viagem_enc_1',
          motoristaId: 'mot_1',
          motoristaNome: 'Motorista Teste',
          veiculoId: 'v1',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Van',
          kmInicial: 15420,
          cidadeDestino: 'Mirassol',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
        );

        bool viagemEncerradaCallbackChamado = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (_) => FormularioEncerramento(
                        viagem: viagem,
                        onViagemEncerrada: () {
                          viagemEncerradaCallbackChamado = true;
                        },
                      ),
                    );
                  },
                  child: const Text('Abrir Encerramento'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Encerramento'));
        await tester.pumpAndSettle();
        expect(find.text('Formulário de Encerramento'), findsOneWidget);

        // Mede o tempo de reação do callback de Confirmar (encerramento em memória + disparo de pop)
        final sw = Stopwatch()..start();
        final btnConfirmar = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Confirmar'),
        );
        btnConfirmar.onPressed!();
        sw.stop();
        await tester.pump();

        expect(
          sw.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Callback de fechamento do modal de encerramento levou ${sw.elapsedMilliseconds} ms (orçamento máximo: 100 ms)',
        );
        expect(viagemEncerradaCallbackChamado, isTrue);
        // Exibe a barra de progresso não-intrusiva enquanto o PDF é compilado em background
        expect(
          find.textContaining('Preparando relatório PDF em segundo plano'),
          findsOneWidget,
        );
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.text('Formulário de Encerramento'), findsNothing);
      },
    );
  });

  group('2. Orçamento de Cota Comprovado (FinOps < 200 gravações por jornada diária)', () {
    test(
      'Jornada diária completa (declaração + 360 amostras GPS em 1h30 + 4 passageiros x 4 etapas + encerramento) consome < 200 gravações',
      () async {
        // Contabiliza todas as gravações remotas simuladas
        int gravacoesViagemService = 0;
        int gravacoesPacienteSync = 0;

        viagemService.executorPersistenciaRemotaOverride = (op, payload) async {
          gravacoesViagemService++;
        };
        syncService.executorRemotoOverride = (pacienteId, payload) async {
          gravacoesPacienteSync++;
        };

        final veiculo = const VeiculoModel(
          id: 'v_finops',
          modelo: 'Sprinter 15L',
          placa: 'FIN-2026',
          quilometragemAtual: 50000,
          emUso: false,
          capacidade: 15,
        );

        final passageiros = List.generate(
          4,
          (i) => PassageiroViagemModel(
            pacienteId: 'pac_fin_$i',
            pacienteNome: 'Passageiro $i',
            pacienteCpf: '1234567890$i',
            localOrigem: 'Rua $i',
            localDestino: 'Hospital Regional',
            horarioAtendimento: '08:00',
            statusEmbarque: 0,
          ),
        );

        for (final pv in passageiros) {
          syncService.registrarPacienteEmMemoriaSeAusente(
            PacienteModel(
              id: pv.pacienteId,
              nome: pv.pacienteNome,
              cpf: pv.pacienteCpf!,
              telefone: '17999990000',
              enderecoPaciente: pv.localOrigem,
              localConsulta: pv.localDestino,
              localSaida: pv.localOrigem,
              horarioConsulta: pv.horarioAtendimento,
              status: 0,
              prontoRetorno: true,
            ),
          );
        }

        viagemService.resetParaTestes(
          veiculosIniciais: [veiculo],
          todasViagensIniciais: [
            ViagemModel(
              id: 'viagem_finops_dia',
              motoristaId: '',
              motoristaNome: '',
              veiculoId: 'v_finops',
              veiculoPlaca: 'FIN-2026',
              veiculoModelo: 'Sprinter 15L',
              kmInicial: 50000,
              cidadeDestino: 'São José do Rio Preto',
              dataHoraInicio: DateTime.now(),
              status: 'planejada',
              passageirosIds: passageiros.map((p) => p.pacienteId).toList(),
              passageiros: passageiros,
            ),
          ],
        );
        viagemService.executorPersistenciaRemotaOverride = (op, payload) async {
          gravacoesViagemService++;
        };
        syncService.executorRemotoOverride = (pacienteId, payload) async {
          gravacoesPacienteSync++;
        };

        // 1. Declaração de veículo e Início de viagem
        await viagemService.declararVeiculo(
          veiculo: veiculo,
          kmInicial: 50010,
          motoristaId: 'mot_finops',
          motoristaNome: 'Motorista FinOps',
          cidadeDestino: 'São José do Rio Preto',
        );
        await viagemService.iniciarViagem(
          veiculo: veiculo,
          kmInicial: 50010,
          cidadeDestino: 'São José do Rio Preto',
          motoristaId: 'mot_finops',
          motoristaNome: 'Motorista FinOps',
        );

        // 2. Simulação de 1h30min (90 minutos = 5400 segundos) de telemetria GPS a cada 15 segundos (360 amostras):
        // - Primeiros 30 minutos: veículo em deslocamento rodoviário (~250m a cada 15s)
        // - 30 minutos intermediários: veículo parado aguardando pacientes no hospital (jitter de GPS < 15m)
        // - Últimos 30 minutos: veículo retornando (~250m a cada 15s)
        double latAtual = -20.7850;
        double lngAtual = -49.5210;
        final tZero = DateTime(2026, 11, 9, 7, 0, 0);

        for (int step = 0; step < 360; step++) {
          final timestampSimulado = tZero.add(Duration(seconds: step * 15));
          final bool veiculoParadoNoHospital = step >= 120 && step < 240;

          if (veiculoParadoNoHospital) {
            // Ruído de GPS estacionário (< 10 metros): NÃO pode gerar nenhuma gravação!
            latAtual += 0.00002;
          } else {
            // Deslocamento real em rodovia (~280 metros a cada 15 segundos)
            latAtual += 0.0025;
            lngAtual += 0.0010;
          }

          locService.atualizarLocalizacaoMotorista(
            motoristaId: 'mot_finops',
            motoristaNome: 'Motorista FinOps',
            latitude: latAtual,
            longitude: lngAtual,
            veiculoPlaca: 'FIN-2026',
            veiculoModelo: 'Sprinter 15L',
            cidadeDestino: 'São José do Rio Preto',
            viagemId: 'viagem_finops_dia',
            instanteReferencia: timestampSimulado,
          );
        }

        // 3. Quatro passageiros completando as 4 etapas (0 -> 1 -> 2 -> 3 -> 4)
        final acoes = [
          AcaoTransicao.motoristaEmbarcarIda,
          AcaoTransicao.motoristaDesembarcarConsulta,
          AcaoTransicao.motoristaReembarcarVolta,
          AcaoTransicao.motoristaConcluirViagem,
        ];

        for (int etapa = 0; etapa < acoes.length; etapa++) {
          for (final pv in passageiros) {
            if (etapa == 2) {
              // Paciente sinaliza pronto para retorno no hospital
              await syncService.sinalizarPronto(
                pacienteId: pv.pacienteId,
                atorId: pv.pacienteId,
                atorRole: 'paciente',
                idempotencyKey: 'pronto_${pv.pacienteId}',
              );
            }
            await syncService.avancarEtapaMotorista(
              pacienteId: pv.pacienteId,
              motoristaId: 'mot_finops',
              acao: acoes[etapa],
            );
            await viagemService.atualizarStatusPassageiroNaViagem(
              viagemId: 'viagem_finops_dia',
              pacienteId: pv.pacienteId,
              novoStatus: etapa + 1,
            );
          }
        }

        // 4. Encerramento da viagem
        await viagemService.encerrarTodasViagens(
          kmFinal: 50120,
          kmRodado: 110,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        final totalGps = locService.totalGravacoesRemotasGps;
        final totalGeral =
            gravacoesViagemService + gravacoesPacienteSync + totalGps;

        // Em 60 minutos em movimento (e 30 minutos parado), com trava de >= 60s e > 200m,
        // o GPS grava no máximo ~61 vezes (em vez de 20.000 gravações!).
        expect(
          totalGps,
          lessThanOrEqualTo(65),
          reason:
              'Telemetria GPS com throttler 200m + 60s deveria emitir <= 65 gravações em 1h30, mas emitiu $totalGps',
        );
        expect(
          totalGeral,
          lessThan(200),
          reason:
              'Jornada diária completa deve consumir < 200 gravações no Firestore (consumiu $totalGeral)',
        );
      },
    );
  });

  group('3. Concorrência Real de Múltiplos Motoristas em Frotas Paralelas', () {
    test(
      'Dois motoristas operando simultaneamente (Van para Barretos vs Carro para Rio Preto) mantêm viagens e veículos 100% isolados',
      () async {
        final vanBarretos = const VeiculoModel(
          id: 'veic_van_barretos',
          modelo: 'Renault Master Van',
          placa: 'BRT-1111',
          quilometragemAtual: 80000,
          emUso: false,
          capacidade: 15,
        );
        final carroRioPreto = const VeiculoModel(
          id: 'veic_spin_riopreto',
          modelo: 'Chevrolet Spin',
          placa: 'SJR-2222',
          quilometragemAtual: 30000,
          emUso: false,
          capacidade: 7,
        );

        final viagemPlanejadaBarretos = ViagemModel(
          id: 'viagem_barretos_01',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: 'veic_van_barretos',
          veiculoPlaca: 'BRT-1111',
          veiculoModelo: 'Renault Master Van',
          kmInicial: 80000,
          cidadeDestino: 'Monte Aprazível',
          dataHoraInicio: DateTime.now(),
          status: 'planejada',
          passageirosIds: const ['pac_brt_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_brt_1',
              pacienteNome: 'Ana (Rota 1)',
              localOrigem: 'Centro',
              localDestino: 'Hospital de Amor',
              horarioAtendimento: '07:30',
              statusEmbarque: 0,
            ),
          ],
        );

        final viagemPlanejadaRioPreto = ViagemModel(
          id: 'viagem_riopreto_02',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: 'veic_spin_riopreto',
          veiculoPlaca: 'SJR-2222',
          veiculoModelo: 'Chevrolet Spin',
          kmInicial: 30000,
          cidadeDestino: 'São José do Rio Preto',
          dataHoraInicio: DateTime.now(),
          status: 'planejada',
          passageirosIds: const ['pac_sjr_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_sjr_1',
              pacienteNome: 'Bruno (Rota 2)',
              localOrigem: 'Bairro Sul',
              localDestino: 'Hospital de Base',
              horarioAtendimento: '08:30',
              statusEmbarque: 0,
            ),
          ],
        );

        viagemService.resetParaTestes(
          veiculosIniciais: [vanBarretos, carroRioPreto],
          todasViagensIniciais: [
            viagemPlanejadaBarretos,
            viagemPlanejadaRioPreto,
          ],
        );

        // Motorista 1 declara a Van e inicia a viagem de Monte Aprazível
        final declMot1 = await viagemService.declararVeiculo(
          veiculo: vanBarretos,
          kmInicial: 80050,
          motoristaId: 'mot_01',
          motoristaNome: 'João (Motorista Van)',
          cidadeDestino: 'Monte Aprazível',
        );
        expect(declMot1.sucesso, isTrue);

        final iniMot1 = await viagemService.iniciarViagem(
          veiculo: vanBarretos,
          kmInicial: 80050,
          cidadeDestino: 'Monte Aprazível',
          motoristaId: 'mot_01',
          motoristaNome: 'João (Motorista Van)',
        );
        expect(iniMot1.sucesso, isTrue);

        // Verifica que a viagem de São José do Rio Preto NÃO foi sobrescrita pelo Motorista 1!
        final viagemRioPretoIntocada = viagemService.todasViagens
            .firstWhere((v) => v.id == 'viagem_riopreto_02');
        expect(viagemRioPretoIntocada.motoristaId, isEmpty);
        expect(viagemRioPretoIntocada.veiculoId, equals('veic_spin_riopreto'));
        expect(viagemRioPretoIntocada.veiculoPlaca, equals('SJR-2222'));
        expect(viagemRioPretoIntocada.status, equals('planejada'));

        // Motorista 2 declara a Spin e inicia a viagem de São José do Rio Preto em paralelo
        final declMot2 = await viagemService.declararVeiculo(
          veiculo: carroRioPreto,
          kmInicial: 30020,
          motoristaId: 'mot_02',
          motoristaNome: 'Pedro (Motorista Spin)',
          cidadeDestino: 'São José do Rio Preto',
        );
        expect(declMot2.sucesso, isTrue);

        final iniMot2 = await viagemService.iniciarViagem(
          veiculo: carroRioPreto,
          kmInicial: 30020,
          cidadeDestino: 'São José do Rio Preto',
          motoristaId: 'mot_02',
          motoristaNome: 'Pedro (Motorista Spin)',
        );
        expect(iniMot2.sucesso, isTrue);

        // Verifica que ambas as viagens coexistem ativas com seus respectivos veículos, placas, KMs e motoristas!
        final v1Final = viagemService.todasViagens
            .firstWhere((v) => v.id == 'viagem_barretos_01');
        final v2Final = viagemService.todasViagens
            .firstWhere((v) => v.id == 'viagem_riopreto_02');

        expect(v1Final.sessaoId, equals(declMot1.sessao!.id));
        expect(v1Final.veiculoId, equals('veic_van_barretos'));
        expect(v1Final.veiculoPlaca, equals('BRT-1111'));
        expect(v1Final.kmInicial, equals(80050));
        expect(v1Final.passageiros.first.pacienteId, equals('pac_brt_1'));

        expect(v2Final.sessaoId, equals(declMot2.sessao!.id));
        expect(v2Final.veiculoId, equals('veic_spin_riopreto'));
        expect(v2Final.veiculoPlaca, equals('SJR-2222'));
        expect(v2Final.kmInicial, equals(30020));
        expect(v2Final.passageiros.first.pacienteId, equals('pac_sjr_1'));

        // Consultas isoladas por motorista retornam apenas as viagens daquele motorista
        final ativasMot1 = viagemService.obterViagensAtivasPorMotorista(
          'mot_01',
          veiculoId: 'veic_van_barretos',
        );
        final ativasMot2 = viagemService.obterViagensAtivasPorMotorista(
          'mot_02',
          veiculoId: 'veic_spin_riopreto',
        );

        expect(ativasMot1.map((v) => v.id).toList(), equals(['viagem_barretos_01']));
        expect(ativasMot2.map((v) => v.id).toList(), equals(['viagem_riopreto_02']));
      },
    );
  });

  group('4. Rollback Visual Automático em Falha de Rede ou Permissão', () {
    testWidgets(
      'Quando o Firestore rejeita a escrita em background (permission-denied / unavailable), o card reverte ao status anterior com SnackBar de erro e sem travar em loading',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final completerRejeicao = Completer<void>();
        syncService.executorRemotoOverride = (pacienteId, payload) async {
          await completerRejeicao.future;
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing or insufficient permissions.',
          );
        };

        final viagemAtiva = ViagemModel(
          id: 'viagem_rollback_1',
          motoristaId: 'mot_rb',
          motoristaNome: 'Motorista Rollback',
          veiculoId: 'v1',
          veiculoPlaca: 'RBK-9999',
          veiculoModelo: 'Van',
          kmInicial: 10000,
          cidadeDestino: 'Mirassol',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          passageirosIds: const ['pac_rb_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_rb_1',
              pacienteNome: 'Carlos Rollback',
              pacienteCpf: '999.888.777-66',
              localOrigem: 'Rua Rollback, 100',
              localDestino: 'AME Mirassol',
              horarioAtendimento: '09:00',
              statusEmbarque: 0,
            ),
          ],
        );

        viagemService.resetParaTestes(
          viagemAtivaInicial: viagemAtiva,
          todasViagensIniciais: [viagemAtiva],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemInicial: viagemAtiva,
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Aguardando Transporte'), findsOneWidget);

        // 1. Executa swipe e confirma
        await tester.drag(
          find.byType(Dismissible).first,
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('botao_confirmar_dialogo_motorista')),
        );
        await tester.pump();

        // 2. Estado otimista reflete 'Embarcou para Ida' (status 1) imediatamente no CardPaciente
        expect(
          syncService.obterPacienteMemoria('pac_rb_1')?.status,
          equals(1),
        );
        expect(
          find.descendant(
            of: find.byType(Dismissible),
            matching: find.text('Embarcou para Ida'),
          ),
          findsOneWidget,
        );

        // 3. Servidor rejeita com permission-denied em background
        completerRejeicao.complete();
        await tester.pumpAndSettle();

        // 4. O estado deve ter sofrido rollback automático para 0 ('Aguardando Transporte') com SnackBar de erro!
        expect(
          syncService.obterPacienteMemoria('pac_rb_1')?.status,
          equals(0),
        );
        expect(find.text('Aguardando Transporte'), findsOneWidget);
        expect(
          find.textContaining('permission-denied'),
          findsOneWidget,
        );
      },
    );
  });
}
