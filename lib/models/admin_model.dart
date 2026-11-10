import 'firestore_parse_utils.dart';

/// Modelo imutável com os dados cadastrais de um administrador no Firestore.
class AdminModel {
  final String id;
  final String nome;
  final String cpf;
  final String email;
  final String telefone;
  final String role;
  final bool ativo;
  final DateTime? criadoEm;
  final String? senha;

  AdminModel({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.email,
    required this.telefone,
    this.role = 'admin',
    this.ativo = true,
    this.criadoEm,
    this.senha,
  });

  // Salvar no Firebase
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cpf': cpf,
      'email': email,
      'telefone': telefone,
      'role': role,
      'ativo': ativo,
      'criadoEm': criadoEm?.toIso8601String(),
      if (senha != null && senha!.isNotEmpty) 'senha': senha,
    };
  }

  // Ler do Firebase
  factory AdminModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AdminModel(
      id: docId ?? '',
      nome: (map['nome'] ?? '').toString(),
      cpf: (map['cpf'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      telefone: (map['telefone'] ?? '').toString(),
      role: (map['role'] ?? 'admin').toString(),
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      criadoEm: parsearDataFirestore(map['criadoEm']),
      senha: map['senha']?.toString(),
    );
  }
}
