// ============================================================================
// ARQUIVO: lib/motorista.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa a tela principal operacional de controle e acompanhamento de
// viagens pelo motorista (widget Stateful "Motorista"). Exibe em tempo real
// a lista de passageiros cadastrados na rota, a capacidade e ocupação do
// veículo, e permite a alteração de status do passageiro (como embarcou,
// desembarcou, consulta finalizada) através de gestos de deslize lateral (swipe/
// Dismissible). Permite também iniciar ou encerrar a viagem através dos
// formulários acoplados no rodapé (FooterPacientes).
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Apresentação / View (Interface do Usuário com Flutter).
//
// ONDE É USADO (REFERÊNCIAS NO REPOSITÓRIO):
// - lib/screens/auth_gate.dart: Renderizado quando o usuário autenticado possui role "motorista".
// - lib/routes/route_guard.dart: Mapeado na rota protegida "/motorista".
// - test/screens/auth_gate_test.dart: Verificação de redirecionamento do motorista.
// - test/widget_test.dart: Testes instrumentados de renderização de interface.
//
// DE ONDE RECEBE DADOS:
// - Cloud Firestore: coleção "usuarios" para ouvir pacientes (role == 'paciente')
//   e motoristas (role == 'motorista').
// - lib/services/viagem_service.dart: escuta o stream de viagem ativa (viagemAtivaStream).
// - ModalRoute: argumentos de navegação contendo ViagemModel caso venha de redirecionamento.
// - Parâmetros opcionais de injeção de dependência para testes: viagemInicial,
//   viagemServiceOverride, pacientesStreamOverride.
//
// O QUE EXPORTA / EXPÕE:
// - class Motorista extends StatefulWidget: Widget visual da tela do motorista.
// - class _MotoristaState: Estado interno associado ao ciclo de vida do widget.
//
// ORIGEM HISTÓRICA:
// Criado pela equipe do projeto TransSaúde (commits e34c23d, 4651c09 e refinado em
// commits subsequentes como ccbbe0e, 588756d, 8d73cce, c0351c9).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - dart:async: StreamSubscription para assinaturas reativas.
// - package:cloud_firestore: leitura e escrita assíncrona no banco NoSQL Firestore.
// - package:firebase_core: checagem de inicialização de instâncias do Firebase.
// - package:flutter/material.dart: componentes de UI Material Design.
// - Efeitos colaterais: atualiza campos no banco remoto Firestore ao arrastar cards
//   e assina ouvintes em tempo real que consomem tráfego de rede.
//
// INCONSISTÊNCIAS / OBSERVAÇÕES TÉCNICAS:
// - A consulta do motorista em _ouvirDadosMotorista() busca com .limit(1) qualquer motorista
//   cadastrado no banco, em vez de filtrar pelo id do motorista atualmente autenticado.
// - O método confirmDismiss retorna sempre false para evitar que o Dismissible remova
//   o widget da árvore localmente de forma abrupta, delegando o redesenho à Stream reativa.
// ============================================================================
// Importa utilitários assíncronos do Dart, incluindo StreamSubscription e Streams
import 'dart:async';

// Importa a biblioteca do Cloud Firestore para acesso ao banco de dados em tempo real
import 'package:cloud_firestore/cloud_firestore.dart';
// Importa o núcleo do Firebase para verificar se o aplicativo já foi inicializado
import 'package:firebase_core/firebase_core.dart';
// Importa o conjunto completo de componentes Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o modelo de dados que representa um motorista no sistema
import 'package:trans_saude/models/motorista_model.dart';
// Importa o modelo de dados que representa um paciente no sistema
import 'package:trans_saude/models/paciente_model.dart';
// Importa o modelo de dados que encapsula as informações de uma viagem
import 'package:trans_saude/models/viagem_model.dart';
// Importa o serviço responsável pela gestão de viagens e seus fluxos
import 'package:trans_saude/services/viagem_service.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/localizacao_motorista_service.dart';
import 'package:trans_saude/services/paciente_sync_service.dart';
import 'package:trans_saude/services/transicao_paciente_service.dart';

// Importa o componente visual de card individual de paciente
import 'components/card_paciente.dart';
import 'components/dialogo_confirmacao_motorista.dart';
// Importa o componente visual do rodapé da tela com informações de vagas e ações
import 'components/footer_pacientes.dart';
// Importa o componente visual do cabeçalho de viagem com título e paginação
import 'components/motorista_header.dart';
// Importa o formulário de início de viagem para declaração de veículo e KM inicial
import 'components/formulario_inicio_viagem.dart';

