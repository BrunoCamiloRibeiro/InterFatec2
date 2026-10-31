import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import 'validacao_viagem.dart';

// Armazena o resultado da tentativa de iniciar uma viagem
class ResultadoInicioViagem {
  // Indica se a inicialização da viagem ocorreu com sucesso
  final bool sucesso;
  // Instância da viagem criada em caso de sucesso
  final ViagemModel? viagem;
  // Mensagem descritiva do erro em caso de falha
  final String? mensagemErro;

  const ResultadoInicioViagem._({
    required this.sucesso,
    this.viagem,
    this.mensagemErro,
  });

  // Retorna uma instância de ResultadoInicioViagem com sucesso e os dados da viagem
  factory ResultadoInicioViagem.sucesso(ViagemModel viagem) =>
      ResultadoInicioViagem._(sucesso: true, viagem: viagem);

  // Retorna uma instância de ResultadoInicioViagem com erro e a mensagem correspondente
  factory ResultadoInicioViagem.erro(String mensagem) =>
      ResultadoInicioViagem._(sucesso: false, mensagemErro: mensagem);
}

// Gerencia a lista de veículos, streams de atualização e o ciclo de vida das viagens
class ViagemService {
  // Instância única da classe ViagemService
  static final ViagemService _instance = ViagemService._interno();

  // Construtor fábrica que retorna a instância única
  factory ViagemService() => _instance;

  // Construtor privado que executa a inicialização dos dados base
  ViagemService._interno() {
    _inicializarDadosBase();
  }

  // Armazena a viagem ativa no momento
  ViagemModel? _viagemAtiva;

  // Controlador de fluxo de dados para a lista de veículos
  final StreamController<List<VeiculoModel>> _veiculosController =
      StreamController<List<VeiculoModel>>.broadcast();

  // Controlador de fluxo de dados para a viagem ativa
  final StreamController<ViagemModel?> _viagemAtivaController =
      StreamController<ViagemModel?>.broadcast();

  // Lista de veículos armazenada em memória
  final List<VeiculoModel> _veiculosMemoria = [];

  // Indicador de inicialização dos dados da lista em memória
  bool _inicializado = false;

  // Retorna a viagem ativa atual
  ViagemModel? get viagemAtiva => _viagemAtiva;

  // Retorna o fluxo de dados da viagem ativa
  Stream<ViagemModel?> get viagemAtivaStream => _viagemAtivaController.stream;

  // Retorna o fluxo de dados da lista de veículos
  Stream<List<VeiculoModel>> get veiculosStream => _veiculosController.stream;

  // Insere registros padrão de veículos na lista em memória
  void _inicializarDadosBase() {
    if (_inicializado) return;
    _veiculosMemoria.addAll([
      const VeiculoModel(
        id: 'v1',
        placa: 'ABC-1D23',
        modelo: 'Chevrolet Spin 1.8 LTZ',
        capacidade: 7,
        quilometragemAtual: 85420,
        emUso: false,
      ),
      const VeiculoModel(
        id: 'v2',
        placa: 'BRA-2E45',
        modelo: 'Renault Master Minibus',
        capacidade: 16,
        quilometragemAtual: 142100,
        emUso: false,
      ),
      const VeiculoModel(
        id: 'v3',
        placa: 'POL-3F67',
        modelo: 'Fiat Ducato Ambulância',
        capacidade: 4,
        quilometragemAtual: 63250,
        emUso: false,
      ),
      const VeiculoModel(
        id: 'v4',
        placa: 'XYZ-9K88',
        modelo: 'Fiat Cronos Drive 1.3',
        capacidade: 5,
        quilometragemAtual: 41900,
        emUso: true,
        motoristaAtualId: 'mot_antonio',
      ),
    ]);
    _inicializado = true;
  }

