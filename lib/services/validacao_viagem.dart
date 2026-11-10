import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';

/// Encapsula o resultado (Result Pattern) de uma validação de regra de negócio.
class ResultadoValidacao {
  final bool valido;
  final String? mensagemErro;

  const ResultadoValidacao._({required this.valido, this.mensagemErro});

  factory ResultadoValidacao.sucesso() =>
      const ResultadoValidacao._(valido: true);

  factory ResultadoValidacao.erro(String mensagem) =>
      ResultadoValidacao._(valido: false, mensagemErro: mensagem);

  @override
  String toString() => valido ? 'Válido' : 'Erro: $mensagemErro';
}

/// Funções puras de validação para início de viagem e prevenção de conflitos na grade.
class ValidacaoViagem {
  /// Acréscimo máximo plausível de quilometragem entre duas viagens consecutivas.
  static const int tetoPlausibilidadeKm = 2000;

  static ResultadoValidacao validarQuilometragem({
    required String? valorDigitado,
    required int ultimaKmRegistrada,
    int tetoMaximo = tetoPlausibilidadeKm,
  }) {
    if (valorDigitado == null || valorDigitado.trim().isEmpty) {
      return ResultadoValidacao.erro(
        'Informe a quilometragem atual do veículo.',
      );
    }

    final textoLimpo = valorDigitado.trim();
    final kmInformada = int.tryParse(textoLimpo);
    if (kmInformada == null || !RegExp(r'^\d+$').hasMatch(textoLimpo)) {
      return ResultadoValidacao.erro(
        'A quilometragem deve ser um número inteiro válido.',
      );
    }

    if (kmInformada < ultimaKmRegistrada) {
      return ResultadoValidacao.erro(
        'A quilometragem ($kmInformada km) não pode ser menor que a última registrada ($ultimaKmRegistrada km).',
      );
    }

    if (kmInformada - ultimaKmRegistrada > tetoMaximo) {
      return ResultadoValidacao.erro(
        'Quilometragem acima do teto de plausibilidade (+$tetoMaximo km da última registrada). Verifique se digitou corretamente.',
      );
    }

    return ResultadoValidacao.sucesso();
  }

  static ResultadoValidacao validarVeiculo(VeiculoModel? veiculo) {
    if (veiculo == null) {
      return ResultadoValidacao.erro(
        'Selecione um veículo disponível para iniciar.',
      );
    }
    if (veiculo.emUso) {
      return ResultadoValidacao.erro(
        'O veículo ${veiculo.placa} já está em uso.',
      );
    }
    return ResultadoValidacao.sucesso();
  }

  static ResultadoValidacao validarCidade(String? cidade) {
    if (cidade == null || cidade.trim().isEmpty) {
      return ResultadoValidacao.erro('Selecione a cidade de destino.');
    }
    return ResultadoValidacao.sucesso();
  }

  /// Filtra veículos livres, mantendo o carro em uso apenas se pertencer ao motorista atual.
  static List<VeiculoModel> filtrarVeiculosDisponiveis(
    List<VeiculoModel> veiculos, {
    Set<String> placasEmUso = const {},
    String? motoristaPermitidoId,
  }) {
    return veiculos.where((veiculo) {
      if (veiculo.emUso) {
        return motoristaPermitidoId != null &&
            veiculo.motoristaAtualId == motoristaPermitidoId;
      }
      return !placasEmUso.contains(veiculo.placa);
    }).toList();
  }

  /// Resolve deterministicamente o [EstadoViagem] da tela do motorista.
  static EstadoViagem resolverEstadoMotorista({
    required bool temViagemAtiva,
    required bool modalFormularioAberto,
  }) {
    if (temViagemAtiva) return EstadoViagem.viagemAtiva;
    if (modalFormularioAberto) return EstadoViagem.preenchendoFormulario;
    return EstadoViagem.semViagem;
  }

  static ({ViagemModel viagem, String horarioV})? _buscarConflitoNoDia({
    required DateTime data,
    required String horario,
    required List<ViagemModel> viagensDoDia,
    required bool Function(ViagemModel) mesmoRecurso,
    String? viagemIdAtual,
  }) {
    final dataAlvo = DateTime(data.year, data.month, data.day);
    final horarioNovo = horario.toLowerCase().trim();
    final hmNovo =
        _extrairHoraMinuto(horarioNovo) ?? (hour: data.hour, minute: data.minute);

    for (final v in viagensDoDia) {
      if (viagemIdAtual != null && v.id == viagemIdAtual) continue;
      if (v.isCancelada) continue;

      final dataV = v.dataOperacional;
      final mesmaData =
          dataV.year == dataAlvo.year &&
          dataV.month == dataAlvo.month &&
          dataV.day == dataAlvo.day;
      if (!mesmaData || !mesmoRecurso(v)) continue;

      final horarioV = v.tituloHorario.toLowerCase().trim();
      final hmV =
          _extrairHoraMinuto(horarioV) ??
          (hour: v.dataHoraInicio.hour, minute: v.dataHoraInicio.minute);
      final mesmoHorarioSaida =
          hmNovo.hour == hmV.hour && hmNovo.minute == hmV.minute;

      if (horarioV == horarioNovo || mesmoHorarioSaida) {
        return (viagem: v, horarioV: horarioV);
      }
    }
    return null;
  }

