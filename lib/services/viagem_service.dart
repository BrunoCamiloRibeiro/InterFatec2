// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/viagem_service.dart
// Camada: Domínio / Serviços de Dados e Infraestrutura (Services)
//
// O QUE ESTE ARQUIVO FAZ:
// Centraliza a gestão de dados operacionais e concorrência das viagens do
// transporte municipal (TFD). Controla o ciclo de vida da viagem (início,
// acompanhamento e encerramento), provê streams reativas broadcast para lista de
// veículos disponíveis e viagem ativa, realiza sincronização híbrida com o
// Cloud Firestore (coleções 'veiculos', 'viagens' e 'usuarios') com fallback para
// memória local, previne reserva simultânea do mesmo veículo por motoristas
// distintos e disponibiliza utilitários de injeção de estado para testes.
//
// PARA QUE SERVE NO PROJETO:
// É o serviço de backend da tela do motorista, responsável por garantir que as
// transações de início e finalização de percurso ocorram de forma consistente,
// sincronizando odômetro, placas em uso e status operacional em tempo real.
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (escuta da viagem ativa e encerramento de percurso)
// - lib/components/formulario_inicio_viagem.dart (carregamento de frota e envio da viagem)
// - test/formulario_inicio_viagem_test.dart (testes unitários e de integração de viagens)
//
// DE ONDE RECEBE DADOS:
// - Cloud Firestore (documentos das coleções 'veiculos', 'viagens' e 'usuarios')
// - Dados pré-populados na memória interna (_veiculosMemoria)
// - Entradas do usuário repassadas via formulários de início e encerramento
//
// O QUE EXPORTA / EXPÕE:
// - class ResultadoInicioViagem: resultado de tentativa de início com sucesso, viagem ou mensagem de erro
// - class ViagemService: singleton de gerenciamento com:
//   * ViagemModel? get viagemAtiva
//   * Stream<ViagemModel?> get viagemAtivaStream
//   * Stream<List<VeiculoModel>> get veiculosStream
//   * Stream<List<VeiculoModel>> carregarVeiculosDisponiveis({String? motoristaId})
//   * Future<ResultadoInicioViagem> iniciarViagem(...)
//   * Future<void> encerrarViagem({int? kmFinal, int? kmRodado})
//   * void resetParaTestes(...)
//
// ORIGEM HISTÓRICA:
// Criado no commit aa02e80 pela equipe do projeto na issue #17.
// Não provém de scaffold ou código gerado por ferramentas.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'dart:async', 'package:cloud_firestore/cloud_firestore.dart' e
// 'package:firebase_core/firebase_core.dart'.
// Efeitos colaterais: Escrita e leitura assíncrona no Cloud Firestore, emissão de
// eventos em StreamControllers broadcast e mutação do estado singleton em memória.
// ============================================================================

// Importa a biblioteca assíncrona do Dart para manipulação de Streams e StreamControllers
import 'dart:async';

// Linha em branco separadora entre imports do core e pacotes externos
// Importa o cliente Cloud Firestore para gravação e leitura de documentos remotos
import 'package:cloud_firestore/cloud_firestore.dart';
// Importa o cliente Firebase Core para checagem de inicialização da plataforma Firebase
import 'package:firebase_core/firebase_core.dart';

// Linha em branco separadora entre pacotes externos e modelos internos
// Importa o modelo de dados de veículos
import '../models/veiculo_model.dart';
// Importa o modelo de dados de viagens
import '../models/viagem_model.dart';
// Importa a classe de validações de regras de negócio de viagem
import 'validacao_viagem.dart';

// Linha em branco separadora entre imports e ResultadoInicioViagem
// Comentário original do autor mantido byte a byte:
// Armazena o resultado da tentativa de iniciar uma viagem
// Classe que encapsula o desfecho da tentativa de abertura de viagem
class ResultadoInicioViagem {
  // Comentário original do autor mantido byte a byte:
  // Indica se a inicialização da viagem ocorreu com sucesso
  // Atributo imutável do tipo bool indicando êxito da operação
  final bool sucesso;
  // Comentário original do autor mantido byte a byte:
  // Instância da viagem criada em caso de sucesso
  // Atributo opcional do tipo ViagemModel com a entidade criada
  final ViagemModel? viagem;
  // Comentário original do autor mantido byte a byte:
  // Mensagem descritiva do erro em caso de falha
  // Atributo opcional do tipo String contendo o texto amigável do erro
  final String? mensagemErro;