// Declaração do StatefulWidget Motorista, tela operacional acessível pelo perfil motorista
class Motorista extends StatefulWidget {
  // Viagem inicial informada para exibição dos dados na tela
  // Propriedade opcional para inicializar a tela com uma viagem já carregada
  final ViagemModel? viagemInicial;
  // Instância customizada do serviço de viagens
  // Permite injetar uma instância simulada ou customizada de ViagemService para testes
  final ViagemService? viagemServiceOverride;
  // Stream de pacientes injetada externamente
  // Permite injetar um fluxo simulado de pacientes para testes automatizados
  final Stream<List<PacienteModel>>? pacientesStreamOverride;
  // Instância do serviço de sincronização e transições de status (injetável para testes)
  final PacienteSyncService? syncServiceOverride;

  // Construtor constante da classe Motorista que aceita parâmetros de injeção opcionais
  const Motorista({
    // Chave identificadora única do widget na árvore de elementos
    super.key,
    // Parâmetro opcional com os dados da viagem inicial
    this.viagemInicial,
    // Parâmetro opcional para injeção de dependência de ViagemService
    this.viagemServiceOverride,
    // Parâmetro opcional para injeção de dependência da Stream de pacientes
    this.pacientesStreamOverride,
    // Parâmetro opcional para injeção de dependência de PacienteSyncService
    this.syncServiceOverride,
  // Fechamento da lista de parâmetros do construtor
  });

  // Sobrescrita obrigatória que cria o estado mutável associado a este widget
  @override
  // Instancia e retorna a classe de estado _MotoristaState
  State<Motorista> createState() => _MotoristaState();
// Fechamento da classe Motorista
}

// Classe de estado privada que gerencia o ciclo de vida e renderização da tela do motorista
class _MotoristaState extends State<Motorista> {
  // Instância do serviço de viagens
  // Referência ao serviço de gerenciamento do ciclo de vida das viagens
  late final ViagemService _viagemService;

  // Inscrição para escutar mudanças no estado da viagem ativa
  // Assinatura na stream para desinscrever adequadamente no método dispose
  StreamSubscription<ViagemModel?>? _subViagemAtiva;

  // Inscrição para escutar a lista com todas as N viagens ativas (Issue #65)
  StreamSubscription<List<ViagemModel>>? _subViagensAtivas;

  // Lista com as N viagens ativas sob a sessão do motorista (Issue #65)
  List<ViagemModel> _viagensAtivas = [];

  // Índice da viagem em exibição ativa na tela (0 a N-1)
  int _indiceViagemAtual = 0;

  // Viagem ativa associada à sessão do motorista
  // Armazena a viagem em andamento para exibir na interface e controlar fluxos
  ViagemModel? _viagemAtiva;

  // Capacidade do veículo obtida dos dados do motorista
  // Quantidade total de assentos disponíveis no veículo utilizado na viagem
  int _capacidadeVeiculo = 0;

  // Serviço central de sincronização atômica e máquina de estados de transição
  late final PacienteSyncService _syncService;

  // Identificador do motorista autenticado ou associado aos dados da viagem
  String? _motoristaId;

  // Verifica se existem instâncias ativas do Firebase inicializadas
  // Método auxiliar que checa se o Firebase foi inicializado sem lançar exceções não tratadas
  bool _isFirebaseDisponivel() {
    // Bloco protegido para tentar verificar a lista de aplicativos Firebase inicializados
    try {
      // Retorna verdadeiro se houver ao menos um app Firebase registrado no ecossistema
      return Firebase.apps.isNotEmpty;
    // Captura qualquer erro de acesso ao Firebase (como em ambiente de testes unitários simples)
    } catch (_) {
      // Retorna falso indicando que o Firebase não está disponível neste contexto
      return false;
    // Fechamento do bloco catch
    }
  // Fechamento do método _isFirebaseDisponivel
  }

