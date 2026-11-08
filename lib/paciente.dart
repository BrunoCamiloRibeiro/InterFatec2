// ============================================================================
// ARQUIVO: lib/paciente.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa a tela principal do Módulo do Paciente (StatefulWidget "Paciente"),
// concebida no escopo da Issue #18. Apresenta ao passageiro logado as suas
// informações cadastrais essenciais, status da viagem atual, dados completos da
// consulta médica agendada (local, horário, ponto de partida, acompanhante),
// botões de ação rápida ("Estou Pronto" e "Fui embora / Carona") e a área
// reservada para rastreamento veicular em tempo real (CardTrackingPaciente).
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Apresentação / View (Interface do Usuário com Flutter).
//
// ONDE É USADO (REFERÊNCIAS NO REPOSITÓRIO):
// - lib/screens/auth_gate.dart: Renderizado quando o usuário autenticado possui role "paciente".
// - lib/routes/route_guard.dart: Mapeado na rota protegida "/paciente".
// - test/screens/auth_gate_test.dart: Verificação de redirecionamento do paciente.
//
// DE ONDE RECEBE DADOS:
// - Cloud Firestore: coleção "usuarios" (documento individual do paciente ou consulta com limit(1)).
// - lib/models/paciente_model.dart: conversão e modelagem tipada do paciente.
// - Parâmetros opcionais via construtor:
//   - pacienteId: ID do documento para escuta direta.
//   - pacienteStreamOverride: Stream customizada para testes unitários ou emulação de dados.
// - Componentes filhos consumidos:
//   - lib/components/card_identificacao_paciente.dart
//   - lib/components/card_dados_consulta.dart
//   - lib/components/card_tracking_paciente.dart
//
// O QUE EXPORTA / EXPÕE:
// - class Paciente extends StatefulWidget: Widget da tela do paciente.
// - class _PacienteState: Gerenciador de estado e ciclo de vida da tela.
//
// ORIGEM HISTÓRICA:
// Criado pela equipe na Issue #18 (commit 54f018c e estilizado no commit 6553abd).
// Substituiu a implementação prototípica legada que residia em lib/Outdated/paciente.dart.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:cloud_firestore: escuta reativa em tempo real de documentos no Firestore.
// - package:firebase_core: checagem de inicialização das instâncias do Firebase.
// - package:flutter/material.dart: componentes de UI Material Design.
// - Efeitos colaterais: consome conexões de rede ativas via Stream do Firestore.
//
// INCONSISTÊNCIAS / OBSERVAÇÕES TÉCNICAS:
// - Os botões de ação ("Estou Pronto" e "Fui embora") possuem corpos de callback
//   vazios acompanhados de comentários TODO sinalizando a pendência da Issue #19.
// - Quando pacienteId não é informado e o Firebase está online, a busca consome
//   o primeiro paciente cadastrado (.limit(1)), útil para desenvolvimento, mas
//   não segmentado por usuário logado específico.
// ============================================================================
// Importa a biblioteca oficial do Cloud Firestore para acesso ao banco de dados NoSQL
import 'package:cloud_firestore/cloud_firestore.dart';
// Importa o pacote principal do Firebase Core para verificação de inicialização
import 'package:firebase_core/firebase_core.dart';
// Importa a biblioteca de componentes visuais Material Design do Flutter
import 'package:flutter/material.dart';

// Importa o componente visual que exibe os detalhes da consulta agendada
import 'components/card_dados_consulta.dart';
// Importa o componente visual de identificação do paciente com avatar e status
import 'components/card_identificacao_paciente.dart';
// Importa o componente de mapa e rastreamento da viagem em tempo real
import 'components/card_tracking_paciente.dart';
// Importa o modelo de localização dos motoristas em trânsito
import 'models/localizacao_motorista_model.dart';
// Importa o modelo de dados representativo da entidade Paciente
import 'models/paciente_model.dart';
// Importa o serviço de autenticação para logout
import 'services/auth_service.dart';

