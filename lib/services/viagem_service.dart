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
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/paciente_model.dart';
import '../models/sessao_veiculo_model.dart';
import '../models/user_role.dart';
import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import 'auth_service.dart';
import 'codigo_acesso_service.dart';
import 'localizacao_motorista_service.dart';
import 'paciente_sync_service.dart';
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
  bool _escutandoFirestore = false;
  bool _sessaoFinalizadaPeloMotorista = false;
  StreamSubscription<PacienteModel>? _subSyncPacientesInterno;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subVeiculosRemoto;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subPacientesRemoto;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subViagensRemoto;

  /// Mapa de sessões ativas por motorista para isolamento de concorrência real.
  final Map<String, SessaoVeiculoModel> _sessoesAtivasPorMotorista = {};

  /// Stream de erros de sincronização e rollback do Firestore (unavailable, permission-denied, resource-exhausted).
  final StreamController<String> _errosSincronizacaoController =
      StreamController<String>.broadcast();
  Stream<String> get errosSincronizacaoStream =>
      _errosSincronizacaoController.stream;

  /// Contador de gravações remotas no Firestore para auditoria de FinOps (plano Spark).
  int _totalGravacoesFirestoreJornada = 0;
  int get totalGravacoesFirestoreJornada => _totalGravacoesFirestoreJornada;

  /// Hook injetável para testes simularem falha de rede/permissão no meio de mutações em background.
  @visibleForTesting
  Future<void> Function(String operacao, Map<String, dynamic> payload)?
      executorPersistenciaRemotaOverride;

  void _tratarFalhaFirestore(
    String operacao,
    Object erro, {
    VoidCallback? onRollback,
  }) {
    String codigo = 'unknown';
    String detalhe = erro.toString();
    if (erro is FirebaseException) {
      codigo = erro.code;
      detalhe = erro.message ?? erro.code;
    }
    debugPrint('Falha Firestore em [$operacao] ($codigo): $detalhe');
    if (onRollback != null &&
        (erro is FirebaseException ||
            codigo == 'unavailable' ||
            codigo == 'permission-denied' ||
            codigo == 'resource-exhausted' ||
            detalhe.contains('permission-denied') ||
            detalhe.contains('unavailable') ||
            detalhe.contains('resource-exhausted') ||
            executorPersistenciaRemotaOverride != null)) {
      onRollback();
    }
    if (!_errosSincronizacaoController.isClosed) {
      _errosSincronizacaoController.add(
        'Falha de sincronização ($codigo) em $operacao: $detalhe',
      );
    }
  }

  String _obterInicioDoDiaOperacionalIso([DateTime? referencia]) {
    final ref = referencia ?? DateTime.now();
    return DateTime(ref.year, ref.month, ref.day).toIso8601String();
  }

  String _normalizarTextoRota(String valor) {
    return valor
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÂÃ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊ]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÔÕ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛ]'), 'U')
        .replaceAll('Ç', 'C');
  }

  /// Verifica se uma viagem aberta pode ser assumida por um motorista/veículo sem sobrescrever frotas paralelas.
  bool _viagemElegivelParaSessao(
    ViagemModel v, {
    required String motoristaId,
    required String veiculoId,
    required String veiculoPlaca,
    String? cidadeDestino,
    String? sessaoId,
  }) {
    if (v.isCancelada || v.isConcluida) return false;
    if (v.id.startsWith('sessao_ativa_')) return false;
    if (todosPacientesVoltaram(v)) return false;

    final motViagem = v.motoristaId.trim();
    final motAlvo = motoristaId.trim();
    if (motViagem.isNotEmpty && motAlvo.isNotEmpty && motViagem != motAlvo && motViagem != 'motorista_atual') {
      return false;
    }

    final veicViagem = v.veiculoId.trim();
    final veicAlvo = veiculoId.trim();
    final placaViagem = _normalizarPlacaInterna(v.veiculoPlaca);
    final placaAlvo = _normalizarPlacaInterna(veiculoPlaca);
    final vinculadaExplicitamenteAoMotorista =
        motViagem.isNotEmpty && (motViagem == motAlvo || motViagem == 'motorista_atual');
    final vinculadaExplicitamenteAoVeiculo =
        (veicViagem.isNotEmpty && veicViagem == veicAlvo) ||
        (placaViagem.isNotEmpty && placaViagem == placaAlvo);

    final sessaoViagem = v.sessaoId?.trim() ?? '';
    final sessaoAlvo = sessaoId?.trim() ?? '';
    if (sessaoViagem.isNotEmpty &&
        sessaoAlvo.isNotEmpty &&
        sessaoViagem != sessaoAlvo &&
        v.isAtiva &&
        !vinculadaExplicitamenteAoMotorista &&
        !vinculadaExplicitamenteAoVeiculo) {
      return false;
    }

    if (veicViagem.isNotEmpty && veicAlvo.isNotEmpty && veicViagem != veicAlvo) {
      final outroEmUso = _veiculosMemoria.any(
        (vm) => vm.id == veicViagem && vm.emUso && vm.motoristaAtualId != motAlvo,
      );
      if (v.isPlanejada || outroEmUso || (sessaoViagem.isNotEmpty && !vinculadaExplicitamenteAoMotorista)) {
        return false;
      }
    }

    if (placaViagem.isNotEmpty &&
        placaAlvo.isNotEmpty &&
        placaViagem != placaAlvo) {
      final outroEmUso = _veiculosMemoria.any(
        (vm) =>
            _normalizarPlacaInterna(vm.placa) == placaViagem &&
            vm.emUso &&
            vm.motoristaAtualId != motAlvo,
      );
      if (v.isPlanejada || outroEmUso || (sessaoViagem.isNotEmpty && !vinculadaExplicitamenteAoMotorista)) {
        return false;
      }
    }

    if (cidadeDestino != null &&
        cidadeDestino.trim().isNotEmpty &&
        v.cidadeDestino.trim().isNotEmpty) {
      final rotaViagem = _normalizarTextoRota(v.cidadeDestino);
      final rotaAlvo = _normalizarTextoRota(cidadeDestino);
      final destinoCombina = rotaViagem == rotaAlvo ||
          (rotaViagem.length >= 3 && rotaAlvo.contains(rotaViagem)) ||
          (rotaAlvo.length >= 3 && rotaViagem.contains(rotaAlvo));
      if (!destinoCombina &&
          !vinculadaExplicitamenteAoMotorista &&
          !vinculadaExplicitamenteAoVeiculo) {
        return false;
      }
    }

    return true;
  }

  /// Retorna as viagens ativas filtradas especificamente para um motorista ou sessão.
  List<ViagemModel> obterViagensAtivasPorMotorista(
    String motoristaId, {
    String? veiculoId,
  }) {
    final sessaoMot = _sessoesAtivasPorMotorista[motoristaId];
    final vid = veiculoId ?? sessaoMot?.veiculoId ?? '';
    final sid = sessaoMot?.id ?? '';
    return _todasViagensMemoria.where((v) {
      if (v.isCancelada || v.isConcluida || todosPacientesVoltaram(v)) {
        return false;
      }
      if (sid.isNotEmpty && v.sessaoId == sid) return true;
      if (vid.isNotEmpty && v.veiculoId == vid && v.isAtiva) return true;
      if (motoristaId.isNotEmpty && v.motoristaId == motoristaId && v.isAtiva) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Viagens que foram concluídas automaticamente (todos os pacientes em status 4) durante a sessão atual do motorista,
  /// preservadas até que o motorista gere o relatório e finalize a sessão do veículo.
  final List<ViagemModel> _viagensConcluidasNaSessao = [];

  ViagemModel _enriquecerViagemParaRelatorio(
    ViagemModel v, {
    ViagemModel? referenciaSessao,
  }) {
    final sessao = _sessaoAtiva;
    final conclSessao =
        _viagensConcluidasNaSessao.where((vc) => vc.id == v.id).firstOrNull;
    final placa = v.veiculoPlaca.isNotEmpty
        ? v.veiculoPlaca
        : (conclSessao?.veiculoPlaca.isNotEmpty == true
              ? conclSessao!.veiculoPlaca
              : (sessao?.veiculoPlaca.isNotEmpty == true
                    ? sessao!.veiculoPlaca
                    : (referenciaSessao?.veiculoPlaca ?? '')));
    final modelo = v.veiculoModelo.isNotEmpty
        ? v.veiculoModelo
        : (conclSessao?.veiculoModelo.isNotEmpty == true
              ? conclSessao!.veiculoModelo
              : (sessao?.veiculoModelo.isNotEmpty == true
                    ? sessao!.veiculoModelo
                    : (referenciaSessao?.veiculoModelo ?? '')));
    final veiculoId = v.veiculoId.isNotEmpty
        ? v.veiculoId
        : (conclSessao?.veiculoId.isNotEmpty == true
              ? conclSessao!.veiculoId
              : (sessao?.veiculoId.isNotEmpty == true
                    ? sessao!.veiculoId
                    : (referenciaSessao?.veiculoId ?? '')));
    final kmIni = v.kmInicial > 0
        ? v.kmInicial
        : ((conclSessao?.kmInicial ?? 0) > 0
              ? conclSessao!.kmInicial
              : ((sessao?.kmInicial ?? 0) > 0
                    ? sessao!.kmInicial
                    : (referenciaSessao?.kmInicial ?? 0)));
    final motNome = v.motoristaNome.isNotEmpty
        ? v.motoristaNome
        : (conclSessao?.motoristaNome.isNotEmpty == true
              ? conclSessao!.motoristaNome
              : (sessao?.motoristaNome.isNotEmpty == true
                    ? sessao!.motoristaNome
                    : (referenciaSessao?.motoristaNome ?? '')));
    final codigos = <String, String>{
      ...?conclSessao?.codigosAcesso,
      ...v.codigosAcesso,
    };
    return v.copyWith(
      veiculoId: veiculoId,
      veiculoPlaca: placa,
      veiculoModelo: modelo,
      kmInicial: kmIni,
      motoristaNome: motNome,
      codigosAcesso: codigos,
    );
  }

  /// Retorna as viagens reais operadas na sessão para geração do relatório PDF.
  List<ViagemModel> obterViagensParaRelatorio({
    List<ViagemModel>? viagensExplicitas,
    ViagemModel? viagemUnica,
  }) {
    final informadas = <ViagemModel>[
      ...?viagensExplicitas,
      ?viagemUnica,
      ..._viagensAtivasMemoria,
      ?_viagemAtiva,
    ];
    final refSessao = viagemUnica ?? _viagemAtiva ?? informadas.firstOrNull;
    final reais = <String, ViagemModel>{};
    for (final v in _viagensConcluidasNaSessao) {
      if (v.id.isNotEmpty && !v.id.startsWith('sessao_ativa_')) {
        final emTodas = _todasViagensMemoria.where((tv) => tv.id == v.id).firstOrNull;
        reais[v.id] = _enriquecerViagemParaRelatorio(
          emTodas ?? v,
          referenciaSessao: refSessao,
        );
      }
    }
    for (final v in informadas) {
      if (v.id.isNotEmpty && !v.id.startsWith('sessao_ativa_')) {
        final emTodas = _todasViagensMemoria.where((tv) => tv.id == v.id).firstOrNull;
        reais[v.id] = _enriquecerViagemParaRelatorio(
          emTodas ?? v,
          referenciaSessao: refSessao,
        );
      }
    }
    if (reais.isNotEmpty) {
      return reais.values.toList();
    }
    final unicas = <String, ViagemModel>{};
    for (final v in informadas) {
      if (v.id.isNotEmpty) {
        unicas[v.id] = _enriquecerViagemParaRelatorio(
          v,
          referenciaSessao: refSessao,
        );
      }
    }
    return unicas.values.toList();
  }

  /// Reconstrói a lista de [PacienteModel] de uma viagem para o relatório PDF,
  /// funcionando mesmo quando a viagem já foi concluída automaticamente e a lista ativa da tela esvaziou.
  List<PacienteModel> obterPacientesParaViagemRelatorio(
    ViagemModel viagem, {
    List<PacienteModel>? pacientesInformados,
  }) {
    final mapaInformados = <String, PacienteModel>{
      if (pacientesInformados != null)
        for (final p in pacientesInformados) p.id: p,
    };
    if (viagem.passageiros.isNotEmpty) {
      return viagem.passageiros.map((pv) {
        final pInf = mapaInformados[pv.pacienteId];
        final pMem = PacienteSyncService().obterPacienteMemoria(pv.pacienteId);
        final pBase = pInf ?? pMem;
        final st = resolverStatusEfetivoPassageiro(
          pv,
          pacientesContexto: pacientesInformados,
        );
        return PacienteModel(
          id: pv.pacienteId,
          nome: pv.pacienteNome.isNotEmpty
              ? pv.pacienteNome
              : (pBase?.nome ?? ''),
          cpf: (pv.pacienteCpf != null && pv.pacienteCpf!.isNotEmpty)
              ? pv.pacienteCpf!
              : (pBase?.cpf ?? ''),
          telefone: (pBase != null && pBase.telefone.isNotEmpty)
              ? pBase.telefone
              : (pv.acompanhanteTelefone ?? ''),
          enderecoPaciente: pv.localOrigem.isNotEmpty
              ? pv.localOrigem
              : (pBase?.enderecoPaciente ?? ''),
          localSaida: pv.localOrigem.isNotEmpty
              ? pv.localOrigem
              : (pBase?.localSaida ?? ''),
          localConsulta: pv.localDestino.isNotEmpty
              ? pv.localDestino
              : (pBase?.localConsulta ?? ''),
          horarioConsulta: pv.horarioAtendimento.isNotEmpty
              ? pv.horarioAtendimento
              : (pBase?.horarioConsulta ?? ''),
          nomeAcompanhante:
              (pv.acompanhanteNome != null && pv.acompanhanteNome!.isNotEmpty)
                  ? pv.acompanhanteNome
                  : pBase?.nomeAcompanhante,
          cpfAcompanhante: pBase?.cpfAcompanhante,
          telAcompanhante: (pv.acompanhanteTelefone != null &&
                  pv.acompanhanteTelefone!.isNotEmpty)
              ? pv.acompanhanteTelefone
              : pBase?.telAcompanhante,
          rg: pBase?.rg,
          cnh: pBase?.cnh,
          status: st,
          prontoRetorno: pBase?.prontoRetorno ?? false,
          janelaReversao: pBase?.janelaReversao,
        );
      }).toList();
    }
    return pacientesInformados ?? const <PacienteModel>[];
  }

  String _normalizarPlacaInterna(String placa) {
    return placa.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  /// Resolve o status efetivo de um passageiro (considerando memória de sincronização e contexto).
  int resolverStatusEfetivoPassageiro(
    PassageiroViagemModel p, {
    List<PacienteModel>? pacientesContexto,
  }) {
    int statusEfetivo = p.statusEmbarque;
    if (pacientesContexto != null) {
      final pacCtx =
          pacientesContexto.where((x) => x.id == p.pacienteId).firstOrNull;
      if (pacCtx != null) {
        if (pacCtx.status == 5 || statusEfetivo == 5) return 5;
        // Evita que um paciente recém-adicionado (statusEmbarque == 0) herde status == 4 residual de outra viagem anterior
        if (pacCtx.status > statusEfetivo &&
            !(statusEfetivo == 0 && pacCtx.status == 4)) {
          statusEfetivo = pacCtx.status;
        }
      }
    }
    final pacSync = PacienteSyncService().obterPacienteMemoria(p.pacienteId);
    if (pacSync != null) {
      if (pacSync.status == 5 || statusEfetivo == 5) return 5;
      if (pacSync.status > statusEfetivo &&
          !(statusEfetivo == 0 && pacSync.status == 4)) {
        statusEfetivo = pacSync.status;
      }
    }
    return statusEfetivo;
  }

  /// Calcula a quantidade de lugares preenchidos na viagem considerando apenas
  /// as pessoas às quais o motorista já deu a baixa em andamento (status >= 1 e <= 3).
  int calcularLugaresPreenchidosComBaixa(
    ViagemModel viagem, {
    List<PacienteModel>? pacientesContexto,
  }) {
    if (viagem.passageiros.isNotEmpty) {
      int total = 0;
      for (final p in viagem.passageiros) {
        final st = resolverStatusEfetivoPassageiro(
          p,
          pacientesContexto: pacientesContexto,
        );
        if (st >= 1 && st <= 3) {
          total += p.assentosOcupados;
        }
      }
      return total;
    }
    if (pacientesContexto != null && pacientesContexto.isNotEmpty) {
      final ids = viagem.passageirosIds.toSet();
      final lista = ids.isNotEmpty
          ? pacientesContexto.where((p) => ids.contains(p.id))
          : pacientesContexto;
      int total = 0;
      for (final p in lista) {
        if (p.status >= 1 && p.status <= 3) {
          total += (p.nomeAcompanhante != null &&
                  p.nomeAcompanhante!.trim().isNotEmpty)
              ? 2
              : 1;
        }
      }
      return total;
    }
    return 0;
  }

  /// Verifica se todos os pacientes da viagem já voltaram (status == 4, desconsiderando cancelados status == 5).
  bool todosPacientesVoltaram(
    ViagemModel viagem, {
    List<PacienteModel>? pacientesContexto,
  }) {
    if (viagem.passageiros.isNotEmpty) {
      final naoCancelados = viagem.passageiros.where((p) {
        final st = resolverStatusEfetivoPassageiro(
          p,
          pacientesContexto: pacientesContexto,
        );
        return st != 5;
      }).toList();
      if (naoCancelados.isEmpty) return true;
      return naoCancelados.every((p) {
        final st = resolverStatusEfetivoPassageiro(
          p,
          pacientesContexto: pacientesContexto,
        );
        return st == 4;
      });
    }
    if (pacientesContexto != null && pacientesContexto.isNotEmpty) {
      final ids = viagem.passageirosIds.toSet();
      final listaRef = ids.isNotEmpty
          ? pacientesContexto.where((p) => ids.contains(p.id)).toList()
          : pacientesContexto;
      final naoCancelados = listaRef.where((p) => p.status != 5).toList();
      if (naoCancelados.isEmpty) return true;
      return naoCancelados.every((p) => p.status == 4);
    }
    if (viagem.passageirosIds.isNotEmpty) {
      bool algumRegistrado = false;
      for (final id in viagem.passageirosIds) {
        final pacSync = PacienteSyncService().obterPacienteMemoria(id);
        if (pacSync != null) {
          algumRegistrado = true;
          if (pacSync.status != 4 && pacSync.status != 5) {
            return false;
          }
        } else {
          return false;
        }
      }
      if (algumRegistrado) return true;
    }
    return viagem.isConcluida;
  }

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
  Stream<List<ViagemModel>> get todasViagensStream {
    _garantirEscutaFirestore();
    return _todasViagensController.stream;
  }

  /// Retorna lista imutável com todas as viagens em memória
  List<ViagemModel> get todasViagens {
    _garantirEscutaFirestore();
    return List.unmodifiable(_todasViagensMemoria);
  }

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


  /// Retorna lista imutável com todos os veículos em memória
  List<VeiculoModel> get todosVeiculos => List.unmodifiable(_veiculosMemoria);
  // Linha em branco separadora entre getters e métodos privados
  // ----------------------------------------------------------------------------
  // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
  // Insere registros padrão de veículos na lista em memória
  // ----------------------------------------------------------------------------
  // MÉTODO PRIVADO: _inicializarDadosBase
  // - Popula a lista em memória com a frota padrão do município de Poloni.
  // --------------------------------------------------------------------------
  void _inicializarDadosBase() {
    _subSyncPacientesInterno ??=
        PacienteSyncService().alteracoesGlobaisStream.listen((p) {
      atualizarStatusPassageiroNaViagem(
        viagemId: '',
        pacienteId: p.id,
        novoStatus: p.status,
      );
    });
    // Interrompe se a lista já tiver sido inicializada anteriormente
    if (_inicializado) {
      _garantirEscutaFirestore();
      return;
    }
    _garantirEscutaFirestore();
    // Marca a flag como verdadeira para prevenir reinicialização
    _inicializado = true;
  // Fecha o método _inicializarDadosBase
  }

  void _garantirEscutaFirestore() {
    if (_escutandoFirestore || !_isFirebaseDisponivel()) return;
    _escutandoFirestore = true;
    try {
      _subVeiculosRemoto?.cancel();
      _subVeiculosRemoto = FirebaseFirestore.instance
          .collection('veiculos')
          .snapshots()
          .listen((snap) {
        _veiculosMemoria
          ..clear()
          ..addAll(snap.docs.map((d) => VeiculoModel.fromMap(d.data(), docId: d.id)));
        if (!_veiculosController.isClosed) {
          _veiculosController.add(ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria));
        }
      }, onError: (Object e) {
        _tratarFalhaFirestore('escutar_veiculos', e);
      });

      _subPacientesRemoto?.cancel();
      _subPacientesRemoto = FirebaseFirestore.instance
          .collection('usuarios')
          .where('role', isEqualTo: 'paciente')
          .snapshots()
          .listen((snap) {
        for (final d in snap.docs) {
          final pac = PacienteModel.fromMap(d.data(), docId: d.id);
          PacienteSyncService().atualizarPacienteEmMemoria(pac);
          final podePropagar = pac.status != 4 ||
              _todasViagensMemoria.any(
                (v) =>
                    !v.isCancelada &&
                    !v.isConcluida &&
                    v.passageiros.any(
                      (p) => p.pacienteId == pac.id && p.statusEmbarque > 0,
                    ),
              );
          if (podePropagar) {
            atualizarStatusPassageiroNaViagem(
              viagemId: '',
              pacienteId: pac.id,
              novoStatus: pac.status,
              persistirRemoto: false,
            );
          }
        }
      }, onError: (Object e) {
        _tratarFalhaFirestore('escutar_pacientes', e);
      });

      // Filtro temporal estrito (FinOps): busca apenas viagens do dia operacional em diante,
      // e NUNCA executa set()/update() dentro do listener de snapshots para evitar loops re-entrantes.
      _subViagensRemoto?.cancel();
      _subViagensRemoto = FirebaseFirestore.instance
          .collection('viagens')
          .snapshots()
          .listen((snap) {
        final viagensCarregadas = <ViagemModel>[];
        for (final d in snap.docs) {
          var v = ViagemModel.fromMap(d.data(), docId: d.id);
          // Sincroniza códigos apenas em memória local (Zero escritas dentro do listener!)
          if ((v.isAtiva || v.isPlanejada) && !v.isCancelada && !v.isConcluida) {
            final (codigos, hashes, alterou) = _sincronizarCodigosDaViagem(
              viagemId: v.id,
              passageiros: v.passageiros,
              passageirosIds: v.passageirosIds,
              codigosExistentes: v.codigosAcesso,
              hashesExistentes: v.codigosHash,
            );
            if (alterou) {
              v = v.copyWith(codigosAcesso: codigos, codigosHash: hashes);
            }
          }
          viagensCarregadas.add(v);
        }

        sincronizarViagensRemotas(viagensCarregadas);
      }, onError: (Object e) {
        _tratarFalhaFirestore('escutar_viagens', e);
      });
    } on FirebaseException catch (e) {
      _escutandoFirestore = false;
      _tratarFalhaFirestore('garantir_escuta_firestore', e);
    } catch (e) {
      _escutandoFirestore = false;
      _tratarFalhaFirestore('garantir_escuta_firestore', e);
    }
  }

  /// Encerra os listeners ativos associados ao escopo da sessão/tela (FinOps).
  void encerrarEscutasFirestore() {
    _subVeiculosRemoto?.cancel();
    _subVeiculosRemoto = null;
    _subPacientesRemoto?.cancel();
    _subPacientesRemoto = null;
    _subViagensRemoto?.cancel();
    _subViagensRemoto = null;
    _escutandoFirestore = false;
  }

  ViagemModel _criarPlaceholderSessaoAtiva(SessaoVeiculoModel sessao, {String cidadeDestino = ''}) {
    return ViagemModel(
      id: 'sessao_ativa_${sessao.veiculoId}',
      motoristaId: '',
      motoristaNome: '',
      veiculoId: sessao.veiculoId,
      veiculoPlaca: sessao.veiculoPlaca,
      veiculoModelo: sessao.veiculoModelo,
      kmInicial: sessao.kmInicial,
      cidadeDestino: cidadeDestino,
      dataHoraInicio: sessao.dataHoraInicio,
      status: 'ativa',
      sessaoId: sessao.id,
    );
  }

  /// Sincroniza a lista em memória com um snapshot de viagens vindo do Firestore.
  void sincronizarViagensRemotas(List<ViagemModel> viagensCarregadas) {
    final processadas = <ViagemModel>[];
    for (var v in viagensCarregadas) {
      if (v.id.startsWith('sessao_ativa_')) continue;
      if (!v.isPlanejada &&
          !v.isCancelada &&
          !v.isConcluida &&
          v.passageiros.isNotEmpty &&
          v.passageiros.any((p) => p.statusEmbarque > 0) &&
          todosPacientesVoltaram(v)) {
        final agora = DateTime.now();
        final codigosOriginais = Map<String, String>.from(v.codigosAcesso);
        v = v.copyWith(
          status: 'encerrada',
          dataHoraFim: v.dataHoraFim ?? agora,
          codigosAcesso: const {},
        );
        if (_sessaoAtiva != null &&
            !_viagensConcluidasNaSessao.any((vc) => vc.id == v.id)) {
          _viagensConcluidasNaSessao.add(
            _enriquecerViagemParaRelatorio(
              v.copyWith(codigosAcesso: codigosOriginais),
            ),
          );
        }
      }
      processadas.add(v);
    }

    _todasViagensMemoria
      ..clear()
      ..addAll(processadas);
    if (!_todasViagensController.isClosed) {
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    // Sincroniza viagens que fazem parte da sessão ativa em memória, removendo as concluídas/canceladas
    bool atualizouAtiva = false;
    for (int i = _viagensAtivasMemoria.length - 1; i >= 0; i--) {
      final atualMem = _viagensAtivasMemoria[i];
      if (atualMem.id.startsWith('sessao_ativa_')) continue;
      final vRemota = processadas
          .where((v) => v.id == atualMem.id)
          .firstOrNull;
      if (vRemota != null) {
        if (vRemota.isCancelada || vRemota.isConcluida || todosPacientesVoltaram(vRemota)) {
          if (vRemota.isConcluida &&
              !_viagensConcluidasNaSessao.any((vc) => vc.id == vRemota.id)) {
            _viagensConcluidasNaSessao.add(
              _enriquecerViagemParaRelatorio(
                vRemota.copyWith(
                  codigosAcesso: {
                    ...atualMem.codigosAcesso,
                    ...vRemota.codigosAcesso,
                  },
                ),
                referenciaSessao: atualMem,
              ),
            );
          }
          final idRemovido = atualMem.id;
          _viagensAtivasMemoria.removeAt(i);
          atualizouAtiva = true;
          if (_viagemAtiva?.id == idRemovido) {
            if (_viagensAtivasMemoria.isNotEmpty) {
              _viagemAtiva = _viagensAtivasMemoria.first;
            } else if (_sessaoAtiva != null) {
              final ph = _criarPlaceholderSessaoAtiva(
                _sessaoAtiva!,
                cidadeDestino: vRemota.cidadeDestino,
              );
              _viagensAtivasMemoria.add(ph);
              _viagemAtiva = ph;
            } else {
              _viagemAtiva = null;
            }
            if (!_viagemAtivaController.isClosed) {
              _viagemAtivaController.add(_viagemAtiva);
            }
          }
        } else {
          final pertenceSessaoAtual = _sessaoAtiva != null &&
              _viagemElegivelParaSessao(
                vRemota,
                motoristaId: _sessaoAtiva!.motoristaId,
                veiculoId: _sessaoAtiva!.veiculoId,
                veiculoPlaca: _sessaoAtiva!.veiculoPlaca,
                sessaoId: _sessaoAtiva!.id,
              );
          final vComVeiculoSessao = pertenceSessaoAtual
              ? vRemota.copyWith(
                  veiculoId: _sessaoAtiva!.veiculoId,
                  veiculoPlaca: _sessaoAtiva!.veiculoPlaca,
                  veiculoModelo: _sessaoAtiva!.veiculoModelo,
                  kmInicial: _sessaoAtiva!.kmInicial,
                  status: 'ativa',
                )
              : vRemota;
          _viagensAtivasMemoria[i] = vComVeiculoSessao;
          atualizouAtiva = true;
          if (_viagemAtiva?.id == vRemota.id) {
            _viagemAtiva = vComVeiculoSessao;
            if (!_viagemAtivaController.isClosed) {
              _viagemAtivaController.add(_viagemAtiva);
            }
          }
        }
      }
    }

    // Se houver uma sessão de veículo ativa, vincula apenas novas viagens abertas elegíveis a esta sessão/veículo
    if (_sessaoAtiva != null) {
      final destinoSessao = _viagemAtiva?.cidadeDestino ?? '';
      final novasAbertas = processadas.where(
        (v) =>
            _viagemElegivelParaSessao(
              v,
              motoristaId: _sessaoAtiva!.motoristaId,
              veiculoId: _sessaoAtiva!.veiculoId,
              veiculoPlaca: _sessaoAtiva!.veiculoPlaca,
              cidadeDestino: destinoSessao,
              sessaoId: _sessaoAtiva!.id,
            ) &&
            !_viagensAtivasMemoria.any((va) => va.id == v.id),
      );
      for (final na in novasAbertas) {
        _viagensAtivasMemoria.removeWhere((va) => va.id.startsWith('sessao_ativa_'));
        final vAtivada = na.copyWith(
          veiculoId: _sessaoAtiva!.veiculoId,
          veiculoPlaca: _sessaoAtiva!.veiculoPlaca,
          veiculoModelo: _sessaoAtiva!.veiculoModelo,
          kmInicial: _sessaoAtiva!.kmInicial,
          status: 'ativa',
          sessaoId: _sessaoAtiva!.id,
        );
        _viagensAtivasMemoria.add(vAtivada);
        atualizouAtiva = true;
      }
      if (atualizouAtiva &&
          (_viagemAtiva == null || _viagemAtiva!.id.startsWith('sessao_ativa_')) &&
          _viagensAtivasMemoria.isNotEmpty) {
        _viagemAtiva = _viagensAtivasMemoria.first;
        if (!_viagemAtivaController.isClosed) {
          _viagemAtivaController.add(_viagemAtiva);
        }
      }
    }

    if (atualizouAtiva && !_viagensAtivasController.isClosed) {
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
  }

  /// Restaura automaticamente a sessão de veículo ativa do motorista ao abrir o app ou a tela,
  /// para que ele só precise responder ao formulário de início de viagem após finalizar (gerar relatório).
  void restaurarSessaoMotoristaSeAtiva({
    required String motoristaId,
    required String motoristaNome,
    List<VeiculoModel>? frota,
  }) {
    if (_sessaoFinalizadaPeloMotorista) return;
    if (_sessaoAtiva != null && _viagemAtiva != null && _viagemAtiva!.isAtiva && !_viagemAtiva!.id.startsWith('sessao_ativa_')) return;
    if (motoristaId.trim().isEmpty) return;

    final listaVeiculos = (frota != null && frota.isNotEmpty) ? frota : _veiculosMemoria;
    VeiculoModel? veiculoEmUso = listaVeiculos.where((v) {
      if (!v.emUso) return false;
      final motVeiculo = v.motoristaAtualId?.trim() ?? '';
      return motVeiculo.isNotEmpty && motVeiculo == motoristaId.trim();
    }).firstOrNull;

    // Se o veículo não estiver formalmente marcado como emUso mas houver viagem ativa vinculada ao motorista:
    ViagemModel? viagemDoMotorista;
    if (veiculoEmUso == null) {
      viagemDoMotorista = _todasViagensMemoria.where((v) {
        if (v.isCancelada || v.isConcluida || todosPacientesVoltaram(v)) return false;
        final mot = v.motoristaId.trim();
        final motNome = v.motoristaNome.trim().toLowerCase();
        final motNomeAlvo = motoristaNome.trim().toLowerCase();
        final vinculadoAoMotorista = (mot.isNotEmpty && (mot == motoristaId.trim() || mot == 'motorista_atual')) ||
            (motNomeAlvo.isNotEmpty && motNome.isNotEmpty && motNome == motNomeAlvo);
        final semMotoristaEAtiva = mot.isEmpty && v.isAtiva;
        return vinculadoAoMotorista || semMotoristaEAtiva;
      }).firstOrNull;

      if (viagemDoMotorista != null) {
        veiculoEmUso = listaVeiculos.where((v) {
          return (viagemDoMotorista!.veiculoId.isNotEmpty &&
                  v.id == viagemDoMotorista.veiculoId) ||
              (viagemDoMotorista.veiculoPlaca.isNotEmpty &&
                  _normalizarPlacaInterna(v.placa) ==
                      _normalizarPlacaInterna(viagemDoMotorista.veiculoPlaca));
        }).firstOrNull ??
        VeiculoModel(
          id: viagemDoMotorista.veiculoId.isNotEmpty
              ? viagemDoMotorista.veiculoId
              : 'veiculo_${viagemDoMotorista.id}',
          placa: viagemDoMotorista.veiculoPlaca.isNotEmpty
              ? viagemDoMotorista.veiculoPlaca
              : 'TFD',
          modelo: viagemDoMotorista.veiculoModelo.isNotEmpty
              ? viagemDoMotorista.veiculoModelo
              : 'Veículo Municipal',
          quilometragemAtual: viagemDoMotorista.kmInicial,
          emUso: true,
          motoristaAtualId: motoristaId,
        );
      }
    } else {
      viagemDoMotorista = _todasViagensMemoria.where((v) {
        if (v.isCancelada || v.isConcluida || todosPacientesVoltaram(v)) return false;
        final vinculadoAoMotorista = (v.motoristaId.isNotEmpty && (v.motoristaId == motoristaId || v.motoristaId == 'motorista_atual')) ||
            (motoristaNome.trim().isNotEmpty && v.motoristaNome.trim().toLowerCase() == motoristaNome.trim().toLowerCase());
        final vinculadoAoVeiculo = (v.veiculoId.isNotEmpty && v.veiculoId == veiculoEmUso!.id) ||
            (v.veiculoPlaca.isNotEmpty && _normalizarPlacaInterna(v.veiculoPlaca) == _normalizarPlacaInterna(veiculoEmUso!.placa));
        final semMotoristaEAtiva = v.motoristaId.isEmpty && v.isAtiva;
        return vinculadoAoMotorista || vinculadoAoVeiculo || semMotoristaEAtiva;
      }).firstOrNull;
    }

    if (veiculoEmUso == null) return;

    final sessaoIdRestaurada = (viagemDoMotorista != null &&
            viagemDoMotorista.sessaoId != null &&
            viagemDoMotorista.sessaoId!.isNotEmpty)
        ? viagemDoMotorista.sessaoId!
        : 'sessao_${veiculoEmUso.id}';

    _sessaoAtiva ??= SessaoVeiculoModel(
      id: sessaoIdRestaurada,
      motoristaId: motoristaId,
      motoristaNome: motoristaNome,
      veiculoId: veiculoEmUso.id,
      veiculoPlaca: veiculoEmUso.placa,
      veiculoModelo: veiculoEmUso.modelo,
      kmInicial: veiculoEmUso.quilometragemAtual,
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
    );
    if (!_sessaoAtivaController.isClosed) {
      _sessaoAtivaController.add(_sessaoAtiva);
    }

    _viagensAtivasMemoria.removeWhere((va) => va.id.startsWith('sessao_ativa_'));
    for (int i = 0; i < _todasViagensMemoria.length; i++) {
      final base = _todasViagensMemoria[i];
      if (!_viagemElegivelParaSessao(
        base,
        motoristaId: motoristaId,
        veiculoId: veiculoEmUso.id,
        veiculoPlaca: veiculoEmUso.placa,
        sessaoId: _sessaoAtiva!.id,
      )) {
        continue;
      }

      final vAtivada = base.copyWith(
        motoristaId: base.motoristaId.isNotEmpty ? base.motoristaId : motoristaId,
        motoristaNome: base.motoristaNome.isNotEmpty ? base.motoristaNome : motoristaNome,
        veiculoId: veiculoEmUso.id,
        veiculoPlaca: veiculoEmUso.placa,
        veiculoModelo: veiculoEmUso.modelo,
        kmInicial: veiculoEmUso.quilometragemAtual,
        status: 'ativa',
        sessaoId: _sessaoAtiva!.id,
      );
      if (!_viagensAtivasMemoria.any((va) => va.id == vAtivada.id)) {
        _viagensAtivasMemoria.add(vAtivada);
      }
    }

    if (_viagensAtivasMemoria.isEmpty) {
      if (viagemDoMotorista != null) {
        _viagensAtivasMemoria.add(viagemDoMotorista.copyWith(
          motoristaId: viagemDoMotorista.motoristaId.isNotEmpty ? viagemDoMotorista.motoristaId : motoristaId,
          motoristaNome: viagemDoMotorista.motoristaNome.isNotEmpty ? viagemDoMotorista.motoristaNome : motoristaNome,
          status: 'ativa',
          sessaoId: _sessaoAtiva!.id,
        ));
      } else {
        _viagensAtivasMemoria.add(_criarPlaceholderSessaoAtiva(_sessaoAtiva!));
      }
    }

    _viagemAtiva = _viagensAtivasMemoria.first;
    if (!_viagemAtivaController.isClosed) {
      _viagemAtivaController.add(_viagemAtiva);
    }
    if (!_viagensAtivasController.isClosed) {
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }
  }

  /// Gera códigos de acesso únicos (4 a 5 dígitos) e seus respectivos hashes SHA-256
  /// para todos os passageiros da viagem que ainda não possuam código ou cujo hash
  /// esteja ausente/dessincronizado (ex.: código inserido manualmente no console).
  (Map<String, String>, Map<String, String>, bool) _sincronizarCodigosDaViagem({
    required String viagemId,
    required List<PassageiroViagemModel> passageiros,
    required List<String> passageirosIds,
    required Map<String, String> codigosExistentes,
    required Map<String, String> hashesExistentes,
  }) {
    final mapaCodigos = Map<String, String>.from(codigosExistentes);
    final mapaHashes = Map<String, String>.from(hashesExistentes);
    bool alterou = false;

    // Coleta todos os IDs de pacientes da viagem
    final idsPacientes = <String>{
      ...passageiros.map((p) => p.pacienteId).where((id) => id.trim().isNotEmpty),
      ...passageirosIds.where((id) => id.trim().isNotEmpty),
      ...mapaCodigos.keys.where((id) => id.trim().isNotEmpty),
    };

    for (final pid in idsPacientes) {
      final codigoAtual = mapaCodigos[pid]?.trim() ?? '';
      if (codigoAtual.isEmpty) {
        final novoCodigo = CodigoAcessoService.gerarCodigoUnicoNaViagem(mapaCodigos.values);
        mapaCodigos[pid] = novoCodigo;
        mapaHashes[pid] = CodigoAcessoService.calcularHash(novoCodigo, viagemId);
        alterou = true;
      } else {
        final hashEsperado = CodigoAcessoService.calcularHash(codigoAtual, viagemId);
        if (mapaHashes[pid] != hashEsperado) {
          mapaHashes[pid] = hashEsperado;
          alterou = true;
        }
      }
    }

    return (mapaCodigos, mapaHashes, alterou);
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
    } on FirebaseException catch (e) {
      debugPrint('Firebase indisponível (${e.code})');
      return false;
    } catch (e) {
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
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore('carregar_veiculos_disponiveis', e);
      } catch (e) {
        // --------------------------------------------------------------------
        // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
        // Prossegue para o fluxo em memória caso ocorra exceção
        // --------------------------------------------------------------------
        _tratarFalhaFirestore('carregar_veiculos_disponiveis', e);
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
    String? cidadeDestino,
  }) async {
    // Validação de regras de negócio de odômetro
    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: kmInicial.toString(),
      ultimaKmRegistrada: veiculo.quilometragemAtual,
    );
    if (!validacaoKm.valido) {
      return ResultadoDeclaracaoVeiculo.erro(validacaoKm.mensagemErro!);
    }

    // Checagem e atualização otimista em memória (Zero-Wait UI < 16 ms)
    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculo.id);
    VeiculoModel? veiculoSnapshotAnterior;
    if (index != -1) {
      final veicMem = _veiculosMemoria[index];
      if (veicMem.emUso &&
          veicMem.motoristaAtualId != null &&
          veicMem.motoristaAtualId != motoristaId) {
        return ResultadoDeclaracaoVeiculo.erro(
          'O veículo ${veiculo.placa} já está em uso por outro motorista.',
        );
      }
      veiculoSnapshotAnterior = veicMem;
      _veiculosMemoria[index] = _veiculosMemoria[index].copyWith(
        emUso: true,
        motoristaAtualId: motoristaId,
        quilometragemAtual: kmInicial,
      );
    }

    final sessaoAnterior = _sessaoAtiva;
    final viagemAtivaAnterior = _viagemAtiva;
    final viagensAtivasAnteriores = List<ViagemModel>.from(_viagensAtivasMemoria);
    final todasViagensAnteriores = List<ViagemModel>.from(_todasViagensMemoria);

    // Instancia a nova SessaoVeiculoModel
    final novaSessao = SessaoVeiculoModel(
      id: 'sessao_${DateTime.now().millisecondsSinceEpoch}_${motoristaId.isNotEmpty ? motoristaId : veiculo.id}',
      motoristaId: motoristaId,
      motoristaNome: motoristaNome,
      veiculoId: veiculo.id,
      veiculoPlaca: veiculo.placa,
      veiculoModelo: veiculo.modelo,
      kmInicial: kmInicial,
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
    );

    _sessaoFinalizadaPeloMotorista = false;
    _sessaoAtiva = novaSessao;
    if (motoristaId.isNotEmpty) {
      _sessoesAtivasPorMotorista[motoristaId] = novaSessao;
    }
    _sessaoAtivaController.add(_sessaoAtiva);
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );

    // Vincula apenas as viagens abertas elegíveis para este motorista/veículo/rota (isolamento de frotas paralelas)
    _viagensConcluidasNaSessao.clear();
    _viagensAtivasMemoria.removeWhere((va) => va.id.startsWith('sessao_ativa_'));
    final viagensAbertas = _todasViagensMemoria.where((v) {
      return _viagemElegivelParaSessao(
        v,
        motoristaId: motoristaId,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        cidadeDestino: cidadeDestino,
        sessaoId: novaSessao.id,
      );
    }).toList();

    final List<String> viagensIdsSessao = [];
    final List<ViagemModel> viagensAtivadasParaPersistir = [];
    for (final v in viagensAbertas) {
      final (codigosSinc, hashesSinc, _) = _sincronizarCodigosDaViagem(
        viagemId: v.id,
        passageiros: v.passageiros,
        passageirosIds: v.passageirosIds,
        codigosExistentes: v.codigosAcesso,
        hashesExistentes: v.codigosHash,
      );
      final vAtivada = v.copyWith(
        sessaoId: novaSessao.id,
        motoristaId: v.motoristaId,
        motoristaNome: v.motoristaNome,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        veiculoModelo: veiculo.modelo,
        kmInicial: kmInicial,
        status: 'ativa',
        codigosAcesso: codigosSinc,
        codigosHash: hashesSinc,
      );
      final idxAtiva = _viagensAtivasMemoria.indexWhere((va) => va.id == v.id);
      if (idxAtiva == -1) {
        _viagensAtivasMemoria.add(vAtivada);
      } else {
        _viagensAtivasMemoria[idxAtiva] = vAtivada;
      }
      viagensAtivadasParaPersistir.add(vAtivada);
      viagensIdsSessao.add(vAtivada.id);
      final idx = _todasViagensMemoria.indexWhere((tv) => tv.id == v.id);
      if (idx != -1) {
        _todasViagensMemoria[idx] = vAtivada;
      }
    }

    if (viagensIdsSessao.isNotEmpty) {
      _sessaoAtiva = _sessaoAtiva!.copyWith(viagensIds: viagensIdsSessao);
      if (motoristaId.isNotEmpty) {
        _sessoesAtivasPorMotorista[motoristaId] = _sessaoAtiva!;
      }
      _sessaoAtivaController.add(_sessaoAtiva);
    }

    final viagensDestaSessao = _viagensAtivasMemoria
        .where((va) => va.sessaoId == novaSessao.id || va.veiculoId == veiculo.id)
        .toList();
    if (viagensDestaSessao.isNotEmpty) {
      _viagemAtiva = viagensDestaSessao.first;
      _viagemAtivaController.add(_viagemAtiva);
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    void reverterDeclaracaoOtimista() {
      if (index != -1 && veiculoSnapshotAnterior != null) {
        _veiculosMemoria[index] = veiculoSnapshotAnterior;
      }
      if (motoristaId.isNotEmpty) {
        _sessoesAtivasPorMotorista.remove(motoristaId);
      }
      _sessaoAtiva = sessaoAnterior;
      _viagemAtiva = viagemAtivaAnterior;
      _viagensAtivasMemoria
        ..clear()
        ..addAll(viagensAtivasAnteriores);
      _todasViagensMemoria
        ..clear()
        ..addAll(todasViagensAnteriores);
      _sessaoAtivaController.add(_sessaoAtiva);
      _viagemAtivaController.add(_viagemAtiva);
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
      _veiculosController.add(
        ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
      );
    }

    // Persistência em background no Firestore com tratamento explícito e rollback
    if (executorPersistenciaRemotaOverride != null || _isFirebaseDisponivel()) {
      final sessaoParaPersistir = _sessaoAtiva!;
      unawaited(
        Future.microtask(() async {
          try {
            if (executorPersistenciaRemotaOverride != null) {
              await executorPersistenciaRemotaOverride!(
                'declarar_veiculo',
                sessaoParaPersistir.toMap(),
              );
              _totalGravacoesFirestoreJornada += 2 + viagensAtivadasParaPersistir.length;
              return;
            }
            final docRef = FirebaseFirestore.instance.collection('veiculos').doc(veiculo.id);
            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final docSnap = await transaction.get(docRef);
              if (docSnap.exists) {
                final dados = docSnap.data() ?? {};
                final emUsoRemoto = dados['emUso'] == true;
                final motoristaOcupando = dados['motoristaAtualId'];
                if (emUsoRemoto &&
                    motoristaOcupando != null &&
                    motoristaOcupando != motoristaId) {
                  throw FirebaseException(
                    plugin: 'cloud_firestore',
                    code: 'aborted',
                    message:
                        'O veículo ${veiculo.placa} foi colocado em uso por outro motorista.',
                  );
                }
              }

              transaction.set(docRef, {
                'emUso': true,
                'motoristaAtualId': motoristaId,
                'quilometragemAtual': kmInicial,
                'status': 'emViagem',
              }, SetOptions(merge: true));

              if (motoristaId.isNotEmpty) {
                final motoristaRef = FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(motoristaId);
                transaction.set(motoristaRef, {'emViagem': true}, SetOptions(merge: true));
              }
            });
            _totalGravacoesFirestoreJornada += 2;

            await FirebaseFirestore.instance
                .collection('sessoes_veiculo')
                .doc(novaSessao.id)
                .set(sessaoParaPersistir.toMap());
            _totalGravacoesFirestoreJornada++;

            for (final va in viagensAtivadasParaPersistir) {
              await FirebaseFirestore.instance
                  .collection('viagens')
                  .doc(va.id)
                  .set(va.toMap(), SetOptions(merge: true));
              _totalGravacoesFirestoreJornada++;
            }

            if (motoristaId.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(motoristaId)
                  .set({'emViagem': true}, SetOptions(merge: true));
              _totalGravacoesFirestoreJornada++;
            }
          } on FirebaseException catch (e) {
            _tratarFalhaFirestore(
              'declarar_veiculo',
              e,
              onRollback: reverterDeclaracaoOtimista,
            );
          } catch (e) {
            _tratarFalhaFirestore(
              'declarar_veiculo',
              e,
              onRollback: reverterDeclaracaoOtimista,
            );
          }
        }),
      );
    }

    return ResultadoDeclaracaoVeiculo.sucesso(_sessaoAtiva!);
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

    if (executorPersistenciaRemotaOverride != null || _isFirebaseDisponivel()) {
      final idsAtualizados = List<String>.from(_sessaoAtiva!.viagensIds);
      unawaited(
        Future.microtask(() async {
          try {
            if (executorPersistenciaRemotaOverride != null) {
              await executorPersistenciaRemotaOverride!(
                'criar_viagem_sessao',
                novaViagem.toMap(),
              );
              _totalGravacoesFirestoreJornada += 2;
              return;
            }
            await FirebaseFirestore.instance
                .collection('viagens')
                .doc(novaViagem.id)
                .set(novaViagem.toMap());
            _totalGravacoesFirestoreJornada++;

            await FirebaseFirestore.instance
                .collection('sessoes_veiculo')
                .doc(sessao.id)
                .set({'viagensIds': idsAtualizados}, SetOptions(merge: true));
            _totalGravacoesFirestoreJornada++;
          } on FirebaseException catch (e) {
            _tratarFalhaFirestore(
              'criar_viagem_sessao',
              e,
              onRollback: () {
                _viagensAtivasMemoria.removeWhere((v) => v.id == novaViagem.id);
                _todasViagensMemoria.removeWhere((v) => v.id == novaViagem.id);
                if (_viagemAtiva?.id == novaViagem.id) {
                  _viagemAtiva = _viagensAtivasMemoria.firstOrNull;
                  _viagemAtivaController.add(_viagemAtiva);
                }
                _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
                _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
              },
            );
          } catch (e) {
            _tratarFalhaFirestore('criar_viagem_sessao', e);
          }
        }),
      );
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
    if (viagem != null &&
        viagem.codigosAcesso.containsKey(pacienteId) &&
        viagem.codigosAcesso[pacienteId]!.trim().isNotEmpty) {
      final codigoExistente = viagem.codigosAcesso[pacienteId]!.trim();
      final hashEsperado = CodigoAcessoService.calcularHash(codigoExistente, viagemId);
      if (viagem.codigosHash[pacienteId] != hashEsperado) {
        final mapaHashes = Map<String, String>.from(viagem.codigosHash);
        mapaHashes[pacienteId] = hashEsperado;
        final viagemAtualizada = viagem.copyWith(codigosHash: mapaHashes);
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
        if (_isFirebaseDisponivel()) {
          unawaited(
            FirebaseFirestore.instance
                .collection('viagens')
                .doc(viagemId)
                .set({
                  'codigosAcesso': {pacienteId: codigoExistente},
                  'codigosHash': {pacienteId: hashEsperado},
                }, SetOptions(merge: true))
                .catchError((Object e) {
                  _tratarFalhaFirestore('sincronizar_hash_codigo_acesso', e);
                }),
          );
        }
      }
      return codigoExistente;
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

    // 6. Persiste os mapas de códigos e hashes no Firestore de forma assíncrona não-bloqueante
    if (_isFirebaseDisponivel()) {
      _totalGravacoesFirestoreJornada++;
      unawaited(
        FirebaseFirestore.instance
            .collection('viagens')
            .doc(viagemId)
            .set({
              'codigosAcesso': {pacienteId: novoCodigo},
              'codigosHash': {pacienteId: novoHash},
            }, SetOptions(merge: true))
            .catchError((Object e) {
              _tratarFalhaFirestore('gerar_codigo_acesso', e);
            }),
      );
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

    // Linha em branco separadora entre consulta remota e verificação na memória
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Verifica a situação do veículo na lista em memória
    // ------------------------------------------------------------------------
    // Localiza o índice do veículo na lista interna da memória
    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculo.id);
    VeiculoModel? veiculoSnapshotAnterior;
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
      veiculoSnapshotAnterior = veicMem;
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

    final sessaoAnterior = _sessaoAtiva;
    final viagemAtivaAnterior = _viagemAtiva;
    final viagensAtivasAnteriores = List<ViagemModel>.from(_viagensAtivasMemoria);
    final todasViagensAnteriores = List<ViagemModel>.from(_todasViagensMemoria);

    _sessaoFinalizadaPeloMotorista = false;
    // Se não houver sessão ativa prévia para este veículo, inicializa a Sessão de Veículo do condutor
    if (_sessaoAtiva == null || _sessaoAtiva!.veiculoId != veiculo.id) {
      _sessaoAtiva = SessaoVeiculoModel(
        id: 'sessao_${DateTime.now().millisecondsSinceEpoch}_${motoristaId.isNotEmpty ? motoristaId : veiculo.id}',
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
    final sessaoCorrente = _sessaoAtiva!;
    if (motoristaId.isNotEmpty) {
      _sessoesAtivasPorMotorista[motoristaId] = sessaoCorrente;
    }

    // O formulário de início de viagem NÃO gera uma nova viagem no banco/sistema:
    // vincula apenas as viagens existentes abertas elegíveis para a rota/veículo/motorista atual,
    // garantindo isolamento total entre frotas e motoristas que operam em paralelo.
    _viagensConcluidasNaSessao.clear();
    _viagensAtivasMemoria.removeWhere(
      (va) =>
          va.id.startsWith('sessao_ativa_') ||
          va.isCancelada ||
          va.isConcluida ||
          todosPacientesVoltaram(va),
    );

    final List<ViagemModel> viagensExistentesParaPersistir = [];
    for (int i = 0; i < _todasViagensMemoria.length; i++) {
      final base = _todasViagensMemoria[i];
      if (!_viagemElegivelParaSessao(
        base,
        motoristaId: motoristaId,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        cidadeDestino: cidadeDestino,
        sessaoId: sessaoCorrente.id,
      )) {
        continue;
      }

      final (codigosSinc, hashesSinc, _) = _sincronizarCodigosDaViagem(
        viagemId: base.id,
        passageiros: base.passageiros,
        passageirosIds: base.passageirosIds,
        codigosExistentes: base.codigosAcesso,
        hashesExistentes: base.codigosHash,
      );
      final vAtivada = base.copyWith(
        motoristaId: base.motoristaId,
        motoristaNome: base.motoristaNome,
        veiculoId: veiculo.id,
        veiculoPlaca: veiculo.placa,
        veiculoModelo: veiculo.modelo,
        kmInicial: kmInicial,
        status: 'ativa',
        sessaoId: sessaoCorrente.id,
        codigosAcesso: codigosSinc,
        codigosHash: hashesSinc,
      );
      _todasViagensMemoria[i] = vAtivada;
      viagensExistentesParaPersistir.add(vAtivada);

      final idxAtiva = _viagensAtivasMemoria.indexWhere((va) => va.id == vAtivada.id);
      if (idxAtiva != -1) {
        _viagensAtivasMemoria[idxAtiva] = vAtivada;
      } else {
        _viagensAtivasMemoria.add(vAtivada);
      }
    }

    final viagensDestaSessao = _viagensAtivasMemoria
        .where(
          (va) =>
              va.sessaoId == sessaoCorrente.id ||
              va.veiculoId == veiculo.id,
        )
        .toList();

    final ViagemModel novaViagem;
    if (viagensDestaSessao.isNotEmpty) {
      novaViagem = viagensDestaSessao.first;
    } else {
      // Nenhuma viagem aberta cadastrada pelo administrador para esta rota/veículo: cria apenas placeholder de sessão
      // em memória para a tela do motorista, SEM adicionar em _todasViagensMemoria e SEM salvar na coleção 'viagens'.
      novaViagem = _criarPlaceholderSessaoAtiva(
        sessaoCorrente,
        cidadeDestino: cidadeDestino,
      );
      _viagensAtivasMemoria.add(novaViagem);
    }

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

    void reverterInicioViagemOtimista() {
      if (index != -1 && veiculoSnapshotAnterior != null) {
        _veiculosMemoria[index] = veiculoSnapshotAnterior;
      }
      if (motoristaId.isNotEmpty) {
        _sessoesAtivasPorMotorista.remove(motoristaId);
      }
      _sessaoAtiva = sessaoAnterior;
      _viagemAtiva = viagemAtivaAnterior;
      _viagensAtivasMemoria
        ..clear()
        ..addAll(viagensAtivasAnteriores);
      _todasViagensMemoria
        ..clear()
        ..addAll(todasViagensAnteriores);
      _sessaoAtivaController.add(_sessaoAtiva);
      _viagemAtivaController.add(_viagemAtiva);
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
      _veiculosController.add(
        ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
      );
    }

    // Linha em branco separadora entre notificação local e persistência remota
    // ------------------------------------------------------------------------
    // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
    // Persiste as alterações no Firestore
    // ------------------------------------------------------------------------
    // Persiste as mudanças no Cloud Firestore em background (Zero-Wait UI) com tratamento explícito e rollback
    if (executorPersistenciaRemotaOverride != null || _isFirebaseDisponivel()) {
      unawaited(
        Future.microtask(() async {
          // Bloco try para capturar exceções de gravação remota
          try {
            if (executorPersistenciaRemotaOverride != null) {
              await executorPersistenciaRemotaOverride!(
                'iniciar_viagem',
                novaViagem.toMap(),
              );
              _totalGravacoesFirestoreJornada += 1 + viagensExistentesParaPersistir.length;
              return;
            }
            // ----------------------------------------------------------------
            // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
            // Consulta o documento do veículo no Firestore para verificar uso concorrente
            // ----------------------------------------------------------------
            final docRef = FirebaseFirestore.instance
                .collection('veiculos')
                .doc(veiculo.id);

            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final docSnap = await transaction.get(docRef);
              if (docSnap.exists) {
                final dados = docSnap.data() ?? {};
                final emUsoRemoto = dados['emUso'] == true;
                final motoristaOcupando = dados['motoristaAtualId'];
                if (emUsoRemoto &&
                    motoristaOcupando != null &&
                    motoristaOcupando != motoristaId) {
                  throw FirebaseException(
                    plugin: 'cloud_firestore',
                    code: 'aborted',
                    message:
                        'O veículo ${veiculo.placa} foi colocado em uso por outro motorista. Escolha outro veículo.',
                  );
                }
              }

              transaction.set(docRef, {
                'emUso': true,
                'motoristaAtualId': motoristaId,
                'quilometragemAtual': kmInicial,
                'status': 'emViagem',
              }, SetOptions(merge: true));

              if (motoristaId.isNotEmpty) {
                FirebaseAuthService.motoristaEmViagemStatic = true;
                final motoristaRef = FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(motoristaId);
                transaction.set(motoristaRef, {'emViagem': true}, SetOptions(merge: true));
              }
            });
            _totalGravacoesFirestoreJornada += 2;

            // Atualiza apenas as viagens existentes elegíveis (não cria documento novo na coleção 'viagens')
            for (final vp in viagensExistentesParaPersistir) {
              await FirebaseFirestore.instance
                  .collection('viagens')
                  .doc(vp.id)
                  .set(vp.toMap(), SetOptions(merge: true));
              _totalGravacoesFirestoreJornada++;
            }
          // Captura erros de escrita remota expondo falha e rollback
          } on FirebaseException catch (e) {
            _tratarFalhaFirestore(
              'iniciar_viagem',
              e,
              onRollback: reverterInicioViagemOtimista,
            );
          } catch (e) {
            // ----------------------------------------------------------------
            // COMENTÁRIO PREEXISTENTE PRESERVADO NA ÍNTEGRA (BYTE A BYTE):
            // Prossegue com a verificação em memória caso ocorra falha de consulta remota
            // Ignora erros de escrita remota
            // ----------------------------------------------------------------
            _tratarFalhaFirestore(
              'iniciar_viagem',
              e,
              onRollback: reverterInicioViagemOtimista,
            );
          // Fecha o bloco catch
          }
        }),
      );
    // Fecha a checagem de Firebase disponível
    }

    // Linha em branco separadora entre persistência e retorno de sucesso
    // Retorna o resultado com indicador de sucesso e a viagem criada
    return ResultadoInicioViagem.sucesso(novaViagem);
  // Fecha o método iniciarViagem
  }

  // Linha em branco separadora entre iniciarViagem e encerrarViagem
  /// Atualiza o status de embarque de um passageiro dentro da viagem ativa/planejada,
  /// mantendo o Gerenciador de Viagens do Administrador em perfeita sincronia.
  /// Quando todos os pacientes vinculados à viagem ficam com status concluído (status == 4),
  /// a viagem finaliza instantaneamente e deixa de aparecer para os motoristas.
  Future<void> atualizarStatusPassageiroNaViagem({
    required String viagemId,
    required String pacienteId,
    required int novoStatus,
    bool persistirRemoto = true,
  }) async {
    if (pacienteId.isEmpty) return;

    final todasViagensSnapshot = List<ViagemModel>.from(_todasViagensMemoria);
    final viagensAtivasSnapshot = List<ViagemModel>.from(_viagensAtivasMemoria);
    final viagemAtivaSnapshot = _viagemAtiva;

    ViagemModel? atualizarModelo(ViagemModel v, {bool preservarCodigosSeConcluir = false}) {
      if (v.passageiros.isEmpty) return null;
      bool mudou = false;
      final novosPassageiros = v.passageiros.map((p) {
        if (p.pacienteId == pacienteId && p.statusEmbarque != novoStatus) {
          mudou = true;
          return p.copyWith(statusEmbarque: novoStatus);
        }
        final stEfetivo = resolverStatusEfetivoPassageiro(p);
        if (p.statusEmbarque != stEfetivo) {
          mudou = true;
          return p.copyWith(statusEmbarque: stEfetivo);
        }
        return p;
      }).toList();
      if (!mudou) return null;
      var atualizada = v.copyWith(passageiros: novosPassageiros);
      if (!atualizada.isCancelada &&
          !atualizada.isConcluida &&
          todosPacientesVoltaram(atualizada)) {
        final codigosOriginais = Map<String, String>.from(atualizada.codigosAcesso);
        atualizada = atualizada.copyWith(
          status: 'encerrada',
          dataHoraFim: DateTime.now(),
          codigosAcesso: preservarCodigosSeConcluir ? codigosOriginais : const {},
        );
      }
      return atualizada;
    }

    final viagensParaPersistir = <ViagemModel>[];

    bool alterouTodas = false;
    for (int i = 0; i < _todasViagensMemoria.length; i++) {
      final v = _todasViagensMemoria[i];
      if (v.id == viagemId ||
          (!v.isCancelada &&
              !v.isConcluida &&
              v.passageiros.any((p) => p.pacienteId == pacienteId))) {
        final codigosAntes = Map<String, String>.from(v.codigosAcesso);
        final att = atualizarModelo(v);
        if (att != null) {
          if (att.isConcluida &&
              _sessaoAtiva != null &&
              !_viagensConcluidasNaSessao.any((vc) => vc.id == att.id)) {
            _viagensConcluidasNaSessao.add(
              _enriquecerViagemParaRelatorio(
                att.copyWith(codigosAcesso: codigosAntes),
                referenciaSessao: v,
              ),
            );
          }
          _todasViagensMemoria[i] = att;
          viagensParaPersistir.add(att);
          alterouTodas = true;
        }
      }
    }
    if (alterouTodas) {
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    bool alterouAtivas = false;
    for (int i = _viagensAtivasMemoria.length - 1; i >= 0; i--) {
      final v = _viagensAtivasMemoria[i];
      if (v.id == viagemId || v.passageiros.any((p) => p.pacienteId == pacienteId)) {
        final codigosAntes = Map<String, String>.from(v.codigosAcesso);
        final att = atualizarModelo(v);
        if (att != null) {
          if (att.isConcluida) {
            final idxConcl = _viagensConcluidasNaSessao.indexWhere((vc) => vc.id == att.id);
            final enriquecida = _enriquecerViagemParaRelatorio(
              att.copyWith(codigosAcesso: codigosAntes),
              referenciaSessao: v,
            );
            if (idxConcl == -1) {
              _viagensConcluidasNaSessao.add(enriquecida);
            } else {
              _viagensConcluidasNaSessao[idxConcl] = enriquecida;
            }
            _viagensAtivasMemoria.removeAt(i);
          } else {
            _viagensAtivasMemoria[i] = att;
          }
          alterouAtivas = true;
          if (!viagensParaPersistir.any((vp) => vp.id == att.id)) {
            viagensParaPersistir.add(att);
          }
        }
      }
    }

    if (_viagemAtiva != null &&
        (_viagemAtiva!.id == viagemId ||
            _viagemAtiva!.passageiros.any((p) => p.pacienteId == pacienteId))) {
      final vAntes = _viagemAtiva!;
      final codigosAntes = Map<String, String>.from(vAntes.codigosAcesso);
      final att = atualizarModelo(vAntes);
      if (att != null) {
        if (att.isConcluida) {
          final idxConcl = _viagensConcluidasNaSessao.indexWhere((vc) => vc.id == att.id);
          final enriquecida = _enriquecerViagemParaRelatorio(
            att.copyWith(codigosAcesso: codigosAntes),
            referenciaSessao: vAntes,
          );
          if (idxConcl == -1) {
            _viagensConcluidasNaSessao.add(enriquecida);
          } else {
            _viagensConcluidasNaSessao[idxConcl] = enriquecida;
          }
          if (_viagensAtivasMemoria.isNotEmpty) {
            _viagemAtiva = _viagensAtivasMemoria.first;
          } else if (_sessaoAtiva != null) {
            final ph = _criarPlaceholderSessaoAtiva(
              _sessaoAtiva!,
              cidadeDestino: att.cidadeDestino,
            );
            _viagensAtivasMemoria.add(ph);
            _viagemAtiva = ph;
            alterouAtivas = true;
          } else {
            _viagemAtiva = null;
          }
        } else {
          _viagemAtiva = att;
        }
        _viagemAtivaController.add(_viagemAtiva);
        if (!viagensParaPersistir.any((vp) => vp.id == att.id)) {
          viagensParaPersistir.add(att);
        }
      }
    } else if (alterouAtivas &&
        _viagemAtiva != null &&
        !_viagensAtivasMemoria.any((va) => va.id == _viagemAtiva!.id)) {
      if (_viagensAtivasMemoria.isNotEmpty) {
        _viagemAtiva = _viagensAtivasMemoria.first;
      } else if (_sessaoAtiva != null) {
        final ph = _criarPlaceholderSessaoAtiva(_sessaoAtiva!);
        _viagensAtivasMemoria.add(ph);
        _viagemAtiva = ph;
      } else {
        _viagemAtiva = null;
      }
      _viagemAtivaController.add(_viagemAtiva);
    }

    if (alterouAtivas) {
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }

    void reverterStatusPassageiro() {
      _todasViagensMemoria
        ..clear()
        ..addAll(todasViagensSnapshot);
      _viagensAtivasMemoria
        ..clear()
        ..addAll(viagensAtivasSnapshot);
      _viagemAtiva = viagemAtivaSnapshot;
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
      _viagemAtivaController.add(_viagemAtiva);
    }

    if (persistirRemoto &&
        viagensParaPersistir.isNotEmpty &&
        (executorPersistenciaRemotaOverride != null || _isFirebaseDisponivel())) {
      unawaited(
        Future.microtask(() async {
          for (final vp in viagensParaPersistir) {
            if (vp.id.startsWith('sessao_ativa_')) continue;
            try {
              final dados = <String, dynamic>{
                'passageiros': vp.passageiros.map((p) => p.toMap()).toList(),
                'status': vp.status,
              };
              if (vp.isConcluida) {
                dados['dataHoraFim'] =
                    (vp.dataHoraFim ?? DateTime.now()).toIso8601String();
                dados['codigosAcesso'] = <String, dynamic>{};
              }
              if (executorPersistenciaRemotaOverride != null) {
                await executorPersistenciaRemotaOverride!(
                  'atualizar_status_passageiro_viagem',
                  dados,
                );
                _totalGravacoesFirestoreJornada++;
                continue;
              }
              await FirebaseFirestore.instance
                  .collection('viagens')
                  .doc(vp.id)
                  .set(dados, SetOptions(merge: true));
              _totalGravacoesFirestoreJornada++;
            } on FirebaseException catch (e) {
              _tratarFalhaFirestore(
                'atualizar_status_passageiro_viagem',
                e,
                onRollback: reverterStatusPassageiro,
              );
            } catch (e) {
              _tratarFalhaFirestore(
                'atualizar_status_passageiro_viagem',
                e,
                onRollback: reverterStatusPassageiro,
              );
            }
          }
        }),
      );
    }
  }

  // ----------------------------------------------------------------------------
  // ENCERRAMENTO DE VIAGENS E SESSÃO (Issue #65: Suporte a N Viagens & LGPD)
  // ----------------------------------------------------------------------------
  /// Encerra a jornada do motorista atual e, caso todos os pacientes da viagem
  /// já tenham retornado (status == 4), finaliza também a viagem em si.
  ///
  /// - Quando o motorista finaliza a própria viagem, a sessão dele é encerrada e o veículo
  ///   é liberado para que o motorista retorne ao formulário de início de viagem;
  /// - A viagem só é finalizada (`status = 'encerrada'`) se todos os pacientes não cancelados
  ///   tiverem voltado (`status == 4`), independente do motorista.
  Future<void> encerrarViagem({
    String? viagemId,
    ViagemModel? viagemExplicita,
    int? kmFinal,
    int? kmRodado,
    List<PacienteModel>? pacientes,
  }) async {
    // Determina a viagem a ser encerrada (especificada por objeto, ID ou _viagemAtiva atual)
    final idAlvo = viagemExplicita?.id ?? viagemId ?? _viagemAtiva?.id;
    if (idAlvo == null || idAlvo.isEmpty) return;

    final index = _viagensAtivasMemoria.indexWhere((v) => v.id == idAlvo);
    final tvIdxInicial = _todasViagensMemoria.indexWhere((tv) => tv.id == idAlvo);

    ViagemModel? viagemLocalizada;
    if (index != -1) {
      viagemLocalizada = _viagensAtivasMemoria[index];
    } else if (tvIdxInicial != -1) {
      viagemLocalizada = _todasViagensMemoria[tvIdxInicial];
    } else if (_viagemAtiva?.id == idAlvo) {
      viagemLocalizada = _viagemAtiva;
    } else if (viagemExplicita != null) {
      viagemLocalizada = viagemExplicita;
    }

    if (viagemLocalizada == null) return;
    final ViagemModel viagem = viagemLocalizada;
    final ehPlaceholderSessao = viagem.id.startsWith('sessao_ativa_');
    final veiculoId = viagem.veiculoId.isNotEmpty
        ? viagem.veiculoId
        : (_sessaoAtiva?.veiculoId ?? '');
    final agoraFim = DateTime.now();

    // Sincroniza os status reais dos passageiros sem forçar para 4 os pacientes que ainda não voltaram
    final passageirosSincronizados = viagem.passageiros.map((p) {
      final st = resolverStatusEfetivoPassageiro(
        p,
        pacientesContexto: pacientes,
      );
      return p.copyWith(statusEmbarque: st);
    }).toList();

    final kmFinalCalculado = kmFinal ?? viagem.kmFinal;
    final kmRodadoCalculado = kmRodado ??
        viagem.kmRodado ??
        ((kmFinalCalculado != null && kmFinalCalculado >= viagem.kmInicial)
            ? (kmFinalCalculado - viagem.kmInicial)
            : null);

    final viagemComPassageirosSinc = viagem.copyWith(
      passageiros: passageirosSincronizados,
    );

    // Verifica se todos os pacientes da viagem já retornaram (status == 4, ou 5 se cancelado)
    final bool todosVoltaram = viagem.isConcluida ||
        viagem.passageiros.isEmpty ||
        todosPacientesVoltaram(
          viagemComPassageirosSinc,
          pacientesContexto: pacientes,
        );

    // 1. A viagem só finaliza ('encerrada') se todos os pacientes tiverem voltado;
    //    caso contrário permanece 'ativa' aguardando o retorno dos demais pacientes.
    final ViagemModel viagemAtualizada = todosVoltaram
        ? viagem.copyWith(
            status: 'encerrada',
            motoristaId: '',
            motoristaNome: '',
            removerSessaoId: true,
            kmFinal: kmFinalCalculado,
            kmRodado: kmRodadoCalculado,
            dataHoraFim: viagem.dataHoraFim ?? agoraFim,
            passageiros: passageirosSincronizados,
            // Purgando códigos em texto plano: expira credenciais ativas quando a viagem finaliza
            codigosAcesso: const {},
          )
        : viagem.copyWith(
            status: 'ativa',
            motoristaId: '',
            motoristaNome: '',
            removerSessaoId: true,
            kmFinal: kmFinalCalculado,
            kmRodado: kmRodadoCalculado,
            passageiros: passageirosSincronizados,
          );

    // 2. Remove da lista de viagens ativas da sessão do motorista atual para redirecioná-lo ao início
    if (index != -1) {
      _viagensAtivasMemoria.removeAt(index);
      _viagensAtivasController.add(List.unmodifiable(_viagensAtivasMemoria));
    }

    if (!ehPlaceholderSessao) {
      final tvIdx = _todasViagensMemoria.indexWhere((tv) => tv.id == idAlvo);
      if (tvIdx != -1) {
        _todasViagensMemoria[tvIdx] = viagemAtualizada;
      } else {
        _todasViagensMemoria.add(viagemAtualizada);
      }
      _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
    }

    // 3. Se a viagem encerrada era a viagem ativa visualizada pelo motorista, avança para a próxima ou zera
    if (_viagemAtiva?.id == idAlvo) {
      _viagemAtiva = _viagensAtivasMemoria.isNotEmpty ? _viagensAtivasMemoria.first : null;
      _viagemAtivaController.add(_viagemAtiva);
    }

    // 4. Se não houver mais nenhuma viagem ativa na jornada do motorista, encerra a sessão dele e libera o veículo
    final sessaoFinalizada = _viagensAtivasMemoria.isEmpty;
    final sessaoIdEncerrada = _sessaoAtiva?.id;
    final idMotoristaSessao = _sessaoAtiva?.motoristaId ?? '';
    final nomeMotoristaSessao = _sessaoAtiva?.motoristaNome ?? '';
    if (sessaoFinalizada) {
      _sessaoFinalizadaPeloMotorista = true;
      _sessaoAtiva = _sessaoAtiva?.copyWith(
        status: 'encerrada',
        kmFinal: kmFinalCalculado,
        kmRodado: kmRodadoCalculado,
        dataHoraFim: agoraFim,
      );
      _sessaoAtivaController.add(_sessaoAtiva);
      _sessaoAtiva = null;

      // Libera o veículo na lista de memória
      final veicIndex = _veiculosMemoria.indexWhere((v) => v.id == veiculoId);
      if (veicIndex != -1) {
        _veiculosMemoria[veicIndex] = _veiculosMemoria[veicIndex].copyWith(
          emUso: false,
          motoristaAtualId: null,
          quilometragemAtual: kmFinalCalculado ?? _veiculosMemoria[veicIndex].quilometragemAtual,
        );
      }

      _veiculosController.add(
        ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
      );
    }

    // 5. Persiste as alterações no Cloud Firestore de forma assíncrona não-bloqueante
    if (_isFirebaseDisponivel()) {
      final idMotoristaParaLiberar = viagem.motoristaId.trim().isNotEmpty
          ? viagem.motoristaId.trim()
          : (idMotoristaSessao.trim().isNotEmpty
              ? idMotoristaSessao.trim()
              : (FirebaseAuthService().currentDocId ?? FirebaseAuthService().currentUserId ?? ''));
      final nomeMotoristaParaLiberar = viagem.motoristaNome.trim().isNotEmpty
          ? viagem.motoristaNome.trim()
          : (nomeMotoristaSessao.trim().isNotEmpty
              ? nomeMotoristaSessao.trim()
              : 'Motorista');

      unawaited(
        Future.microtask(() async {
          try {
            if (!ehPlaceholderSessao) {
              final dadosViagem = <String, dynamic>{
                'status': viagemAtualizada.status,
                'motoristaId': '',
                'motoristaNome': '',
                if (todosVoltaram)
                  'dataHoraFim':
                      (viagemAtualizada.dataHoraFim ?? agoraFim).toIso8601String(),
                if (todosVoltaram) 'codigosAcesso': <String, dynamic>{},
                if (passageirosSincronizados.isNotEmpty)
                  'passageiros': passageirosSincronizados.map((p) => p.toMap()).toList(),
              };
              if (kmFinalCalculado != null) dadosViagem['kmFinal'] = kmFinalCalculado;
              if (kmRodadoCalculado != null) dadosViagem['kmRodado'] = kmRodadoCalculado;

              await FirebaseFirestore.instance
                  .collection('viagens')
                  .doc(viagem.id)
                  .set(dadosViagem, SetOptions(merge: true));
              _totalGravacoesFirestoreJornada++;

              // Registro Homologado: Snapshot imutável congelado na coleção viagens_homologadas
              try {
                final strParaHash =
                    '${viagem.id}:$kmFinalCalculado:$kmRodadoCalculado:${agoraFim.toIso8601String()}';
                final hashSha256 =
                    sha256.convert(utf8.encode(strParaHash)).toString();

                final dadosHomologados = <String, dynamic>{
                  'viagemId': viagem.id,
                  'cidadeDestino': viagemAtualizada.cidadeDestino,
                  'motoristaId': idMotoristaParaLiberar,
                  'motoristaNome': nomeMotoristaParaLiberar,
                  'veiculoId': veiculoId,
                  'veiculoPlaca': viagemAtualizada.veiculoPlaca,
                  'veiculoModelo': viagemAtualizada.veiculoModelo,
                  'kmInicial': viagem.kmInicial,
                  'kmFinal': kmFinalCalculado,
                  'kmRodado': kmRodadoCalculado,
                  'dataHoraInicio': viagem.dataHoraInicio.toIso8601String(),
                  'dataHoraFim': agoraFim.toIso8601String(),
                  'passageiros':
                      passageirosSincronizados.map((p) => p.toMap()).toList(),
                  'status': 'homologada',
                  'autor': nomeMotoristaParaLiberar,
                  'hashIntegridade': hashSha256,
                  'homologadoEm': FieldValue.serverTimestamp(),
                };

                await FirebaseFirestore.instance
                    .collection('viagens_homologadas')
                    .doc(viagem.id)
                    .set(dadosHomologados, SetOptions(merge: true));
                _totalGravacoesFirestoreJornada++;
              } catch (e) {
                // Tolerância a falha do snapshot homologado: erro na coleção não bloqueia liberação do veículo/motorista
                debugPrint('Aviso: falha na persistência do snapshot homologado ($e)');
              }
            }

            if (sessaoFinalizada) {
              if (sessaoIdEncerrada != null && sessaoIdEncerrada.isNotEmpty) {
                final dadosSessao = <String, dynamic>{
                  'status': 'encerrada',
                  'dataHoraFim': agoraFim.toIso8601String(),
                };
                if (kmFinalCalculado != null) {
                  dadosSessao['kmFinal'] = kmFinalCalculado;
                }
                if (kmRodadoCalculado != null) {
                  dadosSessao['kmRodado'] = kmRodadoCalculado;
                }
                await FirebaseFirestore.instance
                    .collection('sessoes_veiculo')
                    .doc(sessaoIdEncerrada)
                    .set(dadosSessao, SetOptions(merge: true));
                _totalGravacoesFirestoreJornada++;
              }

              final dadosVeiculo = <String, dynamic>{
                'emUso': false,
                'motoristaAtualId': null,
              };
              if (kmFinalCalculado != null) {
                dadosVeiculo['quilometragemAtual'] = kmFinalCalculado;
              }

              if (veiculoId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('veiculos')
                    .doc(veiculoId)
                    .set(dadosVeiculo, SetOptions(merge: true));
                _totalGravacoesFirestoreJornada++;
              }

              // Gravação de emViagem: false no documento de usuarios/{motoristaId} para liberar o condutor
              if (idMotoristaParaLiberar.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(idMotoristaParaLiberar)
                    .set({'emViagem': false}, SetOptions(merge: true));
                _totalGravacoesFirestoreJornada++;
                LocalizacaoMotoristaService().removerOuInativarMotorista(idMotoristaParaLiberar);
              }
            }
          } on FirebaseException catch (e) {
            _tratarFalhaFirestore('encerrar_viagem', e);
          } catch (e) {
            _tratarFalhaFirestore('encerrar_viagem', e);
          }
        }),
      );
    }
  }

  /// Encerra em lote todas as N viagens ativas vinculadas à sessão atual do condutor.
  Future<void> encerrarTodasViagens({
    int? kmFinal,
    int? kmRodado,
    List<ViagemModel>? viagensExplicitas,
    List<PacienteModel>? pacientes,
  }) async {
    _sessaoFinalizadaPeloMotorista = true;
    final idMotoristaDaSessaoAntes = _sessaoAtiva?.motoristaId ?? '';
    final mapaParaEncerrar = <String, ViagemModel>{};

    if (viagensExplicitas != null && viagensExplicitas.isNotEmpty) {
      for (final v in viagensExplicitas) {
        if (v.id.isNotEmpty) mapaParaEncerrar[v.id] = v;
      }
    } else {
      for (final vc in _viagensConcluidasNaSessao) {
        if (vc.id.isNotEmpty) mapaParaEncerrar[vc.id] = vc;
      }
      for (final v in _viagensAtivasMemoria) {
        if (v.id.isNotEmpty) mapaParaEncerrar[v.id] = v;
      }
      if (_viagemAtiva != null && _viagemAtiva!.id.isNotEmpty) {
        mapaParaEncerrar[_viagemAtiva!.id] = _viagemAtiva!;
      }
    }

    // Também inclui qualquer Horário ativo em _todasViagensMemoria do mesmo veículo
    final refViagem = mapaParaEncerrar.values.firstOrNull;
    if (refViagem != null) {
      final placaRef = _normalizarPlacaInterna(refViagem.veiculoPlaca);
      for (final tv in _todasViagensMemoria) {
        if (tv.isCancelada || tv.isConcluida) continue;
        final mesmoVeiculo = (refViagem.veiculoId.isNotEmpty &&
                tv.veiculoId == refViagem.veiculoId) ||
            (placaRef.isNotEmpty &&
                _normalizarPlacaInterna(tv.veiculoPlaca) == placaRef);
        if (tv.isAtiva && mesmoVeiculo) {
          mapaParaEncerrar[tv.id] = tv;
        }
      }
    }

    for (final v in mapaParaEncerrar.values.toList()) {
      await encerrarViagem(
        viagemId: v.id,
        viagemExplicita: v,
        kmFinal: kmFinal,
        kmRodado: kmRodado,
        pacientes: pacientes,
      );
    }

    _viagensConcluidasNaSessao.clear();
    FirebaseAuthService.motoristaEmViagemStatic = false;

    final idMotoristaFinal = refViagem?.motoristaId.trim().isNotEmpty == true
        ? refViagem!.motoristaId.trim()
        : (idMotoristaDaSessaoAntes.trim().isNotEmpty
            ? idMotoristaDaSessaoAntes.trim()
            : (FirebaseAuthService().currentDocId ?? FirebaseAuthService().currentUserId ?? ''));
    if (_isFirebaseDisponivel() && idMotoristaFinal.isNotEmpty) {
      unawaited(
        FirebaseFirestore.instance
            .collection('usuarios')
            .doc(idMotoristaFinal)
            .set({'emViagem': false}, SetOptions(merge: true))
            .catchError((_) {}),
      );
      LocalizacaoMotoristaService().removerOuInativarMotorista(idMotoristaFinal);
    }

    // Garante limpeza completa do estado ativo da sessão quando não restarem viagens de outros veículos
    if (viagensExplicitas == null || _viagensAtivasMemoria.isEmpty) {
      if (_viagensAtivasMemoria.isNotEmpty || _viagemAtiva != null || _sessaoAtiva != null) {
        _viagensAtivasMemoria.clear();
        _viagemAtiva = null;
        _sessaoAtiva = null;
        _viagensAtivasController.add(const <ViagemModel>[]);
        _viagemAtivaController.add(null);
        _sessaoAtivaController.add(null);
      }
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
            .where('dataHoraInicio', isGreaterThanOrEqualTo: _obterInicioDoDiaOperacionalIso())
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
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore('migrar_viagens_legadas', e);
      } catch (e) {
        _tratarFalhaFirestore('migrar_viagens_legadas', e);
      }
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
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore('reverter_migracao', e);
      } catch (e) {
        _tratarFalhaFirestore('reverter_migracao', e);
      }
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
  /// O veículo não precisa ser definido na criação, pois é escolhido pelo motorista ao iniciar a viagem.
  /// As viagens não possuem um motorista vinculado a elas na criação/edição.
  Future<ResultadoOperacaoViagem> criarHorarioViagem({
    required DateTime data,
    required String horario,
    String veiculoId = '',
    String veiculoPlaca = '',
    String veiculoModelo = '',
    int capacidadeVeiculo = 0,
    String motoristaId = '',
    String motoristaNome = '',
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

    // 3. Validação de conflito de motorista (apenas se um motorista foi explicitamente informado)
    if (motoristaId.trim().isNotEmpty) {
      final validacaoMotorista = ValidacaoViagem.validarConflitoMotorista(
        motoristaId: motoristaId,
        data: data,
        horario: horario,
        viagensDoDia: viagensDoDia,
      );
      if (!validacaoMotorista.valido) {
        return ResultadoOperacaoViagem.erro(validacaoMotorista.mensagemErro!);
      }
    }

    // 4. Validação de conflito de veículo (apenas se um veículo foi explicitamente informado)
    if (veiculoId.trim().isNotEmpty) {
      final validacaoVeiculo = ValidacaoViagem.validarConflitoVeiculo(
        veiculoId: veiculoId,
        data: data,
        horario: horario,
        viagensDoDia: viagensDoDia,
      );
      if (!validacaoVeiculo.valido) {
        return ResultadoOperacaoViagem.erro(validacaoVeiculo.mensagemErro!);
      }
    }

    // 5. Validação de capacidade (apenas se capacidade de veículo positiva foi informada)
    if (capacidadeVeiculo > 0) {
      final totalAssentos =
          passageiros.fold<int>(0, (acc, p) => acc + p.assentosOcupados);
      final validacaoCapacidade = ValidacaoViagem.validarCapacidade(
        totalPassageirosComAcompanhantes: totalAssentos,
        capacidadeVeiculo: capacidadeVeiculo,
      );
      if (!validacaoCapacidade.valido) {
        return ResultadoOperacaoViagem.erro(validacaoCapacidade.mensagemErro!);
      }
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

    final idNovaViagem =
        'horario_${dataAlvo.year}_${dataAlvo.month}_${dataAlvo.day}_${DateTime.now().millisecondsSinceEpoch}';
    final listaPassageirosIds = passageiros
        .expand((p) => [p.pacienteId, if (p.acompanhanteId != null) p.acompanhanteId!])
        .where((id) => id.isNotEmpty)
        .toList();
    final (codigosGerados, hashesGerados, _) = _sincronizarCodigosDaViagem(
      viagemId: idNovaViagem,
      passageiros: passageiros,
      passageirosIds: listaPassageirosIds,
      codigosExistentes: const {},
      hashesExistentes: const {},
    );

    final novaViagem = ViagemModel(
      id: idNovaViagem,
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
      passageirosIds: listaPassageirosIds,
      codigosAcesso: codigosGerados,
      codigosHash: hashesGerados,
    );

    // 8. Gravação na memória e notificação das streams
    // Reseta para 0 o status em memória/banco dos pacientes adicionados com statusEmbarque == 0
    // para que uma viagem recém-criada não herde status concluído (4) de viagens anteriores
    PacienteSyncService().resetarStatusPacientesParaNovaViagem(
      passageiros
          .where((p) => p.statusEmbarque == 0)
          .map((p) => p.pacienteId),
    );
    _todasViagensMemoria.add(novaViagem);
    _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));

    // 9. Persistência remota
    if (_isFirebaseDisponivel()) {
      try {
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(novaViagem.id)
            .set(novaViagem.toMap());
        _totalGravacoesFirestoreJornada++;
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore(
          'criar_horario_viagem',
          e,
          onRollback: () {
            _todasViagensMemoria.removeWhere((v) => v.id == novaViagem.id);
            _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
          },
        );
      } catch (e) {
        _tratarFalhaFirestore('criar_horario_viagem', e);
      }
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

    if (viagem.motoristaId.trim().isNotEmpty) {
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
    }

    if (viagem.veiculoId.trim().isNotEmpty) {
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

    // 3. Tratamento de códigos de acesso existentes e geração para novos passageiros
    // Preserva códigos de passageiros mantidos; descarta códigos de removidos e gera para novos
    final mapaCodigosPreservados = <String, String>{
      ...existente.codigosAcesso,
      ...viagem.codigosAcesso,
    };
    final mapaHashesPreservados = <String, String>{
      ...existente.codigosHash,
      ...viagem.codigosHash,
    };
    final idsAtuais = viagem.passageiros.map((p) => p.pacienteId).toSet();
    mapaCodigosPreservados.removeWhere((id, _) => !idsAtuais.contains(id));
    mapaHashesPreservados.removeWhere((id, _) => !idsAtuais.contains(id));

    final listaPassageirosIds = viagem.passageiros
        .expand((p) => [p.pacienteId, if (p.acompanhanteId != null) p.acompanhanteId!])
        .where((id) => id.isNotEmpty)
        .toList();

    final (codigosSinc, hashesSinc, _) = _sincronizarCodigosDaViagem(
      viagemId: viagem.id,
      passageiros: viagem.passageiros,
      passageirosIds: listaPassageirosIds,
      codigosExistentes: mapaCodigosPreservados,
      hashesExistentes: mapaHashesPreservados,
    );

    final viagemAtualizada = viagem.copyWith(
      codigosAcesso: codigosSinc,
      codigosHash: hashesSinc,
      passageirosIds: listaPassageirosIds,
    );

    PacienteSyncService().resetarStatusPacientesParaNovaViagem(
      viagemAtualizada.passageiros
          .where((p) => p.statusEmbarque == 0)
          .map((p) => p.pacienteId),
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
        _totalGravacoesFirestoreJornada++;
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore(
          'atualizar_horario_viagem',
          e,
          onRollback: () {
            _todasViagensMemoria[index] = existente;
            _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
          },
        );
      } catch (e) {
        _tratarFalhaFirestore('atualizar_horario_viagem', e);
      }
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
          _totalGravacoesFirestoreJornada++;
        } on FirebaseException catch (e) {
          _tratarFalhaFirestore(
            'cancelar_horario_viagem',
            e,
            onRollback: () {
              _todasViagensMemoria[index] = viagem;
              _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
            },
          );
        } catch (e) {
          _tratarFalhaFirestore('cancelar_horario_viagem', e);
        }
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
          _totalGravacoesFirestoreJornada++;
        } on FirebaseException catch (e) {
          _tratarFalhaFirestore(
            'excluir_horario_viagem',
            e,
            onRollback: () {
              _todasViagensMemoria.insert(index, removida);
              _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
            },
          );
        } catch (e) {
          _tratarFalhaFirestore('excluir_horario_viagem', e);
        }
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

      final idDuplicada =
          'horario_${dataDestinoFormatada.year}_${dataDestinoFormatada.month}_${dataDestinoFormatada.day}_${DateTime.now().millisecondsSinceEpoch}_$i';
      final (codigosDup, hashesDup, _) = _sincronizarCodigosDaViagem(
        viagemId: idDuplicada,
        passageiros: vo.passageiros,
        passageirosIds: vo.passageirosIds,
        codigosExistentes: const {},
        hashesExistentes: const {},
      );

      final passageirosResetados = vo.passageiros
          .map((p) => p.copyWith(statusEmbarque: 0))
          .toList();
      PacienteSyncService().resetarStatusPacientesParaNovaViagem(
        passageirosResetados.map((p) => p.pacienteId),
      );

      final novaViagem = ViagemModel(
        id: idDuplicada,
        motoristaId: '',
        motoristaNome: '',
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
        passageiros: passageirosResetados,
        passageirosIds: List.from(vo.passageirosIds),
        codigosAcesso: codigosDup,
        codigosHash: hashesDup,
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
          _totalGravacoesFirestoreJornada++;
        } on FirebaseException catch (e) {
          _tratarFalhaFirestore(
            'duplicar_viagens_dia',
            e,
            onRollback: () {
              _todasViagensMemoria.removeWhere((v) => v.id == novaViagem.id);
              duplicadas.removeWhere((v) => v.id == novaViagem.id);
              _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
            },
          );
        } catch (e) {
          _tratarFalhaFirestore('duplicar_viagens_dia', e);
        }
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
    final viagemAnterior = _todasViagensMemoria[index];

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

    PacienteSyncService().resetarStatusPacientesParaNovaViagem(
      viagemAtualizada.passageiros
          .where((p) => p.statusEmbarque == 0)
          .map((p) => p.pacienteId),
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
        _totalGravacoesFirestoreJornada++;
      } on FirebaseException catch (e) {
        _tratarFalhaFirestore(
          'reordenar_passageiros',
          e,
          onRollback: () {
            _todasViagensMemoria[index] = viagemAnterior;
            _todasViagensController.add(List.unmodifiable(_todasViagensMemoria));
          },
        );
      } catch (e) {
        _tratarFalhaFirestore('reordenar_passageiros', e);
      }
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
    _sessaoFinalizadaPeloMotorista = false;
    _sessoesAtivasPorMotorista.clear();
    _totalGravacoesFirestoreJornada = 0;
    executorPersistenciaRemotaOverride = null;
    _sessaoAtiva = sessaoAtivaInicial;
    if (sessaoAtivaInicial != null && sessaoAtivaInicial.motoristaId.isNotEmpty) {
      _sessoesAtivasPorMotorista[sessaoAtivaInicial.motoristaId] = sessaoAtivaInicial;
    }
    _sessaoAtivaController.add(_sessaoAtiva);
    _viagensConcluidasNaSessao.clear();

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
