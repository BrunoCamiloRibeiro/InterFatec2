// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/viagem_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula as informações operacionais de uma Viagem do transporte
// de pacientes (TFD), incluindo a máquina de estados do ciclo de vida
// (EstadoViagem), dados do motorista condutor, veículo reservado, leituras do
// hodômetro (KM inicial/final), lista de passageiros e timestamps de execução.
//
// PARA QUE SERVE NO PROJETO:
// É a entidade central para o fluxo de viagens da issue #17 e geração do PDF
// da issue #16: registra o início do trajeto, gerencia a reserva de veículos,
// armazena observações de percurso e calcula o total de quilômetros rodados.
//
// ONDE É USADO NO PROJETO:
// - lib/services/viagem_service.dart (criação, escuta de viagem ativa, encerramento)
// - lib/services/validacao_viagem.dart (validações de formulário de início)
// - lib/motorista.dart (gerenciamento do estado da tela principal do motorista)
// - lib/components/formulario_inicio_viagem.dart (coleta de dados iniciais)
// - lib/components/formulario_encerramento.dart (registro de KM final e fim)
// - lib/components/timeline_viagem.dart (rastreamento do ciclo de vida)
// - test/formulario_inicio_viagem_test.dart e test/widget_test.dart
//
// DE ONDE RECEBE DADOS:
// Documentos NoSQL da coleção 'viagens' do Firebase Firestore e formulários de UI.
//
// O QUE EXPORTA / EXPÕE:
// - enum EstadoViagem: semViagem, preenchendoFormulario, viagemAtiva, encerrada
// - class ViagemModel: modelo imutável de viagem
// - Atributos: id, motoristaId, motoristaNome, veiculoId, veiculoPlaca,
//   veiculoModelo, kmInicial, cidadeDestino, dataHoraInicio, status,
//   kmFinal, kmRodado, dataHoraFim, observacoes, passageirosIds
// - Construtor constante ViagemModel(...)
// - Map<String, dynamic> toMap(): serialização para Firestore
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

import 'passageiro_viagem_model.dart';
export 'passageiro_viagem_model.dart';

// Linha em branco separadora entre o cabeçalho descritivo do arquivo e a enumeração de estados
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
// Estados possíveis do ciclo de vida da viagem do motorista
// ----------------------------------------------------------------------------
// DECLARAÇÃO DO TIPO ENUMERADO: EstadoViagem
// - O que a instrução faz: Declara o ciclo de vida e a máquina de estados finita da viagem do motorista.
// - O que é o elemento: Tipo enumerado puro ('enum') do Dart.
// - Papel no sistema: Controla a exibição reativa de componentes na tela 'lib/motorista.dart':
//   se exibe botão de iniciar viagem, formulário de partida, lista de passageiros ou resumo final.
// ----------------------------------------------------------------------------
enum EstadoViagem {
  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Motorista autenticado sem viagem ativa vinculada
  // --------------------------------------------------------------------------
  // CONSTANTE ENUMERADA: semViagem
  // - O que é: Estado inicial de repouso ou prontidão do motorista antes de abrir qualquer escala.
  // --------------------------------------------------------------------------
  semViagem,

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Formulário de início de viagem em exibição para preenchimento
  // --------------------------------------------------------------------------
  // CONSTANTE ENUMERADA: preenchendoFormulario
  // - O que é: Estado transitório onde o formulário modal de partida está aberto para digitação de KM e veículo.
  // --------------------------------------------------------------------------
  preenchendoFormulario,

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Viagem em andamento com veículo selecionado e lista de passageiros liberada
  // --------------------------------------------------------------------------
  // CONSTANTE ENUMERADA: viagemAtiva
  // - O que é: Estado operacional principal onde o trajeto está ocorrendo e baixas de passageiros são permitidas.
  // --------------------------------------------------------------------------
  viagemAtiva,

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Viagem concluída com dados finais registrados
  // --------------------------------------------------------------------------
  // CONSTANTE ENUMERADA: encerrada
  // - O que é: Estado terminal pós-conclusão da viagem com KM final registrado no banco.
  // --------------------------------------------------------------------------
  encerrada,

// Fecha a declaração do corpo da enumeração EstadoViagem
}

