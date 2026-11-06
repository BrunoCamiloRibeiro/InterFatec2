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

import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import 'validacao_viagem.dart';

// Linha em branco separadora entre imports e a classe de resultado
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
    );

    // Linha em branco separadora entre criação da viagem e notificação dos fluxos
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Atualiza a variável e notifica os fluxos de dados
    // ------------------------------------------------------------------------
    // Atualiza a propriedade interna de viagem ativa
    _viagemAtiva = novaViagem;
    // Emite o novo objeto na stream de viagem ativa
    _viagemAtivaController.add(_viagemAtiva);
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
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Altera o status da viagem para encerrada e libera o veículo associado
  // ----------------------------------------------------------------------------
  // MÉTODO ASSÍNCRONO: encerrarViagem
  // - Registra KM final e dataHoraFim no documento da viagem;
  // - Libera o veículo associado ('emUso: false' e 'motoristaAtualId: null');
  // - Libera o motorista na coleção 'usuarios' ('emViagem: false');
  // - Zera '_viagemAtiva' e notifica as streams.
  // --------------------------------------------------------------------------
  Future<void> encerrarViagem({int? kmFinal, int? kmRodado}) async {
    // Interrompe se não houver viagem ativa em curso
    if (_viagemAtiva == null) return;

    // Linha em branco separadora entre checagem de viagem ativa e extração de dados
    // Extrai a viagem ativa atual
    final viagem = _viagemAtiva!;
    // Extrai o ID do veículo utilizado
    final veiculoId = viagem.veiculoId;

    // Linha em branco separadora entre extração e atualização de memória
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Atualiza os dados do veículo na lista em memória
    // ------------------------------------------------------------------------
    // Localiza o veículo utilizado na lista da memória
    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculoId);
    // Se o veículo for encontrado na memória, atualiza sua disponibilidade
    if (index != -1) {
      // Libera o veículo na memória e atualiza a quilometragem se informada
      _veiculosMemoria[index] = _veiculosMemoria[index].copyWith(
        emUso: false,
        motoristaAtualId: null,
        quilometragemAtual:
            kmFinal ?? _veiculosMemoria[index].quilometragemAtual,
      );
    // Fecha verificação do índice
    }

    // Linha em branco separadora entre memória e notificação de fluxos
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Limpa a viagem ativa e atualiza os fluxos de dados
    // ------------------------------------------------------------------------
    // Zera a propriedade de viagem ativa
    _viagemAtiva = null;
    // Emite nulo na stream de viagem ativa
    _viagemAtivaController.add(null);
    // Emite a nova lista de veículos disponíveis na stream de frota
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );

    // Linha em branco separadora entre notificação local e atualização no Firestore
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Atualiza os documentos no Firestore
    // ------------------------------------------------------------------------
    // Atualiza os registros correspondentes no Cloud Firestore se disponível
    if (_isFirebaseDisponivel()) {
      // Bloco try para capturar exceções de escrita no Firestore
      try {
        // Prepara os dados para liberar o veículo
        final dadosVeiculo = <String, dynamic>{
          'emUso': false,
          'motoristaAtualId': null,
        };
        // Se o KM final foi informado, adiciona aos dados do veículo
        if (kmFinal != null) {
          dadosVeiculo['quilometragemAtual'] = kmFinal;
        // Fecha checagem de kmFinal
        }
        // Grava as alterações do veículo no Firestore
        await FirebaseFirestore.instance
            .collection('veiculos')
            .doc(veiculoId)
            .set(dadosVeiculo, SetOptions(merge: true));

        // Linha em branco separadora entre veículo e viagem no Firestore
        // Prepara os dados para encerrar o documento da viagem
        final dadosViagem = <String, dynamic>{
          'status': 'encerrada',
          'dataHoraFim': DateTime.now().toIso8601String(),
        };
        // Se o KM final foi informado, adiciona aos dados da viagem
        if (kmFinal != null) {
          dadosViagem['kmFinal'] = kmFinal;
        // Fecha checagem de kmFinal
        }
        // Se o KM rodado foi informado, adiciona aos dados da viagem
        if (kmRodado != null) {
          dadosViagem['kmRodado'] = kmRodado;
        // Fecha checagem de kmRodado
        }
        // Grava as alterações na coleção de viagens
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagem.id)
            .set(dadosViagem, SetOptions(merge: true));

        // Linha em branco separadora entre viagem e motorista no Firestore
        // Libera o motorista no Firestore definindo emViagem como false
        if (viagem.motoristaId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(viagem.motoristaId)
              .set({'emViagem': false}, SetOptions(merge: true));
        // Fecha checagem de motoristaId
        }
      // Captura erros de escrita remota sem propagar falha
      } catch (_) {
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Ignora erros de escrita remota
        // --------------------------------------------------------------------
      // Fecha o bloco catch
      }
    // Fecha a checagem de Firebase disponível
    }
  // Fecha o método encerrarViagem
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
  // Abre o corpo do método resetParaTestes
  }) {
    // Restaura a viagem ativa para o valor parametrizado
    _viagemAtiva = viagemAtivaInicial;
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
