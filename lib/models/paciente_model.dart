class PacienteModel {
  final String id;
  final String nome;
  final String cpf;
  final String telefone;
  final String enderecoPaciente;
  final String localConsulta;
  final String localSaida;
  final String horarioConsulta;
  final int status;
  final String? nomeAcompanhante;
  final String? telAcompanhante;
  final String role;
  final bool ativo;
  final DateTime? criadoEm;

  PacienteModel({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.telefone,
    required this.enderecoPaciente,
    required this.localConsulta,
    this.localSaida = '',
    this.horarioConsulta = '',
    this.status = 0,
    this.nomeAcompanhante,
    this.telAcompanhante,
    this.role = 'paciente',
    this.ativo = true,
    this.criadoEm,
  });

  // Salvar no Firebase
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cpf': cpf,
      'telefone': telefone,
      'enderecoPaciente': enderecoPaciente,
      'localConsulta': localConsulta,
      'localSaida': localSaida,
      'horarioConsulta': horarioConsulta,
      'status': status,
      'nomeAcompanhante': nomeAcompanhante,
      'telAcompanhante': telAcompanhante,
      'role': role,
      'ativo': ativo,
      'criadoEm': criadoEm?.toIso8601String(),
    };
  }

  // Ler do Firebase
  factory PacienteModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return PacienteModel(
      id: docId ?? '',
      nome: map['nome'] ?? '',
      cpf: map['cpf'] ?? '',
      telefone: map['telefone'] ?? '',
      enderecoPaciente: map['enderecoPaciente'] ?? '',
      localConsulta: map['localConsulta'] ?? '',
      localSaida: map['localSaida'] ?? 'Residência',
      horarioConsulta: map['horarioConsulta'] ?? '',
      status: map['status'] ?? 0,
      nomeAcompanhante: map['nomeAcompanhante'],
      telAcompanhante: map['telAcompanhante'],
      role: map['role'] ?? 'paciente',
      ativo: map['ativo'] ?? true,
      criadoEm: map['criadoEm'] != null
          ? DateTime.tryParse(map['criadoEm'].toString())
          : null,
    );
  }
}
