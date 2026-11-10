// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/sessao_veiculo_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula as informações de uma Sessão de Veículo aberta pelo motorista,
// representando o vínculo: Sessão do Condutor -> Veículo Municipal -> N Viagens Ativas.
// Permite que o condutor declare seu veículo e quilometragem inicial uma única vez
// e gerencie múltiplas rotas/viagens independentes ao longo de sua jornada de trabalho.
//
// PARA QUE SERVE NO PROJETO:
// É o modelo central da refatoração da Issue #65: desacopla a declaração de veículo
// da criação imediata de viagem, viabilizando jornadas com escalas múltiplas,
// navegação entre viagens no painel e geração de relatório PDF consolidado em lote.
//
// ONDE É USADO NO PROJETO:
// - lib/services/viagem_service.dart (registro da sessão e gerenciamento das N viagens)
// - lib/motorista.dart (exibição de dados do veículo e paginação entre viagens)
// - lib/components/formulario_inicio_viagem.dart (declaração de veículo do condutor)
//
// DE ONDE RECEBE DADOS:
// Formulário de Declaração de Veículo e coleção 'sessoes_veiculo' do Firestore.
//
// O QUE EXPORTA / EXPÕE:
// - class SessaoVeiculoModel: entidade imutável da sessão
// - Construtor constante SessaoVeiculoModel(...)
// - toMap() e factory fromMap() para persistência no Firestore
// - copyWith() para clonagem imutável com parâmetros atualizados
// ============================================================================

import 'firestore_parse_utils.dart';

/// Modelo de dados que representa a Sessão de Veículo do Motorista.
///
/// Estrutura a relação:
/// 1 Motorista + 1 Veículo Declarado -> N Viagens Ativas na jornada.
class SessaoVeiculoModel {
  /// Identificador exclusivo da sessão de veículo (geralmente gerado com timestamp).
  final String id;

  /// Identificador único do motorista autenticado responsável pela sessão.
  final String motoristaId;

  /// Nome completo do motorista condutor.
  final String motoristaNome;

  /// Identificador do veículo municipal selecionado.
  final String veiculoId;

  /// Placa do veículo municipal selecionado.
  final String veiculoPlaca;

  /// Modelo descritivo do veículo selecionado.
  final String veiculoModelo;

  /// Quilometragem inicial registrada no momento da declaração do veículo.
  final int kmInicial;

  /// Data e hora da declaração de início da sessão do veículo.
  final DateTime dataHoraInicio;

  /// Situação operacional da sessão ('ativa' ou 'encerrada').
  final String status;

  /// Quilometragem final registrada no encerramento da sessão de trabalho.
  final int? kmFinal;

  /// Total de quilômetros rodados durante a sessão (kmFinal - kmInicial).
  final int? kmRodado;

  /// Data e hora de conclusão da sessão do veículo.
  final DateTime? dataHoraFim;

  /// Lista de identificadores das viagens ativas vinculadas a esta sessão.
  final List<String> viagensIds;

  /// Observações gerais da jornada de trabalho.
  final String? observacoes;

  /// Construtor constante para instâncias imutáveis de [SessaoVeiculoModel].
  const SessaoVeiculoModel({
    required this.id,
    required this.motoristaId,
    required this.motoristaNome,
    required this.veiculoId,
    required this.veiculoPlaca,
    required this.veiculoModelo,
    required this.kmInicial,
    required this.dataHoraInicio,
    this.status = 'ativa',
    this.kmFinal,
    this.kmRodado,
    this.dataHoraFim,
    this.viagensIds = const [],
    this.observacoes,
  });

  /// Indica se a sessão do veículo permanece em andamento.
  bool get isAtiva => status == 'ativa';

  /// Serializa a sessão de veículo para formato [Map] persistível no Cloud Firestore.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'motoristaId': motoristaId,
      if (motoristaNome.trim().isNotEmpty)
        'motoristaNome': motoristaNome.trim(),
      'veiculoId': veiculoId,
      if (veiculoPlaca.trim().isNotEmpty) 'veiculoPlaca': veiculoPlaca.trim(),
      if (veiculoModelo.trim().isNotEmpty)
        'veiculoModelo': veiculoModelo.trim(),
      'kmInicial': kmInicial,
      'dataHoraInicio': dataHoraInicio.toIso8601String(),
      'status': status,
      if (kmFinal != null) 'kmFinal': kmFinal,
      if (kmRodado != null) 'kmRodado': kmRodado,
      if (dataHoraFim != null) 'dataHoraFim': dataHoraFim!.toIso8601String(),
      'viagensIds': viagensIds,
      if (observacoes != null && observacoes!.trim().isNotEmpty)
        'observacoes': observacoes!.trim(),
    };
  }

  /// Reconstrói uma instância de [SessaoVeiculoModel] a partir de um [Map] NoSQL.
  factory SessaoVeiculoModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawViagens = map['viagensIds'];
    List<String> parsedViagens = [];
    if (rawViagens is List) {
      parsedViagens = rawViagens.map((e) => e.toString()).toList();
    }

    return SessaoVeiculoModel(
      id: docId ?? (map['id'] ?? '').toString(),
      motoristaId: (map['motoristaId'] ?? '').toString(),
      motoristaNome: (map['motoristaNome'] ?? '').toString(),
      veiculoId: (map['veiculoId'] ?? '').toString(),
      veiculoPlaca: (map['veiculoPlaca'] ?? '').toString(),
      veiculoModelo: (map['veiculoModelo'] ?? '').toString(),
      kmInicial: (map['kmInicial'] is num)
          ? (map['kmInicial'] as num).toInt()
          : (int.tryParse(map['kmInicial']?.toString() ?? '') ?? 0),
      dataHoraInicio:
          parsearDataFirestore(map['dataHoraInicio']) ?? DateTime.now(),
      status: (map['status'] ?? 'ativa').toString(),
      kmFinal: map['kmFinal'] != null ? (map['kmFinal'] as num).toInt() : null,
      kmRodado: map['kmRodado'] != null ? (map['kmRodado'] as num).toInt() : null,
      dataHoraFim: parsearDataFirestore(map['dataHoraFim']),
      viagensIds: parsedViagens,
      observacoes: map['observacoes']?.toString(),
    );
  }

  /// Retorna uma cópia imutável desta sessão substituindo apenas os campos especificados.
  SessaoVeiculoModel copyWith({
    String? id,
    String? motoristaId,
    String? motoristaNome,
    String? veiculoId,
    String? veiculoPlaca,
    String? veiculoModelo,
    int? kmInicial,
    DateTime? dataHoraInicio,
    String? status,
    int? kmFinal,
    int? kmRodado,
    DateTime? dataHoraFim,
    List<String>? viagensIds,
    String? observacoes,
  }) {
    return SessaoVeiculoModel(
      id: id ?? this.id,
      motoristaId: motoristaId ?? this.motoristaId,
      motoristaNome: motoristaNome ?? this.motoristaNome,
      veiculoId: veiculoId ?? this.veiculoId,
      veiculoPlaca: veiculoPlaca ?? this.veiculoPlaca,
      veiculoModelo: veiculoModelo ?? this.veiculoModelo,
      kmInicial: kmInicial ?? this.kmInicial,
      dataHoraInicio: dataHoraInicio ?? this.dataHoraInicio,
      status: status ?? this.status,
      kmFinal: kmFinal ?? this.kmFinal,
      kmRodado: kmRodado ?? this.kmRodado,
      dataHoraFim: dataHoraFim ?? this.dataHoraFim,
      viagensIds: viagensIds ?? this.viagensIds,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}
