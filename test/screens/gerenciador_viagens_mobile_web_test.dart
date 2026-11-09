// ============================================================================
// TESTE DE INTERFACE WEB EM TAMANHO DE CELULAR E DESKTOP (VIEWPORT 360DP)
// ----------------------------------------------------------------------------
// Repositório: BrunoCamiloRibeiro/InterFatec2
// Contexto: Issue #65 - Verificação de responsividade do Gerenciador de Horários
//           em dimensões mobile (360x640) e desktop (1280x800) sem estouros de
//           layout (RenderFlex overflow) e com componentes operacionais.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/screens/gerenciador_viagens_screen.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<UserRole> login(String cpf, String senha) async => UserRole.admin;
  @override
  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) async =>
      UserRole.paciente;
  @override
  Future<void> logout() async {}
  @override
  Stream<String?> get authStateChanges => const Stream.empty();
  @override
  Future<UserRole> resolveUserRole(String uid, {bool forceRefresh = false}) async =>
      UserRole.admin;
  @override
  UserRole? getCachedRole(String uid) => UserRole.admin;
  @override
  void clearRoleCache() {}
  @override
  String? get currentUserId => 'admin_mobile_test';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViagemService viagemService;
  final dataTeste = DateTime(2026, 11, 8);

  setUp(() {
    viagemService = ViagemService();
    viagemService.resetParaTestes(
      veiculosIniciais: const [
        VeiculoModel(
          id: 'v1',
          placa: 'ABC-1D23',
          modelo: 'Spin',
          capacidade: 7,
          quilometragemAtual: 50000,
        ),
      ],
      todasViagensIniciais: [
        ViagemModel(
          id: 'h1',
          motoristaId: 'mot_antonio',
          motoristaNome: 'Antônio Carlos',
          veiculoId: 'v1',
          veiculoPlaca: 'ABC-1D23',
          veiculoModelo: 'Spin',
          kmInicial: 50000,
          cidadeDestino: 'BARRETOS',
          nomeHorario: '06:00 - Saída Barretos',
          dataViagem: dataTeste,
          dataHoraInicio: DateTime(2026, 11, 8, 6),
          status: 'planejada',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p1',
              pacienteNome: 'Maria Aparecida',
              localDestino: 'Hospital de Amor',
              horarioAtendimento: '09:00',
              ordemEmbarque: 1,
            ),
          ],
        ),
      ],
    );
  });

  Widget criarWidgetTest({required ViagemService service, required AuthService auth}) {
    return MaterialApp(
      home: GerenciadorViagensScreen(
        viagemServiceOverride: service,
        authServiceOverride: auth,
        dataInicial: dataTeste,
      ),
    );
  }

  group('GerenciadorViagensScreen - Responsividade Mobile e Desktop Web', () {
    testWidgets('1. Renderiza no viewport de celular 360x640 sem RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(criarWidgetTest(service: viagemService, auth: fakeAuth));
      await tester.pumpAndSettle();

      // Verifica presença do título e vocabulário "Horário"
      expect(find.text('Gerenciador de Horários'), findsOneWidget);
      expect(find.byKey(const Key('botaoNovoHorarioFAB')), findsOneWidget);
      expect(find.byKey(const Key('campoBuscaHorario')), findsOneWidget);

      // Card de horário
      expect(find.text('06:00 - Saída Barretos'), findsOneWidget);
      expect(find.text('BARRETOS'), findsOneWidget);
      expect(find.text('PLANEJADA'), findsOneWidget);
      expect(find.text('Maria Aparecida'), findsOneWidget);

      // Nenhum erro de overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Renderiza no viewport desktop 1280x800 sem RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(criarWidgetTest(service: viagemService, auth: fakeAuth));
      await tester.pumpAndSettle();

      expect(find.text('Gerenciador de Horários'), findsOneWidget);
      expect(find.text('06:00 - Saída Barretos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Abre diálogo de Novo Horário em 360x640 sem overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(criarWidgetTest(service: viagemService, auth: fakeAuth));
      await tester.pumpAndSettle();

      // Clica no botão flutuante de Novo Horário
      await tester.tap(find.byKey(const Key('botaoNovoHorarioFAB')));
      await tester.pumpAndSettle();

      expect(find.text('Novo Horário de Saída'), findsOneWidget);
      expect(find.byKey(const Key('campoNomeHorario')), findsOneWidget);
      expect(find.byKey(const Key('campoCidadeDestino')), findsOneWidget);
      expect(find.byKey(const Key('dropdownVeiculo')), findsNothing);
      expect(find.byKey(const Key('dropdownMotorista')), findsNothing);
      expect(find.byKey(const Key('botaoSalvarHorarioModal')), findsOneWidget);

      // Fecha o diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Abre menu lateral (Drawer) e acessa itens de navegação', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(criarWidgetTest(service: viagemService, auth: fakeAuth));
      await tester.pumpAndSettle();

      // Abre o Drawer através do ScaffoldState
      final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menuLateralAdmin')), findsOneWidget);
      expect(find.text('TransSaúde Municipal'), findsOneWidget);
      expect(find.text('PAINEL DO ADMINISTRADOR'), findsOneWidget);
      expect(find.byKey(const Key('menuItemHorarios')), findsOneWidget);
      expect(find.byKey(const Key('menuItemGestaoPessoas')), findsOneWidget);
      expect(find.byKey(const Key('menuItemGestaoVeiculos')), findsOneWidget);
      expect(find.byKey(const Key('botaoLogoutAdminCorpo')), findsOneWidget);

      // Clica em Gestão de Pessoas
      await tester.tap(find.byKey(const Key('menuItemGestaoPessoas')));
      await tester.pumpAndSettle();

      // Verifica que navegou para a tela de Gestão de Pessoas
      expect(find.text('Gestão de Pessoas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
