import 'firestore_parse_utils.dart';
import 'passageiro_viagem_model.dart';
export 'passageiro_viagem_model.dart';

/// Estados possíveis do ciclo de vida da viagem na visão do motorista.
enum EstadoViagem {
  semViagem,
  preenchendoFormulario,
  viagemAtiva,
  encerrada,
}

/// Modelo imutável de dados operacionais de uma Viagem TFD.
class ViagemModel {
  final String id;
  final String motoristaId;
  final String motoristaNome;
  final String veiculoId;
  final String veiculoPlaca;
  final String veiculoModelo;
  final int kmInicial;
  final String cidadeDestino;
  final DateTime dataHoraInicio;

  /// Situação operacional: `'aberta'`, `'planejada'`, `'ativa'`, `'encerrada'` ou `'cancelada'`.
  final String status;

  final int? kmFinal;
  final int? kmRodado;
  final DateTime? dataHoraFim;
  final String? observacoes;
  final List<String> passageirosIds;
  final String? sessaoId;

  /// Códigos de acesso temporários de 4–5 dígitos indexados por `pacienteId`.
  final Map<String, String> codigosAcesso;

  /// Hashes criptográficos dos códigos de acesso indexados por `pacienteId`.
  final Map<String, String> codigosHash;

  final String? nomeHorario;
  final DateTime? dataViagem;
  final List<PassageiroViagemModel> passageiros;
  final double? ultimaLatitude;
  final double? ultimaLongitude;
  final DateTime? ultimaAtualizacaoLocalizacao;

  const ViagemModel({
    required this.id,
    required this.motoristaId,
    required this.motoristaNome,
    required this.veiculoId,
    required this.veiculoPlaca,
    required this.veiculoModelo,
    required this.kmInicial,
    required this.cidadeDestino,
    required this.dataHoraInicio,
    this.status = 'ativa',
    this.kmFinal,
    this.kmRodado,
    this.dataHoraFim,
    this.observacoes,
    this.passageirosIds = const [],
    this.sessaoId,
    this.codigosAcesso = const {},
    this.codigosHash = const {},
    this.nomeHorario,
    this.dataViagem,
    this.passageiros = const [],
    this.ultimaLatitude,
    this.ultimaLongitude,
    this.ultimaAtualizacaoLocalizacao,
  });

  String get tituloHorario {
    if (nomeHorario != null && nomeHorario!.trim().isNotEmpty) {
      return nomeHorario!;
    }
    final hora = dataHoraInicio.hour.toString().padLeft(2, '0');
    final minuto = dataHoraInicio.minute.toString().padLeft(2, '0');
    return '$hora:$minuto - $cidadeDestino';
  }

  DateTime get dataOperacional =>
      dataViagem ??
      DateTime(dataHoraInicio.year, dataHoraInicio.month, dataHoraInicio.day);

  int get totalAssentosOcupados {
    if (passageiros.isNotEmpty) {
      return passageiros.fold(0, (sum, p) => sum + p.assentosOcupados);
    }
    return passageirosIds.length;
  }

  bool get isAtiva {
    final st = status.trim().toLowerCase();
    return st == 'ativa' || st == 'em andamento' || st == 'em_andamento';
  }

  bool get isPlanejada {
    final st = status.trim().toLowerCase();
    return st == 'planejada' || st == 'agendada';
  }

  bool get isAberta => status.trim().toLowerCase() == 'aberta';

  bool get isConcluida {
    final st = status.trim().toLowerCase();
    return st == 'encerrada' || st == 'concluida' || st == 'finalizada';
  }

  bool get isCancelada => status.trim().toLowerCase() == 'cancelada';

  /// Indica viagem ainda operacional (nem encerrada nem cancelada).
  bool get isEmOperacao => !isConcluida && !isCancelada;

  Map<String, dynamic> toMap() {
    final effectivePassageirosIds = passageirosIds.isNotEmpty
        ? passageirosIds
        : passageiros.map((p) => p.pacienteId).toList();

    return {
      'id': id,
      'motoristaId': motoristaId,
      'motoristaNome': motoristaNome,
      'veiculoId': veiculoId,
      'veiculoPlaca': veiculoPlaca,
      'veiculoModelo': veiculoModelo,
      'kmInicial': kmInicial,
      'cidadeDestino': cidadeDestino,
      'dataHoraInicio': dataHoraInicio.toIso8601String(),
      'status': status,
      'kmFinal': kmFinal,
      'kmRodado': kmRodado,
      if (dataHoraFim != null) 'dataHoraFim': dataHoraFim!.toIso8601String(),
      'observacoes': observacoes,
      'passageirosIds': effectivePassageirosIds,
      'sessaoId': sessaoId,
      'codigosAcesso': codigosAcesso,
      'codigosHash': codigosHash,
      if (nomeHorario != null) 'nomeHorario': nomeHorario,
      if (nomeHorario != null && nomeHorario!.length <= 60)
        'horario': nomeHorario,
      'dataViagem': (dataViagem ?? dataHoraInicio).toIso8601String(),
      'passageiros': passageiros.map((p) => p.toMap()).toList(),
      if (ultimaLatitude != null) 'ultimaLatitude': ultimaLatitude,
      if (ultimaLongitude != null) 'ultimaLongitude': ultimaLongitude,
      if (ultimaAtualizacaoLocalizacao != null)
        'ultimaAtualizacaoLocalizacao':
            ultimaAtualizacaoLocalizacao!.toIso8601String(),
    };
  }