  // Linha em branco separadora entre atributos e construtor privado

  // Construtor constante privado para garantir instanciação controlada por factories
  const ResultadoInicioViagem._({
    // Parâmetro obrigatório para o indicador booleano de sucesso
    required this.sucesso,
    // Parâmetro opcional para a instância da viagem
    this.viagem,
    // Parâmetro opcional para a mensagem descritiva de erro
    this.mensagemErro,
  // Fecha a lista de parâmetros do construtor privado
  });

  // Linha em branco separadora entre construtor privado e factories
  // Comentário original do autor mantido byte a byte:
  // Retorna uma instância de ResultadoInicioViagem com sucesso e os dados da viagem
  // Factory que cria um resultado de inicialização bem-sucedida associando a viagem
  factory ResultadoInicioViagem.sucesso(ViagemModel viagem) =>
      // Instanciação privada com sucesso=true e os dados da viagem criada
      ResultadoInicioViagem._(sucesso: true, viagem: viagem);

  // Linha em branco separadora entre factories
  // Comentário original do autor mantido byte a byte:
  // Retorna uma instância de ResultadoInicioViagem com erro e a mensagem correspondente
  // Factory que cria um resultado de inicialização com erro e mensagem explicativa
  factory ResultadoInicioViagem.erro(String mensagem) =>
      // Instanciação privada com sucesso=false e a mensagem de erro
      ResultadoInicioViagem._(sucesso: false, mensagemErro: mensagem);
// Fecha a classe ResultadoInicioViagem
}

// Linha em branco separadora entre ResultadoInicioViagem e ViagemService
// Comentário original do autor mantido byte a byte:
// Gerencia a lista de veículos, streams de atualização e o ciclo de vida das viagens
// Declaração da classe ViagemService estruturada como Singleton
class ViagemService {
  // Comentário original do autor mantido byte a byte:
  // Instância única da classe ViagemService
  // Campo estático privado contendo a referência singleton da classe
  static final ViagemService _instance = ViagemService._interno();

  // Linha em branco separadora entre o campo estático e a factory

  // Comentário original do autor mantido byte a byte:
  // Construtor fábrica que retorna a instância única
  // Factory singleton que devolve sempre a mesma instância compartilhada
  factory ViagemService() => _instance;

  // Linha em branco separadora entre a factory e o construtor privado

  // Comentário original do autor mantido byte a byte:
  // Construtor privado que executa a inicialização dos dados base
  // Construtor nomeado privado que dispara a carga dos veículos padrão
  ViagemService._interno() {
    // Executa a função interna de população de dados base
    _inicializarDadosBase();
  // Fecha o bloco do construtor interno
  }

  // Linha em branco separadora entre construtor e atributos de estado
  // Comentário original do autor mantido byte a byte:
  // Armazena a viagem ativa no momento
  // Propriedade privada que guarda em memória a viagem em andamento
  ViagemModel? _viagemAtiva;

  // Linha em branco separadora entre atributos de estado
  // Comentário original do autor mantido byte a byte:
  // Controlador de fluxo de dados para a lista de veículos
  // StreamController em broadcast para notificar múltiplos ouvintes da frota
  final StreamController<List<VeiculoModel>> _veiculosController =
      StreamController<List<VeiculoModel>>.broadcast();

  // Linha em branco separadora entre controladores
  // Comentário original do autor mantido byte a byte:
  // Controlador de fluxo de dados para a viagem ativa
  // StreamController em broadcast para notificar mudanças na viagem ativa
  final StreamController<ViagemModel?> _viagemAtivaController =
      StreamController<ViagemModel?>.broadcast();

  // Linha em branco separadora entre controladores e memória
  // Comentário original do autor mantido byte a byte:
  // Lista de veículos armazenada em memória
  // Lista mutável interna utilizada como fallback caso o Firestore não esteja ativo
  final List<VeiculoModel> _veiculosMemoria = [];

  // Linha em branco separadora entre lista e flag
  // Comentário original do autor mantido byte a byte:
  // Indicador de inicialização dos dados da lista em memória
  // Flag de controle para evitar repopulação duplicada da memória
  bool _inicializado = false;

  // Linha em branco separadora entre flags e getters públicos
  // Comentário original do autor mantido byte a byte:
  // Retorna a viagem ativa atual
  // Getter síncrono para leitura do estado atual da viagem
  ViagemModel? get viagemAtiva => _viagemAtiva;

