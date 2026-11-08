import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/controllers/veiculo_controller.dart';
import 'package:trans_saude/models/veiculo_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VeiculoModel - Compatibilidade e Serialização', () {
    test('Serialização e desserialização preservam campos do CRUD e de Viagem', () {
      final veiculo = const VeiculoModel(
        id: 'v_teste_1',
        placa: 'BRA2E19',
        tipo: TipoVeiculo.van,
        marca: 'Chevrolet',
        modelo: 'Spin',
        ano: 2024,
        qtdAssentos: 7,
        status: StatusVeiculo.disponivel,
        quilometragemAtual: 35000,
        motoristaResponsavelId: 'mot_1',
        ultimoMotoristaId: 'mot_1',
        possuiAC: true,
        possuiPreferencial: true,
        observacoes: 'Uso sanitário regular',
      );

      // Valida aliases de compatibilidade
      expect(veiculo.capacidade, equals(7));
      expect(veiculo.emUso, isFalse);
      expect(veiculo.motoristaAtualId, equals('mot_1'));
      expect(veiculo.ultimaKmRegistrada, equals(35000));

      final map = veiculo.toMap();
      expect(map['placa'], equals('BRA2E19'));
      expect(map['capacidade'], equals(7));
      expect(map['qtdAssentos'], equals(7));
      expect(map['status'], equals('disponivel'));
      expect(map['emUso'], isFalse);

      final veiculoRecriado = VeiculoModel.fromMap(map, docId: 'v_teste_1');
      expect(veiculoRecriado.id, equals('v_teste_1'));
      expect(veiculoRecriado.placa, equals('BRA2E19'));
      expect(veiculoRecriado.capacidade, equals(7));
      expect(veiculoRecriado.status, equals(StatusVeiculo.disponivel));
      expect(veiculoRecriado.emUso, isFalse);
    });

    test('Status emViagem reflete emUso: true', () {
      final vViagem = const VeiculoModel(
        id: 'v_viagem',
        placa: 'XYZ9999',
        status: StatusVeiculo.emViagem,
      );
      expect(vViagem.emUso, isTrue);

      final map = vViagem.toMap();
      expect(map['emUso'], isTrue);

      // Reconversão a partir de payload legado onde só havia 'emUso: true'
      final legado = VeiculoModel.fromMap({
        'id': 'v_legado',
        'placa': 'LEG1111',
        'emUso': true,
        'capacidade': 15,
      });
      expect(legado.status, equals(StatusVeiculo.emViagem));
      expect(legado.emUso, isTrue);
      expect(legado.qtdAssentos, equals(15));
    });
  });

  group('VeiculoController - Operações de CRUD e Filtro', () {
    late VeiculoController controller;

    setUp(() {
      controller = VeiculoController();
      controller.resetParaTestes(
        veiculosIniciais: const [
          VeiculoModel(
            id: 'veiculo001',
            placa: 'ABC1D23',
            tipo: TipoVeiculo.van,
            marca: 'Renault',
            modelo: 'Master',
            ano: 2023,
            qtdAssentos: 15,
            status: StatusVeiculo.disponivel,
            quilometragemAtual: 45280,
          ),
          VeiculoModel(
            id: 'veiculo002',
            placa: 'DEF4G56',
            tipo: TipoVeiculo.ambulancia,
            marca: 'Fiat',
            modelo: 'Ducato',
            ano: 2022,
            qtdAssentos: 4,
            status: StatusVeiculo.emManutencao,
            quilometragemAtual: 62150,
          ),
        ],
      );
    });

    tearDown(() {
      controller.resetParaTestes();
    });

    test('Carrega dados e popula lista com sucesso', () async {
      await controller.carregarVeiculos();
      expect(controller.totalVeiculos, greaterThan(0));
      expect(controller.carregando, isFalse);
    });

    test('Filtra veículos por placa, modelo ou marca', () async {
      await controller.carregarVeiculos();

      controller.filtrar('ABC');
      expect(
        controller.veiculosFiltrados.every(
          (v) =>
              v.placa.toLowerCase().contains('abc') ||
              v.modelo.toLowerCase().contains('abc') ||
              v.marca.toLowerCase().contains('abc'),
        ),
        isTrue,
      );

      controller.filtrar('');
      expect(controller.veiculosFiltrados.length, equals(controller.totalVeiculos));
    });

    test('Adiciona novo veículo e reflete nos totais', () async {
      await controller.carregarVeiculos();
      final totalAntes = controller.totalVeiculos;

      final novo = const VeiculoModel(
        id: 'v_novo_unit',
        placa: 'NEW-2026',
        marca: 'Ford',
        modelo: 'Transit',
        status: StatusVeiculo.disponivel,
      );

      controller.adicionarVeiculo(novo);
      expect(controller.totalVeiculos, equals(totalAntes + 1));
      expect(controller.todosVeiculos.first.placa, equals('NEW-2026'));
    });

    test('Atualiza veículo existente', () async {
      await controller.carregarVeiculos();
      final original = controller.todosVeiculos.first;

      final atualizado = original.copyWith(
        modelo: 'Modelo Atualizado',
        quilometragemAtual: 99999,
      );

      controller.atualizarVeiculo(atualizado);
      final encontrado = controller.todosVeiculos.firstWhere((v) => v.id == original.id);
      expect(encontrado.modelo, equals('Modelo Atualizado'));
      expect(encontrado.quilometragemAtual, equals(99999));
    });

    test('Altera status do veículo rapidamente', () async {
      await controller.carregarVeiculos();
      final original = controller.todosVeiculos.first;

      controller.alterarStatus(original.id, StatusVeiculo.emManutencao);
      final encontrado = controller.todosVeiculos.firstWhere((v) => v.id == original.id);
      expect(encontrado.status, equals(StatusVeiculo.emManutencao));
    });

    test('Remove veículo pelo identificador', () async {
      await controller.carregarVeiculos();
      final original = controller.todosVeiculos.first;
      final totalAntes = controller.totalVeiculos;

      controller.removerVeiculo(original.id);
      expect(controller.totalVeiculos, equals(totalAntes - 1));
      expect(controller.todosVeiculos.any((v) => v.id == original.id), isFalse);
    });
  });
}
