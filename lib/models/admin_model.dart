// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/admin_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula os dados cadastrais e de privilégio de um Administrador
// da Secretaria Municipal de Saúde, fornecendo propriedades imutáveis e
// métodos de serialização (toMap) e desserialização (fromMap) para o Firebase.
//
// PARA QUE SERVE NO PROJETO:
// Permite a manipulação tipada de administradores no sistema, estruturando os
// atributos necessários para a gestão de acessos, listagem de equipe e
// auditoria de contas do sistema de transporte de pacientes (TFD).
//
// ONDE É USADO NO PROJETO:
// - lib/lista_pessoas.dart (exibição da listagem de administradores cadastrados)
// - test/lista_pessoas_test.dart (testes unitários e de widget da tela de pessoas)
//
// DE ONDE RECEBE DADOS:
// Documentos serializados em JSON/Map obtidos do Firebase Firestore (coleção
// de usuários com role 'admin') ou instâncias mockadas em cenários de teste.
//
// O QUE EXPORTA / EXPÕE:
// - class AdminModel: classe de modelo imutável
// - Atributos: id, nome, cpf, email, telefone, role, ativo, criadoEm
// - Construtor nomeado padrão AdminModel(...)
// - Map<String, dynamic> toMap(): converte para formato aceito no Firestore
// - factory AdminModel.fromMap(Map, {docId}): reconstrói objeto a partir do Firestore
//
// ORIGEM HISTÓRICA:
// Criado especificamente pela equipe de desenvolvimento no commit ccbbe0e para
// unificar os modelos cadastrais no Firestore. Não provém de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Utiliza tipos primitivos e estruturas nativas do Dart SDK (sem pacotes externos).
// É uma classe de dados pura: sem efeitos colaterais, sem alteração de estado global.
// ============================================================================

// Linha em branco separadora entre o cabeçalho descritivo do arquivo e a declaração da classe
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE MODELO DE DADOS: AdminModel
// - O que a instrução faz: Declara formalmente a classe imutável representativa de um Administrador.
// - O que é o elemento: Classe de dados (Data Transfer Object / Entity) de domínio.
// - Papel arquitetural: Define o contrato estrutural e a tipagem dos dados cadastrais de
//   usuários administradores gerenciados pela Secretaria Municipal de Saúde de Poloni.
// - De onde vem: Escrita especificamente para a arquitetura de autenticação e RBAC do TransSaúde.
// - Conexões no sistema: Consumida por 'lib/lista_pessoas.dart' para gerenciamento de
//   usuários da equipe administrativa e validada nos testes de 'test/lista_pessoas_test.dart'.
// - Efeitos colaterais: Nenhum. É uma declaração de tipo puro sem alocação ou mutação de estado.
// ----------------------------------------------------------------------------
class AdminModel {
  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: id
  // - O que a linha faz: Declara o identificador primário exclusivo do administrador no sistema.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Corresponde à chave primária (Document ID) no Cloud Firestore ou ao UID
  //   gerado pelo Firebase Authentication. Permite operações atômicas de atualização e exclusão.
  // - Conexões: Utilizado como 'Key' em listas visuais no Flutter e em comparações de identidade.
  // - De onde vem: Mapeado a partir do parâmetro nomeado 'docId' do construtor factory 'fromMap'.
  // --------------------------------------------------------------------------
  final String id;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: nome
  // - O que a linha faz: Declara o campo de armazenamento do nome civil completo do usuário.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Usado para exibição nominal na barra superior (AppBar), crachás,
  //   relatórios de auditoria e listagens de gestão de servidores municipais.
  // - Conexões: Exibido nos cards informativos de 'lib/lista_pessoas.dart' e pesquisável por texto.
  // --------------------------------------------------------------------------
  final String nome;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: cpf
  // - O que a linha faz: Declara o número do Cadastro de Pessoas Físicas do administrador.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Funciona como chave de identificação funcional e credencial de login
  //   na tela de autenticação, podendo conter 11 dígitos numéricos ou máscara '000.000.000-00'.
  // - Conexões: Sanitizado em 'lib/services/auth_service.dart' e pesquisado em buscas textuais.
  // --------------------------------------------------------------------------
  final String cpf;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: email
  // - O que a linha faz: Declara o endereço eletrônico institucional do administrador.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Utilizado para comunicações oficiais, recuperação de acesso e
  //   vinculação direta com a conta de e-mail no provedor Firebase Authentication.
  // - Conexões: Apresentado no detalhamento de perfil e utilizado para validação cadastral.
  // --------------------------------------------------------------------------
  final String email;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: telefone
  // - O que a linha faz: Declara o número de telefone de contato móvel ou fixo do administrador.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Canal de comunicação emergencial entre a central administrativa,
  //   motoristas em trânsito e o plantão da Unidade Básica de Saúde.
  // - Conexões: Exibido nos cartões de contato da tela de listagem de pessoas.
  // --------------------------------------------------------------------------
  final String telefone;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: role
  // - O que a linha faz: Declara o identificador textual do papel de controle de acesso (RBAC).
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo 'String'.
  // - Papel no sistema: Define o nível de permissão; no caso desta entidade, possui o valor fixo
  //   'admin', concedendo acesso irrestrito às funcionalidades de gestão do TransSaúde.
  // - Conexões: Avaliado pelo 'RouteGuard' para permitir acesso a rotas administrativas ('/admin').
  // --------------------------------------------------------------------------
  final String role;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: ativo
  // - O que a linha faz: Declara o indicador de situação cadastral e operacional da conta.
  // - O que é o elemento: Campo imutável ('final') do tipo primitivo booleano ('bool').
  // - Papel no sistema: 'true' indica administrador em pleno exercício; 'false' representa
  //   conta inativada ou suspensa, impedindo login ou autorização de rotas protegidas.
  // - Conexões: Utilizado em filtros visuais de listagem de pessoas ativas vs. inativas.
  // --------------------------------------------------------------------------
  final bool ativo;

