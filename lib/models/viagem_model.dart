// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/viagem_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Define os modelos que representam o ciclo de vida completo de uma viagem do
// transporte sanitário (TFD): a enumeração EstadoViagem (máquina de estados do
// motorista) e a classe de entidade ViagemModel, contendo motorista, veículo,
// quilometragem inicial e final, cidade de destino, timestamps, status e
// lista de identificadores de passageiros vinculados à rota.
//
// PARA QUE SERVE NO PROJETO:
// É o modelo central da operação de transporte, utilizado para controlar a
// interface do motorista (sem viagem, preenchendo formulário, viagem ativa, encerrada),
// persistir o registro da rota no Firestore e fornecer os dados para a emissão
// do documento oficial impresso "Roteiro da Viagem - Ficha de Atendimento TFD".
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (coordenação de telas e estado ativo da viagem)
// - lib/components/formulario_inicio_viagem.dart (abertura e envio da viagem)
// - lib/components/formulario_encerramento.dart (conclusão com KM final)
// - lib/components/footer_pacientes.dart (acionamento do diálogo de encerramento)
// - lib/services/viagem_service.dart (persistência transacional no Firestore)
// - lib/services/validacao_viagem.dart (regras de validação de KM e preenchimento)
// - lib/services/relatorio_pdf_service.dart (composição do cabeçalho e rodapé do PDF)
// - test/formulario_inicio_viagem_test.dart (testes de validação e formulário)
// - test/relatorio_pdf_test.dart (testes de geração do PDF da viagem)
// - test/widget_test.dart (testes de fluxo completo da tela de motorista)
//
// DE ONDE RECEBE DADOS:
// Documentos serializados do Firebase Firestore (coleção 'viagens'), entradas
// dos formulários visuais preenchidos pelos motoristas ou dados de teste.
//
// O QUE EXPORTA / EXPÕE:
// - enum EstadoViagem: semViagem, preenchendoFormulario, viagemAtiva, encerrada
// - class ViagemModel: modelo imutável com todas as propriedades da viagem
// - Map<String, dynamic> toMap(): serializa para Firestore
// - factory ViagemModel.fromMap(Map, {docId}): reconstrói a partir do Firestore
// - ViagemModel copyWith(...): clonagem imutável com campos substituídos
//
// ORIGEM HISTÓRICA:
// Criado no commit aa02e80 pela equipe como base da issue #17. Não veio de scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente dos tipos padrão do Dart SDK (DateTime, List, Map, etc.).
// Entidade imutável em memória: sem efeitos colaterais de I/O, rede ou estado global.
// ============================================================================

// Linha em branco separadora entre o cabeçalho de documentação e o enum
// Comentário original do autor mantido byte a byte:
// Estados possíveis do ciclo de vida da viagem do motorista
// Enumeração que representa os diferentes estágios da máquina de estados da viagem
enum EstadoViagem {
  // Comentário original do autor mantido byte a byte:
  // Motorista autenticado sem viagem ativa vinculada
  // Estado no qual o motorista está livre e pode iniciar uma nova viagem
  semViagem,
  // Comentário original do autor mantido byte a byte:
  // Formulário de início de viagem em exibição para preenchimento
  // Estado no qual o motorista está selecionando veículo e digitando KM inicial
  preenchendoFormulario,
  // Comentário original do autor mantido byte a byte:
  // Viagem em andamento com veículo selecionado e lista de passageiros liberada
  // Estado operacional onde os passageiros podem ser embarcados e desembarcados
  viagemAtiva,
  // Comentário original do autor mantido byte a byte:
  // Viagem concluída com dados finais registrados
  // Estado final pós-conclusão com registro do KM de retorno e baixa de todos
  encerrada,
// Fecha o bloco de declaração do enum EstadoViagem
}

