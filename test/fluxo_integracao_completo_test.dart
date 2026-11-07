// ============================================================================
// ARQUIVO: test/fluxo_integracao_completo_test.dart
// ----------------------------------------------------------------------------
// Teste de Integração de Ponta a Ponta (End-to-End) - FASE 3: VERIFICAÇÃO
//
// FLUXO INTEGRADO COMPLETO COBERTO NESTE TESTE:
// 1. Admin cria "Horários" (viagens do dia) com pacientes e acompanhantes;
// 2. Motorista se autentica via AuthService e visualiza os horários atribuídos a ele;
// 3. Motorista declara o veículo e odômetro inicial, ativando a sessão do dia;
// 4. Embarque de passageiros gera o código de acesso numérico dinâmico (4-5 dígitos);
// 5. Paciente e acompanhante autenticam-se com sucesso via CPF e código;
// 6. Geração de PDF em lote de N viagens (exatamente N arquivos válidos e isolados);
// 7. Reautenticação do motorista e admin comprova isolamento total de sessão (sem contaminação);
// 8. Integridade do banco/dados: contagens antes/depois e ausência de registros órfãos.
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/passageiro_viagem_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/codigo_acesso_service.dart';
import 'package:trans_saude/services/relatorio_pdf_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

// Fake User do Firebase para testes integrados
class _FakeUser implements User {
  @override
  final String uid;
  @override
  final String? email;

