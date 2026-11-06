// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/validacao_viagem.dart
// Camada: Domínio / Serviços de Negócio (Services)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa as funções e regras puras de validação de dados para a operação
// de viagens do transporte de saúde: validação da quilometragem inicial e final
// com teto de plausibilidade (+2000 km), checagem de disponibilidade de veículos,
// validação de preenchimento de destino, filtragem de frota disponível para
// evitar conflitos concorrentes e resolução do estado atual do motorista.
//
// PARA QUE SERVE NO PROJETO:
// Isola toda a lógica de validação do formulário e da máquina de estados em
// métodos estáticos puros, facilitando testes unitários rápidos e garantindo
// que tanto a interface com o usuário quanto os serviços de persistência
// apliquem rigorosamente os mesmos critérios antes de gravar no banco de dados.
//
// ONDE É USADO NO PROJETO:
// - lib/components/formulario_inicio_viagem.dart (validação em tempo de digitação)
// - lib/services/viagem_service.dart (validação prévia antes de transações no Firestore)
// - test/formulario_inicio_viagem_test.dart (testes unitários das regras de negócio)
//
// DE ONDE RECEBE DADOS:
// Parâmetros em memória recebidos das telas de formulário e componentes
// (textos digitados, instâncias de VeiculoModel, conjuntos de placas e flags de estado).
//
// O QUE EXPORTA / EXPÕE:
// - class ResultadoValidacao: estrutura de retorno com booleano 'valido' e 'mensagemErro'
// - class ValidacaoViagem: classe utilitária com métodos estáticos de validação
//   * static const int tetoPlausibilidadeKm
//   * static ResultadoValidacao validarQuilometragem(...)
//   * static ResultadoValidacao validarVeiculo(...)
//   * static ResultadoValidacao validarCidade(...)
//   * static List<VeiculoModel> filtrarVeiculosDisponiveis(...)
//   * static EstadoViagem resolverEstadoMotorista(...)
//
// ORIGEM HISTÓRICA:
// Criado no commit aa02e80 pela equipe do projeto como parte da issue #17.
// Não provém de scaffold ou template gerado automaticamente.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende internamente dos modelos VeiculoModel e ViagemModel.
// Código estritamente puro e determinístico: sem efeitos colaterais, sem I/O e sem rede.
// ============================================================================

// Importa o modelo VeiculoModel para validações de capacidade, placa e estado de uso
import '../models/veiculo_model.dart';
// Importa o modelo ViagemModel e enum EstadoViagem para resolução da máquina de estados
import '../models/viagem_model.dart';

// Linha em branco separadora entre imports e a declaração de ResultadoValidacao
// Comentário original do autor mantido byte a byte:
// Armazena o resultado de uma validação de campo ou operação
// Classe que encapsula o desfecho de uma regra de validação
class ResultadoValidacao {
  // Comentário original do autor mantido byte a byte:
  // Indica se os dados avaliados atendem aos critérios de validação
  // Atributo imutável do tipo bool que expressa sucesso (true) ou falha (false)
  final bool valido;
  // Comentário original do autor mantido byte a byte:
  // Mensagem descritiva do erro quando o dado é inválido
  // Atributo opcional do tipo String contendo o texto amigável de erro
  final String? mensagemErro;

  // Linha em branco separadora entre atributos e construtor privado

  // Construtor privado constante para forçar uso das factories semânticas sucesso() e erro()
  const ResultadoValidacao._({required this.valido, this.mensagemErro});

  // Linha em branco separadora entre construtor privado e factories
  // Comentário original do autor mantido byte a byte:
  // Retorna uma instância de ResultadoValidacao com status válido
  // Factory que cria um resultado de validação bem-sucedida sem mensagem de erro
  factory ResultadoValidacao.sucesso() =>
      // Instanciação constante privada com valido=true e mensagemErro=null
      const ResultadoValidacao._(valido: true);

  // Linha em branco separadora entre factory sucesso e factory erro
  // Comentário original do autor mantido byte a byte:
  // Retorna uma instância de ResultadoValidacao com status inválido e mensagem de erro
  // Factory que cria um resultado de validação indicando erro e associando a mensagem
  factory ResultadoValidacao.erro(String mensagem) =>
      // Instanciação privada com valido=false e a mensagem repassada
      ResultadoValidacao._(valido: false, mensagemErro: mensagem);

  // Linha em branco separadora entre factories e toString
  // Comentário original do autor mantido byte a byte:
  // Retorna a representação em texto do resultado da validação
  // Sobrescreve toString para exibição formatada em logs e asserções de teste
  @override
  // Retorna 'Válido' se a validação passou, ou o prefixo de erro concatenado com a mensagem
  String toString() => valido ? 'Válido' : 'Erro: $mensagemErro';
// Fecha a classe ResultadoValidacao
}