// Linha em branco separadora entre o enum e a classe ViagemModel
// Comentário original do autor mantido byte a byte:
// Modelo de dados para armazenar informações de uma viagem realizada pelo motorista
// Declaração da classe imutável ViagemModel
class ViagemModel {
  // Comentário original do autor mantido byte a byte:
  // Identificador único da viagem
  // ID do documento correspondente gerado no Cloud Firestore
  final String id;
  // Comentário original do autor mantido byte a byte:
  // Identificador do motorista responsável
  // ID do documento do motorista autenticado que iniciou a viagem
  final String motoristaId;
  // Comentário original do autor mantido byte a byte:
  // Nome do motorista responsável
  // Nome completo do motorista condutor para exibição nos relatórios e telas
  final String motoristaNome;
  // Comentário original do autor mantido byte a byte:
  // Identificador do veículo utilizado
  // ID do documento do veículo selecionado na coleção 'veiculos'
  final String veiculoId;
  // Comentário original do autor mantido byte a byte:
  // Placa do veículo utilizado
  // Placa de identificação veicular (ex: ABC-1234)
  final String veiculoPlaca;
  // Comentário original do autor mantido byte a byte:
  // Modelo do veículo utilizado
  // Marca e modelo do veículo (ex: Chevrolet Spin)
  final String veiculoModelo;
  // Comentário original do autor mantido byte a byte:
  // Quilometragem do veículo no início da viagem
  // Leitura do hodômetro registrada na partida
  final int kmInicial;
  // Comentário original do autor mantido byte a byte:
  // Município de destino da viagem
  // Cidade para onde os pacientes serão transportados (ex: São José do Rio Preto)
  final String cidadeDestino;
  // Comentário original do autor mantido byte a byte:
  // Data e hora de início da viagem
  // Timestamp de quando o motorista iniciou oficialmente o trajeto
  final DateTime dataHoraInicio;
  // Comentário original do autor mantido byte a byte:
  // Situação da viagem ('ativa' ou 'encerrada')
  // String indicativa de status de execução
  final String status;

  // Linha em branco separadora entre atributos iniciais e de encerramento
  // Comentário original do autor mantido byte a byte:
  // Quilometragem do veículo no encerramento da viagem
  // Leitura do hodômetro no momento da finalização do percurso (opcional)
  final int? kmFinal;
  // Comentário original do autor mantido byte a byte:
  // Total de quilômetros percorridos durante a viagem
  // Diferença calculada entre kmFinal e kmInicial (opcional)
  final int? kmRodado;
  // Comentário original do autor mantido byte a byte:
  // Data e hora de encerramento da viagem
  // Timestamp da finalização da viagem (opcional)
  final DateTime? dataHoraFim;
  // Comentário original do autor mantido byte a byte:
  // Anotações adicionais sobre a viagem
  // Campo de texto livre para intercorrências ou observações gerais (opcional)
  final String? observacoes;
  // Comentário original do autor mantido byte a byte:
  // Identificadores dos passageiros vinculados à viagem
  // Lista contendo os IDs dos pacientes que participam desta viagem
  final List<String> passageirosIds;

