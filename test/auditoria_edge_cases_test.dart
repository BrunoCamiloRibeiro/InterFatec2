import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/card_tracking_paciente.dart';
import 'package:trans_saude/components/dialog_excluir_veiculo.dart';
import 'package:trans_saude/components/footer_veiculos.dart';
import 'package:trans_saude/components/formulario_pessoa.dart';
import 'package:trans_saude/detalhes_veiculo.dart';
import 'package:trans_saude/lista_pessoas.dart';
import 'package:trans_saude/models/localizacao_motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/paciente.dart';
import 'package:trans_saude/screens/gerenciador_viagens_screen.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/codigo_acesso_service.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

class _FakeUser implements User {
  @override
  final String uid;

  _FakeUser({required this.uid});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  @override
  final User? user;

  _FakeUserCredential({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  final User? userOverride;
  bool signedOut = false;

  _FakeFirebaseAuth({this.userOverride});

  @override
  User? get currentUser => userOverride;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _FakeUserCredential(user: userOverride);
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ViagemService viagemService;
  late PacienteSyncService syncService;

  setUp(() {
    viagemService = ViagemService();
    syncService = PacienteSyncService();
    viagemService.resetParaTestes();
    syncService.resetParaTestes();
    FirebaseAuthService.resetarRateLimitParaTestes();
    CodigoAcessoService.resetarRateLimitParaTestes();
  });

  tearDown(() {
    viagemService.executorPersistenciaRemotaOverride = null;
    syncService.executorRemotoOverride = null;
    viagemService.encerrarEscutasFirestore();
  });

  group('Auditoria - Casos de Borda de Swipe (Motorista)', () {
    testWidgets('Swipe parcial interrompido não abre diálogo e mantém status 0', (tester) async {
      final paciente = PacienteModel(
        id: 'p_parcial',
        nome: 'Maria Parcial',
        cpf: '529.982.247-25',
        telefone: '(17) 99999-0001',
        enderecoPaciente: 'Rua das Flores, 10',
        localConsulta: 'HB Rio Preto',
        status: 0,
      );
      syncService.resetParaTestes([paciente]);

      await tester.pumpWidget(
        MaterialApp(
          home: Motorista(
            viagemInicial: ViagemModel(
              id: 'v_parcial',
              motoristaId: 'mot_1',
              motoristaNome: 'Carlos Silva',
              veiculoId: 'veic_1',
              veiculoPlaca: 'DEF-4G56',
              veiculoModelo: 'Ducato',
              kmInicial: 50000,
              cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
              dataHoraInicio: DateTime(2026, 11, 11, 6, 0),
              status: 'ativa',
            ),
            syncServiceOverride: syncService,
            pacientesStreamOverride: Stream.value([paciente]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(const ValueKey('p_parcial')), const Offset(-45, 0));
      await tester.pumpAndSettle();

      expect(find.text('PRÓXIMA ETAPA'), findsNothing);
      expect(find.text('Aguardando Transporte'), findsOneWidget);
      expect(
        syncService.ouvirPaciente('p_parcial'),
        emits(predicate<PacienteModel?>((p) => p?.status == 0)),
      );
    });

    testWidgets('Card concluído (status 4) desativa Dismissible e ignora avanço duplicado', (tester) async {
      final pacienteConcluido = PacienteModel(
        id: 'p_concluido',
        nome: 'Ana Concluída',
        cpf: '180.879.890-23',
        telefone: '(17) 99999-0002',
        enderecoPaciente: 'Rua XV, 85',
        localConsulta: 'Hospital de Amor',
        status: 4,
      );
      syncService.resetParaTestes([pacienteConcluido]);

      await tester.pumpWidget(
        MaterialApp(
          home: Motorista(
            viagemInicial: ViagemModel(
              id: 'v_duplo',
              motoristaId: 'mot_1',
              motoristaNome: 'Carlos Silva',
              veiculoId: 'veic_1',
              veiculoPlaca: 'DEF-4G56',
              veiculoModelo: 'Ducato',
              kmInicial: 50000,
              cidadeDestino: 'BARRETOS',
              dataHoraInicio: DateTime(2026, 11, 11, 7, 30),
              status: 'ativa',
            ),
            syncServiceOverride: syncService,
            pacientesStreamOverride: Stream.value([pacienteConcluido]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dismissible = tester.widget<Dismissible>(find.byKey(const ValueKey('p_concluido')));
      expect(dismissible.direction, equals(DismissDirection.none));

      final resDuplo = await syncService.avancarEtapaMotorista(
        pacienteId: 'p_concluido',
        motoristaId: 'mot_1',
        acao: AcaoTransicao.motoristaReembarcarVolta,
        viagemId: 'v_duplo',
      );
      expect(resDuplo.sucesso, isFalse);
    });

    test('Swipe sem rede reverte estado otimista e publica falha em stream', () async {
      final paciente = PacienteModel(
        id: 'p_offline',
        nome: 'Lucas Offline',
        cpf: '678.901.234-69',
        telefone: '(17) 99999-0003',
        enderecoPaciente: 'Av. Brasil, 200',
        localConsulta: 'AME',
        status: 0,
      );
      syncService.resetParaTestes([paciente]);
      syncService.registrarPacienteEmMemoriaSeAusente(paciente, viagemId: 'v_off');
      syncService.executorRemotoOverride = (pacienteId, payload) async {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      };

      final falhasFuture = syncService.falhasPorViagemStream.first;

      final res = await syncService.avancarEtapaMotorista(
        pacienteId: 'p_offline',
        motoristaId: 'mot_1',
        acao: AcaoTransicao.motoristaEmbarcarIda,
        viagemId: 'v_off',
      );
      expect(res.sucesso, isTrue);

      final falha = await falhasFuture;
      expect(falha.pacienteId, equals('p_offline'));
      expect(falha.estadoRevertido.status, equals(0));
      expect(falha.mensagem, contains('revertida'));
    });
  });

  group('Auditoria - Casos de Borda de Rastreamento (Paciente)', () {
    testWidgets('Exibe aviso de posição desatualizada e botões de zoom >= 48x48dp', (tester) async {
      final streamCtrl = StreamController<List<LocalizacaoMotoristaModel>>.broadcast();
      addTearDown(streamCtrl.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardTrackingPaciente(
              motoristasStreamOverride: streamCtrl.stream,
            ),
          ),
        ),
      );

      streamCtrl.add([
        LocalizacaoMotoristaModel(
          id: 'mot_stale',
          motoristaId: 'mot_stale',
          motoristaNome: 'Roberto Antigo',
          veiculoPlaca: 'BRA-2E19',
          veiculoModelo: 'Spin',
          cidadeDestino: 'BARRETOS',
          latitude: -20.8073,
          longitude: -49.3950,
          ultimaAtualizacao: DateTime.now().subtract(const Duration(minutes: 25)),
          emViagem: true,
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('(desatualizado)'), findsOneWidget);

      final btnZoomIn = tester.getSize(find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 48 && w.constraints?.maxHeight == 48,
      ).first);
      expect(btnZoomIn.width, greaterThanOrEqualTo(48));
      expect(btnZoomIn.height, greaterThanOrEqualTo(48));
    });
  });

  group('Auditoria - Correções de Bloqueio e Validação', () {
    test('Rejeita horário vazio e passageiro duplicado na criação de viagem', () async {
      final resVazio = await viagemService.criarHorarioViagem(
        data: DateTime(2026, 11, 11),
        horario: '   ',
        cidadeDestino: 'BARRETOS',
        roleRequisitante: UserRole.admin,
      );
      expect(resVazio.sucesso, isFalse);
      expect(resVazio.mensagemErro, contains('Informe o horário de saída'));

      final pDup = PassageiroViagemModel(
        pacienteId: 'pac_dup',
        pacienteNome: 'Ana Clara',
        pacienteCpf: '529.982.247-25',
        pacienteTelefone: '(17) 99999-1111',
        localOrigem: 'Rua A, 1',
        localDestino: 'HB',
      );
      final resDup = await viagemService.criarHorarioViagem(
        data: DateTime(2026, 11, 11),
        horario: '08:00',
        cidadeDestino: 'BARRETOS',
        passageiros: [pDup, pDup],
        roleRequisitante: UserRole.admin,
      );
      expect(resDup.sucesso, isFalse);
      expect(resDup.mensagemErro, contains('já foi adicionado'));
    });

    test('Bloqueia cancelamento de viagem já concluída e alinha kmInicial ao encerrar', () async {
      final res = await viagemService.criarHorarioViagem(
        data: DateTime(2026, 11, 11),
        horario: '06:00',
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
        roleRequisitante: UserRole.admin,
      );
      expect(res.sucesso, isTrue);

      await viagemService.iniciarViagem(
        motoristaId: 'mot_1',
        motoristaNome: 'Carlos Silva',
        veiculo: VeiculoModel(
          id: 'veic_1',
          placa: 'DEF-4G56',
          modelo: 'Ducato',
          capacidade: 15,
          quilometragemAtual: 50000,
        ),
        kmInicial: 50000,
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
      );
      await viagemService.encerrarViagem(
        viagemId: res.viagem!.id,
        kmFinal: 50250,
        kmRodado: 250,
        forcarConclusao: true,
        motoristaEncerramentoId: 'mot_1',
      );

      final vConc = viagemService.todasViagens.firstWhere((v) => v.id == res.viagem!.id);
      expect(vConc.kmInicial, equals(50000));
      expect(vConc.kmFinal, equals(50250));
      expect(vConc.kmRodado, equals(250));

      final resCancelar = await viagemService.cancelarOuExcluirHorarioViagem(
        res.viagem!.id,
        softDelete: true,
        roleRequisitante: UserRole.admin,
      );
      expect(resCancelar.sucesso, isFalse);
      expect(resCancelar.mensagemErro, contains('já foi concluída'));
    });

    testWidgets('DialogExcluirVeiculo exibe bloqueio e sem botão confirmar quando emUso=true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DialogExcluirVeiculo(
              id: 'v_uso',
              placa: 'BRA2E19',
              modelo: 'Spin 1.8',
              emUso: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Veículo em Uso'), findsOneWidget);
      expect(find.text('Entendi'), findsOneWidget);
      expect(find.text('Confirmar'), findsNothing);
    });

    test('Bloqueia login de usuário inativo (motorista/admin e paciente)', () async {
      final authInativo = FirebaseAuthService(
        auth: _FakeFirebaseAuth(userOverride: _FakeUser(uid: 'mot_inativo_auditoria')),
        userDocFetcher: (_) async => {
          'role': 'motorista',
          'ativo': false,
          'nome': 'Motorista Inativo',
        },
      );

      await expectLater(
        () => authInativo.login('234.567.890-92', '123456'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'user-inactive'),
        ),
      );

      final viagemComCodigo = ViagemModel(
        id: 'v_pac_inat',
        motoristaId: 'm1',
        motoristaNome: 'Carlos',
        veiculoId: 'v1',
        veiculoPlaca: 'DEF4G56',
        veiculoModelo: 'Ducato',
        kmInicial: 50000,
        cidadeDestino: 'BARRETOS',
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
        passageirosIds: const ['pac_inativo'],
        codigosAcesso: const {'pac_inativo': '12345'},
        codigosHash: {
          'pac_inativo': CodigoAcessoService.calcularHash('12345', 'v_pac_inat'),
        },
      );
      viagemService.resetParaTestes(viagensAtivasIniciais: [viagemComCodigo]);

      await expectLater(
        () => FirebaseAuthService().loginPacienteComCodigo(
          documento: '529.982.247-25',
          codigoAcesso: '12345',
          pacientesParaTestes: [
            PacienteModel(
              id: 'pac_inativo',
              nome: 'Paciente Desativado',
              cpf: '529.982.247-25',
              telefone: '(17) 99999-9999',
              enderecoPaciente: 'Rua X',
              localConsulta: 'HB',
              ativo: false,
            ),
          ],
        ),
        throwsA(isA<AuthException>()),
      );
    });

    testWidgets('Tela Paciente sem sessão/id não vaza cadastro de outro usuário', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Paciente(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Nenhum dado de paciente encontrado'), findsOneWidget);
    });
  });

  group('Auditoria - Decisões Q3 e Q4 Aplicadas', () {
    testWidgets('Q3: FormularioPessoa exige CNH e senha (>= 6) ao criar motorista e avisa sobre Auth na edição', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FormularioPessoa())));
      await tester.tap(find.text('Motorista'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Carlos Motorista');
      await tester.enterText(find.byType(TextFormField).at(1), '52998224725');
      await tester.enterText(find.byType(TextFormField).at(2), '17999990000');
      await tester.enterText(find.byKey(const Key('campoSenhaPessoa')), '123');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cadastrar'));
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('CNH válido'), findsOneWidget);
      expect(find.textContaining('pelo menos 6 caracteres'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormularioPessoa(
              pessoaParaEditar: PessoaItem(
                id: 'mot_edit',
                nome: 'Carlos Motorista',
                cpf: '529.982.247-25',
                telefone: '(17) 99999-0000',
                role: 'motorista',
                badgeLabel: 'Motorista',
                badgeCor: Color(0xFF0F172A),
                detalheExtra: 'CNH: 12345678900',
                cnh: '12345678900',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Firebase Auth'), findsOneWidget);
    });

    testWidgets('Q4: Remove seta voltar raiz em Motorista/Paciente, oculta Relatório Frota e deixa 1 CTA Novo Horário no Admin', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                Expanded(
                  child: FooterVeiculos(veiculosDisponiveis: 2, veiculosTotais: 2),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Veículos: 2 / 2'), findsOneWidget);
      expect(find.text('Relatório Frota'), findsNothing);

      final p = PacienteModel(
        id: 'p_q4',
        nome: 'Maria Q4',
        cpf: '529.982.247-25',
        telefone: '(17) 99999-0001',
        enderecoPaciente: 'Rua A',
        localConsulta: 'HB',
        status: 0,
      );
      syncService.resetParaTestes([p]);
      await tester.pumpWidget(
        MaterialApp(
          home: Motorista(
            viagemInicial: ViagemModel(
              id: 'v_q4',
              motoristaId: 'mot_1',
              motoristaNome: 'Carlos Silva',
              veiculoId: 'veic_1',
              veiculoPlaca: 'DEF-4G56',
              veiculoModelo: 'Ducato',
              kmInicial: 50000,
              cidadeDestino: 'BARRETOS',
              dataHoraInicio: DateTime(2026, 11, 11, 6, 0),
              status: 'ativa',
            ),
            syncServiceOverride: syncService,
            pacientesStreamOverride: Stream.value([p]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byKey(const Key('botaoLogoutMotorista')), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Paciente(
            pacienteStreamOverride: Stream.value(p),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byKey(const Key('botaoLogoutPaciente')), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: GerenciadorViagensScreen(
            viagemServiceOverride: viagemService,
            dataInicial: DateTime(2026, 11, 11),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('botaoNovoHorarioFAB')), findsOneWidget);
      expect(find.byKey(const Key('botaoNovoHorarioBarra')), findsNothing);
      expect(find.text('Criar Novo Horário'), findsNothing);
      expect(find.byKey(const Key('botaoMapaFrotaAdmin')), findsOneWidget);

      await tester.tap(find.byKey(const Key('botaoMapaFrotaAdmin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Localização dos Motoristas'), findsOneWidget);
      expect(find.byKey(const Key('botaoGestaoPessoasAppBar')), findsNothing);
    });

    testWidgets('DetalhesVeiculo formata Timestamp e remove ações duplicadas', (tester) async {
      final veiculoMap = <String, dynamic>{
        'id': 'v_det_1',
        'placa': 'DEF4G56',
        'marca': 'Fiat',
        'modelo': 'Ducato Minibus',
        'tipo': 'van',
        'ano': 2023,
        'qtdAssentos': 15,
        'quilometragemAtual': 73000,
        'status': 'disponivel',
        'criadoEm': Timestamp.fromDate(DateTime(2026, 11, 11, 9, 30)),
        'atualizadoEm': Timestamp.fromDate(DateTime(2026, 11, 11, 10, 45)),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: DetalhesVeiculo(veiculo: veiculoMap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Veículo DEF4G56'), findsOneWidget);
      expect(find.text('Ver Detalhes'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Excluir Veículo'), findsOneWidget);
      expect(find.text('Editar Veículo'), findsOneWidget);
      expect(find.textContaining('Timestamp('), findsNothing);
      expect(find.text('11/11/2026 às 09:30'), findsOneWidget);
      expect(find.text('11/11/2026 às 10:45'), findsOneWidget);
    });
  });
}
