class MotoristaModel {
  final String id;
  final String nome;
  final String cpf;
  final String telefone;
  final String email;
  final String cnh;
  final String veiculoModelo;
  final String veiculoPlaca;
  final int capacidadeVeiculo;
  final bool emViagem;
  final String role;
  final bool ativo;
  final DateTime? criadoEm;

  MotoristaModel({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.telefone,
    required this.email,
    required this.cnh,
    required this.veiculoModelo,
    required this.veiculoPlaca,
    this.capacidadeVeiculo = 4,
    this.emViagem = false,
    this.role = 'motorista',
    this.ativo = true,
    this.criadoEm,
  });

  // Salvar no Firebase
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cpf': cpf,
      'telefone': telefone,
      'email': email,
      'cnh': cnh,
      'veiculoModelo': veiculoModelo,
      'veiculoPlaca': veiculoPlaca,
      'capacidadeVeiculo': capacidadeVeiculo,
      'emViagem': emViagem,
      'role': role,
      'ativo': ativo,
      'criadoEm': criadoEm?.toIso8601String(),
    };
  }

  // Ler do Firebase
  factory MotoristaModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return MotoristaModel(
      id: docId ?? '',
      nome: map['nome'] ?? '',
      cpf: map['cpf'] ?? '',
      telefone: map['telefone'] ?? '',
      email: map['email'] ?? '',
      cnh: map['cnh'] ?? '',
      veiculoModelo: map['veiculoModelo'] ?? '',
      veiculoPlaca: map['veiculoPlaca'] ?? '',
      capacidadeVeiculo: map['capacidadeVeiculo'] ?? 4,
      emViagem: map['emViagem'] ?? false,
      role: map['role'] ?? 'motorista',
      ativo: map['ativo'] ?? true,
      criadoEm: map['criadoEm'] != null
          ? DateTime.tryParse(map['criadoEm'].toString())
          : null,
    );
  }
}