  // Sobrescrita do ciclo de vida chamada quando o widget é inserido na árvore
  @override
  // Método de inicialização de estado interno e ouvintes
  void initState() {
    // Chama a implementação da classe pai obrigatória no ciclo do StatefulWidget
    super.initState();
    // Atribui o serviço injetado por parâmetro ou instancia um novo ViagemService padrão
    _viagemService = widget.viagemServiceOverride ?? ViagemService();
    _syncService = widget.syncServiceOverride ?? PacienteSyncService();

    // Inicializa a variável com a viagem fornecida no construtor
    // Atribui o valor de viagemInicial recebido via construtor à variável de estado
    _viagemAtiva = widget.viagemInicial;

    // Inicializa o cache local com as viagens ativas pré-existentes na sessão
    _viagensAtivas = _viagemService.viagensAtivas;
    if (_viagensAtivas.isNotEmpty && _viagemAtiva == null) {
      _viagemAtiva = _viagensAtivas.first;
    }
    if (_viagemAtiva == null && _viagemService.viagemAtiva != null) {
      _viagemAtiva = _viagemService.viagemAtiva;
    }
    _atualizarTransmissaoGpsMotorista();

    // Assina a stream de atualização da viagem ativa
    // Ouve reativamente qualquer alteração na viagem ativa transmitida pelo serviço
    _subViagemAtiva = _viagemService.viagemAtivaStream.listen((viagem) {
      // Garante que o widget ainda está montado na árvore antes de atualizar o estado
      if (mounted) {
        // Notifica a árvore do Flutter que o estado interno mudou e requer redesenho
        setState(() {
          // Atualiza a viagem ativa com o novo objeto emitido pela stream
          _viagemAtiva = viagem;
        // Fechamento da função de callback de setState
        });
        _atualizarTransmissaoGpsMotorista();
      // Fechamento da verificação if mounted
      }
    // Fechamento do listener da stream
    });

    // Assina a stream de N viagens ativas (Issue #65)
    _subViagensAtivas = _viagemService.viagensAtivasStream.listen((viagens) {
      if (mounted) {
        setState(() {
          _viagensAtivas = viagens;
          if (_viagensAtivas.isNotEmpty) {
            if (_indiceViagemAtual >= _viagensAtivas.length) {
              _indiceViagemAtual = _viagensAtivas.length - 1;
            }
            _viagemAtiva = _viagensAtivas[_indiceViagemAtual];
          } else {
            _viagemAtiva = null;
          }
        });
        _atualizarTransmissaoGpsMotorista();
      }
    });

    // Inicia a escuta dos dados do motorista caso o Firebase esteja disponível
    // Inicia o stream Firestore para carregar a capacidade do veículo se o Firebase estiver ativo
    if (_isFirebaseDisponivel()) {
      // Dispara a consulta contínua aos dados do motorista no Firestore
      _ouvirDadosMotorista();
    // Fechamento da condicional de verificação do Firebase
    }
  // Fechamento do método initState
  }

  // Sobrescrita do ciclo de vida chamada quando dependências herdadas mudam ou após initState
  @override
  // Método para obter argumentos transmitidos por rotas de navegação com segurança
  void didChangeDependencies() {
    // Chama a implementação herdada da classe pai State
    super.didChangeDependencies();
    // Obtém os argumentos de rota contendo a viagem iniciada
    // Se a viagem ativa ainda não foi definida, busca dos argumentos da rota atual
    if (_viagemAtiva == null) {
      // Lê as configurações e argumentos passados na rota atual
      final args = ModalRoute.of(context)?.settings.arguments;
      // Valida se o argumento recebido é de fato uma instância de ViagemModel
      if (args is ViagemModel) {
        // Atribui a viagem recebida via rota à variável de estado
        _viagemAtiva = args;
      // Fechamento do if de verificação de tipo de argumento
      }
    // Fechamento da verificação se _viagemAtiva é nula
    }
  // Fechamento do método didChangeDependencies
  }

  void _atualizarTransmissaoGpsMotorista() {
    final v = _viagemAtiva;
    if (v != null && v.isAtiva) {
      LocalizacaoMotoristaService().iniciarTransmissaoGpsMotorista(
        motoristaId: v.motoristaId.isNotEmpty
            ? v.motoristaId
            : (FirebaseAuthService().currentUserId ?? 'motorista_atual'),
        motoristaNome: v.motoristaNome.isNotEmpty
            ? v.motoristaNome
            : 'Motorista Municipal',
        veiculoPlaca: v.veiculoPlaca,
        veiculoModelo: v.veiculoModelo,
        cidadeDestino: v.cidadeDestino,
        viagemId: v.id,
      );
    } else {
      LocalizacaoMotoristaService().pararTransmissaoGpsMotorista();
    }
  }

  // Sobrescrita do ciclo de vida chamada quando o widget é descartado permanentemente
  @override
  // Método de liberação de recursos, cancelamento de assinaturas e timers
  void dispose() {
    LocalizacaoMotoristaService().pararTransmissaoGpsMotorista();
    // Cancela as inscrições nas streams de viagem ativa e N viagens
    _subViagemAtiva?.cancel();
    _subViagensAtivas?.cancel();
    // Invoca o descarte da classe pai
    super.dispose();
  // Fechamento do método dispose
  }