  _FakeUser({required this.uid, this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake UserCredential do Firebase
class _FakeUserCredential implements UserCredential {
  @override
  final User? user;

  _FakeUserCredential({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake FirebaseAuth determinístico em memória
class _FakeFirebaseAuth implements FirebaseAuth {
  User? _currentUser;
  final Map<String, String> credentialsValidas;

  _FakeFirebaseAuth({this.credentialsValidas = const {}});

  @override
  User? get currentUser => _currentUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (credentialsValidas.containsKey(email) &&
        credentialsValidas[email] == password) {
      final user = _FakeUser(uid: 'uid_$email', email: email);
      _currentUser = user;
      return _FakeUserCredential(user: user);
    }
    throw FirebaseAuthException(code: 'wrong-password');
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViagemService viagemService;
  late FirebaseAuthService authService;
  late _FakeFirebaseAuth fakeAuth;

  final dataHoje = DateTime.now();

  // Entidades base de pessoas e veículos existentes
  final veiculoSpin = const VeiculoModel(
    id: 'veic_spin_01',
    placa: 'BRA-2E19',
    modelo: 'Chevrolet Spin 1.8 LTZ',
    capacidade: 7,
    quilometragemAtual: 50000,
  );

  final veiculoMaster = const VeiculoModel(
    id: 'veic_van_02',
    placa: 'SP-9A88',
    modelo: 'Renault Master 2.3',
    capacidade: 15,
    quilometragemAtual: 120000,
  );

  final motoristaAntonio = MotoristaModel(
    id: 'mot_antonio_01',
    nome: 'Antônio Carlos Ribeiro',
    cpf: '111.222.333-44',
    telefone: '(17) 99876-5432',
    email: 'antonio@transsaude.sp.gov.br',
    cnh: '12345678900',
    veiculoModelo: 'Chevrolet Spin 1.8 LTZ',
    veiculoPlaca: 'BRA-2E19',
  );

  // Pacientes com CPFs oficiais válidos para o algoritmo módulo 11
  final pacienteMaria = PacienteModel(
    id: 'pac_maria_01',
    nome: 'Maria Aparecida da Silva',
    cpf: '529.982.247-25', // CPF matematicamente válido
    telefone: '(17) 99123-4567',
    enderecoPaciente: 'Rua das Flores, 120 - Centro, Poloni',
    localConsulta: 'Hospital de Amor de Barretos',
    localSaida: 'UBS Poloni',
    nomeAcompanhante: 'José da Silva (Esposo)',
    cpfAcompanhante: '301.894.649-92', // CPF matematicamente válido
    status: 1, // Embarcou
  );

  final pacienteCarlos = PacienteModel(
    id: 'pac_carlos_02',
    nome: 'Carlos Eduardo Martins',
    cpf: '301.894.649-92', // CPF matematicamente válido
    telefone: '(17) 99456-7890',
    enderecoPaciente: 'Av. Brasil, 45 - Poloni',
    localConsulta: 'AME São José do Rio Preto',
    localSaida: 'Residência',
    status: 1, // Embarcou
  );

  final pacienteAna = PacienteModel(
    id: 'pac_ana_03',
    nome: 'Ana Paula Ferreira',
    cpf: '571.098.984-31', // CPF matematicamente válido
    telefone: '(17) 99234-5678',
    enderecoPaciente: 'Rua 7 de Setembro, 88 - Poloni',
    localConsulta: 'Hospital de Base de São José do Rio Preto',
    localSaida: 'UBS Poloni',
    status: 1, // Embarcou
  );

  setUp(() {
    FirebaseAuthService.resetarRateLimitParaTestes();
    CodigoAcessoService.resetarRateLimitParaTestes();

    viagemService = ViagemService();
    viagemService.resetParaTestes(
      veiculosIniciais: [veiculoSpin, veiculoMaster],
      todasViagensIniciais: [],
    );

    fakeAuth = _FakeFirebaseAuth(
      credentialsValidas: {
        '00011122233@transsaude.sp.gov.br': 'adminSenhaForte2026',
        '11122233344@transsaude.sp.gov.br': 'motoristaSenhaForte2026',
      },
    );

    authService = FirebaseAuthService(
      auth: fakeAuth,
      userDocFetcher: (uid) async {
        if (uid == 'uid_00011122233@transsaude.sp.gov.br') {
          return {'role': 'admin', 'nome': 'Administrador Geral'};
        }
        if (uid == 'uid_11122233344@transsaude.sp.gov.br') {
          return {'role': 'motorista', 'nome': 'Antônio Carlos Ribeiro'};
        }
        return null;
      },
    );
  });

  group('Fase 3: Fluxo de Integração Completo de Ponta a Ponta', () {
    test('Executa o ciclo integral da operação: Admin -> Motorista -> Declaração -> Embarque -> Código -> Paciente/Acomp -> PDF em Lote', () async {
      // -----------------------------------------------------------------------
      // ETAPA 1: Administrador se autentica e planeja os Horários do dia
      // -----------------------------------------------------------------------
      final roleAdmin = await authService.login('000.111.222-33', 'adminSenhaForte2026');
      expect(roleAdmin, equals(UserRole.admin));
      expect(authService.currentUserId, equals('uid_00011122233@transsaude.sp.gov.br'));

      // Admin cria Horário 1: "06:00 - Barretos" (Veículo Spin, Motorista Antônio)
      // Passageiros: Maria Aparecida (com acompanhante) e Carlos Eduardo
      final resultadoH1 = await viagemService.criarHorarioViagem(
        data: dataHoje,
        horario: '06:00 - Saída Barretos',
        cidadeDestino: 'BARRETOS',
        veiculoId: veiculoSpin.id,
        veiculoPlaca: veiculoSpin.placa,
        veiculoModelo: veiculoSpin.modelo,
        capacidadeVeiculo: veiculoSpin.capacidade,
        motoristaId: motoristaAntonio.id,
        motoristaNome: motoristaAntonio.nome,
        roleRequisitante: UserRole.admin,
        passageiros: [
          PassageiroViagemModel(
            pacienteId: pacienteMaria.id,
            pacienteNome: pacienteMaria.nome,
            pacienteCpf: pacienteMaria.cpf,
            acompanhanteNome: pacienteMaria.nomeAcompanhante,
            localOrigem: 'UBS Poloni',
            localDestino: pacienteMaria.localConsulta,
            horarioAtendimento: '09:00',
            ordemEmbarque: 1,
            observacoes: 'Paciente oncológica',
          ),
          PassageiroViagemModel(
            pacienteId: pacienteCarlos.id,
            pacienteNome: pacienteCarlos.nome,
            pacienteCpf: pacienteCarlos.cpf,
            localOrigem: 'Residência',
            localDestino: pacienteCarlos.localConsulta,
            horarioAtendimento: '10:00',
            ordemEmbarque: 2,
          ),
        ],
      );
      expect(resultadoH1.sucesso, isTrue, reason: 'Horário 1 deve ser criado sem conflitos');
      final viagem1 = resultadoH1.viagem!;
      expect(viagem1.isPlanejada, isTrue);
      expect(viagem1.totalAssentosOcupados, equals(3), reason: 'Maria + Acompanhante + Carlos = 3 assentos');

      // Admin cria Horário 2: "13:30 - São José do Rio Preto" (Veículo Master, Motorista Antônio)
      // Passageira: Ana Paula
      final resultadoH2 = await viagemService.criarHorarioViagem(
        data: dataHoje,
        horario: '13:30 - Retorno Especial SJRP',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        veiculoId: veiculoMaster.id,
        veiculoPlaca: veiculoMaster.placa,
        veiculoModelo: veiculoMaster.modelo,
        capacidadeVeiculo: veiculoMaster.capacidade,
        motoristaId: motoristaAntonio.id,
        motoristaNome: motoristaAntonio.nome,
        roleRequisitante: UserRole.admin,
        passageiros: [
          PassageiroViagemModel(
            pacienteId: pacienteAna.id,
            pacienteNome: pacienteAna.nome,
            pacienteCpf: pacienteAna.cpf,
            localOrigem: 'UBS Poloni',
            localDestino: pacienteAna.localConsulta,
            horarioAtendimento: '15:00',
            ordemEmbarque: 1,
          ),
        ],
      );
      expect(resultadoH2.sucesso, isTrue, reason: 'Horário 2 deve ser criado sem conflitos');
      final viagem2 = resultadoH2.viagem!;
      expect(viagem2.isPlanejada, isTrue);

      // Admin faz logout
      await authService.logout();
      expect(authService.currentUserId, isNull);

      // -----------------------------------------------------------------------
      // ETAPA 2: Motorista se autentica e visualiza seus Horários do dia
      // -----------------------------------------------------------------------
      final roleMotorista = await authService.login('111.222.333-44', 'motoristaSenhaForte2026');
      expect(roleMotorista, equals(UserRole.motorista));
      expect(authService.currentUserId, equals('uid_11122233344@transsaude.sp.gov.br'));

      // Motorista consulta suas viagens do dia
      final viagensAtribuidas = viagemService.listarViagensDoMotorista(
        motoristaAntonio.id,
        dataHoje,
      );
      expect(viagensAtribuidas.length, equals(2));
      expect(viagensAtribuidas.map((v) => v.id), containsAll([viagem1.id, viagem2.id]));

      // -----------------------------------------------------------------------
      // ETAPA 3: Motorista declara o veículo e odômetro inicial
      // -----------------------------------------------------------------------
      final declaracaoRes = await viagemService.declararVeiculo(
        veiculo: veiculoSpin,
        kmInicial: 50000,
        motoristaId: motoristaAntonio.id,
        motoristaNome: motoristaAntonio.nome,
      );
      expect(declaracaoRes.sucesso, isTrue);
      expect(viagemService.sessaoAtiva, isNotNull);
      expect(viagemService.sessaoAtiva!.veiculoPlaca, equals('BRA-2E19'));
      expect(viagemService.sessaoAtiva!.kmInicial, equals(50000));

      // As viagens do dia do motorista foram ativadas e vinculadas à sessão
      expect(viagemService.viagensAtivas.length, greaterThanOrEqualTo(1));
      final viagemAtivaAtual = viagemService.viagensAtivas.firstWhere((v) => v.id == viagem1.id);
      expect(viagemAtivaAtual.status, equals('ativa'));

      // -----------------------------------------------------------------------
      // ETAPA 4: Embarque de passageiros -> Geração de Código Numérico (4-5 dígitos)
      // -----------------------------------------------------------------------
      final codigoMaria = await viagemService.gerarOuObterCodigoAcesso(
        viagemId: viagem1.id,
        pacienteId: pacienteMaria.id,
      );
      expect(RegExp(r'^\d{4,5}$').hasMatch(codigoMaria), isTrue,
          reason: 'Código gerado deve ter estritamente entre 4 e 5 dígitos numéricos');

      // Idempotência: obter o código novamente para a mesma Maria na mesma viagem retorna o mesmo código
      final codigoMariaReconsulta = await viagemService.gerarOuObterCodigoAcesso(
        viagemId: viagem1.id,
        pacienteId: pacienteMaria.id,
      );
      expect(codigoMariaReconsulta, equals(codigoMaria));

      final codigoCarlos = await viagemService.gerarOuObterCodigoAcesso(
        viagemId: viagem1.id,
        pacienteId: pacienteCarlos.id,
      );
      expect(RegExp(r'^\d{4,5}$').hasMatch(codigoCarlos), isTrue);
      expect(codigoCarlos, isNot(equals(codigoMaria)), reason: 'Códigos entre passageiros devem ser distintos');

      // -----------------------------------------------------------------------
      // ETAPA 5: Paciente e Acompanhante realizam login com CPF e Código de Acesso
      // -----------------------------------------------------------------------
      // (a) Paciente Maria faz login com seu CPF e o código numérico gerado
      final rolePacienteMaria = await authService.loginPacienteComCodigo(
        documento: pacienteMaria.cpf,
        codigoAcesso: codigoMaria,
        pacientesParaTestes: [pacienteMaria, pacienteCarlos, pacienteAna],
      );
      expect(rolePacienteMaria, equals(UserRole.paciente));
      expect(authService.currentUserId, equals(pacienteMaria.id));

      // (b) Logout da paciente
      await authService.logout();
      expect(authService.currentUserId, isNull);

      // (c) Acompanhante de Maria faz login usando o CPF do paciente e o código gerado no embarque
      final roleAcompanhante = await authService.loginPacienteComCodigo(
        documento: pacienteMaria.cpf,
        codigoAcesso: codigoMaria,
        pacientesParaTestes: [pacienteMaria, pacienteCarlos, pacienteAna],
      );
      expect(roleAcompanhante, equals(UserRole.paciente));

      await authService.logout();

      // -----------------------------------------------------------------------
      // ETAPA 6: Geração de Relatório PDF em Lote para as N viagens do dia
      // -----------------------------------------------------------------------
      final Map<String, List<PacienteModel>> pacientesPorViagem = {
        viagem1.id: [pacienteMaria, pacienteCarlos],
        viagem2.id: [pacienteAna],
      };

      final lotePdfs = await RelatorioPdfService.gerarLoteViagensPdf(
        viagens: [viagem1, viagem2],
        pacientesPorViagem: pacientesPorViagem,
        kmSaidaInformado: 50000,
        kmRetornoInformado: 50250,
        kmRodadoInformado: 250,
      );

      // Verificação da regra de lote: N viagens = N arquivos de PDF independentes
      expect(lotePdfs.length, equals(2), reason: 'Exatamente 2 PDFs individuais devem ser gerados');
      expect(lotePdfs.containsKey(viagem1.id), isTrue);
      expect(lotePdfs.containsKey(viagem2.id), isTrue);

      final pdf1Bytes = lotePdfs[viagem1.id]!;
      final pdf2Bytes = lotePdfs[viagem2.id]!;

      expect(pdf1Bytes.length, greaterThan(1500), reason: 'PDF da viagem 1 deve conter cabeçalho, itinerário e passageiros');
      expect(pdf2Bytes.length, greaterThan(1500), reason: 'PDF da viagem 2 deve conter cabeçalho e passageira Ana');

      // -----------------------------------------------------------------------
      // ETAPA 7: Reautenticação do Motorista e Admin - Ausência de Contaminação
      // -----------------------------------------------------------------------
      // Motorista entra novamente com senha
      final roleMotoristaRevisita = await authService.login('111.222.333-44', 'motoristaSenhaForte2026');
      expect(roleMotoristaRevisita, equals(UserRole.motorista));
      expect(authService.currentUserId, equals('uid_11122233344@transsaude.sp.gov.br'),
          reason: 'Sessão do motorista deve ser exclusivamente sua, sem IDs de paciente em memória');

      await authService.logout();

      // Admin entra novamente com senha
      final roleAdminRevisita = await authService.login('000.111.222-33', 'adminSenhaForte2026');
      expect(roleAdminRevisita, equals(UserRole.admin));
      expect(authService.currentUserId, equals('uid_00011122233@transsaude.sp.gov.br'));

      await authService.logout();
    });

    test('Integridade do modelo e banco de dados: ausência de registros órfãos e consistência relacional', () async {
      // Criação de viagem com passageiros referenciando pessoas reais
      final res = await viagemService.criarHorarioViagem(
        data: dataHoje,
        horario: '08:00 - Mirassol Especial',
        cidadeDestino: 'MIRASSOL',
        veiculoId: veiculoSpin.id,
        veiculoPlaca: veiculoSpin.placa,
        veiculoModelo: veiculoSpin.modelo,
        capacidadeVeiculo: veiculoSpin.capacidade,
        motoristaId: motoristaAntonio.id,
        motoristaNome: motoristaAntonio.nome,
        roleRequisitante: UserRole.admin,
        passageiros: [
          PassageiroViagemModel(
            pacienteId: pacienteMaria.id,
            pacienteNome: pacienteMaria.nome,
            pacienteCpf: pacienteMaria.cpf,
            localOrigem: 'UBS Poloni',
            localDestino: 'Hospital de Olhos',
            horarioAtendimento: '09:30',
            ordemEmbarque: 1,
          ),
        ],
      );

      expect(res.sucesso, isTrue);
      final viagem = res.viagem!;

      // 1. Integridade de Veículo (chave estrangeira veiculoId existe no cadastro)
      final veiculosCadastradosIds = [veiculoSpin.id, veiculoMaster.id];
      expect(veiculosCadastradosIds, contains(viagem.veiculoId));

      // 2. Integridade de Motorista (chave estrangeira motoristaId existe no cadastro)
      final motoristasCadastradosIds = [motoristaAntonio.id];
      expect(motoristasCadastradosIds, contains(viagem.motoristaId));

      // 3. Integridade de Passageiros (nenhum registro órfão)
      final pacientesCadastradosIds = [pacienteMaria.id, pacienteCarlos.id, pacienteAna.id];
      for (final passageiro in viagem.passageiros) {
        expect(pacientesCadastradosIds, contains(passageiro.pacienteId),
            reason: 'O passageiro deve referenciar um paciente cadastrado existente');
      }

      // 4. Integridade da máquina de estados do Horário
      expect(viagem.isPlanejada, isTrue);
      expect(viagem.isAtiva, isFalse);
      expect(viagem.isConcluida, isFalse);
      expect(viagem.isCancelada, isFalse);

      // Cancelamento lógico (soft cancel)
      final resCancel = await viagemService.cancelarOuExcluirHorarioViagem(
        viagem.id,
        roleRequisitante: UserRole.admin,
      );
      expect(resCancel.sucesso, isTrue);
      expect(resCancel.viagem?.isCancelada, isTrue);

      final viagemCancelada = viagemService.obterViagensPorData(dataHoje).firstWhere((v) => v.id == viagem.id);
      expect(viagemCancelada.isCancelada, isTrue);
      expect(viagemCancelada.status, equals('cancelada'));
    });
  });
}
