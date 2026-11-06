// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/motorista_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula as informações cadastrais e operacionais de um motorista
// do serviço municipal de transporte de saúde (TFD), incluindo dados pessoais,
// CNH, dados do veículo padrão, capacidade, indicador de status de viagem e
// métodos de conversão para/de Map para persistência no Firebase Firestore.
//
// PARA QUE SERVE NO PROJETO:
// Permite a manipulação tipada das informações do motorista nas telas de
// operação de viagens, no acompanhamento pelos pacientes e na gestão de
// recursos humanos e frota pela administração municipal.
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (exibição de dados do motorista na tela de operações)
// - lib/lista_pessoas.dart (listagem geral de motoristas cadastrados)
// - test/lista_pessoas_test.dart (testes de renderização e busca na tela de pessoas)
//
// DE ONDE RECEBE DADOS:
// Documentos serializados do Firebase Firestore (documentos com role 'motorista')
// ou objetos instanciados para testes e simulações.
//
// O QUE EXPORTA / EXPÕE:
// - class MotoristaModel: classe de modelo de dados imutável
// - Atributos: id, nome, cpf, telefone, email, cnh, veiculoModelo, veiculoPlaca,
//   capacidadeVeiculo, emViagem, role, ativo, criadoEm
// - Construtor nomeado padrão MotoristaModel(...)
// - Map<String, dynamic> toMap(): serializa para o Firestore
// - factory MotoristaModel.fromMap(Map, {docId}): desserializa do Firestore
//
// ORIGEM HISTÓRICA:
// Criado no commit b7618c0 e expandido no commit ccbbe0e pela equipe do projeto
// para unificação com a arquitetura de Firestore. Não veio de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Utiliza estritamente os tipos padrão do Dart SDK (sem pacotes externos).
// É uma entidade pura de dados em memória: sem I/O, rede ou estado global.
// ============================================================================

// Linha em branco separadora entre o cabeçalho de documentação e a declaração da classe
// Declaração da classe de modelo para os Motoristas da frota
class MotoristaModel {
  // Identificador único do documento do motorista no Firestore
  final String id;
  // Nome completo do motorista para identificação nas escalas e telas
  final String nome;
  // Cadastro de Pessoa Física (CPF) usado para identificação ou login
  final String cpf;
  // Número de telefone para contato e comunicação operacional
  final String telefone;
  // Endereço de correio eletrônico institucional ou pessoal do motorista
  final String email;
  // Número de registro da Carteira Nacional de Habilitação (CNH)
  final String cnh;
  // Modelo e marca do veículo usualmente atribuído ao motorista
  final String veiculoModelo;
  // Placa de trânsito do veículo atribuído
  final String veiculoPlaca;
  // Quantidade máxima de passageiros que o veículo suporta (capacidade)
  final int capacidadeVeiculo;
  // Indicador booleano sinalizando se o motorista está com viagem em andamento
  final bool emViagem;
  // Papel de controle de acesso do usuário no sistema (padrão 'motorista')
  final String role;
  // Indicador booleano de situação cadastral (ativo ou inativo)
  final bool ativo;
  // Data e hora de criação do registro no sistema (opcional)
  final DateTime? criadoEm;

  // Linha em branco separadora entre os atributos e o construtor da classe

