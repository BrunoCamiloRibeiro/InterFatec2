import 'firestore_parse_utils.dart';

/// Modelo imutável com os dados operacionais e cadastrais de um motorista.
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
  final String? senha;

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
    this.senha,
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
      if (senha != null && senha!.isNotEmpty) 'senha': senha,
    };
  }

  // Ler do Firebase
  factory MotoristaModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final capRaw = map['capacidadeVeiculo'];
    final int capInt = (capRaw is num)
        ? capRaw.toInt()
        : (int.tryParse(capRaw?.toString() ?? '') ?? 4);

    return MotoristaModel(
      id: docId ?? '',
      nome: (map['nome'] ?? '').toString(),
      cpf: (map['cpf'] ?? '').toString(),
      telefone: (map['telefone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      cnh: (map['cnh'] ?? '').toString(),
      veiculoModelo: (map['veiculoModelo'] ?? '').toString(),
      veiculoPlaca: (map['veiculoPlaca'] ?? '').toString(),
      capacidadeVeiculo: capInt,
      emViagem: map['emViagem'] == true || map['emViagem'] == 'true',
      role: (map['role'] ?? 'motorista').toString(),
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      criadoEm: parsearDataFirestore(map['criadoEm']),
      senha: map['senha']?.toString(),
    );
  }
}