  // --------------------------------------------------------------------------
  // ATRIBUTO DE INSTÂNCIA: criadoEm
  // - O que a linha faz: Declara o registro cronológico de quando a conta foi criada no sistema.
  // - O que é o elemento: Campo imutável ('final') do tipo 'DateTime?', opcional/anulável.
  // - Papel no sistema: Permite auditoria temporal, ordenação histórica de cadastros e relatórios.
  // - Conexões: Deserializado a partir de Timestamp do Firestore ou string ISO-8601 por '_parsearData'.
  // --------------------------------------------------------------------------
  final DateTime? criadoEm;

  // Linha em branco separadora entre a declaração dos atributos e o construtor principal

  // --------------------------------------------------------------------------
  // CONSTRUTOR PADRÃO COM PARÂMETROS NOMEADOS: AdminModel
  // - O que faz: Instancia um objeto imutável de AdminModel atribuindo valores a todas as propriedades.
  // - O que é: Construtor generativo com parâmetros nomeados obrigatórios ('required') e opcionais com padrão.
  // - Papel arquitetural: Garante integridade referencial impedindo a criação de instâncias incompletas.
  // - Conexões: Chamado explicitamente em testes de widget e pelo factory 'AdminModel.fromMap'.
  // --------------------------------------------------------------------------
  AdminModel({
    // ------------------------------------------------------------------------
    // PARÂMETRO: id
    // - O que faz: Atribui o identificador único fornecido ao campo 'this.id'.
    // - Modificador: 'required' (obrigatório em tempo de compilação).
    // ------------------------------------------------------------------------
    required this.id,

    // ------------------------------------------------------------------------
    // PARÂMETRO: nome
    // - O que faz: Atribui o nome civil completo do administrador ao campo 'this.nome'.
    // - Modificador: 'required' (obrigatório em tempo de compilação).
    // ------------------------------------------------------------------------
    required this.nome,

    // ------------------------------------------------------------------------
    // PARÂMETRO: cpf
    // - O que faz: Atribui o CPF fornecido ao campo 'this.cpf'.
    // - Modificador: 'required' (obrigatório em tempo de compilação).
    // ------------------------------------------------------------------------
    required this.cpf,

    // ------------------------------------------------------------------------
    // PARÂMETRO: email
    // - O que faz: Atribui o endereço de correio eletrônico fornecido ao campo 'this.email'.
    // - Modificador: 'required' (obrigatório em tempo de compilação).
    // ------------------------------------------------------------------------
    required this.email,

    // ------------------------------------------------------------------------
    // PARÂMETRO: telefone
    // - O que faz: Atribui o telefone de contato fornecido ao campo 'this.telefone'.
    // - Modificador: 'required' (obrigatório em tempo de compilação).
    // ------------------------------------------------------------------------
    required this.telefone,

    // ------------------------------------------------------------------------
    // PARÂMETRO OPCIONAL: role
    // - O que faz: Atribui o papel funcional ao campo 'this.role', assumindo 'admin' por padrão.
    // - Valor padrão: 'admin' (garante que instâncias desta classe sejam sempre administradoras).
    // ------------------------------------------------------------------------
    this.role = 'admin',

    // ------------------------------------------------------------------------
    // PARÂMETRO OPCIONAL: ativo
    // - O que faz: Atribui a situação cadastral ao campo 'this.ativo', assumindo 'true' por padrão.
    // - Valor padrão: true (uma nova conta é assumida como ativa por padrão).
    // ------------------------------------------------------------------------
    this.ativo = true,

    // ------------------------------------------------------------------------
    // PARÂMETRO OPCIONAL: criadoEm
    // - O que faz: Atribui a data e hora de registro ou 'null' se ainda não persistida no banco.
    // - Tipo: 'DateTime?' (permite ausência de valor na criação inicial).
    // ------------------------------------------------------------------------
    this.criadoEm,

  // Fecha a lista de parâmetros formais nomeados do construtor AdminModel
  });

