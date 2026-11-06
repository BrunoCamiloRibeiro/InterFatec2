// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/veiculo_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula a estrutura de dados de um veículo da frota municipal de
// saúde de Poloni, armazenando placa, modelo, capacidade de passageiros,
// quilometragem hodômetro atual, controle de uso concorrente (emUso) e motorista
// vinculado, além de métodos de conversão, cópia e comparação de igualdade.
//
// PARA QUE SERVE NO PROJETO:
// É a entidade utilizada para listar veículos no formulário de início de viagem,
// garantir bloqueio transacional contra seleção simultânea do mesmo carro por
// dois motoristas, validar se o KM inicial informado não retrocede em relação
// ao último KM registrado e atualizar o odômetro no encerramento da viagem.
//
// ONDE É USADO NO PROJETO:
// - lib/components/formulario_inicio_viagem.dart (dropdown e validação de KM)
// - lib/services/validacao_viagem.dart (regras de validação de início da viagem)
// - lib/services/viagem_service.dart (escuta em tempo real e atualização de frota)
// - test/formulario_inicio_viagem_test.dart (testes unitários e de widget da frota)
// - test/widget_test.dart (testes de integração do fluxo de viagem)
//
// DE ONDE RECEBE DADOS:
// Documentos serializados do Firebase Firestore (coleção 'veiculos') ou
// instâncias mockadas em cenários de teste automatizado.
//
// O QUE EXPORTA / EXPÕE:
// - class VeiculoModel: classe imutável representativa de veículo
// - Atributos: id, placa, modelo, capacidade, quilometragemAtual, emUso, motoristaAtualId
// - const VeiculoModel(...): construtor constante com valores padrão
// - Map<String, dynamic> toMap(): serialização para Firestore
// - factory VeiculoModel.fromMap(Map, {docId}): desserialização do Firestore
// - VeiculoModel copyWith(...): clonagem imutável com campos substituídos
// - bool operator ==(Object other) e int get hashCode: igualdade por id e placa
//
// ORIGEM HISTÓRICA:
// Criado no commit aa02e80 pela equipe como base da issue #17 (controle de
// concorrência e início de viagem). Não veio de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente dos tipos padrão do Dart SDK.
// Objeto imutável e puro: não executa rede, persistência em disco ou I/O direto.
// ============================================================================

// Linha em branco separadora entre o cabeçalho de documentação e o código-fonte
// Comentários originais do autor mantidos byte a byte:
// Modelo de dados para representar um veículo da frota municipal de saúde.
// Armazena identificação, modelo, placa, capacidade e a quilometragem atual/última registrada.
// Declaração da classe VeiculoModel que estrutura as propriedades do automóvel
class VeiculoModel {
  // Comentário original do autor mantido byte a byte:
  // Identificador único do documento do veículo
  // Atributo imutável do tipo String com o ID do documento no Firestore
  final String id;
  // Comentário original do autor mantido byte a byte:
  // Placa de identificação do veículo
  // Atributo imutável do tipo String contendo a placa oficial (ex: ABC-1234)
  final String placa;
  // Comentário original do autor mantido byte a byte:
  // Nome e especificação de modelo do veículo
  // Atributo imutável do tipo String com a marca/modelo (ex: Spin, Van Master)
  final String modelo;
  // Comentário original do autor mantido byte a byte:
  // Capacidade total de passageiros suportada
  // Atributo imutável do tipo int indicando lotação máxima permitida
  final int capacidade;
  // Comentário original do autor mantido byte a byte:
  // Quilometragem atual ou última registrada do veículo
  // Atributo imutável do tipo int com a leitura do hodômetro em quilômetros
  final int quilometragemAtual;
  // Comentário original do autor mantido byte a byte:
  // Indicador se o veículo está associado a uma viagem ativa
  // Atributo imutável do tipo bool para evitar dupla reserva concorrente
  final bool emUso;
  // Comentário original do autor mantido byte a byte:
  // Identificador do motorista atualmente associado ao veículo
  // Atributo opcional do tipo String com o ID do motorista que está conduzindo
  final String? motoristaAtualId;

