import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/screens/gerenciador_viagens_screen.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/relatorio_pdf_service.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  setUp(() {
    ViagemService().resetParaTestes(
      veiculosIniciais: const [
        VeiculoModel(
          id: 'v1',
          placa: 'ABC-1D23',
          modelo: 'Chevrolet Spin 1.8 LTZ',
          capacidade: 7,
          quilometragemAtual: 85420,
          emUso: false,
        ),
      ],
    );
  });

  tearDown(() {
    ViagemService().resetParaTestes();
  });

  group('Fluxo do Motorista: Início de Viagem e Finalização com Confirmação', () {
    testWidgets(
      '1. Primeiro acesso do dia exibe FormularioInicioViagem para escolher veículo e KM inicial',
      (tester) async {
        // Inicializa o serviço sem viagem ativa
        expect(ViagemService().viagemAtiva, isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Motorista(),
          ),
        );
        // Processa microtask de carga de veículos
        await tester.pump();
        await tester.pumpAndSettle();

        // Deve exibir o formulário de início e seleção de veículo
        expect(find.text('Início da Viagem'), findsOneWidget);
        expect(find.text('Veículo da Frota'), findsOneWidget);
        expect(find.text('Quilometragem Inicial'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<VeiculoModel>), findsOneWidget);
        expect(find.byKey(const Key('campoKmInicial')), findsOneWidget);
        expect(find.byKey(const Key('botaoIniciarViagem')), findsOneWidget);

        // Não deve exibir a lista de passageiros enquanto não iniciar
        expect(find.text('Lista de Passageiros'), findsNothing);
      },
    );

    testWidgets(
      '2. Após iniciar viagem, exibe a Lista de Passageiros e NÃO exibe mais o formulário inicial',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Motorista(),
          ),
        );
        // Processa microtask de carga de veículos
        await tester.pump();
        await tester.pumpAndSettle();

        // Abre o dropdown de veículos da frota padrão (Poloni)
        await tester.tap(find.byType(DropdownButtonFormField<VeiculoModel>));
        await tester.pumpAndSettle();

        // Seleciona o primeiro veículo disponível na lista
        await tester.tap(find.textContaining('Spin').first);
        await tester.pumpAndSettle();

        // Inicia a viagem
        await tester.tap(find.byKey(const Key('botaoIniciarViagem')));
        await tester.pumpAndSettle();

        // Agora deve estar na Lista de Passageiros com a badge da viagem
        expect(find.text('Lista de Passageiros'), findsOneWidget);
        expect(find.text('Gerar Relatório'), findsOneWidget);

        // O formulário de início NÃO deve gerar uma nova viagem em todasViagens
        expect(ViagemService().todasViagens, isEmpty);

        // O formulário de início NÃO deve mais estar na tela
        expect(find.text('Veículo da Frota'), findsNothing);
      },
    );

    testWidgets(
      '3. Clicar em "Gerar Relatório" pergunta se tem certeza; se cancelar, continua na viagem',
      (tester) async {
        final viagemAtiva = ViagemModel(
          id: 'v_teste_123',
          motoristaId: 'mot_01',
          motoristaNome: 'João Motorista',
          veiculoId: 'veic_01',
          veiculoPlaca: 'ABC-1234',
          veiculoModelo: 'Spin',
          kmInicial: 10000,
          cidadeDestino: 'São José do Rio Preto',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(viagemInicial: viagemAtiva),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lista de Passageiros'), findsOneWidget);

        // Clica para gerar relatório
        await tester.tap(find.text('Gerar Relatório'));
        await tester.pumpAndSettle();

        // Deve exibir a pergunta de confirmação
        expect(find.byKey(const Key('dialogConfirmarFinalizacaoViagem')), findsOneWidget);
        expect(
          find.text('Você tem certeza que quer finalizar a viagem?'),
          findsOneWidget,
        );

        // Cancela a finalização
        await tester.tap(find.byKey(const Key('botaoCancelarFinalizacao')));
        await tester.pumpAndSettle();

        // Permanece na Lista de Passageiros com a viagem ainda ativa
        expect(find.text('Lista de Passageiros'), findsOneWidget);
        expect(find.text('Formulário de Encerramento'), findsNothing);
      },
    );

    testWidgets(
      '4. Clicar em "Gerar Relatório", confirmar e finalizar a viagem reseta a tela para o FormularioInicioViagem',
      (tester) async {
        final viagemService = ViagemService();
        final veiculoTeste = const VeiculoModel(
          id: 'veic_encerramento_01',
          placa: 'XYZ-9876',
          modelo: 'Spin LTZ',
          quilometragemAtual: 50000,
          capacidade: 7,
          emUso: false,
        );

        // Inicia a viagem no serviço
        await viagemService.iniciarViagem(
          veiculo: veiculoTeste,
          kmInicial: 50000,
          cidadeDestino: 'Barretos',
          motoristaId: 'mot_teste',
          motoristaNome: 'Carlos',
        );

        expect(viagemService.viagemAtiva, isNotNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Motorista(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lista de Passageiros'), findsOneWidget);

        // Clica para gerar relatório
        await tester.tap(find.text('Gerar Relatório'));
        await tester.pumpAndSettle();

        // Confirma que tem certeza que deseja finalizar a viagem
        expect(
          find.text('Você tem certeza que quer finalizar a viagem?'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('botaoConfirmarFinalizacao')));
        await tester.pumpAndSettle();

        // Abre o Formulário de Encerramento
        expect(find.text('Formulário de Encerramento'), findsOneWidget);

        // Preenche retorno e clica em Confirmar
        await tester.enterText(find.widgetWithText(TextField, '00:00'), '18:30');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 85650'), '50200');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 230'), '200');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Viagem deve estar encerrada no serviço
        expect(viagemService.viagemAtiva, isNull);

        // A tela do motorista deve ter resetado para o formulário de início de viagem
        expect(find.text('Início da Viagem'), findsOneWidget);
        expect(find.text('Veículo da Frota'), findsOneWidget);
        expect(find.byKey(const Key('campoKmInicial')), findsOneWidget);
      },
    );

    testWidgets(
      '5. Fechar a própria viagem redireciona o motorista para o FormularioInicioViagem, mas a viagem só finaliza se todos os pacientes tiverem voltado',
      (tester) async {
        final viagemService = ViagemService();
        final syncService = PacienteSyncService();
        syncService.resetParaTestes([
          PacienteModel(
            id: 'p_1',
            nome: 'Maria Oliveira',
            cpf: '111.222.333-44',
            telefone: '(17) 99111-1111',
            enderecoPaciente: 'Rua A, 10',
            localConsulta: 'Hospital de Base',
            status: 2, // Ainda no hospital (não voltou)
          ),
        ]);

        final viagemExterna = ViagemModel(
          id: 'horario_2026_11_8_999999',
          motoristaId: 'mot_01',
          motoristaNome: 'João Motorista',
          veiculoId: 'v1',
          veiculoPlaca: 'ABC-1D23',
          veiculoModelo: 'Chevrolet Spin 1.8 LTZ',
          kmInicial: 85420,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p_1',
              pacienteNome: 'Maria Oliveira',
              localOrigem: 'Rua A, 10',
              localDestino: 'Hospital de Base',
              horarioAtendimento: '10:30',
              ordemEmbarque: 1,
              statusEmbarque: 2,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(viagemInicial: viagemExterna),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lista de Passageiros'), findsOneWidget);
        expect(find.text('MARIA OLIVEIRA'), findsOneWidget);

        // Motorista 1 encerra a própria viagem com paciente ainda em status 2 (no hospital)
        await tester.tap(find.text('Gerar Relatório'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('botaoConfirmarFinalizacao')));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, '00:00'), '12:00');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 85650'), '85510');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 230'), '90');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Verifica redirecionamento imediato do motorista para FormularioInicioViagem
        expect(find.text('Início da Viagem'), findsOneWidget);
        expect(find.text('Lista de Passageiros'), findsNothing);

        // Porém a viagem NÃO finalizou ainda porque a paciente ainda não voltou (status == 2)
        final viagemParcial = viagemService.todasViagens
            .where((v) => v.id == 'horario_2026_11_8_999999')
            .firstOrNull;
        expect(viagemParcial, isNotNull);
        expect(viagemParcial!.isAtiva, isTrue);
        expect(viagemParcial.isConcluida, isFalse);
        expect(viagemParcial.passageiros.first.statusEmbarque, equals(2));

        // Agora outro motorista traz a paciente de volta (status -> 4)
        await viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: 'horario_2026_11_8_999999',
          pacienteId: 'p_1',
          novoStatus: 4,
        );

        final viagemFinal = viagemService.todasViagens
            .where((v) => v.id == 'horario_2026_11_8_999999')
            .firstOrNull;
        expect(viagemFinal, isNotNull);
        expect(viagemFinal!.isConcluida, isTrue);
        expect(viagemFinal.passageiros.first.statusEmbarque, equals(4));
      },
    );

    testWidgets(
      '6. Viagem criada sem veículo definido, lugares dependem da baixa do motorista e viagem só finaliza quando todos voltarem (independente do motorista)',
      (tester) async {
        final hoje = DateTime.now();
        final dataDia = DateTime(hoje.year, hoje.month, hoje.day);
        final viagemService = ViagemService();
        final syncService = PacienteSyncService();

        final p1 = PacienteModel(
          id: 'pac_status_1',
          nome: 'Ana Souza',
          cpf: '111.222.333-44',
          telefone: '(17) 99111-1111',
          enderecoPaciente: 'Rua 1, 100',
          localConsulta: 'HB Rio Preto',
          horarioConsulta: '09:00',
          status: 0,
        );
        final p2 = PacienteModel(
          id: 'pac_status_2',
          nome: 'Bruno Lima',
          cpf: '222.333.444-55',
          telefone: '(17) 99222-2222',
          enderecoPaciente: 'Rua 2, 200',
          localConsulta: 'AME Rio Preto',
          horarioConsulta: '10:00',
          status: 0,
        );
        syncService.resetParaTestes([p1, p2]);

        // 1. Admin cria Horário SEM definir veículo e SEM motorista vinculado
        final criacao = await viagemService.criarHorarioViagem(
          data: dataDia,
          horario: '06:00 - Rio Preto',
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_status_1',
              pacienteNome: 'Ana Souza',
              pacienteCpf: '111.222.333-44',
              localOrigem: 'Rua 1, 100',
              localDestino: 'HB Rio Preto',
              horarioAtendimento: '09:00',
              ordemEmbarque: 1,
              statusEmbarque: 0,
            ),
            PassageiroViagemModel(
              pacienteId: 'pac_status_2',
              pacienteNome: 'Bruno Lima',
              pacienteCpf: '222.333.444-55',
              localOrigem: 'Rua 2, 200',
              localDestino: 'AME Rio Preto',
              horarioAtendimento: '10:00',
              ordemEmbarque: 2,
              statusEmbarque: 0,
            ),
          ],
          roleRequisitante: UserRole.admin,
        );
        expect(criacao.sucesso, isTrue);
        expect(criacao.viagem!.veiculoId, isEmpty);
        expect(criacao.viagem!.motoristaId, isEmpty);
        expect(criacao.viagem!.motoristaNome, isEmpty);
        final viagemId = criacao.viagem!.id;
        expect(viagemService.todasViagens.length, equals(1));

        await tester.pumpWidget(
          MaterialApp(
            home: GerenciadorViagensScreen(
              dataInicial: dataDia,
              pacientesIniciais: [p1, p2],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica status PLANEJADA, veículo a definir pelo motorista e lugares com baixa = 0
        expect(find.text('PLANEJADA'), findsOneWidget);
        expect(find.text('Veículo: A definir pelo motorista'), findsOneWidget);
        expect(find.text('Lugares com baixa: 0 (veículo a definir)'), findsOneWidget);
        expect(find.text('Aguardando Transporte'), findsNWidgets(2));

        // 2. Motorista escolhe o veículo e inicia a viagem -> NÃO gera nova viagem, ativa a viagem existente sem vincular motorista
        await viagemService.iniciarViagem(
          veiculo: const VeiculoModel(
            id: 'v1',
            placa: 'ABC-1D23',
            modelo: 'Chevrolet Spin 1.8 LTZ',
            capacidade: 7,
            quilometragemAtual: 85420,
          ),
          kmInicial: 85420,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          motoristaId: 'mot_carlos',
          motoristaNome: 'Carlos Motorista',
        );
        await tester.pumpAndSettle();
        expect(viagemService.todasViagens.length, equals(1));
        expect(viagemService.todasViagens.first.motoristaId, isEmpty);
        expect(find.text('EM TRÂNSITO (ATIVA)'), findsOneWidget);
        expect(find.text('Veículo: ABC-1D23 (Chevrolet Spin 1.8 LTZ)'), findsOneWidget);
        expect(find.text('Lugares: 0 / 7 (7 disponíveis)'), findsOneWidget);

        // 3. Testa transição dos status e atualização dinâmica de lugares disponíveis/preenchidos conforme a baixa
        // Paciente 2 solicita cancelamento -> status 5 ('Cancelado')
        await syncService.solicitarCancelamento(
          pacienteId: 'pac_status_2',
          atorId: 'pac_status_2',
          atorRole: 'paciente',
        );
        await viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: viagemId,
          pacienteId: 'pac_status_2',
          novoStatus: 5,
        );
        await tester.pumpAndSettle();
        expect(find.text('Cancelado'), findsOneWidget);

        // Motorista 1 dá baixa de embarque na Paciente 1 -> status 1 ('Embarcou para Ida') -> 1 lugar preenchido, 6 disponíveis!
        await syncService.avancarEtapaMotorista(
          pacienteId: 'pac_status_1',
          motoristaId: 'mot_carlos',
          acao: AcaoTransicao.motoristaEmbarcarIda,
        );
        await viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: viagemId,
          pacienteId: 'pac_status_1',
          novoStatus: 1,
        );
        await tester.pumpAndSettle();
        expect(find.text('Embarcou para Ida'), findsOneWidget);
        expect(find.text('Lugares: 1 / 7 (6 disponíveis)'), findsOneWidget);

        // Paciente 1 desembarca para consulta -> status 2 ('Desembarcou para Consulta')
        await syncService.avancarEtapaMotorista(
          pacienteId: 'pac_status_1',
          motoristaId: 'mot_carlos',
          acao: AcaoTransicao.motoristaDesembarcarConsulta,
        );
        await viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: viagemId,
          pacienteId: 'pac_status_1',
          novoStatus: 2,
        );
        await tester.pumpAndSettle();
        expect(find.text('Desembarcou para Consulta'), findsOneWidget);

        // 4. Motorista 1 encerra a PRÓPRIA viagem enquanto Paciente 1 ainda está no hospital (status 2):
        //    a sessão do Motorista 1 encerra, mas a viagem continua 'EM TRÂNSITO (ATIVA)'!
        await viagemService.encerrarTodasViagens(
          kmFinal: 85510,
          kmRodado: 90,
        );
        await tester.pumpAndSettle();
        expect(viagemService.viagemAtiva, isNull);
        expect(find.text('EM TRÂNSITO (ATIVA)'), findsOneWidget);
        expect(find.text('CONCLUÍDA'), findsNothing);

        // Paciente 1 sinaliza que está pronta -> badge 'Pronto p/ Retorno'
        await syncService.sinalizarPronto(
          pacienteId: 'pac_status_1',
          atorId: 'pac_status_1',
          atorRole: 'paciente',
        );
        await tester.pumpAndSettle();
        expect(find.text('Pronto p/ Retorno'), findsOneWidget);

        // 5. OUTRO motorista ('mot_roberto') inicia veículo, reembarca Paciente 1 para volta (status 3) e conclui o retorno (status 4):
        //    assim que todos os pacientes ficam com status concluído, a viagem finaliza INSTANTANEAMENTE e desaparece para os motoristas!
        await viagemService.iniciarViagem(
          veiculo: const VeiculoModel(
            id: 'v1',
            placa: 'ABC-1D23',
            modelo: 'Chevrolet Spin 1.8 LTZ',
            capacidade: 7,
            quilometragemAtual: 85510,
          ),
          kmInicial: 85510,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          motoristaId: 'mot_roberto',
          motoristaNome: 'Roberto Motorista',
        );
        expect(viagemService.viagensAtivas.any((v) => v.id == viagemId), isTrue);

        await syncService.avancarEtapaMotorista(
          pacienteId: 'pac_status_1',
          motoristaId: 'mot_roberto',
          acao: AcaoTransicao.motoristaReembarcarVolta,
        );
        await tester.pumpAndSettle();
        expect(find.text('Reembarcou para Volta'), findsOneWidget);

        await syncService.avancarEtapaMotorista(
          pacienteId: 'pac_status_1',
          motoristaId: 'mot_roberto',
          acao: AcaoTransicao.motoristaConcluirViagem,
        );
        await tester.pumpAndSettle();

        // A viagem finalizou instantaneamente e não aparece mais nas viagens ativas para os motoristas
        expect(viagemService.viagensAtivas.any((v) => v.id == viagemId), isFalse);
        expect(find.text('CONCLUÍDA'), findsOneWidget);
        expect(find.byKey(Key('bannerViagemConcluida_$viagemId')), findsOneWidget);
        expect(find.textContaining('Viagem concluída pelo motorista'), findsOneWidget);
        expect(find.text('Concluído'), findsOneWidget);
        expect(find.text('Cancelado'), findsOneWidget);

        // 6. Mesmo após a viagem ter auto-concluído, o relatório recupera a viagem, veículo e passageiros para gerar o PDF
        final viagensRel = viagemService.obterViagensParaRelatorio();
        expect(viagensRel, isNotEmpty);
        final vRel = viagensRel.firstWhere((v) => v.id == viagemId);
        expect(vRel.veiculoPlaca, equals('ABC-1D23'));
        final pacsRel = viagemService.obterPacientesParaViagemRelatorio(vRel);
        expect(pacsRel.length, equals(2));
        final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
          viagem: vRel,
          pacientes: pacsRel,
          retornoInformado: '16:45',
          kmRetornoInformado: 85600,
          kmRodadoInformado: 90,
        );
        expect(pdfBytes, isNotEmpty);

        // 7. Criar uma NOVA viagem com paciente que estava em status == 4 na viagem anterior NÃO deve entrar como CONCLUÍDA
        final novaCriacao = await viagemService.criarHorarioViagem(
          data: dataDia.add(const Duration(days: 1)),
          horario: '07:00 - Rio Preto',
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_status_1',
              pacienteNome: 'Ana Souza',
              pacienteCpf: '111.222.333-44',
              localOrigem: 'Rua 1, 100',
              localDestino: 'HB Rio Preto',
              horarioAtendimento: '09:00',
              ordemEmbarque: 1,
              statusEmbarque: 0,
            ),
          ],
          roleRequisitante: UserRole.admin,
        );
        expect(novaCriacao.sucesso, isTrue);
        expect(novaCriacao.viagem!.isPlanejada, isTrue);
        expect(novaCriacao.viagem!.isConcluida, isFalse);
        expect(viagemService.todosPacientesVoltaram(novaCriacao.viagem!), isFalse);
        expect(syncService.obterPacienteMemoria('pac_status_1')?.status, equals(0));
      },
    );
  });
}
