// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/estado_tela_paciente.dart
// Camada: Apresentação / Máquina de Estados da View (State Pattern)
//
// O QUE ESTE ARQUIVO FAZ:
// Declara a hierarquia exaustiva de estados selados (Sealed Classes do Dart 3)
// para a tela do paciente. Substitui a proliferação de booleanos soltos por
// subtipos fortemente tipados dos quais a UI deriva seus botões, badges e
// comportamentos de forma determinística e mutuamente exclusiva.
//
// PARA QUE SERVE NO PROJETO:
// Garante por construção que ações concorrentes ou contraditórias (ex.: "Estou
// Pronto" e "Fui embora" exibidos simultaneamente durante um cancelamento)
// sejam impossíveis de ocorrer na interface gráfica.
//
// ORIGEM HISTÓRICA:
// Criado para a revisão arquitetural e coerência de estados das telas de Paciente
// e Motorista (Issue #19).
// ============================================================================

import 'package:flutter/foundation.dart';
import 'janela_reversao_model.dart';
import 'paciente_model.dart';

/// Classe base selada que representa qualquer estado possível da tela do paciente.
@immutable
sealed class EstadoTelaPaciente {
  const EstadoTelaPaciente();
}

/// Estado de carregamento ou inicialização dos dados da Stream.
class EstadoPacienteCarregando extends EstadoTelaPaciente {
  const EstadoPacienteCarregando();
}

/// Paciente agendado em domicílio aguardando a chegada do veículo.
/// Status backend: 0 (Aguardando Transporte).
class EstadoAguardandoTransporte extends EstadoTelaPaciente {
  final PacienteModel paciente;
  final bool enviandoAcao;

  const EstadoAguardandoTransporte({
    required this.paciente,
    this.enviandoAcao = false,
  });
}

/// Paciente embarcado na van em trajeto de ida até a clínica/hospital.
/// Status backend: 1 (Embarcou para Ida).
class EstadoEmTransitoIda extends EstadoTelaPaciente {
  final PacienteModel paciente;

  const EstadoEmTransitoIda({required this.paciente});
}

/// Paciente desembarcado no hospital aguardando a consulta médica.
/// Status backend: 2 (Desembarcou para Consulta, com prontoRetorno == false).
class EstadoNaConsultaMedica extends EstadoTelaPaciente {
  final PacienteModel paciente;
  final bool enviandoAcao;

  const EstadoNaConsultaMedica({
    required this.paciente,
    this.enviandoAcao = false,
  });
}

/// Paciente finalizou a consulta médica e avisou o motorista.
/// Status backend: 2 (Desembarcou para Consulta, com prontoRetorno == true).
/// Pode possuir janela de reversão ativa de 60 s para desfazer o aviso.
class EstadoAguardandoRetornoVan extends EstadoTelaPaciente {
  final PacienteModel paciente;
  final JanelaReversaoModel? janela;
  final bool enviandoAcao;

  const EstadoAguardandoRetornoVan({
    required this.paciente,
    this.janela,
    this.enviandoAcao = false,
  });
}

/// Paciente reembarcado na van após a consulta em trajeto de volta para casa.
/// Status backend: 3 (Reembarcou para Volta).
class EstadoEmTransitoRetorno extends EstadoTelaPaciente {
  final PacienteModel paciente;

  const EstadoEmTransitoRetorno({required this.paciente});
}

/// Viagem cancelada (carona/desistência), mas com janela ativa de 5 minutos para desfazer.
/// Status backend: 5 (Cancelado com janela ativa).
class EstadoCanceladoReversivel extends EstadoTelaPaciente {
  final PacienteModel paciente;
  final JanelaReversaoModel janela;
  final bool desfazendo;

  const EstadoCanceladoReversivel({
    required this.paciente,
    required this.janela,
    this.desfazendo = false,
  });
}

/// Cancelamento definitivo consolidado (janela expirada ou sem janela).
/// Status backend: 5 (Cancelado definitivo).
class EstadoCanceladoDefinitivo extends EstadoTelaPaciente {
  final PacienteModel paciente;

  const EstadoCanceladoDefinitivo({required this.paciente});
}

/// Transporte completamente finalizado pelo motorista na entrega domiciliar.
/// Status backend: 4 (Concluído).
class EstadoViagemConcluida extends EstadoTelaPaciente {
  final PacienteModel paciente;

  const EstadoViagemConcluida({required this.paciente});
}

/// Utilitário puro de mapeamento de dados do domínio para a máquina de estados da tela.
class MapeadorEstadoPaciente {
  /// Resolve o estado exato e determinístico da UI a partir do modelo do paciente.
  static EstadoTelaPaciente resolver(
    PacienteModel? paciente, {
    bool enviando = false,
    DateTime? agora,
  }) {
    if (paciente == null) {
      return const EstadoPacienteCarregando();
    }

    final janela = paciente.janelaReversao;
    final bool temJanelaAtiva =
        janela != null && janela.estaAtiva(agora: agora);

    return switch (paciente.status) {
      0 => EstadoAguardandoTransporte(
          paciente: paciente,
          enviandoAcao: enviando,
        ),
      1 => EstadoEmTransitoIda(paciente: paciente),
      2 => (paciente.prontoRetorno)
          ? EstadoAguardandoRetornoVan(
              paciente: paciente,
              janela: temJanelaAtiva ? janela : null,
              enviandoAcao: enviando,
            )
          : EstadoNaConsultaMedica(
              paciente: paciente,
              enviandoAcao: enviando,
            ),
      3 => EstadoEmTransitoRetorno(paciente: paciente),
      4 => EstadoViagemConcluida(paciente: paciente),
      5 => (temJanelaAtiva && janela.acao == 'cancelamento_carona')
          ? EstadoCanceladoReversivel(
              paciente: paciente,
              janela: janela,
              desfazendo: enviando,
            )
          : EstadoCanceladoDefinitivo(paciente: paciente),
      _ => EstadoAguardandoTransporte(
          paciente: paciente,
          enviandoAcao: enviando,
        ),
    };
  }
}
