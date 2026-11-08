// ============================================================================
// ARQUIVO: lib/lista_pessoas.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa a tela completa de Gestão de Pessoas do sistema TransSaúde
// (StatefulWidget "ListaPessoas") e o ViewModel polimórfico "PessoaItem"
// (criados na Issue #34). Centraliza a listagem unificada, filtragem por abas
// de perfis (Todos, Pacientes, Motoristas, Administradores com contadores em
// tempo real), busca reativa por Nome ou CPF, e fluxo de exclusão lógica
// (inativação no Firestore com 'ativo = false') com confirmação dialógica para
// conformidade com normas de governança, LGPD e auditoria pública.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Apresentação / View e ViewModel de Interface (lib/lista_pessoas.dart).
//
// ONDE É USADO (REFERÊNCIAS NO REPOSITÓRIO):
// - lib/main.dart: registrado como rota nomeada '/pessoas' no MaterialApp.
// - test/lista_pessoas_test.dart: suíte completa de testes de widget e integração.
//
// DE ONDE RECEBE DADOS:
// - Cloud Firestore: coleção "usuarios" (escuta snapshots em tempo real de todos os perfis).
// - Modelos consumidos e normalizados:
//   - lib/models/paciente_model.dart (PacienteModel)
//   - lib/models/motorista_model.dart (MotoristaModel)
//   - lib/models/admin_model.dart (AdminModel)
// - Componente de exibição reutilizado:
//   - lib/components/card_identificacao_paciente.dart (CardIdentificacaoPaciente)
// - Parâmetros opcionais via construtor para testes:
//   - mockPacientes, mockMotoristas, mockAdmins, streamOverride.
//
// O QUE EXPORTA / EXPÕE:
// - class PessoaItem: ViewModel polimórfico de representação unificada na UI.
// - class ListaPessoas extends StatefulWidget: Tela interativa de gestão de pessoas.
// - class _ListaPessoasState: Estado e controladores da tela.
//
// ORIGEM HISTÓRICA:
// Criado pela equipe de desenvolvimento no escopo da Issue #34 (commit 472aa0a).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - dart:async: StreamSubscription para assinatura reativa.
// - package:cloud_firestore: leitura contínua e atualização remota (update 'ativo': false).
// - package:firebase_core: checagem de inicialização da infraestrutura Firebase.
// - package:flutter/material.dart: componentes de UI Material Design.
// - Efeitos colaterais: atualiza documentos no Firestore marcando 'ativo: false'
//   e mantém conexão de stream de rede ativa.
//
// INCONSISTÊNCIAS / OBSERVAÇÕES TÉCNICAS:
// - O FloatingActionButton ('Novo') possui callback vazio com TODO indicando
//   que a navegação para o formulário de cadastro de pessoas será criada futuramente.
// - O callback onEditar do CardIdentificacaoPaciente está atualmente vazio (() {}).
// ============================================================================
// Importa utilitários assíncronos fundamentais do Dart como StreamSubscription
import 'dart:async';

// Importa a biblioteca oficial do Cloud Firestore para banco de dados NoSQL reativo
import 'package:cloud_firestore/cloud_firestore.dart';
// Importa o pacote principal Firebase Core para verificação de inicialização
import 'package:firebase_core/firebase_core.dart';
// Importa o conjunto completo de componentes de interface Material Design do Flutter
import 'package:flutter/material.dart';

// Importa o componente reutilizável de identificação visual de pessoas com avatar e ações
import 'components/card_identificacao_paciente.dart';
// Importa o modelo de dados representativo de administradores do sistema
import 'models/admin_model.dart';
// Importa o modelo de dados representativo de motoristas
import 'models/motorista_model.dart';
// Importa o modelo de dados representativo de pacientes
import 'models/paciente_model.dart';

/// ============================================================================
/// VIEWMODEL POLIMÓRFICO: PESSOA ITEM
/// ============================================================================
/// Normaliza entidades distintas (PacienteModel, MotoristaModel, AdminModel) em
/// uma única estrutura de apresentação para a interface, eliminando código
/// duplicado, contadores paralelos e múltiplos loops de renderização.
// Classe ViewModel que consolida atributos comuns para apresentação na interface
class PessoaItem {
  /// Identificador único da pessoa (utilizado como chave do documento no Firestore)
  // Atributo imutável com o ID do documento
  final String id;

  /// Nome completo da pessoa cadastrada
  // Atributo imutável com o nome da pessoa
  final String nome;

  /// Cadastro de Pessoa Física (CPF) formatado
  // Atributo imutável com o CPF formatado
  final String cpf;

  /// Telefone principal de contato
  // Atributo imutável com o telefone de contato
  final String telefone;

  /// Papel de acesso no sistema ('paciente', 'motorista' ou 'admin')
  // Papel funcional da pessoa no controle de acesso
  final String role;

  /// Texto exibido na etiqueta/badge do card (ex: "Paciente", "Motorista", "Administrador")
  // Rótulo textual da etiqueta de identificação visual
  final String badgeLabel;

  /// Cor temática do badge baseada no papel da pessoa
  // Cor da etiqueta de identificação visual
  final Color badgeCor;

  /// Status de agendamento ou transporte (consumido de PacienteModel.dadosStatus)
  // Status numérico da etapa de transporte ou atendimento
  final int status;

  /// Detalhe contextual complementar (ex: local da consulta médica, modelo/placa do veículo ou e-mail)
  // Texto opcional com informações complementares dependentes do perfil
  final String? detalheExtra;

  /// Indicador de situação cadastral para suporte a exclusão lógica (LGPD/Auditoria)
  // Flag booleana que indica se o cadastro está ativo no sistema
  final bool ativo;

  // Construtor constante da classe PessoaItem
  const PessoaItem({
    // Identificador obrigatório
    required this.id,
    // Nome obrigatório
    required this.nome,
    // CPF obrigatório
    required this.cpf,
    // Telefone obrigatório
    required this.telefone,
    // Papel obrigatório
    required this.role,
    // Rótulo da badge obrigatório
    required this.badgeLabel,
    // Cor da badge obrigatória
    required this.badgeCor,
    // Status numérico com valor padrão 0
    this.status = 0,
    // Detalhe complementar opcional
    this.detalheExtra,
    // Situação cadastral com padrão verdadeiro
    this.ativo = true,
  // Fechamento da lista de parâmetros do construtor
  });

