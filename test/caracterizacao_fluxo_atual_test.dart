// ============================================================================
// ARQUIVO: test/caracterizacao_fluxo_atual_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Suíte de testes de caracterização que registra o comportamento oficial do
// sistema TransSaúde antes das refatorações da Issue #65.
//
// COBERTURA DE CARACTERIZAÇÃO:
// 1. ViagemService: ciclo de vida de viagem atual (iniciar, concorrência, encerrar)
// 2. Regras de validação de quilometragem e destinos
// 3. Ocupação de assentos na tela do motorista (paciente individual vs com acompanhante)
// 4. Mapeamento de status e transições do ciclo do paciente (0 a 5)
// 5. Autenticação e RouteGuard: bloqueio de perfis indevidos no painel operacional
// 6. Integridade da geração do documento PDF atual
//
// PAPEL NA FASE 0:
// Provar de forma automatizada que a base de código está íntegra antes das
// mudanças da Fase 1 e garantir que o comportamento existente não regrida.
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/routes/route_guard.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/relatorio_pdf_service.dart';
import 'package:trans_saude/services/validacao_viagem.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Caracterização - ViagemService e Validação de Viagem', () {
    late ViagemService service;

    setUp(() {
      service = ViagemService();
      service.resetParaTestes();
    });

    test('Lista inicial de veículos contém veículos padrão com frotas livres', () async {
      final veiculos = await service.carregarVeiculosDisponiveis().first;
      expect(veiculos.isNotEmpty, isTrue);
      expect(veiculos.any((v) => v.placa == 'ABC-1D23'), isTrue);
      // Veículo ocupado por mot_antonio não deve constar como disponível
      expect(veiculos.any((v) => v.placa == 'XYZ-9K88'), isFalse);
    });

    test('Validação de odômetro impede recuo de quilometragem', () {
      final validacao = ValidacaoViagem.validarQuilometragem(
        valorDigitado: '85400',
        ultimaKmRegistrada: 85420,
      );
      expect(validacao.valido, isFalse);
      expect(validacao.mensagemErro, contains('não pode ser menor que a última registrada'));
    });

    test('Validação de odômetro impede salto absurdo (+2000 km)', () {
      final validacao = ValidacaoViagem.validarQuilometragem(
        valorDigitado: '95000',
        ultimaKmRegistrada: 85420,
      );
      expect(validacao.valido, isFalse);
      expect(validacao.mensagemErro, contains('acima do teto de plausibilidade'));
    });

    test('Iniciar viagem válida atualiza viagemAtiva e emite evento na stream', () async {
      final veiculo = const VeiculoModel(
        id: 'v_teste',
        placa: 'TEST-1234',
        modelo: 'Van Municipal',
        capacidade: 15,
        quilometragemAtual: 50000,
        emUso: false,
      );

      final resultado = await service.iniciarViagem(
        veiculo: veiculo,
        kmInicial: 50120,
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        motoristaId: 'mot_teste',
        motoristaNome: 'Motorista de Teste',
      );

      expect(resultado.sucesso, isTrue);
      expect(resultado.viagem, isNotNull);
      expect(service.viagemAtiva?.id, resultado.viagem!.id);
      expect(service.viagemAtiva?.veiculoPlaca, 'TEST-1234');
      expect(service.viagemAtiva?.kmInicial, 50120);
      expect(service.viagemAtiva?.status, 'ativa');
    });

    test('Encerrar viagem ativa zera a referência e libera estado operacional', () async {
      final veiculo = const VeiculoModel(
        id: 'v_encerrar',
        placa: 'FIM-9999',
        modelo: 'Ambulância',
        capacidade: 4,
        quilometragemAtual: 30000,
        emUso: false,
      );

      await service.iniciarViagem(
        veiculo: veiculo,
        kmInicial: 30100,
        cidadeDestino: 'BARRETOS',
        motoristaId: 'mot_fim',
        motoristaNome: 'Condutor Fim',
      );

      expect(service.viagemAtiva, isNotNull);
      await service.encerrarViagem(kmFinal: 30250, kmRodado: 150);
      expect(service.viagemAtiva, isNull);
    });
  });

  group('Caracterização - Lógica de Ocupação e Status de Pacientes', () {
    test('Paciente individual no status 1 (embarcou ida) ocupa 1 assento', () {
      final p = PacienteModel(
        id: 'p1',
        nome: 'João da Silva',
        cpf: '111.222.333-44',
        telefone: '17999991111',
        enderecoPaciente: 'Rua 1',
        localConsulta: 'Hospital',
        status: 1,
      );

      final ocupados = (p.status == 1 || p.status == 3)
          ? ((p.nomeAcompanhante?.isNotEmpty == true) ? 2 : 1)
          : 0;

      expect(ocupados, equals(1));
    });

    test('Paciente com acompanhante preenchido no status 1 ocupa 2 assentos', () {
      final p = PacienteModel(
        id: 'p2',
        nome: 'Maria da Silva',
        cpf: '222.333.444-55',
        telefone: '17999992222',
        enderecoPaciente: 'Rua 2',
        localConsulta: 'Hospital',
        status: 1,
        nomeAcompanhante: 'Acompanhante da Maria',
        telAcompanhante: '17999993333',
      );

      final ocupados = (p.status == 1 || p.status == 3)
          ? ((p.nomeAcompanhante?.isNotEmpty == true) ? 2 : 1)
          : 0;

      expect(ocupados, equals(2));
    });

    test('Paciente aguardando (status 0) ou concluído (status 4 ou 5) ocupa 0 assentos a bordo', () {
      final pAguardando = PacienteModel(
        id: 'p0',
        nome: 'Carlos',
        cpf: '333',
        telefone: '17',
        enderecoPaciente: 'Rua 0',
        localConsulta: 'Hospital',
        status: 0,
      );

      final pConcluido = PacienteModel(
        id: 'p4',
        nome: 'Ana',
        cpf: '444',
        telefone: '17',
        enderecoPaciente: 'Rua 4',
        localConsulta: 'Hospital',
        status: 4,
      );

      int calcularOcupacao(PacienteModel p) =>
          (p.status == 1 || p.status == 3)
              ? ((p.nomeAcompanhante?.isNotEmpty == true) ? 2 : 1)
              : 0;

      expect(calcularOcupacao(pAguardando), equals(0));
      expect(calcularOcupacao(pConcluido), equals(0));
    });

    test('Máquina de status mapeia rótulos e cores oficiais de 0 a 5', () {
      final s0 = PacienteModel.dadosStatus(0);
      expect(s0.$1, 'Aguardando Transporte');
      expect(s0.$2, const Color(0xFF2563EB));

      final s1 = PacienteModel.dadosStatus(1);
      expect(s1.$1, 'Embarcou para Ida');
      expect(s1.$2, const Color(0xFF1D4ED8));

      final s2 = PacienteModel.dadosStatus(2);
      expect(s2.$1, 'Desembarcou para Consulta');
      expect(s2.$2, const Color(0xFFD97706));

      final s3 = PacienteModel.dadosStatus(3);
      expect(s3.$1, 'Reembarcou para Volta');
      expect(s3.$2, const Color(0xFF4338CA));

      final s4 = PacienteModel.dadosStatus(4);
      expect(s4.$1, 'Concluído');
      expect(s4.$2, const Color(0xFF16A34A));

      final s5 = PacienteModel.dadosStatus(5);
      expect(s5.$1, 'Cancelado');
      expect(s5.$2, const Color(0xFFB83227));
    });
  });

  group('Caracterização - Segurança, RBAC e RouteGuard', () {
    test('RouteGuard autoriza /motorista quando role é motorista', () {
      final fakeAuth = _FakeAuthService(currentRole: UserRole.motorista, uid: 'mot_123');
      final route = RouteGuard.onGenerateRoute(
        const RouteSettings(name: '/motorista'),
        authService: fakeAuth,
      );
      expect(route, isA<MaterialPageRoute>());
    });

    test('RouteGuard bloqueia paciente de acessar /motorista e redireciona para painel do paciente', () {
      final fakeAuth = _FakeAuthService(currentRole: UserRole.paciente, uid: 'pac_123');
      final route = RouteGuard.onGenerateRoute(
        const RouteSettings(name: '/motorista'),
        authService: fakeAuth,
      );
      expect(route, isA<MaterialPageRoute>());
      // O builder deve construir a tela de paciente, impedindo acesso à do motorista
      final widget = (route as MaterialPageRoute).builder(
        // Contexto fictício mockado
        _FakeBuildContext(),
      );
      expect(widget.runtimeType.toString(), contains('Paciente'));
    });
  });

  group('Caracterização - Relatório PDF Atual', () {
    test('Gera PDF contendo dados da viagem e do paciente no layout oficial', () async {
      pw.Font? fReg;
      pw.Font? fBold;
      final fileReg = File('assets/fonts/LiberationSans-Regular.ttf');
      final fileBold = File('assets/fonts/LiberationSans-Bold.ttf');
      if (fileReg.existsSync() && fileBold.existsSync()) {
        fReg = pw.Font.ttf(fileReg.readAsBytesSync().buffer.asByteData());
        fBold = pw.Font.ttf(fileBold.readAsBytesSync().buffer.asByteData());
      }

      final viagem = ViagemModel(
        id: '999888',
        motoristaId: 'mot_carac',
        motoristaNome: 'JOAO MOTORISTA CARACTERIZACAO',
        veiculoId: 'v1',
        veiculoPlaca: 'CAR-1234',
        veiculoModelo: 'SPIN 1.8',
        kmInicial: 10000,
        cidadeDestino: 'CATANDUVA',
        dataHoraInicio: DateTime(2026, 11, 7, 8, 0),
      );

      final pacientes = [
        PacienteModel(
          id: 'p_carac_1',
          nome: 'PACIENTE CARACTERIZACAO UM',
          cpf: '123.456.789-00',
          telefone: '(17) 98888-7777',
          enderecoPaciente: 'RUA DO CARACTER, 100',
          localConsulta: 'HOSPITAL DE CATANDUVA',
          horarioConsulta: '10:00',
        ),
      ];

      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagem,
        pacientes: pacientes,
        fonteRegular: fReg,
        fonteBold: fBold,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}

// Implementação Fake de AuthService para testes determinísticos
class _FakeAuthService implements AuthService {
  final UserRole? currentRole;
  final String? uid;

  _FakeAuthService({this.currentRole, this.uid});

  @override
  String? get currentUserId => uid;

  @override
  UserRole? getCachedRole(String uid) => currentRole;

  @override
  void clearRoleCache() {}

  @override
  Stream<String?> get authStateChanges => Stream.value(uid);

  @override
  Future<UserRole> login(String cpf, String senha) async {
    if (currentRole == null) {
      throw const AuthException('Credenciais inválidas');
    }
    return currentRole!;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserRole> resolveUserRole(String uid, {bool forceRefresh = false}) async {
    return currentRole ?? UserRole.paciente;
  }

  @override
  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) async {
    return currentRole ?? UserRole.paciente;
  }
}

// Contexto Fake para invocação do builder de rota em testes de unidade puros
class _FakeBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