  // Construtor principal da classe MotoristaModel com inicialização nomeada
  MotoristaModel({
    // Parâmetro obrigatório para o identificador único do motorista
    required this.id,
    // Parâmetro obrigatório para o nome completo do motorista
    required this.nome,
    // Parâmetro obrigatório para o CPF do motorista
    required this.cpf,
    // Parâmetro obrigatório para o telefone de contato
    required this.telefone,
    // Parâmetro obrigatório para o e-mail de contato
    required this.email,
    // Parâmetro obrigatório para a CNH do motorista
    required this.cnh,
    // Parâmetro obrigatório para a descrição do modelo do veículo
    required this.veiculoModelo,
    // Parâmetro obrigatório para a placa do veículo
    required this.veiculoPlaca,
    // Parâmetro opcional com valor padrão de 4 assentos de capacidade
    this.capacidadeVeiculo = 4,
    // Parâmetro opcional com valor padrão falso indicando que não está em viagem
    this.emViagem = false,
    // Parâmetro opcional com valor padrão de perfil 'motorista'
    this.role = 'motorista',
    // Parâmetro opcional com valor padrão verdadeiro indicando cadastro ativo
    this.ativo = true,
    // Parâmetro opcional com a data de criação do registro
    this.criadoEm,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre o construtor e o método de serialização
  // Comentário original do autor mantido byte a byte:
  // Salvar no Firebase
  // Método que serializa a instância do motorista em um Map para gravação no Firestore
  Map<String, dynamic> toMap() {
    // Retorna a estrutura Map populada com as propriedades da instância
    return {
      // Mapeia o nome do motorista para a chave 'nome'
      'nome': nome,
      // Mapeia o CPF do motorista para a chave 'cpf'
      'cpf': cpf,
      // Mapeia o telefone do motorista para a chave 'telefone'
      'telefone': telefone,
      // Mapeia o e-mail do motorista para a chave 'email'
      'email': email,
      // Mapeia a CNH do motorista para a chave 'cnh'
      'cnh': cnh,
      // Mapeia o modelo do veículo para a chave 'veiculoModelo'
      'veiculoModelo': veiculoModelo,
      // Mapeia a placa do veículo para a chave 'veiculoPlaca'
      'veiculoPlaca': veiculoPlaca,
      // Mapeia a capacidade de passageiros para a chave 'capacidadeVeiculo'
      'capacidadeVeiculo': capacidadeVeiculo,
      // Mapeia a situação de viagem ativa para a chave 'emViagem'
      'emViagem': emViagem,
      // Mapeia o papel de privilégio para a chave 'role'
      'role': role,
      // Mapeia o status ativo da conta para a chave 'ativo'
      'ativo': ativo,
      // Mapeia a data de criação no formato ISO-8601 se não for nula
      'criadoEm': criadoEm?.toIso8601String(),
    // Fecha o mapa de pares chave-valor
    };
  // Fecha o bloco de instruções do método toMap
  }

  // Linha em branco separadora entre métodos de instância e método utilitário de conversão de data

  // Método estático utilitário para interpretar com resiliência datas do Firebase
  static DateTime? _parsearData(dynamic valor) {
    // Retorna nulo imediatamente caso o valor de entrada seja nulo
    if (valor == null) return null;
    // Se o valor já for um DateTime válido, retorna o próprio objeto
    if (valor is DateTime) return valor;
    // Bloco de tratamento para suporte a Timestamp do Firebase Firestore
    try {
      // Executa chamada dinâmica para o método toDate() característico do Firestore
      return (valor as dynamic).toDate() as DateTime;
    // Captura qualquer erro na chamada do método toDate()
    } catch (_) {}
    // Bloco de tratamento para parsing de strings de data (ex: ISO-8601)
    try {
      // Converte o valor para string e tenta o parsing via DateTime.tryParse
      return DateTime.tryParse(valor.toString());
    // Captura qualquer erro durante a interpretação da string
    } catch (_) {}
    // Retorna nulo se não for possível converter o valor recebido
    return null;
  // Fecha o bloco do método estático _parsearData
  }

  // Linha em branco separadora entre o método de parsing e a factory de desserialização
  // Comentário original do autor mantido byte a byte:
  // Ler do Firebase
  // Construtor factory que cria uma instância de MotoristaModel a partir de um Map de dados
  factory MotoristaModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Extrai o valor bruto associado à capacidade do veículo
    final capRaw = map['capacidadeVeiculo'];
    // Converte com segurança a capacidade para número inteiro ou usa 4 como fallback
    final int capInt = (capRaw is num)
        // Se já for numérico, extrai o inteiro
        ? capRaw.toInt()
        // Caso contrário, tenta realizar parse da string ou adota 4 como padrão
        : (int.tryParse(capRaw?.toString() ?? '') ?? 4);

    // Linha em branco separadora entre a conversão de capacidade e a instanciação do objeto

    // Retorna uma nova instância de MotoristaModel populada a partir dos dados do Map
    return MotoristaModel(
      // Atribui o identificador único fornecido ou uma string vazia
      id: docId ?? '',
      // Atribui o nome extraído ou string vazia em caso de ausência
      nome: (map['nome'] ?? '').toString(),
      // Atribui o CPF extraído ou string vazia em caso de ausência
      cpf: (map['cpf'] ?? '').toString(),
      // Atribui o telefone extraído ou string vazia em caso de ausência
      telefone: (map['telefone'] ?? '').toString(),
      // Atribui o e-mail extraído ou string vazia em caso de ausência
      email: (map['email'] ?? '').toString(),
      // Atribui o registro de CNH extraído ou string vazia
      cnh: (map['cnh'] ?? '').toString(),
      // Atribui a descrição do modelo do veículo ou string vazia
      veiculoModelo: (map['veiculoModelo'] ?? '').toString(),
      // Atribui a placa do veículo ou string vazia
      veiculoPlaca: (map['veiculoPlaca'] ?? '').toString(),
      // Atribui o valor inteiro validado da capacidade de passageiros
      capacidadeVeiculo: capInt,
      // Converte a propriedade emViagem considerando booleanos ou representação textual 'true'
      emViagem: map['emViagem'] == true || map['emViagem'] == 'true',
      // Atribui o perfil de permissão ou adota 'motorista' como padrão seguro
      role: (map['role'] ?? 'motorista').toString(),
      // Valida se a conta está ativa, considerando nulos como ativo por padrão
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      // Realiza a conversão segura da data de criação com _parsearData
      criadoEm: _parsearData(map['criadoEm']),
    // Fecha a chamada do construtor de MotoristaModel
    );
  // Fecha o bloco do construtor factory fromMap
  }
// Fecha o bloco de declaração da classe MotoristaModel
}