  /// Construtor fábrica para converter uma instância de [PacienteModel] em [PessoaItem]
  // Fábrica especializada na transformação de pacientes para a estrutura unificada de exibição
  factory PessoaItem.fromPaciente(PacienteModel p) => PessoaItem(
    // Repassa o identificador do paciente
    id: p.id,
    // Repassa o nome do paciente
    nome: p.nome,
    // Repassa o CPF do paciente
    cpf: p.cpf,
    // Repassa o telefone do paciente
    telefone: p.telefone,
    // Repassa a role funcional do paciente
    role: p.role,
    // Rótulo padrão de identificação para pacientes
    badgeLabel: 'Paciente',
    // Cor azul padronizada para badges de pacientes
    badgeCor: const Color(0xFF2563EB),
    // Repassa o status numérico do transporte/consulta
    status: p.status,
    // Concatena o local da consulta caso informado, ou nulo
    detalheExtra: p.localConsulta.isNotEmpty
        // Texto descritivo com o hospital/unidade
        ? 'Consulta: ${p.localConsulta}'
        // Valor nulo caso o campo esteja vazio
        : null,
    // Repassa a situação de atividade do registro
    ativo: p.ativo,
  // Fechamento da instanciação de PessoaItem
  );

  /// Construtor fábrica para converter uma instância de [MotoristaModel] em [PessoaItem]
  // Fábrica especializada na transformação de motoristas para a estrutura unificada de exibição
  factory PessoaItem.fromMotorista(MotoristaModel m) => PessoaItem(
    // Repassa o identificador do motorista
    id: m.id,
    // Repassa o nome do motorista
    nome: m.nome,
    // Repassa o CPF do motorista
    cpf: m.cpf,
    // Repassa o telefone do motorista
    telefone: m.telefone,
    // Repassa o papel de motorista
    role: m.role,
    // Rótulo padrão de identificação para motoristas
    badgeLabel: 'Motorista',
    // Cor escura azulada padronizada para badges de motoristas
    badgeCor: const Color(0xFF0F172A),
    // Status fixo em 0 para motoristas (não utilizam status de passageiro)
    status: 0,
    // Detalhe extra contendo o modelo e a placa do veículo conduzido
    detalheExtra: 'Veículo: ${m.veiculoModelo} (${m.veiculoPlaca})',
    // Repassa a situação cadastral do motorista
    ativo: m.ativo,
  // Fechamento da instanciação de PessoaItem
  );

  /// Construtor fábrica para converter uma instância de [AdminModel] em [PessoaItem]
  // Fábrica especializada na transformação de administradores para a estrutura unificada de exibição
  factory PessoaItem.fromAdmin(AdminModel a) => PessoaItem(
    // Repassa o identificador do administrador
    id: a.id,
    // Repassa o nome do administrador
    nome: a.nome,
    // Repassa o CPF do administrador
    cpf: a.cpf,
    // Repassa o telefone do administrador
    telefone: a.telefone,
    // Repassa o papel de admin
    role: a.role,
    // Rótulo padrão de identificação para administradores
    badgeLabel: 'Administrador',
    // Cor roxa sofisticada padronizada para badges de administradores
    badgeCor: const Color(0xFF7C3AED),
    // Status fixo em 0 para administradores
    status: 0,
    // Detalhe extra com o e-mail institucional caso presente
    detalheExtra: a.email.isNotEmpty ? 'E-mail: ${a.email}' : null,
    // Repassa a situação cadastral do administrador
    ativo: a.ativo,
  // Fechamento da instanciação de PessoaItem
  );
// Fechamento da classe PessoaItem
}

/// ============================================================================
/// TELA DE GESTÃO DE PESSOAS (CRUD - ISSUE #34)
/// ============================================================================
/// Centraliza a consulta, filtragem por perfil, busca reativa por nome/CPF
/// e exclusão lógica de Pacientes, Motoristas e Administradores.
///
/// Padrões de Arquitetura e Boas Práticas Adotados:
/// 1. Consumo em tempo real do Cloud Firestore (coleção 'usuarios').
/// 2. Reciclagem de memória e virtualização de lista com [ListView.builder].
/// 3. Filtragem fora da árvore de renderização (event-driven no [build]).
/// 4. Desacoplamento entre os diálogos de interface e as mutações de estado.
/// 5. Padronização visual com motorista.dart e paciente.dart (fundo branco, AppBar oficial).
// Declaração do StatefulWidget ListaPessoas para controle e exibição do cadastro geral
class ListaPessoas extends StatefulWidget {
  /// Lista opcional de pacientes para testes de widget ou execução sem backend
  // Lista opcional para injeção de pacientes em modo offline ou testes de tela
  final List<PacienteModel>? mockPacientes;

  /// Lista opcional de motoristas para testes de widget ou execução sem backend
  // Lista opcional para injeção de motoristas em testes
  final List<MotoristaModel>? mockMotoristas;

  /// Lista opcional de administradores para testes de widget ou execução sem backend
  // Lista opcional para injeção de administradores em testes
  final List<AdminModel>? mockAdmins;

  /// Stream customizada para injeção de dependência em testes automatizados
  // Stream alternativa injetável para testes automatizados
  final Stream<List<PessoaItem>>? streamOverride;

  // Construtor constante da classe ListaPessoas com injeções opcionais
  const ListaPessoas({
    // Chave identificadora do widget
    super.key,
    // Injeção de pacientes para testes
    this.mockPacientes,
    // Injeção de motoristas para testes
    this.mockMotoristas,
    // Injeção de administradores para testes
    this.mockAdmins,
    // Injeção de stream customizada
    this.streamOverride,
  // Fechamento dos parâmetros do construtor
  });

  // Sobrescrita obrigatória que cria o estado mutável do widget
  @override
  // Instancia e retorna a classe de estado privada _ListaPessoasState
  State<ListaPessoas> createState() => _ListaPessoasState();
// Fechamento da classe ListaPessoas
}

// Classe de estado privada que administra as listas, filtros e ciclo de vida da tela
class _ListaPessoasState extends State<ListaPessoas> {
  /// Controlador do campo de texto de pesquisa
  // Controlador para monitorar e limpar o campo de busca
  final TextEditingController _buscaController = TextEditingController();

  /// Papel selecionado para filtragem ('todos', 'paciente', 'motorista' ou 'admin')
  // Categoria de filtro ativa atualmente selecionada nas abas horizontais
  String _filtroRole = 'todos';

  /// Termo de busca normalizado em caixa baixa para comparação case-insensitive
  // String armazenando o texto digitado pelo usuário em minúsculas
  String _termoBusca = '';

