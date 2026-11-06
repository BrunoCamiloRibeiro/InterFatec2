// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/validacao_viagem.dart
// Camada: Serviços / Lógica de Negócios e Validações
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa funções puras de validação de regras de negócio para a inicialização
// de viagens do transporte de saúde (TFD), incluindo validação de hodômetro
// (KM inicial não regressivo e teto de plausibilidade), checagem de concorrência
// e reserva de veículos ('validarVeiculo'), filtragem de frotas disponíveis
// e resolução determinística da máquina de estados do motorista.
//
// PARA QUE SERVE NO PROJETO:
// Garante a integridade operacional da issue #17: impede fraudes ou erros de
// digitação de quilometragem, evita que dois motoristas iniciem viagens no
// mesmo veículo em paralelo e desacopla as regras lógicas da interface gráfica
// e do Firebase Firestore, permitindo testes unitários rápidos e isolados.
//
// ONDE É USADO NO PROJETO:
// - lib/components/formulario_inicio_viagem.dart (validação síncrona de campos na UI)
// - lib/services/viagem_service.dart (validação defensiva pré-gravação no banco)
// - lib/motorista.dart (resolução do estado da tela através de resolverEstadoMotorista)
// - test/formulario_inicio_viagem_test.dart (suíte de testes unitários de validação)
//
// DE ONDE RECEBE DADOS:
// Parâmetros primitivos (strings de formulários, inteiros de KM) e instâncias de
// VeiculoModel e ViagemModel fornecidas pela UI ou por streams do Firestore.
//
// O QUE EXPORTA / EXPÕE:
// - class ResultadoValidacao: encapsula sucesso/erro com mensagem descritiva
//   * ResultadoValidacao.sucesso()
//   * ResultadoValidacao.erro(String mensagem)
// - class ValidacaoViagem: métodos utilitários estáticos
//   * static const int tetoPlausibilidadeKm = 2000
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

// ----------------------------------------------------------------------------
// IMPORTAÇÃO DE DEPENDÊNCIAS DE DOMÍNIO INTERNO:
// - VeiculoModel: Modelo representativo dos automóveis da frota municipal.
// - ViagemModel e EstadoViagem: Entidade de viagem e máquina de estados operacionais.
// ----------------------------------------------------------------------------
import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';

// Linha em branco separadora entre imports e a declaração de ResultadoValidacao
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
// Armazena o resultado de uma validação de campo ou operação
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE RESULTADO: ResultadoValidacao
// - O que a instrução faz: Modela e encapsula o desfecho de qualquer verificação lógica de campo.
// - O que é o elemento: Tipo de retorno semântico (Result Pattern) imutável com construtor privado.
// - Papel no sistema: Evita o lançamento de exceções custosas em fluxos normais de validação,
//   fornecendo propriedades claras ('valido' e 'mensagemErro') para renderização na UI.
// ----------------------------------------------------------------------------
class ResultadoValidacao {
  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Indica se os dados avaliados atendem aos critérios de validação
  // --------------------------------------------------------------------------
  // ATRIBUTO: valido
  // - O que é: Campo imutável ('final') do tipo primitivo booleano ('bool').
  // - Papel: 'true' se todos os critérios foram atendidos com sucesso; 'false' caso haja impedimento.
  // --------------------------------------------------------------------------
  final bool valido;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Mensagem descritiva do erro quando o dado é inválido
  // --------------------------------------------------------------------------
  // ATRIBUTO: mensagemErro
  // - O que é: Campo imutável opcional/anulável ('String?').
  // - Papel: Texto explicativo para ser exibido abaixo do campo no TextFormField ou em SnackBar.
  // --------------------------------------------------------------------------
  final String? mensagemErro;

  // Linha em branco separadora entre atributos e construtor privado

  // --------------------------------------------------------------------------
  // CONSTRUTOR PRIVADO CONSTANTE: ResultadoValidacao._
  // - O que faz: Inicializa os campos garantindo que instâncias só sejam geradas via factories.
  // --------------------------------------------------------------------------
  const ResultadoValidacao._({required this.valido, this.mensagemErro});

  // Linha em branco separadora entre construtor privado e factories
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna uma instância de ResultadoValidacao com status válido
  // ----------------------------------------------------------------------------
  // FACTORY CONSTRUTOR: ResultadoValidacao.sucesso
  // - O que faz: Retorna uma instância imutável constante indicando validação aprovada.
  // ----------------------------------------------------------------------------
  factory ResultadoValidacao.sucesso() =>
      // Cria instância constante com valido=true e mensagemErro=null
      const ResultadoValidacao._(valido: true);

  // Linha em branco separadora entre factory sucesso e factory erro
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna uma instância de ResultadoValidacao com status inválido e mensagem de erro
  // ----------------------------------------------------------------------------
  // FACTORY CONSTRUTOR: ResultadoValidacao.erro
  // - O que faz: Retorna uma instância indicando falha de validação com mensagem detalhada.
  // - Parâmetro: 'mensagem' (String) com o texto de orientação amigável.
  // ----------------------------------------------------------------------------
  factory ResultadoValidacao.erro(String mensagem) =>
      // Cria instância com valido=false e mensagem explicativa
      ResultadoValidacao._(valido: false, mensagemErro: mensagem);

  // Linha em branco separadora entre factories e toString
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna a representação em texto do resultado da validação
  // ----------------------------------------------------------------------------
  // SOBRESCRITA DO MÉTODO: toString
  // - O que faz: Retorna representação textual para depuração e mensagens de asserção em testes.
  // ----------------------------------------------------------------------------
  @override
  // Formata o texto como 'Válido' ou 'Erro: <mensagem>'
  String toString() => valido ? 'Válido' : 'Erro: $mensagemErro';

// Fecha a declaração da classe ResultadoValidacao
}

