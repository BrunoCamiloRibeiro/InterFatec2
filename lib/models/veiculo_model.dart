// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/veiculo_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula as características físicas, cadastrais e o estado de uso
// de um Veículo da frota municipal de saúde, fornecendo imutabilidade,
// serialização (toMap), desserialização (fromMap), clonagem (copyWith) e
// sobrescrita de igualdade por valor (operator == e hashCode).
//
// PARA QUE SERVE NO PROJETO:
// É o elemento central para o controle de concorrência e início de viagens
// da issue #17: impede que um mesmo veículo seja selecionado simultaneamente
// por dois motoristas ('emUso'), valida a capacidade de passageiros e armazena
// a quilometragem atual do hodômetro para cálculo de distâncias percorridas.
//
// ONDE É USADO NO PROJETO:
// - lib/services/viagem_service.dart (reserva atômica de veículo, escuta de frotas)
// - lib/components/formulario_inicio_viagem.dart (dropdown de seleção de veículos livres)
// - test/formulario_inicio_viagem_test.dart (testes de concorrência e seleção de frota)
//
// DE ONDE RECEBE DADOS:
// Documentos NoSQL da coleção 'veiculos' do Firebase Firestore.
//
// O QUE EXPORTA / EXPÕE:
// - class VeiculoModel: classe de modelo imutável
// - Atributos: id, placa, modelo, capacidade, quilometragemAtual, emUso, motoristaAtualId
// - Construtor constante VeiculoModel(...)
// - Map<String, dynamic> toMap(): serialização para Firestore
// - factory VeiculoModel.fromMap(Map, {docId}): desserialização com fallbacks
// - VeiculoModel copyWith(...): clonagem imutável com campos alterados
// - operator == e hashCode: comparação estrutural por identidade e placa
//
// ORIGEM HISTÓRICA:
// Criado no commit aa02e80 pela equipe como base da issue #17 (controle de
// concorrência e início de viagem). Não veio de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente dos tipos padrão do Dart SDK.
// Objeto imutável e puro: não executa rede, persistência em disco ou I/O direto.
// ============================================================================

// Linha em branco separadora entre o cabeçalho descritivo do arquivo e o código da entidade
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
// Modelo de dados para representar um veículo da frota municipal de saúde.
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
// Armazena identificação, modelo, placa, capacidade e a quilometragem atual/última registrada.
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE DOMÍNIO: VeiculoModel
// - O que a instrução faz: Declara formalmente a classe imutável representativa de um automóvel municipal.
// - O que é o elemento: Entidade de domínio / Data Transfer Object (DTO) imutável com construtor 'const'.
// - Papel no sistema: Modela vans, ambulâncias, carros leves e micro-ônibus utilizados para TFD.
// - Conexões no sistema: Consumida por 'ViagemService' para controle de concorrência e reserva.
// - Efeitos colaterais: Nenhum. É uma declaração de tipo puro sem alocação ou mutação de estado.
// ----------------------------------------------------------------------------
class VeiculoModel {
  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Identificador único do documento do veículo
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: id
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Identificador primário (Document ID) no Cloud Firestore para transações atômicas de reserva.
  // --------------------------------------------------------------------------
  final String id;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Placa de identificação do veículo
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: placa
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Placa oficial de trânsito (padrão Mercosul ou cinza) impressa na ficha de viagem TFD.
  // --------------------------------------------------------------------------
  final String placa;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Nome e especificação de modelo do veículo
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: modelo
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Descrição de marca e modelo comercial (ex.: 'Chevrolet Spin', 'Renault Master').
  // --------------------------------------------------------------------------
  final String modelo;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Capacidade total de passageiros suportada
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: capacidade
  // - O que é: Campo imutável ('final') do tipo primitivo número inteiro ('int').
  // - Papel: Quantidade máxima de passageiros (pacientes + acompanhantes) autorizados no veículo.
  // --------------------------------------------------------------------------
  final int capacidade;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Quilometragem atual ou última registrada do veículo
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: quilometragemAtual
  // - O que é: Campo imutável ('final') do tipo primitivo número inteiro ('int').
  // - Papel: Leitura atual do hodômetro do veículo para validação de quilometragem de saída.
  // --------------------------------------------------------------------------
  final int quilometragemAtual;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Indicador se o veículo está associado a uma viagem ativa
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: emUso
  // - O que é: Campo imutável ('final') do tipo primitivo booleano ('bool').
  // - Papel: Bandeira de concorrência; 'true' indica veículo em trânsito, impedindo nova alocação.
  // --------------------------------------------------------------------------
  final bool emUso;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Identificador do motorista atualmente associado ao veículo
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: motoristaAtualId
  // - O que é: Campo imutável opcional/anulável ('String?').
  // - Papel: ID do motorista que reservou o veículo durante o ciclo ativo da viagem.
  // --------------------------------------------------------------------------
  final String? motoristaAtualId;