  /// Inscrição ativa no stream do Firestore (cancelada no [dispose])
  // Objeto de assinatura da stream do Firestore para descarte no dispose
  StreamSubscription<List<PessoaItem>>? _inscricaoUsuarios;

  /// Coleção principal de todas as pessoas carregadas
  // Lista em memória com todos os registros carregados do banco ou mocks
  List<PessoaItem> _todasPessoas = [];

  /// Coleção pré-filtrada que alimenta diretamente o [ListView.builder]
  // Lista filtrada pronta para exibição imediata no ListView.builder
  List<PessoaItem> _pessoasFiltradas = [];

  /// Contadores consolidados calculados em passada única
  // Total consolidado de pacientes ativos
  int _totalPacientes = 0;
  // Total consolidado de motoristas ativos
  int _totalMotoristas = 0;
  // Total consolidado de administradores ativos
  int _totalAdmins = 0;

  /// Mensagem de erro descritiva para exibição de alerta em caso de falhas
  // Texto descritivo de falha para apresentação no banner vermelho
  String? _erroGeral;

  /// Bloqueia interações concorrentes durante requisições assíncronas
  // Flag que previne múltiplos toques durante operações de salvamento ou inativação
  bool _salvando = false;

  /// Indica se a tela ainda está aguardando o primeiro carregamento de dados
  // Flag que controla a exibição do CircularProgressIndicator inicial
  bool _carregando = true;

  /// Verifica se o Firebase foi inicializado nesta sessão do aplicativo
  // Checa com segurança se a infraestrutura do Firebase está pronta
  bool _isFirebaseDisponivel() {
    // Tenta acessar a lista de instâncias de FirebaseApps
    try {
      // Retorna verdadeiro se houver ao menos um app Firebase ativo
      return Firebase.apps.isNotEmpty;
    // Captura erros quando o Firebase não foi configurado no ambiente
    } catch (_) {
      // Retorna falso indicando ausência de backend Firebase
      return false;
    // Fechamento do bloco catch
    }
  // Fechamento do método _isFirebaseDisponivel
  }

  // Sobrescrita do ciclo de vida disparada na inserção do widget na árvore
  @override
  // Método de inicialização de controladores, ouvintes e conexões
  void initState() {
    // Executa a inicialização padrão da classe pai State
    super.initState();

    // Identifica se dados mockados foram explicitamente fornecidos (comum em testes)
    // Verifica se alguma lista de teste foi injetada via construtor
    final temMockExplicitamente =
        // Checa se mockPacientes foi fornecido
        widget.mockPacientes != null ||
        // Checa se mockMotoristas foi fornecido
        widget.mockMotoristas != null ||
        // Checa se mockAdmins foi fornecido
        widget.mockAdmins != null;

    // Inicialização síncrona com dados de fallback/testes
    // Define a lista inicial de pacientes a partir dos mocks ou lista padrão de demonstração
    final pacientesIniciais =
        // Se foi injetado mock de pacientes, utiliza-o
        widget.mockPacientes ??
        // Se houver mock explícito em outra entidade, lista vazia; senão lista estática padrão
        (temMockExplicitamente
            // Lista vazia para não misturar dados fictícios padrão com mocks específicos de testes
            ? <PacienteModel>[]
            // Lista com pacientes fictícios para demonstração
            : [
                // Primeiro paciente fictício
                PacienteModel(
                  // ID de exemplo
                  id: 'pac_1',
                  // Nome completo
                  nome: 'Maria Silva Santos',
                  // CPF
                  cpf: '123.456.789-00',
                  // Telefone
                  telefone: '(14) 99876-5432',
                  // Endereço residencial
                  enderecoPaciente: 'Rua das Flores, 123',
                  // Unidade hospitalar
                  localConsulta: 'Hospital de Base',
                  // Status
                  status: 0,
                // Fechamento de pac_1
                ),
                // Segundo paciente fictício
                PacienteModel(
                  // ID de exemplo
                  id: 'pac_2',
                  // Nome completo
                  nome: 'Carlos Eduardo Oliveira',
                  // CPF
                  cpf: '234.567.890-11',
                  // Telefone
                  telefone: '(14) 99123-4567',
                  // Endereço residencial
                  enderecoPaciente: 'Av. Brasil, 450',
                  // Unidade de saúde
                  localConsulta: 'AME Bauru',
                  // Status
                  status: 1,
                // Fechamento de pac_2
                ),
              // Fechamento da lista padrão de pacientes
              ]);

    // Define a lista inicial de motoristas a partir dos mocks ou exemplo padrão
    final motoristasIniciais =
        // Se foi injetado mock de motoristas, utiliza-o
        widget.mockMotoristas ??
        // Se houver mock de outro tipo, lista vazia; senão lista com motorista padrão
        (temMockExplicitamente
            // Lista vazia
            ? <MotoristaModel>[]
            // Lista com motorista padrão
            : [
                // Motorista padrão de exemplo
                MotoristaModel(
                  // ID de exemplo
                  id: 'mot_1',
                  // Nome completo
                  nome: 'João de Deus Pereira',
                  // CPF
                  cpf: '456.789.012-33',
                  // Telefone
                  telefone: '(14) 99777-8899',
                  // E-mail institucional
                  email: 'joao@saude.sp.gov.br',
                  // CNH
                  cnh: '01234567890',
                  // Modelo do veículo
                  veiculoModelo: 'Chevrolet Spin',
                  // Placa do veículo
                  veiculoPlaca: 'BRA2E19',
                // Fechamento de mot_1
                ),
              // Fechamento da lista de motoristas
              ]);

    // Define a lista inicial de administradores a partir dos mocks ou exemplo padrão
    final adminsIniciais =
        // Se foi injetado mock de administradores, utiliza-o
        widget.mockAdmins ??
        // Se houver mock de outro tipo, lista vazia; senão lista com admin padrão
        (temMockExplicitamente
            // Lista vazia
            ? <AdminModel>[]
            // Lista com administradora padrão
            : [
                // Administradora padrão de exemplo
                AdminModel(
                  // ID de exemplo
                  id: 'adm_1',
                  // Nome completo
                  nome: 'Dra. Fernanda Vasconcelos',
                  // CPF
                  cpf: '678.901.234-55',
                  // E-mail institucional
                  email: 'fernanda.admin@saude.sp.gov.br',
                  // Telefone
                  telefone: '(14) 99111-0022',
                  // Papel de administrador
                  role: 'admin',
                // Fechamento de adm_1
                ),
              // Fechamento da lista de administradores
              ]);

    // Unificação na lista polimórfica
    // Agrupa e converte todas as entidades iniciais no ViewModel unificado PessoaItem
    _todasPessoas = [
      // Mapeia todos os pacientes para PessoaItem
      ...pacientesIniciais.map(PessoaItem.fromPaciente),
      // Mapeia todos os motoristas para PessoaItem
      ...motoristasIniciais.map(PessoaItem.fromMotorista),
      // Mapeia todos os administradores para PessoaItem
      ...adminsIniciais.map(PessoaItem.fromAdmin),
    // Fechamento da lista unificada
    ];
    // Executa a primeira passada de filtros e contagem
    _atualizarFiltros();
    // Marca o carregamento inicial como concluído
    _carregando = false;

    // Listener para reagir à digitação de busca do usuário
    // Registra callback no controlador de texto para busca dinâmica ao digitar
    _buscaController.addListener(() {
      // Extrai o texto digitado sem espaços nas bordas e em letras minúsculas
      final novoTermo = _buscaController.text.trim().toLowerCase();
      // Se o termo modificado for diferente do termo corrente
      if (novoTermo != _termoBusca) {
        // Atualiza o estado da tela com o novo termo e reexecuta os filtros
        setState(() {
          // Atribui o novo termo de pesquisa
          _termoBusca = novoTermo;
          // Recalcula as listas filtradas
          _atualizarFiltros();
        // Fechamento do callback de setState
        });
      // Fechamento da verificação if novoTermo
      }
    // Fechamento do listener do buscaController
    });

    // Inicia a sincronização com o banco de dados remoto
    // Dispara a escuta em tempo real do Cloud Firestore
    _iniciarEscutaFirebase();
  // Fechamento do método initState
  }

