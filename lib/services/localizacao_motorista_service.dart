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

    // 2. Se o Firebase estiver ativo, escuta viagens e motoristas remotos
    if (_isFirebaseDisponivel()) {
      try {
        FirebaseFirestore.instance
            .collection('viagens')
            .snapshots()
            .listen((snapshot) {
          final viagens = snapshot.docs
              .map((doc) => ViagemModel.fromMap(doc.data(), docId: doc.id))
              .toList();
          _sincronizarComViagens(viagens);
        }, onError: (_) {});

        // Escuta documentos de motoristas na coleção 'usuarios' que possuam coordenadas GPS ativas
        FirebaseFirestore.instance
            .collection('usuarios')
            .where('role', isEqualTo: 'motorista')
            .snapshots()
            .listen((snapshot) {
          bool alterou = false;
          for (final doc in snapshot.docs) {
            final dados = doc.data();
            final emViagem = dados['emViagem'] == true;
            final latRaw = dados['latitude'];
            final lngRaw = dados['longitude'];
            final double? lat = (latRaw is num)
                ? latRaw.toDouble()
                : double.tryParse(latRaw?.toString() ?? '');
            final double? lng = (lngRaw is num)
                ? lngRaw.toDouble()
                : double.tryParse(lngRaw?.toString() ?? '');

            if (emViagem && lat != null && lng != null) {
              final nome = (dados['nome'] ?? '').toString().trim();
              final placa = (dados['veiculoPlaca'] ?? '').toString().trim();
              final modelo = (dados['veiculoModelo'] ?? '').toString().trim();
              final destino = (dados['cidadeDestino'] ?? '').toString().trim();
              _motoristasAtivosMemoria[doc.id] = LocalizacaoMotoristaModel(
                id: 'loc_${doc.id}',
                motoristaId: doc.id,
                motoristaNome: nome.isNotEmpty ? nome : 'Motorista',
                veiculoPlaca: placa,
                veiculoModelo: modelo,
                cidadeDestino: destino,
                latitude: lat,
                longitude: lng,
                ultimaAtualizacao: DateTime.now(),
                emViagem: true,
                viagemId: dados['viagemAtivaId']?.toString(),
              );
              alterou = true;
            } else if (dados['emViagem'] == false &&
                _motoristasAtivosMemoria.containsKey(doc.id)) {
              _motoristasAtivosMemoria.remove(doc.id);
              alterou = true;
            }
          }
          if (alterou) {
            _motoristasAtivosController.add(motoristasAtivos);
          }
        }, onError: (_) {});

        // Escuta coleção dedicada de localizações de motoristas, se disponível
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
        }, onError: (_) {});
      } catch (e) {
        debugPrint('Firestore location listeners error: $e');
      }
    }
  }

  void _sincronizarComViagens(List<ViagemModel> viagens) {
    bool alterou = false;

    // Remove motoristas cujas viagens foram encerradas ou canceladas
    for (final v in viagens) {
      if (v.isCancelada || v.isConcluida) {
        final idsParaRemover = _motoristasAtivosMemoria.entries
            .where((e) => e.value.viagemId == v.id)
            .map((e) => e.key)
            .toList();
        for (final id in idsParaRemover) {
          _motoristasAtivosMemoria.remove(id);
          alterou = true;
        }
      }
    }

    // Sincroniza apenas viagens ativas ou planejadas que já possuam coordenadas GPS reais
    final viagensValidas = viagens
        .where((v) =>
            (v.isAtiva || v.isPlanejada) &&
            !v.isCancelada &&
            !v.isConcluida &&
            v.ultimaLatitude != null &&
            v.ultimaLongitude != null)
        .toList();

    for (final viagem in viagensValidas) {
      final motoristaId = viagem.motoristaId.isNotEmpty
          ? viagem.motoristaId
          : 'mot_${viagem.id}';

      if (motoristaId == 'motorista_atual') continue;

      _motoristasAtivosMemoria[motoristaId] = LocalizacaoMotoristaModel(
        id: 'loc_$motoristaId',
        motoristaId: motoristaId,
        motoristaNome: viagem.motoristaNome.isNotEmpty
            ? viagem.motoristaNome
            : 'Motorista',
        veiculoPlaca: viagem.veiculoPlaca,
        veiculoModelo: viagem.veiculoModelo,
        cidadeDestino: viagem.cidadeDestino,
        latitude: viagem.ultimaLatitude!,
        longitude: viagem.ultimaLongitude!,
        ultimaAtualizacao:
            viagem.ultimaAtualizacaoLocalizacao ?? DateTime.now(),
        emViagem: true,
        viagemId: viagem.id,
      );
      alterou = true;
    }

    if (alterou) {
      _motoristasAtivosController.add(motoristasAtivos);
    }
  }

  /// Atualiza ativamente a posição real de um motorista (GPS ou broadcast)
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
      // 1. Atualiza na coleção 'viagens' (documento da viagem ativa ou viagens do motorista)
      try {
        if (viagemId != null && viagemId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('viagens')
              .doc(viagemId)
              .set({
            'ultimaLatitude': latitude,
            'ultimaLongitude': longitude,
            'ultimaAtualizacaoLocalizacao': agora.toIso8601String(),
            'status': 'ativa',
          }, SetOptions(merge: true));
        } else {
          final snap = await FirebaseFirestore.instance
              .collection('viagens')
              .where('motoristaId', isEqualTo: motoristaId)
              .get();
          for (final doc in snap.docs) {
            final st = (doc.data()['status'] ?? '').toString();
            if (st == 'ativa' || st == 'planejada') {
              await doc.reference.set({
                'ultimaLatitude': latitude,
                'ultimaLongitude': longitude,
                'ultimaAtualizacaoLocalizacao': agora.toIso8601String(),
                'status': 'ativa',
              }, SetOptions(merge: true));
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao persistir localização na viagem: $e');
      }

      // 2. Atualiza no documento do motorista na coleção 'usuarios'
      if (motoristaId.isNotEmpty && motoristaId != 'motorista_atual') {
        try {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(motoristaId)
              .set({
            'latitude': latitude,
            'longitude': longitude,
            'ultimaAtualizacaoLocalizacao': agora.toIso8601String(),
            'emViagem': true,
            if (veiculoPlaca.isNotEmpty) 'veiculoPlaca': veiculoPlaca,
            if (veiculoModelo.isNotEmpty) 'veiculoModelo': veiculoModelo,
            if (cidadeDestino.isNotEmpty) 'cidadeDestino': cidadeDestino,
            if (viagemId != null && viagemId.isNotEmpty)
              'viagemAtivaId': viagemId,
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      // 3. Tenta atualizar na coleção dedicada 'localizacoes_motoristas' de forma isolada
      try {
        await FirebaseFirestore.instance
            .collection('localizacoes_motoristas')
            .doc(motoristaId)
            .set(registro.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Se houver viagem ativa/planejada sem coordenadas GPS registradas, vincula a posição GPS real capturada no aparelho
  Future<void> garantirLocalizacaoViagemAtivaComGpsDispositivo(
    double latitude,
    double longitude,
  ) async {
    final viagens = ViagemService().todasViagens.where((v) =>
        (v.isAtiva || v.isPlanejada) &&
        !v.isCancelada &&
        !v.isConcluida &&
        v.motoristaId.isNotEmpty &&
        v.motoristaId != 'motorista_atual');

    for (final v in viagens) {
      if (!_motoristasAtivosMemoria.containsKey(v.motoristaId)) {
        await atualizarLocalizacaoMotorista(
          motoristaId: v.motoristaId,
          motoristaNome: v.motoristaNome.isNotEmpty ? v.motoristaNome : 'Motorista',
          veiculoPlaca: v.veiculoPlaca,
          veiculoModelo: v.veiculoModelo,
          cidadeDestino: v.cidadeDestino,
          latitude: latitude,
          longitude: longitude,
          viagemId: v.id,
        );
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
            .collection('usuarios')
            .doc(motoristaId)
            .set({'emViagem': false}, SetOptions(merge: true));
      } catch (_) {}
      try {
        FirebaseFirestore.instance
            .collection('localizacoes_motoristas')
            .doc(motoristaId)
            .set({'emViagem': false}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  StreamSubscription<Position>? _gpsStreamSubscription;
  Timer? _gpsPeriodicTimer;

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
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        final ultima = await Geolocator.getLastKnownPosition();
        if (ultima != null) return ultima;
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao obter posição do dispositivo: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
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
          distanceFilter: 5,
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

      // Atualiza periodicamente mesmo quando o veículo está parado no semáforo/embarque
      _gpsPeriodicTimer?.cancel();
      _gpsPeriodicTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        final pos = await obterPosicaoDispositivoAtual();
        if (pos != null) {
          await atualizarLocalizacaoMotorista(
            motoristaId: motoristaId,
            motoristaNome: motoristaNome,
            veiculoPlaca: veiculoPlaca,
            veiculoModelo: veiculoModelo,
            cidadeDestino: cidadeDestino,
            latitude: pos.latitude,
            longitude: pos.longitude,
            viagemId: viagemId,
          );
        }
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
    _gpsPeriodicTimer?.cancel();
    _gpsPeriodicTimer = null;
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
