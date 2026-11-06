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

  static DateTime? _parsearData(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    try {
      return (valor as dynamic).toDate() as DateTime;
    } catch (_) {}
    try {
      return DateTime.tryParse(valor.toString());
    } catch (_) {}
    return null;
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
      criadoEm: _parsearData(map['criadoEm']),
    );
  }
}