  /// Conecta e escuta as mudanças em tempo real na coleção 'usuarios' do Firestore
  // Método responsável pela conexão e escuta da coleção 'usuarios'
  void _iniciarEscutaFirebase() {
    // Permite injeção de stream externa para testes de integração
    // Se foi injetada uma stream simulada de lista de pessoas
    if (widget.streamOverride != null) {
      // Assina a stream simulada diretamente
      _inscricaoUsuarios = widget.streamOverride!.listen((pessoas) {
        // Aborta se o widget não estiver mais montado
        if (!mounted) return;
        // Atualiza a lista unificada no estado e reprocessa filtros
        setState(() {
          // Atualiza a lista completa com os dados recebidos
          _todasPessoas = pessoas;
          // Finaliza o carregamento
          _carregando = false;
          // Recalcula contadores e lista filtrada
          _atualizarFiltros();
        // Fechamento do setState
        });
      // Fechamento do listen
      });
      // Retorna imediatamente após registrar a escuta simulada
      return;
    // Fechamento do if de streamOverride
    }

    // Se o Firebase estiver ativo e operacional
    if (_isFirebaseDisponivel()) {
      // Registra a assinatura da stream da coleção 'usuarios'
      _inscricaoUsuarios = FirebaseFirestore.instance
          // Coleção raiz de usuários
          .collection('usuarios')
          // Escuta alterações em tempo real nos documentos
          .snapshots()
          // Mapeia o snapshot bruto para a lista de PessoaItem
          .map((snapshot) {
            // Cria a lista vazia temporária
            final lista = <PessoaItem>[];
            // Itera sobre todos os documentos emitidos
            for (final doc in snapshot.docs) {
              // Bloco protegido contra falhas em documentos com campos corrompidos
              try {
                // Obtém o mapa de atributos do documento
                final dados = doc.data();

                // Respeita a regra de exclusão lógica (ignora inativados)
                // Lê o campo de atividade cadastral
                final ativo = dados['ativo'];
                // Se o registro foi explicitamente inativado, salta a iteração
                if (ativo == false || ativo == 'false') continue;

                // Lê o papel de acesso
                final rawRole = dados['role'];
                // Normaliza o papel para minúsculas com fallback para 'paciente'
                final role = (rawRole != null)
                    ? rawRole.toString().trim().toLowerCase()
                    : 'paciente';

                // Converte o documento bruto do Firestore no modelo adequado
                // Se for administrador
                if (role == 'admin' || role == 'administrador') {
                  // Converte para AdminModel
                  final admin = AdminModel.fromMap(dados, docId: doc.id);
                  // Adiciona o PessoaItem correspondente
                  lista.add(PessoaItem.fromAdmin(admin));
                // Se for motorista
                } else if (role == 'motorista') {
                  // Converte para MotoristaModel
                  final motorista = MotoristaModel.fromMap(dados, docId: doc.id);
                  // Adiciona o PessoaItem correspondente
                  lista.add(PessoaItem.fromMotorista(motorista));
                // Se for paciente (ou papel desconhecido/padrão)
                } else {
                  // Converte para PacienteModel
                  final paciente = PacienteModel.fromMap(dados, docId: doc.id);
                  // Adiciona o PessoaItem correspondente
                  lista.add(PessoaItem.fromPaciente(paciente));
                // Fechamento da condicional de perfil
                }
              // Captura qualquer erro de conversão de documento individual
              } catch (e) {
                // Previne que um registro com formato corrompido quebre toda a listagem
                // Loga o erro no console de debug sem travar a interface
                debugPrint('Aviso: documento ${doc.id} ignorado: $e');
              // Fechamento do bloco catch
              }
            // Fechamento do for de documentos
            }
            // Retorna a lista unificada processada
            return lista;
          // Fechamento do map
          })
          // Registra os callbacks de escuta dos dados emitidos
          .listen(
            // Callback chamado com a lista processada a cada atualização
            (pessoas) {
              // Aborta se o widget foi desmontado
              if (!mounted) return;
              // Atualiza o estado da tela
              setState(() {
                // Atualiza a lista caso o Firestore possua registros
                // Se o banco contiver ao menos um registro, substitui a lista em memória
                if (pessoas.isNotEmpty) {
                  // Atribui os novos registros
                  _todasPessoas = pessoas;
                // Fechamento do if de pessoas não vazio
                }
                // Finaliza o carregamento
                _carregando = false;
                // Limpa mensagem de erro prévia
                _erroGeral = null;
                // Atualiza contadores e itens filtrados
                _atualizarFiltros();
              // Fechamento do setState
              });
            // Fechamento do callback de sucesso
            },
            // Callback chamado em caso de erro na stream remota
            onError: (dynamic erro) {
              // Aborta se o widget foi desmontado
              if (!mounted) return;
              // Extrai a mensagem descritiva do erro
              final msg = erro != null ? erro.toString() : 'Erro de conexão';
              // Atualiza o estado com a mensagem de erro
              setState(() {
                // Formata o aviso de falha de sincronização
                _erroGeral = 'Falha ao sincronizar com o banco: $msg';
                // Finaliza o indicador de carregamento
                _carregando = false;
              // Fechamento do setState
              });
            // Fechamento do callback onError
            },
          // Fechamento do listen
          );
    // Fechamento do if de Firebase disponível
    }
  // Fechamento do método _iniciarEscutaFirebase
  }