  static Map<String, String> _parseMapaStrings(dynamic raw) {
    if (raw is! Map) return const {};
    return Map<String, String>.from(
      raw.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }

  factory ViagemModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final passageirosRaw = map['passageiros'];
    final passageirosIdsRaw = map['passageirosIds'];

    final passageirosDetalhados =
        (passageirosRaw is List && passageirosRaw.isNotEmpty)
            ? passageirosRaw
                .map(
                  (p) => PassageiroViagemModel.fromMap(
                    Map<String, dynamic>.from(p as Map),
                  ),
                )
                .toList()
            : (passageirosIdsRaw is List && passageirosIdsRaw.isNotEmpty)
                ? passageirosIdsRaw
                    .map(
                      (id) => PassageiroViagemModel(
                        pacienteId: id.toString(),
                        pacienteNome: 'Paciente $id',
                        localDestino: map['cidadeDestino']?.toString() ?? '',
                      ),
                    )
                    .toList()
                : const <PassageiroViagemModel>[];

    return ViagemModel(
      id: docId ?? map['id'] ?? '',
      motoristaId: map['motoristaId'] ?? '',
      motoristaNome: map['motoristaNome'] ?? '',
      veiculoId: map['veiculoId'] ?? '',
      veiculoPlaca: map['veiculoPlaca'] ?? '',
      veiculoModelo: map['veiculoModelo'] ?? '',
      kmInicial:
          (map['kmInicial'] is num) ? (map['kmInicial'] as num).toInt() : 0,
      cidadeDestino: map['cidadeDestino'] ?? '',
      dataHoraInicio:
          parsearDataFirestore(map['dataHoraInicio']) ?? DateTime.now(),
      status: map['status'] ?? 'ativa',
      kmFinal: (map['kmFinal'] is num) ? (map['kmFinal'] as num).toInt() : null,
      kmRodado:
          (map['kmRodado'] is num) ? (map['kmRodado'] as num).toInt() : null,
      dataHoraFim: parsearDataFirestore(map['dataHoraFim']),
      observacoes: map['observacoes'],
      passageirosIds: (passageirosIdsRaw is List)
          ? List<String>.from(passageirosIdsRaw)
          : const [],
      sessaoId: map['sessaoId']?.toString(),
      codigosAcesso: _parseMapaStrings(map['codigosAcesso']),
      codigosHash: _parseMapaStrings(map['codigosHash']),
      nomeHorario: map['nomeHorario']?.toString() ?? map['horario']?.toString(),
      dataViagem: parsearDataFirestore(map['dataViagem']),
      passageiros: passageirosDetalhados,
      ultimaLatitude: (map['ultimaLatitude'] is num)
          ? (map['ultimaLatitude'] as num).toDouble()
          : double.tryParse(map['ultimaLatitude']?.toString() ?? ''),
      ultimaLongitude: (map['ultimaLongitude'] is num)
          ? (map['ultimaLongitude'] as num).toDouble()
          : double.tryParse(map['ultimaLongitude']?.toString() ?? ''),
      ultimaAtualizacaoLocalizacao:
          parsearDataFirestore(map['ultimaAtualizacaoLocalizacao']),
    );
  }

  ViagemModel copyWith({
    String? id,
    String? motoristaId,
    String? motoristaNome,
    String? veiculoId,
    String? veiculoPlaca,
    String? veiculoModelo,
    int? kmInicial,
    String? cidadeDestino,
    DateTime? dataHoraInicio,
    String? status,
    int? kmFinal,
    int? kmRodado,
    DateTime? dataHoraFim,
    String? observacoes,
    List<String>? passageirosIds,
    String? sessaoId,
    bool removerSessaoId = false,
    Map<String, String>? codigosAcesso,
    Map<String, String>? codigosHash,
    String? nomeHorario,
    DateTime? dataViagem,
    List<PassageiroViagemModel>? passageiros,
    double? ultimaLatitude,
    double? ultimaLongitude,
    DateTime? ultimaAtualizacaoLocalizacao,
  }) {
    final novosPassageiros = passageiros ?? this.passageiros;
    final novosPassageirosIds =
        passageirosIds ??
        ((passageiros != null &&
                (passageiros.isNotEmpty || this.passageiros.isNotEmpty))
            ? passageiros.map((p) => p.pacienteId).toList()
            : this.passageirosIds);

    return ViagemModel(
      id: id ?? this.id,
      motoristaId: motoristaId ?? this.motoristaId,
      motoristaNome: motoristaNome ?? this.motoristaNome,
      veiculoId: veiculoId ?? this.veiculoId,
      veiculoPlaca: veiculoPlaca ?? this.veiculoPlaca,
      veiculoModelo: veiculoModelo ?? this.veiculoModelo,
      kmInicial: kmInicial ?? this.kmInicial,
      cidadeDestino: cidadeDestino ?? this.cidadeDestino,
      dataHoraInicio: dataHoraInicio ?? this.dataHoraInicio,
      status: status ?? this.status,
      kmFinal: kmFinal ?? this.kmFinal,
      kmRodado: kmRodado ?? this.kmRodado,
      dataHoraFim: dataHoraFim ?? this.dataHoraFim,
      observacoes: observacoes ?? this.observacoes,
      passageirosIds: novosPassageirosIds,
      sessaoId: removerSessaoId ? null : (sessaoId ?? this.sessaoId),
      codigosAcesso: codigosAcesso ?? this.codigosAcesso,
      codigosHash: codigosHash ?? this.codigosHash,
      nomeHorario: nomeHorario ?? this.nomeHorario,
      dataViagem: dataViagem ?? this.dataViagem,
      passageiros: novosPassageiros,
      ultimaLatitude: ultimaLatitude ?? this.ultimaLatitude,
      ultimaLongitude: ultimaLongitude ?? this.ultimaLongitude,
      ultimaAtualizacaoLocalizacao:
          ultimaAtualizacaoLocalizacao ?? this.ultimaAtualizacaoLocalizacao,
    );
  }
}