// Linha em branco separadora entre o enum EstadoViagem e a classe ViagemModel
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
// Modelo de dados para armazenar informações de uma viagem realizada pelo motorista
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE DOMÍNIO: ViagemModel
// - O que a instrução faz: Declara formalmente a entidade imutável de dados da Viagem TFD.
// - O que é o elemento: Entidade de domínio / Data Transfer Object (DTO) imutável com construtor 'const'.
// - Papel no sistema: Concentra os dados operacionais da rota de transporte de saúde.
// ----------------------------------------------------------------------------
class ViagemModel {
  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Identificador único da viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: id
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Identificador primário (Document ID) no Cloud Firestore para a viagem.
  // --------------------------------------------------------------------------
  final String id;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Identificador do motorista responsável
  // --------------------------------------------------------------------------
  // ATRIBUTO: motoristaId
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Chave estrangeira que referencia o condutor responsável na coleção de motoristas.
  // --------------------------------------------------------------------------
  final String motoristaId;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Nome do motorista responsável
  // --------------------------------------------------------------------------
  // ATRIBUTO: motoristaNome
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Nome completo do condutor para apresentação direta em relatórios e no PDF sem queries adicionais.
  // --------------------------------------------------------------------------
  final String motoristaNome;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Identificador do veículo utilizado
  // --------------------------------------------------------------------------
  // ATRIBUTO: veiculoId
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Chave estrangeira que referencia o veículo reservado na coleção 'veiculos'.
  // --------------------------------------------------------------------------
  final String veiculoId;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Placa do veículo utilizado
  // --------------------------------------------------------------------------
  // ATRIBUTO: veiculoPlaca
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Placa do veículo utilizada para exibição no cabeçalho e na ficha física TFD.
  // --------------------------------------------------------------------------
  final String veiculoPlaca;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Modelo do veículo utilizado
  // --------------------------------------------------------------------------
  // ATRIBUTO: veiculoModelo
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Modelo do automóvel impresso no relatório de transporte.
  // --------------------------------------------------------------------------
  final String veiculoModelo;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Quilometragem do veículo no início da viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: kmInicial
  // - O que é: Campo imutável ('final') do tipo primitivo número inteiro ('int').
  // - Papel: Hodômetro inicial conferido pelo motorista antes de dar a partida.
  // --------------------------------------------------------------------------
  final int kmInicial;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Município de destino da viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: cidadeDestino
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: Cidade polo de saúde para onde os pacientes serão levados (ex.: 'São José do Rio Preto').
  // --------------------------------------------------------------------------
  final String cidadeDestino;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Data e hora de início da viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: dataHoraInicio
  // - O que é: Campo imutável ('final') do tipo 'DateTime'.
  // - Papel: Timestamp oficial de abertura da viagem para auditoria e controle de pontualidade.
  // --------------------------------------------------------------------------
  final DateTime dataHoraInicio;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Situação da viagem ('ativa' ou 'encerrada')
  // --------------------------------------------------------------------------
  // ATRIBUTO: status
  // - O que é: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel: 'ativa' para viagens em trânsito; 'encerrada' para viagens finalizadas.
  // --------------------------------------------------------------------------
  final String status;