  // Sobrescrita do ciclo de vida quando o widget é destruído permanentemente
  @override
  // Método de liberação de recursos para evitar vazamentos de memória
  void dispose() {
    // Libera a inscrição do stream para evitar vazamentos de memória (memory leaks)
    // Cancela a inscrição no Firestore
    _inscricaoUsuarios?.cancel();
    // Descarta o controlador de texto
    // Libera o TextEditingController de pesquisa
    _buscaController.dispose();
    // Executa a finalização da classe pai
    super.dispose();
  // Fechamento do método dispose
  }

  /// Executa a contagem e a filtragem unificadas em uma única passada O(N)
  /// eliminando iterações repetidas e cálculos concorrentes dentro do build
  // Método otimizado de contagem e filtragem linear O(N)
  void _atualizarFiltros() {
    // Contador acumulado de pacientes
    int pacientes = 0;
    // Contador acumulado de motoristas
    int motoristas = 0;
    // Contador acumulado de administradores
    int admins = 0;
    // Lista para acumular os itens que atendem a todos os filtros
    final filtrados = <PessoaItem>[];

    // Percorre cada pessoa uma única vez
    for (final p in _todasPessoas) {
      // 1. Contabiliza totais consolidados por papel em passada única
      // Incrementa o contador correspondente ao papel do usuário
      if (p.role == 'paciente') {
        // Soma paciente
        pacientes++;
      // Incrementa motoristas
      } else if (p.role == 'motorista') {
        // Soma motorista
        motoristas++;
      // Incrementa administradores
      } else if (p.role == 'admin' || p.role == 'administrador') {
        // Soma admin
        admins++;
      // Fechamento da contagem por papel
      }

      // 2. Aplica filtro de papel da aba selecionada
      // Avalia se o registro combina com a categoria selecionada na barra de abas
      final correspondeAba = switch (_filtroRole) {
        // Aba 'todos' aceita qualquer perfil
        'todos' => true,
        // Aba 'paciente' filtra apenas pacientes
        'paciente' => p.role == 'paciente',
        // Aba 'motorista' filtra apenas motoristas
        'motorista' => p.role == 'motorista',
        // Aba 'admin' filtra administradores
        'admin' => p.role == 'admin' || p.role == 'administrador',
        // Fallback padrão
        _ => true,
      // Fechamento do switch de verificação de aba
      };

      // Se não corresponder à aba selecionada, pula para o próximo registro
      if (!correspondeAba) continue;

      // 3. Aplica filtro textual de busca por Nome ou CPF
      // Se houver termo de busca e o registro não contiver o texto nem no nome nem no CPF
      if (_termoBusca.isNotEmpty &&
          !p.nome.toLowerCase().contains(_termoBusca) &&
          !p.cpf.contains(_termoBusca)) {
        // Salta o registro que não atende ao critério de busca
        continue;
      // Fechamento da validação textual
      }

      // Adiciona o registro validado à lista de filtrados
      filtrados.add(p);
    // Fechamento do loop for
    }

    // Atribui os contadores consolidados às variáveis de estado
    _totalPacientes = pacientes;
    // Atribui o total de motoristas
    _totalMotoristas = motoristas;
    // Atribui o total de administradores
    _totalAdmins = admins;
    // Atribui a lista filtrada para consumo na interface
    _pessoasFiltradas = filtrados;
  // Fechamento do método _atualizarFiltros
  }

  /// Diálogo puro de confirmação: apresenta as justificativas de governança e auditoria
  // Exibe o diálogo modal de confirmação antes de inativar uma pessoa
  Future<bool?> _mostrarConfirmacaoInativacao(String nome) {
    // Abre a caixa de diálogo modal e retorna um booleano assíncrono
    return showDialog<bool>(
      // Contexto da tela
      context: context,
      // Construtor do widget do diálogo
      builder: (ctx) => AlertDialog(
        // Cantos arredondados do diálogo
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // Título estilizado com ícone de aviso e texto em vermelho
        title: Row(
          // Filhos do título em linha horizontal
          children: const [
            // Ícone triangular de aviso em tom vermelho
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            // Espaçamento horizontal entre ícone e texto
            SizedBox(width: 8),
            // Título do diálogo
            Text(
              // Texto do título
              'Inativar Registro',
              // Estilização tipográfica em negrito
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            // Fechamento do Text
            ),
          // Fechamento dos filhos da Row
          ],
        // Fechamento do title
        ),
        // Corpo do diálogo explicando as consequências de governança e auditoria
        content: Text(
          // Mensagem formatada com interpolação do nome da pessoa
          'Deseja inativar $nome?\n\n'
          'Conforme as regras de governança e auditoria, o registro ficará indisponível para novos agendamentos.',
          // Estilização do texto explicativo em tom cinza escuro
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        // Fechamento do content
        ),
        // Botões de ação do diálogo
        actions: [
          // Botão de cancelamento que fecha o diálogo retornando false
          TextButton(
            // Fecha o diálogo com resultado falso
            onPressed: () => Navigator.pop(ctx, false),
            // Rótulo textual de cancelamento
            child: const Text(
              // Texto do botão
              'Cancelar',
              // Cor suave para ação secundária
              style: TextStyle(color: Color(0xFF64748B)),
            // Fechamento do Text
            ),
          // Fechamento do TextButton
          ),
          // Botão de confirmação de inativação com fundo vermelho
          ElevatedButton(
            // Estilo do botão de confirmação
            style: ElevatedButton.styleFrom(
              // Cor vermelha de alerta
              backgroundColor: const Color(0xFFDC2626),
              // Cor branca do texto
              foregroundColor: Colors.white,
              // Cantos arredondados do botão
              shape: RoundedRectangleBorder(
                // Raio de 8 pixels
                borderRadius: BorderRadius.circular(8),
              // Fechamento do RoundedRectangleBorder
              ),
            // Fechamento do styleFrom
            ),
            // Fecha o diálogo com resultado verdadeiro confirmando a operação
            onPressed: () => Navigator.pop(ctx, true),
            // Rótulo de confirmação
            child: const Text('Confirmar Inativação'),
          // Fechamento do ElevatedButton
          ),
        // Fechamento da lista actions
        ],
      // Fechamento do AlertDialog
      ),
    // Fechamento do showDialog
    );
  // Fechamento do método _mostrarConfirmacaoInativacao
  }

