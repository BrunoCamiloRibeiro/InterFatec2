import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/veiculo_model.dart';

/// Controller baseado no padrão ChangeNotifier para gerenciar o ciclo de vida dos Veículos
/// com sincronização em tempo real no Cloud Firestore (Coleção 'veiculos').
class VeiculoController extends ChangeNotifier {
  // Singleton para fácil acesso e compartilhamento de estado na aplicação
  static final VeiculoController _instance = VeiculoController._internal();
  factory VeiculoController() => _instance;
  VeiculoController._internal();

  final List<VeiculoModel> _veiculos = [];
  bool _carregando = false;
  String? _erro;
  String _filtroTexto = '';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subFirestore;

  bool get _isFirebaseDisponivel {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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

  /// Carrega os dados reais do Firestore ou fallback em JSON/Memória
  Future<void> carregarVeiculos() async {
    if (_veiculos.isNotEmpty && _subFirestore != null) return;

    _carregando = true;
    _erro = null;
    notifyListeners();

    if (_isFirebaseDisponivel) {
      try {
        await _subFirestore?.cancel();
        _subFirestore = FirebaseFirestore.instance
            .collection('veiculos')
            .snapshots()
            .listen((snapshot) async {
          if (snapshot.docs.isNotEmpty) {
            _veiculos.clear();
            for (final doc in snapshot.docs) {
              _veiculos.add(VeiculoModel.fromMap(doc.data(), docId: doc.id));
            }
            _carregando = false;
            notifyListeners();
          } else {
            // Se a coleção estiver vazia no Firestore, faz seed dos dados de exemplo
            await _popularFirestoreComDadosIniciais();
          }
        }, onError: (e) {
          _erro = 'Erro na sincronização com o banco: $e';
          _carregando = false;
          notifyListeners();
        });
        return;
      } catch (e) {
        debugPrint('Erro ao iniciar listener do Firestore: $e');
      }
    }

    // Fallback para execução sem Firebase ou testes locais
    await _carregarDoJsonFallback();
  }

  Future<void> _popularFirestoreComDadosIniciais() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/dados_veiculos.json',
      );
      final List<dynamic> jsonDecodificado =
          jsonDecode(jsonString) as List<dynamic>;

      final batch = FirebaseFirestore.instance.batch();
      _veiculos.clear();
      for (final item in jsonDecodificado) {
        final v = VeiculoModel.fromMap(Map<String, dynamic>.from(item as Map));
        final docRef = FirebaseFirestore.instance.collection('veiculos').doc(v.id);
        batch.set(docRef, v.toMap());
        _veiculos.add(v);
      }
      await batch.commit();
    } catch (_) {
      await _carregarDoJsonFallback();
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> _carregarDoJsonFallback() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/dados_veiculos.json',
      );
      final List<dynamic> jsonDecodificado =
          jsonDecode(jsonString) as List<dynamic>;

      _veiculos.clear();
      for (final item in jsonDecodificado) {
        _veiculos.add(
            VeiculoModel.fromMap(Map<String, dynamic>.from(item as Map)));
      }
    } catch (e) {
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

  /// Adiciona um novo veículo na lista (CREATE) e persiste no Firestore
  Future<void> adicionarVeiculo(VeiculoModel novoVeiculo) async {
    _veiculos.insert(0, novoVeiculo);
    notifyListeners();

    if (_isFirebaseDisponivel) {
      try {
        final col = FirebaseFirestore.instance.collection('veiculos');
        final docRef = (novoVeiculo.id.isNotEmpty && !novoVeiculo.id.startsWith('veiculo_'))
            ? col.doc(novoVeiculo.id)
            : col.doc();
        final veiculoFinal = novoVeiculo.id != docRef.id
            ? novoVeiculo.copyWith(id: docRef.id)
            : novoVeiculo;
        await docRef.set(veiculoFinal.toMap());
      } catch (e) {
        debugPrint('Erro ao persistir novo veículo no Firestore: $e');
      }
    }
  }

  /// Atualiza os dados de um veículo existente (UPDATE) e persiste no Firestore
  Future<void> atualizarVeiculo(VeiculoModel veiculoAtualizado) async {
    final index = _veiculos.indexWhere((v) => v.id == veiculoAtualizado.id);
    if (index != -1) {
      _veiculos[index] = veiculoAtualizado;
      notifyListeners();
    }

    if (_isFirebaseDisponivel) {
      try {
        await FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculoAtualizado.id)
            .set(veiculoAtualizado.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Erro ao atualizar veículo no Firestore: $e');
      }
    }
  }

  /// Altera rapidamente o status do veículo (UPDATE status via Dropdown) e persiste no Firestore
  Future<void> alterarStatus(String id, StatusVeiculo novoStatus) async {
    final agora = DateTime.now().toIso8601String();
    final index = _veiculos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _veiculos[index] = _veiculos[index].copyWith(
        status: novoStatus,
        atualizadoEm: agora,
      );
      notifyListeners();
    }

    if (_isFirebaseDisponivel) {
      try {
        await FirebaseFirestore.instance.collection('veiculos').doc(id).update({
          'status': novoStatus.valor,
          'emUso': novoStatus == StatusVeiculo.emViagem,
          'atualizadoEm': agora,
        });
      } catch (e) {
        debugPrint('Erro ao atualizar status no Firestore: $e');
      }
    }
  }

  /// Remove um veículo da lista (DELETE) e do Firestore
  Future<void> removerVeiculo(String id) async {
    _veiculos.removeWhere((v) => v.id == id);
    notifyListeners();

    if (_isFirebaseDisponivel) {
      try {
        await FirebaseFirestore.instance.collection('veiculos').doc(id).delete();
      } catch (e) {
        debugPrint('Erro ao deletar veículo no Firestore: $e');
      }
    }
  }

  @visibleForTesting
  void resetParaTestes() {
    _subFirestore?.cancel();
    _subFirestore = null;
    _veiculos.clear();
    _filtroTexto = '';
    _carregando = false;
    _erro = null;
  }
}