  // Linha em branco separadora entre atributos iniciais e de encerramento
  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Quilometragem do veículo no encerramento da viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: kmFinal
  // - O que é: Campo imutável opcional/anulável ('int?').
  // - Papel: Hodômetro de chegada digitado pelo motorista no formulário de encerramento.
  // --------------------------------------------------------------------------
  final int? kmFinal;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Total de quilômetros percorridos durante a viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: kmRodado
  // - O que é: Campo imutável opcional/anulável ('int?').
  // - Papel: Diferença matemática calculada (kmFinal - kmInicial) para prestação de contas de combustível.
  // --------------------------------------------------------------------------
  final int? kmRodado;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Data e hora de encerramento da viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: dataHoraFim
  // - O que é: Campo imutável opcional/anulável ('DateTime?').
  // - Papel: Timestamp registrado no momento em que o motorista finaliza a rota.
  // --------------------------------------------------------------------------
  final DateTime? dataHoraFim;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Anotações adicionais sobre a viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: observacoes
  // - O que é: Campo imutável opcional/anulável ('String?').
  // - Papel: Texto livre para registrar imprevistos, atrasos ou ocorrências no trajeto.
  // --------------------------------------------------------------------------
  final String? observacoes;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Identificadores dos passageiros vinculados à viagem
  // --------------------------------------------------------------------------
  // ATRIBUTO: passageirosIds
  // - O que é: Campo imutável ('final') do tipo lista de strings ('List<String>').
  // - Papel: Lista de IDs dos documentos dos pacientes que foram associados a esta escala de transporte.
  // --------------------------------------------------------------------------
  final List<String> passageirosIds;

  // --------------------------------------------------------------------------
  // ATRIBUTO: sessaoId
  // - O que é: Identificador da sessão de veículo do motorista vinculada a esta viagem (Issue #65).
  // --------------------------------------------------------------------------
  final String? sessaoId;

  // --------------------------------------------------------------------------
  // ATRIBUTO: codigosAcesso
  // - O que é: Dicionário associando pacienteId -> código numérico de 4 a 5 dígitos (Issue #65).
  // --------------------------------------------------------------------------
  final Map<String, String> codigosAcesso;

  // --------------------------------------------------------------------------
  // ATRIBUTO: codigosHash
  // - O que é: Dicionário associando pacienteId -> hash criptográfico do código (Issue #65).
  // --------------------------------------------------------------------------
  final Map<String, String> codigosHash;

  /// Nome amigável do Horário (ex.: "06:00 - São José do Rio Preto - HB")
  final String? nomeHorario;

  /// Data da operação do dia (YYYY-MM-DD)
  final DateTime? dataViagem;

  /// Lista detalhada de passageiros com acompanhantes, ordens e destinos
  final List<PassageiroViagemModel> passageiros;

  /// Última latitude real transmitida pelo GPS do motorista
  final double? ultimaLatitude;

  /// Última longitude real transmitida pelo GPS do motorista
  final double? ultimaLongitude;

  /// Timestamp da última atualização de GPS do motorista
  final DateTime? ultimaAtualizacaoLocalizacao;

