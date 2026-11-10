import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/screens/login_screen.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

class _FakeAuthAlternancia extends FirebaseAuthService {
  final Map<String, ({UserRole role, String docId, bool emViagem})> usuarios;
  String? _docAtual;

  _FakeAuthAlternancia(this.usuarios);

  @override
  String? get currentUserId => _docAtual;

  @override
  String? get currentDocId => _docAtual;

  @override
  Future<UserRole> login(String cpf, String senha) async {
    final clean = cpf.replaceAll(RegExp(r'\D'), '');
    final reg = usuarios[clean];
    if (reg == null) {
      throw const AuthException('CPF ou senha incorretos.');
    }
    _docAtual = reg.docId;
    FirebaseAuthService.motoristaEmViagemStatic = reg.emViagem;
    return reg.role;
  }

  @override
  Future<void> logout() async {
    _docAtual = null;
    FirebaseAuthService.motoristaEmViagemStatic = null;
    ViagemService().limparSessaoLocal();
  }
}

void main() {
  setUp(() {
    FirebaseAuthService.motoristaEmViagemStatic = null;
    PacienteSyncService().resetParaTestes();
    ViagemService().resetParaTestes();
  });

  tearDown(() {
    FirebaseAuthService.motoristaEmViagemStatic = null;
    PacienteSyncService().resetParaTestes();
    ViagemService().resetParaTestes();
  });

  group('Isolamento de Sessões Entre Motoristas (Início e Fim Independentes)', () {
    test(
      'restaurarSessaoMotoristaSeAtiva não sequestra viagem ativa sem motoristaId nem de outro condutor',
      () {
        final service = ViagemService();
        const veicA = VeiculoModel(
          id: 'veic_a',
          placa: 'AAA-1111',
          modelo: 'Spin A',
          quilometragemAtual: 10000,
          emUso: true,
          motoristaAtualId: 'mot_a',
        );
        const veicB = VeiculoModel(
          id: 'veic_b',
          placa: 'BBB-2222',
          modelo: 'Spin B',
          quilometragemAtual: 20000,
          emUso: false,
        );
        final viagemAtivaSemMot = ViagemModel(
          id: 'viagem_ativa_shared',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: 'veic_a',
          veiculoPlaca: 'AAA-1111',
          veiculoModelo: 'Spin A',
          kmInicial: 10000,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          sessaoId: 'sessao_mot_a',
          passageirosIds: const ['p1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p1',
              pacienteNome: 'Ana',
              localDestino: 'Hospital',
              statusEmbarque: 1,
            ),
          ],
        );

        service.resetParaTestes(
          veiculosIniciais: const [veicA, veicB],
          todasViagensIniciais: [viagemAtivaSemMot],
        );

        // Motorista B sem carro ativo (emViagem=false) não pode adotar viagem/veículo de A.
        service.restaurarSessaoMotoristaSeAtiva(
          motoristaId: 'mot_b',
          motoristaNome: 'Bruno',
          frota: const [veicA, veicB],
        );

        expect(service.viagemAtiva, isNull);
        expect(service.viagensAtivas, isEmpty);
        expect(service.sessaoAtiva, isNull);
      },
    );

    test(
      'Encerrar a sessão do Motorista A NÃO encerra a sessão nem libera o veículo do Motorista B',
      () async {
        final service = ViagemService();
        const veicA = VeiculoModel(
          id: 'veic_a',
          placa: 'AAA-1111',
          modelo: 'Spin A',
          quilometragemAtual: 10000,
          capacidade: 4,
          emUso: false,
        );
        const veicB = VeiculoModel(
          id: 'veic_b',
          placa: 'BBB-2222',
          modelo: 'Van B',
          quilometragemAtual: 20000,
          capacidade: 15,
          emUso: false,
        );

        final viagemA = ViagemModel(
          id: 'viagem_barretos_a',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: '',
          veiculoPlaca: '',
          veiculoModelo: '',
          kmInicial: 0,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime.now(),
          status: 'planejada',
          passageirosIds: const ['pac_a'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_a',
              pacienteNome: 'Paciente A',
              localDestino: 'HB',
              statusEmbarque: 0,
            ),
          ],
        );
        final viagemB = ViagemModel(
          id: 'viagem_barretos_b',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: '',
          veiculoPlaca: '',
          veiculoModelo: '',
          kmInicial: 0,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime.now(),
          status: 'planejada',
          passageirosIds: const ['pac_b'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_b',
              pacienteNome: 'Paciente B',
              localDestino: 'HA',
              statusEmbarque: 0,
            ),
          ],
        );

        service.resetParaTestes(
          veiculosIniciais: const [veicA, veicB],
          todasViagensIniciais: [viagemA, viagemB],
        );

        // Motorista A declara veic_a e inicia jornada (adota viagens planejadas abertas de A).
        await service.declararVeiculo(
          veiculo: veicA,
          kmInicial: 10050,
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
          cidadeDestino: 'Barretos',
        );
        await service.iniciarViagem(
          veiculo: veicA,
          kmInicial: 10050,
          cidadeDestino: 'Barretos',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
        );

        // Simula criação posterior da viagem B atribuída a mot_b e início da jornada de B.
        final viagemBComMot = viagemB.copyWith(
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
        );
        service.sincronizarViagensRemotas([
          ...service.todasViagens.where((v) => v.id != 'viagem_barretos_b'),
          viagemBComMot,
        ]);

        await service.declararVeiculo(
          veiculo: veicB,
          kmInicial: 20100,
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
          cidadeDestino: 'Barretos',
        );
        await service.iniciarViagem(
          veiculo: veicB,
          kmInicial: 20100,
          cidadeDestino: 'Barretos',
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
        );

        // Motorista A finaliza a PRÓPRIA jornada (kmFinal: 10150).
        await service.encerrarTodasViagens(
          kmFinal: 10150,
          kmRodado: 100,
          motoristaId: 'mot_a',
        );

        // Veículo A foi liberado; Veículo B CONTINUA em uso por mot_b!
        final vAFinal = service.todosVeiculos.firstWhere((v) => v.id == 'veic_a');
        final vBFinal = service.todosVeiculos.firstWhere((v) => v.id == 'veic_b');
        expect(vAFinal.emUso, isFalse);
        expect(vAFinal.motoristaAtualId, isNull);
        expect(vBFinal.emUso, isTrue);
        expect(vBFinal.motoristaAtualId, equals('mot_b'));

        // A viagem de B continua ativa sob posse de mot_b; as viagens sem retorno de A permanecem abertas ('ativa'), nunca 'encerrada'.
        final ativasMotB = service.obterViagensAtivasPorMotorista(
          'mot_b',
          veiculoId: 'veic_b',
        );
        expect(ativasMotB.any((v) => v.id == 'viagem_barretos_b'), isTrue);
        final vAPersistida = service.todasViagens.firstWhere(
          (v) => v.id == 'viagem_barretos_a',
        );
        expect(vAPersistida.status, equals('ativa'));
        expect(vAPersistida.isConcluida, isFalse);
      },
    );

    test(
      'Viagem sem passageiros embarcados/cadastrados não muda para status encerrada quando motorista libera o veículo',
      () async {
        final service = ViagemService();
        const veic = VeiculoModel(
          id: 'veic_vazio',
          placa: 'VAZ-0001',
          modelo: 'Spin',
          quilometragemAtual: 5000,
          emUso: false,
        );
        final viagemVazia = ViagemModel(
          id: 'viagem_sem_pacs',
          motoristaId: 'mot_x',
          motoristaNome: 'Xavier',
          veiculoId: 'veic_vazio',
          veiculoPlaca: 'VAZ-0001',
          veiculoModelo: 'Spin',
          kmInicial: 5000,
          cidadeDestino: 'Mirassol',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          sessaoId: 'sessao_mot_x',
          passageiros: const [],
          passageirosIds: const [],
        );

        service.resetParaTestes(
          veiculosIniciais: const [veic],
          viagensAtivasIniciais: [viagemVazia],
        );

        await service.encerrarViagem(
          viagemId: 'viagem_sem_pacs',
          kmFinal: 5050,
          kmRodado: 50,
        );

        final vAtualizada =
            service.todasViagens.firstWhere((v) => v.id == 'viagem_sem_pacs');
        expect(vAtualizada.status, equals('ativa'));
        expect(vAtualizada.isConcluida, isFalse);
      },
    );

    testWidgets(
      'Alternância Login A -> Inicia Viagem A -> Logout -> Login B (emViagem=false) exibe formulário de início limpo para B',
      (tester) async {
        final service = ViagemService();
        const veicA = VeiculoModel(
          id: 'veic_a',
          placa: 'AAA-1111',
          modelo: 'Spin A',
          quilometragemAtual: 10000,
          emUso: true,
          motoristaAtualId: 'mot_a',
        );
        const veicB = VeiculoModel(
          id: 'veic_b',
          placa: 'BBB-2222',
          modelo: 'Spin B',
          quilometragemAtual: 20000,
          emUso: false,
        );
        final viagemA = ViagemModel(
          id: 'viagem_do_a',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
          veiculoId: 'veic_a',
          veiculoPlaca: 'AAA-1111',
          veiculoModelo: 'Spin A',
          kmInicial: 10000,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          sessaoId: 'sessao_mot_a',
          passageirosIds: const ['pac_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_1',
              pacienteNome: 'Paciente Secreto do A',
              localDestino: 'Hospital',
              statusEmbarque: 1,
            ),
          ],
        );

        service.resetParaTestes(
          veiculosIniciais: const [veicA, veicB],
          todasViagensIniciais: [viagemA],
          viagensAtivasIniciais: [viagemA],
        );

        final fakeAuth = _FakeAuthAlternancia({
          '52998224725': (role: UserRole.motorista, docId: 'mot_a', emViagem: true),
          '15350946056': (role: UserRole.motorista, docId: 'mot_b', emViagem: false),
        });

        await fakeAuth.login('52998224725', '123456');
        service.restaurarSessaoMotoristaSeAtiva(
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
        );
        expect(service.viagemAtiva?.id, equals('viagem_do_a'));

        // Motorista A faz logout e Motorista B (emViagem = false) entra pela LoginScreen.
        await fakeAuth.logout();
        expect(service.sessaoAtiva, isNull);
        expect(service.viagemAtiva, isNull);

        await tester.pumpWidget(
          MaterialApp(
            routes: {
              '/': (_) => LoginScreen(authService: fakeAuth),
              '/motorista': (_) => const Motorista(),
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('campoCpf')),
          '15350946056',
        );
        await tester.enterText(
          find.byKey(const Key('campoSenha')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('botaoEntrar')));
        await tester.pumpAndSettle();

        // Motorista B deve ver o formulário de início de viagem e NÃO ver a lista do A.
        expect(find.text('Início da Viagem'), findsOneWidget);
        expect(find.text('Lista de Passageiros'), findsNothing);
        expect(find.text('Paciente Secreto do A'), findsNothing);
      },
    );

    test(
      'Motorista B vê todas as viagens operacionais (ativa e aberta), modifica paciente compartilhado sem criar viagem fantasma e libera somente seu veículo ao finalizar',
      () async {
        final service = ViagemService();
        const veicA = VeiculoModel(
          id: 'veic_a',
          placa: 'AAA-1111',
          modelo: 'Spin A',
          quilometragemAtual: 10000,
          capacidade: 4,
          emUso: true,
          motoristaAtualId: 'mot_a',
        );
        const veicBus = VeiculoModel(
          id: 'veic_bus',
          placa: 'BUS-9K88',
          modelo: 'Ônibus Municipal',
          quilometragemAtual: 80000,
          capacidade: 44,
          emUso: false,
        );
        const veicB = VeiculoModel(
          id: 'veic_b',
          placa: 'BBB-2222',
          modelo: 'Van B',
          quilometragemAtual: 20000,
          capacidade: 15,
          emUso: false,
        );

        final viagem1 = ViagemModel(
          id: 'viagem_1',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
          veiculoId: 'veic_a',
          veiculoPlaca: 'AAA-1111',
          veiculoModelo: 'Spin A',
          kmInicial: 10000,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          sessaoId: 'sessao_mot_a',
          passageirosIds: const ['pac_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_1',
              pacienteNome: 'Ana Silva',
              localDestino: 'HB',
              statusEmbarque: 1,
            ),
          ],
        );
        final viagem2 = ViagemModel(
          id: 'viagem_2',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: 'veic_bus',
          veiculoPlaca: 'BUS-9K88',
          veiculoModelo: 'Ônibus Municipal',
          kmInicial: 80000,
          cidadeDestino: 'Rio Preto',
          dataHoraInicio: DateTime.now(),
          status: 'aberta',
          passageirosIds: const ['pac_2'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_2',
              pacienteNome: 'Carlos Souza',
              localDestino: 'Base',
              statusEmbarque: 0,
            ),
          ],
        );
        final viagemClosed = ViagemModel(
          id: 'viagem_closed',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
          veiculoId: 'veic_a',
          veiculoPlaca: 'AAA-1111',
          veiculoModelo: 'Spin A',
          kmInicial: 9500,
          kmFinal: 9900,
          kmRodado: 400,
          cidadeDestino: 'Jaú',
          dataHoraInicio: DateTime.now(),
          status: 'encerrada',
          passageirosIds: const ['pac_old'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_old',
              pacienteNome: 'Antigo',
              localDestino: 'Amaral Carvalho',
              statusEmbarque: 4,
            ),
          ],
        );

        service.resetParaTestes(
          veiculosIniciais: const [veicA, veicBus, veicB],
          todasViagensIniciais: [viagem1, viagem2, viagemClosed],
        );

        await service.declararVeiculo(
          veiculo: veicB,
          kmInicial: 20100,
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
          cidadeDestino: 'São José do Rio Preto',
        );
        await service.iniciarViagem(
          veiculo: veicB,
          kmInicial: 20100,
          cidadeDestino: 'São José do Rio Preto',
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
        );

        expect(
          service.viagensAtivas.any((v) => v.id.startsWith('sessao_ativa_')),
          isFalse,
        );
        final idsAtivos = service.viagensAtivas.map((v) => v.id).toSet();
        expect(idsAtivos, containsAll(['viagem_1', 'viagem_2']));
        expect(idsAtivos, isNot(contains('viagem_closed')));

        final v1Compartilhada =
            service.viagensAtivas.firstWhere((v) => v.id == 'viagem_1');
        expect(v1Compartilhada.motoristaId, equals('mot_a'));
        expect(v1Compartilhada.veiculoId, equals('veic_a'));

        await service.atualizarStatusPassageiroNaViagem(
          viagemId: 'viagem_1',
          pacienteId: 'pac_1',
          novoStatus: 2,
          persistirRemoto: false,
        );
        final v1Atualizada =
            service.todasViagens.firstWhere((v) => v.id == 'viagem_1');
        expect(v1Atualizada.passageiros.first.statusEmbarque, equals(2));

        await service.encerrarTodasViagens(
          kmFinal: 20200,
          kmRodado: 100,
          motoristaId: 'mot_b',
        );

        final vAFinal = service.todosVeiculos.firstWhere((v) => v.id == 'veic_a');
        final vBFinal = service.todosVeiculos.firstWhere((v) => v.id == 'veic_b');
        expect(vBFinal.emUso, isFalse);
        expect(vBFinal.motoristaAtualId, isNull);
        expect(vAFinal.emUso, isTrue);
        expect(vAFinal.motoristaAtualId, equals('mot_a'));

        final v1AposFimB =
            service.todasViagens.firstWhere((v) => v.id == 'viagem_1');
        final v2AposFimB =
            service.todasViagens.firstWhere((v) => v.id == 'viagem_2');
        expect(v1AposFimB.isEmOperacao, isTrue);
        expect(v2AposFimB.isEmOperacao, isTrue);
      },
    );

    testWidgets(
      'Motorista B exibe placa e capacidade do próprio veículo e pagina entre viagem ativa e aberta vendo todos os pacientes',
      (tester) async {
        final service = ViagemService();
        const veicA = VeiculoModel(
          id: 'veic_a',
          placa: 'AAA-1111',
          modelo: 'Spin A',
          quilometragemAtual: 10000,
          capacidade: 4,
          emUso: true,
          motoristaAtualId: 'mot_a',
        );
        const veicB = VeiculoModel(
          id: 'veic_b',
          placa: 'BBB-2222',
          modelo: 'Van B',
          quilometragemAtual: 20000,
          capacidade: 15,
          emUso: false,
        );

        final viagem1 = ViagemModel(
          id: 'viagem_1',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
          veiculoId: 'veic_a',
          veiculoPlaca: 'AAA-1111',
          veiculoModelo: 'Spin A',
          kmInicial: 10000,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          sessaoId: 'sessao_mot_a',
          passageirosIds: const ['pac_1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_1',
              pacienteNome: 'Ana Compartilhada',
              localDestino: 'HB',
              statusEmbarque: 1,
            ),
          ],
        );
        final viagem2 = ViagemModel(
          id: 'viagem_2',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: 'veic_bus',
          veiculoPlaca: 'BUS-9K88',
          veiculoModelo: 'Ônibus',
          kmInicial: 80000,
          cidadeDestino: 'Rio Preto',
          dataHoraInicio: DateTime.now(),
          status: 'aberta',
          passageirosIds: const ['pac_2'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_2',
              pacienteNome: 'Carlos Aberta',
              localDestino: 'Base',
              statusEmbarque: 0,
            ),
          ],
        );
        final viagemClosed = ViagemModel(
          id: 'viagem_closed',
          motoristaId: 'mot_a',
          motoristaNome: 'Motorista A',
          veiculoId: 'veic_a',
          veiculoPlaca: 'AAA-1111',
          veiculoModelo: 'Spin A',
          kmInicial: 9500,
          kmFinal: 9900,
          kmRodado: 400,
          cidadeDestino: 'Jaú',
          dataHoraInicio: DateTime.now(),
          status: 'encerrada',
          passageirosIds: const ['pac_old'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_old',
              pacienteNome: 'Encerrada Não Exibida',
              localDestino: 'Amaral Carvalho',
              statusEmbarque: 4,
            ),
          ],
        );

        service.resetParaTestes(
          veiculosIniciais: const [veicA, veicB],
          todasViagensIniciais: [viagem1, viagem2, viagemClosed],
        );

        await service.declararVeiculo(
          veiculo: veicB,
          kmInicial: 20100,
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
          cidadeDestino: 'Rio Preto',
        );
        await service.iniciarViagem(
          veiculo: veicB,
          kmInicial: 20100,
          cidadeDestino: 'Rio Preto',
          motoristaId: 'mot_b',
          motoristaNome: 'Motorista B',
        );
        FirebaseAuthService.motoristaEmViagemStatic = true;

        await tester.pumpWidget(
          const MaterialApp(home: Motorista()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Em Viagem: BBB-2222'), findsOneWidget);
        expect(find.text('Lugares: 1 / 15'), findsOneWidget);
        expect(find.textContaining('Viagem 1 de 2'), findsOneWidget);
        expect(find.textContaining('ANA COMPARTILHADA'), findsOneWidget);
        expect(find.textContaining('ENCERRADA NÃO EXIBIDA'), findsNothing);

        await tester.tap(find.byIcon(Icons.arrow_forward_ios));
        await tester.pumpAndSettle();

        expect(find.text('Em Viagem: BBB-2222'), findsOneWidget);
        expect(find.text('Lugares: 0 / 15'), findsOneWidget);
        expect(find.textContaining('Viagem 2 de 2'), findsOneWidget);
        expect(find.textContaining('CARLOS ABERTA'), findsOneWidget);
      },
    );
  });
}
