// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/paciente_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e centraliza os dados cadastrais, clínicos, de viagem e de status
// de um Paciente atendido pelo Tratamento Fora de Domicílio (TFD), incluindo
// dados de acompanhante e uma máquina de estados visual e textual (dadosStatus).
//
// PARA QUE SERVE NO PROJETO:
// É o modelo central da experiência do paciente e do motorista: representa cada
// passageiro na lista do dia, mapeando seu ciclo completo de transporte
// (Aguardando Transporte -> Embarcou Ida -> Desembarcou Consulta ->
// Reembarcou Volta -> Concluído ou Cancelado).
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (lista de passageiros do dia, contadores e filtros)
// - lib/paciente.dart (painel de acompanhamento do paciente)
// - lib/components/card_paciente.dart (renderização visual com cores/ícones)
// - lib/components/card_identificacao_paciente.dart (resumo com avatar)
// - lib/components/card_dados_consulta.dart (detalhes da consulta e acompanhante)
// - lib/components/bloco_acompanhante.dart (exibição de acompanhante)
// - lib/services/relatorio_pdf_service.dart (geração do Roteiro de Viagem TFD)
// - test/components/motorista_header_test.dart e test/lista_pessoas_test.dart
//
// DE ONDE RECEBE DADOS:
// Documentos NoSQL da coleção 'pacientes' do Firebase Firestore ou instâncias
// criadas durante a montagem da escala diária de viagens.
//
// O QUE EXPORTA / EXPÕE:
// - class PacienteModel: modelo de dados imutável do paciente
// - Atributos: id, nome, cpf, telefone, enderecoPaciente, localConsulta,
//   localSaida, horarioConsulta, status, nomeAcompanhante, telAcompanhante,
//   role, ativo, criadoEm
// - Construtor nomeado PacienteModel(...)
// - static (String, Color, IconData) dadosStatus(int status): mapeamento central de status
// - Getters: textoStatus, corStatus, iconeStatus
// - Map<String, dynamic> toMap(): serialização para Firestore
// - factory PacienteModel.fromMap(Map, {docId}): desserialização do Firestore
//
// ORIGEM HISTÓRICA:
// Criado no commit ccbbe0e pela equipe do projeto como parte da issue #14
// (baixa de embarque/desembarque em tempo real). Não veio de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart' para utilizar as classes Color e
// IconData no mapeamento dos estados visuais. É uma classe pura em memória:
// sem efeitos colaterais, sem mutabilidade e sem chamadas diretas de I/O ou rede.
// ============================================================================

// ----------------------------------------------------------------------------
// IMPORTAÇÃO DE PACOTE DE TERCEIROS / FLUTTER FRAMEWORK:
// - O que faz: Importa o ecossistema Material Design do Flutter SDK.
// - Símbolos consumidos neste arquivo: 'Color', 'IconData', 'Icons' e 'Colors'.
// - Papel arquitetural: Fornece as definições de cores e ícones vetoriais utilizadas
//   na tupla de retorno da função de mapeamento de status ('dadosStatus').
// ----------------------------------------------------------------------------
import 'package:flutter/material.dart';

// Linha em branco separadora entre os imports e a declaração da classe principal
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE MODELO DE DOMÍNIO: PacienteModel
// - O que a instrução faz: Declara formalmente a entidade imutável de dados do Paciente TFD.
// - O que é o elemento: Classe de dados (DTO/Model) com atributos finais imutáveis.
// - Papel no sistema: Representa os cidadãos transportados pelo serviço municipal de saúde,
//   agrupando identificação civil, endereço de embarque, agendamento de consulta médica,
//   necessidade de acompanhante e o status do ciclo de vida na viagem diária.
// - De onde vem: Escrita especificamente para a arquitetura do projeto TransSaúde.
// - Efeitos colaterais: Nenhum. É uma declaração de tipo puro sem alocação ou mutação de estado.
// ----------------------------------------------------------------------------
class PacienteModel {
  // --------------------------------------------------------------------------
  // ATRIBUTO: id
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Identificador primário exclusivo do documento do paciente no Cloud Firestore.
  // - Conexões: Utilizado como chave única ('Key') em widgets Flutter e para atualizações de status.
  // --------------------------------------------------------------------------
  final String id;