  // Linha em branco separadora entre atributos e construtor principal
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Construtor com os parâmetros de inicialização da viagem
  // ----------------------------------------------------------------------------
  // CONSTRUTOR CONSTANTE: ViagemModel
  // - O que faz: Constrói uma nova instância imutável de ViagemModel.
  // - Modificador 'const': Permite instanciação canônica e garante imutabilidade dos dados.
  // ----------------------------------------------------------------------------
  const ViagemModel({
    // Parâmetro obrigatório: Identificador único no Firestore
    required this.id,
    // Parâmetro obrigatório: ID do condutor responsável
    required this.motoristaId,
    // Parâmetro obrigatório: Nome do condutor responsável
    required this.motoristaNome,
    // Parâmetro obrigatório: ID do veículo utilizado
    required this.veiculoId,
    // Parâmetro obrigatório: Placa do veículo utilizado
    required this.veiculoPlaca,
    // Parâmetro obrigatório: Modelo do veículo utilizado
    required this.veiculoModelo,
    // Parâmetro obrigatório: Leitura do hodômetro na partida
    required this.kmInicial,
    // Parâmetro obrigatório: Município de destino
    required this.cidadeDestino,
    // Parâmetro obrigatório: Data e hora do início da rota
    required this.dataHoraInicio,
    // Parâmetro opcional: Situação operacional, padrão 'ativa'
    this.status = 'ativa',
    // Parâmetro opcional: Leitura do hodômetro na chegada
    this.kmFinal,
    // Parâmetro opcional: Total de quilômetros percorridos
    this.kmRodado,
    // Parâmetro opcional: Data e hora de conclusão
    this.dataHoraFim,
    // Parâmetro opcional: Observações e ocorrências
    this.observacoes,
    // Parâmetro opcional: Lista de IDs dos passageiros agendados, padrão lista vazia
    this.passageirosIds = const [],
    // Parâmetro opcional: Identificador da sessão de veículo
    this.sessaoId,
    // Parâmetro opcional: Códigos de acesso para exibição ao motorista
    this.codigosAcesso = const {},
    // Parâmetro opcional: Hashes dos códigos de acesso para autenticação
    this.codigosHash = const {},
    // Parâmetro opcional: Nome do horário
    this.nomeHorario,
    // Parâmetro opcional: Data do horário
    this.dataViagem,
    // Parâmetro opcional: Lista de passageiros
    this.passageiros = const [],
    // Parâmetros opcionais de geolocalização real do motorista
    this.ultimaLatitude,
    this.ultimaLongitude,
    this.ultimaAtualizacaoLocalizacao,
  // Fecha a lista de parâmetros formais nomeados do construtor
  });

  // ----------------------------------------------------------------------------
  // GETTERS AUXILIARES DE HORÁRIO E AUDITORIA (FASE 1)
  // ----------------------------------------------------------------------------
  /// Retorna o título amigável do Horário (ou destino formatado como fallback)
  String get tituloHorario {
    if (nomeHorario != null && nomeHorario!.trim().isNotEmpty) {
      return nomeHorario!;
    }
    final hora = dataHoraInicio.hour.toString().padLeft(2, '0');
    final minuto = dataHoraInicio.minute.toString().padLeft(2, '0');
    return '$hora:$minuto - $cidadeDestino';
  }

  /// Retorna a data operacional da viagem
  DateTime get dataOperacional =>
      dataViagem ?? DateTime(dataHoraInicio.year, dataHoraInicio.month, dataHoraInicio.day);

  /// Total consolidado de assentos ocupados nesta viagem (considerando acompanhantes)
  int get totalAssentosOcupados {
    if (passageiros.isNotEmpty) {
      return passageiros.fold(0, (sum, p) => sum + p.assentosOcupados);
    }
    return passageirosIds.length;
  }

  /// Retorna se a viagem é ativa
  bool get isAtiva => status == 'ativa';

  /// Retorna se a viagem é planejada
  bool get isPlanejada => status == 'planejada';

  /// Retorna se a viagem foi encerrada ou concluída
  bool get isConcluida => status == 'encerrada' || status == 'concluida';

  /// Retorna se a viagem foi cancelada
  bool get isCancelada => status == 'cancelada';

  // Linha em branco separadora entre o construtor e o método toMap
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Converte os dados da viagem para uma estrutura Map de chave e valor
  // ----------------------------------------------------------------------------
  // MÉTODO DE SERIALIZAÇÃO: toMap
  // - O que faz: Converte o objeto ViagemModel em um dicionário Map<String, dynamic>.
  // - Retorno: Map pronto para ser persistido na coleção 'viagens' do Cloud Firestore.
  // ----------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    final effectivePassageirosIds = passageirosIds.isNotEmpty
        ? passageirosIds
        : passageiros.map((p) => p.pacienteId).toList();

