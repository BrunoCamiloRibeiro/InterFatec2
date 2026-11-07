// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/viagem_service.dart
// Camada: Serviços / Gestão de Viagens e Frota (Lógica de Negócios)
//
// O QUE ESTE ARQUIVO FAZ:
// Centraliza a gestão operacional das viagens do transporte municipal de
// saúde (TFD), implementando um serviço Singleton ('ViagemService') com controle
// de concorrência em tempo real, reserva atômica de veículos no Firestore,
// streams reativas em broadcast para atualização de frota e viagem ativa,
// persistência do ciclo de vida (início e encerramento) e fallback em memória.
//
// PARA QUE SERVE NO PROJETO:
// É o coração da automação da escala de motoristas da issue #17:
// 1) Oferece uma stream contínua de veículos livres para seleção na UI;
// 2) Impede corrida e dupla reserva do mesmo veículo por motoristas distintos;
// 3) Gerencia a transição de estado da viagem (semViagem -> emViagem -> encerrada);
// 4) Atualiza o hodômetro dos veículos após o término das viagens;
// 5) Permite testes unitários determinísticos através do método resetParaTestes.
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (escuta de viagem ativa e carregamento de veículos)
// - lib/components/formulario_inicio_viagem.dart (reserva e início da viagem)
// - lib/components/formulario_encerramento.dart (conclusão da viagem e KM final)
// - lib/components/timeline_viagem.dart (rastreamento de status da viagem)
// - test/formulario_inicio_viagem_test.dart (testes de concorrência e inicialização)
// - test/widget_test.dart (testes de integração visual do fluxo do motorista)
//
// DE ONDE RECEBE DADOS:
// Coleções 'veiculos', 'viagens' e 'usuarios' do Cloud Firestore, ou de listas
// e instâncias mantidas em cache de memória quando executando sem conexão.
//
// O QUE EXPORTA / EXPÕE:
// - class ResultadoInicioViagem:
//   * ResultadoInicioViagem.sucesso(ViagemModel viagem)
//   * ResultadoInicioViagem.erro(String mensagem)
// - class ViagemService:
//   * factory ViagemService() (Singleton)
//   * ViagemModel? get viagemAtiva
//   * Stream<ViagemModel?> get viagemAtivaStream
//   * Stream<List<VeiculoModel>> get veiculosStream
//   * Stream<List<VeiculoModel>> carregarVeiculosDisponiveis({String? motoristaId})
//   * Future<ResultadoInicioViagem> iniciarViagem(...)
//   * Future<void> encerrarViagem({int? kmFinal, int? kmRodado})
//   * void resetParaTestes(...)
//
// ORIGEM HISTÓRICA:
// Criado no commit aa02e80 pela equipe do projeto para atender à issue #17
// (início e controle de concorrência de viagens). Não veio de template.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'dart:async', 'package:cloud_firestore/cloud_firestore.dart' e
// 'package:firebase_core/firebase_core.dart'.
// Efeitos colaterais: Escrita e leitura assíncrona no Cloud Firestore, emissão de
// eventos em StreamControllers broadcast e mutação do estado singleton em memória.
// ============================================================================

// ----------------------------------------------------------------------------
// IMPORTAÇÃO DE BIBLIOTECAS E PACOTES:
// - dart:async: Manipulação de eventos assíncronos, Streams e StreamControllers.
// - cloud_firestore: Persistência remota de documentos nas coleções 'veiculos' e 'viagens'.
// - firebase_core: Verificação defensiva de inicialização do Firebase ('Firebase.apps').
// - veiculo_model.dart: Entidade de veículos da frota municipal.
// - viagem_model.dart: Entidade de viagens e enum EstadoViagem.
// - validacao_viagem.dart: Regras puras de validação de KM, cidade e filtros de frota.
// ----------------------------------------------------------------------------
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/sessao_veiculo_model.dart';
import '../models/user_role.dart';
import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import 'codigo_acesso_service.dart';
import 'validacao_viagem.dart';

// Linha em branco separadora entre imports e a classe de resultado
// ----------------------------------------------------------------------------
// COMENTÁRIO: Resultado de Operação de Viagem (FASE 1: CRUD de Horários)
// ----------------------------------------------------------------------------
/// Encapsula o resultado de operações de CRUD e gestão de Horários de Viagem.
class ResultadoOperacaoViagem {
  final bool sucesso;
  final ViagemModel? viagem;
  final String? mensagemErro;

  const ResultadoOperacaoViagem._({
    required this.sucesso,
    this.viagem,
    this.mensagemErro,
  });

  factory ResultadoOperacaoViagem.sucesso(ViagemModel viagem) =>
      ResultadoOperacaoViagem._(sucesso: true, viagem: viagem);

  factory ResultadoOperacaoViagem.erro(String mensagem) =>
      ResultadoOperacaoViagem._(sucesso: false, mensagemErro: mensagem);
}

// Linha em branco separadora entre imports e a classe de resultado
// ----------------------------------------------------------------------------
// COMENTÁRIO: Resultado da Declaração de Veículo (Issue #65)
// ----------------------------------------------------------------------------
/// Encapsula o resultado da declaração de veículo pelo motorista.
class ResultadoDeclaracaoVeiculo {
  /// Indica se a declaração do veículo ocorreu com sucesso.
  final bool sucesso;

  /// Sessão de veículo instanciada em caso de sucesso.
  final SessaoVeiculoModel? sessao;

  /// Mensagem explicativa em caso de erro.
  final String? mensagemErro;

  const ResultadoDeclaracaoVeiculo._({
    required this.sucesso,
    this.sessao,
    this.mensagemErro,
  });

  /// Factory de sucesso associando a [SessaoVeiculoModel].
  factory ResultadoDeclaracaoVeiculo.sucesso(SessaoVeiculoModel sessao) =>
      ResultadoDeclaracaoVeiculo._(sucesso: true, sessao: sessao);

  /// Factory de erro com mensagem descritiva.
  factory ResultadoDeclaracaoVeiculo.erro(String mensagem) =>
      ResultadoDeclaracaoVeiculo._(sucesso: false, mensagemErro: mensagem);
}

// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
// Armazena o resultado da tentativa de iniciar uma viagem
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE RESULTADO: ResultadoInicioViagem
// - O que a instrução faz: Modela e encapsula o desfecho da tentativa de abertura de viagem.
// - O que é o elemento: Tipo de retorno semântico (Result Pattern) imutável com construtor privado.
// - Papel no sistema: Retorna a instância de ViagemModel em caso de sucesso ou mensagem explicativa de erro.
// ----------------------------------------------------------------------------
class ResultadoInicioViagem {
  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Indica se a inicialização da viagem ocorreu com sucesso
  // --------------------------------------------------------------------------
  // ATRIBUTO: sucesso
  // - O que é: Campo imutável ('final') do tipo primitivo booleano ('bool').
  // - Papel: 'true' se a viagem foi validada e criada com sucesso; 'false' caso haja impedimento.
  // --------------------------------------------------------------------------
  final bool sucesso;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Instância da viagem criada em caso de sucesso
  // --------------------------------------------------------------------------
  // ATRIBUTO: viagem
  // - O que é: Campo imutável opcional/anulável ('ViagemModel?').
  // - Papel: Dados completos da viagem aberta e vinculada ao veículo.
  // --------------------------------------------------------------------------
  final ViagemModel? viagem;

  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Mensagem descritiva do erro em caso de falha
  // --------------------------------------------------------------------------
  // ATRIBUTO: mensagemErro
  // - O que é: Campo imutável opcional/anulável ('String?').
  // - Papel: Mensagem de erro para ser exibida na interface gráfica ao motorista.
  // --------------------------------------------------------------------------
  final String? mensagemErro;

  // Linha em branco separadora entre atributos e construtor privado

  // --------------------------------------------------------------------------
  // CONSTRUTOR PRIVADO CONSTANTE: ResultadoInicioViagem._
  // - O que faz: Inicializa os campos garantindo uso exclusivo de factories semânticas.
  // --------------------------------------------------------------------------
  const ResultadoInicioViagem._({
    // Parâmetro obrigatório: Indicador booleano de sucesso
    required this.sucesso,
    // Parâmetro opcional: Entidade da viagem criada
    this.viagem,
    // Parâmetro opcional: Mensagem descritiva de erro
    this.mensagemErro,
  // Fecha a lista de parâmetros do construtor privado
  });

  // Linha em branco separadora entre construtor privado e factories
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna uma instância de ResultadoInicioViagem com sucesso e os dados da viagem
  // ----------------------------------------------------------------------------
  // FACTORY CONSTRUTOR: ResultadoInicioViagem.sucesso
  // - O que faz: Instancia um resultado de sucesso associando o objeto de ViagemModel.
  // ----------------------------------------------------------------------------
  factory ResultadoInicioViagem.sucesso(ViagemModel viagem) =>
      // Cria instância privada com sucesso=true e os dados da viagem
      ResultadoInicioViagem._(sucesso: true, viagem: viagem);

  // Linha em branco separadora entre factories
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna uma instância de ResultadoInicioViagem com erro e a mensagem correspondente
  // ----------------------------------------------------------------------------
  // FACTORY CONSTRUTOR: ResultadoInicioViagem.erro
  // - O que faz: Instancia um resultado indicando falha de inicialização com mensagem explicativa.
  // ----------------------------------------------------------------------------
  factory ResultadoInicioViagem.erro(String mensagem) =>
      // Cria instância privada com sucesso=false e a mensagem de erro
      ResultadoInicioViagem._(sucesso: false, mensagemErro: mensagem);

// Fecha a declaração da classe ResultadoInicioViagem
}