  /// Executa o fluxo de inativação lógica no Firestore e atualiza o estado local
  // Método assíncrono disparado ao confirmar a inativação de uma pessoa
  Future<void> _aoInativar(PessoaItem pessoa) async {
    // Exibe o diálogo de confirmação e aguarda a resposta do usuário
    final confirmado = await _mostrarConfirmacaoInativacao(pessoa.nome);
    // Se o usuário confirmou a operação e o widget ainda estiver montado
    if (confirmado == true && mounted) {
      // Ativa o estado de salvamento para bloquear ações concorrentes
      setState(() {
        // Bloqueia ações interativas
        _salvando = true;
      // Fechamento do setState
      });

      // Aplica a exclusão lógica no Cloud Firestore (ativo = false)
      // Se a conexão com o Firebase estiver ativa
      if (_isFirebaseDisponivel()) {
        // Tenta atualizar remotamente o documento
        try {
          // Atualiza o documento no Firestore marcando 'ativo: false'
          await FirebaseFirestore.instance
              // Coleção de usuários
              .collection('usuarios')
              // Documento correspondente ao ID da pessoa
              .doc(pessoa.id)
              // Atualiza apenas a flag de atividade cadastral
              .update({'ativo': false});
        // Captura eventuais erros de rede ou permissão
        } catch (e) {
          // Se o widget ainda estiver montado na árvore
          if (mounted) {
            // Registra a mensagem de erro no estado da tela
            setState(() {
              // Formata mensagem de falha
              _erroGeral = 'Falha ao inativar no Firebase: $e';
            // Fechamento do setState
            });
          // Fechamento do if mounted
          }
        // Fechamento do bloco catch
        }
      // Fechamento do if Firebase disponível
      }

      // Atualiza a memória local para resposta visual imediata ao usuário
      // Atualiza a lista em memória sem precisar recarregar toda a coleção
      setState(() {
        // Remove a pessoa inativada da lista local
        _todasPessoas.removeWhere(
          // Localiza pelo identificador e papel
          (p) => p.id == pessoa.id && p.role == pessoa.role,
        // Fechamento do removeWhere
        );
        // Recalcula contadores e itens visíveis
        _atualizarFiltros();
        // Desbloqueia as interações
        _salvando = false;
      // Fechamento do setState
      });
    // Fechamento do if de confirmação
    }
  // Fechamento do método _aoInativar
  }

  /// Constrói o banner de alerta em caso de falha de comunicação ou sincronização
  // Constrói o widget de banner de erro vermelho
  Widget _construirMensagemErro() {
    // Se não houver erro registrado, retorna um widget encolhido invisível
    if (_erroGeral == null) return const SizedBox.shrink();

    // Espaçamento inferior para o banner de erro
    return Padding(
      // Recuo de 14 pixels abaixo do banner
      padding: const EdgeInsets.only(bottom: 14),
      // Contêiner estilizado avermelhado
      child: Container(
        // Recuo interno de 12 pixels
        padding: const EdgeInsets.all(12),
        // Decoração do banner
        decoration: BoxDecoration(
          // Fundo vermelho suave
          color: Colors.red.shade50,
          // Cantos arredondados de 8 pixels
          borderRadius: BorderRadius.circular(8),
          // Borda vermelha suave
          border: Border.all(color: Colors.red.shade300),
        // Fechamento do BoxDecoration
        ),
        // Linha com ícone e texto de erro
        child: Row(
          // Alinhamento ao topo vertical
          crossAxisAlignment: CrossAxisAlignment.start,
          // Filhos da linha
          children: [
            // Ícone de erro em vermelho escuro
            Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
            // Espaçamento horizontal
            const SizedBox(width: 8),
            // Texto expandido que ocupa a largura disponível
            Expanded(
              // Exibe a mensagem de erro
              child: Text(
                // Mensagem armazenada
                _erroGeral!,
                // Estilo tipográfico do texto de erro
                style: TextStyle(
                  // Tamanho da fonte
                  fontSize: 12,
                  // Peso semi-negrito
                  fontWeight: FontWeight.w600,
                  // Cor vermelha escura
                  color: Colors.red.shade900,
                // Fechamento do TextStyle
                ),
              // Fechamento do Text
              ),
            // Fechamento do Expanded
            ),
          // Fechamento da lista children
          ],
        // Fechamento da Row
        ),
      // Fechamento do Container
      ),
    // Fechamento do Padding
    );
  // Fechamento do método _construirMensagemErro
  }

  /// Constrói o campo de busca com bordas suaves e ícones padronizados
  // Constrói o campo visual de pesquisa
  Widget _construirCampoBusca() {
    // Retorna o TextField conectado ao controlador de busca
    return TextField(
      // Controlador de texto
      controller: _buscaController,
      // Decoração e estilo do campo
      decoration: InputDecoration(
        // Ícone de lupa no início do campo
        prefixIcon: const Icon(
          // Ícone de busca
          Icons.search,
          // Tamanho de 20 pixels
          size: 20,
          // Cor cinza suave
          color: Color(0xFF64748B),
        // Fechamento do Icon
        ),
        // Botão para limpar a busca exibido somente quando há texto digitado
        suffixIcon: _termoBusca.isNotEmpty
            // Botão de limpeza
            ? IconButton(
                // Ícone de fechar / limpar
                icon: const Icon(
                  // Ícone de X
                  Icons.clear,
                  // Tamanho de 20 pixels
                  size: 20,
                  // Cor cinza suave
                  color: Color(0xFF64748B),
                // Fechamento do Icon
                ),
                // Limpa o conteúdo do campo ao tocar
                onPressed: () => _buscaController.clear(),
              // Fechamento do IconButton
              )
            // Caso não haja texto digitado, não exibe ícone de sufixo
            : null,
        // Dica de texto no campo
        hintText: 'Buscar por nome ou CPF...',
        // Estilo tipográfico da dica
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        // Reduz o preenchimento vertical para formato mais compacto
        isDense: true,
        // Espaçamento interno das bordas ao texto
        contentPadding: const EdgeInsets.symmetric(
          // Recuo horizontal de 14 pixels
          horizontal: 14,
          // Recuo vertical de 12 pixels
          vertical: 12,
        // Fechamento do EdgeInsets
        ),
        // Habilita cor de fundo preenchida
        filled: true,
        // Cor cinza azulada suave de fundo
        fillColor: const Color(0xFFF1F5F9),
        // Borda arredondada sem contorno duro
        border: OutlineInputBorder(
          // Raio de 12 pixels
          borderRadius: BorderRadius.circular(12),
          // Sem linha de borda externa
          borderSide: BorderSide.none,
        // Fechamento do OutlineInputBorder
        ),
      // Fechamento do InputDecoration
      ),
    // Fechamento do TextField
    );
  // Fechamento do método _construirCampoBusca
  }

