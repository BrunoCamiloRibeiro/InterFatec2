import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/screens/gerenciador_viagens_screen.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final viagemService = ViagemService();
  final syncService = PacienteSyncService();

  setUp(() {
    FirebaseAuthService().clearRoleCache();
    FirebaseAuthService.motoristaEmViagemStatic = null;
    viagemService.resetParaTestes();
    syncService.resetParaTestes([]);
  });

  tearDown(() {
    viagemService.encerrarEscutasFirestore();
    viagemService.limparSessaoLocal();
  });

  group('Rastreamento de Motorista no Swipe & Contador de Lugares por Motorista', () {
    test('PassageiroViagemModel serializa e desserializa motoristaId e motoristaNome', () {
      const original = PassageiroViagemModel(
        pacienteId: 'p1',
        pacienteNome: 'Lucas Ferreira',
        localOrigem: 'Rua dos Parques',
        localDestino: 'HB',
        horarioAtendimento: '16:00',
        statusEmbarque: 1,
        motoristaId: 'mot_a',
        motoristaNome: 'Carlos Silva',
      );

      final map = original.toMap();
      expect(map['motoristaId'], equals('mot_a'));
      expect(map['motoristaNome'], equals('Carlos Silva'));

      final reconstruido = PassageiroViagemModel.fromMap(map);
      expect(reconstruido, equals(original));
      expect(reconstruido.motoristaId, equals('mot_a'));
      expect(reconstruido.motoristaNome, equals('Carlos Silva'));

      final limpo = reconstruido.copyWith(limparMotorista: true);
      expect(limpo.motoristaId, isNull);
      expect(limpo.motoristaNome, isNull);
    });

    testWidgets(
      'Swipe do passageiro registra motoristaId e adiciona lugares apenas no contador do motorista que deu o embarque (mesmo se outro encerrar/reembarcar)',
      (tester) async {
        final hoje = DateTime.now();
        final dataDia = DateTime(hoje.year, hoje.month, hoje.day);

        const veicVanA = VeiculoModel(
          id: 'veic_a',
          placa: 'AAA-1111',
          modelo: 'Spin 7L',
          capacidade: 7,
          quilometragemAtual: 10000,
        );
        const veicVanB = VeiculoModel(
          id: 'veic_b',
          placa: 'BBB-2222',
          modelo: 'Ducato 15L',
          capacidade: 15,
          quilometragemAtual: 20000,
        );

        final criacao = await viagemService.criarHorarioViagem(
          data: dataDia,
          horario: '07:00 - Rio Preto',
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_swipe_1',
              pacienteNome: 'Lucas Ferreira',
              pacienteCpf: '998.004.870-00',
              pacienteTelefone: '(99) 99999-9999',
              acompanhanteNome: 'Maria Ferreira',
              localOrigem: 'Rua dos Parques',
              localDestino: 'HB',
              horarioAtendimento: '16:00',
              ordemEmbarque: 1,
              statusEmbarque: 0,
            ),
          ],
          roleRequisitante: UserRole.admin,
        );
        expect(criacao.sucesso, isTrue);
        final viagemId = criacao.viagem!.id;

        viagemService.resetParaTestes(
          veiculosIniciais: const [veicVanA, veicVanB],
          todasViagensIniciais: [criacao.viagem!],
        );

        // 1. Motorista A inicia viagem e realiza o swipe (0 -> 1) no card do passageiro
        await viagemService.iniciarViagem(
          veiculo: veicVanA,
          kmInicial: 10000,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lugares: 0 / 7'), findsOneWidget);

        // Swipe para a esquerda -> diálogo de confirmação -> Confirmar
        await tester.drag(
          find.byKey(const ValueKey('pac_swipe_1')),
          const Offset(-400, 0),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('botao_confirmar_dialogo_motorista')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('botao_confirmar_dialogo_motorista')),
        );
        await tester.pumpAndSettle();

        // Verifica atribuição do motorista no PassageiroViagemModel e contagem 2/7 para Motorista A
        final pvAposEmbarqueA = viagemService.todasViagens
            .firstWhere((v) => v.id == viagemId)
            .passageiros
            .first;
        expect(pvAposEmbarqueA.statusEmbarque, equals(1));
        expect(pvAposEmbarqueA.motoristaId, equals('mot_a'));
        expect(pvAposEmbarqueA.motoristaNome, equals('Motorista A'));
        expect(find.text('Lugares: 2 / 7'), findsOneWidget);
        expect(find.text('Disponíveis: 5'), findsOneWidget);

        // 2. Motorista B entra em outro veículo na mesma viagem:
        //    passageiro ainda está embarcado com Motorista A (status 1, motoristaId='mot_a'),
        //    então NÃO deve somar assentos no contador de lugares do Motorista B.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        viagemService.limparSessaoLocal();

        await viagemService.iniciarViagem(
          veiculo: veicVanB,
          kmInicial: 20000,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lugares: 0 / 15'), findsOneWidget);
        expect(find.text('Disponíveis: 15'), findsOneWidget);

        // 3. Paciente desembarca (1 -> 2) e em seguida Motorista B reembarca para volta (2 -> 3)
        await syncService.avancarEtapaMotorista(
          pacienteId: 'pac_swipe_1',
          motoristaId: 'mot_a',
          acao: AcaoTransicao.motoristaDesembarcarConsulta,
          viagemId: viagemId,
        );
        await viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: viagemId,
          pacienteId: 'pac_swipe_1',
          novoStatus: 2,
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
        );
        await syncService.sinalizarPronto(
          pacienteId: 'pac_swipe_1',
          atorId: 'pac_swipe_1',
          atorRole: 'paciente',
          viagemId: viagemId,
        );
        await viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: viagemId,
          pacienteId: 'pac_swipe_1',
          novoStatus: 2,
          prontoRetorno: true,
        );
        await tester.pumpAndSettle();
        expect(find.text('Lugares: 0 / 15'), findsOneWidget);

        // Agora Motorista B dá swipe para reembarcar na volta (2 -> 3)
        await tester.drag(
          find.byKey(const ValueKey('pac_swipe_1')),
          const Offset(-400, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('botao_confirmar_dialogo_motorista')),
        );
        await tester.pumpAndSettle();

        final pvAposReembarqueB = viagemService.todasViagens
            .firstWhere((v) => v.id == viagemId)
            .passageiros
            .first;
        expect(pvAposReembarqueB.statusEmbarque, equals(3));
        expect(pvAposReembarqueB.motoristaId, equals('mot_b'));
        expect(find.text('Lugares: 2 / 15'), findsOneWidget);
        expect(find.text('Disponíveis: 13'), findsOneWidget);
      },
    );
  });

  group('Encerramento de Relatório sem Finalizar Pendências', () {
    testWidgets(
      'Gerar relatório com pacientes em Aguardando (0) e Desembarcou (2) mantém viagem ativa, preserva pendências, reexibe ao trocar de carro/motorista e mantém ativa no Admin',
      (tester) async {
        final hoje = DateTime.now();
        final dataDia = DateTime(hoje.year, hoje.month, hoje.day);

        const veic1 = VeiculoModel(
          id: 'veic_carro_1',
          placa: 'ABC-1D23',
          modelo: 'Spin LTZ',
          capacidade: 7,
          quilometragemAtual: 50000,
        );
        const veic2 = VeiculoModel(
          id: 'veic_carro_2',
          placa: 'DEF-4G56',
          modelo: 'Ducato Minibus',
          capacidade: 15,
          quilometragemAtual: 73000,
        );

        final pDesembarcou = PacienteModel(
          id: 'pac_pend_2',
          nome: 'Ana Desembarcou',
          cpf: '111.111.111-11',
          telefone: '(17) 99111-1111',
          enderecoPaciente: 'Rua Um, 10',
          localConsulta: 'Hospital de Base',
          horarioConsulta: '08:00',
          status: 2,
        );
        final pAguardando = PacienteModel(
          id: 'pac_pend_0',
          nome: 'Bruno Aguardando',
          cpf: '222.222.222-22',
          telefone: '(17) 99222-2222',
          enderecoPaciente: 'Rua Dois, 20',
          localConsulta: 'AME',
          horarioConsulta: '10:00',
          status: 0,
        );

        syncService.resetParaTestes([pDesembarcou, pAguardando]);

        final viagemBase = ViagemModel(
          id: 'horario_pendentes_01',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: '',
          veiculoPlaca: '',
          veiculoModelo: '',
          kmInicial: 50000,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          nomeHorario: '06:00 - Rio Preto',
          dataHoraInicio: DateTime(dataDia.year, dataDia.month, dataDia.day, 6),
          status: 'ativa',
          passageirosIds: const ['pac_pend_2', 'pac_pend_0'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_pend_2',
              pacienteNome: 'Ana Desembarcou',
              pacienteCpf: '111.111.111-11',
              localOrigem: 'Rua Um, 10',
              localDestino: 'Hospital de Base',
              horarioAtendimento: '08:00',
              ordemEmbarque: 1,
              statusEmbarque: 2,
              motoristaId: 'mot_a',
              motoristaNome: 'Motorista A',
            ),
            PassageiroViagemModel(
              pacienteId: 'pac_pend_0',
              pacienteNome: 'Bruno Aguardando',
              pacienteCpf: '222.222.222-22',
              localOrigem: 'Rua Dois, 20',
              localDestino: 'AME',
              horarioAtendimento: '10:00',
              ordemEmbarque: 2,
              statusEmbarque: 0,
            ),
          ],
        );

        viagemService.resetParaTestes(
          veiculosIniciais: const [veic1, veic2],
          todasViagensIniciais: [viagemBase],
        );

        await viagemService.iniciarViagem(
          veiculo: veic1,
          kmInicial: 50000,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ANA DESEMBARCOU'), findsOneWidget);
        expect(find.text('BRUNO AGUARDANDO'), findsOneWidget);

        // Abre diálogo de encerramento/relatório e verifica aviso correto (sem prometer marcar como Concluído)
        await tester.tap(find.text('Gerar Relatório'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('permanecerão com o status atual na viagem'),
          findsOneWidget,
        );
        expect(find.textContaining('serão marcados como Concluídos'), findsNothing);

        await tester.tap(find.byKey(const Key('botaoConfirmarFinalizacao')));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, '00:00'), '12:30');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 85650'), '50150');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 230'), '150');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Sessão encerrada e motorista voltou ao início, veículo 1 liberado com KM atualizado
        expect(find.text('Início da Viagem'), findsOneWidget);
        expect(viagemService.viagemAtiva, isNull);
        final veic1Pos =
            viagemService.todosVeiculos.firstWhere((v) => v.id == 'veic_carro_1');
        expect(veic1Pos.emUso, isFalse);
        expect(veic1Pos.quilometragemAtual, equals(50150));

        // Viagem segue ativa no banco e os passageiros pendentes mantêm 2 e 0
        final vPos = viagemService.todasViagens
            .firstWhere((v) => v.id == 'horario_pendentes_01');
        expect(vPos.status, equals('ativa'));
        expect(vPos.isConcluida, isFalse);
        expect(
          vPos.passageiros
              .firstWhere((p) => p.pacienteId == 'pac_pend_2')
              .statusEmbarque,
          equals(2),
        );
        expect(
          vPos.passageiros
              .firstWhere((p) => p.pacienteId == 'pac_pend_0')
              .statusEmbarque,
          equals(0),
        );

        // Mesmo motorista entra novamente com OUTRO carro (veic_carro_2): vê os pendentes
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await viagemService.iniciarViagem(
          veiculo: veic2,
          kmInicial: 73000,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lista de Passageiros'), findsOneWidget);
        expect(find.text('ANA DESEMBARCOU'), findsOneWidget);
        expect(find.text('BRUNO AGUARDANDO'), findsOneWidget);
        expect(find.text('Desembarcou para Consulta'), findsOneWidget);
        expect(find.text('Aguardando Transporte'), findsOneWidget);

        // Outro motorista (Motorista B) também enxerga os mesmos pendentes ativos
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        viagemService.limparSessaoLocal();
        await viagemService.iniciarViagem(
          veiculo: veic1,
          kmInicial: 50150,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ANA DESEMBARCOU'), findsOneWidget);
        expect(find.text('BRUNO AGUARDANDO'), findsOneWidget);

        // No painel administrativo a viagem permanece EM TRÂNSITO (ATIVA), nunca CONCLUÍDA
        await tester.pumpWidget(
          MaterialApp(
            home: GerenciadorViagensScreen(
              dataInicial: dataDia,
              pacientesIniciais: [pDesembarcou, pAguardando],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('EM TRÂNSITO (ATIVA)'), findsOneWidget);
        expect(find.text('CONCLUÍDA'), findsNothing);
        expect(
          find.byKey(const Key('bannerViagemConcluida_horario_pendentes_01')),
          findsNothing,
        );
        expect(find.text('Desembarcou para Consulta'), findsOneWidget);
        expect(find.text('Aguardando Transporte'), findsOneWidget);
      },
    );
  });
}