// Linha em branco separadora entre ResultadoValidacao e ValidacaoViagem
// Comentário original do autor mantido byte a byte:
// Métodos de validação dos dados de entrada do formulário e estados da viagem
// Classe utilitária contendo métodos estáticos puros de verificação
class ValidacaoViagem {
  // Comentário original do autor mantido byte a byte:
  // Limite máximo numérico aceito para acréscimo de quilometragem em relação ao último registro
  // Constante inteira com limite máximo de 2000 km adicionais aceitos em um lançamento
  static const int tetoPlausibilidadeKm = 2000;

  // Linha em branco separadora entre a constante e o método de validação de KM
  // Comentário original do autor mantido byte a byte:
  // Valida o valor digitado no campo de quilometragem em relação ao último valor registrado
  // Método estático que valida o texto digitado de KM confrontando com o odômetro anterior
  static ResultadoValidacao validarQuilometragem({
    // Parâmetro obrigatório recebendo o texto digitado pelo motorista
    required String? valorDigitado,
    // Parâmetro obrigatório com a última quilometragem persistida do veículo
    required int ultimaKmRegistrada,
    // Parâmetro opcional de teto de plausibilidade com valor padrão tetoPlausibilidadeKm
    int tetoMaximo = tetoPlausibilidadeKm,
  // Abre o corpo do método validarQuilometragem
  }) {
    // Comentário original do autor mantido byte a byte:
    // Verifica se o texto é nulo ou vazio
    // Checa se o parâmetro de texto é nulo ou composto exclusivamente por espaços em branco
    if (valorDigitado == null || valorDigitado.trim().isEmpty) {
      // Retorna resultado de erro orientando a informar a quilometragem
      return ResultadoValidacao.erro(
        // Mensagem explicativa para preenchimento obrigatório
        'Informe a quilometragem atual do veículo.',
      // Fecha a chamada da factory de erro
      );
    // Fecha a checagem de texto vazio
    }

    // Linha em branco separadora entre checagem de vazio e sanitização
    // Remove espaços em branco antes e depois do texto digitado
    final textoLimpo = valorDigitado.trim();

    // Linha em branco separadora entre sanitização e validação de dígitos
    // Comentário original do autor mantido byte a byte:
    // Converte o texto para número inteiro e valida formato numérico
    // Tenta interpretar o texto como número inteiro
    final kmInformada = int.tryParse(textoLimpo);
    // Verifica se a conversão falhou ou se contém caracteres não numéricos via regex
    if (kmInformada == null || !RegExp(r'^\d+$').hasMatch(textoLimpo)) {
      // Retorna erro caso o formato não seja composto estritamente por dígitos inteiros
      return ResultadoValidacao.erro(
        // Mensagem de formato inválido
        'A quilometragem deve ser um número inteiro válido.',
      // Fecha a chamada da factory de erro
      );
    // Fecha a checagem de formato numérico
    }

    // Linha em branco separadora entre formato e checagem de regressão de KM
    // Comentário original do autor mantido byte a byte:
    // Compara o valor informado com a última quilometragem conhecida
    // Impede que o motorista registre uma quilometragem inferior ao hodômetro existente
    if (kmInformada < ultimaKmRegistrada) {
      // Retorna erro informando os valores discrepantes
      return ResultadoValidacao.erro(
        // Mensagem detalhando a impossibilidade de redução de KM
        'A quilometragem ($kmInformada km) não pode ser menor que a última registrada ($ultimaKmRegistrada km).',
      // Fecha a chamada da factory de erro
      );
    // Fecha a checagem de regressão de KM
    }

    // Linha em branco separadora entre regressão e checagem de teto de plausibilidade
    // Comentário original do autor mantido byte a byte:
    // Calcula a diferença e compara com o limite máximo estabelecido
    // Calcula a quantidade de quilômetros acrescidos
    final diferenca = kmInformada - ultimaKmRegistrada;
    // Verifica se a diferença ultrapassa o teto aceitável de segurança
    if (diferenca > tetoMaximo) {
      // Retorna erro alertando sobre possível erro de digitação
      return ResultadoValidacao.erro(
        // Mensagem informando superação do teto de plausibilidade
        'Quilometragem acima do teto de plausibilidade (+$tetoMaximo km da última registrada). Verifique se digitou corretamente.',
      // Fecha a chamada da factory de erro
      );
    // Fecha a checagem do teto
    }

    // Linha em branco separadora entre validações e retorno de sucesso
    // Retorna status de sucesso caso passe por todas as regras anteriores
    return ResultadoValidacao.sucesso();
  // Fecha o método validarQuilometragem
  }