// Tela principal do Módulo do Paciente (Issue #18)
// Centraliza a identificação, dados da consulta agendada, tracking e botões de ação
// Declaração do StatefulWidget Paciente para a tela do passageiro
class Paciente extends StatefulWidget {
  // Identificador opcional do paciente autenticado
  // Chave de documento no Firestore utilizada para carregar os dados específicos do usuário
  final String? pacienteId;
  // Stream customizada de paciente injetada externamente (útil para testes unitários)
  // Fluxo reativo injetável para testes automatizados sem dependência de backend real
  final Stream<PacienteModel?>? pacienteStreamOverride;
  // Stream customizada de motoristas ativos em trânsito para testes unitários
  final Stream<List<LocalizacaoMotoristaModel>>? motoristasStreamOverride;

  // Construtor constante da classe Paciente que aceita propriedades opcionais de injeção
  const Paciente({
    super.key,
    this.pacienteId,
    this.pacienteStreamOverride,
    this.motoristasStreamOverride,
  });

  // Sobrescrita que cria o estado mutável associado a este widget
  @override
  // Instancia e retorna a classe de estado privada _PacienteState
  State<Paciente> createState() => _PacienteState();
// Fechamento da classe Paciente
}

// Classe de estado privada que gerencia o ciclo de vida e a construção da UI do paciente
class _PacienteState extends State<Paciente> {
  // Verifica se o Firebase foi inicializado
  // Checa a disponibilidade do Firebase para decidir entre backend real ou fallback mockado
  bool _isFirebaseDisponivel() {
    // Tenta acessar a lista de aplicativos Firebase registrados
    try {
      // Retorna verdadeiro caso a lista de instâncias Firebase não esteja vazia
      return Firebase.apps.isNotEmpty;
    // Captura exceções em ambientes de teste sem Firebase inicializado
    } catch (_) {
      // Retorna falso sinalizando a ausência de conexão Firebase
      return false;
    // Fechamento do bloco catch
    }
  // Fechamento do método _isFirebaseDisponivel
  }

  // Retorna a stream de dados do paciente ativo em tempo real
  // Função que produz o fluxo reativo do paciente corrente
  Stream<PacienteModel?> _carregarPaciente() {
    // Permite injeção de stream para testes automatizados
    // Se foi injetada uma stream simulada de paciente no construtor
    if (widget.pacienteStreamOverride != null) {
      // Retorna diretamente a stream mockada recebida
      return widget.pacienteStreamOverride!;
    // Fechamento da condicional de stream injetada
    }

    // Se o serviço do Firebase estiver ativo e operacional
    if (_isFirebaseDisponivel()) {
      // Caso o ID tenha sido fornecido, escuta direto o documento dele
      // Verifica se o identificador do paciente foi informado
      if (widget.pacienteId != null) {
        // Acessa o documento específico do paciente na coleção 'usuarios'
        return FirebaseFirestore.instance
            // Coleção de usuários
            .collection('usuarios')
            // Referência direta ao documento do paciente informado
            .doc(widget.pacienteId)
            // Emite snapshots a cada alteração no documento
            .snapshots()
            // Converte o snapshot recebido em uma instância de PacienteModel ou nulo
            .map((doc) {
              // Se o documento não existir ou os dados forem nulos, retorna nulo
              if (!doc.exists || doc.data() == null) return null;
              // Converte o mapa de dados do documento para o modelo PacienteModel
              return PacienteModel.fromMap(doc.data()!, docId: doc.id);
            // Fechamento do map
            });
      // Fechamento da verificação se pacienteId não é nulo
      }

      // Senão, pega o primeiro paciente cadastrado para desenvolvimento
      // Fallback para ambiente de desenvolvimento: escuta o primeiro paciente cadastrado
      return FirebaseFirestore.instance
          // Coleção de usuários
          .collection('usuarios')
          // Filtra documentos onde o perfil seja 'paciente'
          .where('role', isEqualTo: 'paciente')
          // Limita a consulta a um único documento
          .limit(1)
          // Ouve alterações no documento em tempo real
          .snapshots()
          // Transforma o snapshot da coleção em PacienteModel
          .map((snapshot) {
            // Se nenhum paciente foi localizado na coleção, retorna nulo
            if (snapshot.docs.isEmpty) return null;
            // Obtém o primeiro documento do resultado
            final doc = snapshot.docs.first;
            // Converte os dados brutos do Firestore em PacienteModel
            return PacienteModel.fromMap(doc.data(), docId: doc.id);
          // Fechamento do map
          });
    // Fechamento do if de Firebase disponível
    }

    // Mock de fallback com dados realistas caso execute offline ou sem Firebase
    // Retorna uma Stream com um único valor contendo um paciente fictício para testes
    return Stream.value(
      // Instanciação de PacienteModel com atributos realistas
      PacienteModel(
        // Identificador fixo fictício
        id: 'p1',
        // Nome completo do paciente
        nome: 'Maria das Graças Aparecida',
        // CPF formatado fictício
        cpf: '123.456.789-00',
        // Telefone de contato
        telefone: '(17) 99123-4567',
        // Endereço de residência
        enderecoPaciente: 'Rua das Flores, 125 - Centro',
        // Hospital de destino
        localConsulta: 'Hospital de Base de São José do Rio Preto',
        // Ponto de saída do paciente
        localSaida: 'Residência',
        // Horário agendado da consulta
        horarioConsulta: '14:30',
        // Nome do acompanhante cadastrado
        nomeAcompanhante: 'José Aparecido',
        // Status inicial: 0 (Aguardando)
        status: 0,
        // Data e hora de criação do registro
        criadoEm: DateTime.now(),
      // Fechamento do PacienteModel
      ),
    // Fechamento do Stream.value
    );
  // Fechamento do método _carregarPaciente
  }

