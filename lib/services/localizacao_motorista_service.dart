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
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Limiares de FinOps para contenção de cota no plano Spark:
  /// Persiste remotamente apenas quando houver deslocamento > 200m E intervalo >= 60s.
  static const double distanciaMinimaTelemetriaMetros = 200.0;
  static const Duration intervaloMinimoTelemetria = Duration(seconds: 60);

  final Map<String, LocalizacaoMotoristaModel> _motoristasAtivosMemoria = {};
  final Map<String, ({double lat, double lng, DateTime timestamp})>
      _ultimaCoordenadaPersistida = {};
  String? _transmissaoAtivaMotoristaId;
  String? _transmissaoAtivaViagemId;
  bool _iniciandoTransmissao = false;
  bool _inicializado = false;
  int _totalGravacoesRemotasGps = 0;

  StreamSubscription<List<ViagemModel>>? _subViagensLocal;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _subLocalizacoesFirestore;

  /// Total acumulado de gravações de telemetria GPS despachadas (FinOps).
  int get totalGravacoesRemotasGps => _totalGravacoesRemotasGps;

  /// Retorna a lista síncrona atual de motoristas ativos em memória
  List<LocalizacaoMotoristaModel> get motoristasAtivos =>
      List.unmodifiable(_motoristasAtivosMemoria.values.toList());

  /// Stream reativa de todos os motoristas ativos em trânsito no momento
  Stream<List<LocalizacaoMotoristaModel>> obterMotoristasAtivosStream() {
    if (!_inicializado) {
      _inicializarOuvintes();
    }
    _motoristasAtivosController.add(motoristasAtivos);
    return _motoristasAtivosController.stream;
  }

  /// Calcula a distância geodésica (Haversine) em metros entre duas coordenadas.
  static double calcularDistanciaMetros(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double raioTerraMetros = 6371000.0;
    final double dLat = (lat2 - lat1) * (math.pi / 180.0);
    final double dLon = (lon2 - lon1) * (math.pi / 180.0);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return raioTerraMetros * c;
  }

  /// Avalia o throttler/debouncer de estado: só autoriza escrita remota se for
  /// a posição inicial da sessão OU se houver deslocamento real > 200m E intervalo >= 60s.
  bool devePersistirTelemetriaGps({
    required String motoristaId,
    required double latitude,
    required double longitude,
    DateTime? instante,
  }) {
    final agora = instante ?? DateTime.now();
    final anterior = _ultimaCoordenadaPersistida[motoristaId];
    if (anterior == null) {
      return true;
    }
    final intervalo = agora.difference(anterior.timestamp);
    if (intervalo < intervaloMinimoTelemetria) {
      return false;
    }
    final deslocamentoMetros = calcularDistanciaMetros(
      anterior.lat,
      anterior.lng,
      latitude,
      longitude,
    );
    return deslocamentoMetros > distanciaMinimaTelemetriaMetros;
  }

  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }


  /// Inicia ou reata a escuta do Firestore quando há sessão autenticada.
  void garantirEscutasFirestore() {
    if (!_inicializado ||
        (_subLocalizacoesFirestore == null && _isFirebaseDisponivel())) {
      _inicializado = false;
      _inicializarOuvintes();
    }
  }

  void _inicializarOuvintes() {
    if (_inicializado) return;
    _inicializado = true;

    // 1. Escuta viagens do ViagemService local
    try {
      _subViagensLocal?.cancel();
      _subViagensLocal = ViagemService().todasViagensStream.listen((viagens) {
        _sincronizarComViagens(viagens);
      });
    } catch (e) {
      debugPrint('ViagemService stream listener error: $e');
    }

    // 2. Se o Firebase estiver ativo e autenticado, escuta a coleção dedicada de telemetria
    if (_isFirebaseDisponivel()) {
      String? authUid;
      try {
        authUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
      if (authUid == null || authUid.isEmpty) {
        return;
      }
      try {
        _subLocalizacoesFirestore?.cancel();
        _subLocalizacoesFirestore = FirebaseFirestore.instance
            .collection('localizacoes_motoristas')
            .where('emViagem', isEqualTo: true)
            .snapshots()
            .listen((snapshot) {
          final removidos = snapshot.docChanges
              .where((c) => c.type == DocumentChangeType.removed);
          for (final ch in removidos) {
            final motIdRemovido =
                (ch.doc.data()?['motoristaId'] ?? ch.doc.id).toString();
            _motoristasAtivosMemoria.remove(motIdRemovido);
          }
          for (final doc in snapshot.docs) {
            final loc = LocalizacaoMotoristaModel.fromMap(doc.data(), docId: doc.id);
            _motoristasAtivosMemoria[loc.motoristaId] = loc;
          }
          _motoristasAtivosController.add(motoristasAtivos);
        }, onError: (Object erro) {
          debugPrint('Erro no listener de localizacoes_motoristas: $erro');
          _subLocalizacoesFirestore?.cancel();
          _subLocalizacoesFirestore = null;
        });
      } catch (e) {
        debugPrint('Firestore location listeners error: $e');
      }
    }
  }

  /// Encerra as subscrições de escuta associadas ao escopo da sessão/tela (FinOps).
  void encerrarEscutas() {
    pararTransmissaoGpsMotorista();
    _subViagensLocal?.cancel();
    _subViagensLocal = null;
    _subLocalizacoesFirestore?.cancel();
    _subLocalizacoesFirestore = null;
    _inicializado = false;
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

    // Sincroniza apenas viagens operacionais que já possuam coordenadas GPS reais
    final viagensValidas = viagens
        .where((v) =>
            v.isEmOperacao &&
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
    DateTime? instanteReferencia,
  }) async {
    final agora = instanteReferencia ?? DateTime.now();
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

    // FinOps Throttler/Debouncer com trava de estado:
    // Só autoriza gravação remota se houver deslocamento > 200m E intervalo >= 60s
    // (ou se for a coordenada inicial da jornada), suspendendo gravações com veículo parado.
    if (!devePersistirTelemetriaGps(
      motoristaId: motoristaId,
      latitude: latitude,
      longitude: longitude,
      instante: agora,
    )) {
      return;
    }

    _ultimaCoordenadaPersistida[motoristaId] = (
      lat: latitude,
      lng: longitude,
      timestamp: agora,
    );
    _totalGravacoesRemotasGps++;

    if (_isFirebaseDisponivel()) {
      // Isola a telemetria GPS exclusivamente na coleção 'localizacoes_motoristas',
      // eliminando gravações contínuas nos documentos transacionais de 'viagens' e 'usuarios'.
      try {
        await FirebaseFirestore.instance
            .collection('localizacoes_motoristas')
            .doc(motoristaId)
            .set(registro.toMap(), SetOptions(merge: true));
      } on FirebaseException catch (e) {
        debugPrint(
          'Falha Firebase ao persistir telemetria GPS [${e.code}]: ${e.message}',
        );
      } catch (e) {
        debugPrint('Erro ao persistir telemetria GPS: $e');
      }
    }
  }

  /// Se houver viagem ativa/planejada sem coordenadas GPS registradas, vincula a posição GPS real capturada no aparelho
  Future<void> garantirLocalizacaoViagemAtivaComGpsDispositivo(
    double latitude,
    double longitude,
  ) async {
    final viagens = ViagemService().todasViagens.where((v) =>
        v.isEmOperacao &&
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
    _ultimaCoordenadaPersistida.remove(motoristaId);
    _motoristasAtivosController.add(motoristasAtivos);

    if (_isFirebaseDisponivel()) {
      try {
        FirebaseFirestore.instance
            .collection('localizacoes_motoristas')
            .doc(motoristaId)
            .update({
              'emViagem': false,
              'atualizadoEm': FieldValue.serverTimestamp(),
            })
            .catchError((_) {});
      } catch (e) {
        debugPrint('Erro ao inativar localização do motorista: $e');
      }
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
    // Trava de idempotência para evitar re-entrância por listeners de snapshot
    if (_transmissaoAtivaMotoristaId == motoristaId &&
        _transmissaoAtivaViagemId == viagemId &&
        (_iniciandoTransmissao || _gpsStreamSubscription != null)) {
      return true;
    }
    _transmissaoAtivaMotoristaId = motoristaId;
    _transmissaoAtivaViagemId = viagemId;
    _iniciandoTransmissao = true;
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

      // Escuta stream contínua de movimentação filtrada por deslocamento mínimo de 200m
      // (suspende emissões quando o veículo está parado).
      _gpsStreamSubscription?.cancel();
      _gpsPeriodicTimer?.cancel();
      _gpsPeriodicTimer = null;
      _gpsStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 200,
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
      _iniciandoTransmissao = false;
      return true;
    } catch (e) {
      _iniciandoTransmissao = false;
      debugPrint('Erro ao iniciar transmissão GPS do motorista: $e');
      return false;
    }
  }

  /// Encerra a transmissão contínua de GPS do motorista
  void pararTransmissaoGpsMotorista() {
    _transmissaoAtivaMotoristaId = null;
    _transmissaoAtivaViagemId = null;
    _iniciandoTransmissao = false;
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
    pararTransmissaoGpsMotorista();
    _ultimaCoordenadaPersistida.clear();
    _totalGravacoesRemotasGps = 0;
    _motoristasAtivosMemoria.clear();
    if (dadosIniciais != null) {
      for (final m in dadosIniciais) {
        _motoristasAtivosMemoria[m.motoristaId] = m;
      }
    }
    _motoristasAtivosController.add(motoristasAtivos);
  }
}
