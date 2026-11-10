// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/passageiro_viagem_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula as informações operacionais de um passageiro individual
// vinculado a uma viagem específica (Horário do dia), incluindo referências ao
// paciente titular, acompanhante opcional, local de embarque/origem, destino,
// horário do atendimento médico/consulta, ordem de coleta na rota, observações
// e status de embarque em tempo real.
//
// PARA QUE SERVE NO PROJETO:
// Atende à FASE 1 do sistema TransSaúde (Gerenciador e CRUD de Viagens/Horários).
// Permite que a gestão municipal dimensione a lotação dos veículos por assento,
// planeje o itinerário de embarques ordenados e vincule acompanhantes a pacientes
// já cadastrados sem necessidade de recadastramento ou duplicação de dados.
//
// ONDE É USADO NO PROJETO:
// - lib/models/viagem_model.dart (contido na lista de passageiros de ViagemModel)
// - lib/services/viagem_service.dart (gestão de passageiros por viagem)
// - lib/screens/gerenciador_viagens_screen.dart (UI de agendamento e gerenciamento)
//
// DE ONDE RECEBE DADOS:
// Documentos NoSQL da coleção 'viagens' do Cloud Firestore (campo 'passageiros')
// e formulários do Gerenciador de Horários do Dia.
//
// O QUE EXPORTA / EXPÕE:
// - class PassageiroViagemModel: Modelo imutável de passageiro vinculado à viagem.
// ============================================================================

import 'package:flutter/foundation.dart';

import 'janela_reversao_model.dart';

/// Modelo de dados representativo de um passageiro agendado em um Horário de viagem.
@immutable
class PassageiroViagemModel {
  /// Identificador único do paciente (referência ao documento na coleção 'usuarios')
  final String pacienteId;

  /// Nome completo do paciente titular (cache visual para relatórios e listas)
  final String pacienteNome;

  /// CPF do paciente titular (opcional/cache)
  final String? pacienteCpf;

  /// Telefone de contato do paciente (opcional/cache operacional)
  final String? pacienteTelefone;

  /// Identificador do acompanhante (se cadastrado) ou nulo caso não haja
  final String? acompanhanteId;

  /// Nome completo do acompanhante
  final String? acompanhanteNome;

  /// Telefone do acompanhante para contato emergencial
  final String? acompanhanteTelefone;

  /// Ponto de partida / embarque (ex.: "UBS Poloni", "Residência")
  final String localOrigem;

  /// Destino específico para onde o paciente se deslocará (ex.: "Hospital de Base")
  final String localDestino;

  /// Horário agendado do atendimento médico / exame (ex.: "08:00")
  final String horarioAtendimento;

  /// Sequência de embarque do passageiro no itinerário de coleta (1, 2, 3...)
  final int ordemEmbarque;

  /// Observações clínicas ou logísticas (ex.: "Cadeirante", "Jejum", "Prioritário")
  final String? observacoes;

  /// Status atual do ciclo de transporte (0=Aguardando, 1=Embarcou, etc.)
  final int statusEmbarque;

  /// Indica se o paciente já sinalizou prontidão para o retorno nesta viagem.
  final bool prontoRetorno;

  /// Janela temporária de reversão vinculada especificamente a esta viagem.
  final JanelaReversaoModel? janelaReversao;

  /// Construtor constante imutável
  const PassageiroViagemModel({
    required this.pacienteId,
    required this.pacienteNome,
    this.pacienteCpf,
    this.pacienteTelefone,
    this.acompanhanteId,
    this.acompanhanteNome,
    this.acompanhanteTelefone,
    this.localOrigem = 'UBS Poloni',
    required this.localDestino,
    this.horarioAtendimento = '',
    this.ordemEmbarque = 1,
    this.observacoes,
    this.statusEmbarque = 0,
    this.prontoRetorno = false,
    this.janelaReversao,
  });

  /// Converte a instância para mapa compatível com persistência no Cloud Firestore
  Map<String, dynamic> toMap() {
    return {
      'pacienteId': pacienteId,
      'pacienteNome': pacienteNome,
      if (pacienteCpf != null) 'pacienteCpf': pacienteCpf,
      if (pacienteTelefone != null) 'pacienteTelefone': pacienteTelefone,
      if (acompanhanteId != null) 'acompanhanteId': acompanhanteId,
      if (acompanhanteNome != null) 'acompanhanteNome': acompanhanteNome,
      if (acompanhanteTelefone != null)
        'acompanhanteTelefone': acompanhanteTelefone,
      'localOrigem': localOrigem,
      'localDestino': localDestino,
      'horarioAtendimento': horarioAtendimento,
      'ordemEmbarque': ordemEmbarque,
      if (observacoes != null) 'observacoes': observacoes,
      'statusEmbarque': statusEmbarque,
      if (prontoRetorno) 'prontoRetorno': prontoRetorno,
      if (janelaReversao != null) 'janelaReversao': janelaReversao!.toMap(),
    };
  }

