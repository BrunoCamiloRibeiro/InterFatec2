// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/localizacao_motorista_service.dart
// Camada: Serviços de Domínio / Infraestrutura (Services)
//
// O QUE ESTE ARQUIVO FAZ:
// Centraliza a gestão, rastreamento e distribuição reativa da localização
// geográfica de todos os motoristas com viagens ativas na rede municipal de
// transporte sanitário (TFD).
// 1) Escuta em tempo real as viagens ativas no Cloud Firestore e no ViagemService;
// 2) Captura opcionalmente a posição GPS do dispositivo do condutor via Geolocator
//    de forma segura e resiliente (sem quebras de plataforma na Web ou testes);
// 3) Distribui a lista de motoristas ativos via Stream reativa para todos os
//    pacientes visualizarem simultaneamente no mapa;
// 4) Respeita estritamente a premissa de negócio: exibir posições dos motoristas
//    em trânsito SEM estimar tempo de chegada (ETA) e SEM calcular rotas.
//
// ONDE É USADO NO PROJETO:
// - lib/components/card_tracking_paciente.dart
// - lib/motorista.dart
// - lib/paciente.dart
// - test/components/card_tracking_paciente_test.dart
//
// ORIGEM HISTÓRICA:
// Criado para atender o requisito da Issue #65 / Painel do Paciente.
// ============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/localizacao_motorista_model.dart';
import '../models/viagem_model.dart';
import 'viagem_service.dart';

/// Serviço singleton para controle e streaming de geolocalização dos motoristas.
class LocalizacaoMotoristaService {
  static final LocalizacaoMotoristaService _instance =
      LocalizacaoMotoristaService._internal();

  factory LocalizacaoMotoristaService() => _instance;

  LocalizacaoMotoristaService._internal() {
    _inicializarOuvintes();
  }

  final StreamController<List<LocalizacaoMotoristaModel>>
      _motoristasAtivosController =
      StreamController<List<LocalizacaoMotoristaModel>>.broadcast();

  final Map<String, LocalizacaoMotoristaModel> _motoristasAtivosMemoria = {};
  bool _inicializado = false;

  /// Retorna a lista síncrona atual de motoristas ativos em memória
  List<LocalizacaoMotoristaModel> get motoristasAtivos =>
      List.unmodifiable(_motoristasAtivosMemoria.values.toList());

