// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/motorista_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula as informações operacionais, cadastrais e de habilitação
// de um Motorista do transporte de saúde, estruturando atributos imutáveis e
// fornecendo métodos de serialização (toMap) e desserialização (fromMap).
//
// PARA QUE SERVE NO PROJETO:
// Representa a entidade de motorista que conduz as viagens TFD, associando
// seus dados de identificação funcional (CNH, CPF), veículo habitual, status
// de disponibilidade ('emViagem') e permissões no sistema.
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (obtenção e exibição dos dados do motorista logado)
// - lib/lista_pessoas.dart (listagem e filtros da equipe de motoristas)
// - lib/components/motorista_header.dart (cabeçalho visual com dados do motorista)
// - test/components/motorista_header_test.dart (testes unitários do cabeçalho)
// - test/lista_pessoas_test.dart (testes de renderização e busca de motoristas)
//
// DE ONDE RECEBE DADOS:
// Documentos NoSQL do Firebase Firestore (coleção 'usuarios' ou 'motoristas'),
// processados pela fábrica 'MotoristaModel.fromMap'.
//
// O QUE EXPORTA / EXPÕE:
// - class MotoristaModel: entidade imutável de dados do motorista
// - Atributos: id, nome, cpf, telefone, email, cnh, veiculoModelo, veiculoPlaca,
//   capacidadeVeiculo, emViagem, role, ativo, criadoEm
// - Construtor nomeado padrão MotoristaModel(...)
// - Map<String, dynamic> toMap(): conversão para formato persistível no Firestore
// - factory MotoristaModel.fromMap(Map, {docId}): desserialização com fallbacks
//
// ORIGEM HISTÓRICA:
// Criado pela equipe de desenvolvimento no commit ccbbe0e e expandido nas
// sprints de gestão de viagens e autenticação. Não provém de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Utiliza estritamente os tipos padrão do Dart SDK (sem pacotes externos).
// É uma entidade pura de dados em memória: sem I/O, rede ou estado global.
// ============================================================================