  // Consulta os dados do motorista na coleção 'usuarios' do Firestore
  // Inicia um ouvinte em tempo real no Firestore para obter a capacidade do veículo do motorista
  void _ouvirDadosMotorista() {
    // Acessa a instância global do Firestore
    FirebaseFirestore.instance
        // Navega até a coleção raiz 'usuarios'
        .collection('usuarios')
        // Filtra os usuários com papel funcional de motorista
        .where('role', isEqualTo: 'motorista')
        // Limita a consulta ao primeiro documento encontrado
        .limit(1)
        // Obtém a stream contínua de fotos instantâneas (snapshots) da coleção
        .snapshots()
        // Registra o ouvinte para processar as emissões de snapshots
        .listen((snapshot) {
          // Verifica se existem documentos retornados e se o widget ainda está montado
          if (snapshot.docs.isNotEmpty && mounted) {
            // Converte os dados brutos do documento em um modelo fortemente tipado MotoristaModel
            final motorista = MotoristaModel.fromMap(
              // Mapa de atributos do primeiro documento retornado
              snapshot.docs.first.data(),
              // Identificador do documento do Firestore
              docId: snapshot.docs.first.id,
            // Fechamento da chamada de instanciação MotoristaModel.fromMap
            );
            // Atualiza o estado da interface com a capacidade do veículo obtida
            setState(() {
              // Atribui a capacidade numérica de assentos do veículo
              _capacidadeVeiculo = motorista.capacidadeVeiculo;
              _motoristaId = motorista.id.isNotEmpty ? motorista.id : snapshot.docs.first.id;
            // Fechamento da função de callback de setState
            });
          // Fechamento do bloco if
          }
        // Fechamento da função ouvinte listen
        });
  // Fechamento do método _ouvirDadosMotorista
  }

  // Retorna a stream de pacientes cadastrados
  // Retorna a stream reativa de lista de pacientes, respeitando mocks ou conectando ao Firestore
  Stream<List<PacienteModel>> carregarPacientes() {
    // Se foi injetada uma stream simulada para testes, retorna-a diretamente
    if (widget.pacientesStreamOverride != null) {
      // Retorna o fluxo mockado injetado no construtor
      return widget.pacientesStreamOverride!;
    // Fechamento da condicional de stream injetada
    }

    // Se a viagem ativa possuir passageiros cadastrados (ex: definidos pelo admin no Gerenciador)
    if (_viagemAtiva != null && _viagemAtiva!.passageiros.isNotEmpty) {
      return Stream.value(
        _viagemAtiva!.passageiros.map<PacienteModel>((pv) => PacienteModel(
          id: pv.pacienteId,
          nome: pv.pacienteNome,
          cpf: pv.pacienteCpf ?? '',
          telefone: pv.acompanhanteTelefone ?? '',
          enderecoPaciente: pv.localOrigem,
          localSaida: pv.localOrigem,
          localConsulta: pv.localDestino,
          nomeAcompanhante: pv.acompanhanteNome,
          telAcompanhante: pv.acompanhanteTelefone,
          status: pv.statusEmbarque,
        )).toList(),
      );
    }

    // Se o serviço do Firebase estiver ativo e inicializado no app
    if (_isFirebaseDisponivel()) {
      // Realiza a consulta contínua na coleção 'usuarios' do Firestore
      return FirebaseFirestore.instance
          // Coleção onde os perfis estão armazenados
          .collection('usuarios')
          // Filtra apenas os usuários com papel de paciente
          .where('role', isEqualTo: 'paciente')
          // Ouve as emissões em tempo real de documentos
          .snapshots()
          // Mapeia o snapshot de documentos para uma lista tipada de PacienteModel
          .map((snapshot) {
            // Itera sobre cada documento retornado no snapshot
            return snapshot.docs.map((doc) {
              // Converte o documento bruto em um objeto PacienteModel estruturado
              return PacienteModel.fromMap(doc.data(), docId: doc.id);
            // Converte a sequência mapeada em uma lista do Dart
            }).toList();
          // Fechamento do mapeamento
          });
    // Fechamento da condicional de verificação do Firebase
    }

    // Retorna lista com pacientes de teste quando o Firebase não está disponível
    // Fluxo de fallback com dados mockados para exibição offline ou modo de demonstração
    return Stream.value([
      // Primeiro paciente fictício de exemplo
      PacienteModel(
        // Identificador fixo para teste
        id: 'p1',
        // Nome fictício do paciente
        nome: 'Maria das Graças Aparecida',
        // CPF formatado fictício
        cpf: '123.456.789-00',
        // Endereço de embarque do paciente
        enderecoPaciente: 'Rua das Flores, 125 - Centro',
        // Número de telefone para contato
        telefone: '(17) 99123-4567',
        // Destino da consulta de saúde
        localConsulta: 'Hospital de Base',
        // Local de saída / embarque de origem
        localSaida: 'Laboratório de Análises Clínicas',
        // Status inicial: 0 (Aguardando)
        status: 0,
      // Fechamento da instância de PacienteModel p1
      ),
      // Segundo paciente fictício de exemplo
      PacienteModel(
        // Identificador fixo para teste
        id: 'p2',
        // Nome fictício do segundo paciente
        nome: 'Carlos Eduardo Martins',
        // CPF formatado fictício
        cpf: '987.654.321-00',
        // Endereço de embarque do segundo paciente
        enderecoPaciente: 'Rua dos Ipês, 310',
        // Número de telefone para contato
        telefone: '(17) 99456-7890',
        // Destino da consulta médica
        localConsulta: 'AME São José do Rio Preto',
        // Local de saída ou laboratório
        localSaida: 'Centro de Diagnóstico por Imagem',
        // Status inicial: 1 (Embarcou)
        status: 1,
      // Fechamento da instância de PacienteModel p2
      ),
    // Fechamento da lista fornecida na Stream.value
    ]);
  // Fechamento do método carregarPacientes
  }

