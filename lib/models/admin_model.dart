class AdminModel {
  final String id;
  final String nome;
  final String cpf;
  final String email;
  final String telefone;
  final String role;
  final bool ativo;
  final DateTime? criadoEm;

  AdminModel({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.email,
    required this.telefone,
    this.role = 'admin',
    this.ativo = true,
    this.criadoEm,
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
    };
  }

  // Ler do Firebase
  factory AdminModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AdminModel(
      id: docId ?? '',
      nome: map['nome'] ?? '',
      cpf: map['cpf'] ?? '',
      email: map['email'] ?? '',
      telefone: map['telefone'] ?? '',
      role: map['role'] ?? 'admin',
      ativo: map['ativo'] ?? true,
      criadoEm: map['criadoEm'] != null
          ? DateTime.tryParse(map['criadoEm'].toString())
          : null,
    );
  }
}
