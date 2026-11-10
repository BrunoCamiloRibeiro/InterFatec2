import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/dialogo_confirmacao_motorista.dart';
import 'package:trans_saude/components/formulario_novo_veiculo.dart';
import 'package:trans_saude/components/modal_filtros_veiculo.dart';
import 'package:trans_saude/controllers/veiculo_controller.dart';
import 'package:trans_saude/detalhes_veiculo.dart';
import 'package:trans_saude/lista_pessoas.dart';
import 'package:trans_saude/lista_veiculos.dart';
import 'package:trans_saude/models/admin_model.dart';
import 'package:trans_saude/models/janela_reversao_model.dart';
import 'package:trans_saude/models/localizacao_motorista_model.dart';
import 'package:trans_saude/models/motorista_model.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/paciente.dart';
import 'package:trans_saude/screens/auth_gate.dart';
import 'package:trans_saude/screens/gerenciador_viagens_screen.dart';
import 'package:trans_saude/screens/login_screen.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

class _FakeRespAuthService implements AuthService {
  bool falharLogin = false;

  @override
  Future<UserRole> login(String cpf, String senha) async {
    if (falharLogin) {
      throw const AuthException(
        'Credenciais inválidas para o CPF informado. Verifique seus dados e tente novamente.',
      );
    }
    return UserRole.motorista;
  }

  @override
  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) async {
    return UserRole.paciente;
  }

  @override
  Future<void> logout() async {}

  @override
  Stream<String?> get authStateChanges => const Stream.empty();

  @override
  Future<UserRole> resolveUserRole(String uid, {bool forceRefresh = false}) async =>
      UserRole.motorista;

  @override
  UserRole? getCachedRole(String uid) => null;

  @override
  void clearRoleCache() {}

  @override
  String? get currentUserId => 'user_resp_test';
}

