import 'package:flutter/material.dart';

/// Enumeração fortemente tipada para o Status do Veículo com cores e estilos pré-computados
/// para evitar cálculos pesados de [Color.lerp] e alocações de cor em tempo de renderização.
enum StatusVeiculo {
  disponivel(
    valor: 'disponivel',
    label: 'Disponível',
    corBase: Colors.green,
    corFundo: Color(0x334CAF50), // Colors.green com alpha 0.2 pré-computado
    corDestaque: Color(0xFF1B5E20), // Color.lerp(Colors.green, Colors.black, 0.5)
  ),
  emViagem(
    valor: 'emViagem',
    label: 'Em Viagem',
    corBase: Colors.blue,
    corFundo: Color(0x332196F3), // Colors.blue com alpha 0.2 pré-computado
    corDestaque: Color(0xFF0D47A1), // Color.lerp(Colors.blue, Colors.black, 0.5)
  ),
  emManutencao(
    valor: 'emManutencao',
    label: 'Em Manutenção',
    corBase: Colors.orange,
    corFundo: Color(0x33FF9800), // Colors.orange com alpha 0.2 pré-computado
    corDestaque: Color(0xFFE65100), // Color.lerp(Colors.orange, Colors.black, 0.5)
  ),
  inativo(
    valor: 'inativo',
    label: 'Inativo',
    corBase: Colors.grey,
    corFundo: Color(0x339E9E9E), // Colors.grey com alpha 0.2 pré-computado
    corDestaque: Color(0xFF424242), // Color.lerp(Colors.grey, Colors.black, 0.5)
  );

  final String valor;
  final String label;
  final Color corBase;
  final Color corFundo;
  final Color corDestaque;

  const StatusVeiculo({
    required this.valor,
    required this.label,
    required this.corBase,
    required this.corFundo,
    required this.corDestaque,
  });

  static StatusVeiculo fromString(String? valor) {
    switch (valor?.toLowerCase()) {
      case 'disponivel':
        return StatusVeiculo.disponivel;
      case 'emmanutencao':
      case 'manutencao':
        return StatusVeiculo.emManutencao;
      case 'emviagem':
      case 'emuso':
        return StatusVeiculo.emViagem;
      case 'inativo':
        return StatusVeiculo.inativo;
      default:
        return StatusVeiculo.disponivel;
    }
  }
}

/// Enumeração para os tipos de veículo com ícones e rótulos
enum TipoVeiculo {
  van(
    valor: 'van',
    label: 'Van',
    icone: Icons.airport_shuttle_outlined,
  ),
  ambulancia(
    valor: 'ambulancia',
    label: 'Ambulância',
    icone: Icons.emergency_outlined,
  ),
  onibus(
    valor: 'onibus',
    label: 'Ônibus',
    icone: Icons.directions_bus_outlined,
  ),
  carro(
    valor: 'carro',
    label: 'Carro',
    icone: Icons.directions_car_outlined,
  );

  final String valor;
  final String label;
  final IconData icone;

  const TipoVeiculo({
    required this.valor,
    required this.label,
    required this.icone,
  });

  static TipoVeiculo fromString(String? valor) {
    switch (valor?.toLowerCase()) {
      case 'van':
        return TipoVeiculo.van;
      case 'ambulancia':
        return TipoVeiculo.ambulancia;
      case 'onibus':
      case 'microonibus':
        return TipoVeiculo.onibus;
      default:
        return TipoVeiculo.carro;
    }
  }
}

/// Modelo de dados imutável do Veículo
class VeiculoModel {
  final String id;
  final String placa;
  final TipoVeiculo tipo;
  final String marca;
  final String modelo;
  final int ano;
  final int qtdAssentos;
  final StatusVeiculo status;
  final int quilometragemAtual;
  final String? motoristaResponsavelId;
  final String? ultimoMotoristaId;
  final bool possuiAC;
  final bool possuiPreferencial;
  final String? observacoes;
  final String? criadoEm;
  final String? atualizadoEm;
  final String? atualizadoPor;