  // --------------------------------------------------------------------------
  // ATRIBUTO: nome
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Nome completo do paciente transportado.
  // - Conexões: Renderizado nos cards da lista do motorista, no painel do paciente e na ficha física PDF.
  // --------------------------------------------------------------------------
  final String nome;

  // --------------------------------------------------------------------------
  // ATRIBUTO: cpf
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Cadastro de Pessoa Física do paciente, usado para controle clínico e login.
  // - Conexões: Sanitizado pelo AuthService e pesquisado em buscas textuais da gestão de pessoas.
  // --------------------------------------------------------------------------
  final String cpf;

  // --------------------------------------------------------------------------
  // ATRIBUTO: telefone
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Número de contato telefônico do paciente para alinhamento de horários e avisos.
  // - Conexões: Exibido na ficha impressa PDF e disponível para discagem rápida pelo motorista.
  // --------------------------------------------------------------------------
  final String telefone;

  // --------------------------------------------------------------------------
  // ATRIBUTO: enderecoPaciente
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Endereço residencial completo do paciente (rua, número, bairro).
  // - Conexões: Utilizado pelo motorista para planejar a rota de coleta e impresso na ficha TFD.
  // --------------------------------------------------------------------------
  final String enderecoPaciente;

  // --------------------------------------------------------------------------
  // ATRIBUTO: localConsulta
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Nome do hospital, clínica especializada, AME ou unidade de saúde de destino.
  // - Conexões: Exibido com destaque nos cards de viagem e na coluna Destino do relatório PDF.
  // --------------------------------------------------------------------------
  final String localConsulta;

  // --------------------------------------------------------------------------
  // ATRIBUTO: localSaida
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Ponto específico onde o paciente aguarda o transporte (ex.: 'Residência' ou 'UBS Poloni').
  // - Conexões: Exibido na ficha física de viagem e nos detalhes do agendamento.
  // --------------------------------------------------------------------------
  final String localSaida;

  // --------------------------------------------------------------------------
  // ATRIBUTO: horarioConsulta
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Horário programado para o procedimento médico na cidade de destino (ex.: '08:00', '13:30').
  // - Conexões: Crucial para o motorista priorizar o itinerário de entrega dos pacientes a tempo.
  // --------------------------------------------------------------------------
  final String horarioConsulta;

  // --------------------------------------------------------------------------
  // ATRIBUTO: status
  // - O que é: Campo final imutável do tipo primitivo inteiro ('int').
  // - Papel: Código numérico (0 a 5) que representa o estágio atual do paciente no ciclo da viagem.
  // - Valores válidos:
  //   * 0: Aguardando Transporte
  //   * 1: Embarcou para Ida
  //   * 2: Desembarcou para Consulta
  //   * 3: Reembarcou para Volta
  //   * 4: Concluído
  //   * 5: Cancelado
  // - Conexões: Altera a cor do card, o badge visual, os contadores do cabeçalho e a lógica de baixa.
  // --------------------------------------------------------------------------
  final int status;

  // --------------------------------------------------------------------------
  // ATRIBUTO: nomeAcompanhante
  // - O que é: Campo final opcional/anulável ('String?').
  // - Papel: Nome do acompanhante do paciente, quando houver exigência médica ou legal (ex.: idoso/menor).
  // - Conexões: Contabiliza +1 na lotação geral da viagem e gera bloco visual dedicado na ficha PDF.
  // --------------------------------------------------------------------------
  final String? nomeAcompanhante;

  // --------------------------------------------------------------------------
  // ATRIBUTO: telAcompanhante
  // - O que é: Campo final opcional/anulável ('String?').
  // - Papel: Telefone de contato do acompanhante responsável.
  // - Conexões: Exibido ao motorista para contato de emergência e registrado na ficha de transporte.
  // --------------------------------------------------------------------------
  final String? telAcompanhante;

