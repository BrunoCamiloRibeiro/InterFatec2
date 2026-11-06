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

// Linha em branco separadora entre cabeçalho descritivo e o início da enumeração
// Comentário original do autor mantido byte a byte:
/// Perfis de acesso do aplicativo
// Declaração da enumeração UserRole que encapsula os níveis de privilégio do sistema
enum UserRole {
  // Constante representativa do perfil de Administrador com valor 'admin' e rótulo 'Administrador'
  admin('admin', 'Administrador'),
  // Constante representativa do perfil de Motorista com valor 'motorista' e rótulo 'Motorista'
  motorista('motorista', 'Motorista'),
  // Constante representativa do perfil de Paciente com valor 'paciente' e rótulo 'Paciente'
  paciente('paciente', 'Paciente');

  // Linha em branco separadora entre as constantes da enum e seus membros de instância

  // Atributo imutável do tipo String que guarda o identificador interno padronizado do perfil
  final String valor;
  // Atributo imutável do tipo String que armazena a descrição legível para o usuário final
  final String label;

  // Linha em branco separadora entre os atributos de instância e o construtor

  // Construtor constante da enumeração que inicializa os campos 'valor' e 'label'
  const UserRole(this.valor, this.label);

  // Linha em branco separadora entre o construtor e os métodos estáticos utilitários

  // Método utilitário estático que recebe uma string opcional e converte para a enumeração correspondente
  static UserRole fromString(String? role) {
    // Compara se o texto informado corresponde exatamente ao perfil de administrador
    if (role == 'admin') return UserRole.admin;
    // Compara se o texto informado corresponde exatamente ao perfil de motorista
    if (role == 'motorista') return UserRole.motorista;
    // Caso não seja nenhum dos anteriores (ou seja nulo), adota Paciente como valor padrão seguro
    return UserRole.paciente;
  // Fecha o bloco de instruções do método fromString
  }
// Fecha o bloco de declaração da enumeração UserRole
}