// Linha em branco separadora entre o cabeçalho descritivo do arquivo e a declaração da classe
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE MODELO DE DADOS: MotoristaModel
// - O que a instrução faz: Declara formalmente a classe imutável representativa de um Motorista.
// - O que é o elemento: Classe de domínio / Data Transfer Object (DTO) imutável.
// - Papel arquitetural: Modela a entidade de negócio responsável pela condução dos veículos
//   municipais de transporte de pacientes (TFD), concentrando dados de habilitação, veículo e status.
// - De onde vem: Escrita especificamente para a regra de negócio do TransSaúde.
// - Conexões no sistema: Utilizada em 'lib/motorista.dart', 'lib/components/motorista_header.dart'
//   e 'lib/lista_pessoas.dart', permitindo vincular o condutor às viagens registradas.
// - Efeitos colaterais: Nenhum. É uma declaração de tipo puro sem alocação ou mutação de estado.
// ----------------------------------------------------------------------------
class MotoristaModel {
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: id
  // - O que a linha faz: Declara a chave primária de identificação do motorista.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Corresponde ao Document ID no Firestore ou ao UID do Firebase Auth,
  //   sendo a chave relacional que conecta o condutor aos documentos da coleção 'viagens'.
  // - Conexões: Utilizado em queries como 'where("motoristaId", isEqualTo: id)'.
  // --------------------------------------------------------------------------
  final String id;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: nome
  // - O que a linha faz: Declara o nome completo do motorista municipal.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Exibido no cabeçalho superior da tela de operação ('MotoristaHeader'),
  //   na ficha impressa do Roteiro de Viagem TFD e na escala administrativa de condutores.
  // - Conexões: Renderizado em 'lib/components/motorista_header.dart' e pesquisável por texto.
  // --------------------------------------------------------------------------
  final String nome;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: cpf
  // - O que a linha faz: Declara o registro de Cadastro de Pessoa Física do motorista.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Credencial de acesso para autenticação no aplicativo móvel
  //   e identificador funcional único para conferência junto aos registros de recursos humanos.
  // - Conexões: Sanitizado em 'lib/services/auth_service.dart' para permitir login via CPF.
  // --------------------------------------------------------------------------
  final String cpf;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: telefone
  // - O que a linha faz: Declara o número telefônico para chamadas e mensagens operacionais.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Permite contato telefônico imediato da central de agendamento ou
  //   de pacientes caso ocorram imprevistos, atrasos de retorno ou emergências no trajeto.
  // - Conexões: Exibido nos cartões de detalhamento de pessoas em 'lib/lista_pessoas.dart'.
  // --------------------------------------------------------------------------
  final String telefone;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: email
  // - O que a linha faz: Declara o endereço de correio eletrônico cadastrado do condutor.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Usado como chave de autenticação interna no Firebase Auth e canal
  //   institucional para comunicações de escalas e avisos da Secretaria de Saúde.
  // --------------------------------------------------------------------------
  final String email;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: cnh
  // - O que a linha faz: Declara o número de registro da Carteira Nacional de Habilitação.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Documento de porte obrigatório para regularidade jurídica do condutor;
  //   permite à gestão municipal auditar a validade e a categoria adequada de condução.
  // - Conexões: Apresentado na listagem de motoristas para validação de conformidade legal.
  // --------------------------------------------------------------------------
  final String cnh;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: veiculoModelo
  // - O que a linha faz: Declara a especificação e modelo do veículo atribuído habitualmente.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Facilita o preenchimento prévio na tela de início de viagem,
  //   associando o condutor ao seu veículo costumeiro (ex.: Spin, Van, Micro-ônibus).
  // - Conexões: Exibido no cabeçalho do motorista e utilizado como sugestão no formulário.
  // --------------------------------------------------------------------------
  final String veiculoModelo;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: veiculoPlaca
  // - O que a linha faz: Declara a placa identificadora de trânsito do veículo atribuído.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Identificador de trânsito utilizado para cruzamento de dados com
  //   a frota de veículos ('VeiculoModel'), permitindo verificar o status de uso do automóvel.
  // - Conexões: Exibida em 'MotoristaHeader' e vinculada à inicialização de novas viagens.
  // --------------------------------------------------------------------------
  final String veiculoPlaca;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: capacidadeVeiculo
  // - O que a linha faz: Declara a quantidade máxima de passageiros que o veículo suporta.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo número inteiro ('int').
  // - Papel no sistema: Limite operacional de lotação utilizado para impedir sobrecarga de
  //   pacientes agendados em uma única viagem municipal de saúde.
  // - Conexões: Validado pelo serviço de validação de viagem ('ValidacaoViagem').
  // --------------------------------------------------------------------------
  final int capacidadeVeiculo;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: emViagem
  // - O que a linha faz: Declara a bandeira de status operacional em trânsito do motorista.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo booleano ('bool').
  // - Papel no sistema: 'true' sinaliza que o condutor possui viagem em andamento, impedindo
  //   o início de uma nova viagem simultânea e alterando o estado visual da tela inicial.
  // - Conexões: Sincronizado em tempo real pelo 'ViagemService' e ouvido pela tela 'Motorista'.
  // --------------------------------------------------------------------------
  final bool emViagem;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: role
  // - O que a linha faz: Declara o identificador do papel funcional no controle de acesso (RBAC).
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Estabelece o nível de permissão; fixado como 'motorista' para autorizar
  //   a navegação exclusiva nas rotas e módulos operacionais da frota de transporte.
  // - Conexões: Avaliado pelo 'RouteGuard' para permitir acesso à tela '/motorista'.
  // --------------------------------------------------------------------------
  final String role;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: ativo
  // - O que a linha faz: Declara a situação de vínculo ativo ou inativo do cadastro.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo booleano ('bool').
  // - Papel no sistema: Permite desligar temporariamente ou suspender o acesso de motoristas
  //   afastados ou de férias sem excluir o histórico de viagens passadas do banco de dados.
  // - Conexões: Utilizado nos filtros de exibição de condutores ativos em 'lib/lista_pessoas.dart'.
  // --------------------------------------------------------------------------
  final bool ativo;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: criadoEm
  // - O que a linha faz: Declara o registro cronológico de cadastro do motorista no sistema.
  // - O que é o elemento: Campo imutável ('final') do tipo 'DateTime?', opcional/anulável.
  // - Papel no sistema: Suporta auditoria cadastral e relatórios administrativos de antiguidade.
  // --------------------------------------------------------------------------
  final DateTime? criadoEm;

  // Senha de acesso operacional persistida no documento da coleção 'usuarios'
  final String? senha;