  // Linha em branco separadora entre getters públicos
  // Comentário original do autor mantido byte a byte:
  // Retorna o fluxo de dados da viagem ativa
  // Getter da Stream para observação reativa de mudanças na viagem ativa
  Stream<ViagemModel?> get viagemAtivaStream => _viagemAtivaController.stream;

  // Linha em branco separadora entre getters públicos
  // Comentário original do autor mantido byte a byte:
  // Retorna o fluxo de dados da lista de veículos
  // Getter da Stream para observação reativa de mudanças na lista de veículos
  Stream<List<VeiculoModel>> get veiculosStream => _veiculosController.stream;

  // Linha em branco separadora entre getters e métodos privados
  // Comentário original do autor mantido byte a byte:
  // Insere registros padrão de veículos na lista em memória
  // Método de inicialização da lista local de veículos municipais
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
  // Comentário original do autor mantido byte a byte:
  // Verifica se existem instâncias ativas do Firebase inicializadas
  // Método defensivo para checagem da disponibilidade do Firebase
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
  // Comentário original do autor mantido byte a byte:
  // Retorna um fluxo com a lista de veículos disponíveis filtrados
  // Retorna uma Stream com os veículos liberados para condução
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
                // Comentário original do autor mantido byte a byte:
                // Escreve os veículos padrão no Firestore quando a coleção está sem documentos
                // Sincroniza a base de dados padrão no Firestore de forma assíncrona
                _sincronizarVeiculosBaseNoFirestore();
                // Retorna os veículos da memória aplicando o filtro de disponibilidade
                return ValidacaoViagem.filtrarVeiculosDisponiveis(
                  _veiculosMemoria,
                  motoristaPermitidoId: motoristaId,
                );
              // Fecha verificação de snapshot vazio
              }
              // Comentário original do autor mantido byte a byte:
              // Mapeia os documentos retornados para instâncias de VeiculoModel
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
        // Comentário original do autor mantido byte a byte:
        // Prossegue para o fluxo em memória caso ocorra exceção
      // Fecha o bloco catch
      }
    // Fecha a checagem de Firebase disponível
    }

    // Linha em branco separadora entre tentativa remota e emissão local
    // Comentário original do autor mantido byte a byte:
    // Emite a lista de veículos armazenada em memória através do StreamController
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
  // Comentário original do autor mantido byte a byte:
  // Envia os veículos da lista em memória para a coleção 'veiculos' do Firestore
  // Método assíncrono para preencher a coleção 'veiculos' no Firestore quando vazia
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
      // Comentário original do autor mantido byte a byte:
      // Ignora falhas de escrita durante a sincronização
    // Fecha o bloco catch
    }
  // Fecha o método _sincronizarVeiculosBaseNoFirestore
  }

  // Linha em branco separadora entre sincronização e iniciarViagem
  // Comentário original do autor mantido byte a byte:
  // Valida os dados, atualiza a disponibilidade do veículo e cria o registro de viagem
  // Método assíncrono central para validação e abertura de uma nova viagem
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
    // Comentário original do autor mantido byte a byte:
    // Valida a quilometragem informada contra a última registrada
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
    // Comentário original do autor mantido byte a byte:
    // Valida a cidade informada
    // Executa a validação de preenchimento da cidade de destino
    final validacaoCidade = ValidacaoViagem.validarCidade(cidadeDestino);
    // Se a cidade for inválida, retorna erro imediato com a mensagem
    if (!validacaoCidade.valido) {
      return ResultadoInicioViagem.erro(validacaoCidade.mensagemErro!);
    // Fecha checagem de cidade inválida
    }

    // Linha em branco separadora entre validação de cidade e checagem remota no Firestore
    // Comentário original do autor mantido byte a byte:
    // Consulta o documento do veículo no Firestore para verificar uso concorrente
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
          // Comentário original do autor mantido byte a byte:
          // Verifica se o veículo está marcado em uso por motorista distinto
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
        // Comentário original do autor mantido byte a byte:
        // Prossegue com a verificação em memória caso ocorra falha de consulta remota
      // Fecha bloco catch
      }
    // Fecha checagem de Firebase disponível
    }

    // Linha em branco separadora entre consulta remota e verificação na memória
    // Comentário original do autor mantido byte a byte:
    // Verifica a situação do veículo na lista em memória
    // Localiza o índice do veículo na lista interna da memória
    final index = _veiculosMemoria.indexWhere((v) => v.id == veiculo.id);
    // Se o veículo constar na lista da memória, valida conflito local
    if (index != -1) {
      // Obtém a instância do veículo na memória
      final veicMem = _veiculosMemoria[index];
      // Comentário original do autor mantido byte a byte:
      // Verifica se o veículo da memória está em uso por outro motorista
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
      // Comentário original do autor mantido byte a byte:
      // Atualiza o veículo na memória com status emUso, novo condutor e quilometragem
      // Atualiza o veículo na memória com a reserva e o KM informado
      _veiculosMemoria[index] = _veiculosMemoria[index].copyWith(
        emUso: true,
        motoristaAtualId: motoristaId,
        quilometragemAtual: kmInicial,
      );
    // Fecha verificação do índice na memória
    }

    // Linha em branco separadora entre atualização de memória e criação da viagem
    // Comentário original do autor mantido byte a byte:
    // Instancia o objeto ViagemModel com os dados da viagem
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
    // Comentário original do autor mantido byte a byte:
    // Atualiza a variável e notifica os fluxos de dados
    // Atualiza a propriedade interna de viagem ativa
    _viagemAtiva = novaViagem;
    // Emite o novo objeto na stream de viagem ativa
    _viagemAtivaController.add(_viagemAtiva);
    // Emite a nova lista de veículos filtrados na stream de frota
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );

    // Linha em branco separadora entre notificação local e persistência remota
    // Comentário original do autor mantido byte a byte:
    // Persiste as alterações no Firestore
    // Persiste as mudanças no Cloud Firestore se disponível
    if (_isFirebaseDisponivel()) {
      // Bloco try para capturar exceções de gravação remota
      try {
        // Comentário original do autor mantido byte a byte:
        // Atualiza os dados de uso e quilometragem do veículo
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
        // Comentário original do autor mantido byte a byte:
        // Cria o documento da viagem na coleção 'viagens'
        // Cria o novo documento de viagem na coleção 'viagens'
        await FirebaseFirestore.instance
            .collection('viagens')
            .doc(novaViagem.id)
            .set(novaViagem.toMap());

        // Linha em branco separadora entre criação da viagem e atualização de usuário
        // Comentário original do autor mantido byte a byte:
        // Atualiza a propriedade emViagem do usuário motorista
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
        // Comentário original do autor mantido byte a byte:
        // Ignora erros de escrita remota
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
  // Comentário original do autor mantido byte a byte:
  // Altera o status da viagem para encerrada e libera o veículo associado
  // Método assíncrono para finalização da rota e devolução do automóvel à frota
  Future<void> encerrarViagem({int? kmFinal, int? kmRodado}) async {
    // Interrompe se não houver viagem ativa em curso
    if (_viagemAtiva == null) return;

    // Linha em branco separadora entre checagem de viagem ativa e extração de dados
    // Extrai a viagem ativa atual
    final viagem = _viagemAtiva!;
    // Extrai o ID do veículo utilizado
    final veiculoId = viagem.veiculoId;

    // Linha em branco separadora entre extração e atualização de memória
    // Comentário original do autor mantido byte a byte:
    // Atualiza os dados do veículo na lista em memória
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
    // Comentário original do autor mantido byte a byte:
    // Limpa a viagem ativa e atualiza os fluxos de dados
    // Zera a propriedade de viagem ativa
    _viagemAtiva = null;
    // Emite nulo na stream de viagem ativa
    _viagemAtivaController.add(null);
    // Emite a nova lista de veículos disponíveis na stream de frota
    _veiculosController.add(
      ValidacaoViagem.filtrarVeiculosDisponiveis(_veiculosMemoria),
    );

    // Linha em branco separadora entre notificação local e atualização no Firestore
    // Comentário original do autor mantido byte a byte:
    // Atualiza os documentos no Firestore
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
        // Comentário original do autor mantido byte a byte:
        // Ignora erros de escrita remota
      // Fecha o bloco catch
      }
    // Fecha a checagem de Firebase disponível
    }
  // Fecha o método encerrarViagem
  }

  // Linha em branco separadora entre encerrarViagem e resetParaTestes
  // Comentário original do autor mantido byte a byte:
  // Restaura o estado interno de memória e notifica os fluxos com os valores fornecidos
  // Método utilitário para restabelecimento de estado determinístico em testes
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
// Fecha a classe ViagemService
}