  // Verifica se o condutor possui viagem ativa em andamento no momento
  bool get _temViagemAtiva {
    if (widget.pacientesStreamOverride != null) return true;
    if (_viagemAtiva != null && _viagemAtiva!.isAtiva) return true;
    if (_viagensAtivas.isNotEmpty && _viagensAtivas.any((v) => v.isAtiva)) return true;
    if (_viagemService.viagemAtiva != null && _viagemService.viagemAtiva!.isAtiva) return true;
    return false;
  }

  // Método que constrói a árvore de widgets da interface do motorista
  @override
  // Recebe o contexto de montagem do widget
  Widget build(BuildContext context) {
    // Caso o motorista não possua viagem ativa (primeira vez do dia que entrar ou
    // após finalizar a viagem gerando o relatório final), exibe o formulário de
    // início de viagem para escolher o veículo e registrar a quilometragem inicial.
    if (!_temViagemAtiva) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Início da Viagem'),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              key: const Key('botaoLogoutMotorista'),
              icon: const Icon(Icons.logout),
              tooltip: 'Sair da conta',
              onPressed: () async {
                await FirebaseAuthService().logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              },
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: FormularioInicioViagem(
                motoristaId: FirebaseAuthService().currentUserId ?? 'motorista_atual',
                onViagemIniciada: (novaViagem) {
                  setState(() {
                    _viagemAtiva = novaViagem;
                  });
                },
              ),
            ),
          ),
        ),
      );
    }

    // Define lista inicial de pacientes quando o Firebase não está disponível
    // Fornece dados iniciais caso o Firebase esteja offline para evitar tela em branco
    final pacientesIniciais = _isFirebaseDisponivel()
        // Se o Firebase estiver ativo, não define dados iniciais síncronos
        ? null
        // Se estiver offline, define uma lista estática de fallback
        : [
            // Paciente 1 mockado para renderização imediata offline
            PacienteModel(
              // ID fictício
              id: 'p1',
              // Nome completo
              nome: 'Maria das Graças Aparecida',
              // CPF
              cpf: '123.456.789-00',
              // Endereço
              enderecoPaciente: 'Rua das Flores, 125 - Centro',
              // Telefone
              telefone: '(17) 99123-4567',
              // Destino hospitalar
              localConsulta: 'Hospital de Base',
              // Ponto de partida
              localSaida: 'Laboratório de Análises Clínicas',
              // Status
              status: 0,
            // Fechamento do paciente mock 1
            ),
            // Paciente 2 mockado para renderização imediata offline
            PacienteModel(
              // ID fictício
              id: 'p2',
              // Nome completo
              nome: 'Carlos Eduardo Martins',
              // CPF
              cpf: '987.654.321-00',
              // Endereço
              enderecoPaciente: 'Rua dos Ipês, 310',
              // Telefone
              telefone: '(17) 99456-7890',
              // Destino de saúde
              localConsulta: 'AME São José do Rio Preto',
              // Ponto de partida
              localSaida: 'Centro de Diagnóstico por Imagem',
              // Status
              status: 1,
            // Fechamento do paciente mock 2
            ),
          // Fechamento da lista de pacientes iniciais
          ];

    // Constrói a UI de forma reativa a partir da Stream de pacientes
    return StreamBuilder<List<PacienteModel>>(
      // Dados iniciais fornecidos para exibição imediata antes do primeiro evento
      initialData: pacientesIniciais,
      // Stream de onde os dados de pacientes são continuamente consumidos
      stream: carregarPacientes(),
      // Construtor reativo chamado a cada nova emissão da Stream
      builder: (context, snapshot) {
        // Se a Stream estiver aguardando conexão e não tiver nenhum dado prévio
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          // Exibe uma tela simples com indicador de carregamento giratório centralizado
          return const Scaffold(
            // Corpo com círculo de progresso
            body: Center(child: CircularProgressIndicator()),
          // Fechamento do Scaffold de carregamento
          );
        // Fechamento do bloco if de espera
        }

        // Se ocorreu algum erro durante a leitura da Stream
        if (snapshot.hasError) {
          // Exibe uma tela de erro informando a falha no carregamento
          return const Scaffold(
            // Corpo com texto explicativo do erro
            body: Center(child: Text('Erro ao carregar os pacientes.')),
          // Fechamento do Scaffold de erro
          );
        // Fechamento do bloco if de erro
        }

        // Obtém os pacientes emitidos pela Stream ou uma lista vazia caso nulo
        final pacientes = snapshot.data ?? [];
        // Calcula os lugares ocupados (pacientes com status == 1 "Embarcou")
        // Variável acumuladora de assentos ocupados por pacientes e acompanhantes
        int preenchidos = 0;
        // Passageiros a bordo: status 1 (Ida) ou status 3 (Volta). Se houver acompanhante, ocupa 2 vagas
        // Itera sobre os pacientes que estão atualmente a bordo do veículo
        for (var p in pacientes.where((p) => p.status == 1 || p.status == 3)) {
          // Se o paciente tiver acompanhante com nome preenchido, soma 2 vagas; senão, soma 1 vaga
          preenchidos += (p.nomeAcompanhante?.isNotEmpty == true) ? 2 : 1;
        // Fechamento do loop for de contagem de vagas
        }

        // Retorna a estrutura visual completa da página com Scaffold
        return Scaffold(
          // Barra de navegação superior da aplicação com identidade visual consistente
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 2,
            // Botão de retorno na extremidade esquerda da barra superior
            leading: IconButton(
              // Ícone com seta apontando para a esquerda
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              // Ação executada ao tocar no botão de voltar
              onPressed: () {
                // Retorna à tela anterior ou redireciona para a rota inicial
                // Verifica se há tela anterior na pilha de navegação para retroceder
                if (Navigator.of(context).canPop()) {
                  // Desempilha e volta à tela imediatamente anterior
                  Navigator.of(context).pop();
                // Caso não haja tela anterior na pilha
                } else {
                  // Substitui a rota atual pela rota raiz do sistema
                  Navigator.of(context).pushReplacementNamed('/');
                // Fechamento da condicional if/else
                }
              // Fechamento do callback onPressed
              },
            // Fechamento do IconButton leading
            ),
            // Título central da barra de navegação superior
            title: const Text(
              'Lista de Passageiros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            // Ações e widgets auxiliares na extremidade direita da barra superior
            actions: [
              // Exibe a placa do veículo associado à viagem ativa
              // Se houver uma viagem ativa em andamento, exibe a etiqueta com a placa do carro
              if (_viagemAtiva != null)
                // Espaçamento horizontal externo da etiqueta de placa
                Padding(
                  // Aplica recuo de 12 pixels nas laterais
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  // Centraliza verticalmente o widget indicador
                  child: Center(
                    // Contêiner estilizado como uma badge/pílula verde
                    child: Container(
                      // Espaçamento interno da badge
                      padding: const EdgeInsets.symmetric(
                        // Recuo horizontal interno
                        horizontal: 10,
                        // Recuo vertical interno
                        vertical: 5,
                      // Fechamento do EdgeInsets
                      ),
                      // Decoração visual da badge com cor de fundo verde e cantos arredondados
                      decoration: BoxDecoration(
                        // Cor verde destacada para viagem em andamento
                        color: Colors.green.shade700,
                        // Borda arredondada suave
                        borderRadius: BorderRadius.circular(12),
                      // Fechamento do BoxDecoration
                      ),
                      // Texto informando a placa do veículo ativo
                      child: Text(
                        // Concatena o texto com a placa do veículo da viagem ativa
                        'Em Viagem: ${_viagemAtiva!.veiculoPlaca}',
                        // Estilização tipográfica do texto da placa
                        style: const TextStyle(
                          // Cor branca para alto contraste
                          color: Colors.white,
                          // Tamanho compacto de fonte
                          fontSize: 11,
                          // Peso em negrito para boa legibilidade
                          fontWeight: FontWeight.bold,
                        // Fechamento do TextStyle
                        ),
                      // Fechamento do Text
                      ),
                    // Fechamento do Container
                    ),
                  // Fechamento do Center
                  ),
                // Fechamento do Padding
                ),
              // Botão de logout do motorista
              IconButton(
                key: const Key('botaoLogoutMotorista'),
                icon: const Icon(Icons.logout),
                color: Colors.white,
                tooltip: 'Sair da conta',
                onPressed: () async {
                  await FirebaseAuthService().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                },
              ),
            // Fechamento da lista actions
            ],
          // Fechamento do AppBar
          ),
          // Cor de fundo padronizada para toda a página
          backgroundColor: const Color(0xFFF8FAFC),
          // Área protegida contra entalhes de tela (notches) e barras do sistema operacional
          body: SafeArea(
            // Lista rolável vertical contendo os cabeçalhos e os cartões de pacientes
            child: ListView(
              // Espaçamento interno ao redor de todo o conteúdo da lista
              padding: const EdgeInsets.all(16),
              // Filhos organizados sequencialmente na rolagem
              children: [
                // TODO(#13): ligar ao ViagemModel
                // Componente de cabeçalho da viagem mostrando o título da viagem e controles de navegação
                MotoristaHeader(
                  // Título dinâmico da viagem baseado no ID da viagem ativa ou fallback
                  tituloViagem: _viagensAtivas.length > 1
                      ? 'Viagem ${_indiceViagemAtual + 1} de ${_viagensAtivas.length} (${_viagemAtiva?.cidadeDestino ?? ""})'
                      : (_viagemAtiva != null && _viagemAtiva!.id.isNotEmpty
                          ? 'Viagem ${_viagemAtiva!.id}'
                          : 'Viagem 1'),
                  // Callback para retroceder viagem na sessão ativa (Issue #65)
                  onAnterior: _viagensAtivas.length > 1 && _indiceViagemAtual > 0
                      ? () {
                          setState(() {
                            _indiceViagemAtual--;
                            _viagemAtiva = _viagensAtivas[_indiceViagemAtual];
                          });
                        }
                      : null,
                  // Callback para avançar viagem na sessão ativa (Issue #65)
                  onProxima: _viagensAtivas.length > 1 &&
                          _indiceViagemAtual < _viagensAtivas.length - 1
                      ? () {
                          setState(() {
                            _indiceViagemAtual++;
                            _viagemAtiva = _viagensAtivas[_indiceViagemAtual];
                          });
                        }
                      : null,
                // Fechamento do MotoristaHeader
                ),
                // Espaçador vertical entre o cabeçalho e os cards de passageiros
                const SizedBox(height: 12),
                // Itera sobre todos os pacientes emitidos para renderizar os cards interativos
                for (final paciente in pacientes)
                  // Espaçamento inferior entre cada card de paciente
                  Padding(
                    // Recuo de 10 pixels na parte inferior de cada card
                    padding: const EdgeInsets.only(bottom: 10),
                    // Widget interativo que detecta gestos de deslize lateral (swipe)
                    child: Dismissible(
                      // Chave única para o Flutter rastrear a identidade deste item na lista
                      key: ValueKey(
                        // Utiliza o ID do paciente se disponível, ou o nome como fallback
                        paciente.id.isNotEmpty ? paciente.id : paciente.nome,
                      // Fechamento do ValueKey
                      ),
                      // Direção permitida: bloqueia permanentemente o retrocesso startToEnd.
                      // Permite apenas endToStart para pacientes com etapas ativas pendentes (status < 4).
                      direction: (paciente.status < 4)
                          ? DismissDirection.endToStart
                          : DismissDirection.none,
                      // Em conformidade com a asserção do Flutter Dismissible (secondaryBackground != null exige background != null):
                      background: Container(),
                      // Fundo exibido ao arrastar o card da direita para a esquerda (avançar)
                      secondaryBackground: Container(
                        padding: const EdgeInsets.only(right: 16),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, color: Colors.white, size: 50),
                            Text('Avançar', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      // Callback confirmDismiss com diálogo de confirmação defensivo e validação de regras de negócio
                      confirmDismiss: (direction) async {
                        // Bloqueia qualquer direção diferente do avanço oficial
                        if (direction != DismissDirection.endToStart) {
                          return false;
                        }

                        final int statusAtual = paciente.status;

                        // Se a viagem já foi concluída ou cancelada, impede qualquer transição
                        if (statusAtual >= 4) {
                          return false;
                        }

                        // BLOQUEIO DE REGRA (Status 2 -> 3):
                        // Se estiver no hospital (Status 2) e o paciente ainda não sinalizou estar pronto
                        // (prontoRetorno == false), bloqueia a tentativa e alerta o motorista.
                        if (statusAtual == 2 && !paciente.prontoRetorno) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFFD97706),
                              content: Text(
                                'O paciente ainda está em atendimento médico.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return false;
                        }

                        // Determina o próximo status e a ação correspondente pela sequência obrigatória
                        // (0 -> 1 -> 2 -> 3 -> 4)
                        final (int proximoStatus, AcaoTransicao acao) = switch (statusAtual) {
                          0 => (1, AcaoTransicao.motoristaEmbarcarIda),
                          1 => (2, AcaoTransicao.motoristaDesembarcarConsulta),
                          2 => (3, AcaoTransicao.motoristaReembarcarVolta),
                          3 => (4, AcaoTransicao.motoristaConcluirViagem),
                          _ => (-1, AcaoTransicao.motoristaEmbarcarIda),
                        };

                        if (proximoStatus == -1) {
                          return false;
                        }

                        final (proximoStatusNome, proximoStatusCor, proximoStatusIcone) =
                            PacienteModel.dadosStatus(proximoStatus);

                        // Diálogo modal ergonômico com botões full-width largos, tipografia escaneável e haptics
                        final bool confirmou = await exibirDialogoConfirmacaoMotorista(
                          context: context,
                          nomePaciente: paciente.nome,
                          proximoStatusNome: proximoStatusNome,
                          proximoStatusCor: proximoStatusCor,
                          proximoStatusIcone: proximoStatusIcone,
                          localDestino: (proximoStatus == 1 || proximoStatus == 2)
                              ? paciente.localConsulta
                              : paciente.enderecoPaciente,
                        );

                        // Se cancelado ou fechado fora, o card desliza de volta para a posição original
                        if (!confirmou) {
                          return false;
                        }

                        // Centraliza o disparo da mutação no serviço oficial (PacienteSyncService / TransicaoPacienteService)
                        final resultado = await _syncService.avancarEtapaMotorista(
                          pacienteId: paciente.id,
                          motoristaId: _motoristaId ?? 'motorista',
                          acao: acao,
                        );

                        if (!context.mounted) return false;

                        if (resultado.sucesso) {
                          // Se o paciente avançou para embarque/viagem (status >= 1) e há viagem ativa, gera ou obtém código de acesso (Issue #65)
                          if (proximoStatus >= 1 && _viagemAtiva != null) {
                            final codigo =
                                await _viagemService.gerarOuObterCodigoAcesso(
                              viagemId: _viagemAtiva!.id,
                              pacienteId: paciente.id,
                            );
                            if (mounted) {
                              setState(() {
                                final novosCodigos = Map<String, String>.from(
                                  _viagemAtiva!.codigosAcesso,
                                );
                                novosCodigos[paciente.id] = codigo;
                                _viagemAtiva = _viagemAtiva!.copyWith(
                                  codigosAcesso: novosCodigos,
                                );
                              });
                            }
                          }

                          if (!context.mounted) return false;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF16A34A),
                              content: Text(
                                "Avanço para '$proximoStatusNome' confirmado com sucesso.",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFB83227),
                              content: Text(
                                resultado.mensagem,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }

                        // Retorna false para que o Dismissible reposicione o card suavemente no centro,
                        // permitindo que o StreamBuilder re-renderize o widget com o novo status e cor
                        // sem removê-lo da lista operacional do dia.
                        return false;
                      },
                      // Widget filho apresentado como conteúdo visual do item arrastável
                      child: CardPaciente(
                        // Nome do paciente para exibição no cabeçalho do card
                        nomePaciente: paciente.nome,
                        // Endereço de residência para busca ou desembarque
                        enderecoPaciente: paciente.enderecoPaciente,
                        // Telefone de contato do paciente
                        telPaciente: paciente.telefone,
                        // Local hospitalar ou clínico da consulta
                        localConsulta: paciente.localConsulta,
                        // Local ou laboratório de saída
                        localSaida: paciente.localSaida,
                        // Status numérico atual para estilização do indicador visual
                        status: paciente.status,
                        // Repassa os dados do acompanhante para o card
                        // Nome do acompanhante, se houver
                        nomeAcompanhante: paciente.nomeAcompanhante,
                        // Telefone do acompanhante, se houver
                        telAcompanhante: paciente.telAcompanhante,
                        prontoRetorno: paciente.prontoRetorno,
                        janelaReversao: paciente.janelaReversao,
                        // Código de acesso temporário gerado no embarque (Issue #65)
                        codigoAcesso:
                            _viagemAtiva?.codigosAcesso[paciente.id],
                      // Fechamento do CardPaciente
                      ),
                    // Fechamento do Dismissible
                    ),
                  // Fechamento do Padding
                  ),
              // Fechamento da lista children do ListView
              ],
            // Fechamento do ListView
            ),
          // Fechamento do SafeArea
          ),
          // Barra de navegação inferior contendo o resumo de assentos e formulários de início/fim de viagem
          bottomNavigationBar: FooterPacientes(
            // Quantidade de assentos ocupados no momento
            lugaresPreenchidos: preenchidos,
            // Capacidade máxima total de assentos do veículo
            lugaresTotais: _capacidadeVeiculo > 0 ? _capacidadeVeiculo : 7,
            // Viagem ativa em andamento para controlar se o botão exibe Iniciar ou Finalizar
            viagem: _viagemAtiva,
            // Lista completa de pacientes para validação de encerramento
            pacientes: pacientes,
          // Fechamento do FooterPacientes
          ),
        // Fechamento do Scaffold
        );
      // Fechamento do builder do StreamBuilder
      },
    // Fechamento do StreamBuilder
    );
  // Fechamento do método build
  }
// Fechamento da classe _MotoristaState
}