  /// Constrói um ChoiceChip individual para a barra de seleção de papéis
  // Constrói uma aba/chip interativa para filtragem de perfil
  Widget _construirChipFiltro(String role, String label) {
    // Checa se a role passada é a que está selecionada no momento
    final ativo = _filtroRole == role;
    // Retorna o ChoiceChip estilizado
    return ChoiceChip(
      // Rótulo textual do chip
      label: Text(label),
      // Estado de seleção ativo/inativo
      selected: ativo,
      // Cor de fundo quando selecionado (azul escuro elegante)
      selectedColor: const Color(0xFF0F172A),
      // Estilo tipográfico do rótulo
      labelStyle: TextStyle(
        // Texto branco quando ativo, cinza quando inativo
        color: ativo ? Colors.white : const Color(0xFF475569),
        // Negrito quando ativo, peso médio quando inativo
        fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
        // Tamanho de fonte
        fontSize: 13,
      // Fechamento do TextStyle
      ),
      // Cor de fundo quando inativo
      backgroundColor: const Color(0xFFF1F5F9),
      // Sem contorno de borda lateral
      side: BorderSide.none,
      // Formato arredondado de pílula
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Callback disparado ao selecionar o chip
      onSelected: (_) {
        // Atualiza a aba selecionada no estado
        setState(() {
          // Atribui o novo perfil selecionado
          _filtroRole = role;
          // Recalcula a filtragem
          _atualizarFiltros();
        // Fechamento do setState
        });
      // Fechamento do onSelected
      },
    // Fechamento do ChoiceChip
    );
  // Fechamento do método _construirChipFiltro
  }

  /// Constrói a linha horizontal de abas de filtro com contadores automáticos
  // Constrói o container rolável horizontal com os chips de filtro
  Widget _construirBarraFiltros({
    // Parâmetro obrigatório com o total geral de pessoas
    required int totalGeral,
    // Parâmetro obrigatório com o total de pacientes
    required int totalPacientes,
    // Parâmetro obrigatório com o total de motoristas
    required int totalMotoristas,
    // Parâmetro obrigatório com o total de administradores
    required int totalAdmins,
  // Fechamento da lista de parâmetros
  }) {
    // Habilita rolagem horizontal para que caibam todos os chips confortavelmente
    return SingleChildScrollView(
      // Eixo de rolagem horizontal
      scrollDirection: Axis.horizontal,
      // Linha contendo a sequência de chips
      child: Row(
        // Filhos da linha
        children: [
          // Chip para a opção 'Todos'
          _construirChipFiltro('todos', 'Todos ($totalGeral)'),
          // Espaçamento horizontal entre chips
          const SizedBox(width: 8),
          // Chip para a opção 'Pacientes'
          _construirChipFiltro('paciente', 'Pacientes ($totalPacientes)'),
          // Espaçamento horizontal entre chips
          const SizedBox(width: 8),
          // Chip para a opção 'Motoristas'
          _construirChipFiltro('motorista', 'Motoristas ($totalMotoristas)'),
          // Espaçamento horizontal entre chips
          const SizedBox(width: 8),
          // Chip para a opção 'Administradores'
          _construirChipFiltro('admin', 'Administradores ($totalAdmins)'),
        // Fechamento dos filhos da Row
        ],
      // Fechamento da Row
      ),
    // Fechamento do SingleChildScrollView
    );
  // Fechamento do método _construirBarraFiltros
  }

  /// Constrói o estado vazio amigável quando nenhum registro atende aos critérios
  // Constrói a mensagem centralizada amigável quando a busca ou filtro retorna zero itens
  Widget _construirEstadoVazio() {
    // Centraliza o conteúdo na tela
    return Center(
      // Espaçamento uniforme
      child: Padding(
        // Recuo de 24 pixels
        padding: const EdgeInsets.all(24.0),
        // Coluna com ícone e mensagens
        child: Column(
          // Ocupa o tamanho vertical mínimo
          mainAxisSize: MainAxisSize.min,
          // Filhos da mensagem de estado vazio
          children: [
            // Ícone temático de busca de pessoas
            Icon(
              // Ícone de pessoa com lupa
              Icons.person_search_outlined,
              // Tamanho destacado de 48 pixels
              size: 48,
              // Cor cinza suave
              color: Colors.grey.shade400,
            // Fechamento do Icon
            ),
            // Espaçamento vertical
            const SizedBox(height: 12),
            // Título do estado vazio
            const Text(
              // Texto principal
              'Nenhuma pessoa encontrada',
              // Estilização tipográfica em negrito
              style: TextStyle(
                // Tamanho de fonte 15
                fontSize: 15,
                // Peso negrito
                fontWeight: FontWeight.bold,
                // Cor cinza escuro
                color: Color(0xFF334155),
              // Fechamento do TextStyle
              ),
            // Fechamento do Text
            ),
            // Espaçamento vertical sutil
            const SizedBox(height: 4),
            // Subtítulo orientando o usuário
            const Text(
              // Mensagem instrucional
              'Tente buscar com outro nome ou número de CPF.',
              // Estilo secundário
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              // Centralização do texto
              textAlign: TextAlign.center,
            // Fechamento do Text
            ),
          // Fechamento da lista children
          ],
        // Fechamento da Column
        ),
      // Fechamento do Padding
      ),
    // Fechamento do Center
    );
  // Fechamento do método _construirEstadoVazio
  }