  // Linha em branco separadora entre atributos e construtor
  // Comentário original do autor mantido byte a byte:
  // Construtor com os parâmetros de inicialização da viagem
  // Construtor constante para garantir instanciação imutável da viagem
  const ViagemModel({
    // Parâmetro obrigatório para o identificador único da viagem
    required this.id,
    // Parâmetro obrigatório para o ID do motorista condutor
    required this.motoristaId,
    // Parâmetro obrigatório para o nome completo do motorista
    required this.motoristaNome,
    // Parâmetro obrigatório para o ID do automóvel utilizado
    required this.veiculoId,
    // Parâmetro obrigatório para a placa do automóvel
    required this.veiculoPlaca,
    // Parâmetro obrigatório para a descrição do modelo do automóvel
    required this.veiculoModelo,
    // Parâmetro obrigatório para a leitura de KM no início da viagem
    required this.kmInicial,
    // Parâmetro obrigatório para o município de destino
    required this.cidadeDestino,
    // Parâmetro obrigatório para a data e hora do início da viagem
    required this.dataHoraInicio,
    // Parâmetro opcional de status com valor padrão 'ativa'
    this.status = 'ativa',
    // Parâmetro opcional para o KM no término da viagem
    this.kmFinal,
    // Parâmetro opcional para a quilometragem total percorrida
    this.kmRodado,
    // Parâmetro opcional para a data e hora de encerramento
    this.dataHoraFim,
    // Parâmetro opcional para observações da viagem
    this.observacoes,
    // Parâmetro opcional para a lista de IDs de passageiros (padrão lista vazia)
    this.passageirosIds = const [],
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e toMap
  // Comentário original do autor mantido byte a byte:
  // Converte os dados da viagem para uma estrutura Map de chave e valor
  // Método que serializa a instância para um Map compatível com o Firestore
  Map<String, dynamic> toMap() {
    // Retorna a estrutura em Map com os pares chave-valor preenchidos
    return {
      // Mapeia o ID da viagem para a chave 'id'
      'id': id,
      // Mapeia o ID do motorista para a chave 'motoristaId'
      'motoristaId': motoristaId,
      // Mapeia o nome do motorista para a chave 'motoristaNome'
      'motoristaNome': motoristaNome,
      // Mapeia o ID do veículo para a chave 'veiculoId'
      'veiculoId': veiculoId,
      // Mapeia a placa do veículo para a chave 'veiculoPlaca'
      'veiculoPlaca': veiculoPlaca,
      // Mapeia o modelo do veículo para a chave 'veiculoModelo'
      'veiculoModelo': veiculoModelo,
      // Mapeia o KM inicial para a chave 'kmInicial'
      'kmInicial': kmInicial,
      // Mapeia a cidade destino para a chave 'cidadeDestino'
      'cidadeDestino': cidadeDestino,
      // Mapeia a data de início convertida em texto ISO-8601
      'dataHoraInicio': dataHoraInicio.toIso8601String(),
      // Mapeia a situação operacional para a chave 'status'
      'status': status,
      // Mapeia o KM final para a chave 'kmFinal'
      'kmFinal': kmFinal,
      // Mapeia a quilometragem percorrida para a chave 'kmRodado'
      'kmRodado': kmRodado,
      // Mapeia a data de encerramento convertida em texto ISO-8601 se não for nula
      'dataHoraFim': dataHoraFim?.toIso8601String(),
      // Mapeia o campo de observações para a chave 'observacoes'
      'observacoes': observacoes,
      // Mapeia a lista de passageiros para a chave 'passageirosIds'
      'passageirosIds': passageirosIds,
    // Fecha o dicionário Map de pares chave-valor
    };
  // Fecha o bloco de instruções do método toMap
  }

  // Linha em branco separadora entre toMap e fromMap
  // Comentário original do autor mantido byte a byte:
  // Constrói uma instância de ViagemModel a partir de um Map de dados
  // Construtor factory que reconstrói a instância de ViagemModel a partir do Firestore
  factory ViagemModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Retorna a nova instância preenchida com conversões e fallbacks defensivos
    return ViagemModel(
      // Atribui o identificador docId recebido, o campo 'id' do map ou string vazia
      id: docId ?? map['id'] ?? '',
      // Atribui o ID do motorista ou string vazia como fallback
      motoristaId: map['motoristaId'] ?? '',
      // Atribui o nome do motorista ou string vazia como fallback
      motoristaNome: map['motoristaNome'] ?? '',
      // Atribui o ID do veículo ou string vazia como fallback
      veiculoId: map['veiculoId'] ?? '',
      // Atribui a placa do veículo ou string vazia como fallback
      veiculoPlaca: map['veiculoPlaca'] ?? '',
      // Atribui o modelo do veículo ou string vazia como fallback
      veiculoModelo: map['veiculoModelo'] ?? '',
      // Converte com segurança o kmInicial para int ou assume 0 como fallback
      kmInicial: (map['kmInicial'] is num)
          // Converte número para int
          ? (map['kmInicial'] as num).toInt()
          // Padrão de 0 km caso não seja numérico
          : 0,
      // Atribui a cidade de destino ou string vazia como fallback
      cidadeDestino: map['cidadeDestino'] ?? '',
      // Realiza parsing da data e hora de início ou utiliza a data atual como fallback seguro
      dataHoraInicio: map['dataHoraInicio'] != null
          // Tenta realizar parse da representação textual da data
          ? DateTime.tryParse(map['dataHoraInicio'].toString()) ??
                // Se o parse falhar, assume a data e hora do momento atual
                DateTime.now()
          // Se for nulo, assume a data e hora do momento atual
          : DateTime.now(),
      // Atribui a situação da viagem ou 'ativa' por padrão
      status: map['status'] ?? 'ativa',
      // Converte kmFinal para int se for numérico, ou nulo se ausente
      kmFinal: (map['kmFinal'] is num) ? (map['kmFinal'] as num).toInt() : null,
      // Converte kmRodado para int se for numérico, ou nulo se ausente
      kmRodado: (map['kmRodado'] is num)
          // Converte valor numérico para int
          ? (map['kmRodado'] as num).toInt()
          // Mantém nulo caso não seja numérico
          : null,
      // Realiza parsing da data de encerramento se presente no Map
      dataHoraFim: map['dataHoraFim'] != null
          // Converte texto da data de encerramento em DateTime
          ? DateTime.tryParse(map['dataHoraFim'].toString())
          // Mantém nulo se não houver data de encerramento
          : null,
      // Atribui as observações registradas
      observacoes: map['observacoes'],
      // Converte a lista de IDs de passageiros com validação de tipo de lista
      passageirosIds: (map['passageirosIds'] is List)
          // Cria nova lista de Strings a partir do iterável
          ? List<String>.from(map['passageirosIds'])
          // Fallback para lista vazia constante
          : const [],
    // Fecha a chamada do construtor de ViagemModel
    );
  // Fecha o bloco do construtor factory fromMap
  }

  // Linha em branco separadora entre fromMap e copyWith
  // Comentário original do autor mantido byte a byte:
  // Cria uma nova instância de ViagemModel copiando os campos existentes e substituindo os informados
  // Método copyWith para criar cópias imutáveis atualizando apenas os atributos desejados
  ViagemModel copyWith({
    // Novo identificador de viagem opcional
    String? id,
    // Novo ID de motorista opcional
    String? motoristaId,
    // Novo nome de motorista opcional
    String? motoristaNome,
    // Novo ID de veículo opcional
    String? veiculoId,
    // Nova placa de veículo opcional
    String? veiculoPlaca,
    // Novo modelo de veículo opcional
    String? veiculoModelo,
    // Novo KM inicial opcional
    int? kmInicial,
    // Nova cidade destino opcional
    String? cidadeDestino,
    // Nova data de início opcional
    DateTime? dataHoraInicio,
    // Novo status operacional opcional
    String? status,
    // Novo KM final opcional
    int? kmFinal,
    // Novo KM total rodado opcional
    int? kmRodado,
    // Nova data de encerramento opcional
    DateTime? dataHoraFim,
    // Novas observações opcionais
    String? observacoes,
    // Nova lista de passageiros opcional
    List<String>? passageirosIds,
  // Fecha a lista de parâmetros do copyWith
  }) {
    // Retorna uma nova instância mesclando novos valores com os existentes
    return ViagemModel(
      // Mantém ID atual se não for informado um novo
      id: id ?? this.id,
      // Mantém ID de motorista atual se não for informado um novo
      motoristaId: motoristaId ?? this.motoristaId,
      // Mantém nome de motorista atual se não for informado um novo
      motoristaNome: motoristaNome ?? this.motoristaNome,
      // Mantém ID de veículo atual se não for informado um novo
      veiculoId: veiculoId ?? this.veiculoId,
      // Mantém placa atual se não for informada uma nova
      veiculoPlaca: veiculoPlaca ?? this.veiculoPlaca,
      // Mantém modelo atual se não for informado um novo
      veiculoModelo: veiculoModelo ?? this.veiculoModelo,
      // Mantém KM inicial atual se não for informado um novo
      kmInicial: kmInicial ?? this.kmInicial,
      // Mantém destino atual se não for informado um novo
      cidadeDestino: cidadeDestino ?? this.cidadeDestino,
      // Mantém data de início atual se não for informada uma nova
      dataHoraInicio: dataHoraInicio ?? this.dataHoraInicio,
      // Mantém status atual se não for informado um novo
      status: status ?? this.status,
      // Mantém KM final se não for informado um novo
      kmFinal: kmFinal ?? this.kmFinal,
      // Mantém KM rodado se não for informado um novo
      kmRodado: kmRodado ?? this.kmRodado,
      // Mantém data de término se não for informada uma nova
      dataHoraFim: dataHoraFim ?? this.dataHoraFim,
      // Mantém observações se não forem informadas novas
      observacoes: observacoes ?? this.observacoes,
      // Mantém lista de passageiros se não for informada uma nova
      passageirosIds: passageirosIds ?? this.passageirosIds,
    // Fecha a chamada do construtor ViagemModel
    );
  // Fecha o bloco do método copyWith
  }
// Fecha o bloco de declaração da classe ViagemModel
}