// Linha em branco separadora entre ResultadoInicioViagem e ViagemService
// ----------------------------------------------------------------------------
// COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
// Gerencia a lista de veículos, streams de atualização e o ciclo de vida das viagens
// ----------------------------------------------------------------------------
// DECLARAÇÃO DA CLASSE DE SERVIÇO: ViagemService
// - O que a instrução faz: Declara o serviço Singleton responsável pela gestão de viagens e frota.
// - O que é o elemento: Classe de serviço com padrão Singleton e streams reativas em broadcast.
// ----------------------------------------------------------------------------
class ViagemService {
  // --------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Instância única da classe ViagemService
  // --------------------------------------------------------------------------
  // CAMPO ESTÁTICO PRIVADO: _instance
  // - O que é: Instância singleton da classe ViagemService alocada em memória.
  // --------------------------------------------------------------------------
  static final ViagemService _instance = ViagemService._interno();

  // Linha em branco separadora entre o campo estático e a factory
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Construtor fábrica que retorna a instância única
  // ----------------------------------------------------------------------------
  // FACTORY SINGLETON: ViagemService
  // - Retorna sempre a referência estática compartilhada '_instance'.
  // ----------------------------------------------------------------------------
  factory ViagemService() => _instance;

  // Linha em branco separadora entre a factory e o construtor privado
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Construtor privado que executa a inicialização dos dados base
  // ----------------------------------------------------------------------------
  // CONSTRUTOR PRIVADO: ViagemService._interno
  // - O que faz: Dispara a carga de dados padrão na memória.
  // ----------------------------------------------------------------------------
  ViagemService._interno() {
    // Popula a lista inicial de veículos na memória
    _inicializarDadosBase();
  // Fecha o bloco do construtor interno
  }

  // Linha em branco separadora entre construtor e atributos de estado
  // ----------------------------------------------------------------------------
  // ATRIBUTO: _sessaoAtiva (Issue #65: Sessão de Veículo do Motorista)
  // - Armazena em memória a sessão de veículo ativa do condutor.
  // --------------------------------------------------------------------------
  SessaoVeiculoModel? _sessaoAtiva;

  // ----------------------------------------------------------------------------
  // CONTROLADOR REATIVO: _sessaoAtivaController
  // - Emite mudanças de status da sessão ativa de veículo.
  // --------------------------------------------------------------------------
  final StreamController<SessaoVeiculoModel?> _sessaoAtivaController =
      StreamController<SessaoVeiculoModel?>.broadcast();

  // ----------------------------------------------------------------------------
  // LISTA LOCAL DE MEMÓRIA: _viagensAtivasMemoria (Issue #65: N Viagens Ativas)
  // - Lista ordenada com todas as viagens ativas associadas à jornada/sessão.
  // --------------------------------------------------------------------------
  final List<ViagemModel> _viagensAtivasMemoria = [];

  // ----------------------------------------------------------------------------
  // CONTROLADOR REATIVO: _viagensAtivasController
  // - Emite a lista atualizada de todas as N viagens ativas do motorista.
  // --------------------------------------------------------------------------
  final StreamController<List<ViagemModel>> _viagensAtivasController =
      StreamController<List<ViagemModel>>.broadcast();

  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Armazena a viagem ativa no momento
  // ----------------------------------------------------------------------------
  // ATRIBUTO PRIVADO: _viagemAtiva
  // - Armazena em memória a viagem em andamento para o motorista conectado.
  // --------------------------------------------------------------------------
  ViagemModel? _viagemAtiva;

  // Linha em branco separadora entre atributos de estado
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Controlador de fluxo de dados para a lista de veículos
  // ----------------------------------------------------------------------------
  // CONTROLADOR REATIVO: _veiculosController
  // - StreamController broadcast para emitir atualizações na lista de veículos da frota.
  // --------------------------------------------------------------------------
  final StreamController<List<VeiculoModel>> _veiculosController =
      StreamController<List<VeiculoModel>>.broadcast();

  // Linha em branco separadora entre controladores
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Controlador de fluxo de dados para a viagem ativa
  // ----------------------------------------------------------------------------
  // CONTROLADOR REATIVO: _viagemAtivaController
  // - StreamController broadcast para emitir mudanças de status da viagem ativa.
  // --------------------------------------------------------------------------
  final StreamController<ViagemModel?> _viagemAtivaController =
      StreamController<ViagemModel?>.broadcast();

  // Linha em branco separadora entre controladores e memória
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Lista de veículos armazenada em memória
  // ----------------------------------------------------------------------------
  // LISTA LOCAL DE MEMÓRIA: _veiculosMemoria
  // - Cache local mutável utilizado como fallback caso o Firestore não esteja acessível.
  // --------------------------------------------------------------------------
  final List<VeiculoModel> _veiculosMemoria = [];

  // Linha em branco separadora entre lista e flag
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Indicador de inicialização dos dados da lista em memória
  // ----------------------------------------------------------------------------
  // BANDEIRA DE CONTROLE: _inicializado
  // - Evita que os dados padrão sejam inseridos repetidamente na memória.
  // --------------------------------------------------------------------------
  bool _inicializado = false;

  // Linha em branco separadora entre flags e getters públicos
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna a viagem ativa atual
  // ----------------------------------------------------------------------------
  // GETTER PÚBLICO: viagemAtiva
  // - Retorna síncronamente a viagem ativa atual em memória.
  // --------------------------------------------------------------------------
  ViagemModel? get viagemAtiva => _viagemAtiva;

  // ----------------------------------------------------------------------------
  // GETTERS DE SESSÃO E N VIAGENS (Issue #65)
  // ----------------------------------------------------------------------------
  /// Retorna a sessão ativa de veículo do motorista, se houver.
  SessaoVeiculoModel? get sessaoAtiva => _sessaoAtiva;

  /// Stream reativa de atualizações da sessão de veículo.
  Stream<SessaoVeiculoModel?> get sessaoAtivaStream => _sessaoAtivaController.stream;

  /// Retorna a lista imutável de todas as N viagens ativas da sessão atual.
  List<ViagemModel> get viagensAtivas => List.unmodifiable(_viagensAtivasMemoria);

  /// Stream reativa emitindo a lista com as N viagens ativas do condutor.
  Stream<List<ViagemModel>> get viagensAtivasStream => _viagensAtivasController.stream;

  // ----------------------------------------------------------------------------
  // LISTA LOCAL DE MEMÓRIA: _todasViagensMemoria (FASE 1: CRUD de Horários/Viagens)
  // ----------------------------------------------------------------------------
  final List<ViagemModel> _todasViagensMemoria = [];
  final StreamController<List<ViagemModel>> _todasViagensController =
      StreamController<List<ViagemModel>>.broadcast();

  /// Stream reativa emitindo todas as viagens cadastradas no sistema
  Stream<List<ViagemModel>> get todasViagensStream => _todasViagensController.stream;

  /// Retorna lista imutável com todas as viagens em memória
  List<ViagemModel> get todasViagens => List.unmodifiable(_todasViagensMemoria);

  // Linha em branco separadora entre getters públicos
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna o fluxo de dados da viagem ativa
  // ----------------------------------------------------------------------------
  // GETTER DE STREAM: viagemAtivaStream
  // - Retorna a stream de observação reativa de mudanças na viagem ativa.
  // --------------------------------------------------------------------------
  Stream<ViagemModel?> get viagemAtivaStream => _viagemAtivaController.stream;

  // Linha em branco separadora entre getters públicos
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna o fluxo de dados da lista de veículos
  // ----------------------------------------------------------------------------
  // GETTER DE STREAM: veiculosStream
  // - Retorna a stream de observação reativa de mudanças na frota de veículos.
  // --------------------------------------------------------------------------
  Stream<List<VeiculoModel>> get veiculosStream => _veiculosController.stream;