void _esperarSemExcecao(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void _configurarViewport(
  WidgetTester tester, {
  Size size = const Size(320, 568),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _appResponsivo(
  Widget home, {
  double textScale = 1.5,
  Map<String, WidgetBuilder>? routes,
}) {
  return MaterialApp(
    routes: routes ?? const {},
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: home,
  );
}

void main() {
  setUp(() {
    ViagemService().resetParaTestes(
      veiculosIniciais: const [
        VeiculoModel(
          id: 'v_spin',
          placa: 'ABC-1D23',
          marca: 'Chevrolet',
          modelo: 'Spin Premier Automática 7 Lugares',
          ano: 2025,
          qtdAssentos: 7,
          quilometragemAtual: 45200,
          status: StatusVeiculo.disponivel,
          emUso: false,
          possuiAC: true,
          possuiPreferencial: true,
          observacoes: 'Veículo revisado recentemente para transporte intermunicipal.',
        ),
        VeiculoModel(
          id: 'v_master',
          placa: 'BRA-2E45',
          marca: 'Renault',
          modelo: 'Master Minibus Executiva',
          ano: 2024,
          qtdAssentos: 15,
          quilometragemAtual: 98310,
          status: StatusVeiculo.emManutencao,
          emUso: false,
          possuiAC: true,
        ),
      ],
    );
    PacienteSyncService().resetParaTestes();
    VeiculoController().resetParaTestes(
      veiculosIniciais: const [
        VeiculoModel(
          id: 'v_spin',
          placa: 'ABC-1D23',
          marca: 'Chevrolet',
          modelo: 'Spin Premier Automática 7 Lugares',
          ano: 2025,
          qtdAssentos: 7,
          quilometragemAtual: 45200,
          status: StatusVeiculo.disponivel,
          possuiAC: true,
          possuiPreferencial: true,
          observacoes: 'Revisão preventiva em dia.',
        ),
        VeiculoModel(
          id: 'v_master',
          placa: 'BRA-2E45',
          marca: 'Renault',
          modelo: 'Master Minibus Executiva',
          ano: 2024,
          qtdAssentos: 15,
          quilometragemAtual: 98310,
          status: StatusVeiculo.emManutencao,
          possuiAC: true,
        ),
      ],
    );
  });

  tearDown(() {
    ViagemService().resetParaTestes();
    PacienteSyncService().resetParaTestes();
    VeiculoController().resetParaTestes();
  });

  group('Responsividade em Tela de Celular (320x568 e escala 1.5x)', () {
    testWidgets('1. LoginScreen e AuthGate não quebram em 320x568 com texto ampliado', (tester) async {
      _configurarViewport(tester);
      final fakeAuth = _FakeRespAuthService()..falharLogin = true;

      await tester.pumpWidget(_appResponsivo(LoginScreen(authService: fakeAuth)));
      await tester.pumpAndSettle();
      _esperarSemExcecao(tester);

      // Dispara erro extenso no formulário do motorista
      await tester.enterText(find.byKey(const Key('campoCpf')), '52998224725');
      await tester.enterText(find.byKey(const Key('campoSenha')), '123456');
      await tester.ensureVisible(find.byKey(const Key('botaoEntrar')));
      await tester.tap(find.byKey(const Key('botaoEntrar')));
      await tester.pumpAndSettle();
      _esperarSemExcecao(tester);
      expect(find.byKey(const Key('mensagemErro')), findsOneWidget);

      // Aguarda encerramento do SnackBar temporário para liberar o rodapé
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Alterna para o modo Paciente
      await tester.ensureVisible(find.byKey(const Key('botaoModoPaciente')));
      await tester.tap(find.byKey(const Key('botaoModoPaciente')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('campoDocumentoPaciente')), findsOneWidget);
      _esperarSemExcecao(tester);

      // AuthGate em estado de erro temporário
      final authCtrl = StreamController<String?>.broadcast();
      addTearDown(authCtrl.close);
      await tester.pumpWidget(
        _appResponsivo(
          AuthGate(
            authService: fakeAuth,
            authStateStream: authCtrl.stream,
            roleResolver: (_) async => throw const AuthException(
              'Falha de conexão com o servidor. Verifique sua internet e tente novamente.',
              code: 'unavailable',
            ),
          ),
        ),
      );
      authCtrl.add('uid_erro');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('botaoTentarNovamente')), findsOneWidget);
      _esperarSemExcecao(tester);
    });

    testWidgets('2. Fluxo do Motorista (início, viagem ativa, card longo, encerramento e diálogo)', (tester) async {
      _configurarViewport(tester);

      // Tela inicial de seleção de veículo
      await tester.pumpWidget(_appResponsivo(const Motorista()));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Início da Viagem'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Tela em viagem com nomes extensos, acompanhante, código e alerta
      final pacienteLongo = PacienteModel(
        id: 'pac_longo',
        nome: 'Maria Aparecida Gonçalves dos Santos Ferreira',
        cpf: '529.982.247-25',
        telefone: '(17) 99123-4567',
        enderecoPaciente: 'Avenida das Palmeiras Imperiais, 1450 - Jardim Aeroporto',
        localConsulta: 'Hospital de Amor - Ambulatório de Oncologia Clínica',
        localSaida: 'UBS Central de Poloni',
        horarioConsulta: '07:45',
        status: 2,
        prontoRetorno: true,
        nomeAcompanhante: 'José Carlos Gonçalves Ferreira',
        telAcompanhante: '(17) 99876-5432',
        janelaReversao: JanelaReversaoModel(
          acao: 'pronto_retorno',
          iniciadoEm: DateTime.utc(2026, 11, 10, 10, 0),
          expiraEm: DateTime.utc(2026, 11, 10, 10, 5),
          estadoAnterior: 2,
        ),
      );

      final viagemLonga = ViagemModel(
        id: 'v_longa_01',
        motoristaId: 'mot_01',
        motoristaNome: 'Antônio Carlos Rodrigues da Silva',
        veiculoId: 'v_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin Premier',
        kmInicial: 45200,
        cidadeDestino: 'SÃO JOSÉ DO RIO PRETO — HOSPITAL DE BASE',
        nomeHorario: '05:30 - Primeira Saída Intermunicipal',
        dataViagem: DateTime(2026, 11, 10),
        dataHoraInicio: DateTime(2026, 11, 10, 5, 30),
        status: 'ativa',
        codigosAcesso: const {'pac_longo': '4821'},
        passageiros: const [
          PassageiroViagemModel(
            pacienteId: 'pac_longo',
            pacienteNome: 'Maria Aparecida Gonçalves dos Santos Ferreira',
            pacienteCpf: '529.982.247-25',
            localOrigem: 'UBS Central de Poloni',
            localDestino: 'Hospital de Amor - Ambulatório de Oncologia Clínica',
            horarioAtendimento: '07:45',
            acompanhanteNome: 'José Carlos Gonçalves Ferreira',
            statusEmbarque: 2,
            prontoRetorno: true,
          ),
        ],
      );

      await tester.pumpWidget(
        _appResponsivo(
          Motorista(
            viagemInicial: viagemLonga,
            pacientesStreamOverride: Stream.value([pacienteLongo]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Gerar Relatório'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Abre diálogo de confirmação e depois o FormularioEncerramento
      await tester.tap(find.text('Gerar Relatório'));
      await tester.pumpAndSettle();
      expect(find.text('Finalizar Viagem'), findsOneWidget);
      _esperarSemExcecao(tester);

      await tester.tap(find.byKey(const Key('botaoConfirmarFinalizacao')));
      await tester.pumpAndSettle();
      expect(find.text('Formulário de Encerramento'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Fecha o FormularioEncerramento
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Testa diálogo ergonômico do motorista em tela estreita
      final ctx = tester.element(find.byType(Scaffold).first);
      unawaited(
        exibirDialogoConfirmacaoMotorista(
          context: ctx,
          nomePaciente: pacienteLongo.nome,
          proximoStatusNome: 'Embarcou para Volta',
          proximoStatusCor: Colors.green.shade700,
          proximoStatusIcone: Icons.directions_bus,
          localDestino: pacienteLongo.localConsulta,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('botao_confirmar_dialogo_motorista')), findsOneWidget);
      _esperarSemExcecao(tester);

      await tester.tap(find.byKey(const Key('botao_cancelar_dialogo_motorista')));
      await tester.pumpAndSettle();
    });

    testWidgets('3. Tela do Paciente completa (consulta, banner undo, botões empilhados e mapa)', (tester) async {
      _configurarViewport(tester);

      final agora = DateTime.now().toUtc();
      final pac = PacienteModel(
        id: 'p_mobile_01',
        nome: 'Maria Aparecida Gonçalves dos Santos Ferreira',
        cpf: '529.982.247-25',
        telefone: '(17) 99123-4567',
        enderecoPaciente: 'Rua Marechal Deodoro da Fonseca, 1280',
        localConsulta: 'Hospital de Base - Ambulatório de Cardiologia',
        localSaida: 'UBS Central',
        horarioConsulta: '08:30',
        status: 2,
        prontoRetorno: true,
        nomeAcompanhante: 'João Pedro dos Santos',
        janelaReversao: JanelaReversaoModel(
          acao: 'pronto_retorno',
          iniciadoEm: agora,
          expiraEm: agora.add(const Duration(seconds: 60)),
          estadoAnterior: 2,
        ),
      );

      final motoristasAtivos = [
        LocalizacaoMotoristaModel(
          id: 'loc_m1',
          motoristaId: 'm1',
          motoristaNome: 'Antônio Carlos Rodrigues da Silva',
          veiculoPlaca: 'ABC-1D23',
          veiculoModelo: 'Chevrolet Spin Premier',
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          latitude: -20.8120,
          longitude: -49.3810,
          ultimaAtualizacao: agora,
          emViagem: true,
        ),
      ];

      await tester.pumpWidget(
        _appResponsivo(
          Paciente(
            pacienteId: 'p_mobile_01',
            pacienteStreamOverride: Stream.value(pac),
            motoristasStreamOverride: Stream.value(motoristasAtivos),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Painel do Paciente'), findsOneWidget);
      expect(find.text('Localização dos Motoristas'), findsOneWidget);
      expect(find.text('Focar no Mapa'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Desmonta o widget para cancelar o Timer.periodic de 1s do BannerReversaoPaciente
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('4. GerenciadorViagensScreen e modais administrativos não quebram em 320x568', (tester) async {
      _configurarViewport(tester);

      final dataTeste = DateTime(2026, 11, 10);
      final fakeAuth = _FakeRespAuthService();
      final service = ViagemService();
      service.resetParaTestes(
        todasViagensIniciais: [
          ViagemModel(
            id: 'h_mob_1',
            motoristaId: 'm1',
            motoristaNome: 'Carlos Motorista',
            veiculoId: 'v_spin',
            veiculoPlaca: 'ABC-1D23',
            veiculoModelo: 'Spin Premier',
            kmInicial: 45200,
            cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
            nomeHorario: '05:30 - Saída Hospital de Base',
            dataViagem: dataTeste,
            dataHoraInicio: DateTime(2026, 11, 10, 5, 30),
            status: 'planejada',
            codigosAcesso: const {'p1': '7101'},
            passageiros: const [
              PassageiroViagemModel(
                pacienteId: 'p1',
                pacienteNome: 'Maria Aparecida Gonçalves dos Santos',
                localOrigem: 'UBS Central',
                localDestino: 'Hospital de Base - Setor B',
                horarioAtendimento: '08:00',
                ordemEmbarque: 1,
                acompanhanteNome: 'Carlos Acompanhante',
                observacoes: 'Uso de cadeira de rodas dobrável',
              ),
              PassageiroViagemModel(
                pacienteId: 'p2',
                pacienteNome: 'José da Silva Oliveira Neto',
                localOrigem: 'Policlínica',
                localDestino: 'AME Rio Preto',
                horarioAtendimento: '09:30',
                ordemEmbarque: 2,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        _appResponsivo(
          GerenciadorViagensScreen(
            viagemServiceOverride: service,
            authServiceOverride: fakeAuth,
            dataInicial: dataTeste,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gerenciador de Horários'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Modal Novo Horário -> Adicionar Passageiro
      await tester.tap(find.byKey(const Key('botaoNovoHorarioFAB')));
      await tester.pumpAndSettle();
      _esperarSemExcecao(tester);

      await tester.ensureVisible(find.byKey(const Key('botaoAdicionarPassageiroModal')));
      await tester.tap(find.byKey(const Key('botaoAdicionarPassageiroModal')));
      await tester.pumpAndSettle();
      expect(find.text('Adicionar Passageiro ao Horário'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Fecha Adicionar Passageiro e Novo Horário
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();

      // Modal Reordenar Embarque
      await tester.ensureVisible(find.byKey(const Key('botaoReordenar_h_mob_1')));
      await tester.tap(find.byKey(const Key('botaoReordenar_h_mob_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('botaoSalvarReordenacao')), findsOneWidget);
      _esperarSemExcecao(tester);
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();

      // Modal Duplicar Grade de Horários
      await tester.ensureVisible(find.byKey(const Key('botaoDuplicarHorarios')));
      await tester.tap(find.byKey(const Key('botaoDuplicarHorarios')));
      await tester.pumpAndSettle();
      expect(find.text('Duplicar Grade de Horários'), findsOneWidget);
      _esperarSemExcecao(tester);
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
    });

    testWidgets('5. Gestão de Pessoas, Frota de Veículos e modais não quebram em 320x568', (tester) async {
      _configurarViewport(tester);

      // 5A. ListaPessoas + FormularioPessoa + Exclusão
      await tester.pumpWidget(
        _appResponsivo(
          ListaPessoas(
            mockPacientes: [
              PacienteModel(
                id: 'pac_1',
                nome: 'Maria Aparecida Gonçalves dos Santos',
                cpf: '529.982.247-25',
                telefone: '(17) 99111-2222',
                enderecoPaciente: 'Rua das Acácias, 100',
                localConsulta: 'Hospital de Amor Barretos',
              ),
            ],
            mockMotoristas: [
              MotoristaModel(
                id: 'mot_1',
                nome: 'Carlos Eduardo Pereira da Silva',
                cpf: '111.222.333-44',
                telefone: '(17) 99222-3333',
                email: 'carlos@transsaude.sp.gov.br',
                cnh: '12345678901',
                veiculoModelo: 'Spin',
                veiculoPlaca: 'ABC-1D23',
              ),
            ],
            mockAdmins: [
              AdminModel(
                id: 'adm_1',
                nome: 'Ana Paula Coordenação',
                cpf: '999.888.777-66',
                telefone: '(17) 99333-4444',
                email: 'admin@transsaude.sp.gov.br',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gestão de Pessoas'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Abre FormularioPessoa e alterna papéis
      await tester.tap(find.text('Novo'));
      await tester.pumpAndSettle();
      expect(find.text('Nova Pessoa'), findsOneWidget);
      _esperarSemExcecao(tester);

      await tester.ensureVisible(find.byKey(const Key('checkboxAcompanhante')));
      await tester.tap(find.byKey(const Key('checkboxAcompanhante')));
      await tester.pumpAndSettle();
      _esperarSemExcecao(tester);

      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();

      // 5B. Lista de Veículos + Filtros + Novo Veículo + DetalhesVeiculo
      await tester.pumpWidget(_appResponsivo(const Veiculos()));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Lista de Veículos'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Modal Filtros de Veículos
      await tester.tap(find.byIcon(Icons.tune_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Filtros de Veículos'), findsOneWidget);
      _esperarSemExcecao(tester);
      await tester.tap(find.text('Aplicar Filtros'));
      await tester.pumpAndSettle();

      // Modal Novo Veículo
      await tester.tap(find.text('Novo Veículo'));
      await tester.pumpAndSettle();
      expect(find.byType(FormularioNovoVeiculo), findsOneWidget);
      _esperarSemExcecao(tester);
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();

      // Tela DetalhesVeiculo
      await tester.ensureVisible(find.text('Ver Detalhes').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver Detalhes').first);
      await tester.pumpAndSettle();
      expect(find.byType(DetalhesVeiculo), findsOneWidget);
      _esperarSemExcecao(tester);
      await tester.scrollUntilVisible(
        find.text('Excluir Veículo'),
        200.0,
        scrollable: find.descendant(
          of: find.byType(DetalhesVeiculo),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Excluir Veículo'), findsOneWidget);
      expect(find.text('Editar Veículo'), findsOneWidget);
      _esperarSemExcecao(tester);

      // Garante também ModalFiltrosVeiculo isolado
      await tester.pumpWidget(
        _appResponsivo(
          Scaffold(
            body: ModalFiltrosVeiculo(filtroAtual: FiltroVeiculos()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _esperarSemExcecao(tester);
    });
  });
}