  // Verifica se existem instâncias ativas do Firebase inicializadas
  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Retorna um fluxo com a lista de veículos disponíveis filtrados
  Stream<List<VeiculoModel>> carregarVeiculosDisponiveis({
    String? motoristaId,
  }) {
    if (_isFirebaseDisponivel()) {
      try {
        return FirebaseFirestore.instance
            .collection('veiculos')
            .snapshots()
            .map((snapshot) {
              if (snapshot.docs.isEmpty) {
                // Escreve os veículos padrão no Firestore quando a coleção está sem documentos
                _sincronizarVeiculosBaseNoFirestore();
                return ValidacaoViagem.filtrarVeiculosDisponiveis(
                  _veiculosMemoria,
                  motoristaPermitidoId: motoristaId,
                );
              }
              // Mapeia os documentos retornados para instâncias de VeiculoModel
              final lista = snapshot.docs.map((doc) {
                return VeiculoModel.fromMap(doc.data(), docId: doc.id);
              }).toList();
              return ValidacaoViagem.filtrarVeiculosDisponiveis(
                lista,
                motoristaPermitidoId: motoristaId,
              );
            });
      } catch (_) {
        // Prossegue para o fluxo em memória caso ocorra exceção
      }
    }

    // Emite a lista de veículos armazenada em memória através do StreamController
    Future.microtask(() {
      if (!_veiculosController.isClosed) {
        _veiculosController.add(
          ValidacaoViagem.filtrarVeiculosDisponiveis(
            _veiculosMemoria,
            motoristaPermitidoId: motoristaId,
          ),
        );
      }
    });

    return _veiculosController.stream;
  }

  // Envia os veículos da lista em memória para a coleção 'veiculos' do Firestore
  Future<void> _sincronizarVeiculosBaseNoFirestore() async {
    if (!_isFirebaseDisponivel()) return;
    try {
      final col = FirebaseFirestore.instance.collection('veiculos');
      for (final v in _veiculosMemoria) {
        await col.doc(v.id).set(v.toMap(), SetOptions(merge: true));
      }
    } catch (_) {
      // Ignora falhas de escrita durante a sincronização
    }
  }

  // Valida os dados, atualiza a disponibilidade do veículo e cria o registro de viagem
  Future<ResultadoInicioViagem> iniciarViagem({
    required VeiculoModel veiculo,
    required int kmInicial,
    required String cidadeDestino,
    required String motoristaId,
    required String motoristaNome,
  }) async {
    // Valida a quilometragem informada contra a última registrada
    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: kmInicial.toString(),
      ultimaKmRegistrada: veiculo.quilometragemAtual,
    );
    if (!validacaoKm.valido) {
      return ResultadoInicioViagem.erro(validacaoKm.mensagemErro!);
    }

    // Valida a cidade informada
    final validacaoCidade = ValidacaoViagem.validarCidade(cidadeDestino);
    if (!validacaoCidade.valido) {
      return ResultadoInicioViagem.erro(validacaoCidade.mensagemErro!);
    }

