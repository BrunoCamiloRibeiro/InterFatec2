// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/models/paciente_model.dart
// Camada: Domínio / Modelos de Dados (Models)
//
// O QUE ESTE ARQUIVO FAZ:
// Modela e encapsula as informações cadastrais, de transporte e o ciclo de
// atendimento de um paciente do sistema TFD (Tratamento Fora de Domicílio),
// centralizando o mapeamento de status de viagem (0 a 5) com suas respectivas
// cores, ícones e textos amigáveis, além de métodos de conversão para o Firebase.
//
// PARA QUE SERVE NO PROJETO:
// É a entidade central para o acompanhamento dos deslocamentos de saúde do
// município, sendo utilizada na visualização do paciente, no controle de
// embarque/desembarque pelo motorista, na listagem administrativa de usuários
// e na composição do documento oficial "Ficha de Atendimento TFD" em PDF.
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (gestão e atualização dos pacientes na rota ativa)
// - lib/paciente.dart (painel do paciente acompanhando status da sua viagem)
// - lib/lista_pessoas.dart (listagem geral de pacientes cadastrados na saúde)
// - lib/components/card_paciente.dart (card do paciente na tela do motorista)
// - lib/components/card_identificacao_paciente.dart (dados de contato e endereço)
// - lib/components/footer_pacientes.dart (contadores de embarcados/desembarcados)
// - lib/components/formulario_encerramento.dart (baixa final ao encerrar viagem)
// - lib/services/relatorio_pdf_service.dart (geração do roteiro de viagem impresso)
// - test/lista_pessoas_test.dart (testes de renderização da lista de pacientes)
// - test/relatorio_pdf_test.dart (testes de geração do PDF da viagem TFD)
//
// DE ONDE RECEBE DADOS:
// Documentos do Firebase Firestore (coleção de usuários/pacientes ou listas
// de passageiros vinculadas a viagens), dados em JSON e objetos de mock em testes.
//
// O QUE EXPORTA / EXPÕE:
// - class PacienteModel: modelo imutável de dados do paciente
// - Atributos: id, nome, cpf, telefone, enderecoPaciente, localConsulta,
//   localSaida, horarioConsulta, status, nomeAcompanhante, telAcompanhante,
//   role, ativo, criadoEm
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

// Importação do pacote Material do Flutter para os tipos Color, IconData e biblioteca de ícones
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a definição da classe
// Declaração da classe do modelo de dados para Pacientes do TFD
class PacienteModel {
  // Identificador único do documento do paciente no Firebase Firestore
  final String id;
  // Nome completo do paciente atendido pelo transporte de saúde
  final String nome;
  // Cadastro de Pessoa Física (CPF) do paciente
  final String cpf;
  // Número de telefone para contato direto com o paciente
  final String telefone;
  // Endereço de residência onde o paciente deve ser buscado ou contatado
  final String enderecoPaciente;
  // Local de atendimento médico no município de destino (ex: Hospital, AME, UBS)
  final String localConsulta;
  // Ponto de partida do paciente (ex: 'Residência' ou 'Unidade Básica de Saúde')
  final String localSaida;
  // Horário agendado para a consulta médica ou exame de saúde
  final String horarioConsulta;
  // Código numérico indicando o estágio atual do paciente na viagem (0 a 5)
  final int status;
  // Nome completo do acompanhante do paciente, se houver necessidade legal/médica
  final String? nomeAcompanhante;
  // Telefone para contato com o acompanhante responsável
  final String? telAcompanhante;
  // Papel de perfil de controle de acesso (padrão 'paciente')
  final String role;
  // Indicador se o cadastro do paciente está ativo no sistema
  final bool ativo;
  // Data e hora de criação do cadastro no sistema (opcional)
  final DateTime? criadoEm;

  // Linha em branco separadora entre declarações de campos e o construtor

