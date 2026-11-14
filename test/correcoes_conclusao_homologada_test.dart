// ============================================================================
// ARQUIVO: test/correcoes_conclusao_homologada_test.dart
// ----------------------------------------------------------------------------
// Testes unitários para as novas soluções implementadas:
// 1. Lazy Migration no Login: migra credencial do Firestore para o Firebase Auth
//    e expira campos senha e password em texto plano.
// 2. Validação direta de odômetro no encerramento: kmRetorno < kmInicial bloqueia;
//    kmRetorno >= kmInicial calcula kmRodado = kmRetorno - kmInicial.
// 3. Conclusão da viagem grava snapshot imutável em viagens_homologadas e
//    atualiza emViagem: false no motorista em usuarios.
// 4. Tolerância a falha: erro na geração do PDF não aborta a conclusão homologada.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/components/formulario_encerramento.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/user_role.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/motorista.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/models/janela_reversao_model.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

class _MockUser implements User {
  @override
  final String uid;
  @override
  final String? email;
  _MockUser({required this.uid, this.email});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockUserCredential implements UserCredential {
  @override
  final User? user;
  _MockUserCredential({this.user});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFirebaseAuth implements FirebaseAuth {
  final Map<String, String> credenciaisValidas = {};
  User? _currentUser;
  bool createUserChamado = false;

  @override
  User? get currentUser => _currentUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (credenciaisValidas.containsKey(email) &&
        credenciaisValidas[email] == password) {
      final user = _MockUser(uid: 'uid_$email', email: email);
      _currentUser = user;
      return _MockUserCredential(user: user);
    }
    throw FirebaseAuthException(code: 'user-not-found');
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createUserChamado = true;
    credenciaisValidas[email] = password;
    final user = _MockUser(uid: 'uid_criado_$email', email: email);
    _currentUser = user;
    return _MockUserCredential(user: user);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Simulação de Firestore com suporte a update de documento
// ignore: subtype_of_sealed_class
class _MockDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;
  _MockDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _MockQuerySnapshot(this.docs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _MockDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  final String docId;
  final Map<String, Map<String, dynamic>> store;
  _MockDocumentReference(this.docId, this.store);

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final doc = store[docId] ?? <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key.toString();
      if (entry.value is FieldValue) {
        doc.remove(key);
      } else {
        doc[key] = entry.value;
      }
    }
    store[docId] = doc;
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final d = store[docId];
    return _MockGetDocumentSnapshot(docId, d);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _MockGetDocumentSnapshot
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  _MockGetDocumentSnapshot(this.id, this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _MockCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final Map<String, Map<String, dynamic>> store;
  final List<Object?>? whereInValues;
  _MockCollectionReference(this.store, [this.whereInValues]);

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return _MockCollectionReference(store, whereIn?.toList());
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final entry in store.entries) {
      if (whereInValues == null ||
          whereInValues!.contains(entry.value['cpf'])) {
        docs.add(_MockDocumentSnapshot(entry.key, entry.value));
      }
    }
    return _MockQuerySnapshot(docs);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _MockDocumentReference(path ?? 'doc_default', store);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> usuariosStore = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _MockCollectionReference(usuariosStore);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lazy Migration e Homologação de Viagens', () {
    test('1. Lazy Migration migra credencial do Firestore para o Firebase Auth e expira senhas em texto puro', () async {
      final mockFirestore = _MockFirestore();
      mockFirestore.usuariosStore['mot_carlos'] = {
        'nome': 'Carlos Roberto Pereira',
        'cpf': '123.456.789-01',
        'role': 'motorista',
        'ativo': true,
        'senha': 'senhaSegura123',
        'password': 'senhaSegura123',
      };

      final mockAuth = _MockFirebaseAuth();
      final authService = FirebaseAuthService(
        auth: mockAuth,
        firestore: mockFirestore,
      );

      // Primeiro login: Não existe no Auth, valida contra Firestore, chama createUserWithEmailAndPassword e apaga senha/password
      final role = await authService.login('123.456.789-01', 'senhaSegura123');
      expect(role, equals(UserRole.motorista));
      expect(mockAuth.createUserChamado, isTrue);

      // As chaves senha e password devem ter sido expurgadas do documento no Firestore
      final docAtualizado = mockFirestore.usuariosStore['mot_carlos']!;
      expect(docAtualizado.containsKey('senha'), isFalse);
      expect(docAtualizado.containsKey('password'), isFalse);
      expect(docAtualizado['authUid'], isNotNull);

      // Segundo login: Agora autentica diretamente nativo via Firebase Authentication sem precisar do Firestore
      mockAuth.createUserChamado = false;
      final role2 = await authService.login('12345678901', 'senhaSegura123');
      expect(role2, equals(UserRole.motorista));
      expect(mockAuth.createUserChamado, isFalse);
    });

    testWidgets('2. Validação direta de odômetro: kmRetorno < kmInicial impede conclusão e exibe erro', (tester) async {
      final viagem = ViagemModel(
        id: 'viagem_odometro_teste',
        motoristaId: 'mot_teste',
        motoristaNome: 'Motorista Odômetro',
        veiculoId: 'v1',
        veiculoPlaca: 'BRA-2E19',
        veiculoModelo: 'Spin',
        kmInicial: 1222,
        cidadeDestino: 'São Paulo',
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
      );

      bool confirmado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormularioEncerramento(
              viagem: viagem,
              onConfirmar: (retorno, kmRet, kmRod) {
                confirmado = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Digita kmRetorno menor que kmInicial (caso 1111 vs 1222)
      final camposTexto = find.byType(TextField);
      expect(camposTexto, findsNWidgets(3));

      // Campo 1: Retorno (horário)
      await tester.enterText(camposTexto.at(0), '17:30');
      // Campo 2: Km Retorno
      await tester.enterText(camposTexto.at(1), '1111');
      await tester.pump();

      // Clica em Confirmar
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
      await tester.pumpAndSettle();

      // Não deve ter confirmado e deve exibir a mensagem no SnackBar
      expect(confirmado, isFalse);
      expect(
        find.text('Km de retorno (1111 km) não pode ser menor que o Km inicial (1222 km).'),
        findsOneWidget,
      );

      // Digita kmRetorno válido (1350 >= 1222)
      await tester.enterText(camposTexto.at(1), '1350');
      await tester.pump();

      // Km rodado deve ter sido calculado automaticamente: 1350 - 1222 = 128
      final campoKmRodado = tester.widget<TextField>(camposTexto.at(2));
      expect(campoKmRodado.controller?.text, equals('128'));

      // Agora clica em Confirmar
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(confirmado, isTrue);
    });

    test('3. Encerramento de viagem zera sessão e libera veículo e motorista', () async {
      final viagemService = ViagemService();
      final viagemAtiva = ViagemModel(
        id: 'viagem_libera_motorista',
        motoristaId: 'motorista_carlos',
        motoristaNome: 'Carlos Roberto',
        veiculoId: 'spin_01',
        veiculoPlaca: 'BRA-2E19',
        veiculoModelo: 'Spin',
        kmInicial: 1000,
        cidadeDestino: 'São José do Rio Preto',
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
        passageiros: const [
          PassageiroViagemModel(
            pacienteId: 'p1',
            pacienteNome: 'Paciente 1',
            localDestino: 'Hospital',
            statusEmbarque: 4,
          ),
        ],
      );

      viagemService.resetParaTestes(
        viagensAtivasIniciais: [viagemAtiva],
        veiculosIniciais: [
          VeiculoModel(
            id: 'spin_01',
            placa: 'BRA-2E19',
            modelo: 'Spin',
            quilometragemAtual: 1000,
            emUso: true,
            motoristaAtualId: 'motorista_carlos',
          ),
        ],
      );

      expect(viagemService.viagemAtiva, isNotNull);

      // Encerra a viagem
      await viagemService.encerrarViagem(
        viagemId: 'viagem_libera_motorista',
        kmFinal: 1150,
        kmRodado: 150,
      );

      expect(viagemService.viagemAtiva, isNull);
      expect(viagemService.viagensAtivas, isEmpty);

      final veiculoLiberado = viagemService.todosVeiculos.firstWhere((v) => v.id == 'spin_01');
      expect(veiculoLiberado.emUso, isFalse);
      expect(veiculoLiberado.motoristaAtualId, isNull);
      expect(veiculoLiberado.quilometragemAtual, equals(1150));
    });

    testWidgets('4. Roteamento por emViagem: com emViagem == true não pisca tela de Iniciar Viagem; com emViagem == false exibe início', (tester) async {
      final viagemService = ViagemService();
      viagemService.resetParaTestes();

      // Caso A: emViagem == true (motorista em trânsito)
      FirebaseAuthService.motoristaEmViagemStatic = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Motorista(
            key: const Key('mot_em_viagem'),
            viagemServiceOverride: viagemService,
          ),
        ),
      );

      // Não deve exibir o formulário de "Início da Viagem"
      expect(find.text('Início da Viagem'), findsNothing);
      expect(find.text('Carregando viagem ativa...'), findsOneWidget);

      // Caso B: emViagem == false (motorista sem viagem ativa)
      FirebaseAuthService.motoristaEmViagemStatic = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Motorista(
            key: const Key('mot_sem_viagem'),
            viagemServiceOverride: viagemService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Agora sim deve renderizar o formulário de início de viagem
      expect(find.text('Início da Viagem'), findsOneWidget);
    });

    test('5. Tolerância a falhas: encerramento em lote preserva motorista e veículo liberados', () async {
      final viagemService = ViagemService();
      final v1 = ViagemModel(
        id: 'viagem_tolerancia_1',
        motoristaId: 'mot_tolerancia',
        motoristaNome: 'Motorista Tolerante',
        veiculoId: 'ducato_01',
        veiculoPlaca: 'DEF4G56',
        veiculoModelo: 'Ducato',
        kmInicial: 5000,
        cidadeDestino: 'Barretos',
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
        passageiros: const [
          PassageiroViagemModel(
            pacienteId: 'p_tol',
            pacienteNome: 'Paciente Tolerância',
            localDestino: 'Hospital',
            statusEmbarque: 4,
          ),
        ],
      );

      viagemService.resetParaTestes(
        viagensAtivasIniciais: [v1],
        veiculosIniciais: [
          VeiculoModel(
            id: 'ducato_01',
            placa: 'DEF4G56',
            modelo: 'Ducato',
            quilometragemAtual: 5000,
            emUso: true,
            motoristaAtualId: 'mot_tolerancia',
          ),
        ],
      );

      await viagemService.encerrarTodasViagens(
        kmFinal: 5200,
        kmRodado: 200,
        viagensExplicitas: [v1],
      );

      expect(viagemService.viagemAtiva, isNull);
      expect(viagemService.viagensAtivas, isEmpty);
      expect(FirebaseAuthService.motoristaEmViagemStatic, isFalse);
      final veic = viagemService.todosVeiculos.firstWhere((v) => v.id == 'ducato_01');
      expect(veic.emUso, isFalse);
      expect(veic.motoristaAtualId, isNull);
      expect(veic.quilometragemAtual, equals(5200));
    });

    testWidgets('6. Timeout defensivo (2.5s) desbloqueia tela presa em "Carregando viagem ativa..." e exibe formulário de início', (tester) async {
      final viagemService = ViagemService();
      viagemService.resetParaTestes();
      FirebaseAuthService.motoristaEmViagemStatic = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Motorista(
            key: const Key('mot_timeout_teste'),
            viagemServiceOverride: viagemService,
          ),
        ),
      );

      // Inicialmente exibe o loading "Carregando viagem ativa..."
      expect(find.text('Carregando viagem ativa...'), findsOneWidget);
      expect(find.text('Início da Viagem'), findsNothing);

      // Avança o tempo simulado além dos 2500ms do timeout defensivo
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pumpAndSettle();

      // Após o timeout, o estado foi resetado e exibe o formulário de início
      expect(find.text('Carregando viagem ativa...'), findsNothing);
      expect(find.text('Início da Viagem'), findsOneWidget);
      expect(FirebaseAuthService.motoristaEmViagemStatic, isFalse);
    });

    testWidgets('7. Botão de escape ("Iniciar nova viagem") reseta emViagem e desbloqueia imediatamente', (tester) async {
      final viagemService = ViagemService();
      viagemService.resetParaTestes();
      FirebaseAuthService.motoristaEmViagemStatic = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Motorista(
            key: const Key('mot_escape_teste'),
            viagemServiceOverride: viagemService,
          ),
        ),
      );

      // Localiza o botão de escape e clica
      final botaoCancelar = find.byKey(const Key('botaoCancelarCarregandoViagem'));
      expect(botaoCancelar, findsOneWidget);

      await tester.tap(botaoCancelar);
      await tester.pumpAndSettle();

      // Formulário deve ser renderizado e o estado estático resetado para false
      expect(find.text('Carregando viagem ativa...'), findsNothing);
      expect(find.text('Início da Viagem'), findsOneWidget);
      expect(FirebaseAuthService.motoristaEmViagemStatic, isFalse);
    });

    test('8. Desserialização defensiva de ViagemModel com Timestamp do Firestore e conversão de passageirosIds', () {
      final agora = DateTime.now();
      final timestampInicio = Timestamp.fromDate(agora);
      final timestampFim = Timestamp.fromDate(agora.add(const Duration(hours: 2)));

      final mapFirestore = <String, dynamic>{
        'id': 'viagem_firestore_timestamp',
        'motoristaId': 'mot_123',
        'motoristaNome': 'Carlos Motorista',
        'veiculoId': 'v_123',
        'veiculoPlaca': 'ABC-1234',
        'veiculoModelo': 'Van Master',
        'kmInicial': 50000,
        'cidadeDestino': 'Barretos',
        'status': 'ativa',
        'dataHoraInicio': timestampInicio,
        'dataHoraFim': timestampFim,
        'dataViagem': timestampInicio,
        'ultimaAtualizacaoLocalizacao': timestampInicio,
        'passageiros': [],
        'passageirosIds': ['paciente_1', 'paciente_2'],
      };

      final viagem = ViagemModel.fromMap(mapFirestore);

      expect(viagem.dataHoraInicio.millisecondsSinceEpoch, equals(agora.millisecondsSinceEpoch));
      expect(viagem.dataHoraFim, isNotNull);
      expect(viagem.dataViagem, isNotNull);
      expect(viagem.ultimaAtualizacaoLocalizacao, isNotNull);
      expect(viagem.passageiros.length, equals(2));
      expect(viagem.passageiros[0].pacienteId, equals('paciente_1'));
      expect(viagem.passageiros[0].localDestino, equals('Barretos'));
      expect(viagem.passageiros[1].pacienteId, equals('paciente_2'));
    });

    test('9. Restaurar sessao do motorista com sessaoId divergente recupera viagem ativa existente e seus passageiros', () {
      final viagemService = ViagemService();
      viagemService.resetParaTestes();

      final veiculo = VeiculoModel(
        id: 'veic_master_1',
        placa: 'BRA2E19',
        modelo: 'Renault Master',
        capacidade: 15,
        quilometragemAtual: 42000,
        emUso: true,
        motoristaAtualId: 'mot_joao',
      );

      final viagemAtiva = ViagemModel(
        id: 'viagem_ativa_existente_firestore',
        motoristaId: 'mot_joao',
        motoristaNome: 'João Motorista',
        veiculoId: 'veic_master_1',
        veiculoPlaca: 'BRA2E19',
        veiculoModelo: 'Renault Master',
        kmInicial: 42000,
        cidadeDestino: 'São José do Rio Preto',
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
        sessaoId: 'sessao_remota_anterior_timestamp_12345',
        passageiros: [
          PassageiroViagemModel(
            pacienteId: 'pac_1',
            pacienteNome: 'Maria Santos',
            localOrigem: 'Posto Central',
            localDestino: 'Hospital de Base',
            horarioAtendimento: '08:00',
            statusEmbarque: 0,
          ),
        ],
        passageirosIds: ['pac_1'],
      );

      viagemService.resetParaTestes(
        veiculosIniciais: [veiculo],
        todasViagensIniciais: [viagemAtiva],
      );

      viagemService.restaurarSessaoMotoristaSeAtiva(
        motoristaId: 'mot_joao',
        motoristaNome: 'João Motorista',
        frota: [veiculo],
      );

      expect(viagemService.viagemAtiva, isNotNull);
      expect(viagemService.viagemAtiva!.id, equals('viagem_ativa_existente_firestore'));
      expect(viagemService.viagemAtiva!.passageiros.length, equals(1));
      expect(viagemService.viagemAtiva!.passageiros.first.pacienteNome, equals('Maria Santos'));
      expect(viagemService.viagensAtivas.any((v) => v.id == 'viagem_ativa_existente_firestore'), isTrue);
    });

    testWidgets('10. Viagem ativa com passageiros vazios exibe passageiros da rota via pacientesStreamOverride', (tester) async {
      final viagemService = ViagemService();
      viagemService.resetParaTestes();

      final viagemAtiva = ViagemModel(
        id: 'viagem_sem_passageiros_embutidos',
        motoristaId: 'mot_teste',
        motoristaNome: 'João Motorista',
        veiculoId: 'veic_1',
        veiculoPlaca: 'ABC-1234',
        veiculoModelo: 'Van Master',
        kmInicial: 10000,
        cidadeDestino: 'Barretos',
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
        passageiros: [],
        passageirosIds: [],
      );

      final pacientes = [
        PacienteModel(
          id: 'pac_rota_1',
          nome: 'Paciente Barretos',
          cpf: '111.222.333-44',
          telefone: '(17) 99999-0000',
          enderecoPaciente: 'Rua A, 1',
          localSaida: 'Posto',
          localConsulta: 'Hospital do Amor Barretos',
          horarioConsulta: '09:00',
          status: 0,
        ),
      ];

      viagemService.resetParaTestes(
        viagemAtivaInicial: viagemAtiva,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Motorista(
            key: const Key('mot_fallback_pacientes'),
            viagemInicial: viagemAtiva,
            viagemServiceOverride: viagemService,
            pacientesStreamOverride: Stream.value(pacientes),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PACIENTE BARRETOS'), findsOneWidget);
      expect(find.text('Hospital do Amor Barretos'), findsOneWidget);
      expect(find.text('Início da Viagem'), findsNothing);
    });

    test('11. Desserialização de data com Map _seconds/nanoseconds e status case-insensitive com sinônimos', () {
      final mapComSegundos = <String, dynamic>{
        'id': 'viagem_seconds_map',
        'motoristaId': 'mot_123',
        'motoristaNome': 'Motorista Teste',
        'veiculoId': 'v_1',
        'veiculoPlaca': 'ABC-1234',
        'veiculoModelo': 'Van',
        'kmInicial': 1000,
        'cidadeDestino': 'Barretos',
        'status': 'Em Andamento',
        'dataHoraInicio': {
          '_seconds': 1731140000,
          '_nanoseconds': 0,
        },
      };

      final viagem = ViagemModel.fromMap(mapComSegundos);
      expect(viagem.isAtiva, isTrue);
      expect(viagem.dataHoraInicio.year, equals(2024));

      final mapPlanejada = <String, dynamic>{
        'id': 'viagem_planejada',
        'status': 'Agendada',
      };
      expect(ViagemModel.fromMap(mapPlanejada).isPlanejada, isTrue);

      final mapConcluida = <String, dynamic>{
        'id': 'viagem_concluida',
        'status': 'Finalizada',
      };
      expect(ViagemModel.fromMap(mapConcluida).isConcluida, isTrue);
    });

    test('12. Isolamento de condutores: restaurarSessaoMotoristaSeAtiva não sequestra viagem de outro condutor', () {
      final viagemService = ViagemService();
      viagemService.resetParaTestes();

      final veiculoAndre = VeiculoModel(
        id: 'veic_andre',
        placa: 'AAA1111',
        modelo: 'Spin',
        emUso: true,
        motoristaAtualId: 'mot_andre',
      );

      final viagemAndre = ViagemModel(
        id: 'viagem_do_andre',
        motoristaId: 'mot_andre',
        motoristaNome: 'André Silva',
        veiculoId: 'veic_andre',
        veiculoPlaca: 'AAA1111',
        veiculoModelo: 'Spin',
        kmInicial: 1000,
        cidadeDestino: 'Campinas',
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
        passageiros: [],
        passageirosIds: [],
      );

      viagemService.resetParaTestes(
        veiculosIniciais: [veiculoAndre],
        todasViagensIniciais: [viagemAndre],
      );

      // Carlos abre o aplicativo (sem viagem própria ativa no banco)
      viagemService.restaurarSessaoMotoristaSeAtiva(
        motoristaId: 'mot_carlos',
        motoristaNome: 'Carlos Pereira',
        frota: [veiculoAndre],
      );

      // Não deve vincular Carlos à viagem de André nem criar sessão de veículo falsa
      expect(viagemService.viagemAtiva, isNull);
      expect(viagemService.viagensAtivas, isEmpty);
      expect(viagemService.sessaoAtiva, isNull);
    });

    testWidgets(
      '13. Paciente único com "Fui embora" (status 5) não auto-encerra a viagem e permite swipe 5 -> 1 pelo motorista',
      (tester) async {
        FirebaseAuthService().clearRoleCache();
        final viagemService = ViagemService();
        final syncService = PacienteSyncService();

        final paciente = PacienteModel(
          id: 'pac_unico_5',
          nome: 'Matheus Silva',
          cpf: '111.222.333-44',
          telefone: '(17) 99999-1111',
          enderecoPaciente: 'Rua A, 100',
          localConsulta: 'HB Rio Preto',
          horarioConsulta: '09:00',
          status: 0,
        );
        syncService.resetParaTestes([paciente]);

        final viagem = ViagemModel(
          id: 'viagem_status5_teste',
          motoristaId: 'mot_rodolfo',
          motoristaNome: 'Rodolfo',
          veiculoId: 'veic_1',
          veiculoPlaca: 'BRA-2E19',
          veiculoModelo: 'Spin',
          kmInicial: 1000,
          cidadeDestino: 'Rio Preto',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          passageiros: [
            PassageiroViagemModel(
              pacienteId: 'pac_unico_5',
              pacienteNome: 'Matheus Silva',
              localOrigem: 'Rua A, 100',
              localDestino: 'HB Rio Preto',
              horarioAtendimento: '09:00',
              statusEmbarque: 0,
            ),
          ],
          passageirosIds: ['pac_unico_5'],
        );
        viagemService.resetParaTestes(
          viagensAtivasIniciais: [viagem],
          todasViagensIniciais: [viagem],
        );

        // Simula ação do paciente "Fui embora" -> status 5 com janela de reversão
        final res = await syncService.solicitarCancelamento(
          pacienteId: 'pac_unico_5',
          atorId: 'pac_unico_5',
          atorRole: 'paciente',
          viagemId: 'viagem_status5_teste',
        );
        expect(res.sucesso, isTrue);
        await viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: 'viagem_status5_teste',
          pacienteId: 'pac_unico_5',
          novoStatus: 5,
          prontoRetorno: false,
          janelaReversao: res.paciente?.janelaReversao ??
              JanelaReversaoModel(
                acao: 'cancelamento_carona',
                estadoAnterior: 0,
                iniciadoEm: DateTime.now().toUtc(),
                expiraEm:
                    DateTime.now().toUtc().add(const Duration(seconds: 300)),
              ),
        );

        // Viagem não pode ter sido auto-encerrada
        final viagemAposCancel = viagemService.todasViagens
            .firstWhere((v) => v.id == 'viagem_status5_teste');
        expect(viagemAposCancel.isConcluida, isFalse);
        expect(viagemAposCancel.passageiros.first.statusEmbarque, equals(5));

        // Renderiza a tela do motorista e verifica notificação + swipe 5 -> 1
        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemInicial: viagemAposCancel,
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Aguardando confirmação do passageiro'), findsOneWidget);

        // Desliza o card do paciente em status 5 para embarcar na ida (status 1)
        await tester.drag(find.byType(Dismissible).first, const Offset(-400, 0));
        await tester.pumpAndSettle();

        expect(find.text('PRÓXIMA ETAPA'), findsOneWidget);
        await tester.tap(find.byKey(const Key('botao_confirmar_dialogo_motorista')));
        await tester.pumpAndSettle();

        final viagemAposSwipe = viagemService.todasViagens
            .firstWhere((v) => v.id == 'viagem_status5_teste');
        expect(viagemAposSwipe.passageiros.first.statusEmbarque, equals(1));
      },
    );

    testWidgets(
      '14. Gerar Relatório encerra sessão do veículo mantendo viagem ativa e pendências preservadas quando há paciente não concluído',
      (tester) async {
        FirebaseAuthService().clearRoleCache();
        final viagemService = ViagemService();
        final syncService = PacienteSyncService();
        syncService.resetParaTestes([]);

        const veiculo = VeiculoModel(
          id: 'veic_1',
          placa: 'BRA-2E19',
          modelo: 'Spin LTZ',
          capacidade: 7,
          quilometragemAtual: 50000,
          emUso: false,
        );

        final viagemExibida = ViagemModel(
          id: 'viagem_em_foco',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: '',
          veiculoPlaca: '',
          veiculoModelo: '',
          kmInicial: 50000,
          cidadeDestino: 'Rio Preto',
          dataHoraInicio: DateTime.now(),
          status: 'aberta',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p_pendente',
              pacienteNome: 'Paciente Pendente',
              localOrigem: 'Origem',
              localDestino: 'Destino',
              horarioAtendimento: '08:00',
              statusEmbarque: 2,
            ),
            PassageiroViagemModel(
              pacienteId: 'p_cancelado',
              pacienteNome: 'Paciente Cancelado',
              localOrigem: 'Origem',
              localDestino: 'Destino',
              horarioAtendimento: '09:00',
              statusEmbarque: 5,
            ),
          ],
          passageirosIds: const ['p_pendente', 'p_cancelado'],
        );

        final viagemCompartilhada = ViagemModel(
          id: 'viagem_colega_barretos',
          motoristaId: 'mot_colega',
          motoristaNome: 'Colega',
          veiculoId: 'veic_outro',
          veiculoPlaca: 'XYZ-9999',
          veiculoModelo: 'Van',
          kmInicial: 10000,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime.now(),
          status: 'ativa',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p_barretos',
              pacienteNome: 'Paciente Barretos',
              localOrigem: 'Origem',
              localDestino: 'Hospital Barretos',
              horarioAtendimento: '10:00',
              statusEmbarque: 1,
            ),
          ],
          passageirosIds: const ['p_barretos'],
        );

        viagemService.resetParaTestes(
          veiculosIniciais: const [veiculo],
          todasViagensIniciais: [viagemExibida, viagemCompartilhada],
        );

        await viagemService.iniciarViagem(
          veiculo: veiculo,
          kmInicial: 50000,
          cidadeDestino: 'Rio Preto',
          motoristaId: 'mot_rodolfo',
          motoristaNome: 'Rodolfo',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Motorista(
              viagemInicial: viagemService.viagensAtivas
                  .firstWhere((v) => v.id == 'viagem_em_foco'),
              viagemServiceOverride: viagemService,
              syncServiceOverride: syncService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lista de Passageiros'), findsOneWidget);
        await tester.tap(find.text('Gerar Relatório'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('botaoConfirmarFinalizacao')));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, '00:00'), '14:30');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 85650'), '50120');
        await tester.enterText(find.widgetWithText(TextField, 'Ex: 230'), '120');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        // Viagem em foco permanece ativa e pendente mantém status 2; cancelado mantém 5
        final vFocoFinal = viagemService.todasViagens
            .firstWhere((v) => v.id == 'viagem_em_foco');
        expect(vFocoFinal.status, equals('ativa'));
        expect(vFocoFinal.isConcluida, isFalse);
        expect(
          vFocoFinal.passageiros
              .firstWhere((p) => p.pacienteId == 'p_pendente')
              .statusEmbarque,
          equals(2),
        );
        expect(
          vFocoFinal.passageiros
              .firstWhere((p) => p.pacienteId == 'p_cancelado')
              .statusEmbarque,
          equals(5),
        );

        // A viagem compartilhada de outro motorista permanece intacta e ativa!
        final vColega = viagemService.todasViagens
            .firstWhere((v) => v.id == 'viagem_colega_barretos');
        expect(vColega.status, equals('ativa'));
        expect(vColega.isConcluida, isFalse);

        // Veículo do motorista foi liberado
        final veicFinal =
            viagemService.todosVeiculos.firstWhere((v) => v.id == 'veic_1');
        expect(veicFinal.emUso, isFalse);
      },
    );

    test(
      '15. obterTodasViagensDoDiaParaRelatorio consolida todas as viagens do dia mantendo encerramento isolado',
      () async {
        final viagemService = ViagemService();
        viagemService.limparSessaoLocal();
        final hoje = DateTime(2026, 11, 10, 8, 0);

        final v1Encerrada = ViagemModel(
          id: 'horario_2026_11_10_01',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: 'veic_a',
          veiculoPlaca: 'BRA-2E19',
          veiculoModelo: 'Spin',
          kmInicial: 50000,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          dataHoraInicio: DateTime(2026, 11, 10, 6, 0),
          status: 'encerrada',
          passageirosIds: const ['pac_matheus'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_matheus',
              pacienteNome: 'Matheus',
              localOrigem: 'Origem',
              localDestino: 'HB',
              horarioAtendimento: '08:30',
              statusEmbarque: 4,
            ),
          ],
        );

        final v2Ativa = ViagemModel(
          id: 'horario_2026_11_10_02',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: '',
          veiculoPlaca: 'DEF-4G56',
          veiculoModelo: 'Ducato',
          kmInicial: 72000,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          dataHoraInicio: DateTime(2026, 11, 10, 8, 0),
          status: 'ativa',
          passageirosIds: const ['pac_hank'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_hank',
              pacienteNome: 'Hank',
              localOrigem: 'Origem',
              localDestino: 'AME',
              horarioAtendimento: '22:00',
              statusEmbarque: 0,
            ),
          ],
        );

        final v3Foco = ViagemModel(
          id: 'horario_2026_11_10_03',
          motoristaId: 'mot_bruno',
          motoristaNome: 'Bruno',
          veiculoId: 'veic_b',
          veiculoPlaca: 'AEG-1234',
          veiculoModelo: 'Ka',
          kmInicial: 10000,
          cidadeDestino: 'BARRETOS',
          dataHoraInicio: DateTime(2026, 11, 10, 10, 0),
          status: 'ativa',
          passageirosIds: const ['pac_heitor'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'pac_heitor',
              pacienteNome: 'Heitor',
              localOrigem: 'Origem',
              localDestino: 'Hospital de Amor',
              horarioAtendimento: '15:00',
              statusEmbarque: 1,
            ),
          ],
        );

        viagemService.sincronizarViagensRemotas([
          v1Encerrada,
          v2Ativa,
          v3Foco,
        ]);

        await viagemService.iniciarViagem(
          veiculo: const VeiculoModel(
            id: 'veic_b',
            placa: 'AEG-1234',
            modelo: 'Ka',
            capacidade: 4,
            quilometragemAtual: 10000,
          ),
          kmInicial: 10000,
          cidadeDestino: 'BARRETOS',
          motoristaId: 'mot_bruno',
          motoristaNome: 'Bruno',
        );

        // Encerramento isola estritamente a v3Foco
        final paraEncerrar = viagemService.obterViagensParaRelatorio(
          viagensExplicitas: [v3Foco],
          viagemUnica: v3Foco,
        );
        expect(paraEncerrar.map((v) => v.id).toList(), equals([v3Foco.id]));

        await viagemService.encerrarTodasViagens(
          kmFinal: 10120,
          kmRodado: 120,
          viagensExplicitas: paraEncerrar,
          motoristaId: 'mot_bruno',
          encerrarViagensDefinitivamente: true,
        );

        final v3Pos = viagemService.todasViagens
            .firstWhere((v) => v.id == v3Foco.id);
        final v2Pos = viagemService.todasViagens
            .firstWhere((v) => v.id == v2Ativa.id);
        expect(v3Pos.status, equals('encerrada'));
        expect(v2Pos.status, equals('ativa'));

        // Relatório diário traz TODAS as 3 viagens do dia em ordem cronológica
        final doDia = await viagemService.obterTodasViagensDoDiaParaRelatorio(
          viagemEncerradaAtual: v3Pos,
          dataReferencia: hoje,
        );
        expect(
          doDia.map((v) => v.id).toList(),
          equals([v1Encerrada.id, v2Ativa.id, v3Foco.id]),
        );
      },
    );

    test(
      '16. Encerramento com kmFinal atualiza quilometragemAtual do veículo da sessão mesmo restando outras viagens ativas',
      () async {
        final viagemService = ViagemService();
        viagemService.limparSessaoLocal();

        const veicSpin = VeiculoModel(
          id: 'spin_km_test',
          placa: 'BRA-2E19',
          modelo: 'Spin LTZ',
          capacidade: 7,
          quilometragemAtual: 50000,
          emUso: false,
        );

        final v1Alvo = ViagemModel(
          id: 'viagem_km_1',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: '',
          veiculoPlaca: '',
          veiculoModelo: '',
          kmInicial: 50000,
          cidadeDestino: 'Rio Preto',
          dataHoraInicio: DateTime(2026, 11, 10, 6, 0),
          status: 'ativa',
          passageirosIds: const ['p1'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p1',
              pacienteNome: 'Matheus',
              localOrigem: 'Rua A',
              localDestino: 'HB',
              horarioAtendimento: '08:00',
              statusEmbarque: 2,
            ),
          ],
        );

        final v2Restante = ViagemModel(
          id: 'viagem_km_2',
          motoristaId: '',
          motoristaNome: '',
          veiculoId: '',
          veiculoPlaca: '',
          veiculoModelo: '',
          kmInicial: 50000,
          cidadeDestino: 'Barretos',
          dataHoraInicio: DateTime(2026, 11, 10, 8, 0),
          status: 'ativa',
          passageirosIds: const ['p2'],
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p2',
              pacienteNome: 'Audrey',
              localOrigem: 'Rua B',
              localDestino: 'AME',
              horarioAtendimento: '10:00',
              statusEmbarque: 0,
            ),
          ],
        );

        viagemService.resetParaTestes(
          veiculosIniciais: [veicSpin],
          todasViagensIniciais: [v1Alvo, v2Restante],
        );

        await viagemService.iniciarViagem(
          veiculo: veicSpin,
          kmInicial: 50000,
          cidadeDestino: 'Rio Preto',
          motoristaId: 'mot_alberto',
          motoristaNome: 'Alberto',
        );

        await viagemService.encerrarTodasViagens(
          kmFinal: 53000,
          kmRodado: 3000,
          viagensExplicitas: [v1Alvo],
          motoristaId: 'mot_alberto',
          encerrarViagensDefinitivamente: true,
        );

        // Mesmo com v2Restante mantendo a sessão ativa, a quilometragem do veículo foi atualizada para 53000!
        final veicPos = viagemService.todosVeiculos
            .firstWhere((v) => v.id == 'spin_km_test');
        expect(veicPos.quilometragemAtual, equals(53000));
        expect(veicPos.emUso, isTrue);
        expect(
          viagemService.todasViagens
              .firstWhere((v) => v.id == 'viagem_km_2')
              .status,
          equals('ativa'),
        );
      },
    );
  });
}