  // Método que constrói a árvore de widgets da tela do paciente
  @override
  // Recebe o contexto de renderização do Flutter
  Widget build(BuildContext context) {
    // Construtor reativo baseado na Stream de dados do paciente
    return StreamBuilder<PacienteModel?>(
      // Conecta o construtor à stream de dados do paciente
      stream: _carregarPaciente(),
      // Construtor da interface baseado no snapshot da stream
      builder: (context, snapshot) {
        // Estado de carregamento inicial
        // Se a stream ainda estiver aguardando conexão e não houver dados em cache
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          // Exibe tela com fundo branco e indicador de progresso centralizado
          return const Scaffold(
            // Cor de fundo branca
            backgroundColor: Colors.white,
            // Corpo com círculo de progresso
            body: Center(child: CircularProgressIndicator()),
          // Fechamento do Scaffold de carregamento
          );
        // Fechamento do if de aguardando
        }

        // Extrai o objeto paciente do snapshot atual
        final paciente = snapshot.data;

        // Caso nenhum registro seja localizado
        // Se o paciente for nulo (não encontrado no banco de dados)
        if (paciente == null) {
          // Renderiza tela informativa de ausência de dados
          return Scaffold(
            // Cor de fundo branca padronizada
            backgroundColor: Colors.white,
            // Barra de navegação com título
            appBar: AppBar(title: const Text('Painel do Paciente')),
            // Corpo centralizado com mensagem explicativa
            body: const Center(
              // Texto informativo em tom cinza
              child: Text(
                // Mensagem de dados ausentes
                'Nenhum dado de paciente encontrado.',
                // Estilo tipográfico com cor suave
                style: TextStyle(color: Color(0xFF64748B)),
              // Fechamento do Text
              ),
            // Fechamento do Center
            ),
          // Fechamento do Scaffold
          );
        // Fechamento do if de paciente nulo
        }

        // Renderiza a estrutura completa da tela quando os dados do paciente estão disponíveis
        return Scaffold(
          // Fundo padronizado com as demais telas do aplicativo
          backgroundColor: const Color(0xFFF8FAFC),
          // Barra de navegação superior da tela com identidade visual consistente
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 2,
            // Botão de navegação na extremidade esquerda
            leading: IconButton(
              // Ícone com seta de retrocesso
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              // Ação disparada ao clicar no botão de voltar
              onPressed: () {
                // Se puder desempilhar rota atual, volta para a tela anterior
                if (Navigator.of(context).canPop()) {
                  // Desempilha a rota atual
                  Navigator.of(context).pop();
                // Caso contrário, substitui a rota pela página raiz
                } else {
                  // Navega para a rota raiz '/'
                  Navigator.of(context).pushReplacementNamed('/');
                // Fechamento da condicional if/else
                }
              // Fechamento do callback onPressed
              },
            // Fechamento do IconButton
            ),
            // Título central da barra de navegação
            title: const Text(
              'Painel do Paciente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                key: const Key('botaoLogoutPaciente'),
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
            ],
          // Fechamento do AppBar
          ),
          // Layout responsivo adaptável a 100% da largura da tela, assim como a Lista de Passageiros
          // Área protegida contra entalhes e barras de status do sistema
          body: SafeArea(
            // Habilita rolagem vertical para comportar todos os blocos e cartões
            child: SingleChildScrollView(
              // Margem interna uniforme de 16 pixels ao redor do conteúdo
              padding: const EdgeInsets.all(16.0),
              // Coluna que empilha os blocos verticalmente
              child: Column(
                // Estende os filhos horizontalmente ocupando toda a largura da tela
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // Lista de widgets filhos da tela do paciente
                children: [
                  // 1. COMPONENTE: Card de Identificação do Paciente
                  // Exibe nome, CPF e status com avatar
                  CardIdentificacaoPaciente(
                    // Nome completo do paciente
                    nome: paciente.nome,
                    // CPF do paciente
                    cpf: paciente.cpf,
                    // Status numérico da etapa da viagem
                    status: paciente.status,
                  // Fechamento do CardIdentificacaoPaciente
                  ),
                  // Espaçamento vertical entre os cards
                  const SizedBox(height: 16),

                  // 2. COMPONENTE: Card com Dados da Consulta
                  // Exibe local da consulta, horário, ponto de saída, endereço e acompanhante
                  CardDadosConsulta(
                    // Hospital ou unidade de atendimento
                    localConsulta: paciente.localConsulta,
                    // Horário agendado do atendimento médico
                    horarioConsulta: paciente.horarioConsulta,
                    // Ponto de partida do paciente
                    localSaida: paciente.localSaida,
                    // Endereço de residência do passageiro
                    enderecoPaciente: paciente.enderecoPaciente,
                    // Nome do acompanhante se cadastrado
                    nomeAcompanhante: paciente.nomeAcompanhante,
                  // Fechamento do CardDadosConsulta
                  ),
                  // Espaçamento vertical entre os cards
                  const SizedBox(height: 16),

                  // 3. BOTÕES DE AÇÃO: Primário ("Estou Pronto") e Secundário ("Fui embora")
                  // Linha horizontal contendo os botões de ação do paciente
                  Row(
                    // Filhos dispostos lado a lado
                    children: [
                      // Botão Secundário: Fui embora (Carona)
                      // Primeiro botão ocupando metade proporcional da linha
                      Expanded(
                        // Caixa com altura fixa para toque confortável
                        child: SizedBox(
                          // Altura de 52 pixels
                          height: 52,
                          // Botão com borda avermelhada para cancelamento / carona
                          child: OutlinedButton.icon(
                            // Estilização do botão delineado
                            style: OutlinedButton.styleFrom(
                              // Borda vermelha personalizada
                              side: const BorderSide(
                                // Cor vermelha escura
                                color: Color(0xFFB83227),
                                // Espessura da borda
                                width: 1.5,
                              // Fechamento do BorderSide
                              ),
                              // Cantos arredondados
                              shape: RoundedRectangleBorder(
                                // Raio de arredondamento de 12 pixels
                                borderRadius: BorderRadius.circular(12),
                              // Fechamento do RoundedRectangleBorder
                              ),
                              // Cor de fundo do botão com tom esbranquiçado sutil
                              backgroundColor: const Color(0xFFFFFDF8),
                            // Fechamento do OutlinedButton.styleFrom
                            ),
                            // Ícone de cancelamento
                            icon: const Icon(
                              // Ícone de X circunscrito
                              Icons.cancel_outlined,
                              // Cor vermelha do ícone
                              color: Color(0xFFB83227),
                              // Tamanho do ícone
                              size: 18,
                            // Fechamento do Icon
                            ),
                            // Rótulo de texto do botão
                            label: const Text(
                              // Texto exibido no botão
                              'Fui embora',
                              // Estilização tipográfica do texto
                              style: TextStyle(
                                // Cor vermelha correspondente
                                color: Color(0xFFB83227),
                                // Peso em negrito
                                fontWeight: FontWeight.bold,
                                // Tamanho da fonte
                                fontSize: 13,
                              // Fechamento do TextStyle
                              ),
                            // Fechamento do Text
                            ),
                            // Ação ao pressionar o botão
                            onPressed: () {
                              // TODO: Implementar backend do botão Fui embora / Carona (Issue #19)
                              // Ação de aviso de carona/desistência a ser implementada na Issue 19
                            // Fechamento do callback onPressed
                            },
                          // Fechamento do OutlinedButton.icon
                          ),
                        // Fechamento do SizedBox
                        ),
                      // Fechamento do Expanded do botão secundário
                      ),
                      // Espaçamento horizontal entre os dois botões
                      const SizedBox(width: 12),

                      // Botão Primário: Estou Pronto
                      // Segundo botão ocupando metade proporcional da linha
                      Expanded(
                        // Caixa com altura fixa para toque confortável
                        child: SizedBox(
                          // Altura de 52 pixels
                          height: 52,
                          // Botão com fundo preenchido escuro
                          child: ElevatedButton.icon(
                            // Estilização do botão elevado
                            style: ElevatedButton.styleFrom(
                              // Fundo escuro azulado elegante
                              backgroundColor: const Color(0xFF0F172A),
                              // Cor de primeiro plano (texto e ícones)
                              foregroundColor: Colors.white,
                              // Cantos arredondados
                              shape: RoundedRectangleBorder(
                                // Raio de arredondamento de 12 pixels
                                borderRadius: BorderRadius.circular(12),
                              // Fechamento do RoundedRectangleBorder
                              ),
                              // Elevação sutil de sombra
                              elevation: 2,
                            // Fechamento do ElevatedButton.styleFrom
                            ),
                            // Ícone de confirmação com check circunscrito
                            icon: const Icon(
                              // Ícone de check
                              Icons.check_circle_outline,
                              // Tamanho de 18 pixels
                              size: 18,
                              // Cor branca para contraste
                              color: Colors.white,
                            // Fechamento do Icon
                            ),
                            // Rótulo textual do botão
                            label: const Text(
                              // Texto indicativo
                              'Estou Pronto',
                              // Estilização tipográfica em negrito
                              style: TextStyle(
                                // Peso em negrito
                                fontWeight: FontWeight.bold,
                                // Tamanho da fonte
                                fontSize: 13,
                              // Fechamento do TextStyle
                              ),
                            // Fechamento do Text
                            ),
                            // Ação ao pressionar o botão
                            onPressed: () {
                              // TODO: Implementar backend do botão Estou Pronto (Issue #19)
                              // Ação de confirmação de prontidão a ser implementada na Issue 19
                            // Fechamento do callback onPressed
                            },
                          // Fechamento do ElevatedButton.icon
                          ),
                        // Fechamento do SizedBox
                        ),
                      // Fechamento do Expanded do botão primário
                      ),
                    // Fechamento da lista children da Row
                    ],
                  // Fechamento da Row
                  ),
                  // Espaçamento vertical entre os botões e o card de rastreamento
                  const SizedBox(height: 16),

                  // 4. COMPONENTE: Card com Mapa de Rastreamento dos Motoristas Ativos
                  // Exibe a localização em tempo real de todos os motoristas em trânsito
                  CardTrackingPaciente(
                    motoristasStreamOverride: widget.motoristasStreamOverride,
                  ),
                // Fechamento da lista children da Column
                ],
              // Fechamento da Column
              ),
            // Fechamento do SingleChildScrollView
            ),
          // Fechamento do SafeArea
          ),
        // Fechamento do Scaffold
        );
      // Fechamento do builder do StreamBuilder
      },
    // Fechamento do StreamBuilder
    );
  // Fechamento do método build
  }
// Fechamento da classe _PacienteState
}
