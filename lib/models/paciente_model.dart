import 'package:flutter/material.dart';

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

  // Mapeamento centralizado de status numérico para texto, cor e ícone em todo o app
  static (String texto, Color cor, IconData icone) dadosStatus(int status) {
    return switch (status) {
      0 => (
        'Aguardando Transporte',
        const Color(0xFF2563EB),
        Icons.schedule_outlined,
      ),
      1 => (
        'Embarcou para Ida',
        const Color(0xFF1D4ED8),
        Icons.near_me_outlined,
      ),
      2 => (
        'Desembarcou para Consulta',
        const Color(0xFFD97706),
        Icons.exit_to_app,
      ),
      3 => (
        'Reembarcou para Volta',
        const Color(0xFF4338CA),
        Icons.reply_outlined,
      ),
      4 => ('Concluído', const Color(0xFF16A34A), Icons.check_outlined),
      5 => ('Cancelado', const Color(0xFFB83227), Icons.cancel),
      _ => ('Pendente', Colors.grey, Icons.help),
    };
  }

  // Getters utilitários para acesso rápido na instância do paciente
  String get textoStatus => dadosStatus(status).$1;
  Color get corStatus => dadosStatus(status).$2;
  IconData get iconeStatus => dadosStatus(status).$3;

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
