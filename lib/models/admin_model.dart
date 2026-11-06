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

// Linha em branco separadora entre o cabeçalho de documentação e a definição da classe
// Declaração da classe do modelo de dados para Administradores
class AdminModel {
  // Identificador único do documento do administrador no banco de dados Firestore
  final String id;
  // Nome completo do administrador para identificação e exibição na interface
  final String nome;
  // Cadastro de Pessoa Física (CPF) usado como identificador funcional ou login
  final String cpf;
  // Endereço de correio eletrônico institucional do administrador
  final String email;
  // Telefone de contato institucional ou móvel do administrador
  final String telefone;
  // Papel de controle de acesso, com valor padrão 'admin'
  final String role;
  // Indicador booleano que expressa se a conta está ativa ou desativada no sistema
  final bool ativo;
  // Data e hora de cadastro da conta do administrador no sistema (opcional)
  final DateTime? criadoEm;

  // Linha em branco separadora entre declarações de atributos e o construtor principal

  // Construtor principal da classe AdminModel que inicializa todos os seus atributos
  AdminModel({
    // Parâmetro obrigatório que recebe o ID único do documento no Firestore
    required this.id,
    // Parâmetro obrigatório que recebe o nome completo do administrador
    required this.nome,
    // Parâmetro obrigatório que recebe o CPF cadastrado do administrador
    required this.cpf,
    // Parâmetro obrigatório que recebe o e-mail de contato
    required this.email,
    // Parâmetro obrigatório que recebe o telefone de contato
    required this.telefone,
    // Parâmetro opcional com valor padrão definido para 'admin'
    this.role = 'admin',
    // Parâmetro opcional com valor padrão verdadeiro indicando conta ativa
    this.ativo = true,
    // Parâmetro opcional que recebe a data e hora em que a conta foi criada
    this.criadoEm,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre o construtor e o método de serialização
  // Comentário original do autor mantido byte a byte:
  // Salvar no Firebase
  // Método que serializa a instância atual em um Map estruturado para gravação no Firestore
  Map<String, dynamic> toMap() {
    // Retorna a estrutura em formato Map contendo as chaves e valores dos atributos
    return {
      // Mapeia o nome completo do administrador para a chave 'nome'
      'nome': nome,
      // Mapeia o CPF do administrador para a chave 'cpf'
      'cpf': cpf,
      // Mapeia o e-mail do administrador para a chave 'email'
      'email': email,
      // Mapeia o telefone do administrador para a chave 'telefone'
      'telefone': telefone,
      // Mapeia o papel de privilégio do administrador para a chave 'role'
      'role': role,
      // Mapeia a situação de atividade da conta para a chave 'ativo'
      'ativo': ativo,
      // Mapeia a data de criação convertida para formato de texto padrão ISO-8601 se não for nula
      'criadoEm': criadoEm?.toIso8601String(),
    // Fecha o dicionário Map de pares chave-valor
    };
  // Fecha o bloco de instruções do método toMap
  }

  // Linha em branco separadora entre métodos de instância e método utilitário estático

  // Função utilitária estática para converter com resiliência diferentes tipos de data do Firebase
  static DateTime? _parsearData(dynamic valor) {
    // Retorna nulo imediatamente caso o valor recebido seja nulo
    if (valor == null) return null;
    // Se o valor já for uma instância válida de DateTime, retorna o próprio objeto
    if (valor is DateTime) return valor;
    // Bloco de captura de exceção para tentar ler objeto no formato Timestamp nativo do Firestore
    try {
      // Invoca dinamicamente o método toDate() característico do tipo Timestamp do Cloud Firestore
      return (valor as dynamic).toDate() as DateTime;
    // Captura qualquer erro na chamada dinâmica e segue para a próxima tentativa de parsing
    } catch (_) {}
    // Bloco de captura de exceção para tentar fazer parse de string ISO-8601
    try {
      // Converte o valor para texto e tenta interpretá-lo via DateTime.tryParse
      return DateTime.tryParse(valor.toString());
    // Captura qualquer erro na conversão em texto e finaliza as tentativas
    } catch (_) {}
    // Retorna nulo caso nenhuma das conversões anteriores tenha sido bem-sucedida
    return null;
  // Fecha o bloco da função estática _parsearData
  }

  // Linha em branco separadora entre a função de parsing e o construtor factory
  // Comentário original do autor mantido byte a byte:
  // Ler do Firebase
  // Construtor factory para instanciar AdminModel a partir de um Map de dados e docId opcional
  factory AdminModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Cria e retorna uma nova instância preenchendo campos com valores padrão de segurança
    return AdminModel(
      // Atribui o identificador do documento Firestore recebido ou uma string vazia
      id: docId ?? '',
      // Extrai o nome do Map, tratando valores nulos e convertendo para String
      nome: (map['nome'] ?? '').toString(),
      // Extrai o CPF do Map, tratando valores nulos e convertendo para String
      cpf: (map['cpf'] ?? '').toString(),
      // Extrai o e-mail do Map, tratando valores nulos e convertendo para String
      email: (map['email'] ?? '').toString(),
      // Extrai o telefone do Map, tratando valores nulos e convertendo para String
      telefone: (map['telefone'] ?? '').toString(),
      // Extrai o papel de acesso ou assume 'admin' como fallback padrão seguro
      role: (map['role'] ?? 'admin').toString(),
      // Avalia se o campo ativo é booleano verdadeiro, nulo (padrão ativo) ou string 'true'
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      // Converte o campo de data de criação utilizando a função resiliente _parsearData
      criadoEm: _parsearData(map['criadoEm']),
    // Fecha a chamada do construtor AdminModel
    );
  // Fecha o bloco do construtor factory fromMap
  }
// Fecha o bloco de declaração da classe AdminModel
}
