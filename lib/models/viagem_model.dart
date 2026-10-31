// Estados possíveis do ciclo de vida da viagem do motorista
enum EstadoViagem {
  // Motorista autenticado sem viagem ativa vinculada
  semViagem,
  // Formulário de início de viagem em exibição para preenchimento
  preenchendoFormulario,
  // Viagem em andamento com veículo selecionado e lista de passageiros liberada
  viagemAtiva,
  // Viagem concluída com dados finais registrados
  encerrada,
}

// Modelo de dados para armazenar informações de uma viagem realizada pelo motorista
class ViagemModel {
  // Identificador único da viagem
  final String id;
  // Identificador do motorista responsável
  final String motoristaId;
  // Nome do motorista responsável
  final String motoristaNome;
  // Identificador do veículo utilizado
  final String veiculoId;
  // Placa do veículo utilizado
  final String veiculoPlaca;
  // Modelo do veículo utilizado
  final String veiculoModelo;
  // Quilometragem do veículo no início da viagem
  final int kmInicial;
  // Município de destino da viagem
  final String cidadeDestino;
  // Data e hora de início da viagem
  final DateTime dataHoraInicio;
  // Situação da viagem ('ativa' ou 'encerrada')
  final String status;

  // Quilometragem do veículo no encerramento da viagem
  final int? kmFinal;
  // Total de quilômetros percorridos durante a viagem
  final int? kmRodado;
  // Data e hora de encerramento da viagem
  final DateTime? dataHoraFim;
  // Anotações adicionais sobre a viagem
  final String? observacoes;
  // Identificadores dos passageiros vinculados à viagem
  final List<String> passageirosIds;

  // Construtor com os parâmetros de inicialização da viagem
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
  });

  // Converte os dados da viagem para uma estrutura Map de chave e valor
  Map<String, dynamic> toMap() {
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
      'dataHoraFim': dataHoraFim?.toIso8601String(),
      'observacoes': observacoes,
      'passageirosIds': passageirosIds,
    };
  }

  // Constrói uma instância de ViagemModel a partir de um Map de dados
  factory ViagemModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ViagemModel(
      id: docId ?? map['id'] ?? '',
      motoristaId: map['motoristaId'] ?? '',
      motoristaNome: map['motoristaNome'] ?? '',
      veiculoId: map['veiculoId'] ?? '',
      veiculoPlaca: map['veiculoPlaca'] ?? '',
      veiculoModelo: map['veiculoModelo'] ?? '',
      kmInicial: (map['kmInicial'] is num)
          ? (map['kmInicial'] as num).toInt()
          : 0,
      cidadeDestino: map['cidadeDestino'] ?? '',
      dataHoraInicio: map['dataHoraInicio'] != null
          ? DateTime.tryParse(map['dataHoraInicio'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      status: map['status'] ?? 'ativa',
      kmFinal: (map['kmFinal'] is num) ? (map['kmFinal'] as num).toInt() : null,
      kmRodado: (map['kmRodado'] is num)
          ? (map['kmRodado'] as num).toInt()
          : null,
      dataHoraFim: map['dataHoraFim'] != null
          ? DateTime.tryParse(map['dataHoraFim'].toString())
          : null,
      observacoes: map['observacoes'],
      passageirosIds: (map['passageirosIds'] is List)
          ? List<String>.from(map['passageirosIds'])
          : const [],
    );
  }

  // Cria uma nova instância de ViagemModel copiando os campos existentes e substituindo os informados
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
  }) {
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
      passageirosIds: passageirosIds ?? this.passageirosIds,
    );
  }
}
