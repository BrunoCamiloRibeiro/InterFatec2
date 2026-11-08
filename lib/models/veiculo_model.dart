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

/// Modelo de dados unificado do Veículo, compatível com a gestão de frotas
/// e o fluxo de viagens operacionais do transporte municipal de saúde.
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
    this.tipo = TipoVeiculo.carro,
    this.marca = '',
    this.modelo = '',
    int? ano,
    int? qtdAssentos,
    int? capacidade,
    StatusVeiculo? status,
    bool? emUso,
    this.quilometragemAtual = 0,
    this.motoristaResponsavelId,
    this.ultimoMotoristaId,
    String? motoristaAtualId,
    this.possuiAC = false,
    this.possuiPreferencial = false,
    this.observacoes,
    this.criadoEm,
    this.atualizadoEm,
    this.atualizadoPor,
  })  : ano = ano ?? 2024,
        qtdAssentos = qtdAssentos ?? capacidade ?? 4,
        status = status ??
            (emUso == true
                ? StatusVeiculo.emViagem
                : StatusVeiculo.disponivel);

  /// Alias de capacidade para compatibilidade com o serviço de viagens
  int get capacidade => qtdAssentos;

  /// Alias de status de viagem concorrente para o serviço de viagens
  bool get emUso => status == StatusVeiculo.emViagem;

  /// Alias do motorista atual condutor do veículo
  String? get motoristaAtualId => ultimoMotoristaId ?? motoristaResponsavelId;

  /// Alias da última quilometragem do hodômetro registrada
  int get ultimaKmRegistrada => quilometragemAtual;

  VeiculoModel copyWith({
    String? id,
    String? placa,
    TipoVeiculo? tipo,
    String? marca,
    String? modelo,
    int? ano,
    int? qtdAssentos,
    int? capacidade,
    StatusVeiculo? status,
    bool? emUso,
    int? quilometragemAtual,
    String? motoristaResponsavelId,
    String? ultimoMotoristaId,
    String? motoristaAtualId,
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
      qtdAssentos: qtdAssentos ?? capacidade ?? this.qtdAssentos,
      status: status ??
          (emUso != null
              ? (emUso ? StatusVeiculo.emViagem : StatusVeiculo.disponivel)
              : this.status),
      quilometragemAtual: quilometragemAtual ?? this.quilometragemAtual,
      motoristaResponsavelId:
          motoristaResponsavelId ?? this.motoristaResponsavelId,
      ultimoMotoristaId:
          ultimoMotoristaId ?? motoristaAtualId ?? this.ultimoMotoristaId,
      possuiAC: possuiAC ?? this.possuiAC,
      possuiPreferencial: possuiPreferencial ?? this.possuiPreferencial,
      observacoes: observacoes ?? this.observacoes,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      atualizadoPor: atualizadoPor ?? this.atualizadoPor,
    );
  }

  factory VeiculoModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawAssentos = map['qtdAssentos'] ?? map['capacidade'];
    final int assentos = (rawAssentos is num)
        ? rawAssentos.toInt()
        : (int.tryParse(rawAssentos?.toString() ?? '') ?? 4);

    final rawKm = map['quilometragemAtual'] ?? map['ultimaKmRegistrada'];
    final int km = (rawKm is num)
        ? rawKm.toInt()
        : (int.tryParse(rawKm?.toString() ?? '') ?? 0);

    final rawAno = map['ano'];
    final int anoInt = (rawAno is num)
        ? rawAno.toInt()
        : (int.tryParse(rawAno?.toString() ?? '') ?? DateTime.now().year);

    final rawStatus = map['status']?.toString();
    final bool rawEmUso = map['emUso'] == true || map['emUso'] == 'true';
    final StatusVeiculo statusCalculado = rawStatus != null
        ? StatusVeiculo.fromString(rawStatus)
        : (rawEmUso ? StatusVeiculo.emViagem : StatusVeiculo.disponivel);

    return VeiculoModel(
      id: (docId ?? map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      placa: (map['placa'] ?? 'SEM-PLACA').toString(),
      tipo: TipoVeiculo.fromString(map['tipo']?.toString()),
      marca: (map['marca'] ?? '').toString(),
      modelo: (map['modelo'] ?? '').toString(),
      ano: anoInt,
      qtdAssentos: assentos,
      status: statusCalculado,
      quilometragemAtual: km,
      motoristaResponsavelId: map['motoristaResponsavelId']?.toString(),
      ultimoMotoristaId:
          (map['ultimoMotoristaId'] ?? map['motoristaAtualId'])?.toString(),
      possuiAC: map['possuiAC'] == true || map['possuiAC'] == 'true',
      possuiPreferencial:
          map['possuiPreferencial'] == true || map['possuiPreferencial'] == 'true',
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
      'capacidade': qtdAssentos,
      'status': status.valor,
      'emUso': emUso,
      'quilometragemAtual': quilometragemAtual,
      'ultimaKmRegistrada': quilometragemAtual,
      'motoristaResponsavelId': motoristaResponsavelId,
      'ultimoMotoristaId': ultimoMotoristaId,
      'motoristaAtualId': motoristaAtualId,
      'possuiAC': possuiAC,
      'possuiPreferencial': possuiPreferencial,
      'observacoes': observacoes,
      'criadoEm': criadoEm,
      'atualizadoEm': atualizadoEm,
      'atualizadoPor': atualizadoPor,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VeiculoModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          placa == other.placa;

  @override
  int get hashCode => id.hashCode ^ placa.hashCode;
}
