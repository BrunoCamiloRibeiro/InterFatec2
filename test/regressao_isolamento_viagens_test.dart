// ============================================================================
// TESTES DE REGRESSÃO: Isolamento de Pacientes e Status por Viagem
// ============================================================================
// Garante que alterações de status feitas pelo motorista ou paciente em uma
// viagem não substituam listas nem contaminem status em outras viagens, mesmo
// quando o mesmo passageiro (mesmo ID) aparece em mais de uma viagem.
// ============================================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/footer_pacientes.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/screens/gerenciador_viagens_screen.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  late ViagemService viagemService;
  late PacienteSyncService syncService;

  setUp(() {
    viagemService = ViagemService();
    syncService = PacienteSyncService();
    viagemService.resetParaTestes(
      veiculosIniciais: const [
        VeiculoModel(
          id: 'veic_1',
          placa: 'ABC-1234',
          modelo: 'Renault Master',
          capacidade: 15,
          quilometragemAtual: 50000,
        ),
      ],
    );
    syncService.resetParaTestes();
  });

  tearDown(() {
    viagemService.executorPersistenciaRemotaOverride = null;
    syncService.executorRemotoOverride = null;
    viagemService.resetParaTestes();
    syncService.resetParaTestes();
  });

  group('Regressão: Isolamento de lista e status de passageiros por viagem', () {
    testWidgets(
      '1. Motorista alternando entre viagens mantém listas próprias e isola status de paciente compartilhado',
      (tester) async {
        final agora = DateTime(2026, 11, 10, 6, 0);
        final v1 = ViagemModel(
          id: 'viagem_barretos',
          motoristaId: 'mot_1',
          motoristaNome: 'Carlos Motorista',
          veiculoId: 'veic_1',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Renault Master',
          kmInicial: 50000,
          cidadeDestino: 'Barretos',
          dataHoraInicio: agora,
          status: 'ativa',
          passageirosIds: const ['pac_v1', 'pac_compartilhado'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_v1',
              pacienteNome: 'Maria Viagem Um',
              pacienteCpf: '111.111.111-11',
              localOrigem: 'UBS Centro',
              localDestino: 'Hospital de Amor Barretos',
              horarioAtendimento: '08:00',
              ordemEmbarque: 1,
              statusEmbarque: 0,
            ),
            PassageiroViagemModel(
              pacienteId: 'pac_compartilhado',
              pacienteNome: 'Pedro Compartilhado',
              pacienteCpf: '333.333.333-33',
              localOrigem: 'Rua A, 10',
              localDestino: 'Hospital de Amor Barretos',
              horarioAtendimento: '09:00',
              ordemEmbarque: 2,
              statusEmbarque: 0,
            ),
          ],
        );

        final v2 = ViagemModel(
          id: 'viagem_riopreto',
          motoristaId: 'mot_1',
          motoristaNome: 'Carlos Motorista',
          veiculoId: 'veic_1',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Renault Master',
          kmInicial: 50000,
          cidadeDestino: 'São José do Rio Preto',
          dataHoraInicio: agora.add(const Duration(hours: 2)),
          status: 'ativa',
          passageirosIds: const ['pac_v2', 'pac_compartilhado'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_v2',
              pacienteNome: 'Joana Viagem Dois',
              pacienteCpf: '222.222.222-22',
              localOrigem: 'Rua B, 20',
              localDestino: 'HB Rio Preto',
              horarioAtendimento: '10:30',
              ordemEmbarque: 1,
              statusEmbarque: 0,
            ),
            PassageiroViagemModel(
              pacienteId: 'pac_compartilhado',
              pacienteNome: 'Pedro Compartilhado',
              pacienteCpf: '333.333.333-33',
              localOrigem: 'Rua A, 10',
              localDestino: 'AME Rio Preto',
              horarioAtendimento: '11:00',
              ordemEmbarque: 2,
              statusEmbarque: 0,
            ),
          ],
        );

        viagemService.resetParaTestes(
          viagemAtivaInicial: v1,
          viagensAtivasIniciais: [v1, v2],
          todasViagensIniciais: [v1, v2],
        );

        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemInicial: v1,
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Viagem 1 exibe Maria Viagem Um + Pedro Compartilhado (ambos Aguardando Transporte)
        expect(find.text('MARIA VIAGEM UM'), findsOneWidget);
        expect(find.text('JOANA VIAGEM DOIS'), findsNothing);
        expect(find.text('Aguardando Transporte'), findsNWidgets(2));

        // Motorista avança Pedro Compartilhado na Viagem 1 (0 -> 1: Embarcou para Ida)
        final cardPedro = find.byKey(const ValueKey('pac_compartilhado'));
        await tester.ensureVisible(cardPedro);
        await tester.pumpAndSettle();
        await tester.drag(cardPedro, const Offset(-500, 0));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('botao_confirmar_dialogo_motorista')),
        );
        await tester.pumpAndSettle();

        expect(
          syncService
              .obterPacienteMemoria('pac_compartilhado', viagemId: v1.id)
              ?.status,
          equals(1),
        );
        expect(
          syncService
              .obterPacienteMemoria('pac_compartilhado', viagemId: v2.id)
              ?.status,
          equals(0),
        );

        // Alterna para a Viagem 2: deve exibir Joana Viagem Dois (NÃO Maria) e status 0 intacto
        await tester.tap(find.byTooltip('Próxima viagem'));
        await tester.pumpAndSettle();

        expect(find.text('JOANA VIAGEM DOIS'), findsOneWidget);
        expect(find.text('MARIA VIAGEM UM'), findsNothing);
        expect(find.text('PEDRO COMPARTILHADO'), findsOneWidget);
        expect(find.text('Aguardando Transporte'), findsNWidgets(2));
        expect(find.text('Embarcou para Ida'), findsNothing);

        // Retorna à Viagem 1: mantém Maria Viagem Um e o status atualizado de Pedro
        await tester.tap(find.byTooltip('Viagem anterior'));
        await tester.pumpAndSettle();

        expect(find.text('MARIA VIAGEM UM'), findsOneWidget);
        expect(find.text('JOANA VIAGEM DOIS'), findsNothing);
        expect(find.text('Embarcou para Ida'), findsOneWidget);
        expect(find.text('Aguardando Transporte'), findsOneWidget);
      },
    );

    test(
      '2. Concluir paciente em viagem_1 encerra apenas viagem_1 e preserva viagem_2 em andamento',
      () async {
        final v1 = ViagemModel(
          id: 'v_encerrar',
          motoristaId: 'mot_1',
          motoristaNome: 'Carlos Motorista',
          veiculoId: 'veic_1',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Renault Master',
          kmInicial: 50000,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime(2026, 11, 10, 6, 0),
          status: 'ativa',
          passageirosIds: const ['pac_shared'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_shared',
              pacienteNome: 'Paciente Compartilhado',
              localOrigem: 'UBS',
              localDestino: 'Barretos',
              horarioAtendimento: '08:00',
              statusEmbarque: 0,
            ),
          ],
        );
        final v2 = v1.copyWith(
          id: 'v_preservar',
          cidadeDestino: 'Rio Preto',
          dataHoraInicio: DateTime(2026, 11, 10, 14, 0),
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_shared',
              pacienteNome: 'Paciente Compartilhado',
              localOrigem: 'UBS',
              localDestino: 'Rio Preto',
              horarioAtendimento: '16:00',
              statusEmbarque: 0,
            ),
          ],
        );

        viagemService.resetParaTestes(
          viagemAtivaInicial: v1,
          viagensAtivasIniciais: [v1, v2],
          todasViagensIniciais: [v1, v2],
        );

        for (final acao in [
          AcaoTransicao.motoristaEmbarcarIda,
          AcaoTransicao.motoristaDesembarcarConsulta,
        ]) {
          final r = await syncService.avancarEtapaMotorista(
            pacienteId: 'pac_shared',
            motoristaId: 'mot_1',
            acao: acao,
            viagemId: v1.id,
          );
          await viagemService.atualizarStatusPassageiroNaViagem(
            viagemId: v1.id,
            pacienteId: 'pac_shared',
            novoStatus: r.paciente!.status,
            prontoRetorno: r.paciente!.prontoRetorno,
          );
        }

        final rPronto = await syncService.sinalizarPronto(
          pacienteId: 'pac_shared',
          atorId: 'pac_shared',
          atorRole: 'paciente',
          viagemId: v1.id,
        );
        await viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: v1.id,
          pacienteId: 'pac_shared',
          novoStatus: rPronto.paciente!.status,
          prontoRetorno: true,
          janelaReversao: rPronto.paciente!.janelaReversao,
        );

        for (final acao in [
          AcaoTransicao.motoristaReembarcarVolta,
          AcaoTransicao.motoristaConcluirViagem,
        ]) {
          final r = await syncService.avancarEtapaMotorista(
            pacienteId: 'pac_shared',
            motoristaId: 'mot_1',
            acao: acao,
            viagemId: v1.id,
          );
          await viagemService.atualizarStatusPassageiroNaViagem(
            viagemId: v1.id,
            pacienteId: 'pac_shared',
            novoStatus: r.paciente!.status,
            prontoRetorno: false,
            limparJanelaReversao: true,
          );
        }

        final v1Final = viagemService.todasViagens.firstWhere(
          (v) => v.id == v1.id,
        );
        final v2Final = viagemService.todasViagens.firstWhere(
          (v) => v.id == v2.id,
        );

        expect(v1Final.isConcluida, isTrue);
        expect(v1Final.passageiros.first.statusEmbarque, equals(4));

        expect(v2Final.isAtiva, isTrue);
        expect(v2Final.isConcluida, isFalse);
        expect(v2Final.passageiros.first.statusEmbarque, equals(0));
        expect(v2Final.passageiros.first.prontoRetorno, isFalse);
        expect(
          syncService
              .obterPacienteMemoria('pac_shared', viagemId: v2.id)
              ?.status,
          equals(0),
        );
      },
    );

    testWidgets(
      '3. Rollback otimista em viagem_1 reverte apenas viagem_1 sem afetar viagem_2',
      (tester) async {
        final completerFalha = Completer<void>();
        syncService.executorRemotoOverride = (pid, dados) async {
          await completerFalha.future;
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing permissions',
          );
        };

        final agora = DateTime(2026, 11, 10, 7, 0);
        final v1 = ViagemModel(
          id: 'v_rb_1',
          motoristaId: 'mot_1',
          motoristaNome: 'Carlos Motorista',
          veiculoId: 'veic_1',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Renault Master',
          kmInicial: 50000,
          cidadeDestino: 'Mirassol',
          dataHoraInicio: agora,
          status: 'ativa',
          passageirosIds: const ['pac_rb'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_rb',
              pacienteNome: 'Carlos Rollback',
              localOrigem: 'UBS',
              localDestino: 'AME Mirassol',
              horarioAtendimento: '08:00',
              statusEmbarque: 0,
            ),
          ],
        );
        final v2 = v1.copyWith(
          id: 'v_rb_2',
          cidadeDestino: 'Catanduva',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_rb',
              pacienteNome: 'Carlos Rollback',
              localOrigem: 'UBS',
              localDestino: 'Hospital Catanduva',
              horarioAtendimento: '14:00',
              statusEmbarque: 1,
            ),
          ],
        );

        viagemService.resetParaTestes(
          viagemAtivaInicial: v1,
          viagensAtivasIniciais: [v1, v2],
          todasViagensIniciais: [v1, v2],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemInicial: v1,
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const ValueKey('pac_rb')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('botao_confirmar_dialogo_motorista')),
        );
        await tester.pump();

        expect(
          syncService.obterPacienteMemoria('pac_rb', viagemId: v1.id)?.status,
          equals(1),
        );
        expect(
          syncService.obterPacienteMemoria('pac_rb', viagemId: v2.id)?.status,
          equals(1),
        );

        completerFalha.complete();
        await tester.pumpAndSettle();

        expect(
          syncService.obterPacienteMemoria('pac_rb', viagemId: v1.id)?.status,
          equals(0),
        );
        expect(
          syncService.obterPacienteMemoria('pac_rb', viagemId: v2.id)?.status,
          equals(1),
        );
        expect(
          viagemService.todasViagens
              .firstWhere((v) => v.id == v2.id)
              .passageiros
              .first
              .statusEmbarque,
          equals(1),
        );
      },
    );

    testWidgets(
      '4. GerenciadorViagensScreen exibe badges de status e pronto p/ retorno isolados por card de viagem',
      (tester) async {
        final dataDia = DateTime(2026, 11, 10);
        final pacAdmin = PacienteModel(
          id: 'pac_adm_1',
          nome: 'Ana Admin',
          cpf: '111.222.333-44',
          telefone: '(17) 99111-1111',
          enderecoPaciente: 'Rua 1, 100',
          localConsulta: 'HB',
          status: 0,
        );

        final vA = ViagemModel(
          id: 'v_admin_a',
          motoristaId: 'mot_1',
          motoristaNome: 'Carlos',
          veiculoId: 'veic_1',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Master',
          kmInicial: 50000,
          cidadeDestino: 'Barretos',
          nomeHorario: '06:00 - Barretos',
          dataViagem: dataDia,
          dataHoraInicio: DateTime(2026, 11, 10, 6, 0),
          status: 'ativa',
          passageirosIds: const ['pac_adm_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_adm_1',
              pacienteNome: 'Ana Admin',
              pacienteCpf: '111.222.333-44',
              localOrigem: 'Rua 1',
              localDestino: 'Hospital de Amor',
              horarioAtendimento: '08:00',
              statusEmbarque: 2,
              prontoRetorno: true,
            ),
          ],
        );
        final vB = ViagemModel(
          id: 'v_admin_b',
          motoristaId: 'mot_2',
          motoristaNome: 'Roberto',
          veiculoId: 'veic_1',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Master',
          kmInicial: 50100,
          cidadeDestino: 'Rio Preto',
          nomeHorario: '13:00 - Rio Preto',
          dataViagem: dataDia,
          dataHoraInicio: DateTime(2026, 11, 10, 13, 0),
          status: 'planejada',
          passageirosIds: const ['pac_adm_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_adm_1',
              pacienteNome: 'Ana Admin',
              pacienteCpf: '111.222.333-44',
              localOrigem: 'Rua 1',
              localDestino: 'HB Rio Preto',
              horarioAtendimento: '15:00',
              statusEmbarque: 0,
              prontoRetorno: false,
            ),
          ],
        );

        viagemService.resetParaTestes(
          todasViagensIniciais: [vA, vB],
          viagensAtivasIniciais: [vA],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GerenciadorViagensScreen(
              dataInicial: dataDia,
              pacientesIniciais: [pacAdmin],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cardA = find.byKey(const Key('cardHorario_v_admin_a'));
        final cardB = find.byKey(const Key('cardHorario_v_admin_b'));
        expect(cardA, findsOneWidget);
        expect(cardB, findsOneWidget);

        expect(
          find.descendant(
            of: cardA,
            matching: find.text('Desembarcou para Consulta'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: cardA,
            matching: find.text('Pronto p/ Retorno'),
          ),
          findsOneWidget,
        );

        expect(
          find.descendant(
            of: cardB,
            matching: find.text('Aguardando Transporte'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: cardB,
            matching: find.text('Pronto p/ Retorno'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      '5. FooterPacientes não sofre RenderFlex overflow em viewport móvel estreita (360x640)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final errosRender = <FlutterErrorDetails>[];
        final handlerOriginal = FlutterError.onError;
        FlutterError.onError = (details) {
          errosRender.add(details);
        };
        addTearDown(() {
          FlutterError.onError = handlerOriginal;
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              bottomNavigationBar: FooterPacientes(
                lugaresPreenchidos: 12,
                lugaresTotais: 15,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(errosRender, isEmpty);
        expect(find.text('Lugares: 12 / 15'), findsOneWidget);
        expect(
          find.byKey(const Key('textoLugaresDisponiveisFooter')),
          findsOneWidget,
        );
        expect(find.text('Disponíveis: 3'), findsOneWidget);
        expect(find.text('Gerar Relatório'), findsOneWidget);
      },
    );
  });
}
