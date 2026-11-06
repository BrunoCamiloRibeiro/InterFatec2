import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/veiculo_model.dart';

/// Controller baseado no padrão ChangeNotifier para gerenciar o ciclo de vida do CRUD de Veículos.
/// Permite reconstruções reativas granulares sem recriar telas inteiras.
class VeiculoController extends ChangeNotifier {
  // Singleton para fácil acesso e compartilhamento de estado na aplicação
  static final VeiculoController _instance = VeiculoController._internal();
  factory VeiculoController() => _instance;
  VeiculoController._internal();

  final List<VeiculoModel> _veiculos = [];
  bool _carregando = false;
  String? _erro;
  String _filtroTexto = '';

  // Getters públicos
  bool get carregando => _carregando;
  String? get erro => _erro;
  String get filtroTexto => _filtroTexto;
  List<VeiculoModel> get todosVeiculos => List.unmodifiable(_veiculos);

  // Lista filtrada por busca de texto (placa, modelo, marca)
  List<VeiculoModel> get veiculosFiltrados {
    if (_filtroTexto.isEmpty) return _veiculos;
    final query = _filtroTexto.toLowerCase().trim();
    return _veiculos.where((v) {
      return v.placa.toLowerCase().contains(query) ||
          v.modelo.toLowerCase().contains(query) ||
          v.marca.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  // Veículos ativos (Disponíveis ou Em Viagem)
  List<VeiculoModel> get veiculosAtivos {
    return veiculosFiltrados.where((v) {
      return v.status == StatusVeiculo.disponivel ||
          v.status == StatusVeiculo.emViagem;
    }).toList(growable: false);
  }

  // Veículos pendentes / em manutenção ou inativos
  List<VeiculoModel> get veiculosPendentes {
    return veiculosFiltrados.where((v) {
      return v.status == StatusVeiculo.emManutencao ||
          v.status == StatusVeiculo.inativo;
    }).toList(growable: false);
  }

  // Total de veículos disponíveis para o Footer
  int get totalDisponiveis {
    return _veiculos.where((v) => v.status == StatusVeiculo.disponivel).length;
  }

  int get totalVeiculos => _veiculos.length;

  /// Carrega os dados reais do arquivo JSON (ou fallback com mock)
  Future<void> carregarVeiculos() async {
    if (_veiculos.isNotEmpty) return; // Evita recarregamento repetido desnecessário

    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/dados_veiculos.json',
      );
      final List<dynamic> jsonDecodificado = jsonDecode(jsonString) as List<dynamic>;

      _veiculos.clear();
      for (final item in jsonDecodificado) {
        _veiculos.add(VeiculoModel.fromMap(Map<String, dynamic>.from(item as Map)));
      }
    } catch (e) {
      // Fallback robusto se o arquivo não estiver disponível no bundle
      _veiculos.clear();
      _veiculos.addAll([
        const VeiculoModel(
          id: 'veiculo001',
          placa: 'ABC1D23',
          tipo: TipoVeiculo.van,
          marca: 'Renault',
          modelo: 'Master',
          ano: 2023,
          qtdAssentos: 15,
          status: StatusVeiculo.disponivel,
          quilometragemAtual: 45280,
          possuiAC: true,
          possuiPreferencial: false,
          observacoes: 'Veículo utilizado para viagens intermunicipais.',
          criadoEm: '2026-10-01T08:00:00',
          atualizadoEm: '2026-10-01T08:00:00',
        ),
        const VeiculoModel(
          id: 'veiculo002',
          placa: 'DEF4G56',
          tipo: TipoVeiculo.ambulancia,
          marca: 'Fiat',
          modelo: 'Ducato',
          ano: 2022,
          qtdAssentos: 4,
          status: StatusVeiculo.emManutencao,
          quilometragemAtual: 62150,
          ultimoMotoristaId: 'motorista001',
          possuiAC: true,
          possuiPreferencial: true,
          observacoes: 'Revisão preventiva pendente.',
          criadoEm: '2026-09-15T10:30:00',
          atualizadoEm: '2026-10-20T14:00:00',
          atualizadoPor: 'usuario001',
        ),
      ]);
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Filtra a lista em memória
  void filtrar(String texto) {
    if (_filtroTexto == texto) return;
    _filtroTexto = texto;
    notifyListeners();
  }

  /// Adiciona um novo veículo na lista (CREATE)
  void adicionarVeiculo(VeiculoModel novoVeiculo) {
    _veiculos.insert(0, novoVeiculo);
    notifyListeners();
  }

  /// Atualiza os dados de um veículo existente (UPDATE)
  void atualizarVeiculo(VeiculoModel veiculoAtualizado) {
    final index = _veiculos.indexWhere((v) => v.id == veiculoAtualizado.id);
    if (index != -1) {
      _veiculos[index] = veiculoAtualizado;
      notifyListeners();
    }
  }

  /// Altera rapidamente o status do veículo (UPDATE status via Dropdown)
  void alterarStatus(String id, StatusVeiculo novoStatus) {
    final index = _veiculos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _veiculos[index] = _veiculos[index].copyWith(
        status: novoStatus,
        atualizadoEm: DateTime.now().toIso8601String(),
      );
      notifyListeners();
    }
  }

  /// Remove um veículo da lista (DELETE)
  void removerVeiculo(String id) {
    _veiculos.removeWhere((v) => v.id == id);
    notifyListeners();
  }
}
