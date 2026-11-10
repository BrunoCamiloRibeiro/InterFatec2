// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/janela_reversao_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula os dados de uma Janela de Reversão (Undo Window)
// temporária para ações executadas pelo paciente (desistência de carona ou
// prontidão de retorno após consulta médica), atendendo aos requisitos da Issue #19.
//
// PARA QUE SERVE NO PROJETO:
// Permite que o paciente reverta uma ação acidental em até 5 minutos (300 s)
// no caso de cancelamento/carona ou em até 1 minuto (60 s) no caso de pronto
// de consulta. Armazena timestamps estritos baseados em UTC/relógio do servidor
// para validação segura anti-fraude e controle de concorrência com o motorista.
//
// ONDE É USADO NO PROJETO:
// - lib/models/paciente_model.dart (propriedade janelaReversao)
// - lib/services/transicao_paciente_service.dart (regras puras de transição)
// - lib/services/paciente_sync_service.dart (sincronização atômica no Firestore)
// - lib/components/banner_reversao_paciente.dart (barra de contagem regressiva)
// - test/services/transicao_paciente_service_test.dart
//
// DE ONDE RECEBE DADOS:
// Mapas serializados no Cloud Firestore dentro do documento do paciente
// ou instâncias construídas localmente pelo serviço de transição.
//
// O QUE EXPORTA / EXPÕE:
// - class JanelaReversaoModel
//   * acao (String: 'cancelamento_carona' ou 'pronto_retorno')
//   * iniciadoEm (DateTime em UTC)
//   * expiraEm (DateTime em UTC)
//   * estadoAnterior (int)
//   * idempotencyKey (String?)
//   * estaAtiva({DateTime? agora}) -> bool
//   * tempoRestante({DateTime? agora}) -> Duration
//   * toMap() e factory fromMap(...)
//   * copyWith(...)
// ============================================================================

import 'package:flutter/foundation.dart';

import 'firestore_parse_utils.dart';

/// Modelo imutável que representa uma janela de reversão ativa de ação do paciente.
@immutable
class JanelaReversaoModel {
  /// Identificador textual da ação passível de reversão:
  /// - 'cancelamento_carona': desistência / pegou carona (janela de 300 s / 5 min).
  /// - 'pronto_retorno': consulta médica finalizada (janela de 60 s / 1 min).
  final String acao;

  /// Momento exato em que a ação foi registrada (em UTC).
  final DateTime iniciadoEm;

  /// Momento em que a janela de reversão expira no servidor (em UTC).
  final DateTime expiraEm;

  /// Status numérico anterior do paciente (ex.: 0 para Aguardando, 2 para Na Consulta).
  final int estadoAnterior;

  /// Chave de idempotência única associada ao disparo original da ação.
  final String? idempotencyKey;

  /// Construtor principal da classe JanelaReversaoModel.
  const JanelaReversaoModel({
    required this.acao,
    required this.iniciadoEm,
    required this.expiraEm,
    required this.estadoAnterior,
    this.idempotencyKey,
  });

  /// Verifica se a janela de reversão ainda está ativa e válida temporalmente.
  /// Aceita parâmetro opcional [agora] para injeção de relógio em testes determinísticos.
  bool estaAtiva({DateTime? agora}) {
    final momentoAtual = (agora ?? DateTime.now()).toUtc();
    return momentoAtual.isBefore(expiraEm);
  }

  /// Retorna a duração restante da janela de reversão até a expiração.
  /// Retorna [Duration.zero] caso a janela já tenha expirado.
  Duration tempoRestante({DateTime? agora}) {
    final momentoAtual = (agora ?? DateTime.now()).toUtc();
    final diferenca = expiraEm.difference(momentoAtual);
    return diferenca.isNegative ? Duration.zero : diferenca;
  }

  /// Converte a instância para um mapa serializável no Firestore.
  Map<String, dynamic> toMap() {
    return {
      'acao': acao,
      'iniciadoEm': iniciadoEm.toIso8601String(),
      'expiraEm': expiraEm.toIso8601String(),
      'estadoAnterior': estadoAnterior,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
  }

  /// Reconstrói uma instância de JanelaReversaoModel a partir de um Map NoSQL do Firestore.
  factory JanelaReversaoModel.fromMap(Map<String, dynamic> map) {
    final iniciado =
        parsearDataFirestore(map['iniciadoEm'], emUtc: true) ?? DateTime.now().toUtc();
    final expira = parsearDataFirestore(map['expiraEm'], emUtc: true) ??
        iniciado.add(const Duration(minutes: 5));

    final estadoAntRaw = map['estadoAnterior'];
    final int estadoAnt = (estadoAntRaw is num)
        ? estadoAntRaw.toInt()
        : (int.tryParse(estadoAntRaw?.toString() ?? '') ?? 0);

    return JanelaReversaoModel(
      acao: (map['acao'] ?? 'cancelamento_carona').toString(),
      iniciadoEm: iniciado,
      expiraEm: expira,
      estadoAnterior: estadoAnt,
      idempotencyKey: map['idempotencyKey']?.toString(),
    );
  }

  /// Cria uma cópia imutável com campos substituídos.
  JanelaReversaoModel copyWith({
    String? acao,
    DateTime? iniciadoEm,
    DateTime? expiraEm,
    int? estadoAnterior,
    String? idempotencyKey,
  }) {
    return JanelaReversaoModel(
      acao: acao ?? this.acao,
      iniciadoEm: iniciadoEm ?? this.iniciadoEm,
      expiraEm: expiraEm ?? this.expiraEm,
      estadoAnterior: estadoAnterior ?? this.estadoAnterior,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JanelaReversaoModel &&
        other.acao == acao &&
        other.iniciadoEm == iniciadoEm &&
        other.expiraEm == expiraEm &&
        other.estadoAnterior == estadoAnterior &&
        other.idempotencyKey == idempotencyKey;
  }

  @override
  int get hashCode => Object.hash(
        acao,
        iniciadoEm,
        expiraEm,
        estadoAnterior,
        idempotencyKey,
      );
}