    return {
      'id': id,
      'motoristaId': motoristaId,
      'motoristaNome': motoristaNome,
      'veiculoId': veiculoId,
      'veiculoPlaca': veiculoPlaca,
      'veiculoModelo': veiculoModelo,
      'kmInicial': kmInicial,
      'cidadeDestino': cidadeDestino,
      'dataHoraInicio': dataHoraInicio.toIso8601String(),
      'status': status,
      'kmFinal': kmFinal,
      'kmRodado': kmRodado,
      'dataHoraFim': dataHoraFim?.toIso8601String(),
      'observacoes': observacoes,
      'passageirosIds': effectivePassageirosIds,
      'sessaoId': sessaoId,
      'codigosAcesso': codigosAcesso,
      'codigosHash': codigosHash,
      if (nomeHorario != null) 'nomeHorario': nomeHorario,
      if (nomeHorario != null) 'horario': nomeHorario,
      'dataViagem': (dataViagem ?? dataHoraInicio).toIso8601String(),
      'passageiros': passageiros.map((p) => p.toMap()).toList(),
      if (ultimaLatitude != null) 'ultimaLatitude': ultimaLatitude,
      if (ultimaLongitude != null) 'ultimaLongitude': ultimaLongitude,
      if (ultimaAtualizacaoLocalizacao != null)
        'ultimaAtualizacaoLocalizacao':
            ultimaAtualizacaoLocalizacao!.toIso8601String(),
    };
  }

  // Linha em branco separadora entre toMap e o construtor factory
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Constrói uma instância de ViagemModel a partir de um Map de dados
  // ----------------------------------------------------------------------------
  // CONSTRUTOR FACTORY (FÁBRICA DE DESSERIALIZAÇÃO): ViagemModel.fromMap
  // - O que faz: Reconstrói uma instância tipada de ViagemModel a partir de um Map NoSQL do Firestore.
  // - Parâmetros: 'map' (dados do Firestore) e 'docId' opcional (identificador do documento).
  // ----------------------------------------------------------------------------
  factory ViagemModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // ------------------------------------------------------------------------
    // Instancia e retorna o ViagemModel aplicando sanitização e fallbacks defensivos:
    // ------------------------------------------------------------------------
    return ViagemModel(
      // Atribui 'docId', 'map["id"]' ou string vazia como identificador
      id: docId ?? map['id'] ?? '',
      // Atribui 'motoristaId' ou string vazia como fallback
      motoristaId: map['motoristaId'] ?? '',
      // Atribui 'motoristaNome' ou string vazia como fallback
      motoristaNome: map['motoristaNome'] ?? '',
      // Atribui 'veiculoId' ou string vazia como fallback
      veiculoId: map['veiculoId'] ?? '',
      // Atribui 'veiculoPlaca' ou string vazia como fallback
      veiculoPlaca: map['veiculoPlaca'] ?? '',
      // Atribui 'veiculoModelo' ou string vazia como fallback
      veiculoModelo: map['veiculoModelo'] ?? '',
      // Converte 'kmInicial' de forma segura com fallback para 0 km
      kmInicial: (map['kmInicial'] is num)
          // Se for número, converte diretamente para inteiro
          ? (map['kmInicial'] as num).toInt()
          // Padrão de 0 km caso ausente ou inválido
          : 0,
      // Atribui 'cidadeDestino' ou string vazia como fallback
      cidadeDestino: map['cidadeDestino'] ?? '',
      // Interpreta 'dataHoraInicio' via tryParse ou assume 'DateTime.now()' como fallback seguro
      dataHoraInicio: map['dataHoraInicio'] != null
          // Tenta realizar parse da representação textual da data
          ? DateTime.tryParse(map['dataHoraInicio'].toString()) ??
                // Se o parse falhar, assume a data e hora do momento atual
                DateTime.now()
          // Se for nulo, assume a data e hora do momento atual
          : DateTime.now(),
      // Atribui 'status' ou 'ativa' por padrão
      status: map['status'] ?? 'ativa',
      // Converte 'kmFinal' para inteiro se for número, ou nulo se ausente
      kmFinal: (map['kmFinal'] is num) ? (map['kmFinal'] as num).toInt() : null,
      // Converte 'kmRodado' para inteiro se for número, ou nulo se ausente
      kmRodado: (map['kmRodado'] is num)
          // Converte valor numérico para inteiro
          ? (map['kmRodado'] as num).toInt()
          // Mantém nulo caso não seja numérico
          : null,
      // Interpreta 'dataHoraFim' via DateTime.tryParse se presente
      dataHoraFim: map['dataHoraFim'] != null
          // Converte texto da data de encerramento em DateTime
          ? DateTime.tryParse(map['dataHoraFim'].toString())
          // Mantém nulo se não houver data de encerramento
          : null,
      // Atribui observações registradas
      observacoes: map['observacoes'],
      // Converte 'passageirosIds' com validação de tipo para lista de strings
      passageirosIds: (map['passageirosIds'] is List)
          // Cria nova lista de Strings a partir do iterável
          ? List<String>.from(map['passageirosIds'])
          // Fallback para lista vazia constante
          : const [],
      // Mapeia sessaoId se presente
      sessaoId: map['sessaoId']?.toString(),
      // Mapeia codigosAcesso com conversão segura
      codigosAcesso: (map['codigosAcesso'] is Map)
          ? Map<String, String>.from(
              (map['codigosAcesso'] as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ),
            )
          : const {},
      // Mapeia codigosHash com conversão segura
      codigosHash: (map['codigosHash'] is Map)
          ? Map<String, String>.from(
              (map['codigosHash'] as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ),
            )
          : const {},
      // Mapeia nomeHorario (ou alias horario)
      nomeHorario: map['nomeHorario']?.toString() ?? map['horario']?.toString(),
      // Mapeia dataViagem
      dataViagem: map['dataViagem'] != null
          ? DateTime.tryParse(map['dataViagem'].toString())
          : null,
      // Mapeia passageiros detalhados
      passageiros: (map['passageiros'] is List)
          ? (map['passageiros'] as List)
              .map((p) => PassageiroViagemModel.fromMap(
                  Map<String, dynamic>.from(p as Map)))
              .toList()
          : (map['passageirosIds'] is List)
              ? (map['passageirosIds'] as List)
                  .map((id) => PassageiroViagemModel(
                        pacienteId: id.toString(),
                        pacienteNome: 'Paciente $id',
                        localDestino: map['cidadeDestino']?.toString() ?? '',
                      ))
                  .toList()
              : const [],
      ultimaLatitude: (map['ultimaLatitude'] is num)
          ? (map['ultimaLatitude'] as num).toDouble()
          : double.tryParse(map['ultimaLatitude']?.toString() ?? ''),
      ultimaLongitude: (map['ultimaLongitude'] is num)
          ? (map['ultimaLongitude'] as num).toDouble()
          : double.tryParse(map['ultimaLongitude']?.toString() ?? ''),
      ultimaAtualizacaoLocalizacao: map['ultimaAtualizacaoLocalizacao'] != null
          ? DateTime.tryParse(map['ultimaAtualizacaoLocalizacao'].toString())
          : null,
    // Fecha a lista de argumentos passados ao construtor ViagemModel
    );
  // Fecha o bloco de instruções do construtor factory fromMap
  }

  // Linha em branco separadora entre fromMap e o método copyWith
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Cria uma nova instância de ViagemModel copiando os campos existentes e substituindo os informados
  // ----------------------------------------------------------------------------
  // MÉTODO DE CLONAGEM IMUTÁVEL: copyWith
  // - O que faz: Gera uma cópia da viagem atual permitindo modificar atributos seletivos.
  // - Papel: Usado para transições de estado (ex.: registrar kmFinal e mudar status para 'encerrada').
  // ----------------------------------------------------------------------------
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
    // Novo identificador de sessão opcional
    String? sessaoId,
    // Flag opcional para desvincular sessão (ex: rollback de migração)
    bool removerSessaoId = false,
    // Novos códigos de acesso opcionais
    Map<String, String>? codigosAcesso,
    // Novos hashes de códigos de acesso opcionais
    Map<String, String>? codigosHash,
    // Novo nome do horário opcional
    String? nomeHorario,
    // Nova data da viagem opcional
    DateTime? dataViagem,
    // Nova lista detalhada de passageiros opcional
    List<PassageiroViagemModel>? passageiros,
    double? ultimaLatitude,
    double? ultimaLongitude,
    DateTime? ultimaAtualizacaoLocalizacao,
  // Fecha a lista de parâmetros formais nomeados do copyWith
  }) {
    // ------------------------------------------------------------------------
    // Retorna uma nova instância com os campos mesclados (novo valor ?? valor atual):
    // ------------------------------------------------------------------------
    final novosPassageiros = passageiros ?? this.passageiros;
    final novosPassageirosIds = passageirosIds ??
        (passageiros != null
            ? passageiros.map((p) => p.pacienteId).toList()
            : this.passageirosIds);

    return ViagemModel(
      // Preserva o ID atual se o novo não for fornecido
      id: id ?? this.id,
      // Preserva o ID do motorista atual se o novo não for fornecido
      motoristaId: motoristaId ?? this.motoristaId,
      // Preserva o nome do motorista atual se o novo não for fornecido
      motoristaNome: motoristaNome ?? this.motoristaNome,
      // Preserva o ID do veículo atual se o novo não for fornecido
      veiculoId: veiculoId ?? this.veiculoId,
      // Preserva a placa do veículo atual se a nova não for fornecida
      veiculoPlaca: veiculoPlaca ?? this.veiculoPlaca,
      // Preserva o modelo do veículo atual se o novo não for fornecido
      veiculoModelo: veiculoModelo ?? this.veiculoModelo,
      // Preserva o KM inicial atual se o novo não for fornecido
      kmInicial: kmInicial ?? this.kmInicial,
      // Preserva o destino atual se o novo não for fornecido
      cidadeDestino: cidadeDestino ?? this.cidadeDestino,
      // Preserva a data de início atual se a nova não for fornecida
      dataHoraInicio: dataHoraInicio ?? this.dataHoraInicio,
      // Preserva o status atual se o novo não for fornecido
      status: status ?? this.status,
      // Preserva o KM final se não for informado um novo
      kmFinal: kmFinal ?? this.kmFinal,
      // Preserva o KM total rodado se não for informado um novo
      kmRodado: kmRodado ?? this.kmRodado,
      // Preserva a data de conclusão se não for informada uma nova
      dataHoraFim: dataHoraFim ?? this.dataHoraFim,
      // Preserva as observações se não forem informadas novas
      observacoes: observacoes ?? this.observacoes,
      // Preserva a lista de passageiros se não for informada uma nova
      passageirosIds: novosPassageirosIds,
      // Preserva a sessão se não for informada uma nova (ou remove se explicitado)
      sessaoId: removerSessaoId ? null : (sessaoId ?? this.sessaoId),
      // Preserva os códigos de acesso se não forem informados novos
      codigosAcesso: codigosAcesso ?? this.codigosAcesso,
      // Preserva os hashes dos códigos se não forem informados novos
      codigosHash: codigosHash ?? this.codigosHash,
      // Preserva nome do horário
      nomeHorario: nomeHorario ?? this.nomeHorario,
      // Preserva data da viagem
      dataViagem: dataViagem ?? this.dataViagem,
      // Preserva passageiros
      passageiros: novosPassageiros,
      ultimaLatitude: ultimaLatitude ?? this.ultimaLatitude,
      ultimaLongitude: ultimaLongitude ?? this.ultimaLongitude,
      ultimaAtualizacaoLocalizacao:
          ultimaAtualizacaoLocalizacao ?? this.ultimaAtualizacaoLocalizacao,
    // Fecha a chamada do construtor ViagemModel
    );
  // Fecha o bloco de instruções do método copyWith
  }

// Fecha a declaração do corpo da classe ViagemModel
}
