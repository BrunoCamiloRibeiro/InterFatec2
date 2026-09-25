class MotoristaModel {
  final String nome;
  final String veiculo;
  final String placa;
  final String tempoEstimado;
  final String status;
  final String titulo;
  MotoristaModel({
    required this.nome,
    required this.veiculo,
    required this.placa,
    required this.tempoEstimado,
    required this.status,
    required this.titulo,
  });
 
 
  factory MotoristaModel.fromJson(Map<String, dynamic> json) {
    return MotoristaModel(
      nome: json['nome'] ?? '',
      veiculo: json['veiculo'] ?? '',
      placa: json['placa'] ?? '',
      tempoEstimado: json['tempoEstimado'] ?? '',
      status: json['status'] ?? 'EM TRÂNSITO',
      titulo: json['titulo'] ?? 'Seu Transporte',
    );
  }
  String get infoVeiculoCompleta => '$veiculo • Placa: $placa';
}