// Linha em branco separadora entre ResultadoValidacao e ValidacaoViagem
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
// Métodos de validação dos dados de entrada do formulário e estados da viagem
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE REGRAS DE NEGÓCIO: ValidacaoViagem
// - O que a instrução faz: Agrupa estaticamente todas as funções puras de validação de viagem.
// - O que é o elemento: Classe utilitária estática (namespace) com métodos puros e constantes.
// - Papel no sistema: Concentra as regras de negócio de hodômetro, concorrência e estado da viagem.
// ----------------------------------------------------------------------------
class ValidacaoViagem {
  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Limite máximo numérico aceito para acréscimo de quilometragem em relação ao último registro
  // --------------------------------------------------------------------------
  // CONSTANTE ESTÁTICA: tetoPlausibilidadeKm
  // - O que é: Constante inteira ('int') fixada em 2000 quilômetros.
  // - Papel: Teto máximo razoável de acréscimo de KM entre duas viagens municipais consecutivas.
  // --------------------------------------------------------------------------
  static const int tetoPlausibilidadeKm = 2000;

  // Linha em branco separadora entre a constante e o método de validação de KM
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Valida o valor digitado no campo de quilometragem em relação ao último valor registrado
  // ----------------------------------------------------------------------------
  // MÉTODO ESTÁTICO: validarQuilometragem
  // - O que faz: Valida se o texto digitado pelo motorista no campo de KM é válido e plausível.
  // - Regras avaliadas em cascata:
  //   1) Não pode ser nulo ou vazio;
  //   2) Deve conter apenas dígitos inteiros válidos;
  //   3) Não pode ser menor que a última quilometragem conhecida (impede regressão do odômetro);
  //   4) Não pode exceder o teto máximo de plausibilidade (evita digitação acidental de zeros extras).
  // - Parâmetros: 'valorDigitado', 'ultimaKmRegistrada' e 'tetoMaximo' opcional.
  // ----------------------------------------------------------------------------
  static ResultadoValidacao validarQuilometragem({
    // Parâmetro obrigatório: Texto digitado pelo motorista no campo de entrada
    required String? valorDigitado,
    // Parâmetro obrigatório: Último hodômetro persistido no cadastro do veículo
    required int ultimaKmRegistrada,
    // Parâmetro opcional: Teto máximo de plausibilidade aceitável (padrão 2000 km)
    int tetoMaximo = tetoPlausibilidadeKm,
  // Abre o bloco de instruções do método validarQuilometragem
  }) {
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Verifica se o texto é nulo ou vazio
    // ------------------------------------------------------------------------
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
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Converte o texto para número inteiro e valida formato numérico
    // ------------------------------------------------------------------------
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
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Compara o valor informado com a última quilometragem conhecida
    // ------------------------------------------------------------------------
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
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Calcula a diferença e compara com o limite máximo estabelecido
    // ------------------------------------------------------------------------
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
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Valida a seleção do veículo e seu estado de disponibilidade
  // ----------------------------------------------------------------------------
  // MÉTODO ESTÁTICO: validarVeiculo
  // - O que faz: Verifica se um veículo foi selecionado e se está livre para uso.
  // - Parâmetro: 'veiculo' (VeiculoModel?, opcional).
  // ----------------------------------------------------------------------------
  static ResultadoValidacao validarVeiculo(VeiculoModel? veiculo) {
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Verifica se um veículo foi selecionado
    // ------------------------------------------------------------------------
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
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Verifica se o veículo já se encontra marcado em uso
    // ------------------------------------------------------------------------
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
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Valida se o texto da cidade de destino foi preenchido
  // ----------------------------------------------------------------------------
  // MÉTODO ESTÁTICO: validarCidade
  // - O que faz: Verifica se o município de destino foi informado e não está vazio.
  // - Parâmetro: 'cidade' (String?).
  // ----------------------------------------------------------------------------
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
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Filtra a lista de veículos excluindo aqueles com indicador de uso ativo por outro condutor
  // ----------------------------------------------------------------------------
  // MÉTODO ESTÁTICO: filtrarVeiculosDisponiveis
  // - O que faz: Retorna apenas os veículos livres para seleção, excluindo os que estão em trânsito.
  // - Exceção: Permite o veículo se ele já pertencer à sessão do motorista autenticado ('motoristaPermitidoId').
  // ----------------------------------------------------------------------------
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
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Permite o veículo se pertencer à sessão do motorista informado
        // --------------------------------------------------------------------
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
      // ----------------------------------------------------------------------
      // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
      // Exclui veículo caso sua placa esteja no conjunto de placas em uso
      // ----------------------------------------------------------------------
      // Checa se a placa consta na lista externa de placas em uso
      if (placasEmUso.contains(veiculo.placa)) return false;
      // Mantém o veículo na lista de disponíveis
      return true;
    // Converte o iterável filtrado em uma nova List
    }).toList();
  // Fecha o método filtrarVeiculosDisponiveis
  }

  // Linha em branco separadora entre filtrarVeiculosDisponiveis e resolverEstadoMotorista
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna o EstadoViagem correspondente com base nos parâmetros booleanos
  // ----------------------------------------------------------------------------
  // MÉTODO ESTÁTICO: resolverEstadoMotorista
  // - O que faz: Computa o EstadoViagem reativo a partir de duas condições booleanas da UI.
  // - Regras:
  //   1) Se 'temViagemAtiva' == true -> EstadoViagem.viagemAtiva;
  //   2) Se 'modalFormularioAberto' == true -> EstadoViagem.preenchendoFormulario;
  //   3) Caso contrário -> EstadoViagem.semViagem.
  // ----------------------------------------------------------------------------
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

// Fecha a declaração da classe ValidacaoViagem
}