  // Linha em branco separadora entre a declaração dos atributos e o construtor principal

  // --------------------------------------------------------------------------
  // CONSTRUTOR PADRÃO COM PARÂMETROS NOMEADOS: MotoristaModel
  // - O que faz: Inicializa todos os campos de uma instância imutável de MotoristaModel.
  // - O que é: Construtor generativo com parâmetros obrigatórios e padrões opcionais de segurança.
  // - Papel: Garante a criação de objetos consistentes para exibição e persistência.
  // --------------------------------------------------------------------------
  MotoristaModel({
    // Parâmetro obrigatório: Identificador único no Firestore
    required this.id,
    // Parâmetro obrigatório: Nome completo do motorista
    required this.nome,
    // Parâmetro obrigatório: CPF do condutor
    required this.cpf,
    // Parâmetro obrigatório: Telefone de contato
    required this.telefone,
    // Parâmetro obrigatório: E-mail cadastrado
    required this.email,
    // Parâmetro obrigatório: Número de registro da CNH
    required this.cnh,
    // Parâmetro obrigatório: Descrição do modelo do veículo
    required this.veiculoModelo,
    // Parâmetro obrigatório: Placa oficial do veículo
    required this.veiculoPlaca,
    // Parâmetro opcional: Lotação do veículo com fallback padrão para 4 assentos
    this.capacidadeVeiculo = 4,
    // Parâmetro opcional: Status de viagem ativa assumindo 'false' por padrão
    this.emViagem = false,
    // Parâmetro opcional: Papel de acesso assumindo 'motorista' por padrão
    this.role = 'motorista',
    // Parâmetro opcional: Indicador de conta ativa assumindo 'true' por padrão
    this.ativo = true,
    // Parâmetro opcional: Data e hora de criação do registro no Firestore
    this.criadoEm,
    // Parâmetro opcional: Senha de acesso operacional
    this.senha,
  // Fecha a lista de parâmetros formais nomeados do construtor
  });