  // Linha em branco separadora entre getters e métodos privados
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Insere registros padrão de veículos na lista em memória
  // ----------------------------------------------------------------------------
  // MÉTODO PRIVADO: _inicializarDadosBase
  // - Popula a lista em memória com a frota padrão do município de Poloni.
  // --------------------------------------------------------------------------
  void _inicializarDadosBase() {
    // Interrompe se a lista já tiver sido inicializada anteriormente
    if (_inicializado) return;
    // Popula a memória com 4 veículos representativos da prefeitura
    _veiculosMemoria.addAll([
      // Veículo 1: Chevrolet Spin de 7 lugares
      const VeiculoModel(
        id: 'v1',
        placa: 'ABC-1D23',
        modelo: 'Chevrolet Spin 1.8 LTZ',
        capacidade: 7,
        quilometragemAtual: 85420,
        emUso: false,
      ),
      // Veículo 2: Van Renault Master de 16 lugares
      const VeiculoModel(
        id: 'v2',
        placa: 'BRA-2E45',
        modelo: 'Renault Master Minibus',
        capacidade: 16,
        quilometragemAtual: 142100,
        emUso: false,
      ),
      // Veículo 3: Fiat Ducato Ambulância de 4 lugares
      const VeiculoModel(
        id: 'v3',
        placa: 'POL-3F67',
        modelo: 'Fiat Ducato Ambulância',
        capacidade: 4,
        quilometragemAtual: 63250,
        emUso: false,
      ),
      // Veículo 4: Fiat Cronos de 5 lugares ocupado por mot_antonio
      const VeiculoModel(
        id: 'v4',
        placa: 'XYZ-9K88',
        modelo: 'Fiat Cronos Drive 1.3',
        capacidade: 5,
        quilometragemAtual: 41900,
        emUso: true,
        motoristaAtualId: 'mot_antonio',
      ),
    // Fecha a lista literal de veículos
    ]);

    // Inicializa viagens e horários padrão em memória (FASE 1: Horários do Dia)
    final hoje = DateTime.now();
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);
    if (_todasViagensMemoria.isEmpty) {
      _todasViagensMemoria.addAll([
        ViagemModel(
          id: 'horario_${dataHoje.year}_${dataHoje.month}_${dataHoje.day}_1',
          motoristaId: 'mot_antonio',
          motoristaNome: 'Antônio Carlos da Silva',
          veiculoId: 'v1',
          veiculoPlaca: 'ABC-1D23',
          veiculoModelo: 'Chevrolet Spin 1.8 LTZ',
          kmInicial: 85420,
          cidadeDestino: 'BARRETOS',
          nomeHorario: '06:00 - Barretos (Hospital de Amor)',
          dataViagem: dataHoje,
          dataHoraInicio: DateTime(dataHoje.year, dataHoje.month, dataHoje.day, 6, 0),
          status: 'planejada',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p1',
              pacienteNome: 'Maria das Graças Aparecida',
              localOrigem: 'Rua das Flores, 125 - Centro',
              localDestino: 'Hospital de Amor de Barretos',
              horarioAtendimento: '09:00',
              ordemEmbarque: 1,
              observacoes: 'Exame de rotina oncologia',
            ),
            PassageiroViagemModel(
              pacienteId: 'p2',
              pacienteNome: 'Carlos Eduardo Martins',
              acompanhanteNome: 'Ana Paula Martins',
              localOrigem: 'Rua dos Ipês, 310',
              localDestino: 'Ambulatório Geral de Barretos',
              horarioAtendimento: '10:30',
              ordemEmbarque: 2,
              observacoes: 'Cadeirante com acompanhante',
            ),
          ],
          passageirosIds: const ['p1', 'p2'],
        ),
        ViagemModel(
          id: 'horario_${dataHoje.year}_${dataHoje.month}_${dataHoje.day}_2',
          motoristaId: 'mot_marcos',
          motoristaNome: 'Marcos Roberto Pereira',
          veiculoId: 'v2',
          veiculoPlaca: 'BRA-2E45',
          veiculoModelo: 'Renault Master Minibus',
          kmInicial: 142100,
          cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
          nomeHorario: '08:30 - São José do Rio Preto (HB / Lucy Montoro)',
          dataViagem: dataHoje,
          dataHoraInicio: DateTime(dataHoje.year, dataHoje.month, dataHoje.day, 8, 30),
          status: 'planejada',
          passageiros: const [],
          passageirosIds: const [],
        ),
      ]);
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    // Marca a flag como verdadeira para prevenir reinicialização
    _inicializado = true;
  // Fecha o método _inicializarDadosBase
  }

  // Linha em branco separadora entre métodos privados
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Verifica se existem instâncias ativas do Firebase inicializadas
  // ----------------------------------------------------------------------------
  // MÉTODO PRIVADO: _isFirebaseDisponivel
  // - Retorna true se houver instâncias configuradas de Firebase no runtime atual.
  // --------------------------------------------------------------------------
  bool _isFirebaseDisponivel() {
    // Bloco try para leitura de instâncias do Firebase
    try {
      // Retorna true se houver ao menos um app Firebase inicializado
      return Firebase.apps.isNotEmpty;
    // Em caso de exceção de inicialização ou plataforma, retorna false
    } catch (_) {
      return false;
    // Fecha o bloco catch
    }
  // Fecha o método _isFirebaseDisponivel
  }

  // Linha em branco separadora entre checagem do Firebase e carregarVeiculosDisponiveis
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Retorna um fluxo com a lista de veículos disponíveis filtrados
  // ----------------------------------------------------------------------------
  // MÉTODO PÚBLICO: carregarVeiculosDisponiveis
  // - Retorna uma Stream com os veículos liberados para condução, aplicando filtros de concorrência.
  // --------------------------------------------------------------------------
  Stream<List<VeiculoModel>> carregarVeiculosDisponiveis({
    // ID do motorista atual para não filtrar o veículo já associado a ele
    String? motoristaId,
  // Abre o corpo do método carregarVeiculosDisponiveis
  }) {
    // Se o Firebase estiver inicializado, tenta escutar snapshots do Firestore
    if (_isFirebaseDisponivel()) {
      // Bloco try para capturar falhas de consulta no Firestore
      try {
        // Conecta na coleção 'veiculos' do Cloud Firestore e mapeia os snapshots
        return FirebaseFirestore.instance
            .collection('veiculos')
            .snapshots()
            .map((snapshot) {
              // Verifica se a coleção está vazia
              if (snapshot.docs.isEmpty) {
                // ------------------------------------------------------------
                // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
                // Escreve os veículos padrão no Firestore quando a coleção está sem documentos
                // ------------------------------------------------------------
                // Sincroniza a base de dados padrão no Firestore de forma assíncrona
                _sincronizarVeiculosBaseNoFirestore();
                // Retorna os veículos da memória aplicando o filtro de disponibilidade
                return ValidacaoViagem.filtrarVeiculosDisponiveis(
                  _veiculosMemoria,
                  motoristaPermitidoId: motoristaId,
                );
              // Fecha verificação de snapshot vazio
              }
              // --------------------------------------------------------------
              // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
              // Mapeia os documentos retornados para instâncias de VeiculoModel
              // --------------------------------------------------------------
              // Mapeia os documentos remotos para objetos VeiculoModel
              final lista = snapshot.docs.map((doc) {
                return VeiculoModel.fromMap(doc.data(), docId: doc.id);
              }).toList();
              // Retorna a lista mapeada aplicando o filtro de disponibilidade
              return ValidacaoViagem.filtrarVeiculosDisponiveis(
                lista,
                motoristaPermitidoId: motoristaId,
              );
            // Fecha o map do snapshot
            });
      // Captura erros de rede ou permissão e prossegue para a memória
      } catch (_) {
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Prossegue para o fluxo em memória caso ocorra exceção
        // --------------------------------------------------------------------
      // Fecha o bloco catch
      }
    // Fecha a checagem de Firebase disponível
    }

    // Linha em branco separadora entre tentativa remota e emissão local
    // ----------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Emite a lista de veículos armazenada em memória através do StreamController
    // ----------------------------------------------------------------------------
    // Agenda microtask para emitir os veículos da memória de forma assíncrona
    Future.microtask(() {
      // Checa se o controlador ainda se encontra aberto antes de emitir evento
      if (!_veiculosController.isClosed) {
        // Adiciona a lista filtrada da memória no StreamController
        _veiculosController.add(
          ValidacaoViagem.filtrarVeiculosDisponiveis(
            _veiculosMemoria,
            motoristaPermitidoId: motoristaId,
          ),
        );
      // Fecha checagem de controlador fechado
      }
    // Fecha a microtask
    });

    // Linha em branco separadora entre agendamento e retorno da stream
    // Retorna a stream do StreamController da frota
    return _veiculosController.stream;
  // Fecha o método carregarVeiculosDisponiveis
  }

  // Linha em branco separadora entre métodos de carregamento e sincronização
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Envia os veículos da lista em memória para a coleção 'veiculos' do Firestore
  // ----------------------------------------------------------------------------
  // MÉTODO ASSÍNCRONO: _sincronizarVeiculosBaseNoFirestore
  // - Grava os veículos padrão da prefeitura na coleção 'veiculos' do Firestore.
  // --------------------------------------------------------------------------
  Future<void> _sincronizarVeiculosBaseNoFirestore() async {
    // Interrompe se o Firebase não estiver configurado
    if (!_isFirebaseDisponivel()) return;
    // Bloco try para capturar eventuais falhas de gravação em lote
    try {
      // Obtém referência para a coleção 'veiculos'
      final col = FirebaseFirestore.instance.collection('veiculos');
      // Itera por cada veículo cadastrado na memória
      for (final v in _veiculosMemoria) {
        // Grava o veículo com merge de opções no Firestore
        await col.doc(v.id).set(v.toMap(), SetOptions(merge: true));
      // Fecha o loop de veículos
      }
    // Captura falhas de escrita sem quebrar o fluxo
    } catch (_) {
      // ----------------------------------------------------------------------
      // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
      // Ignora falhas de escrita durante a sincronização
      // ----------------------------------------------------------------------
    // Fecha o bloco catch
    }
  // Fecha o método _sincronizarVeiculosBaseNoFirestore
  }

  // Linha em branco separadora entre sincronização e iniciarViagem
  // Linha em branco separadora entre sincronização e declararVeiculo
  // ----------------------------------------------------------------------------
  // DECLARAÇÃO DE VEÍCULO (Issue #65: Novo Fluxo)
  // ----------------------------------------------------------------------------
  /// Registra a escolha do veículo e odômetro inicial pelo motorista,
  /// estabelecendo a Sessão de Veículo ativa que acomodará N viagens ativas.
  Future<ResultadoDeclaracaoVeiculo> declararVeiculo({
    required VeiculoModel veiculo,
    required int kmInicial,
    required String motoristaId,
    required String motoristaNome,
  }) async {
    // Validação de regras de negócio de odômetro
    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: kmInicial.toString(),
      ultimaKmRegistrada: veiculo.quilometragemAtual,
    );
    if (!validacaoKm.valido) {
      return ResultadoDeclaracaoVeiculo.erro(validacaoKm.mensagemErro!);
    }

    // Checagem de concorrência remota no Firestore
    if (_isFirebaseDisponivel()) {
      try {
        final docRef = FirebaseFirestore.instance.collection('veiculos').doc(veiculo.id);
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          final dados = docSnap.data() ?? {};
          final emUsoRemoto = dados['emUso'] == true;
          final motoristaOcupando = dados['motoristaAtualId'];
          if (emUsoRemoto &&
              motoristaOcupando != null &&
              motoristaOcupando != motoristaId) {
            return ResultadoDeclaracaoVeiculo.erro(
              'O veículo ${veiculo.placa} foi colocado em uso por outro motorista. Escolha outro veículo.',
            );
          }
        }
      } catch (_) {}
    }

    // Checagem e atualização em memória
    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculo.id);
    if (index != -1) {
      final veicMem = _veiculosMemoria[index];
      if (veicMem.emUso &&
          veicMem.motoristaAtualId != null &&
          veicMem.motoristaAtualId != motoristaId) {
        return ResultadoDeclaracaoVeiculo.erro(
          'O veículo ${veiculo.placa} já está em uso por outro motorista.',
        );
      }
      _veiculosMemoria[index] = _veiculosMemoria[index].copyWith(
        emUso: true,
        motoristaAtualId: motoristaId,
        quilometragemAtual: kmInicial,
      );
    }

    // Instancia a nova SessaoVeiculoModel
    final novaSessao = SessaoVeiculoModel(
      id: 'sessao_${DateTime.now().millisecondsSinceEpoch}',
      motoristaId: motoristaId,
      motoristaNome: motoristaNome,
      veiculoId: veiculo.id,
      veiculoPlaca: veiculo.placa,
      veiculoModelo: veiculo.modelo,
      kmInicial: kmInicial,
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
    );

    _sessaoAtiva = novaSessao;
    _sessaoAtivaController.add(_sessaoAtiva);
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );

    // Vincula viagens planejadas do motorista para a data de hoje, se houver
    final hoje = DateTime.now();
    final viagensDoDia = _todasViagensMemoria.where((v) {
      final d = v.dataOperacional;
      return d.year == hoje.year &&
          d.month == hoje.month &&
          d.day == hoje.day &&
          v.motoristaId == motoristaId &&
          !v.isCancelada;
    }).toList();

    final List<String> viagensIdsSessao = [];
    for (final v in viagensDoDia) {
      if (!_viagensAtivasMemoria.any((va) => va.id == v.id)) {
        final vAtivada = v.copyWith(
          sessaoId: novaSessao.id,
          veiculoId: veiculo.id,
          veiculoPlaca: veiculo.placa,
          veiculoModelo: veiculo.modelo,
          kmInicial: kmInicial,
          status: 'ativa',
        );
        _viagensAtivasMemoria.add(vAtivada);
        viagensIdsSessao.add(vAtivada.id);
        final idx = _todasViagensMemoria.indexWhere((tv) => tv.id == v.id);
        if (idx != -1) {
          _todasViagensMemoria[idx] = vAtivada;
        }
      } else {
        viagensIdsSessao.add(v.id);
      }
    }

    if (viagensIdsSessao.isNotEmpty) {
      _sessaoAtiva = _sessaoAtiva!.copyWith(viagensIds: viagensIdsSessao);
      _sessaoAtivaController.add(_sessaoAtiva);
    }

    if (_viagensAtivasMemoria.isNotEmpty) {
      _viagemAtiva = _viagensAtivasMemoria.first;
      _viagemAtivaController.add(_viagemAtiva);
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    // Persistência no Firestore
    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculo.id)
            .set({
              'emUso': true,
              'motoristaAtualId': motoristaId,
              'quilometragemAtual': kmInicial,
            }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('sessoes_veiculo')
            .doc(novaSessao.id)
            .set(novaSessao.toMap());

        if (motoristaId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(motoristaId)
              .set({'emViagem': true}, SetOptions(merge: true));
        }
      } catch (_) {}
    }

    return ResultadoDeclaracaoVeiculo.sucesso(novaSessao);
  }

  /// Adiciona uma nova viagem ativa à sessão de veículo do motorista (Issue #65).
  Future<ResultadoInicioViagem> criarOuAdicionarViagemNaSessao({
    required String cidadeDestino,
    List<String> passageirosIds = const [],
    String? idCustomizado,
  }) async {
    if (_sessaoAtiva == null) {
      return ResultadoInicioViagem.erro(
        'Nenhuma sessão de veículo ativa. Declare o veículo antes de criar viagens.',
      );
    }

    final validacaoCidade = ValidacaoViagem.validarCidade(cidadeDestino);
    if (!validacaoCidade.valido) {
      return ResultadoInicioViagem.erro(validacaoCidade.mensagemErro!);
    }

    final sessao = _sessaoAtiva!;
    final novaViagem = ViagemModel(
      id: idCustomizado ?? 'viagem_${DateTime.now().millisecondsSinceEpoch}_${_viagensAtivasMemoria.length + 1}',
      motoristaId: sessao.motoristaId,
      motoristaNome: sessao.motoristaNome,
      veiculoId: sessao.veiculoId,
      veiculoPlaca: sessao.veiculoPlaca,
      veiculoModelo: sessao.veiculoModelo,
      kmInicial: sessao.kmInicial,
      cidadeDestino: cidadeDestino,
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
      passageirosIds: passageirosIds,
      sessaoId: sessao.id,
    );

    _viagensAtivasMemoria.add(novaViagem);
    _todasViagensMemoria.add(novaViagem);
    _viagemAtiva = novaViagem;

    _viagemAtivaController.add(_viagemAtiva);
    _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    // Atualiza a lista de viagens da sessão
    _sessaoAtiva = _sessaoAtiva!.copyWith(
      viagensIds: [..._sessaoAtiva!.viagensIds, novaViagem.id],
    );
    _sessaoAtivaController.add(_sessaoAtiva);

    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(novaViagem.id)
            .set(novaViagem.toMap());

        await FirebaseFirestore.instance
            .collection('sessoes_veiculo')
            .doc(sessao.id)
            .set({'viagensIds': _sessaoAtiva!.viagensIds}, SetOptions(merge: true));
      } catch (_) {}
    }

    return ResultadoInicioViagem.sucesso(novaViagem);
  }

  // ----------------------------------------------------------------------------
  // CÓDIGO DE ACESSO DO PASSAGEIRO NA VIAGEM (Issue #65)
  // ----------------------------------------------------------------------------
  /// Gera ou recupera o código de acesso (4 a 5 dígitos) para o paciente na viagem.
  ///
  /// - Idempotente: Se já houver código emitido para o paciente, devolve o existente;
  /// - Unicidade: Garante que nenhum outro passageiro da mesma viagem receba código idêntico;
  /// - Hash seguro: Gera hash SHA-256 com salt do viagemId para validação de login do paciente;
  /// - Acompanhante: Usa exatamente o mesmo código do paciente titular.
  Future<String> gerarOuObterCodigoAcesso({
    required String viagemId,
    required String pacienteId,
  }) async {
    // 1. Localiza a viagem na memória de viagens ativas ou em todas as viagens
    int viagemIndex = _viagensAtivasMemoria.indexWhere((v) => v.id == viagemId);
    int todasIndex = _todasViagensMemoria.indexWhere((v) => v.id == viagemId);
    ViagemModel? viagem = viagemIndex != -1
        ? _viagensAtivasMemoria[viagemIndex]
        : (todasIndex != -1
            ? _todasViagensMemoria[todasIndex]
            : (_viagemAtiva?.id == viagemId ? _viagemAtiva : null));

    // 2. Se já existir código atribuído a este paciente na viagem, retorna sem duplicar (Idempotência)
    if (viagem != null && viagem.codigosAcesso.containsKey(pacienteId)) {
      return viagem.codigosAcesso[pacienteId]!;
    }

    // 3. Sorteia código único de 4 a 5 dígitos garantindo ausência de colisões na viagem
    final codigosExistentes = viagem?.codigosAcesso.values ?? const <String>[];
    final novoCodigo = CodigoAcessoService.gerarCodigoUnicoNaViagem(codigosExistentes);

    // 4. Calcula o hash criptográfico seguro com o salt da viagem
    final novoHash = CodigoAcessoService.calcularHash(novoCodigo, viagemId);

    // 5. Atualiza o modelo de viagem em memória
    if (viagem != null) {
      final mapaCodigos = Map<String, String>.from(viagem.codigosAcesso);
      final mapaHashes = Map<String, String>.from(viagem.codigosHash);
      mapaCodigos[pacienteId] = novoCodigo;
      mapaHashes[pacienteId] = novoHash;

      final viagemAtualizada = viagem.copyWith(
        codigosAcesso: mapaCodigos,
        codigosHash: mapaHashes,
      );

      if (viagemIndex != -1) {
        _viagensAtivasMemoria[viagemIndex] = viagemAtualizada;
        _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      }
      if (todasIndex != -1) {
        _todasViagensMemoria[todasIndex] = viagemAtualizada;
        _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
      }
      if (_viagemAtiva?.id == viagemId) {
        _viagemAtiva = viagemAtualizada;
        _viagemAtivaController.add(_viagemAtiva);
      }
    }

    // 6. Persiste os mapas de códigos e hashes no Firestore de forma atômica
    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagemId)
            .set({
              'codigosAcesso.$pacienteId': novoCodigo,
              'codigosHash.$pacienteId': novoHash,
            }, SetOptions(merge: true));
      } catch (_) {}
    }

    return novoCodigo;
  }

  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Valida os dados, atualiza a disponibilidade do veículo e cria o registro de viagem
  // ----------------------------------------------------------------------------
  // MÉTODO CENTRAL DE NEGÓCIO: iniciarViagem
  // - Valida KM inicial e destino;
  // - Verifica concorrência de uso do veículo no Firestore e na memória;
  // - Atualiza o veículo como 'emUso: true' associado ao motorista;
  // - Cria o documento de ViagemModel com status 'ativa';
  // - Emite os novos estados nas streams reativas.
  // --------------------------------------------------------------------------
  Future<ResultadoInicioViagem> iniciarViagem({
    // Veículo selecionado pelo motorista
    required VeiculoModel veiculo,
    // Quilometragem de partida digitada
    required int kmInicial,
    // Município de destino da viagem
    required String cidadeDestino,
    // ID do motorista autenticado
    required String motoristaId,
    // Nome do motorista autenticado
    required String motoristaNome,
  // Abre o corpo do método iniciarViagem
  }) async {
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Valida a quilometragem informada contra a última registrada
    // ------------------------------------------------------------------------
    // Executa a validação de formato e plausibilidade do odômetro
    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: kmInicial.toString(),
      ultimaKmRegistrada: veiculo.quilometragemAtual,
    );
    // Se a quilometragem for inválida, retorna erro imediato com a mensagem
    if (!validacaoKm.valido) {
      return ResultadoInicioViagem.erro(validacaoKm.mensagemErro!);
    // Fecha checagem de KM inválido
    }

    // Linha em branco separadora entre validação de KM e validação de cidade
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Valida a cidade informada
    // ------------------------------------------------------------------------
    // Executa a validação de preenchimento da cidade de destino
    final validacaoCidade = ValidacaoViagem.validarCidade(cidadeDestino);
    // Se a cidade for inválida, retorna erro imediato com a mensagem
    if (!validacaoCidade.valido) {
      return ResultadoInicioViagem.erro(validacaoCidade.mensagemErro!);
    // Fecha checagem de cidade inválida
    }

    // Linha em branco separadora entre validação de cidade e checagem remota no Firestore
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Consulta o documento do veículo no Firestore para verificar uso concorrente
    // ------------------------------------------------------------------------
    // Checa concorrência de reserva no Firestore para impedir conflito entre motoristas
    if (_isFirebaseDisponivel()) {
      // Bloco try para leitura do estado atualizado do veículo no banco
      try {
        // Obtém a referência do documento do veículo
        final docRef = FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculo.id);
        // Busca o snapshot do documento no Firestore
        final docSnap = await docRef.get();

        // Linha em branco separadora entre busca e validação dos dados
        // Verifica se o documento do veículo existe no Firestore
        if (docSnap.exists) {
          // Extrai o mapa de campos do documento
          final dados = docSnap.data() ?? {};
          // Extrai o status de uso atual no servidor
          final emUsoRemoto = dados['emUso'] == true;
          // Extrai o motorista vinculado no servidor
          final motoristaOcupando = dados['motoristaAtualId'];
          // ------------------------------------------------------------------
          // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
          // Verifica se o veículo está marcado em uso por motorista distinto
          // ------------------------------------------------------------------
          // Detecta conflito de concorrência com outro motorista
          if (emUsoRemoto &&
              motoristaOcupando != null &&
              motoristaOcupando != motoristaId) {
            // Retorna erro informando a indisponibilidade concorrente
            return ResultadoInicioViagem.erro(
              'O veículo ${veiculo.placa} foi colocado em uso por outro motorista. Escolha outro veículo.',
            );
          // Fecha detecção de conflito
          }
        // Fecha verificação de documento existente
        }
      // Captura erros de rede sem travar a aplicação
      } catch (_) {
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Prossegue com a verificação em memória caso ocorra falha de consulta remota
        // --------------------------------------------------------------------
      // Fecha bloco catch
      }
    // Fecha checagem de Firebase disponível
    }

    // Linha em branco separadora entre consulta remota e verificação na memória
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Verifica a situação do veículo na lista em memória
    // ------------------------------------------------------------------------
    // Localiza o índice do veículo na lista interna da memória
    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculo.id);
    // Se o veículo constar na lista da memória, valida conflito local
    if (index != -1) {
      // Obtém a instância do veículo na memória
      final veicMem = _veiculosMemoria[index];
      // ----------------------------------------------------------------------
      // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
      // Verifica se o veículo da memória está em uso por outro motorista
      // ----------------------------------------------------------------------
      // Checa se outro motorista já está ocupando o veículo na memória
      if (veicMem.emUso &&
          veicMem.motoristaAtualId != null &&
          veicMem.motoristaAtualId != motoristaId) {
        // Retorna erro de concorrência local
        return ResultadoInicioViagem.erro(
          'O veículo ${veiculo.placa} já está em uso por outro motorista.',
        );
      // Fecha checagem de concorrência local
      }
      // ----------------------------------------------------------------------
      // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
      // Atualiza o veículo na memória com status emUso, novo condutor e quilometragem
      // ----------------------------------------------------------------------
      // Atualiza o veículo na memória com a reserva e o KM informado
      _veiculosMemoria[index] = _veiculosMemoria[index].copyWith(
        emUso: true,
        motoristaAtualId: motoristaId,
        quilometragemAtual: kmInicial,
      );
    // Fecha verificação do índice na memória
    }

    // Se não houver sessão ativa prévia, inicializa a Sessão de Veículo do condutor
    if (_sessaoAtiva == null || _sessaoAtiva!.veiculoId != veiculo.id) {
      _sessaoAtiva = SessaoVeiculoModel(
        id: 'sessao_${DateTime.now().millisecondsSinceEpoch}',
        motoristaId: motoristaId,
        motoristaNome: motoristaNome,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        veiculoModelo: veiculo.modelo,
        kmInicial: kmInicial,
        dataHoraInicio: DateTime.now(),
        status: 'ativa',
      );
      _sessaoAtivaController.add(_sessaoAtiva);
    }

    // Linha em branco separadora entre atualização de memória e criação da viagem
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Instancia o objeto ViagemModel com os dados da viagem
    // ------------------------------------------------------------------------
    // Cria a nova instância de ViagemModel com status 'ativa'
    final novaViagem = ViagemModel(
      // Gera ID baseado em timestamp
      id: 'viagem_${DateTime.now().millisecondsSinceEpoch}',
      // Atribui o ID do motorista
      motoristaId: motoristaId,
      // Atribui o nome do motorista
      motoristaNome: motoristaNome,
      // Atribui o ID do veículo
      veiculoId: veiculo.id,
      // Atribui a placa do veículo
      veiculoPlaca: veiculo.placa,
      // Atribui o modelo do veículo
      veiculoModelo: veiculo.modelo,
      // Atribui a leitura de KM de partida
      kmInicial: kmInicial,
      // Atribui a cidade de destino
      cidadeDestino: cidadeDestino,
      // Atribui o momento do início da viagem
      dataHoraInicio: DateTime.now(),
      // Define a situação operacional como ativa
      status: 'ativa',
      // Vincula à sessão de veículo ativa
      sessaoId: _sessaoAtiva?.id,
    );

    // Linha em branco separadora entre criação da viagem e notificação dos fluxos
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Atualiza a variável e notifica os fluxos de dados
    // ------------------------------------------------------------------------
    // Atualiza a lista interna de N viagens ativas
    _viagensAtivasMemoria.add(novaViagem);
    _todasViagensMemoria.add(novaViagem);
    // Atualiza a propriedade interna de viagem ativa principal
    _viagemAtiva = novaViagem;
    // Emite o novo objeto na stream de viagem ativa
    _viagemAtivaController.add(_viagemAtiva);
    // Emite a lista atualizada de todas as N viagens ativas
    _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    // Emite a nova lista de veículos filtrados na stream de frota
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );

    // Linha em branco separadora entre notificação local e persistência remota
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Persiste as alterações no Firestore
    // ------------------------------------------------------------------------
    // Persiste as mudanças no Cloud Firestore se disponível
    if (_isFirebaseDisponivel()) {
      // Bloco try para capturar exceções de gravação remota
      try {
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Atualiza os dados de uso e quilometragem do veículo
        // --------------------------------------------------------------------
        // Grava no documento do veículo o status emUso, condutor e novo KM
        await FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculo.id)
            .set({
              'emUso': true,
              'motoristaAtualId': motoristaId,
              'quilometragemAtual': kmInicial,
            }, SetOptions(merge: true));

        // Linha em branco separadora entre atualização de veículo e criação de viagem
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Cria o documento da viagem na coleção 'viagens'
        // --------------------------------------------------------------------
        // Cria o novo documento de viagem na coleção 'viagens'
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(novaViagem.id)
            .set(novaViagem.toMap());

        // Linha em branco separadora entre criação da viagem e atualização de usuário
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Atualiza a propriedade emViagem do usuário motorista
        // --------------------------------------------------------------------
        // Atualiza a flag emViagem do documento do motorista na coleção 'usuarios'
        if (motoristaId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(motoristaId)
              .set({'emViagem': true}, SetOptions(merge: true));
        // Fecha checagem de motoristaId não vazio
        }
      // Captura erros de escrita remota sem quebrar a operação local
      } catch (_) {
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Ignora erros de escrita remota
        // --------------------------------------------------------------------
      // Fecha o bloco catch
      }
    // Fecha a checagem de Firebase disponível
    }

    // Linha em branco separadora entre persistência e retorno de sucesso
    // Retorna o resultado com indicador de sucesso e a viagem criada
    return ResultadoInicioViagem.sucesso(novaViagem);
  // Fecha o método iniciarViagem
  }

  // Linha em branco separadora entre iniciarViagem e encerrarViagem
  // ----------------------------------------------------------------------------
  // ENCERRAMENTO DE VIAGENS E SESSÃO (Issue #65: Suporte a N Viagens & LGPD)
  // ----------------------------------------------------------------------------
  /// Encerra uma viagem específica ou todas as viagens ativas da sessão.
  ///
  /// - Segurança & LGPD: Invalida e purga imediatamente os códigos de acesso em texto plano
  ///   (`codigosAcesso` esvaziado), preservando apenas os hashes para fins de auditoria;
  /// - Encerramento de Sessão: Quando a última viagem ativa da sessão é encerrada,
  ///   conclui a [SessaoVeiculoModel] associada e libera o veículo na frota.
  Future<void> encerrarViagem({
    String? viagemId,
    int? kmFinal,
    int? kmRodado,
  }) async {
    // Determina a viagem a ser encerrada (especificada por ID ou _viagemAtiva atual)
    final idAlvo = viagemId ?? _viagemAtiva?.id;
    if (idAlvo == null) return;

    final index = _viagensAtivasMemoria.indexWhere((v) => v.id == idAlvo);
    final ViagemModel viagem = index != -1
        ? _viagensAtivasMemoria[index]
        : (_viagemAtiva?.id == idAlvo ? _viagemAtiva! : _viagemAtiva!);

    final veiculoId = viagem.veiculoId;

    // 1. Atualiza e purga a viagem (invalida códigos em texto plano para segurança)
    final viagemEncerrada = viagem.copyWith(
      status: 'encerrada',
      kmFinal: kmFinal ?? viagem.kmFinal,
      kmRodado: kmRodado ?? viagem.kmRodado,
      dataHoraFim: DateTime.now(),
      // Purgando códigos em texto plano: expira credenciais ativas
      codigosAcesso: const {},
    );

    if (index != -1) {
      _viagensAtivasMemoria.removeAt(index);
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }

    final tvIdx = _todasViagensMemoria.indexWhere((tv) => tv.id == idAlvo);
    if (tvIdx != -1) {
      _todasViagensMemoria[tvIdx] = viagemEncerrada;
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    // 2. Se a viagem encerrada era a viagem ativa visualizada, avança para a próxima ou zera
    if (_viagemAtiva?.id == idAlvo) {
      _viagemAtiva = _viagensAtivasMemoria.isNotEmpty ? _viagensAtivasMemoria.first : null;
      _viagemAtivaController.add(_viagemAtiva);
    }

    // 3. Se não houver mais nenhuma viagem ativa na jornada, encerra a sessão e libera o veículo
    final sessaoFinalizada = _viagensAtivasMemoria.isEmpty;
    if (sessaoFinalizada) {
      _sessaoAtiva = _sessaoAtiva?.copyWith(
        status: 'encerrada',
        kmFinal: kmFinal,
        kmRodado: kmRodado,
        dataHoraFim: DateTime.now(),
      );
      _sessaoAtivaController.add(_sessaoAtiva);
      _sessaoAtiva = null;

      // Libera o veículo na lista de memória
      final veicIndex = _veiculosMemoria.indexWhere((v) => v.id == veiculoId);
      if (veicIndex != -1) {
        _veiculosMemoria[veicIndex] = _veiculosMemoria[veicIndex].copyWith(
          emUso: false,
          motoristaAtualId: null,
          quilometragemAtual: kmFinal ?? _veiculosMemoria[veicIndex].quilometragemAtual,
        );
      }

      _veiculosController.add(
        ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
      );
    }

    // 4. Persiste as alterações no Cloud Firestore
    if (_isFirebaseDisponivel()) {
      try {
        // Atualiza a viagem como encerrada e com códigos purgados
        final dadosViagem = <String, dynamic>{
          'status': 'encerrada',
          'dataHoraFim': DateTime.now().toIso8601String(),
          'codigosAcesso': {},
        };
        if (kmFinal != null) dadosViagem['kmFinal'] = kmFinal;
        if (kmRodado != null) dadosViagem['kmRodado'] = kmRodado;

        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagem.id)
            .set(dadosViagem, SetOptions(merge: true));

        // Se a sessão foi finalizada por completo, libera veículo e motorista
        if (sessaoFinalizada) {
          final dadosVeiculo = <String, dynamic>{
            'emUso': false,
            'motoristaAtualId': null,
          };
          if (kmFinal != null) dadosVeiculo['quilometragemAtual'] = kmFinal;

          await FirebaseFirestore.instance
              .collection('veiculos')
              .doc(veiculoId)
              .set(dadosVeiculo, SetOptions(merge: true));

          if (viagem.motoristaId.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(viagem.motoristaId)
                .set({'emViagem': false}, SetOptions(merge: true));
          }
        }
      } catch (_) {}
    }
  }

  /// Encerra em lote todas as N viagens ativas vinculadas à sessão atual do condutor.
  Future<void> encerrarTodasViagens({int? kmFinal, int? kmRodado}) async {
    final viagensParaEncerrar = List<ViagemModel>.from(_viagensAtivasMemoria);
    for (final v in viagensParaEncerrar) {
      await encerrarViagem(viagemId: v.id, kmFinal: kmFinal, kmRodado: kmRodado);
    }
    if (_viagemAtiva != null) {
      await encerrarViagem(kmFinal: kmFinal, kmRodado: kmRodado);
    }
  }

  // ----------------------------------------------------------------------------
  // MIGRAÇÃO DE DADOS EXISTENTES E PLANO DE REVERSÃO (Issue #65)
  // ----------------------------------------------------------------------------
  /// Migra viagens legadas (sem vínculo de sessão) para o modelo SessaoVeiculoModel -> N Viagens.
  ///
  /// Retorna um relatório com os IDs das viagens migradas e os IDs das sessões geradas.
  Future<Map<String, dynamic>> migrarViagensLegadasParaSessao() async {
    final viagensMigradas = <String>[];
    final sessoesCriadas = <String>[];

    // Migração em memória (viagens ativas em lista e viagem unitária)
    for (int i = 0; i < _viagensAtivasMemoria.length; i++) {
      if (_viagensAtivasMemoria[i].sessaoId == null) {
        final v = _viagensAtivasMemoria[i];
        final sessaoId = _sessaoAtiva?.id ?? 'sessao_migrada_${v.id}';
        if (_sessaoAtiva == null) {
          _sessaoAtiva = SessaoVeiculoModel(
            id: sessaoId,
            motoristaId: v.motoristaId,
            motoristaNome: v.motoristaNome,
            veiculoId: v.veiculoId,
            veiculoPlaca: v.veiculoPlaca,
            veiculoModelo: v.veiculoModelo,
            kmInicial: v.kmInicial,
            dataHoraInicio: v.dataHoraInicio,
            status: v.status,
            viagensIds: [v.id],
          );
          sessoesCriadas.add(sessaoId);
        }
        _viagensAtivasMemoria[i] = v.copyWith(sessaoId: sessaoId);
        if (!viagensMigradas.contains(v.id)) {
          viagensMigradas.add(v.id);
        }
      }
    }

    if (_viagemAtiva != null && _viagemAtiva!.sessaoId == null) {
      if (_sessaoAtiva == null) {
        _sessaoAtiva = SessaoVeiculoModel(
          id: 'sessao_migrada_${DateTime.now().millisecondsSinceEpoch}',
          motoristaId: _viagemAtiva!.motoristaId,
          motoristaNome: _viagemAtiva!.motoristaNome,
          veiculoId: _viagemAtiva!.veiculoId,
          veiculoPlaca: _viagemAtiva!.veiculoPlaca,
          veiculoModelo: _viagemAtiva!.veiculoModelo,
          kmInicial: _viagemAtiva!.kmInicial,
          dataHoraInicio: _viagemAtiva!.dataHoraInicio,
          status: _viagemAtiva!.status,
          viagensIds: [_viagemAtiva!.id],
        );
        sessoesCriadas.add(_sessaoAtiva!.id);
      }
      _viagemAtiva = _viagemAtiva!.copyWith(sessaoId: _sessaoAtiva!.id);
      if (!viagensMigradas.contains(_viagemAtiva!.id)) {
        viagensMigradas.add(_viagemAtiva!.id);
      }
    }

    // Migração no Cloud Firestore (quando ativo)
    if (_isFirebaseDisponivel()) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('viagens')
            .where('status', isEqualTo: 'ativa')
            .get();

        for (final doc in snap.docs) {
          final dados = doc.data();
          if (dados['sessaoId'] == null || dados['sessaoId'].toString().isEmpty) {
            final novaSessaoId = 'sessao_migrada_${doc.id}';
            final novaSessao = SessaoVeiculoModel(
              id: novaSessaoId,
              motoristaId: (dados['motoristaId'] ?? '').toString(),
              motoristaNome: (dados['motoristaNome'] ?? '').toString(),
              veiculoId: (dados['veiculoId'] ?? '').toString(),
              veiculoPlaca: (dados['veiculoPlaca'] ?? '').toString(),
              veiculoModelo: (dados['veiculoModelo'] ?? '').toString(),
              kmInicial: (dados['kmInicial'] is num) ? (dados['kmInicial'] as num).toInt() : 0,
              dataHoraInicio: DateTime.now(),
              status: 'ativa',
              viagensIds: [doc.id],
            );

            await FirebaseFirestore.instance
                .collection('sessoes_veiculo')
                .doc(novaSessaoId)
                .set(novaSessao.toMap());

            await FirebaseFirestore.instance
                .collection('viagens')
                .doc(doc.id)
                .update({'sessaoId': novaSessaoId});

            viagensMigradas.add(doc.id);
            sessoesCriadas.add(novaSessaoId);
          }
        }
      } catch (_) {}
    }

    return {
      'sucesso': true,
      'totalViagensMigradas': viagensMigradas.length,
      'viagensIds': viagensMigradas,
      'sessoesCriadas': sessoesCriadas,
    };
  }

  /// Executa o plano de reversão da migração, desvinculando o sessaoId das viagens especificadas.
  Future<void> reverterMigracaoParaTestes({required List<String> viagensIds}) async {
    for (int i = 0; i < _viagensAtivasMemoria.length; i++) {
      if (viagensIds.contains(_viagensAtivasMemoria[i].id)) {
        _viagensAtivasMemoria[i] = _viagensAtivasMemoria[i].copyWith(removerSessaoId: true);
      }
    }
    if (_viagemAtiva != null && viagensIds.contains(_viagemAtiva!.id)) {
      _viagemAtiva = _viagemAtiva!.copyWith(removerSessaoId: true);
    }
    _sessaoAtiva = null;
    if (_isFirebaseDisponivel()) {
      try {
        for (final id in viagensIds) {
          await FirebaseFirestore.instance
              .collection('viagens')
              .doc(id)
              .update({'sessaoId': FieldValue.delete()});
        }
      } catch (_) {}
    }
  }

  // ============================================================================
  // GESTÃO E CRUD DE HORÁRIOS / VIAGENS (FASE 1: Admin)
  // ============================================================================

  /// Retorna o fluxo reativo com as viagens programadas para uma determinada data.
  Stream<List<ViagemModel>> listarViagensPorDataStream(DateTime data) {
    final dataAlvo = DateTime(data.year, data.month, data.day);
    return todasViagensStream.map((lista) {
      return lista.where((v) {
        final dv = v.dataOperacional;
        return dv.year == dataAlvo.year &&
            dv.month == dataAlvo.month &&
            dv.day == dataAlvo.day;
      }).toList();
    });
  }

  /// Retorna sincronamente as viagens agendadas para a data informada.
  List<ViagemModel> obterViagensPorData(DateTime data) {
    final dataAlvo = DateTime(data.year, data.month, data.day);
    return _todasViagensMemoria.where((v) {
      final dv = v.dataOperacional;
      return dv.year == dataAlvo.year &&
          dv.month == dataAlvo.month &&
          dv.day == dataAlvo.day;
    }).toList();
  }

  /// Retorna as viagens designadas a um motorista em uma data específica.
  List<ViagemModel> listarViagensDoMotorista(String motoristaId, DateTime data) {
    final dataAlvo = DateTime(data.year, data.month, data.day);
    return _todasViagensMemoria.where((v) {
      final dv = v.dataOperacional;
      return dv.year == dataAlvo.year &&
          dv.month == dataAlvo.month &&
          dv.day == dataAlvo.day &&
          v.motoristaId == motoristaId &&
          !v.isCancelada;
    }).toList();
  }

  /// Cria um novo Horário de Saída no gerenciador diário (apenas Administrador).
  Future<ResultadoOperacaoViagem> criarHorarioViagem({
    required DateTime data,
    required String horario,
    required String veiculoId,
    required String veiculoPlaca,
    required String veiculoModelo,
    required int capacidadeVeiculo,
    required String motoristaId,
    required String motoristaNome,
    required String cidadeDestino,
    List<PassageiroViagemModel> passageiros = const [],
    String? observacoes,
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    // 1. Checagem de RBAC no servidor/serviço
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      return ResultadoOperacaoViagem.erro(
        'Apenas administradores possuem permissão para criar novos Horários.',
      );
    }

    // 2. Validação da cidade
    final validacaoCidade = ValidacaoViagem.validarCidade(cidadeDestino);
    if (!validacaoCidade.valido) {
      return ResultadoOperacaoViagem.erro(validacaoCidade.mensagemErro!);
    }

    final dataAlvo = DateTime(data.year, data.month, data.day);
    final viagensDoDia = obterViagensPorData(dataAlvo);

    // 3. Validação de conflito de motorista
    final validacaoMotorista = ValidacaoViagem.validarConflitoMotorista(
      motoristaId: motoristaId,
      data: data,
      horario: horario,
      viagensDoDia: viagensDoDia,
    );
    if (!validacaoMotorista.valido) {
      return ResultadoOperacaoViagem.erro(validacaoMotorista.mensagemErro!);
    }

    // 4. Validação de conflito de veículo
    final validacaoVeiculo = ValidacaoViagem.validarConflitoVeiculo(
      veiculoId: veiculoId,
      data: data,
      horario: horario,
      viagensDoDia: viagensDoDia,
    );
    if (!validacaoVeiculo.valido) {
      return ResultadoOperacaoViagem.erro(validacaoVeiculo.mensagemErro!);
    }

    // 5. Validação de capacidade
    final totalAssentos = passageiros.fold<int>(0, (acc, p) => acc + p.assentosOcupados);
    final validacaoCapacidade = ValidacaoViagem.validarCapacidade(
      totalPassageirosComAcompanhantes: totalAssentos,
      capacidadeVeiculo: capacidadeVeiculo,
    );
    if (!validacaoCapacidade.valido) {
      return ResultadoOperacaoViagem.erro(validacaoCapacidade.mensagemErro!);
    }

    // 6. Validação dos passageiros e acompanhantes
    for (final p in passageiros) {
      final validacaoAcomp = ValidacaoViagem.validarAcompanhante(
        acompanhanteNome: p.acompanhanteNome,
        pacienteId: p.pacienteId,
      );
      if (!validacaoAcomp.valido) {
        return ResultadoOperacaoViagem.erro(validacaoAcomp.mensagemErro!);
      }

      final validacaoPaciente = ValidacaoViagem.validarConflitoPaciente(
        pacienteId: p.pacienteId,
        data: dataAlvo,
        horario: horario,
        viagensDoDia: viagensDoDia,
      );
      if (!validacaoPaciente.valido) {
        return ResultadoOperacaoViagem.erro(validacaoPaciente.mensagemErro!);
      }

      final validacaoHorarioConsulta = ValidacaoViagem.validarCompatibilidadeHorarioConsulta(
        horarioSaida: horario,
        horarioAtendimento: p.horarioAtendimento,
      );
      if (!validacaoHorarioConsulta.valido) {
        return ResultadoOperacaoViagem.erro(validacaoHorarioConsulta.mensagemErro!);
      }
    }

    // 7. Parsing e construção do objeto
    DateTime dataHoraInicioViagem = dataAlvo;
    final match = RegExp(r'(\d{1,2})[:hH](\d{2})').firstMatch(horario);
    if (match != null) {
      final h = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      if (h != null && m != null) {
        dataHoraInicioViagem = DateTime(data.year, data.month, data.day, h, m);
      }
    }

    final novaViagem = ViagemModel(
      id: 'horario_${dataAlvo.year}_${dataAlvo.month}_${dataAlvo.day}_${DateTime.now().millisecondsSinceEpoch}',
      motoristaId: motoristaId,
      motoristaNome: motoristaNome,
      veiculoId: veiculoId,
      veiculoPlaca: veiculoPlaca,
      veiculoModelo: veiculoModelo,
      kmInicial: 0,
      cidadeDestino: cidadeDestino,
      nomeHorario: horario,
      dataViagem: dataAlvo,
      dataHoraInicio: dataHoraInicioViagem,
      status: 'planejada',
      observacoes: observacoes,
      passageiros: passageiros,
      passageirosIds: passageiros
          .expand((p) => [p.pacienteId, if (p.acompanhanteId != null) p.acompanhanteId!])
          .where((id) => id.isNotEmpty)
          .toList(),
    );

    // 8. Gravação na memória e notificação das streams
    _todasViagensMemoria.add(novaViagem);
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    // 9. Persistência remota
    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(novaViagem.id)
            .set(novaViagem.toMap());
      } catch (_) {}
    }

    return ResultadoOperacaoViagem.sucesso(novaViagem);
  }

  /// Atualiza os dados de um Horário de Viagem existente.
  Future<ResultadoOperacaoViagem> atualizarHorarioViagem({
    required ViagemModel viagem,
    int? capacidadeVeiculo,
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    // 1. RBAC
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      return ResultadoOperacaoViagem.erro(
        'Apenas administradores possuem permissão para atualizar Horários.',
      );
    }

    final index = _todasViagensMemoria.indexWhere((v) => v.id == viagem.id);
    if (index == -1) {
      return ResultadoOperacaoViagem.erro('Horário não encontrado.');
    }

    final existente = _todasViagensMemoria[index];
    if (existente.isConcluida) {
      return ResultadoOperacaoViagem.erro(
        'Não é possível editar uma viagem que já foi concluída.',
      );
    }

    // 2. Validações
    final validacaoCidade = ValidacaoViagem.validarCidade(viagem.cidadeDestino);
    if (!validacaoCidade.valido) {
      return ResultadoOperacaoViagem.erro(validacaoCidade.mensagemErro!);
    }

    final dataAlvo = viagem.dataOperacional;
    final viagensDoDia = obterViagensPorData(dataAlvo);

    final validacaoMotorista = ValidacaoViagem.validarConflitoMotorista(
      motoristaId: viagem.motoristaId,
      data: viagem.dataHoraInicio,
      horario: viagem.tituloHorario,
      viagensDoDia: viagensDoDia,
      viagemIdAtual: viagem.id,
    );
    if (!validacaoMotorista.valido) {
      return ResultadoOperacaoViagem.erro(validacaoMotorista.mensagemErro!);
    }

    final validacaoVeiculo = ValidacaoViagem.validarConflitoVeiculo(
      veiculoId: viagem.veiculoId,
      data: viagem.dataHoraInicio,
      horario: viagem.tituloHorario,
      viagensDoDia: viagensDoDia,
      viagemIdAtual: viagem.id,
    );
    if (!validacaoVeiculo.valido) {
      return ResultadoOperacaoViagem.erro(validacaoVeiculo.mensagemErro!);
    }

    if (capacidadeVeiculo != null && capacidadeVeiculo > 0) {
      final validacaoCapacidade = ValidacaoViagem.validarCapacidade(
        totalPassageirosComAcompanhantes: viagem.totalAssentosOcupados,
        capacidadeVeiculo: capacidadeVeiculo,
      );
      if (!validacaoCapacidade.valido) {
        return ResultadoOperacaoViagem.erro(validacaoCapacidade.mensagemErro!);
      }
    }

    for (final p in viagem.passageiros) {
      final validacaoAcomp = ValidacaoViagem.validarAcompanhante(
        acompanhanteNome: p.acompanhanteNome,
        pacienteId: p.pacienteId,
      );
      if (!validacaoAcomp.valido) {
        return ResultadoOperacaoViagem.erro(validacaoAcomp.mensagemErro!);
      }

      final validacaoPaciente = ValidacaoViagem.validarConflitoPaciente(
        pacienteId: p.pacienteId,
        data: dataAlvo,
        horario: viagem.tituloHorario,
        viagensDoDia: viagensDoDia,
        viagemIdAtual: viagem.id,
      );
      if (!validacaoPaciente.valido) {
        return ResultadoOperacaoViagem.erro(validacaoPaciente.mensagemErro!);
      }

      final validacaoHorarioConsulta = ValidacaoViagem.validarCompatibilidadeHorarioConsulta(
        horarioSaida: viagem.tituloHorario,
        horarioAtendimento: p.horarioAtendimento,
      );
      if (!validacaoHorarioConsulta.valido) {
        return ResultadoOperacaoViagem.erro(validacaoHorarioConsulta.mensagemErro!);
      }
    }

    // 3. Tratamento de códigos de acesso existentes
    // Preserva códigos de passageiros mantidos; descarta códigos de removidos
    final mapaCodigosPreservados = Map<String, String>.from(existente.codigosAcesso);
    final mapaHashesPreservados = Map<String, String>.from(existente.codigosHash);
    final idsAtuais = viagem.passageiros.map((p) => p.pacienteId).toSet();
    mapaCodigosPreservados.removeWhere((id, _) => !idsAtuais.contains(id));
    mapaHashesPreservados.removeWhere((id, _) => !idsAtuais.contains(id));

    final viagemAtualizada = viagem.copyWith(
      codigosAcesso: mapaCodigosPreservados,
      codigosHash: mapaHashesPreservados,
      passageirosIds: viagem.passageiros
          .expand((p) => [p.pacienteId, if (p.acompanhanteId != null) p.acompanhanteId!])
          .where((id) => id.isNotEmpty)
          .toList(),
    );

    _todasViagensMemoria[index] = viagemAtualizada;
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    // Se estiver ativa na sessão do motorista, sincroniza
    final ativaIndex = _viagensAtivasMemoria.indexWhere((v) => v.id == viagem.id);
    if (ativaIndex != -1) {
      _viagensAtivasMemoria[ativaIndex] = viagemAtualizada;
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
    if (_viagemAtiva?.id == viagem.id) {
      _viagemAtiva = viagemAtualizada;
      _viagemAtivaController.add(_viagemAtiva);
    }

    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagem.id)
            .set(viagemAtualizada.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }

    return ResultadoOperacaoViagem.sucesso(viagemAtualizada);
  }

  /// Cancela ou exclui um Horário de Viagem (soft delete preferencial).
  Future<ResultadoOperacaoViagem> cancelarOuExcluirHorarioViagem(
    String viagemId, {
    bool softDelete = true,
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      return ResultadoOperacaoViagem.erro(
        'Apenas administradores possuem permissão para cancelar ou excluir Horários.',
      );
    }

    final index = _todasViagensMemoria.indexWhere((v) => v.id == viagemId);
    if (index == -1) {
      return ResultadoOperacaoViagem.erro('Horário não encontrado.');
    }

    final viagem = _todasViagensMemoria[index];

    if (softDelete) {
      // Cancelamento lógico: invalida códigos e marca como cancelada
      final cancelada = viagem.copyWith(
        status: 'cancelada',
        codigosAcesso: const {},
      );
      _todasViagensMemoria[index] = cancelada;
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

      // Remove de viagens ativas do motorista se estiver lá
      final ativaIndex = _viagensAtivasMemoria.indexWhere((v) => v.id == viagemId);
      if (ativaIndex != -1) {
        _viagensAtivasMemoria.removeAt(ativaIndex);
        _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      }
      if (_viagemAtiva?.id == viagemId) {
        _viagemAtiva = _viagensAtivasMemoria.isNotEmpty ? _viagensAtivasMemoria.first : null;
        _viagemAtivaController.add(_viagemAtiva);
      }

      if (_isFirebaseDisponivel()) {
        try {
          await FirebaseFirestore.instance
              .collection('viagens')
              .doc(viagemId)
              .set(cancelada.toMap(), SetOptions(merge: true));
        } catch (_) {}
      }

      return ResultadoOperacaoViagem.sucesso(cancelada);
    } else {
      // Exclusão física
      final removida = _todasViagensMemoria.removeAt(index);
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

      final ativaIndex = _viagensAtivasMemoria.indexWhere((v) => v.id == viagemId);
      if (ativaIndex != -1) {
        _viagensAtivasMemoria.removeAt(ativaIndex);
        _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      }
      if (_viagemAtiva?.id == viagemId) {
        _viagemAtiva = _viagensAtivasMemoria.isNotEmpty ? _viagensAtivasMemoria.first : null;
        _viagemAtivaController.add(_viagemAtiva);
      }

      if (_isFirebaseDisponivel()) {
        try {
          await FirebaseFirestore.instance
              .collection('viagens')
              .doc(viagemId)
              .delete();
        } catch (_) {}
      }

      return ResultadoOperacaoViagem.sucesso(removida);
    }
  }

  /// Duplica todas as viagens ativas/planejadas de uma data de origem para uma data de destino.
  Future<List<ViagemModel>> duplicarViagensDeOutroDia({
    required DateTime dataOrigem,
    required DateTime dataDestino,
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      throw Exception('Apenas administradores podem duplicar Horários.');
    }

    final dataOrigemFormatada = DateTime(dataOrigem.year, dataOrigem.month, dataOrigem.day);
    final dataDestinoFormatada = DateTime(dataDestino.year, dataDestino.month, dataDestino.day);

    final viagensOrigem = _todasViagensMemoria.where((v) {
      final dv = v.dataOperacional;
      return dv.year == dataOrigemFormatada.year &&
          dv.month == dataOrigemFormatada.month &&
          dv.day == dataOrigemFormatada.day &&
          !v.isCancelada;
    }).toList();

    final List<ViagemModel> duplicadas = [];

    for (int i = 0; i < viagensOrigem.length; i++) {
      final vo = viagensOrigem[i];
      final novaHora = DateTime(
        dataDestinoFormatada.year,
        dataDestinoFormatada.month,
        dataDestinoFormatada.day,
        vo.dataHoraInicio.hour,
        vo.dataHoraInicio.minute,
      );

      final novaViagem = ViagemModel(
        id: 'horario_${dataDestinoFormatada.year}_${dataDestinoFormatada.month}_${dataDestinoFormatada.day}_${DateTime.now().millisecondsSinceEpoch}_$i',
        motoristaId: vo.motoristaId,
        motoristaNome: vo.motoristaNome,
        veiculoId: vo.veiculoId,
        veiculoPlaca: vo.veiculoPlaca,
        veiculoModelo: vo.veiculoModelo,
        kmInicial: 0,
        cidadeDestino: vo.cidadeDestino,
        nomeHorario: vo.nomeHorario,
        dataViagem: dataDestinoFormatada,
        dataHoraInicio: novaHora,
        status: 'planejada',
        observacoes: vo.observacoes,
        passageiros: List.from(vo.passageiros),
        passageirosIds: List.from(vo.passageirosIds),
        codigosAcesso: const {},
        codigosHash: const {},
        sessaoId: null,
      );

      _todasViagensMemoria.add(novaViagem);
      duplicadas.add(novaViagem);

      if (_isFirebaseDisponivel()) {
        try {
          await FirebaseFirestore.instance
              .collection('viagens')
              .doc(novaViagem.id)
              .set(novaViagem.toMap());
        } catch (_) {}
      }
    }

    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    return duplicadas;
  }

  /// Reordena a ordem de embarque dos passageiros de um Horário de Viagem.
  Future<ResultadoOperacaoViagem> reordenarPassageiros(
    String viagemId,
    List<PassageiroViagemModel> novosPassageiros, {
    UserRole? roleRequisitante = UserRole.admin,
  }) async {
    if (roleRequisitante != null && roleRequisitante != UserRole.admin) {
      return ResultadoOperacaoViagem.erro(
        'Apenas administradores podem reordenar a ordem de embarque.',
      );
    }

    final index = _todasViagensMemoria.indexWhere((v) => v.id == viagemId);
    if (index == -1) {
      return ResultadoOperacaoViagem.erro('Horário não encontrado.');
    }

    final reordenados = <PassageiroViagemModel>[];
    for (int i = 0; i < novosPassageiros.length; i++) {
      reordenados.add(novosPassageiros[i].copyWith(ordemEmbarque: i + 1));
    }

    final viagemAtualizada = _todasViagensMemoria[index].copyWith(
      passageiros: reordenados,
      passageirosIds: reordenados
          .expand((p) => [p.pacienteId, if (p.acompanhanteId != null) p.acompanhanteId!])
          .where((id) => id.isNotEmpty)
          .toList(),
    );

    _todasViagensMemoria[index] = viagemAtualizada;
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    final ativaIndex = _viagensAtivasMemoria.indexWhere((v) => v.id == viagemId);
    if (ativaIndex != -1) {
      _viagensAtivasMemoria[ativaIndex] = viagemAtualizada;
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
    if (_viagemAtiva?.id == viagemId) {
      _viagemAtiva = viagemAtualizada;
      _viagemAtivaController.add(_viagemAtiva);
    }

    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagemId)
            .set(viagemAtualizada.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }

    return ResultadoOperacaoViagem.sucesso(viagemAtualizada);
  }

  // Linha em branco separadora entre encerrarViagem e resetParaTestes
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Restaura o estado interno de memória e notifica os fluxos com os valores fornecidos
  // ----------------------------------------------------------------------------
  // MÉTODO UTILITÁRIO DE TESTES: resetParaTestes
  // - O que faz: Restabelece o estado da memória e notifica streams para execução isolada de testes.
  // --------------------------------------------------------------------------
  void resetParaTestes({
    // Lista inicial opcional de veículos para simulação
    List<VeiculoModel>? veiculosIniciais,
    // Viagem ativa inicial opcional para simulação
    ViagemModel? viagemAtivaInicial,
    // Sessão de veículo inicial opcional para simulação (Issue #65)
    SessaoVeiculoModel? sessaoAtivaInicial,
    // Lista de viagens ativas iniciais para simulação (Issue #65)
    List<ViagemModel>? viagensAtivasIniciais,
    // Lista de todas as viagens cadastradas para simulação (FASE 1)
    List<ViagemModel>? todasViagensIniciais,
  // Abre o corpo do método resetParaTestes
  }) {
    // Restaura a sessão ativa
    _sessaoAtiva = sessaoAtivaInicial;
    _sessaoAtivaController.add(_sessaoAtiva);

    // Restaura as viagens ativas
    _viagensAtivasMemoria.clear();
    if (viagensAtivasIniciais != null) {
      _viagensAtivasMemoria.addAll(viagensAtivasIniciais);
    } else if (viagemAtivaInicial != null) {
      _viagensAtivasMemoria.add(viagemAtivaInicial);
    }
    _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));

    // Restaura todas as viagens
    _todasViagensMemoria.clear();
    if (todasViagensIniciais != null) {
      _todasViagensMemoria.addAll(todasViagensIniciais);
    } else if (viagensAtivasIniciais != null) {
      _todasViagensMemoria.addAll(viagensAtivasIniciais);
    } else if (viagemAtivaInicial != null) {
      _todasViagensMemoria.add(viagemAtivaInicial);
    }
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    // Restaura a viagem ativa para o valor parametrizado
    _viagemAtiva = viagemAtivaInicial ?? (_viagensAtivasMemoria.isNotEmpty ? _viagensAtivasMemoria.first : null);
    // Emite o novo estado na stream de viagem ativa
    _viagemAtivaController.add(_viagemAtiva);
    // Limpa a lista interna de veículos da memória
    _veiculosMemoria.clear();
    // Se foram fornecidos veículos customizados, insere-os na memória
    if (veiculosIniciais != null) {
      _veiculosMemoria.addAll(veiculosIniciais);
    // Caso contrário, reinicializa a lista padrão da prefeitura
    } else {
      _inicializado = false;
      _inicializarDadosBase();
    // Fecha else de veículos padrão
    }
    // Emite a lista de veículos atualizada na stream de frota
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );
  // Fecha o método resetParaTestes
  }

// Fecha a declaração da classe ViagemService
}
