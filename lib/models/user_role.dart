// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/user_role.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Centraliza a enumeração de perfis de usuário do sistema TransSaúde, definindo
// os tipos de papéis suportados (Administrador, Motorista e Paciente), seus
// identificadores textuais gravados no Firebase e métodos utilitários de
// conversão a partir de strings puras.
//
// PARA QUE SERVE NO PROJETO:
// Garante tipagem estática e segurança na validação de permissões de acesso
// (Role-Based Access Control - RBAC) em todo o fluxo de autenticação,
// redirecionamento de telas e proteção de rotas no aplicativo.
//
// ONDE É USADO NO PROJETO:
// - lib/services/auth_service.dart (resolução de role após login no Firebase)
// - lib/routes/route_guard.dart (bloqueio e autorização de navegação em rotas)
// - lib/screens/auth_gate.dart (direcionamento inicial com base no papel do usuário)
// - lib/screens/login_screen.dart (opções e validação de perfil de login)
// - test/services/auth_service_test.dart (testes unitários de autenticação)
// - test/screens/auth_gate_test.dart (testes de máquina de estados de roteamento)
// - test/screens/login_screen_test.dart (testes visuais de formulário de login)
//
// DE ONDE RECEBE DADOS:
// Strings de papéis vindas do Firebase Firestore (campo 'role' das coleções de usuários)
// ou de parâmetros informados via código durante a inicialização/navegação.
//
// O QUE EXPORTA / EXPÕE:
// - enum UserRole: admin, motorista, paciente
// - String valor: texto padronizado em minúsculas armazenado no banco
// - String label: texto amigável formatado para apresentação na interface
// - static UserRole fromString(String? role): método utilitário para desserialização
//
// ORIGEM HISTÓRICA:
// Criado especificamente pela equipe de desenvolvimento do projeto no commit ccbbe0e
// e ampliado nas rotas de autenticação (PR #59/#60). Não provém de scaffold automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Dependência estrita do core do Dart (sem pacotes de terceiros).
// Arquivo imutável e puro: não executa I/O, chamadas de rede nem altera estado global.
// ============================================================================

// Linha em branco separadora entre o cabeçalho descritivo do arquivo e os comentários da enumeração
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
/// Perfis de acesso do aplicativo
// ----------------------------------------------------------------------------
// DECLARAÇÃO DO TIPO ENUMERADO PRINCIPAL:
// - O que é: Uma 'enhanced enum' (enumeração avançada) introduzida no Dart 2.17.
// - Papel arquitetural: Define o catálogo fechado e canônico de papéis de usuário
//   reconhecidos pelo sistema de autorização e controle de acesso baseado em papéis (RBAC).
// - Por que foi criada assim: Permite associar campos de instância final ('valor' e 'label')
//   e construtores 'const' diretamente a cada elemento da enum, dispensando estruturas
//   complexas de mapeamento manual (Map<String, String>) ou classes de constante isoladas.
// - Vínculos com o projeto:
//   * Consumida por 'lib/services/auth_service.dart' para definir o perfil do usuário logado.
//   * Verificada por 'lib/routes/route_guard.dart' para permitir ou barrar transições de tela.
//   * Avaliada por 'lib/screens/auth_gate.dart' para despachar a tela inicial correspondente.
// - Efeitos colaterais: Nenhum. É uma declaração de tipo puro em tempo de compilação.
enum UserRole {
  // --------------------------------------------------------------------------
  // CONSTANTE ENUMERADA: admin
  // - O que faz: Instancia e registra o membro singleton que representa o Administrador.
  // - O que é: Membro constante da enumeração com invocação do construtor posicional const.
  // - Argumentos passados:
  //   1º 'admin' (String): O identificador de máquina gravado na propriedade 'role'
  //      do documento de usuário na coleção 'usuarios' ou 'admins' do Firestore.
  //   2º 'Administrador' (String): O rótulo formatado em linguagem natural para exibição
  //      na interface gráfica do usuário (menus, appbars, relatórios e seletores).
  // - Papel no sistema: Confere autorização irrestrita (superusuário), concedendo
  //   permissão de acesso a dashboards de controle, rotas '/admin', relatórios de
  //   viagens e cadastros de novos motoristas, veículos e pacientes.
  // - De onde vem: Escrita especificamente para a arquitetura de autenticação da PR #59.
  // --------------------------------------------------------------------------
  admin('admin', 'Administrador'),

  // --------------------------------------------------------------------------
  // CONSTANTE ENUMERADA: motorista
  // - O que faz: Instancia e registra o membro singleton que representa o Motorista.
  // - O que é: Membro constante da enumeração com invocação do construtor posicional const.
  // - Argumentos passados:
  //   1º 'motorista' (String): Chave textual persistida no banco Firestore ('role': 'motorista').
  //   2º 'Motorista' (String): Rótulo textual limpo e amigável para exibição visual.
  // - Papel no sistema: Autoriza a operação de veículos municipais de saúde, visualização
  //   da lista de passageiros agendados para a viagem do dia, alteração de status de
  //   embarque/desembarque de pacientes e emissão da ficha física TFD.
  // - Vínculos com o sistema: Permite entrada na rota '/motorista' via 'RouteGuard'.
  // --------------------------------------------------------------------------
  motorista('motorista', 'Motorista'),