  /// Stream reativa de todos os motoristas ativos em trânsito no momento
  Stream<List<LocalizacaoMotoristaModel>> obterMotoristasAtivosStream() {
    _motoristasAtivosController.add(motoristasAtivos);
    return _motoristasAtivosController.stream;
  }

  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }


  void _inicializarOuvintes() {
    if (_inicializado) return;
    _inicializado = true;

    // 1. Escuta viagens do ViagemService local
    try {
      ViagemService().todasViagensStream.listen((viagens) {
        _sincronizarComViagens(viagens);
      });
    } catch (e) {
      debugPrint('ViagemService stream listener error: $e');
    }

    // 2. Se o Firebase estiver ativo, escuta viagens ativas remotas
    if (_isFirebaseDisponivel()) {
      try {
        FirebaseFirestore.instance
            .collection('viagens')
            .where('status', isEqualTo: 'ativa')
            .snapshots()
            .listen((snapshot) {
          final viagens = snapshot.docs
              .map((doc) => ViagemModel.fromMap(doc.data(), docId: doc.id))
              .toList();
          _sincronizarComViagens(viagens);
        });

        // Escuta coleção dedicada de localizações de motoristas, se alimentada
        FirebaseFirestore.instance
            .collection('localizacoes_motoristas')
            .where('emViagem', isEqualTo: true)
            .snapshots()
            .listen((snapshot) {
          for (final doc in snapshot.docs) {
            final loc = LocalizacaoMotoristaModel.fromMap(doc.data(), docId: doc.id);
            _motoristasAtivosMemoria[loc.motoristaId] = loc;
          }
          _motoristasAtivosController.add(motoristasAtivos);
        });
      } catch (e) {
        debugPrint('Firestore location listeners error: $e');
      }
    }
  }

  void _sincronizarComViagens(List<ViagemModel> viagens) {
    final viagensAtivas = viagens.where((v) => v.isAtiva).toList();
    if (viagensAtivas.isEmpty) {
      return;
    }

    // Para cada viagem ativa, assegura que o condutor está registrado na lista
    for (final viagem in viagensAtivas) {
      final motoristaId = viagem.motoristaId.isNotEmpty
          ? viagem.motoristaId
          : 'mot_${viagem.id}';

      final coords = _obterCoordenadasEstimadasPorDestino(viagem.cidadeDestino);

      final existente = _motoristasAtivosMemoria[motoristaId];
      if (existente != null) {
        _motoristasAtivosMemoria[motoristaId] = existente.copyWith(
          cidadeDestino: viagem.cidadeDestino,
          veiculoPlaca: viagem.veiculoPlaca,
          veiculoModelo: viagem.veiculoModelo,
          viagemId: viagem.id,
          emViagem: true,
          ultimaAtualizacao: DateTime.now(),
        );
      } else {
        _motoristasAtivosMemoria[motoristaId] = LocalizacaoMotoristaModel(
          id: 'loc_$motoristaId',
          motoristaId: motoristaId,
          motoristaNome: viagem.motoristaNome.isNotEmpty
              ? viagem.motoristaNome
              : 'Motorista Municipal',
          veiculoPlaca: viagem.veiculoPlaca.isNotEmpty
              ? viagem.veiculoPlaca
              : 'MUNICIPAL',
          veiculoModelo: viagem.veiculoModelo.isNotEmpty
              ? viagem.veiculoModelo
              : 'Veículo da Saúde',
          cidadeDestino: viagem.cidadeDestino.isNotEmpty
              ? viagem.cidadeDestino
              : 'Em Trânsito',
          latitude: coords.latitude,
          longitude: coords.longitude,
          ultimaAtualizacao: DateTime.now(),
          emViagem: true,
          viagemId: viagem.id,
        );
      }
    }

    _motoristasAtivosController.add(motoristasAtivos);
  }

  /// Retorna coordenadas geográficas realistas no trajeto regional
  ({double latitude, double longitude}) _obterCoordenadasEstimadasPorDestino(
      String destino) {
    final normalizado = destino.toUpperCase();
    if (normalizado.contains('BARRETOS')) {
      // Coordenada intermediária entre Poloni e Barretos (rodovias da região)
      return (latitude: -20.6120, longitude: -48.9100);
    } else if (normalizado.contains('RIO PRETO') || normalizado.contains('SJRP')) {
      // Coordenada intermediária próxima a Mirassol / Rio Preto
      return (latitude: -20.7800, longitude: -49.5200);
    } else if (normalizado.contains('CATANDUVA')) {
      return (latitude: -21.0500, longitude: -49.1200);
    } else if (normalizado.contains('VOTUPORANGA')) {
      return (latitude: -20.5500, longitude: -49.9200);
    } else {
      // Coordenadas próximas à sede municipal de Poloni
      return (latitude: -20.7389, longitude: -49.8217);
    }
  }

  /// Atualiza ativamente a posição de um motorista (GPS ou broadcast)
  Future<void> atualizarLocalizacaoMotorista({
    required String motoristaId,
    required String motoristaNome,
    required String veiculoPlaca,
    required String veiculoModelo,
    required String cidadeDestino,
    required double latitude,
    required double longitude,
    String? viagemId,
  }) async {
    final agora = DateTime.now();
    final registro = LocalizacaoMotoristaModel(
      id: 'loc_$motoristaId',
      motoristaId: motoristaId,
      motoristaNome: motoristaNome,
      veiculoPlaca: veiculoPlaca,
      veiculoModelo: veiculoModelo,
      cidadeDestino: cidadeDestino,
      latitude: latitude,
      longitude: longitude,
      ultimaAtualizacao: agora,
      emViagem: true,
      viagemId: viagemId,
    );

    _motoristasAtivosMemoria[motoristaId] = registro;
    _motoristasAtivosController.add(motoristasAtivos);

    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('localizacoes_motoristas')
            .doc(motoristaId)
            .set(registro.toMap(), SetOptions(merge: true));

        if (viagemId != null && viagemId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('viagens')
              .doc(viagemId)
              .set({
            'ultimaLatitude': latitude,
            'ultimaLongitude': longitude,
            'ultimaAtualizacaoLocalizacao': Timestamp.fromDate(agora),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Erro ao persistir localização remota do motorista: $e');
      }
    }
  }

  /// Remove ou inativa o motorista da lista quando sua viagem for encerrada
  void removerOuInativarMotorista(String motoristaId) {
    _motoristasAtivosMemoria.remove(motoristaId);
    _motoristasAtivosController.add(motoristasAtivos);

    if (_isFirebaseDisponivel()) {
      try {
        FirebaseFirestore.instance
            .collection('localizacoes_motoristas')
            .doc(motoristaId)
            .set({'emViagem': false}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  StreamSubscription<Position>? _gpsStreamSubscription;

  /// Solicita explicitamente a permissão de geolocalização do dispositivo (Android e Web)
  Future<LocationPermission> solicitarPermissaoLocalizacao() async {
    try {
      final servicoHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicoHabilitado) {
        return LocationPermission.denied;
      }
      LocationPermission permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      return permissao;
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de localização do Android/Web: $e');
      return LocationPermission.denied;
    }
  }

  /// Retorna as coordenadas GPS atuais do aparelho do usuário (paciente ou motorista)
  Future<Position?> obterPosicaoDispositivoAtual() async {
    try {
      final permissao = await solicitarPermissaoLocalizacao();
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao obter posição do dispositivo: $e');
      return null;
    }
  }

  /// Inicia o envio periódico da geolocalização real do aparelho do motorista
  Future<bool> iniciarTransmissaoGpsMotorista({
    required String motoristaId,
    required String motoristaNome,
    required String veiculoPlaca,
    required String veiculoModelo,
    required String cidadeDestino,
    String? viagemId,
  }) async {
    try {
      final posInicial = await obterPosicaoDispositivoAtual();
      if (posInicial != null) {
        await atualizarLocalizacaoMotorista(
          motoristaId: motoristaId,
          motoristaNome: motoristaNome,
          veiculoPlaca: veiculoPlaca,
          veiculoModelo: veiculoModelo,
          cidadeDestino: cidadeDestino,
          latitude: posInicial.latitude,
          longitude: posInicial.longitude,
          viagemId: viagemId,
        );
      }

      // Escuta stream contínua de movimentação
      _gpsStreamSubscription?.cancel();
      _gpsStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) {
        atualizarLocalizacaoMotorista(
          motoristaId: motoristaId,
          motoristaNome: motoristaNome,
          veiculoPlaca: veiculoPlaca,
          veiculoModelo: veiculoModelo,
          cidadeDestino: cidadeDestino,
          latitude: pos.latitude,
          longitude: pos.longitude,
          viagemId: viagemId,
        );
      });
      return true;
    } catch (e) {
      debugPrint('Erro ao iniciar transmissão GPS do motorista: $e');
      return false;
    }
  }

  /// Encerra a transmissão contínua de GPS do motorista
  void pararTransmissaoGpsMotorista() {
    _gpsStreamSubscription?.cancel();
    _gpsStreamSubscription = null;
  }

  /// Tenta capturar a posição do GPS do dispositivo de forma resiliente
  Future<Position?> capturarPosicaoGpsSegura() async {
    return obterPosicaoDispositivoAtual();
  }

  /// Método para reset em bateria de testes unitários
  @visibleForTesting
  void redefinirParaTestes({List<LocalizacaoMotoristaModel>? dadosIniciais}) {
    _motoristasAtivosMemoria.clear();
    if (dadosIniciais != null) {
      for (final m in dadosIniciais) {
        _motoristasAtivosMemoria[m.motoristaId] = m;
      }
    }
    _motoristasAtivosController.add(motoristasAtivos);
  }
}