  // Linha em branco separadora entre o construtor e o método de serialização
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Salvar no Firebase
  // ----------------------------------------------------------------------------
  // MÉTODO DE SERIALIZAÇÃO: toMap
  // - O que faz: Converte o objeto MotoristaModel em uma estrutura do tipo Map<String, dynamic>.
  // - O que é o elemento: Método de instância público para persistência em bancos NoSQL.
  // - Retorno: Map contendo todas as propriedades prontas para inclusão/atualização no Firestore.
  // - Papel no sistema: Centraliza o contrato de campos da coleção 'usuarios' ou 'motoristas'.
  // ----------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    // ------------------------------------------------------------------------
    // Retorna a representação de dicionário Map com as chaves esperadas pelo Firestore:
    // ------------------------------------------------------------------------
    return {
      // Mapeia o nome civil para a chave 'nome'
      'nome': nome,
      // Mapeia o documento de CPF para a chave 'cpf'
      'cpf': cpf,
      // Mapeia o telefone de contato para a chave 'telefone'
      'telefone': telefone,
      // Mapeia o e-mail cadastrado para a chave 'email'
      'email': email,
      // Mapeia a habilitação de trânsito para a chave 'cnh'
      'cnh': cnh,
      // Mapeia o modelo usual do veículo para a chave 'veiculoModelo'
      'veiculoModelo': veiculoModelo,
      // Mapeia a placa do veículo para a chave 'veiculoPlaca'
      'veiculoPlaca': veiculoPlaca,
      // Mapeia o número inteiro de assentos para a chave 'capacidadeVeiculo'
      'capacidadeVeiculo': capacidadeVeiculo,
      // Mapeia o indicador de viagem em andamento para a chave 'emViagem'
      'emViagem': emViagem,
      // Mapeia o papel de controle de acesso para a chave 'role'
      'role': role,
      // Mapeia o status da conta para a chave 'ativo'
      'ativo': ativo,
      // Mapeia a data de criação convertida para ISO-8601 se não for nula
      'criadoEm': criadoEm?.toIso8601String(),
      if (senha != null && senha!.isNotEmpty) 'senha': senha,
    // Fecha a declaração do mapa literal
    };
  // Fecha o bloco de instruções do método toMap
  }

  // Linha em branco separadora entre métodos de instância e utilitário de conversão de data

  // ----------------------------------------------------------------------------
  // FUNÇÃO UTILITÁRIA PRIVADA ESTÁTICA: _parsearData
  // - O que faz: Converte valores de tipos arbitrários ('dynamic') para 'DateTime?'.
  // - O que é: Método defensivo resiliente para interpretação de datas de diferentes fontes.
  // - Suporte abrangente: Trata 'Timestamp' nativo do Firestore, instâncias 'DateTime' e strings ISO.
  // - Retorno: 'DateTime' tipado ou 'null' em caso de falha de conversão.
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
  // Fecha o bloco de instruções da função estática _parsearData
  }

  // Linha em branco separadora entre a função de data e o construtor de fábrica
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Ler do Firebase
  // ----------------------------------------------------------------------------
  // CONSTRUTOR FACTORY (FÁBRICA DE DESSERIALIZAÇÃO): MotoristaModel.fromMap
  // - O que faz: Constrói uma instância fortemente tipada de MotoristaModel a partir de um Map.
  // - O que é: Construtor factory defensivo com conversão segura de tipos numéricos e booleanos.
  // - Parâmetros: 'map' (dados brutos do documento) e 'docId' opcional (ID do documento Firestore).
  // - Papel no sistema: Protege a aplicação contra valores corrompidos ou tipos trocados no banco.
  // ----------------------------------------------------------------------------
  factory MotoristaModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // ------------------------------------------------------------------------
    // Extrai o valor bruto associado à capacidade de passageiros do veículo:
    // ------------------------------------------------------------------------
    final capRaw = map['capacidadeVeiculo'];

    // ------------------------------------------------------------------------
    // Realiza a conversão segura para inteiro:
    // Se o valor for 'num', converte via '.toInt()'; se for string ou outro, tenta 'int.tryParse'
    // com fallback seguro para 4 assentos caso o dado seja nulo ou inválido:
    // ------------------------------------------------------------------------
    final int capInt = (capRaw is num)
        // Converte diretamente instâncias numéricas (int ou double) para inteiro
        ? capRaw.toInt()
        // Tenta interpretar representação textual ou assume 4 como lotação padrão
        : (int.tryParse(capRaw?.toString() ?? '') ?? 4);

    // Linha em branco separadora entre a normalização de variáveis e a instanciação

    // ------------------------------------------------------------------------
    // Cria e retorna a instância de MotoristaModel com cada campo sanitizado:
    // ------------------------------------------------------------------------
    return MotoristaModel(
      // Atribui o identificador do documento ou string vazia se nulo
      id: docId ?? '',
      // Atribui o nome recuperado ou string vazia se nulo
      nome: (map['nome'] ?? '').toString(),
      // Atribui o CPF recuperado ou string vazia se nulo
      cpf: (map['cpf'] ?? '').toString(),
      // Atribui o telefone recuperado ou string vazia se nulo
      telefone: (map['telefone'] ?? '').toString(),
      // Atribui o e-mail recuperado ou string vazia se nulo
      email: (map['email'] ?? '').toString(),
      // Atribui a CNH recuperada ou string vazia se nulo
      cnh: (map['cnh'] ?? '').toString(),
      // Atribui a descrição do modelo do veículo ou string vazia se nulo
      veiculoModelo: (map['veiculoModelo'] ?? '').toString(),
      // Atribui a placa do veículo ou string vazia se nulo
      veiculoPlaca: (map['veiculoPlaca'] ?? '').toString(),
      // Atribui a capacidade sanitizada em inteiro
      capacidadeVeiculo: capInt,
      // Interpreta 'emViagem' aceitando booleano verdadeiro ou string 'true'
      emViagem: map['emViagem'] == true || map['emViagem'] == 'true',
      // Atribui o papel de permissão com fallback padrão para 'motorista'
      role: (map['role'] ?? 'motorista').toString(),
      // Interpreta 'ativo' com tolerância a booleano, nulo (ativo por padrão) ou 'true'
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      // Desserializa a data de criação através da função resiliente '_parsearData'
      criadoEm: _parsearData(map['criadoEm']),
      senha: map['senha']?.toString(),
    // Fecha a lista de argumentos passados ao construtor MotoristaModel
    );
  // Fecha o bloco de instruções do construtor factory fromMap
  }

// Fecha a declaração do corpo da classe MotoristaModel
}