  /// Constrói a lista virtualizada de cards reaproveitando [CardIdentificacaoPaciente]
  // Constrói a listagem virtualizada de alta eficiência com ListView.builder
  Widget _construirListaPessoas() {
    // Se ainda estiver na fase de carregamento inicial
    if (_carregando) {
      // Exibe o círculo giratório de progresso
      return const Center(child: CircularProgressIndicator());
    // Fechamento do if carregando
    }

    // Se após carregar a lista de pessoas filtradas estiver vazia
    if (_pessoasFiltradas.isEmpty) {
      // Exibe a tela amigável de estado vazio
      return _construirEstadoVazio();
    // Fechamento do if vazia
    }

    // Constrói a lista sob demanda (virtualizada) para economia de memória
    return ListView.builder(
      // Espaçamento inferior generoso para não sobrepor o botão flutuante 'Novo'
      padding: const EdgeInsets.only(bottom: 80),
      // Quantidade de itens a serem renderizados
      itemCount: _pessoasFiltradas.length,
      // Construtor do widget do item por índice
      itemBuilder: (context, index) {
        // Obtém a pessoa correspondente ao índice
        final pessoa = _pessoasFiltradas[index];
        // Envolve o card em um Padding com chave única
        return Padding(
          // Chave composta para garantir unicidade absoluta entre diferentes papéis
          // Chave única para o gerenciador de estado do Flutter
          key: ValueKey('${pessoa.role}_${pessoa.id}'),
          // Espaçamento inferior entre os cartões
          padding: const EdgeInsets.only(bottom: 12),
          // Componente visual reaproveitado de identificação da pessoa
          child: CardIdentificacaoPaciente(
            // Nome completo da pessoa
            nome: pessoa.nome,
            // CPF da pessoa
            cpf: pessoa.cpf,
            // Status numérico
            status: pessoa.status,
            // Rótulo da badge (Paciente, Motorista ou Administrador)
            labelBadge: pessoa.badgeLabel,
            // Cor temática da badge
            corBadge: pessoa.badgeCor,
            // Telefone para contato
            telefone: pessoa.telefone,
            // Detalhe extra (veículo, consulta ou e-mail)
            detalheExtra: pessoa.detalheExtra,
            // Ação de edição (atualmente vazia para implementação futura)
            onEditar: () {},
            // Ação de inativação disparando o diálogo com fluxo de auditoria
            onInativar: () => _aoInativar(pessoa),
          // Fechamento do CardIdentificacaoPaciente
          ),
        // Fechamento do Padding
        );
      // Fechamento do itemBuilder
      },
    // Fechamento do ListView.builder
    );
  // Fechamento do método _construirListaPessoas
  }

  // Método que constrói a árvore de widgets da tela de pessoas
  @override
  // Recebe o contexto de montagem
  Widget build(BuildContext context) {
    // Retorna a estrutura visual com Scaffold
    return Scaffold(
      // Fundo padronizado com o tema do sistema
      backgroundColor: const Color(0xFFF8FAFC),
      // Barra de navegação superior com identidade visual consistente
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 2,
        // Botão de retorno na extremidade esquerda
        leading: IconButton(
          // Ícone de seta de retorno
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          // Ação disparada ao pressionar o botão voltar
          onPressed: () {
            // Retorna à tela anterior ou navega para a rota raiz
            // Se houver rota anterior para desempilhar
            if (Navigator.of(context).canPop()) {
              // Desempilha e volta
              Navigator.of(context).pop();
            // Caso contrário
            } else {
              // Redireciona para a rota inicial '/'
              Navigator.of(context).pushReplacementNamed('/');
            // Fechamento da condicional if/else
            }
          // Fechamento do onPressed
          },
        // Fechamento do IconButton
        ),
        // Título central da AppBar
        title: const Text(
          'Gestão de Pessoas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      // Fechamento do AppBar
      ),
      // Botão flutuante expandido para adição de novos cadastros
      floatingActionButton: FloatingActionButton.extended(
        // Desabilita toque se uma requisição estiver sendo processada
        onPressed: _salvando
            // Desabilitado
            ? null
            // Callback ativo
            : () {
                // TODO: Abrir formulário de cadastro de pessoas
                // Ação futura de abertura do formulário de cadastro
              // Fechamento da função anônima
              },
        // Cor de fundo do botão flutuante em tom escuro azulado
        backgroundColor: const Color(0xFF0F172A),
        // Cor branca do ícone e texto
        foregroundColor: Colors.white,
        // Ícone de adição com sinal de mais
        icon: const Icon(Icons.add),
        // Rótulo textual do botão flutuante
        label: const Text(
          // Texto 'Novo'
          'Novo',
          // Estilo em negrito
          style: TextStyle(fontWeight: FontWeight.bold),
        // Fechamento do Text
        ),
      // Fechamento do FloatingActionButton.extended
      ),
      // Área de corpo protegida contra entalhes de tela
      body: SafeArea(
        // Espaçamento horizontal e vertical do conteúdo principal
        child: Padding(
          // Recuo horizontal de 16 e vertical de 8 pixels
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // Coluna principal com os elementos da tela
          child: Column(
            // Estica os filhos na largura total
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // Lista de filhos da tela
            children: [
              // Banner de alerta de erros
              // Widget condicional que exibe erros de conexão ou persistência
              _construirMensagemErro(),

              // Campo de entrada de busca
              // Campo de pesquisa textual reativa
              _construirCampoBusca(),
              // Espaçamento vertical entre campo de busca e barra de filtros
              const SizedBox(height: 12),

              // Barra de filtros por categoria com rolagem horizontal
              // Fileira rolável de abas de filtro por papel com contadores
              _construirBarraFiltros(
                // Total consolidado de registros
                totalGeral: _todasPessoas.length,
                // Total de pacientes
                totalPacientes: _totalPacientes,
                // Total de motoristas
                totalMotoristas: _totalMotoristas,
                // Total de administradores
                totalAdmins: _totalAdmins,
              // Fechamento do _construirBarraFiltros
              ),
              // Espaçamento vertical entre filtros e lista de pessoas
              const SizedBox(height: 14),

              // Área de listagem virtualizada de pessoas
              // Lista virtualizada preenchendo o espaço restante da tela
              Expanded(child: _construirListaPessoas()),
            // Fechamento dos filhos da Column
            ],
          // Fechamento da Column
          ),
        // Fechamento do Padding
        ),
      // Fechamento do SafeArea
      ),
    // Fechamento do Scaffold
    );
  // Fechamento do método build
  }
// Fechamento da classe _ListaPessoasState
}
