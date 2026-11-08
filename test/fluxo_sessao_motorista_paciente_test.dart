// ============================================================================
// TESTE DE INTEGRAÇÃO DE PONTA A PONTA: FLUXO COMPLETO SESSÃO MOTORISTA-PACIENTE
// ----------------------------------------------------------------------------
// Repositório: BrunoCamiloRibeiro/InterFatec2
// Contexto: Issue #65 - Declaração de Veículo, Sessão com N Viagens, Embarque,
//           Geração Criptográfica de Código, Login de Paciente/Acompanhante e Encerramento.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/codigo_acesso_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  group('Fluxo Completo de Ponta a Ponta: Sessão Motorista -> Embarque -> Login Paciente/Acompanhante -> Encerramento', () {
    late ViagemService viagemService;
    late FirebaseAuthService authService;

    // Veículo de teste oficial
    final veiculoTeste = VeiculoModel(
      id: 'veic_spin_01',
      modelo: 'Chevrolet Spin 1.8 7L',
      placa: 'BRA-2E19',
      quilometragemAtual: 50000,
      capacidade: 7,
      emUso: false,
    );

    // Paciente 1: Possui CPF próprio válido
    // CPF 529.982.247-25 é matematicamente válido no algoritmo módulo 11
    final pacienteComCpf = PacienteModel(
      id: 'pac_01_titular',
      nome: 'Maria Silva Poloni',
      cpf: '529.982.247-25',
      enderecoPaciente: 'Rua das Flores, 10 - Centro',
      telefone: '(17) 99111-2222',
      localConsulta: 'Hospital de Base de Rio Preto',
      localSaida: 'UBS Poloni',
      status: 0, // Inicialmente agendado
    );

    // Paciente 2: Criança sem CPF, possui acompanhante com CPF válido
    // CPF da mãe acompanhante: 301.894.649-92 (válido módulo 11)
    final pacienteCriancaComMae = PacienteModel(
      id: 'pac_02_crianca',
      nome: 'Pedro Henrique da Silva (Menor)',
      cpf: '', // Sem documento próprio
      nomeAcompanhante: 'Ana Paula Silva (Mãe)',
      cpfAcompanhante: '301.894.649-92',
      enderecoPaciente: 'Rua das Flores, 10 - Centro',
      telefone: '(17) 99111-2222',
      localConsulta: 'Hospital da Criança e Maternidade (HCM)',
      localSaida: 'UBS Poloni',
      status: 0,
    );

    // Paciente 3: Idoso sem CPF cadastrado, mas com RG registrado
    final pacienteComRg = PacienteModel(
      id: 'pac_03_rg',
      nome: 'Benedito da Silva',
      cpf: '',
      rg: 'MG-12.345.678',
      enderecoPaciente: 'Sítio Boa Esperança, Rural',
      telefone: '(17) 99333-4444',
      localConsulta: 'AME Rio Preto',
      localSaida: 'UBS Poloni',
      status: 0,
    );

    setUp(() {
      // 1. Reseta os bloqueios de rate limiting da memória
      CodigoAcessoService.resetarRateLimitParaTestes();

      // 2. Reseta o singleton ViagemService para ambiente isolado
      viagemService = ViagemService();
      viagemService.resetParaTestes(
        veiculosIniciais: [veiculoTeste],
        sessaoAtivaInicial: null,
        viagensAtivasIniciais: [],
      );

      // 3. Inicializa o serviço de autenticação
      authService = FirebaseAuthService();
      authService.clearRoleCache();
    });

    test('Executa o ciclo completo de vida operacional com múltiplas viagens e perfis de passageiros', () async {
      // ======================================================================
      // ETAPA 1: O MOTORISTA DECLARA O VEÍCULO (Início da Jornada)
      // ======================================================================
      final resultadoDeclaracao = await viagemService.declararVeiculo(
        veiculo: veiculoTeste,
        kmInicial: 50000,
        motoristaId: 'mot_carlos_01',
        motoristaNome: 'Carlos Motorista da Saúde',
      );

      expect(resultadoDeclaracao.sucesso, isTrue);
      expect(resultadoDeclaracao.sessao, isNotNull);
      final sessao = resultadoDeclaracao.sessao!;
      expect(sessao.status, equals('ativa'));
      expect(sessao.veiculoPlaca, equals('BRA-2E19'));
      expect(sessao.kmInicial, equals(50000));
      expect(viagemService.sessaoAtiva?.id, equals(sessao.id));

      // ======================================================================
      // ETAPA 2: CRIAÇÃO DE N = 2 VIAGENS VINCULADAS À SESSÃO DO VEÍCULO
      // ======================================================================
      // Viagem 1: Manhã -> Hospital de Base de São José do Rio Preto
      final resViagem1 = await viagemService.criarOuAdicionarViagemNaSessao(
        cidadeDestino: 'São José do Rio Preto',
        passageirosIds: [pacienteComCpf.id, pacienteCriancaComMae.id],
      );
      expect(resViagem1.sucesso, isTrue);
      final viagem1 = resViagem1.viagem!;
      expect(viagem1.sessaoId, equals(sessao.id));
      expect(viagem1.cidadeDestino, equals('São José do Rio Preto'));

      // Viagem 2: Tarde -> Mirassol (AME)
      final resViagem2 = await viagemService.criarOuAdicionarViagemNaSessao(
        cidadeDestino: 'Mirassol',
        passageirosIds: [pacienteComRg.id],
      );
      expect(resViagem2.sucesso, isTrue);
      final viagem2 = resViagem2.viagem!;
      expect(viagem2.sessaoId, equals(sessao.id));
      expect(viagem2.cidadeDestino, equals('Mirassol'));

      // O motorista possui exatamente N = 2 viagens ativas em sua jornada
      expect(viagemService.viagensAtivas.length, equals(2));

      // ======================================================================
      // ETAPA 3: EMBARQUE DOS PASSAGEIROS E GERAÇÃO CRIPTOGRÁFICA DO CÓDIGO
      // ======================================================================
      // Motorista confirma embarque do Paciente 1 (titular com CPF)
      final codigoP1 = await viagemService.gerarOuObterCodigoAcesso(
        viagemId: viagem1.id,
        pacienteId: pacienteComCpf.id,
      );

      // Verificações do código gerado
      expect(codigoP1.length, inInclusiveRange(4, 5));
      expect(RegExp(r'^\d{4,5}$').hasMatch(codigoP1), isTrue);

      // IDEMPOTÊNCIA: Motorista toca novamente no botão "embarcou"
      final codigoP1Repetido = await viagemService.gerarOuObterCodigoAcesso(
        viagemId: viagem1.id,
        pacienteId: pacienteComCpf.id,
      );
      expect(codigoP1Repetido, equals(codigoP1),
          reason: 'Toques subsequentes em embarcou devem ser idempotentes');

      // Motorista confirma embarque do Paciente 2 (Criança / Acompanhante)
      final codigoP2 = await viagemService.gerarOuObterCodigoAcesso(
        viagemId: viagem1.id,
        pacienteId: pacienteCriancaComMae.id,
      );
      expect(codigoP2.length, inInclusiveRange(4, 5));
      expect(codigoP2, isNot(equals(codigoP1)),
          reason: 'Códigos dentro da mesma viagem devem ser únicos por passageiro');

      // Motorista confirma embarque do Paciente 3 (na Viagem 2)
      final codigoP3 = await viagemService.gerarOuObterCodigoAcesso(
        viagemId: viagem2.id,
        pacienteId: pacienteComRg.id,
      );
      expect(codigoP3.length, inInclusiveRange(4, 5));

      // As viagens em memória registram tanto o texto claro para exibição quanto o hash com salt
      final v1Atualizada = viagemService.viagensAtivas.firstWhere((v) => v.id == viagem1.id);
      expect(v1Atualizada.codigosAcesso[pacienteComCpf.id], equals(codigoP1));
      expect(v1Atualizada.codigosHash[pacienteComCpf.id], isNotNull);
      expect(
        v1Atualizada.codigosHash[pacienteComCpf.id],
        equals(CodigoAcessoService.calcularHash(codigoP1, viagem1.id)),
      );

      // ======================================================================
      // ETAPA 4: LOGIN DO PACIENTE TITULAR (Caso A: CPF Próprio + Código)
      // ======================================================================
      final listaPacientesTeste = [pacienteComCpf, pacienteCriancaComMae, pacienteComRg];

      // Login bem-sucedido com máscara ou dígitos limpos
      final roleP1 = await authService.loginPacienteComCodigo(
        documento: '529.982.247-25',
        codigoAcesso: codigoP1,
        pacientesParaTestes: listaPacientesTeste,
      );
      expect(roleP1, equals(UserRole.paciente));
      expect(authService.getCachedRole(pacienteComCpf.id), equals(UserRole.paciente));

      // Limpa cache de autenticação para simular login em outro dispositivo
      await authService.logout();

      // ======================================================================
      // ETAPA 5: LOGIN DA MÃE/ACOMPANHANTE (Caso B: CPF do Acompanhante + Código)
      // ======================================================================
      // A mãe entra usando o próprio CPF dela e o código gerado no embarque da criança
      final roleMae = await authService.loginPacienteComCodigo(
        documento: '301.894.649-92',
        codigoAcesso: codigoP2,
        pacientesParaTestes: listaPacientesTeste,
      );
      expect(roleMae, equals(UserRole.paciente));

      await authService.logout();

      // ======================================================================
      // ETAPA 6: LOGIN POR DOCUMENTO ALTERNATIVO (Caso C: RG/CNH + Código)
      // ======================================================================
      final roleRg = await authService.loginPacienteComCodigo(
        documento: 'MG-12.345.678',
        codigoAcesso: codigoP3,
        pacientesParaTestes: listaPacientesTeste,
      );
      expect(roleRg, equals(UserRole.paciente));

      await authService.logout();

      // ======================================================================
      // ETAPA 7: TENTATIVAS INVÁLIDAS E SEGURANÇA LGPD
      // ======================================================================
      // Código errado para CPF existente deve retornar erro genérico
      expect(
        () async => await authService.loginPacienteComCodigo(
          documento: '529.982.247-25',
          codigoAcesso: '0000',
          pacientesParaTestes: listaPacientesTeste,
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Credenciais inválidas ou viagem não localizada.',
        )),
      );

      // CPF inexistente retorna a mesma mensagem genérica para não vazar existência na base
      expect(
        () async => await authService.loginPacienteComCodigo(
          documento: '983.271.100-57', // CPF válido mas não cadastrado nesta viagem
          codigoAcesso: '1234',
          pacientesParaTestes: listaPacientesTeste,
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Credenciais inválidas ou viagem não localizada.',
        )),
      );

      // ======================================================================
      // ETAPA 8: ENCERRAMENTO DA VIAGEM E INVALIDAÇÃO DOS CÓDIGOS DE ACESSO
      // ======================================================================
      // O motorista conclui a primeira viagem informando os dados de encerramento
      await viagemService.encerrarViagem(
        viagemId: viagem1.id,
        kmFinal: 50080,
        kmRodado: 80,
      );

      // A viagem 1 foi concluída e removida da lista de viagens ativas
      expect(viagemService.viagensAtivas.any((v) => v.id == viagem1.id), isFalse);
      // Mas a Viagem 2 ainda continua ativa na sessão
      expect(viagemService.viagensAtivas.length, equals(1));
      expect(viagemService.sessaoAtiva?.status, equals('ativa'));

      // TENTATIVA DE LOGIN COM CÓDIGO DA VIAGEM ENCERRADA DEVE FALHAR IMEDIATAMENTE
      expect(
        () async => await authService.loginPacienteComCodigo(
          documento: '529.982.247-25',
          codigoAcesso: codigoP1,
          pacientesParaTestes: listaPacientesTeste,
        ),
        throwsA(isA<AuthException>()),
        reason: 'O código de acesso expira e é invalidado assim que a viagem termina',
      );

      // Encerramento da última viagem ativa da jornada (Viagem 2)
      await viagemService.encerrarViagem(
        viagemId: viagem2.id,
        kmFinal: 50150,
        kmRodado: 70,
      );

      // Todas as viagens da jornada foram finalizadas -> a Sessão do Veículo é automaticamente encerrada!
      expect(viagemService.viagensAtivas.isEmpty, isTrue);
      expect(viagemService.sessaoAtiva, isNull);
    });
  });
}
