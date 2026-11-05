import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';

// Armazena o resultado de uma validação de campo ou operação
class ResultadoValidacao {
  // Indica se os dados avaliados atendem aos critérios de validação
  final bool valido;
  // Mensagem descritiva do erro quando o dado é inválido
  final String? mensagemErro;

  const ResultadoValidacao._({required this.valido, this.mensagemErro});

  // Retorna uma instância de ResultadoValidacao com status válido
  factory ResultadoValidacao.sucesso() =>
      const ResultadoValidacao._(valido: true);

  // Retorna uma instância de ResultadoValidacao com status inválido e mensagem de erro
  factory ResultadoValidacao.erro(String mensagem) =>
      ResultadoValidacao._(valido: false, mensagemErro: mensagem);

  // Retorna a representação em texto do resultado da validação
  @override
  String toString() => valido ? 'Válido' : 'Erro: $mensagemErro';
}

// Métodos de validação dos dados de entrada do formulário e estados da viagem
class ValidacaoViagem {
  // Limite máximo numérico aceito para acréscimo de quilometragem em relação ao último registro
  static const int tetoPlausibilidadeKm = 2000;

  // Valida o valor digitado no campo de quilometragem em relação ao último valor registrado
  static ResultadoValidacao validarQuilometragem({
    required String? valorDigitado,
    required int ultimaKmRegistrada,
    int tetoMaximo = tetoPlausibilidadeKm,
  }) {
    // Verifica se o texto é nulo ou vazio
    if (valorDigitado == null || valorDigitado.trim().isEmpty) {
      return ResultadoValidacao.erro(
        'Informe a quilometragem atual do veículo.',
      );
    }

    final textoLimpo = valorDigitado.trim();

    // Converte o texto para número inteiro e valida formato numérico
    final kmInformada = int.tryParse(textoLimpo);
    if (kmInformada == null || !RegExp(r'^\d+$').hasMatch(textoLimpo)) {
      return ResultadoValidacao.erro(
        'A quilometragem deve ser um número inteiro válido.',
      );
    }

    // Compara o valor informado com a última quilometragem conhecida
    if (kmInformada < ultimaKmRegistrada) {
      return ResultadoValidacao.erro(
        'A quilometragem ($kmInformada km) não pode ser menor que a última registrada ($ultimaKmRegistrada km).',
      );
    }

    // Calcula a diferença e compara com o limite máximo estabelecido
    final diferenca = kmInformada - ultimaKmRegistrada;
    if (diferenca > tetoMaximo) {
      return ResultadoValidacao.erro(
        'Quilometragem acima do teto de plausibilidade (+$tetoMaximo km da última registrada). Verifique se digitou corretamente.',
      );
    }

    return ResultadoValidacao.sucesso();
  }

  // Valida a seleção do veículo e seu estado de disponibilidade
  static ResultadoValidacao validarVeiculo(VeiculoModel? veiculo) {
    // Verifica se um veículo foi selecionado
    if (veiculo == null) {
      return ResultadoValidacao.erro(
        'Selecione um veículo disponível para iniciar.',
      );
    }
    // Verifica se o veículo já se encontra marcado em uso
    if (veiculo.emUso) {
      return ResultadoValidacao.erro(
        'O veículo ${veiculo.placa} já está em uso.',
      );
    }
    return ResultadoValidacao.sucesso();
  }

  // Valida se o texto da cidade de destino foi preenchido
  static ResultadoValidacao validarCidade(String? cidade) {
    if (cidade == null || cidade.trim().isEmpty) {
      return ResultadoValidacao.erro('Selecione a cidade de destino.');
    }
    return ResultadoValidacao.sucesso();
  }

  // Filtra a lista de veículos excluindo aqueles com indicador de uso ativo por outro condutor
  static List<VeiculoModel> filtrarVeiculosDisponiveis(
    List<VeiculoModel> veiculos, {
    Set<String> placasEmUso = const {},
    String? motoristaPermitidoId,
  }) {
    return veiculos.where((veiculo) {
      if (veiculo.emUso) {
        // Permite o veículo se pertencer à sessão do motorista informado
        if (motoristaPermitidoId != null &&
            veiculo.motoristaAtualId == motoristaPermitidoId) {
          return true;
        }
        return false;
      }
      // Exclui veículo caso sua placa esteja no conjunto de placas em uso
      if (placasEmUso.contains(veiculo.placa)) return false;
      return true;
    }).toList();
  }

  // Retorna o EstadoViagem correspondente com base nos parâmetros booleanos
  static EstadoViagem resolverEstadoMotorista({
    required bool temViagemAtiva,
    required bool modalFormularioAberto,
  }) {
    if (temViagemAtiva) {
      return EstadoViagem.viagemAtiva;
    }
    if (modalFormularioAberto) {
      return EstadoViagem.preenchendoFormulario;
    }
    return EstadoViagem.semViagem;
  }
}