  // Linha em branco separadora entre atributos e construtor
  // Comentário original do autor mantido byte a byte:
  // Construtor com os parâmetros de inicialização do veículo
  // Construtor constante para permitir instanciação canônica e imutabilidade
  const VeiculoModel({
    // Parâmetro obrigatório para o ID do veículo
    required this.id,
    // Parâmetro obrigatório para a placa do veículo
    required this.placa,
    // Parâmetro obrigatório para o modelo do veículo
    required this.modelo,
    // Parâmetro opcional de capacidade com valor padrão de 4 passageiros
    this.capacidade = 4,
    // Parâmetro obrigatório para a quilometragem atual do veículo
    required this.quilometragemAtual,
    // Parâmetro opcional com valor padrão falso indicando veículo livre
    this.emUso = false,
    // Parâmetro opcional com o ID do motorista condutor atual
    this.motoristaAtualId,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e toMap
  // Comentário original do autor mantido byte a byte:
  // Converte a instância para um Map de pares chave e valor
  // Método de serialização dos dados do veículo para o Firebase Firestore
  Map<String, dynamic> toMap() {
    // Retorna a estrutura em Map com os pares chave-valor para persistência
    return {
      // Mapeia a placa para a chave 'placa'
      'placa': placa,
      // Mapeia o modelo para a chave 'modelo'
      'modelo': modelo,
      // Mapeia a capacidade de passageiros para a chave 'capacidade'
      'capacidade': capacidade,
      // Mapeia a quilometragem para a chave 'quilometragemAtual'
      'quilometragemAtual': quilometragemAtual,
      // Mapeia o indicador de uso para a chave 'emUso'
      'emUso': emUso,
      // Mapeia o motorista condutor para a chave 'motoristaAtualId'
      'motoristaAtualId': motoristaAtualId,
    // Fecha o mapa de pares chave-valor
    };
  // Fecha o bloco de instruções do método toMap
  }

  // Linha em branco separadora entre toMap e fromMap
  // Comentário original do autor mantido byte a byte:
  // Cria uma instância de VeiculoModel a partir de um Map de dados
  // Construtor factory que reconstrói a instância de VeiculoModel a partir do Firestore
  factory VeiculoModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Retorna a nova instância preenchida com conversões seguras de tipos
    return VeiculoModel(
      // Atribui o identificador docId recebido, o campo 'id' do map ou string vazia
      id: docId ?? map['id'] ?? '',
      // Atribui a placa extraída ou string vazia como fallback
      placa: map['placa'] ?? '',
      // Atribui o modelo extraído ou string vazia como fallback
      modelo: map['modelo'] ?? '',
      // Converte com segurança a capacidade para int ou adota 4 como fallback
      capacidade: (map['capacidade'] is num)
          // Converte valor numérico para int
          ? (map['capacidade'] as num).toInt()
          // Padrão de 4 lugares caso não seja numérico
          : 4,
      // Converte com segurança a quilometragem para int ou adota 0 como fallback
      quilometragemAtual: (map['quilometragemAtual'] is num)
          // Converte valor numérico para int
          ? (map['quilometragemAtual'] as num).toInt()
          // Padrão de 0 km caso não seja numérico
          : 0,
      // Atribui o booleano de uso concorrente ou falso se for nulo
      emUso: map['emUso'] ?? false,
      // Atribui o identificador do motorista atual
      motoristaAtualId: map['motoristaAtualId'],
    // Fecha a chamada do construtor VeiculoModel
    );
  // Fecha o bloco do construtor factory fromMap
  }

  // Linha em branco separadora entre fromMap e copyWith
  // Comentário original do autor mantido byte a byte:
  // Cria uma nova instância de VeiculoModel copiando os campos existentes e substituindo os informados
  // Método copyWith para criar clones imutáveis atualizando apenas propriedades específicas
  VeiculoModel copyWith({
    // Novo identificador opcional
    String? id,
    // Nova placa opcional
    String? placa,
    // Novo modelo opcional
    String? modelo,
    // Nova capacidade opcional
    int? capacidade,
    // Nova quilometragem opcional
    int? quilometragemAtual,
    // Novo status de uso opcional
    bool? emUso,
    // Novo motorista associado opcional
    String? motoristaAtualId,
  // Fecha a lista de parâmetros do copyWith
  }) {
    // Retorna uma nova instância mesclando novos valores com os existentes
    return VeiculoModel(
      // Mantém o ID original se o novo não for informado
      id: id ?? this.id,
      // Mantém a placa original se a nova não for informada
      placa: placa ?? this.placa,
      // Mantém o modelo original se o novo não for informado
      modelo: modelo ?? this.modelo,
      // Mantém a capacidade original se a nova não for informada
      capacidade: capacidade ?? this.capacidade,
      // Mantém o odômetro original se o novo não for informado
      quilometragemAtual: quilometragemAtual ?? this.quilometragemAtual,
      // Mantém o status emUso original se o novo não for informado
      emUso: emUso ?? this.emUso,
      // Mantém o motorista atual se o novo não for informado
      motoristaAtualId: motoristaAtualId ?? this.motoristaAtualId,
    // Fecha a chamada do construtor VeiculoModel
    );
  // Fecha o bloco do método copyWith
  }

  // Linha em branco separadora entre copyWith e operator ==
  // Comentário original do autor mantido byte a byte:
  // Compara se dois objetos VeiculoModel possuem o mesmo identificador e mesma placa
  // Sobrescreve o operador de igualdade para checagem por valor semântico
  @override
  // Implementação da verificação de igualdade entre a instância atual e outro objeto
  bool operator ==(Object other) =>
      // Verifica identidade de referência em memória
      identical(this, other) ||
      // Verifica compatibilidade de tipo e correspondência de campos identificadores
      other is VeiculoModel &&
          // Compara os tipos em tempo de execução
          runtimeType == other.runtimeType &&
          // Compara os identificadores únicos de documento
          id == other.id &&
          // Compara as placas dos veículos
          placa == other.placa;

  // Linha em branco separadora entre operator == e hashCode
  // Comentário original do autor mantido byte a byte:
  // Retorna o valor de hash code gerado a partir do id e da placa
  // Sobrescreve o getter hashCode combinando as propriedades id e placa
  @override
  // Retorna a operação XOR entre os códigos hash das strings id e placa
  int get hashCode => id.hashCode ^ placa.hashCode;
// Fecha o bloco da classe VeiculoModel
}