  const VeiculoModel({
    required this.id,
    required this.placa,
    required this.tipo,
    required this.marca,
    required this.modelo,
    required this.ano,
    required this.qtdAssentos,
    required this.status,
    required this.quilometragemAtual,
    this.motoristaResponsavelId,
    this.ultimoMotoristaId,
    this.possuiAC = false,
    this.possuiPreferencial = false,
    this.observacoes,
    this.criadoEm,
    this.atualizadoEm,
    this.atualizadoPor,
  });

  VeiculoModel copyWith({
    String? id,
    String? placa,
    TipoVeiculo? tipo,
    String? marca,
    String? modelo,
    int? ano,
    int? qtdAssentos,
    StatusVeiculo? status,
    int? quilometragemAtual,
    String? motoristaResponsavelId,
    String? ultimoMotoristaId,
    bool? possuiAC,
    bool? possuiPreferencial,
    String? observacoes,
    String? criadoEm,
    String? atualizadoEm,
    String? atualizadoPor,
  }) {
    return VeiculoModel(
      id: id ?? this.id,
      placa: placa ?? this.placa,
      tipo: tipo ?? this.tipo,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      ano: ano ?? this.ano,
      qtdAssentos: qtdAssentos ?? this.qtdAssentos,
      status: status ?? this.status,
      quilometragemAtual: quilometragemAtual ?? this.quilometragemAtual,
      motoristaResponsavelId:
          motoristaResponsavelId ?? this.motoristaResponsavelId,
      ultimoMotoristaId: ultimoMotoristaId ?? this.ultimoMotoristaId,
      possuiAC: possuiAC ?? this.possuiAC,
      possuiPreferencial: possuiPreferencial ?? this.possuiPreferencial,
      observacoes: observacoes ?? this.observacoes,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      atualizadoPor: atualizadoPor ?? this.atualizadoPor,
    );
  }

  factory VeiculoModel.fromMap(Map<String, dynamic> map) {
    return VeiculoModel(
      id: (map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      placa: (map['placa'] ?? 'SEM-PLACA').toString(),
      tipo: TipoVeiculo.fromString(map['tipo']?.toString()),
      marca: (map['marca'] ?? '').toString(),
      modelo: (map['modelo'] ?? '').toString(),
      ano: int.tryParse(map['ano']?.toString() ?? '') ?? DateTime.now().year,
      qtdAssentos: int.tryParse(map['qtdAssentos']?.toString() ?? '') ?? 0,
      status: StatusVeiculo.fromString(map['status']?.toString()),
      quilometragemAtual:
          int.tryParse(map['quilometragemAtual']?.toString() ?? '') ?? 0,
      motoristaResponsavelId: map['motoristaResponsavelId']?.toString(),
      ultimoMotoristaId: map['ultimoMotoristaId']?.toString(),
      possuiAC: map['possuiAC'] == true,
      possuiPreferencial: map['possuiPreferencial'] == true,
      observacoes: map['observacoes']?.toString(),
      criadoEm: map['criadoEm']?.toString(),
      atualizadoEm: map['atualizadoEm']?.toString(),
      atualizadoPor: map['atualizadoPor']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placa': placa,
      'tipo': tipo.valor,
      'marca': marca,
      'modelo': modelo,
      'ano': ano,
      'qtdAssentos': qtdAssentos,
      'status': status.valor,
      'quilometragemAtual': quilometragemAtual,
      'motoristaResponsavelId': motoristaResponsavelId,
      'ultimoMotoristaId': ultimoMotoristaId,
      'possuiAC': possuiAC,
      'possuiPreferencial': possuiPreferencial,
      'observacoes': observacoes,
      'criadoEm': criadoEm,
      'atualizadoEm': atualizadoEm,
      'atualizadoPor': atualizadoPor,
    };
  }
}