  static ResultadoValidacao validarConflitoMotorista({
    required String motoristaId,
    required DateTime data,
    required String horario,
    required List<ViagemModel> viagensDoDia,
    String? viagemIdAtual,
  }) {
    if (motoristaId.trim().isEmpty) {
      return ResultadoValidacao.erro('Selecione um motorista responsável.');
    }

    final conflito = _buscarConflitoNoDia(
      data: data,
      horario: horario,
      viagensDoDia: viagensDoDia,
      viagemIdAtual: viagemIdAtual,
      mesmoRecurso: (v) => v.motoristaId == motoristaId,
    );
    if (conflito != null) {
      return ResultadoValidacao.erro(
        'O motorista ${conflito.viagem.motoristaNome} já está escalado para outro Horário simultâneo (${conflito.horarioV}) nesta data.',
      );
    }
    return ResultadoValidacao.sucesso();
  }

  static ResultadoValidacao validarConflitoVeiculo({
    required String veiculoId,
    required DateTime data,
    required String horario,
    required List<ViagemModel> viagensDoDia,
    String? viagemIdAtual,
  }) {
    if (veiculoId.trim().isEmpty) {
      return ResultadoValidacao.erro('Selecione um veículo para a viagem.');
    }

    final conflito = _buscarConflitoNoDia(
      data: data,
      horario: horario,
      viagensDoDia: viagensDoDia,
      viagemIdAtual: viagemIdAtual,
      mesmoRecurso: (v) => v.veiculoId == veiculoId,
    );
    if (conflito != null) {
      return ResultadoValidacao.erro(
        'O veículo ${conflito.viagem.veiculoPlaca} (${conflito.viagem.veiculoModelo}) já está alocado para o Horário "${conflito.horarioV}" nesta data.',
      );
    }
    return ResultadoValidacao.sucesso();
  }

  static ResultadoValidacao validarCapacidade({
    required int totalPassageirosComAcompanhantes,
    required int capacidadeVeiculo,
  }) {
    if (capacidadeVeiculo <= 0) return ResultadoValidacao.sucesso();
    if (totalPassageirosComAcompanhantes > capacidadeVeiculo) {
      return ResultadoValidacao.erro(
        'Capacidade excedida: $totalPassageirosComAcompanhantes passageiros para um veículo com $capacidadeVeiculo assentos.',
      );
    }
    return ResultadoValidacao.sucesso();
  }

  static ResultadoValidacao validarConflitoPaciente({
    required String pacienteId,
    required DateTime data,
    required String horario,
    required List<ViagemModel> viagensDoDia,
    String? viagemIdAtual,
  }) {
    final conflito = _buscarConflitoNoDia(
      data: data,
      horario: horario,
      viagensDoDia: viagensDoDia,
      viagemIdAtual: viagemIdAtual,
      mesmoRecurso: (v) => v.passageirosIds.contains(pacienteId),
    );
    if (conflito != null) {
      return ResultadoValidacao.erro(
        'O paciente já consta agendado no Horário simultâneo "${conflito.horarioV}" deste dia.',
      );
    }
    return ResultadoValidacao.sucesso();
  }

  static ResultadoValidacao validarCompatibilidadeHorarioConsulta({
    required String horarioSaida,
    required String horarioAtendimento,
  }) {
    if (horarioSaida.trim().isEmpty || horarioAtendimento.trim().isEmpty) {
      return ResultadoValidacao.sucesso();
    }

    final partesSaida = _extrairHoraMinuto(horarioSaida);
    final partesAtendimento = _extrairHoraMinuto(horarioAtendimento);
    if (partesSaida != null && partesAtendimento != null) {
      final minutosSaida = partesSaida.hour * 60 + partesSaida.minute;
      final minutosAtendimento =
          partesAtendimento.hour * 60 + partesAtendimento.minute;
      if (minutosAtendimento <= minutosSaida) {
        return ResultadoValidacao.erro(
          'Horário de consulta ($horarioAtendimento) incompatível: é anterior ou igual à saída do transporte ($horarioSaida).',
        );
      }
    }
    return ResultadoValidacao.sucesso();
  }

  static ({int hour, int minute})? _extrairHoraMinuto(String texto) {
    final match = RegExp(r'(\d{1,2})[:hH](\d{2})').firstMatch(texto);
    if (match != null) {
      final h = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return (hour: h, minute: m);
      }
    }
    return null;
  }

  static ResultadoValidacao validarAcompanhante({
    required String? acompanhanteNome,
    required String pacienteId,
  }) {
    if (acompanhanteNome != null &&
        acompanhanteNome.trim().isNotEmpty &&
        pacienteId.trim().isEmpty) {
      return ResultadoValidacao.erro(
        'Acompanhante não pode ser vinculado sem um paciente titular associado.',
      );
    }
    return ResultadoValidacao.sucesso();
  }
}
