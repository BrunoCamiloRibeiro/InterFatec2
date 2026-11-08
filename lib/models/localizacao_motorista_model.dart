// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/localizacao_motorista_model.dart
// Camada: Modelo de Domínio / DTO (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Define a entidade imutável LocalizacaoMotoristaModel, que encapsula as
// coordenadas geográficas (latitude/longitude), identificação do condutor,
// placa do veículo, cidade de destino e carimbo temporal de atualização
// dos motoristas municipais em viagem ativa.
//
// PARA QUE SERVE NO PROJETO:
// Permite que o módulo do paciente e a central administrativa visualizem
// a localização em tempo real de todos os motoristas em trânsito no mapa,
// em estrita conformidade com a especificação (sem estimativas de rota ou ETA).
//
// ONDE É USADO NO PROJETO:
// - lib/services/localizacao_motorista_service.dart
// - lib/components/card_tracking_paciente.dart
// - lib/paciente.dart
// - test/components/card_tracking_paciente_test.dart
//
// ORIGEM HISTÓRICA:
// Criado para atender a demanda de rastreamento veicular em tempo real
// de todos os motoristas ativos na Issue #65 / Rastreamento do Paciente.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Entidade imutável que representa a coordenada geográfica e metadados
/// de um motorista em viagem ativa no sistema de transporte sanitário.
class LocalizacaoMotoristaModel {
  /// Identificador do registro (geralmente o ID do motorista ou da viagem)
  final String id;

  /// Identificador único do motorista (chave de usuário no Firestore)
  final String motoristaId;

  /// Nome completo do motorista para exibição no mapa
  final String motoristaNome;

  /// Placa do veículo em trânsito (ex.: 'ABC-1D23')
  final String veiculoPlaca;

  /// Modelo do automóvel (ex.: 'Chevrolet Spin 1.8 LTZ')
  final String veiculoModelo;

  /// Município de destino da viagem (ex.: 'São José do Rio Preto', 'Barretos')
  final String cidadeDestino;

  /// Coordenada geográfica de latitude (-90.0 a 90.0)
  final double latitude;

  /// Coordenada geográfica de longitude (-180.0 a 180.0)
  final double longitude;

  /// Timestamp da última transmissão ou captura de sinal GPS
  final DateTime ultimaAtualizacao;

  /// Indica se a viagem correspondente está atualmente em andamento
  final bool emViagem;

  /// Identificador opcional da viagem ativa vinculada
  final String? viagemId;

  const LocalizacaoMotoristaModel({
    required this.id,
    required this.motoristaId,
    required this.motoristaNome,
    required this.veiculoPlaca,
    required this.veiculoModelo,
    required this.cidadeDestino,
    required this.latitude,
    required this.longitude,
    required this.ultimaAtualizacao,
    this.emViagem = true,
    this.viagemId,
  });

  /// Constrói uma instância a partir de um mapa de dados (ex.: Firestore snapshot)
  factory LocalizacaoMotoristaModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    DateTime parseData(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    double parseCoord(dynamic val, double fallback) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? fallback;
      return fallback;
    }

    return LocalizacaoMotoristaModel(
      id: docId ?? map['id']?.toString() ?? '',
      motoristaId: map['motoristaId']?.toString() ?? '',
      motoristaNome: map['motoristaNome']?.toString() ?? 'Motorista Municipal',
      veiculoPlaca: map['veiculoPlaca']?.toString() ?? 'MUNICIPAL',
      veiculoModelo: map['veiculoModelo']?.toString() ?? 'Veículo da Saúde',
      cidadeDestino: map['cidadeDestino']?.toString() ?? 'Destino em Trânsito',
      latitude: parseCoord(map['latitude'], -20.7389),
      longitude: parseCoord(map['longitude'], -49.8217),
      ultimaAtualizacao: parseData(map['ultimaAtualizacao']),
      emViagem: map['emViagem'] as bool? ?? true,
      viagemId: map['viagemId']?.toString(),
    );
  }

  /// Serializa a instância para armazenamento no Cloud Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'motoristaId': motoristaId,
      'motoristaNome': motoristaNome,
      'veiculoPlaca': veiculoPlaca,
      'veiculoModelo': veiculoModelo,
      'cidadeDestino': cidadeDestino,
      'latitude': latitude,
      'longitude': longitude,
      'ultimaAtualizacao': Timestamp.fromDate(ultimaAtualizacao),
      'emViagem': emViagem,
      if (viagemId != null) 'viagemId': viagemId,
    };
  }

  /// Produz uma cópia com campos atualizados preservando imutabilidade
  LocalizacaoMotoristaModel copyWith({
    String? id,
    String? motoristaId,
    String? motoristaNome,
    String? veiculoPlaca,
    String? veiculoModelo,
    String? cidadeDestino,
    double? latitude,
    double? longitude,
    DateTime? ultimaAtualizacao,
    bool? emViagem,
    String? viagemId,
  }) {
    return LocalizacaoMotoristaModel(
      id: id ?? this.id,
      motoristaId: motoristaId ?? this.motoristaId,
      motoristaNome: motoristaNome ?? this.motoristaNome,
      veiculoPlaca: veiculoPlaca ?? this.veiculoPlaca,
      veiculoModelo: veiculoModelo ?? this.veiculoModelo,
      cidadeDestino: cidadeDestino ?? this.cidadeDestino,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ultimaAtualizacao: ultimaAtualizacao ?? this.ultimaAtualizacao,
      emViagem: emViagem ?? this.emViagem,
      viagemId: viagemId ?? this.viagemId,
    );
  }

  @override
  String toString() {
    return 'LocalizacaoMotoristaModel(id: $id, motorista: $motoristaNome, placa: $veiculoPlaca, destino: $cidadeDestino, lat: $latitude, lng: $longitude)';
  }
}