  // --------------------------------------------------------------------------
  // ATRIBUTOS DOCUMENTAIS EXTRAS (Issue #65: Resolução de Identificador de Login)
  // --------------------------------------------------------------------------
  /// CPF do acompanhante responsável (caso o paciente não possua CPF)
  final String? cpfAcompanhante;
  /// Registro Geral (RG) do paciente (documento secundário de identificação)
  final String? rg;
  /// Carteira Nacional de Habilitação (CNH) do paciente (documento secundário)
  final String? cnh;

  // --------------------------------------------------------------------------
  // ATRIBUTO: role
  // - O que é: Campo final imutável do tipo primitivo 'String'.
  // - Papel: Identificador de papel de acesso RBAC, com valor padrão 'paciente'.
  // - Conexões: Usado na autorização de rotas pelo RouteGuard.
  // --------------------------------------------------------------------------
  final String role;

  // --------------------------------------------------------------------------
  // ATRIBUTO: ativo
  // - O que é: Campo final imutável do tipo primitivo booleano ('bool').
  // - Papel: Situação de atividade cadastral no sistema municipal.
  // --------------------------------------------------------------------------
  final bool ativo;

  // --------------------------------------------------------------------------
  // ATRIBUTO: criadoEm
  // - O que é: Campo final imutável do tipo 'DateTime?', opcional.
  // - Papel: Registro temporal da data e hora de inclusão do paciente no sistema.
  // --------------------------------------------------------------------------
  final DateTime? criadoEm;

  // Linha em branco separadora entre a declaração dos campos e o construtor principal

  // --------------------------------------------------------------------------
  // CONSTRUTOR PADRÃO COM PARÂMETROS NOMEADOS: PacienteModel
  // - O que faz: Constrói uma nova instância imutável de PacienteModel com validações de nulidade.
  // - O que é: Construtor generativo com parâmetros obrigatórios ('required') e padrões defensivos.
  // --------------------------------------------------------------------------
  PacienteModel({
    // Parâmetro obrigatório: Identificador único no Firestore
    required this.id,
    // Parâmetro obrigatório: Nome completo do paciente
    required this.nome,
    // Parâmetro obrigatório: CPF do paciente
    required this.cpf,
    // Parâmetro obrigatório: Telefone de contato
    required this.telefone,
    // Parâmetro obrigatório: Endereço residencial
    required this.enderecoPaciente,
    // Parâmetro obrigatório: Local de atendimento médico no destino
    required this.localConsulta,
    // Parâmetro opcional: Ponto de partida, padrão vazio
    this.localSaida = '',
    // Parâmetro opcional: Horário da consulta médica, padrão vazio
    this.horarioConsulta = '',
    // Parâmetro opcional: Código numérico de status, padrão 0 (Aguardando Transporte)
    this.status = 0,
    // Parâmetro opcional: Nome completo do acompanhante
    this.nomeAcompanhante,
    // Parâmetro opcional: Telefone de contato do acompanhante
    this.telAcompanhante,
    this.cpfAcompanhante,
    this.rg,
    this.cnh,
    // Parâmetro opcional: Papel de acesso RBAC, padrão 'paciente'
    this.role = 'paciente',
    // Parâmetro opcional: Indicador de conta ativa, padrão verdadeiro
    this.ativo = true,
    // Parâmetro opcional: Data e hora de criação do registro
    this.criadoEm,
  // Fecha a lista de parâmetros formais nomeados do construtor
  });