  /// Reconstrói uma instância de [PassageiroViagemModel] a partir de dados serializados
  factory PassageiroViagemModel.fromMap(Map<String, dynamic> map) {
    final janelaRaw = map['janelaReversao'];
    return PassageiroViagemModel(
      pacienteId: map['pacienteId']?.toString() ?? '',
      pacienteNome: map['pacienteNome']?.toString() ?? 'Paciente sem nome',
      pacienteCpf: map['pacienteCpf']?.toString(),
      pacienteTelefone: map['pacienteTelefone']?.toString(),
      acompanhanteId: map['acompanhanteId']?.toString(),
      acompanhanteNome: map['acompanhanteNome']?.toString(),
      acompanhanteTelefone: map['acompanhanteTelefone']?.toString(),
      localOrigem: map['localOrigem']?.toString() ?? 'UBS Poloni',
      localDestino: map['localDestino']?.toString() ?? '',
      horarioAtendimento: map['horarioAtendimento']?.toString() ?? '',
      ordemEmbarque: (map['ordemEmbarque'] is num)
          ? (map['ordemEmbarque'] as num).toInt()
          : 1,
      observacoes: map['observacoes']?.toString(),
      statusEmbarque: (map['statusEmbarque'] is num)
          ? (map['statusEmbarque'] as num).toInt()
          : 0,
      prontoRetorno: map['prontoRetorno'] == true,
      janelaReversao: janelaRaw is Map
          ? JanelaReversaoModel.fromMap(Map<String, dynamic>.from(janelaRaw))
          : null,
    );
  }

  /// Quantidade de assentos ocupados por este registro (1 se individual, 2 com acompanhante)
  int get assentosOcupados => (acompanhanteNome != null && acompanhanteNome!.trim().isNotEmpty) ? 2 : 1;

  /// Cria uma cópia com campos atualizados mantendo a imutabilidade
  PassageiroViagemModel copyWith({
    String? pacienteId,
    String? pacienteNome,
    String? pacienteCpf,
    String? pacienteTelefone,
    String? acompanhanteId,
    String? acompanhanteNome,
    String? acompanhanteTelefone,
    String? localOrigem,
    String? localDestino,
    String? horarioAtendimento,
    int? ordemEmbarque,
    String? observacoes,
    int? statusEmbarque,
    bool? prontoRetorno,
    JanelaReversaoModel? janelaReversao,
    bool limparJanelaReversao = false,
  }) {
    return PassageiroViagemModel(
      pacienteId: pacienteId ?? this.pacienteId,
      pacienteNome: pacienteNome ?? this.pacienteNome,
      pacienteCpf: pacienteCpf ?? this.pacienteCpf,
      pacienteTelefone: pacienteTelefone ?? this.pacienteTelefone,
      acompanhanteId: acompanhanteId ?? this.acompanhanteId,
      acompanhanteNome: acompanhanteNome ?? this.acompanhanteNome,
      acompanhanteTelefone: acompanhanteTelefone ?? this.acompanhanteTelefone,
      localOrigem: localOrigem ?? this.localOrigem,
      localDestino: localDestino ?? this.localDestino,
      horarioAtendimento: horarioAtendimento ?? this.horarioAtendimento,
      ordemEmbarque: ordemEmbarque ?? this.ordemEmbarque,
      observacoes: observacoes ?? this.observacoes,
      statusEmbarque: statusEmbarque ?? this.statusEmbarque,
      prontoRetorno: prontoRetorno ?? this.prontoRetorno,
      janelaReversao:
          limparJanelaReversao ? null : (janelaReversao ?? this.janelaReversao),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PassageiroViagemModel &&
        other.pacienteId == pacienteId &&
        other.ordemEmbarque == ordemEmbarque &&
        other.statusEmbarque == statusEmbarque &&
        other.prontoRetorno == prontoRetorno;
  }

  @override
  int get hashCode =>
      pacienteId.hashCode ^
      ordemEmbarque.hashCode ^
      statusEmbarque.hashCode ^
      prontoRetorno.hashCode;
}
