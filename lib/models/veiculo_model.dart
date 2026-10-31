// Modelo de dados para representar um veículo da frota municipal de saúde.
// Armazena identificação, modelo, placa, capacidade e a quilometragem atual/última registrada.
class VeiculoModel {
  // Identificador único do documento do veículo
  final String id;
  // Placa de identificação do veículo
  final String placa;
  // Nome e especificação de modelo do veículo
  final String modelo;
  // Capacidade total de passageiros suportada
  final int capacidade;
  // Quilometragem atual ou última registrada do veículo
  final int quilometragemAtual;
  // Indicador se o veículo está associado a uma viagem ativa
  final bool emUso;
  // Identificador do motorista atualmente associado ao veículo
  final String? motoristaAtualId;

  // Construtor com os parâmetros de inicialização do veículo
  const VeiculoModel({
    required this.id,
    required this.placa,
    required this.modelo,
    this.capacidade = 4,
    required this.quilometragemAtual,
    this.emUso = false,
    this.motoristaAtualId,
  });

  // Converte a instância para um Map de pares chave e valor
  Map<String, dynamic> toMap() {
    return {
      'placa': placa,
      'modelo': modelo,
      'capacidade': capacidade,
      'quilometragemAtual': quilometragemAtual,
      'emUso': emUso,
      'motoristaAtualId': motoristaAtualId,
    };
  }

  // Cria uma instância de VeiculoModel a partir de um Map de dados
  factory VeiculoModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return VeiculoModel(
      id: docId ?? map['id'] ?? '',
      placa: map['placa'] ?? '',
      modelo: map['modelo'] ?? '',
      capacidade: (map['capacidade'] is num)
          ? (map['capacidade'] as num).toInt()
          : 4,
      quilometragemAtual: (map['quilometragemAtual'] is num)
          ? (map['quilometragemAtual'] as num).toInt()
          : 0,
      emUso: map['emUso'] ?? false,
      motoristaAtualId: map['motoristaAtualId'],
    );
  }

  // Cria uma nova instância de VeiculoModel copiando os campos existentes e substituindo os informados
  VeiculoModel copyWith({
    String? id,
    String? placa,
    String? modelo,
    int? capacidade,
    int? quilometragemAtual,
    bool? emUso,
    String? motoristaAtualId,
  }) {
    return VeiculoModel(
      id: id ?? this.id,
      placa: placa ?? this.placa,
      modelo: modelo ?? this.modelo,
      capacidade: capacidade ?? this.capacidade,
      quilometragemAtual: quilometragemAtual ?? this.quilometragemAtual,
      emUso: emUso ?? this.emUso,
      motoristaAtualId: motoristaAtualId ?? this.motoristaAtualId,
    );
  }

  // Compara se dois objetos VeiculoModel possuem o mesmo identificador e mesma placa
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VeiculoModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          placa == other.placa;

  // Retorna o valor de hash code gerado a partir do id e da placa
  @override
  int get hashCode => id.hashCode ^ placa.hashCode;
}