  // Linha em branco separadora entre o construtor e a máquina de status
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Mapeamento centralizado de status numérico para texto, cor e ícone em todo o app
  // ----------------------------------------------------------------------------
  // FUNÇÃO ESTÁTICA CENTRAL DE STATUS: dadosStatus
  // - O que faz: Converte o código numérico de status (0 a 5) em uma tupla estruturada
  //   composta por (String texto, Color cor, IconData icone).
  // - O que é o elemento: Método estático puro de domínio utilizando Records (tuplas) do Dart 3.
  // - Papel arquitetural: Centraliza a identidade visual e semântica de todo o fluxo de transporte.
  //   Evita duplicação de switches ou mapeamentos dispersos em telas e componentes.
  // - Chamadores no sistema: 'CardPaciente', 'CardTrackingPaciente', 'MotoristaHeader',
  //   'FooterPacientes', 'RelatorioPdfService' e os próprios getters desta classe.
  // ----------------------------------------------------------------------------
  static (String texto, Color cor, IconData icone) dadosStatus(int status) {
    // ------------------------------------------------------------------------
    // Avaliação do status via Pattern Matching do Dart 3 (switch expression):
    // ------------------------------------------------------------------------
    return switch (status) {
      // ----------------------------------------------------------------------
      // ESTÁGIO 0: Aguardando Transporte
      // - Significado: Paciente agendado aguardando coleta em domicílio ou ponto de encontro.
      // - Cor visual: Azul vibrante (0xFF2563EB) representando estado pendente programado.
      // - Ícone: 'Icons.schedule_outlined' (relógio).
      // ----------------------------------------------------------------------
      0 => (
        'Aguardando Transporte',
        const Color(0xFF2563EB),
        Icons.schedule_outlined,
      ),

      // ----------------------------------------------------------------------
      // ESTÁGIO 1: Embarcou para Ida
      // - Significado: Paciente confirmado a bordo do veículo no trajeto até o município de destino.
      // - Cor visual: Azul cobalto escuro (0xFF1D4ED8) indicando deslocamento ativo em curso.
      // - Ícone: 'Icons.near_me_outlined' (seta direcional de rota).
      // ----------------------------------------------------------------------
      1 => (
        'Embarcou para Ida',
        const Color(0xFF1D4ED8),
        Icons.near_me_outlined,
      ),

      // ----------------------------------------------------------------------
      // ESTÁGIO 2: Desembarcou para Consulta
      // - Significado: Paciente entregue no hospital, AME ou clínica de atendimento médico.
      // - Cor visual: Âmbar/Laranja (0xFFD97706) sinalizando espera de procedimento clínico.
      // - Ícone: 'Icons.exit_to_app' (desembarque hospitalar).
      // ----------------------------------------------------------------------
      2 => (
        'Desembarcou para Consulta',
        const Color(0xFFD97706),
        Icons.exit_to_app,
      ),

      // ----------------------------------------------------------------------
      // ESTÁGIO 3: Reembarcou para Volta
      // - Significado: Procedimento médico finalizado; paciente reembarcado no veículo para o retorno.
      // - Cor visual: Índigo/Púrpura (0xFF4338CA) sinalizando a perna de retorno da viagem.
      // - Ícone: 'Icons.reply_outlined' (retorno municipal).
      // ----------------------------------------------------------------------
      3 => (
        'Reembarcou para Volta',
        const Color(0xFF4338CA),
        Icons.reply_outlined,
      ),

      // ----------------------------------------------------------------------
      // ESTÁGIO 4: Concluído
      // - Significado: Paciente entregue em segurança em seu município/residência de origem.
      // - Cor visual: Verde sucesso (0xFF16A34A) indicando conclusão plena do atendimento.
      // - Ícone: 'Icons.check_outlined' (confirmação de sucesso).
      // ----------------------------------------------------------------------
      4 => ('Concluído', const Color(0xFF16A34A), Icons.check_outlined),

      // ----------------------------------------------------------------------
      // ESTÁGIO 5: Cancelado
      // - Significado: Atendimento cancelado por desistência, falta ou suspensão médica.
      // - Cor visual: Vermelho de alerta (0xFFB83227) sinalizando cancelamento operacional.
      // - Ícone: 'Icons.cancel' (alerta de cancelamento).
      // ----------------------------------------------------------------------
      5 => ('Cancelado', const Color(0xFFB83227), Icons.cancel),

      // ----------------------------------------------------------------------
      // ESTÁGIO PADRÃO (FALLBACK DEFENSIVO):
      // - Significado: Código de status não catalogado, corrompido ou desconhecido.
      // - Cor visual: Cinza neutro ('Colors.grey').
      // - Ícone: 'Icons.help' (interrogação/ajuda).
      // ----------------------------------------------------------------------
      _ => ('Pendente', Colors.grey, Icons.help),
    // Fecha a expressão switch pattern matching
    };
  // Fecha o bloco de instruções do método dadosStatus
  }