  // Linha em branco separadora entre o construtor da classe e o método de serialização
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Salvar no Firebase
  // ----------------------------------------------------------------------------
  // MÉTODO DE SERIALIZAÇÃO: toMap
  // - O que faz: Converte o objeto AdminModel em uma estrutura do tipo Map<String, dynamic>.
  // - O que é o elemento: Método de instância público de serialização de dados.
  // - Retorno: Map<String, dynamic> pronto para ser enviado via 'set' ou 'update' ao Firestore.
  // - Papel no sistema: Isola os detalhes de mapeamento de banco de dados dentro do próprio modelo,
  //   garantindo que qualquer alteração de schema seja mantida em um único ponto do código.
  // - De onde vem: Padrão arquitetural de DTO amplamente adotado no ecossistema Flutter/Firebase.
  // ----------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    // ------------------------------------------------------------------------
    // Retorna a estrutura literal de dicionário Map com os pares chave/valor correspondentes:
    // ------------------------------------------------------------------------
    return {
      // Chave 'nome' associada ao valor do atributo 'nome' da instância
      'nome': nome,
      // Chave 'cpf' associada ao valor do atributo 'cpf' da instância
      'cpf': cpf,
      // Chave 'email' associada ao valor do atributo 'email' da instância
      'email': email,
      // Chave 'telefone' associada ao valor do atributo 'telefone' da instância
      'telefone': telefone,
      // Chave 'role' associada ao valor do atributo 'role' da instância (sempre 'admin')
      'role': role,
      // Chave 'ativo' associada ao indicador booleano de atividade da conta
      'ativo': ativo,
      // Chave 'criadoEm' serializada em formato de texto ISO-8601 (ex.: 2026-11-06T10:00:00Z) se não for nula
      'criadoEm': criadoEm?.toIso8601String(),
    // Fecha a declaração do mapa literal de pares chave/valor
    };
  // Fecha o corpo de instruções do método de serialização toMap
  }

  // Linha em branco separadora entre o método toMap e a rotina auxiliar de conversão de data

  // ----------------------------------------------------------------------------
  // FUNÇÃO UTILITÁRIA PRIVADA ESTÁTICA: _parsearData
  // - O que faz: Converte com resiliência valores dinâmicos ('dynamic') para instâncias de 'DateTime?'.
  // - O que é o elemento: Método estático auxiliar privado com múltiplos fallbacks defensivos.
  // - Por que foi criada assim: O Cloud Firestore pode retornar datas em formatos heterogêneos:
  //   como instâncias nativas de 'Timestamp' do SDK, instâncias 'DateTime' já desserializadas,
  //   ou strings textuais em formato ISO-8601 serializadas em chamadas REST ou testes.
  // - Parâmetro recebido: 'valor' (dynamic) podendo ser nulo, Timestamp, DateTime, String ou número.
  // - Retorno: Retorna a instância tipada 'DateTime' correspondente ou 'null' se o parse falhar.
  // - Efeitos colaterais: Nenhum. Executa parsing determinístico sem mutação de estado.
  // ----------------------------------------------------------------------------
  static DateTime? _parsearData(dynamic valor) {
    // ------------------------------------------------------------------------
    // Caso base de nulidade: se o valor informado for nulo, retorna imediatamente 'null'.
    // ------------------------------------------------------------------------
    if (valor == null) return null;

    // ------------------------------------------------------------------------
    // Caso de tipo idêntico: se o valor já for uma instância válida de DateTime, retorna diretamente.
    // ------------------------------------------------------------------------
    if (valor is DateTime) return valor;

    // ------------------------------------------------------------------------
    // Tentativa 1: Suporte a instâncias de 'Timestamp' do Cloud Firestore:
    // Utiliza reflexão dinâmica defensiva para invocar '.toDate()' caso o objeto seja um Timestamp.
    // ------------------------------------------------------------------------
    try {
      // Executa chamada dinâmica para o método toDate() característico do Firestore Timestamp
      return (valor as dynamic).toDate() as DateTime;
    // Captura NoSuchMethodError, TypeError ou exceções em tempo de execução sem interromper o fluxo
    } catch (_) {}

    // ------------------------------------------------------------------------
    // Tentativa 2: Suporte a strings em formato padrão ISO-8601:
    // Converte o valor dinâmico para String e tenta o parsing via DateTime.tryParse.
    // ------------------------------------------------------------------------
    try {
      // Tenta interpretar o texto como data ISO-8601; retorna nulo se o formato for inválido
      return DateTime.tryParse(valor.toString());
    // Captura qualquer exceção inesperada durante a conversão em string
    } catch (_) {}

    // ------------------------------------------------------------------------
    // Fallback defensivo final: se nenhuma conversão foi possível, retorna 'null' com segurança.
    // ------------------------------------------------------------------------
    return null;

  // Fecha o corpo de execução da função utilitária estática _parsearData
  }

  // Linha em branco separadora entre a função de parsing e o construtor factory
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Ler do Firebase
  // ----------------------------------------------------------------------------
  // CONSTRUTOR FACTORY (FÁBRICA DE DESSERIALIZAÇÃO): AdminModel.fromMap
  // - O que faz: Reconstrói uma instância fortemente tipada de AdminModel a partir de um Map.
  // - O que é o elemento: Construtor de fábrica ('factory constructor') com parâmetro posicional e nomeado.
  // - Parâmetros recebidos:
  //   * 'map' (Map<String, dynamic>): Dicionário com os dados brutos recuperados do documento Firestore.
  //   * 'docId' (String?, opcional): O identificador alfanumérico exclusivo do documento no Firestore.
  // - Retorno: Nova instância de 'AdminModel' com todos os campos validados e com fallbacks defensivos.
  // - Papel no sistema: Protege a aplicação contra valores ausentes ('null') ou tipos inesperados
  //   no banco de dados, convertendo valores com segurança para String, boolean ou DateTime.
  // ----------------------------------------------------------------------------
  factory AdminModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // ------------------------------------------------------------------------
    // Instancia e retorna o AdminModel aplicando sanitização defensiva em cada atributo:
    // ------------------------------------------------------------------------
    return AdminModel(
      // Atribui o ID do documento fornecido ou uma string vazia caso seja nulo
      id: docId ?? '',
      // Recupera 'nome', tratando nulidade com fallback para string vazia
      nome: (map['nome'] ?? '').toString(),
      // Recupera 'cpf', tratando nulidade com fallback para string vazia
      cpf: (map['cpf'] ?? '').toString(),
      // Recupera 'email', tratando nulidade com fallback para string vazia
      email: (map['email'] ?? '').toString(),
      // Recupera 'telefone', tratando nulidade com fallback para string vazia
      telefone: (map['telefone'] ?? '').toString(),
      // Recupera 'role', assumindo 'admin' como fallback padrão seguro
      role: (map['role'] ?? 'admin').toString(),
      // Converte o campo 'ativo' para booleano com tolerância a booleano verdadeiro, nulo ou string 'true'
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      // Converte o campo 'criadoEm' utilizando a função estática defensiva '_parsearData'
      criadoEm: _parsearData(map['criadoEm']),
    // Fecha a lista de argumentos passados ao construtor AdminModel
    );
  // Fecha o bloco de execução do construtor de fábrica fromMap
  }

// Fecha a declaração do corpo da classe de modelo AdminModel
}