    // Consulta o documento do veículo no Firestore para verificar uso concorrente
    if (_isFirebaseDisponivel()) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculo.id);
        final docSnap = await docRef.get();

        if (docSnap.exists) {
          final dados = docSnap.data() ?? {};
          final emUsoRemoto = dados['emUso'] == true;
          final motoristaOcupando = dados['motoristaAtualId'];
          // Verifica se o veículo está marcado em uso por motorista distinto
          if (emUsoRemoto &&
              motoristaOcupando != null &&
              motoristaOcupando != motoristaId) {
            return ResultadoInicioViagem.erro(
              'O veículo ${veiculo.placa} foi colocado em uso por outro motorista. Escolha outro veículo.',
            );
          }
        }
      } catch (_) {
        // Prossegue com a verificação em memória caso ocorra falha de consulta remota
      }
    }

    // Verifica a situação do veículo na lista em memória
    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculo.id);
    if (index != -1) {
      final veicMem = _veiculosMemoria[index];
      // Verifica se o veículo da memória está em uso por outro motorista
      if (veicMem.emUso &&
          veicMem.motoristaAtualId != null &&
          veicMem.motoristaAtualId != motoristaId) {
        return ResultadoInicioViagem.erro(
          'O veículo ${veiculo.placa} já está em uso por outro motorista.',
        );
      }
      // Atualiza o veículo na memória com status emUso, novo condutor e quilometragem
      _veiculosMemoria[index] = _veiculosMemoria[index].copyWith(
        emUso: true,
        motoristaAtualId: motoristaId,
        quilometragemAtual: kmInicial,
      );
    }

    // Instancia o objeto ViagemModel com os dados da viagem
    final novaViagem = ViagemModel(
      id: 'viagem_${DateTime.now().millisecondsSinceEpoch}',
      motoristaId: motoristaId,
      motoristaNome: motoristaNome,
      veiculoId: veiculo.id,
      veiculoPlaca: veiculo.placa,
      veiculoModelo: veiculo.modelo,
      kmInicial: kmInicial,
      cidadeDestino: cidadeDestino,
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
    );

    // Atualiza a variável e notifica os fluxos de dados
    _viagemAtiva = novaViagem;
    _viagemAtivaController.add(_viagemAtiva);
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );

    // Persiste as alterações no Firestore
    if (_isFirebaseDisponivel()) {
      try {
        // Atualiza os dados de uso e quilometragem do veículo
        await FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculo.id)
            .set({
              'emUso': true,
              'motoristaAtualId': motoristaId,
              'quilometragemAtual': kmInicial,
            }, SetOptions(merge: true));

        // Cria o documento da viagem na coleção 'viagens'
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(novaViagem.id)
            .set(novaViagem.toMap());

        // Atualiza a propriedade emViagem do usuário motorista
        if (motoristaId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(motoristaId)
              .set({'emViagem': true}, SetOptions(merge: true));
        }
      } catch (_) {
        // Ignora erros de escrita remota
      }
    }

    return ResultadoInicioViagem.sucesso(novaViagem);
  }

  // Altera o status da viagem para encerrada e libera o veículo associado
  Future<void> encerrarViagem({int? kmFinal, int? kmRodado}) async {
    if (_viagemAtiva == null) return;

    final viagem = _viagemAtiva!;
    final veiculoId = viagem.veiculoId;

    // Atualiza os dados do veículo na lista em memória
    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculoId);
    if (index != -1) {
      _veiculosMemoria[index] = _veiculosMemoria[index].copyWith(
        emUso: false,
        motoristaAtualId: null,
        quilometragemAtual:
            kmFinal ?? _veiculosMemoria[index].quilometragemAtual,
      );
    }

    // Limpa a viagem ativa e atualiza os fluxos de dados
    _viagemAtiva = null;
    _viagemAtivaController.add(null);
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );

    // Atualiza os documentos no Firestore
    if (_isFirebaseDisponivel()) {
      try {
        final dadosVeiculo = <String, dynamic>{
          'emUso': false,
          'motoristaAtualId': null,
        };
        if (kmFinal != null) {
          dadosVeiculo['quilometragemAtual'] = kmFinal;
        }
        await FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculoId)
            .set(dadosVeiculo, SetOptions(merge: true));

        final dadosViagem = <String, dynamic>{
          'status': 'encerrada',
          'dataHoraFim': DateTime.now().toIso8601String(),
        };
        if (kmFinal != null) {
          dadosViagem['kmFinal'] = kmFinal;
        }
        if (kmRodado != null) {
          dadosViagem['kmRodado'] = kmRodado;
        }
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagem.id)
            .set(dadosViagem, SetOptions(merge: true));

        if (viagem.motoristaId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(viagem.motoristaId)
              .set({'emViagem': false}, SetOptions(merge: true));
        }
      } catch (_) {
        // Ignora erros de escrita remota
      }
    }
  }

  // Restaura o estado interno de memória e notifica os fluxos com os valores fornecidos
  void resetParaTestes({
    List<VeiculoModel>? veiculosIniciais,
    ViagemModel? viagemAtivaInicial,
  }) {
    _viagemAtiva = viagemAtivaInicial;
    _viagemAtivaController.add(_viagemAtiva);
    _veiculosMemoria.clear();
    if (veiculosIniciais != null) {
      _veiculosMemoria.addAll(veiculosIniciais);
    } else {
      _inicializado = false;
      _inicializarDadosBase();
    }
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );
  }
}