  // Linha em branco separadora entre dadosStatus e os getters de conveniência
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Getters utilitários para acesso rápido na instância do paciente
  // ----------------------------------------------------------------------------
  // GETTER: textoStatus
  // - O que faz: Extrai o rótulo textual do status da instância a partir de dadosStatus.
  // - Retorno: String com o texto amigável do status (ex.: 'Aguardando Transporte').
  // ----------------------------------------------------------------------------
  String get textoStatus => dadosStatus(status).$1;

  // ----------------------------------------------------------------------------
  // GETTER: corStatus
  // - O que faz: Extrai a cor associada ao status da instância a partir de dadosStatus.
  // - Retorno: Objeto Color tipado para aplicação em BoxDecoration, textos e ícones.
  // ----------------------------------------------------------------------------
  Color get corStatus => dadosStatus(status).$2;

  // ----------------------------------------------------------------------------
  // GETTER: iconeStatus
  // - O que faz: Extrai o ícone representativo do status da instância a partir de dadosStatus.
  // - Retorno: Objeto IconData pronto para ser renderizado pelo widget Icon().
  // ----------------------------------------------------------------------------
  IconData get iconeStatus => dadosStatus(status).$3;

  // Linha em branco separadora entre os getters e o método de serialização
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Salvar no Firebase
  // ----------------------------------------------------------------------------
  // MÉTODO DE SERIALIZAÇÃO: toMap
  // - O que faz: Converte o objeto PacienteModel em um dicionário Map<String, dynamic>.
  // - Retorno: Estrutura serializável para operações de gravação e atualização no Cloud Firestore.
  // ----------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    // ------------------------------------------------------------------------
    // Retorna a estrutura literal de mapa com todas as propriedades da entidade:
    // ------------------------------------------------------------------------
    return {
      // Mapeia o nome completo civil para a chave 'nome'
      'nome': nome,
      // Mapeia o número de CPF para a chave 'cpf'
      'cpf': cpf,
      // Mapeia o telefone principal para a chave 'telefone'
      'telefone': telefone,
      // Mapeia o endereço residencial para a chave 'enderecoPaciente'
      'enderecoPaciente': enderecoPaciente,
      // Mapeia a unidade médica de atendimento para a chave 'localConsulta'
      'localConsulta': localConsulta,
      // Mapeia o ponto de partida para a chave 'localSaida'
      'localSaida': localSaida,
      // Mapeia o horário agendado do atendimento médico para a chave 'horarioConsulta'
      'horarioConsulta': horarioConsulta,
      // Mapeia o código numérico de status (0 a 5) para a chave 'status'
      'status': status,
      // Mapeia o nome do acompanhante para a chave 'nomeAcompanhante'
      'nomeAcompanhante': nomeAcompanhante,
      // Mapeia o telefone do acompanhante para a chave 'telAcompanhante'
      'telAcompanhante': telAcompanhante,
      'cpfAcompanhante': cpfAcompanhante,
      'rg': rg,
      'cnh': cnh,
      // Mapeia o papel de privilégio para a chave 'role'
      'role': role,
      // Mapeia a bandeira booleana de atividade da conta para a chave 'ativo'
      'ativo': ativo,
      // Mapeia a data de criação convertida para string ISO-8601 se não for nula
      'criadoEm': criadoEm?.toIso8601String(),
    // Fecha o dicionário de pares chave/valor
    };
  // Fecha o bloco de instruções do método toMap
  }

  // Linha em branco separadora entre toMap e a rotina de interpretação de data

  // ----------------------------------------------------------------------------
  // FUNÇÃO UTILITÁRIA PRIVADA ESTÁTICA: _parsearData
  // - O que faz: Converte valores de tipos arbitrários ('dynamic') para 'DateTime?'.
  // - O que é: Função utilitária resiliente com suporte a Timestamp do Firestore e ISO-8601.
  // ----------------------------------------------------------------------------
  static DateTime? _parsearData(dynamic valor) {
    // Retorna nulo imediatamente caso a entrada seja nula
    if (valor == null) return null;
    // Se o valor já for DateTime, retorna diretamente a instância
    if (valor is DateTime) return valor;
    // Tenta invocar toDate() dinamicamente caso seja um Timestamp do Firestore
    try {
      return (valor as dynamic).toDate() as DateTime;
    } catch (_) {}
    // Tenta interpretar o texto via DateTime.tryParse
    try {
      return DateTime.tryParse(valor.toString());
    } catch (_) {}
    // Retorna nulo como fallback de segurança
    return null;
  // Fecha o corpo de execução da função utilitária estática _parsearData
  }

  // Linha em branco separadora entre a função de data e o construtor factory
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Ler do Firebase
  // ----------------------------------------------------------------------------
  // CONSTRUTOR FACTORY (FÁBRICA DE DESSERIALIZAÇÃO): PacienteModel.fromMap
  // - O que faz: Reconstrói uma instância tipada de PacienteModel a partir de um Map de dados NoSQL.
  // - O que é: Construtor de fábrica defensivo com tratamento robusto para campos nulos e conversões.
  // - Parâmetros: 'map' (dados do Firestore) e 'docId' opcional (identificador do documento).
  // ----------------------------------------------------------------------------
  factory PacienteModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // ------------------------------------------------------------------------
    // Extrai o valor bruto associado ao status numérico:
    // ------------------------------------------------------------------------
    final statusRaw = map['status'];

    // ------------------------------------------------------------------------
    // Normaliza o status para número inteiro:
    // Trata instâncias numéricas ('num') ou strings numéricas, com fallback para 0 (Aguardando):
    // ------------------------------------------------------------------------
    final int statusInt = (statusRaw is num)
        // Converte diretamente instâncias numéricas para inteiro
        ? statusRaw.toInt()
        // Tenta interpretar representação textual ou adota 0 como padrão de segurança
        : (int.tryParse(statusRaw?.toString() ?? '') ?? 0);

    // Linha em branco separadora entre a conversão de status e a instanciação

    // ------------------------------------------------------------------------
    // Instancia e retorna o PacienteModel aplicando sanitização e fallbacks defensivos:
    // ------------------------------------------------------------------------
    return PacienteModel(
      // Atribui o identificador do documento ou string vazia se nulo
      id: docId ?? '',
      // Atribui o nome recuperado ou string vazia se nulo
      nome: (map['nome'] ?? '').toString(),
      // Atribui o CPF recuperado ou string vazia se nulo
      cpf: (map['cpf'] ?? '').toString(),
      // Atribui o telefone recuperado ou string vazia se nulo
      telefone: (map['telefone'] ?? '').toString(),
      // Atribui o endereço residencial recuperado ou string vazia se nulo
      enderecoPaciente: (map['enderecoPaciente'] ?? '').toString(),
      // Atribui a unidade médica de consulta ou string vazia se nulo
      localConsulta: (map['localConsulta'] ?? '').toString(),
      // Atribui o ponto de saída, assumindo 'Residência' como padrão amigável caso nulo
      localSaida: (map['localSaida'] ?? 'Residência').toString(),
      // Atribui o horário agendado da consulta ou string vazia se nulo
      horarioConsulta: (map['horarioConsulta'] ?? '').toString(),
      // Atribui o código de status validado e convertido em inteiro
      status: statusInt,
      // Converte o nome do acompanhante para String ou preserva null se ausente
      nomeAcompanhante: map['nomeAcompanhante']?.toString(),
      // Converte o telefone do acompanhante para String ou preserva null se ausente
      telAcompanhante: map['telAcompanhante']?.toString(),
      cpfAcompanhante: map['cpfAcompanhante']?.toString(),
      rg: map['rg']?.toString(),
      cnh: map['cnh']?.toString(),
      // Atribui o papel de permissão com fallback padrão para 'paciente'
      role: (map['role'] ?? 'paciente').toString(),
      // Avalia 'ativo' com tolerância a booleano verdadeiro, nulo (ativo por padrão) ou 'true'
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      // Desserializa a data de criação através da função resiliente '_parsearData'
      criadoEm: _parsearData(map['criadoEm']),
    // Fecha a chamada do construtor de PacienteModel
    );
  // Fecha o bloco de instruções do construtor factory fromMap
  }

// Fecha a declaração do corpo da classe PacienteModel
}