  // Linha em branco separadora entre métodos de validação
  // Comentário original do autor mantido byte a byte:
  // Valida a seleção do veículo e seu estado de disponibilidade
  // Método estático para verificar se o veículo foi escolhido e se está livre
  static ResultadoValidacao validarVeiculo(VeiculoModel? veiculo) {
    // Comentário original do autor mantido byte a byte:
    // Verifica se um veículo foi selecionado
    // Checa se o parâmetro de veículo é nulo
    if (veiculo == null) {
      // Retorna erro exigindo a seleção de um automóvel
      return ResultadoValidacao.erro(
        // Mensagem amigável de exigência de veículo
        'Selecione um veículo disponível para iniciar.',
      // Fecha chamada de erro
      );
    // Fecha checagem de veículo nulo
    }
    // Comentário original do autor mantido byte a byte:
    // Verifica se o veículo já se encontra marcado em uso
    // Checa a flag emUso do veículo selecionado
    if (veiculo.emUso) {
      // Retorna erro informando a indisponibilidade concorrente daquele carro
      return ResultadoValidacao.erro(
        // Mensagem identificando a placa em uso
        'O veículo ${veiculo.placa} já está em uso.',
      // Fecha chamada de erro
      );
    // Fecha checagem de uso
    }
    // Retorna sucesso caso o veículo esteja selecionado e desimpedido
    return ResultadoValidacao.sucesso();
  // Fecha o método validarVeiculo
  }

  // Linha em branco separadora entre validarVeiculo e validarCidade
  // Comentário original do autor mantido byte a byte:
  // Valida se o texto da cidade de destino foi preenchido
  // Método estático que valida a cidade de destino informada
  static ResultadoValidacao validarCidade(String? cidade) {
    // Checa se a string de destino é nula ou vazia
    if (cidade == null || cidade.trim().isEmpty) {
      // Retorna erro solicitando seleção da cidade
      return ResultadoValidacao.erro('Selecione a cidade de destino.');
    // Fecha a checagem de cidade vazia
    }
    // Retorna sucesso se a cidade foi devidamente preenchida
    return ResultadoValidacao.sucesso();
  // Fecha o método validarCidade
  }

  // Linha em branco separadora entre validarCidade e filtrarVeiculosDisponiveis
  // Comentário original do autor mantido byte a byte:
  // Filtra a lista de veículos excluindo aqueles com indicador de uso ativo por outro condutor
  // Método estático que filtra os veículos aptos para condução na sessão atual
  static List<VeiculoModel> filtrarVeiculosDisponiveis(
    // Lista completa de veículos obtida do repositório/banco
    List<VeiculoModel> veiculos, {
    // Conjunto opcional de placas conhecidas como já em uso
    Set<String> placasEmUso = const {},
    // ID do motorista atual para exceção no caso de retomada de sua própria viagem
    String? motoristaPermitidoId,
  // Abre o corpo do método filtrarVeiculosDisponiveis
  }) {
    // Aplica predicado where na lista de veículos
    return veiculos.where((veiculo) {
      // Avalia se o veículo está marcado como em uso no banco
      if (veiculo.emUso) {
        // Comentário original do autor mantido byte a byte:
        // Permite o veículo se pertencer à sessão do motorista informado
        // Verifica se o veículo pertence ao motorista autenticado atual
        if (motoristaPermitidoId != null &&
            veiculo.motoristaAtualId == motoristaPermitidoId) {
          // Permite seleção caso seja do próprio motorista
          return true;
        // Fecha checagem de permissão do motorista
        }
        // Descarta caso esteja em uso por outro motorista
        return false;
      // Fecha bloco if veiculo.emUso
      }
      // Comentário original do autor mantido byte a byte:
      // Exclui veículo caso sua placa esteja no conjunto de placas em uso
      // Checa se a placa consta na lista externa de placas em uso
      if (placasEmUso.contains(veiculo.placa)) return false;
      // Mantém o veículo na lista de disponíveis
      return true;
    // Converte o iterável filtrado em uma nova List
    }).toList();
  // Fecha o método filtrarVeiculosDisponiveis
  }

  // Linha em branco separadora entre filtrarVeiculosDisponiveis e resolverEstadoMotorista
  // Comentário original do autor mantido byte a byte:
  // Retorna o EstadoViagem correspondente com base nos parâmetros booleanos
  // Resolve o estado do motorista com base na existência de viagem ativa e estado do modal
  static EstadoViagem resolverEstadoMotorista({
    // Booleano indicando se existe viagem ativa associada ao condutor
    required bool temViagemAtiva,
    // Booleano indicando se o modal de preenchimento está aberto na tela
    required bool modalFormularioAberto,
  // Abre o corpo do método resolverEstadoMotorista
  }) {
    // Se houver viagem ativa em curso, o estado é viagemAtiva
    if (temViagemAtiva) {
      // Retorna enum correspondente a viagem em andamento
      return EstadoViagem.viagemAtiva;
    // Fecha checagem de viagem ativa
    }
    // Se o modal de formulário estiver em exibição, o estado é preenchendoFormulario
    if (modalFormularioAberto) {
      // Retorna enum correspondente ao preenchimento de formulário
      return EstadoViagem.preenchendoFormulario;
    // Fecha checagem de modal aberto
    }
    // Caso contrário, motorista está livre e sem viagem
    return EstadoViagem.semViagem;
  // Fecha o método resolverEstadoMotorista
  }
// Fecha a classe ValidacaoViagem
}
