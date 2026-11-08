// ============================================================================
// ARQUIVO: test/gerenciador_viagens_test.dart
// ----------------------------------------------------------------------------
// Testes unitários e de integração das regras de negócio do Gerenciador de
// Horários (CRUD de Viagens do Dia, Casos de Borda e RBAC - FASE 1):
// 1. Criação de Horário por Administrador (sucesso);
// 2. Bloqueio de criação/edição/cancelamento por perfis não-admin (RBAC);
// 3. Caso de borda: Conflito de motorista em horários simultâneos no mesmo dia;
// 4. Caso de borda: Conflito de veículo em horários simultâneos no mesmo dia;
// 5. Caso de borda: Lotação acima da capacidade máxima de assentos do veículo;
// 6. Caso de borda: Paciente agendado em múltiplos horários conflitantes no dia;
// 7. Caso de borda: Horário de atendimento anterior ou igual ao horário de saída;
// 8. Caso de borda: Acompanhante sem paciente titular vinculado;
// 9. Duplicação de grade completa de viagens de outro dia;
// 10. Reordenação sequencial do itinerário de embarque (1..N);
// 11. Cancelamento lógico (soft delete) com purga/invalidação de códigos.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/passageiro_viagem_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/validacao_viagem.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViagemService viagemService;
  final dataTeste = DateTime(2026, 11, 8);

  setUp(() {
    viagemService = ViagemService();
    viagemService.resetParaTestes(
      veiculosIniciais: const [
        VeiculoModel(
          id: 'v_spin',
          placa: 'ABC-1D23',
          modelo: 'Spin LTZ',
          capacidade: 7,
          quilometragemAtual: 50000,
        ),
        VeiculoModel(
          id: 'v_master',
          placa: 'BRA-2E45',
          modelo: 'Renault Master',
          capacidade: 16,
          quilometragemAtual: 100000,
        ),
      ],
      todasViagensIniciais: [],
    );
  });

  group('Fase 1 - CRUD e Gerenciador de Horários (Admin)', () {
    test('1. Admin cria Horário com dados válidos com sucesso', () async {
      final res = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '06:00 - Barretos',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_carlos',
        motoristaNome: 'Carlos Condutor',
        cidadeDestino: 'BARRETOS',
        passageiros: const [
          PassageiroViagemModel(
            pacienteId: 'pac_1',
            pacienteNome: 'João Silva',
            localDestino: 'Hospital de Amor',
            horarioAtendimento: '09:00',
            ordemEmbarque: 1,
          ),
        ],
        roleRequisitante: UserRole.admin,
      );

      expect(res.sucesso, isTrue);
      expect(res.viagem, isNotNull);
      expect(res.viagem!.isPlanejada, isTrue);
      expect(res.viagem!.tituloHorario, equals('06:00 - Barretos'));
      expect(res.viagem!.cidadeDestino, equals('BARRETOS'));
      expect(res.viagem!.passageiros.length, equals(1));
      expect(res.viagem!.totalAssentosOcupados, equals(1));

      final viagensDoDia = viagemService.obterViagensPorData(dataTeste);
      expect(viagensDoDia.length, equals(1));
    });

    test('2. Permissões RBAC: Somente admin cria, edita ou cancela horários', () async {
      // Tentativa de criação por perfil motorista
      final resCriacao = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '07:00 - Rio Preto',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_carlos',
        motoristaNome: 'Carlos Condutor',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        roleRequisitante: UserRole.motorista, // NÃO É ADMIN!
      );
      expect(resCriacao.sucesso, isFalse);
      expect(resCriacao.mensagemErro, contains('Apenas administradores'));

      // Cria como admin
      final resSucesso = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '07:00 - Rio Preto',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_carlos',
        motoristaNome: 'Carlos Condutor',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        roleRequisitante: UserRole.admin,
      );
      expect(resSucesso.sucesso, isTrue);

      // Tentativa de cancelamento por motorista
      final resCancelaMotorista = await viagemService.cancelarOuExcluirHorarioViagem(
        resSucesso.viagem!.id,
        roleRequisitante: UserRole.motorista,
      );
      expect(resCancelaMotorista.sucesso, isFalse);
      expect(resCancelaMotorista.mensagemErro, contains('Apenas administradores'));
    });

    test('3. Caso de borda: Conflito de motorista em horários simultâneos no mesmo dia', () async {
      // Cria primeiro horário às 06:00
      await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '06:00 - Barretos',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_carlos',
        motoristaNome: 'Carlos Condutor',
        cidadeDestino: 'BARRETOS',
        roleRequisitante: UserRole.admin,
      );

      // Tenta criar segundo horário às 06:00 com o MESMO motorista
      final resConflito = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '06:00 - Mirassol',
        veiculoId: 'v_master',
        veiculoPlaca: 'BRA-2E45',
        veiculoModelo: 'Renault Master',
        capacidadeVeiculo: 16,
        motoristaId: 'mot_carlos', // MESMO MOTORISTA!
        motoristaNome: 'Carlos Condutor',
        cidadeDestino: 'MIRASSOL',
        roleRequisitante: UserRole.admin,
      );

      expect(resConflito.sucesso, isFalse);
      expect(resConflito.mensagemErro, contains('já está escalado para outro Horário simultâneo'));
    });

    test('4. Caso de borda: Conflito de veículo em horários simultâneos no mesmo dia', () async {
      // Cria primeiro horário com veículo Spin
      await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '07:30 - Rio Preto HB',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_1',
        motoristaNome: 'Motorista 1',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        roleRequisitante: UserRole.admin,
      );

      // Tenta criar segundo horário no mesmo horário usando o MESMO veículo
      final resConflitoVeiculo = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '07:30 - Rio Preto AME',
        veiculoId: 'v_spin', // MESMO VEÍCULO!
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_2',
        motoristaNome: 'Motorista 2',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        roleRequisitante: UserRole.admin,
      );

      expect(resConflitoVeiculo.sucesso, isFalse);
      expect(resConflitoVeiculo.mensagemErro, contains('já está alocado para o Horário'));
    });

    test('5. Caso de borda: Lotação acima da capacidade do veículo', () async {
      // Veículo Spin tem capacidade 7
      // Adiciona 4 pacientes com 4 acompanhantes = 8 assentos ocupados
      final passageirosExcedentes = List.generate(4, (i) {
        return PassageiroViagemModel(
          pacienteId: 'pac_$i',
          pacienteNome: 'Paciente $i',
          acompanhanteNome: 'Acompanhante $i', // Ocupa 2 vagas cada
          localDestino: 'Hospital',
          horarioAtendimento: '09:00',
          ordemEmbarque: i + 1,
        );
      });

      final resCapacidade = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '08:00 - Catanduva',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_marcos',
        motoristaNome: 'Marcos Condutor',
        cidadeDestino: 'CATANDUVA',
        passageiros: passageirosExcedentes, // 4 * 2 = 8 vagas > 7!
        roleRequisitante: UserRole.admin,
      );

      expect(resCapacidade.sucesso, isFalse);
      expect(resCapacidade.mensagemErro, contains('Capacidade excedida: 8 passageiros para um veículo com 7 assentos'));
    });

    test('6. Caso de borda: Paciente agendado em múltiplos horários conflitantes no dia', () async {
      await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '06:00 - Barretos',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_1',
        motoristaNome: 'Motorista 1',
        cidadeDestino: 'BARRETOS',
        passageiros: const [
          PassageiroViagemModel(
            pacienteId: 'pac_maria',
            pacienteNome: 'Maria Santos',
            localDestino: 'Hospital de Amor',
            horarioAtendimento: '08:30',
          ),
        ],
        roleRequisitante: UserRole.admin,
      );

      // Tenta agendar pac_maria em outra viagem simultânea às 06:00
      final resConflitoPaciente = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '06:00 - Barretos',
        veiculoId: 'v_master',
        veiculoPlaca: 'BRA-2E45',
        veiculoModelo: 'Renault Master',
        capacidadeVeiculo: 16,
        motoristaId: 'mot_2',
        motoristaNome: 'Motorista 2',
        cidadeDestino: 'BARRETOS',
        passageiros: const [
          PassageiroViagemModel(
            pacienteId: 'pac_maria', // MESMA PACIENTE!
            pacienteNome: 'Maria Santos',
            localDestino: 'Hospital de Amor',
            horarioAtendimento: '08:30',
          ),
        ],
        roleRequisitante: UserRole.admin,
      );

      expect(resConflitoPaciente.sucesso, isFalse);
      expect(resConflitoPaciente.mensagemErro, contains('O paciente já consta agendado no Horário simultâneo'));
    });

    test('7. Caso de borda: Horário de atendimento anterior ou igual à saída do transporte', () {
      final validacaoIncompativel = ValidacaoViagem.validarCompatibilidadeHorarioConsulta(
        horarioSaida: '08:00',
        horarioAtendimento: '07:30', // Consulta ANTES da saída do carro!
      );
      expect(validacaoIncompativel.valido, isFalse);
      expect(validacaoIncompativel.mensagemErro, contains('incompatível: é anterior ou igual à saída'));

      final validacaoCompativel = ValidacaoViagem.validarCompatibilidadeHorarioConsulta(
        horarioSaida: '06:00',
        horarioAtendimento: '09:00',
      );
      expect(validacaoCompativel.valido, isTrue);
    });

    test('8. Caso de borda: Acompanhante sem paciente titular vinculado', () {
      final validacaoAcomp = ValidacaoViagem.validarAcompanhante(
        acompanhanteNome: 'Acompanhante Solto',
        pacienteId: '', // Paciente vazio!
      );
      expect(validacaoAcomp.valido, isFalse);
      expect(validacaoAcomp.mensagemErro, contains('Acompanhante não pode ser vinculado sem um paciente titular'));
    });

    test('9. Duplicação de grade completa de viagens de outro dia', () async {
      final dataOrigem = DateTime(2026, 11, 7);
      final dataDestino = DateTime(2026, 11, 8);

      // Cria 2 horários na dataOrigem
      await viagemService.criarHorarioViagem(
        data: dataOrigem,
        horario: '06:00 - Barretos',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_1',
        motoristaNome: 'Motorista 1',
        cidadeDestino: 'BARRETOS',
        roleRequisitante: UserRole.admin,
      );
      await viagemService.criarHorarioViagem(
        data: dataOrigem,
        horario: '08:30 - Rio Preto',
        veiculoId: 'v_master',
        veiculoPlaca: 'BRA-2E45',
        veiculoModelo: 'Master',
        capacidadeVeiculo: 16,
        motoristaId: 'mot_2',
        motoristaNome: 'Motorista 2',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        roleRequisitante: UserRole.admin,
      );

      final duplicadas = await viagemService.duplicarViagensDeOutroDia(
        dataOrigem: dataOrigem,
        dataDestino: dataDestino,
        roleRequisitante: UserRole.admin,
      );

      expect(duplicadas.length, equals(2));
      for (final d in duplicadas) {
        expect(d.isPlanejada, isTrue);
        expect(d.kmInicial, equals(0));
        expect(d.dataOperacional.day, equals(dataDestino.day));
      }

      final viagensDestino = viagemService.obterViagensPorData(dataDestino);
      expect(viagensDestino.length, equals(2));
    });

    test('10. Reordenação sequencial do itinerário de embarque (1..N)', () async {
      final res = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '06:00 - Rota Coleta',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_1',
        motoristaNome: 'Motorista 1',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        passageiros: const [
          PassageiroViagemModel(
            pacienteId: 'p1',
            pacienteNome: 'Primeiro',
            localDestino: 'HB',
            ordemEmbarque: 1,
          ),
          PassageiroViagemModel(
            pacienteId: 'p2',
            pacienteNome: 'Segundo',
            localDestino: 'HB',
            ordemEmbarque: 2,
          ),
        ],
        roleRequisitante: UserRole.admin,
      );

      final viagemOriginal = res.viagem!;
      // Inverte a ordem: [Segundo, Primeiro]
      final novaOrdem = [
        viagemOriginal.passageiros[1],
        viagemOriginal.passageiros[0],
      ];

      final resReordem = await viagemService.reordenarPassageiros(
        viagemOriginal.id,
        novaOrdem,
        roleRequisitante: UserRole.admin,
      );

      expect(resReordem.sucesso, isTrue);
      expect(resReordem.viagem!.passageiros.first.pacienteId, equals('p2'));
      expect(resReordem.viagem!.passageiros.first.ordemEmbarque, equals(1));
      expect(resReordem.viagem!.passageiros.last.pacienteId, equals('p1'));
      expect(resReordem.viagem!.passageiros.last.ordemEmbarque, equals(2));
    });

    test('11. Cancelamento lógico (soft delete) invalida códigos de acesso', () async {
      final res = await viagemService.criarHorarioViagem(
        data: dataTeste,
        horario: '06:00 - Viagem Ativa',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        capacidadeVeiculo: 7,
        motoristaId: 'mot_1',
        motoristaNome: 'Motorista 1',
        cidadeDestino: 'BARRETOS',
        passageiros: const [
          PassageiroViagemModel(
            pacienteId: 'p1',
            pacienteNome: 'Paciente 1',
            localDestino: 'Hospital',
          ),
        ],
        roleRequisitante: UserRole.admin,
      );

      final v = res.viagem!;
      // Emite código de acesso
      final codigo = await viagemService.gerarOuObterCodigoAcesso(
        viagemId: v.id,
        pacienteId: 'p1',
      );
      expect(codigo.isNotEmpty, isTrue);

      // Cancela a viagem
      final resCancelamento = await viagemService.cancelarOuExcluirHorarioViagem(
        v.id,
        softDelete: true,
        roleRequisitante: UserRole.admin,
      );

      expect(resCancelamento.sucesso, isTrue);
      expect(resCancelamento.viagem!.isCancelada, isTrue);
      expect(resCancelamento.viagem!.codigosAcesso.isEmpty, isTrue);
    });
  });
}