  // --------------------------------------------------------------------------
  // CONSTANTE ENUMERADA: paciente
  // - O que faz: Instancia e registra o membro singleton que representa o Paciente.
  // - O que é: Membro constante da enumeração com invocação do construtor posicional const.
  // - Argumentos passados:
  //   1º 'paciente' (String): Chave canônica gravada no Firestore ('role': 'paciente').
  //   2º 'Paciente' (String): Rótulo formatado para apresentação textual ao usuário.
  // - Papel no sistema: Representa o usuário final cidadão que utiliza o transporte público
  //   de saúde para consultas e procedimentos intermunicipais.
  // - Vínculos com o sistema: Libera acesso exclusivo à rota '/paciente', permitindo
  //   ao paciente acompanhar o status da sua viagem e os horários previstos de retorno.
  // - Padrão de Fallback: Usado como valor padrão no método 'fromString' quando o papel não
  //   for identificado com precisão, aplicando o princípio de menor privilégio.
  // --------------------------------------------------------------------------
  paciente('paciente', 'Paciente');

  // Linha em branco separadora entre as constantes enumeradas e os membros de instância

  // --------------------------------------------------------------------------
  // PROPRIEDADE DE INSTÂNCIA: valor
  // - O que é: Campo final (imutável em tempo de execução) do tipo primitivo String.
  // - Papel: Armazena a chave interna padronizada e sanitizada (sempre em minúsculas)
  //   que é sincronizada com o banco de dados NoSQL Cloud Firestore.
  // - A que está ligada: Utilizada em conversões, comparações e no armazenamento das
  //   credenciais do usuário, servindo de ponte entre o código Dart e o schema do banco.
  // - Imutabilidade: Sendo declarada como 'final', seu valor é estabelecido no momento
  //   da inicialização das constantes enum e não pode ser reatribuído.
  // --------------------------------------------------------------------------
  final String valor;

  // --------------------------------------------------------------------------
  // PROPRIEDADE DE INSTÂNCIA: label
  // - O que é: Campo final (imutável em tempo de execução) do tipo primitivo String.
  // - Papel: Guarda a representação textual apresentável e amigável do perfil para o usuário.
  // - A que está ligada: Consumida diretamente por componentes da interface com o usuário
  //   (como dropdowns, chips informativos e cabeçalhos) para evitar codificação manual
  //   de textos hardcoded na camada de apresentação (View).
  // --------------------------------------------------------------------------
  final String label;

  // Linha em branco separadora entre as propriedades de instância e a definição do construtor

  // --------------------------------------------------------------------------
  // CONSTRUTOR CONSTANTE: UserRole
  // - O que é: Construtor canônico e constante ('const') com inicializadores formais em campo.
  // - Papel: Atribui os parâmetros posicionais diretamente aos campos imutáveis 'valor' e 'label'.
  // - Parâmetros:
  //   * 'this.valor': Sintaxe de açúcar sintático do Dart que atribui o 1º argumento ao campo 'valor'.
  //   * 'this.label': Sintaxe de açúcar sintático do Dart que atribui o 2º argumento ao campo 'label'.
  // - Por que é const: Garante que todas as instâncias da enumeração sejam alocadas como
  //   objetos canônicos únicos na memória pelo runtime do Dart, otimizando consumo de recursos.
  // --------------------------------------------------------------------------
  const UserRole(this.valor, this.label);

  // Linha em branco separadora entre o construtor da enumeração e os métodos auxiliares estáticos

  // --------------------------------------------------------------------------
  // MÉTODO ESTÁTICO DE CONVERSÃO / PARSER: fromString
  // - O que é: Método utilitário de fábrica estático pertencente ao namespace de UserRole.
  // - O que faz: Converte com segurança tipada qualquer String arbitrária recebida
  //   (por exemplo, payloads JSON do Firebase, query params ou claims) para o respectivo UserRole.
  // - Parâmetro recebido:
  //   * 'role' (String?): Aceita uma String potencialmente nula ou qualquer sequência de caracteres.
  // - Retorno:
  //   * Retorna um membro válido e não-nulo da enumeração 'UserRole' (garantia de não-nulidade).
  // - Estratégia de Defesa (Princípio do Menor Privilégio): Se a string for nula, vazia ou
  //   conter um valor não cadastrado, o método nunca lança erro ou exceção em tempo de execução;
  //   em vez disso, assume 'UserRole.paciente' como fallback seguro.
  // --------------------------------------------------------------------------
  static UserRole fromString(String? role) {
    // ------------------------------------------------------------------------
    // Avaliação condicional para correspondência com o perfil 'admin':
    // - O que faz: Testa se o valor do argumento 'role' é exatamente idêntico à literal 'admin'.
    // - Operador de comparação: '==' compara igualdade de conteúdo textual de strings.
    // - Retorno precoce (early return): Se verdadeiro, retorna imediatamente 'UserRole.admin',
    //   encerrando a execução do método sem avaliar as instruções subsequentes.
    // ------------------------------------------------------------------------
    if (role == 'admin') return UserRole.admin;

    // ------------------------------------------------------------------------
    // Avaliação condicional para correspondência com o perfil 'motorista':
    // - O que faz: Testa se o valor do argumento 'role' é exatamente idêntico à literal 'motorista'.
    // - Operador de comparação: '==' compara igualdade de conteúdo textual de strings.
    // - Retorno precoce (early return): Se verdadeiro, retorna imediatamente 'UserRole.motorista',
    //   concedendo os privilégios operacionais de motorista no sistema.
    // ------------------------------------------------------------------------
    if (role == 'motorista') return UserRole.motorista;

    // ------------------------------------------------------------------------
    // Ponto de saída padrão e fallback seguro (Menor Privilégio):
    // - O que faz: Executado caso o parâmetro 'role' seja nulo, vazio, ou diferente de 'admin'/'motorista'.
    // - Retorno: Retorna a constante 'UserRole.paciente', garantindo que o usuário receba
    //   apenas a menor permissão possível do sistema (paciente), prevenindo escalada de privilégios.
    // ------------------------------------------------------------------------
    return UserRole.paciente;

  // Fecha o bloco de execução e o escopo interno do método estático fromString
  }

// Fecha o bloco de declaração do corpo da enumeração UserRole
}
