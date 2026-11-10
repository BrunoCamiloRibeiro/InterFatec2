import 'package:flutter/material.dart';

import 'firestore_parse_utils.dart';
import 'janela_reversao_model.dart';

/// Modelo imutável de um paciente TFD e seu ciclo de status na viagem.
class PacienteModel {
  final String id;
  final String nome;
  final String cpf;
  final String telefone;
  final String enderecoPaciente;
  final String localConsulta;
  final String localSaida;
  final String horarioConsulta;

  /// Código de status na viagem:
  /// 0 = Aguardando Transporte, 1 = Embarcou Ida, 2 = Desembarcou Consulta,
  /// 3 = Reembarcou Volta, 4 = Concluído, 5 = Cancelado.
  final int status;

  final String? nomeAcompanhante;
  final String? telAcompanhante;
  final String? cpfAcompanhante;
  final String? rg;
  final String? cnh;
  final String role;
  final bool ativo;
  final DateTime? criadoEm;
  final bool prontoRetorno;
  final JanelaReversaoModel? janelaReversao;
  final String? ultimaIdempotencyKey;

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
    this.cpfAcompanhante,
    this.rg,
    this.cnh,
    this.role = 'paciente',
    this.ativo = true,
    this.criadoEm,
    this.prontoRetorno = false,
    this.janelaReversao,
    this.ultimaIdempotencyKey,
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
      'cpfAcompanhante': cpfAcompanhante,
      'rg': rg,
      'cnh': cnh,
      'role': role,
      'ativo': ativo,
      'criadoEm': criadoEm?.toIso8601String(),
      'prontoRetorno': prontoRetorno,
      if (janelaReversao != null) 'janelaReversao': janelaReversao!.toMap(),
      if (ultimaIdempotencyKey != null) 'ultimaIdempotencyKey': ultimaIdempotencyKey,
    };
  }

  // Ler do Firebase
  factory PacienteModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final statusRaw = map['status'];
    final int statusInt = (statusRaw is num)
        ? statusRaw.toInt()
        : (int.tryParse(statusRaw?.toString() ?? '') ?? 0);

    // Suporta acompanhante em objeto aninhado ou em campos planos
    String? nomeAcomp = map['nomeAcompanhante']?.toString();
    String? telAcomp = map['telAcompanhante']?.toString();
    if (map['acompanhante'] is Map) {
      final acompMap = map['acompanhante'] as Map;
      nomeAcomp ??= acompMap['nome']?.toString();
      telAcomp ??= acompMap['telefone']?.toString();
    }

    return PacienteModel(
      id: (docId != null && docId.isNotEmpty) ? docId : (map['id']?.toString() ?? ''),
      nome: (map['nome'] ?? '').toString(),
      cpf: (map['cpf'] ?? '').toString(),
      telefone: (map['telefone'] ?? '').toString(),
      enderecoPaciente: (map['enderecoPaciente'] ?? map['localEmbarque'] ?? '').toString(),
      localConsulta: (map['localConsulta'] ?? '').toString(),
      localSaida: (map['localEmbarque'] ?? map['localSaida'] ?? 'Residência').toString(),
      horarioConsulta: (map['horarioPrevisto'] ?? map['horarioConsulta'] ?? '').toString(),
      status: statusInt,
      nomeAcompanhante: nomeAcomp,
      telAcompanhante: telAcomp ?? map['telAcompanhante']?.toString(),
      cpfAcompanhante: map['cpfAcompanhante']?.toString(),
      rg: map['rg']?.toString(),
      cnh: map['cnh']?.toString(),
      role: (map['role'] ?? 'paciente').toString(),
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      criadoEm: parsearDataFirestore(map['criadoEm']),
      prontoRetorno: map['prontoRetorno'] == true || map['prontoRetorno'] == 'true',
      janelaReversao: map['janelaReversao'] is Map<String, dynamic>
          ? JanelaReversaoModel.fromMap(map['janelaReversao'] as Map<String, dynamic>)
          : (map['janelaReversao'] is Map
              ? JanelaReversaoModel.fromMap(
                  Map<String, dynamic>.from(map['janelaReversao'] as Map))
              : null),
      ultimaIdempotencyKey: map['ultimaIdempotencyKey']?.toString(),
    );
  }

  /// Cria uma cópia imutável com campos substituídos.
  PacienteModel copyWith({
    String? id,
    String? nome,
    String? cpf,
    String? telefone,
    String? enderecoPaciente,
    String? localConsulta,
    String? localSaida,
    String? horarioConsulta,
    int? status,
    String? nomeAcompanhante,
    String? telAcompanhante,
    String? role,
    bool? ativo,
    DateTime? criadoEm,
    bool? prontoRetorno,
    JanelaReversaoModel? janelaReversao,
    bool limparJanelaReversao = false,
    String? ultimaIdempotencyKey,
  }) {
    return PacienteModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      cpf: cpf ?? this.cpf,
      telefone: telefone ?? this.telefone,
      enderecoPaciente: enderecoPaciente ?? this.enderecoPaciente,
      localConsulta: localConsulta ?? this.localConsulta,
      localSaida: localSaida ?? this.localSaida,
      horarioConsulta: horarioConsulta ?? this.horarioConsulta,
      status: status ?? this.status,
      nomeAcompanhante: nomeAcompanhante ?? this.nomeAcompanhante,
      telAcompanhante: telAcompanhante ?? this.telAcompanhante,
      role: role ?? this.role,
      ativo: ativo ?? this.ativo,
      criadoEm: criadoEm ?? this.criadoEm,
      prontoRetorno: prontoRetorno ?? this.prontoRetorno,
      janelaReversao: limparJanelaReversao ? null : (janelaReversao ?? this.janelaReversao),
      ultimaIdempotencyKey: ultimaIdempotencyKey ?? this.ultimaIdempotencyKey,
    );
  }
}