  // Linha em branco separadora entre declarações de atributos e o construtor da classe
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Construtor com os parâmetros de inicialização do veículo
  // ----------------------------------------------------------------------------
  // CONSTRUTOR CONSTANTE: VeiculoModel
  // - O que faz: Inicializa todos os atributos de uma nova instância imutável do veículo.
  // - Modificador 'const': Permite criação canônica na memória pelo runtime do Dart.
  // ----------------------------------------------------------------------------
  const VeiculoModel({
    // Parâmetro obrigatório: ID do documento
    required this.id,
    // Parâmetro obrigatório: Placa de trânsito
    required this.placa,
    // Parâmetro obrigatório: Marca e modelo
    required this.modelo,
    // Parâmetro opcional: Capacidade máxima de passageiros, padrão 4
    this.capacidade = 4,
    // Parâmetro obrigatório: Quilometragem atual do hodômetro
    required this.quilometragemAtual,
    // Parâmetro opcional: Status de uso do veículo, padrão falso (livre)
    this.emUso = false,
    // Parâmetro opcional: ID do condutor atual se em viagem
    this.motoristaAtualId,
  // Fecha a lista de parâmetros formais nomeados do construtor
  });

  // Linha em branco separadora entre o construtor e o método de serialização
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Converte a instância para um Map de pares chave e valor
  // ----------------------------------------------------------------------------
  // MÉTODO DE SERIALIZAÇÃO: toMap
  // - O que faz: Converte o objeto VeiculoModel em uma estrutura do tipo Map<String, dynamic>.
  // - Retorno: Map pronto para ser gravado na coleção 'veiculos' do Cloud Firestore.
  // ----------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    // ------------------------------------------------------------------------
    // Retorna a estrutura em Map com os pares chave/valor correspondentes:
    // ------------------------------------------------------------------------
    return {
      // Mapeia a placa oficial para a chave 'placa'
      'placa': placa,
      // Mapeia a descrição do modelo para a chave 'modelo'
      'modelo': modelo,
      // Mapeia a capacidade máxima para a chave 'capacidade'
      'capacidade': capacidade,
      // Mapeia a quilometragem atual para a chave 'quilometragemAtual'
      'quilometragemAtual': quilometragemAtual,
      // Mapeia a situação de uso concorrente para a chave 'emUso'
      'emUso': emUso,
      // Mapeia o condutor responsável para a chave 'motoristaAtualId'
      'motoristaAtualId': motoristaAtualId,
    // Fecha o dicionário de pares chave/valor
    };
  // Fecha o bloco de instruções do método toMap
  }

  // Linha em branco separadora entre toMap e o construtor factory
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Cria uma instância de VeiculoModel a partir de um Map de dados
  // ----------------------------------------------------------------------------
  // CONSTRUTOR FACTORY (FÁBRICA DE DESSERIALIZAÇÃO): VeiculoModel.fromMap
  // - O que faz: Reconstrói uma instância tipada de VeiculoModel a partir de dados NoSQL do Firestore.
  // - Parâmetros: 'map' (dados brutos) e 'docId' opcional (identificador único do documento).
  // ----------------------------------------------------------------------------
  factory VeiculoModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // ------------------------------------------------------------------------
    // Instancia e retorna o VeiculoModel aplicando conversões e fallbacks defensivos:
    // ------------------------------------------------------------------------
    return VeiculoModel(
      // Atribui 'docId', 'map["id"]' ou string vazia como identificador
      id: docId ?? map['id'] ?? '',
      // Atribui 'placa' ou string vazia como fallback
      placa: map['placa'] ?? '',
      // Atribui 'modelo' ou string vazia como fallback
      modelo: map['modelo'] ?? '',
      // Converte 'capacidade' de forma segura com fallback padrão para 4 lugares
      capacidade: (map['capacidade'] is num)
          // Se for número, converte diretamente para inteiro
          ? (map['capacidade'] as num).toInt()
          // Padrão de 4 lugares caso ausente ou inválido
          : 4,
      // Converte 'quilometragemAtual' de forma segura com fallback padrão para 0 km
      quilometragemAtual: (map['quilometragemAtual'] is num)
          // Se for número, converte diretamente para inteiro
          ? (map['quilometragemAtual'] as num).toInt()
          // Padrão de 0 km caso ausente ou inválido
          : 0,
      // Atribui 'emUso' com fallback padrão para falso
      emUso: map['emUso'] ?? false,
      // Atribui o identificador do motorista condutor atual
      motoristaAtualId: map['motoristaAtualId'],
    // Fecha a lista de argumentos passados ao construtor VeiculoModel
    );
  // Fecha o bloco de instruções do construtor factory fromMap
  }

  // Linha em branco separadora entre fromMap e o método copyWith
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Cria uma nova instância de VeiculoModel copiando os campos existentes e substituindo os informados
  // ----------------------------------------------------------------------------
  // MÉTODO DE CLONAGEM IMUTÁVEL: copyWith
  // - O que faz: Gera uma cópia idêntica da instância atual permitindo sobrescrever seletivamente campos.
  // - Papel: Essencial para arquiteturas de estado imutável no Flutter/Dart.
  // ----------------------------------------------------------------------------
  VeiculoModel copyWith({
    // Novo identificador opcional
    String? id,
    // Nova placa de trânsito opcional
    String? placa,
    // Novo modelo comercial opcional
    String? modelo,
    // Nova capacidade de lotação opcional
    int? capacidade,
    // Nova quilometragem do hodômetro opcional
    int? quilometragemAtual,
    // Novo status de uso concorrente opcional
    bool? emUso,
    // Novo motorista condutor opcional
    String? motoristaAtualId,
  // Fecha a lista de parâmetros formais nomeados do copyWith
  }) {
    // ------------------------------------------------------------------------
    // Retorna uma nova instância com os campos mesclados (novo valor ?? valor atual):
    // ------------------------------------------------------------------------
    return VeiculoModel(
      // Preserva o ID atual se o novo não for fornecido
      id: id ?? this.id,
      // Preserva a placa atual se a nova não for fornecida
      placa: placa ?? this.placa,
      // Preserva o modelo atual se o novo não for fornecido
      modelo: modelo ?? this.modelo,
      // Preserva a capacidade atual se a nova não for fornecida
      capacidade: capacidade ?? this.capacidade,
      // Preserva a quilometragem atual se a nova não for fornecida
      quilometragemAtual: quilometragemAtual ?? this.quilometragemAtual,
      // Preserva o status emUso atual se o novo não for fornecido
      emUso: emUso ?? this.emUso,
      // Preserva o motorista atual se o novo não for fornecido
      motoristaAtualId: motoristaAtualId ?? this.motoristaAtualId,
    // Fecha a chamada do construtor VeiculoModel
    );
  // Fecha o bloco de instruções do método copyWith
  }

  // Linha em branco separadora entre copyWith e a sobrescrita do operador de igualdade
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Compara se dois objetos VeiculoModel possuem o mesmo identificador e mesma placa
  // ----------------------------------------------------------------------------
  // SOBRESCRITA DO OPERADOR DE IGUALDADE: operator ==
  // - O que faz: Define a igualdade semântica estrutural entre instâncias de VeiculoModel.
  // - Critérios: Identidade de referência ou coincidência de tipo, 'id' e 'placa'.
  // ----------------------------------------------------------------------------
  @override
  // Implementação da verificação de igualdade semântica
  bool operator ==(Object other) =>
      // Checa identidade de referência direta na memória (mesmo ponteiro)
      identical(this, other) ||
      // Checa se o outro objeto é do mesmo tipo VeiculoModel
      other is VeiculoModel &&
          // Compara os tipos em tempo de execução
          runtimeType == other.runtimeType &&
          // Compara os identificadores de documento
          id == other.id &&
          // Compara as placas oficiais dos veículos
          placa == other.placa;

  // Linha em branco separadora entre operator == e o getter hashCode
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna o valor de hash code gerado a partir do id e da placa
  // ----------------------------------------------------------------------------
  // SOBRESCRITA DO GETTER: hashCode
  // - O que faz: Gera o hash code do objeto a partir do XOR bitwise ('^') dos hashes de 'id' e 'placa'.
  // - Papel: Garante consistência com o 'operator ==' para uso correto em Maps e Sets.
  // ----------------------------------------------------------------------------
  @override
  // Retorna a operação XOR entre os códigos hash das propriedades identificadoras
  int get hashCode => id.hashCode ^ placa.hashCode;

// Fecha a declaração do corpo da classe VeiculoModel
}