  // Construtor principal da classe PacienteModel com parâmetros nomeados
  PacienteModel({
    // Parâmetro obrigatório para o ID do documento
    required this.id,
    // Parâmetro obrigatório para o nome do paciente
    required this.nome,
    // Parâmetro obrigatório para o CPF do paciente
    required this.cpf,
    // Parâmetro obrigatório para o telefone do paciente
    required this.telefone,
    // Parâmetro obrigatório para o endereço residencial do paciente
    required this.enderecoPaciente,
    // Parâmetro obrigatório para o local de destino/consulta
    required this.localConsulta,
    // Parâmetro opcional para o ponto de saída, padrão vazio
    this.localSaida = '',
    // Parâmetro opcional para o horário da consulta médica
    this.horarioConsulta = '',
    // Parâmetro opcional para o código de status com valor padrão 0 (Aguardando)
    this.status = 0,
    // Parâmetro opcional para o nome do acompanhante
    this.nomeAcompanhante,
    // Parâmetro opcional para o telefone do acompanhante
    this.telAcompanhante,
    // Parâmetro opcional para o perfil de permissão com padrão 'paciente'
    this.role = 'paciente',
    // Parâmetro opcional para a situação cadastral ativa
    this.ativo = true,
    // Parâmetro opcional para a data e hora do cadastro
    this.criadoEm,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre o construtor e o método de status
  // Comentário original do autor mantido byte a byte:
  // Mapeamento centralizado de status numérico para texto, cor e ícone em todo o app
  // Método estático que mapeia o código numérico de status em uma tupla contendo texto, cor e ícone
  static (String texto, Color cor, IconData icone) dadosStatus(int status) {
    // Avalia o código numérico recebido através de uma expressão switch pattern matching
    return switch (status) {
      // Caso 0: Paciente aguardando início da rota ou embarque na cidade de origem
      0 => (
        // Rótulo textual representativo da etapa inicial
        'Aguardando Transporte',
        // Cor azul de destaque visual para o status de espera
        const Color(0xFF2563EB),
        // Ícone de relógio indicando tempo de espera programado
        Icons.schedule_outlined,
      // Fecha a tupla correspondente ao status 0
      ),
      // Caso 1: Paciente confirmado a bordo do veículo para a ida ao destino
      1 => (
        // Rótulo textual confirmando o embarque no trajeto de ida
        'Embarcou para Ida',
        // Tom de azul mais escuro para indicar progresso ativo da viagem
        const Color(0xFF1D4ED8),
        // Ícone de navegação indicando deslocamento em curso
        Icons.near_me_outlined,
      // Fecha a tupla correspondente ao status 1
      ),
      // Caso 2: Paciente desembarcado no hospital ou posto de consulta
      2 => (
        // Rótulo textual confirmando o desembarque na clínica ou hospital
        'Desembarcou para Consulta',
        // Cor âmbar/laranja chamando atenção para o período de espera do atendimento médico
        const Color(0xFFD97706),
        // Ícone de saída indicando que o paciente deixou o veículo no destino
        Icons.exit_to_app,
      // Fecha a tupla correspondente ao status 2
      ),
      // Caso 3: Paciente já atendido e reembarcado no veículo para a viagem de volta
      3 => (
        // Rótulo textual confirmando o retorno do paciente ao veículo para a viagem de volta
        'Reembarcou para Volta',
        // Cor índigo diferenciada para a fase de retorno municipal
        const Color(0xFF4338CA),
        // Ícone de retorno representando a viagem de volta ao ponto de origem
        Icons.reply_outlined,
      // Fecha a tupla correspondente ao status 3
      ),
      // Caso 4: Ciclo completo da viagem concluído com sucesso e paciente entregue
      4 => ('Concluído', const Color(0xFF16A34A), Icons.check_outlined),
      // Caso 5: Atendimento ou transporte cancelado pelo paciente ou equipe de saúde
      5 => ('Cancelado', const Color(0xFFB83227), Icons.cancel),
      // Caso padrão (fallback): Status não reconhecido ou inválido
      _ => ('Pendente', Colors.grey, Icons.help),
    // Fecha a expressão switch
    };
  // Fecha o bloco de instruções do método dadosStatus
  }

  // Linha em branco separadora entre dadosStatus e os getters utilitários
  // Comentário original do autor mantido byte a byte:
  // Getters utilitários para acesso rápido na instância do paciente
  // Getter conveniente que extrai diretamente a descrição textual do status da instância
  String get textoStatus => dadosStatus(status).$1;
  // Getter conveniente que extrai diretamente a cor representativa do status da instância
  Color get corStatus => dadosStatus(status).$2;
  // Getter conveniente que extrai diretamente o ícone representativo do status da instância
  IconData get iconeStatus => dadosStatus(status).$3;

  // Linha em branco separadora entre os getters e o método de serialização
  // Comentário original do autor mantido byte a byte:
  // Salvar no Firebase
  // Método que serializa a instância do paciente em um Map de pares chave-valor para o Firestore
  Map<String, dynamic> toMap() {
    // Retorna a estrutura Map populada com as propriedades da instância
    return {
      // Mapeia o nome do paciente para a chave 'nome'
      'nome': nome,
      // Mapeia o CPF do paciente para a chave 'cpf'
      'cpf': cpf,
      // Mapeia o telefone do paciente para a chave 'telefone'
      'telefone': telefone,
      // Mapeia o endereço residencial para a chave 'enderecoPaciente'
      'enderecoPaciente': enderecoPaciente,
      // Mapeia o local de destino médico para a chave 'localConsulta'
      'localConsulta': localConsulta,
      // Mapeia o ponto de saída para a chave 'localSaida'
      'localSaida': localSaida,
      // Mapeia o horário agendado da consulta para a chave 'horarioConsulta'
      'horarioConsulta': horarioConsulta,
      // Mapeia o código numérico de status para a chave 'status'
      'status': status,
      // Mapeia o nome do acompanhante para a chave 'nomeAcompanhante'
      'nomeAcompanhante': nomeAcompanhante,
      // Mapeia o telefone do acompanhante para a chave 'telAcompanhante'
      'telAcompanhante': telAcompanhante,
      // Mapeia o papel de privilégio para a chave 'role'
      'role': role,
      // Mapeia o status cadastral ativo para a chave 'ativo'
      'ativo': ativo,
      // Mapeia a data de criação convertida para formato de texto padrão ISO-8601
      'criadoEm': criadoEm?.toIso8601String(),
    // Fecha o dicionário Map de pares chave-valor
    };
  // Fecha o bloco de instruções do método toMap
  }

  // Linha em branco separadora entre toMap e a função utilitária de conversão de data

  // Método estático utilitário para converter datas oriundas do Firebase de forma resiliente
  static DateTime? _parsearData(dynamic valor) {
    // Retorna nulo se o valor for nulo
    if (valor == null) return null;
    // Se já for uma instância DateTime, retorna o próprio valor
    if (valor is DateTime) return valor;
    // Tenta interpretar objeto Timestamp característico do Cloud Firestore
    try {
      // Invoca dinamicamente toDate() do Timestamp
      return (valor as dynamic).toDate() as DateTime;
    // Ignora falhas caso o objeto não seja um Timestamp do Firestore
    } catch (_) {}
    // Tenta interpretar o valor em formato string ISO-8601
    try {
      // Realiza parse seguro da representação textual da data
      return DateTime.tryParse(valor.toString());
    // Ignora falhas de parse de string
    } catch (_) {}
    // Retorna nulo caso todas as tentativas falhem
    return null;
  // Fecha o bloco da função estática _parsearData
  }

  // Linha em branco separadora entre a função de data e o construtor factory
  // Comentário original do autor mantido byte a byte:
  // Ler do Firebase
  // Construtor factory que reconstrói uma instância de PacienteModel a partir de um Map de dados
  factory PacienteModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Extrai o valor bruto associado ao código numérico de status
    final statusRaw = map['status'];
    // Converte de maneira resiliente o status para número inteiro ou usa 0 como fallback
    final int statusInt = (statusRaw is num)
        // Se já for número, converte diretamente para int
        ? statusRaw.toInt()
        // Caso contrário, tenta realizar parse da string ou adota 0 (Aguardando)
        : (int.tryParse(statusRaw?.toString() ?? '') ?? 0);

    // Linha em branco separadora entre a conversão de status e a instanciação do objeto

    // Retorna uma nova instância de PacienteModel populada a partir dos dados do Map
    return PacienteModel(
      // Atribui o identificador único fornecido ou uma string vazia
      id: docId ?? '',
      // Atribui o nome extraído ou string vazia em caso de ausência
      nome: (map['nome'] ?? '').toString(),
      // Atribui o CPF extraído ou string vazia em caso de ausência
      cpf: (map['cpf'] ?? '').toString(),
      // Atribui o telefone extraído ou string vazia em caso de ausência
      telefone: (map['telefone'] ?? '').toString(),
      // Atribui o endereço residencial extraído ou string vazia
      enderecoPaciente: (map['enderecoPaciente'] ?? '').toString(),
      // Atribui o local da consulta médica extraído ou string vazia
      localConsulta: (map['localConsulta'] ?? '').toString(),
      // Atribui o local de saída ou 'Residência' como valor padrão amigável
      localSaida: (map['localSaida'] ?? 'Residência').toString(),
      // Atribui o horário da consulta médica ou string vazia
      horarioConsulta: (map['horarioConsulta'] ?? '').toString(),
      // Atribui o código de status validado e convertido
      status: statusInt,
      // Atribui o nome do acompanhante convertido para texto se presente
      nomeAcompanhante: map['nomeAcompanhante']?.toString(),
      // Atribui o telefone do acompanhante convertido para texto se presente
      telAcompanhante: map['telAcompanhante']?.toString(),
      // Atribui o perfil de permissão com padrão seguro 'paciente'
      role: (map['role'] ?? 'paciente').toString(),
      // Avalia se o registro está ativo, tratando nulos como verdadeiro por padrão
      ativo: map['ativo'] == true || map['ativo'] == null || map['ativo'] == 'true',
      // Converte o campo de data de criação usando a função resiliente _parsearData
      criadoEm: _parsearData(map['criadoEm']),
    // Fecha a chamada do construtor PacienteModel
    );
  // Fecha o bloco do construtor factory fromMap
  }
// Fecha o bloco de declaração da classe PacienteModel
}
