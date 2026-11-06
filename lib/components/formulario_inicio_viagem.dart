// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/formulario_inicio_viagem.dart
// Camada: Apresentação / Componentes e Telas de Operação (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa o formulário de início de viagem (FormularioInicioViagem) e sua tela
// correspondente (TelaInicioViagem). Permite ao motorista selecionar o veículo da frota
// municipal disponível via StreamBuilder reativo, escolher o município de destino,
// validar em tempo real a quilometragem inicial (impedindo redução e acima do teto de
// plausibilidade), tratar cenários de corrida e concorrência com outros condutores
// e disparar o início oficial da viagem através de ViagemService.
//
// PARA QUE SERVE NO PROJETO:
// É o formulário obrigatório de partida para a frota municipal do TFD (Tratamento
// Fora de Domicílio), garantindo controle de quilometragem e alocação segura de veículos.
//
// ONDE É USADO NO PROJETO:
// - lib/main.dart (rota inicial ou teste de início de viagem)
// - test/formulario_inicio_viagem_test.dart (testes de validação de formulário e concorrência)
// - test/widget_test.dart (testes de integração da navegação)
//
// DE ONDE RECEBE DADOS:
// - ViagemService (fluxo carregarVeiculosDisponiveis() ou stream injetada via veiculosStreamOverride)
// - Entradas do usuário no formulário e parâmetros de teste (forcarCarregando, forcarErro, forcarVeiculos)
//
// O QUE EXPORTA / EXPÕE:
// - class FormularioInicioViagem extends StatefulWidget
// - class TelaInicioViagem extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 8d73cce pela equipe do projeto como parte da issue #17
// ("formulário de início de viagem"). Não provém de template ou scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart' e 'package:flutter/services.dart'.
// Efeitos colaterais: invoca ViagemService.iniciarViagem() (com alterações no Firestore
// e na memória) e redireciona a navegação via Navigator.pushReplacementNamed ou Navigator.pop.
// ============================================================================

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';
// Importa utilitários de serviços e formatadores de texto do Flutter
import 'package:flutter/services.dart';

// Linha em branco separadora entre pacotes do framework e modelos internos
// Importa o modelo de dados de veículos
import '../models/veiculo_model.dart';
// Importa o modelo de dados de viagens
import '../models/viagem_model.dart';
// Importa as regras de negócio de validação de viagens
import '../services/validacao_viagem.dart';
// Importa o serviço de gerenciamento do ciclo de vida das viagens
import '../services/viagem_service.dart';

// Linha em branco separadora entre imports e FormularioInicioViagem
// Comentário original do autor mantido byte a byte:
// Formulário para seleção de veículo, cidade de destino e inserção de quilometragem inicial
// Declaração do widget StatefulWidget FormularioInicioViagem
class FormularioInicioViagem extends StatefulWidget {
  // Comentário original do autor mantido byte a byte:
  // Callback executado ao iniciar a viagem com sucesso
  // Callback notificado quando a viagem é criada com sucesso
  final ValueChanged<ViagemModel>? onViagemIniciada;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Stream para fornecimento da lista de veículos
  // Stream customizada opcional para injeção de dependência em testes
  final Stream<List<VeiculoModel>>? veiculosStreamOverride;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Identificador do motorista autenticado
  // ID do motorista condutor da viagem
  final String motoristaId;
  // Comentário original do autor mantido byte a byte:
  // Nome do motorista autenticado
  // Nome completo do motorista condutor da viagem
  final String motoristaNome;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Indicador para exibir estado de carregamento
  // Flag para forçar o estado de carregamento em testes visuais
  final bool forcarCarregando;
  // Comentário original do autor mantido byte a byte:
  // Mensagem para exibir estado de erro
  // Texto para forçar exibição de erro em testes visuais
  final String? forcarErro;
  // Comentário original do autor mantido byte a byte:
  // Lista fixa de veículos para exibição
  // Lista estática para forçar veículos em testes visuais
  final List<VeiculoModel>? forcarVeiculos;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados
  const FormularioInicioViagem({
    // Chave opcional do widget
    super.key,
    // Callback de viagem iniciada
    this.onViagemIniciada,
    // Stream de veículos injetável
    this.veiculosStreamOverride,
    // ID do motorista com valor padrão
    this.motoristaId = 'motorista_atual',
    // Nome do motorista com valor padrão
    this.motoristaNome = 'Motorista da Saúde',
    // Flag de carregamento forçado (padrão falso)
    this.forcarCarregando = false,
    // Mensagem de erro forçado
    this.forcarErro,
    // Lista forçada de veículos
    this.forcarVeiculos,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e createState

  // Cria o estado mutável associado a este widget
  @override
  // Instancia a classe de estado _FormularioInicioViagemState
  State<FormularioInicioViagem> createState() => _FormularioInicioViagemState();
// Fecha a classe FormularioInicioViagem
}

// Linha em branco separadora entre FormularioInicioViagem e _FormularioInicioViagemState
// Classe de estado privada que controla o formulário de início de viagem
class _FormularioInicioViagemState extends State<FormularioInicioViagem> {
  // Comentário original do autor mantido byte a byte:
  // Instância do serviço de viagens
  // Referência para o singleton ViagemService
  final ViagemService _viagemService = ViagemService();

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Controlador de texto do campo de quilometragem
  // Controlador de texto para captura e validação da quilometragem
  final TextEditingController _kmController = TextEditingController();

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Veículo selecionado pelo motorista no Dropdown
  // Instância do veículo escolhido atualmente no dropdown
  VeiculoModel? _veiculoSelecionado;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Stream com a lista de veículos disponíveis
  // Stream reativa da frota de veículos
  late final Stream<List<VeiculoModel>> _veiculosStream;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Cidades de destino disponíveis para seleção
  // Lista constante de cidades destino atendidas pelo transporte
  final List<String> _cidadesDestino = const [
    'São José do Rio Preto',
    'Mirassol',
    'Monte Aprazível',
  ];
  // Comentário original do autor mantido byte a byte:
  // Cidade de destino atualmente selecionada
  // String que armazena a cidade selecionada no dropdown
  late String _cidadeSelecionada;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Mensagem de erro de validação do campo de quilometragem
  // String com mensagem de erro do campo de KM
  String? _erroKm;
  // Comentário original do autor mantido byte a byte:
  // Mensagem de erro geral ou de concorrência
  // String com mensagem de erro geral ou de conflito de frota
  String? _erroGeral;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Indicador de requisição em andamento
  // Booleano indicando operação assíncrona de início de viagem em curso
  bool _salvando = false;

  // Linha em branco separadora entre atributos e initState

  // Ciclo de vida: inicialização de estado
  @override
  // Inicializa cidade padrão e stream de veículos
  void initState() {
    // Executa a inicialização padrão da superclasse
    super.initState();
    // Comentário original do autor mantido byte a byte:
    // Inicializa com a primeira cidade da lista
    // Define a primeira cidade da lista como padrão selecionado
    _cidadeSelecionada = _cidadesDestino.first;
    // Comentário original do autor mantido byte a byte:
    // Inicializa o fluxo de veículos com o parâmetro fornecido ou o método do serviço
    // Configura a stream de veículos com o override ou carregamento do serviço
    _veiculosStream =
        widget.veiculosStreamOverride ??
        _viagemService.carregarVeiculosDisponiveis(
          motoristaId: widget.motoristaId,
        );

    // Linha em branco separadora entre configuração da stream e validação forçada
    // Comentário original do autor mantido byte a byte:
    // Valida a lista forçada de veículos quando fornecida
    // Valida se a lista forçada contém veículos disponíveis
    if (widget.forcarVeiculos != null && widget.forcarVeiculos!.isNotEmpty) {
      final disponivel = widget.forcarVeiculos!
          .where((v) => !v.emUso)
          .firstOrNull;
      if (disponivel != null) {
        // Comentário original do autor mantido byte a byte:
        // Mantém seleção vazia para exigir escolha pelo usuário
      }
    }
  }

  // Linha em branco separadora entre initState e dispose

  // Ciclo de vida: descarte de recursos
  @override
  // Libera os recursos alocados
  void dispose() {
    // Comentário original do autor mantido byte a byte:
    // Libera os recursos do controlador de texto
    // Descarta o controlador de KM
    _kmController.dispose();
    // Finaliza na superclasse
    super.dispose();
  }

  // Linha em branco separadora entre dispose e _validarKmEmTempoReal

  // Comentário original do autor mantido byte a byte:
  // Executa a validação da quilometragem informada com base no veículo selecionado
  // Valida o texto digitado de KM em tempo real
  void _validarKmEmTempoReal(String valor) {
    // Exige seleção prévia de veículo antes de validar o odômetro
    if (_veiculoSelecionado == null) {
      setState(() {
        _erroKm = 'Selecione um veículo primeiro.';
      });
      return;
    }

    // Executa validação de regras de negócio de quilometragem
    final resultado = ValidacaoViagem.validarQuilometragem(
      valorDigitado: valor,
      ultimaKmRegistrada: _veiculoSelecionado!.quilometragemAtual,
    );

    // Atualiza o estado da interface com a mensagem de validação
    setState(() {
      _erroKm = resultado.valido ? null : resultado.mensagemErro;
      _erroGeral = null;
    });
  }

  // Linha em branco separadora entre validação de KM e _submeterInicioViagem

  // Comentário original do autor mantido byte a byte:
  // Valida os campos preenchidos e envia a requisição de início de viagem ao serviço
  // Método assíncrono para validação final e início da rota
  Future<void> _submeterInicioViagem() async {
    // Comentário original do autor mantido byte a byte:
    // Valida se há veículo selecionado
    // Valida se o veículo foi escolhido
    if (_veiculoSelecionado == null) {
      setState(() {
        _erroGeral = 'Por favor, selecione um veículo disponível.';
      });
      return;
    }

    // Linha em branco separadora entre validação de veículo e validação de KM
    // Comentário original do autor mantido byte a byte:
    // Valida a quilometragem digitada contra o registro do veículo
    // Valida o odômetro digitado
    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: _kmController.text,
      ultimaKmRegistrada: _veiculoSelecionado!.quilometragemAtual,
    );

    // Se o odômetro for inválido, exibe erro e interrompe
    if (!validacaoKm.valido) {
      setState(() {
        _erroKm = validacaoKm.mensagemErro;
      });
      return;
    }

    // Converte o texto da quilometragem para número inteiro
    final kmDigitada = int.parse(_kmController.text.trim());

    // Linha em branco separadora entre parse e ativação de loading
    // Ativa estado de carregamento
    setState(() {
      _salvando = true;
      _erroGeral = null;
    });

    // Linha em branco separadora entre loading e chamada assíncrona
    // Bloco de tentativa para disparar a viagem no serviço
    try {
      // Comentário original do autor mantido byte a byte:
      // Envia a solicitação de início de viagem para o serviço de viagens
      // Invoca o serviço de viagens para iniciar a rota e persistir no Firestore
      final resultado = await _viagemService.iniciarViagem(
        veiculo: _veiculoSelecionado!,
        kmInicial: kmDigitada,
        cidadeDestino: _cidadeSelecionada,
        motoristaId: widget.motoristaId,
        motoristaNome: widget.motoristaNome,
      );

      // Aborta caso o widget tenha sido desmontado durante a requisição
      if (!mounted) return;

      // Linha em branco separadora entre checagem de montagem e tratamento de falha
      // Comentário original do autor mantido byte a byte:
      // Trata retorno sem sucesso exibindo a mensagem recebida e limpando a seleção
      // Se a operação falhar (ex: conflito de concorrência com outro motorista), exibe erro
      if (!resultado.sucesso) {
        setState(() {
          _salvando = false;
          _erroGeral = resultado.mensagemErro ?? 'Erro ao iniciar viagem.';
          _veiculoSelecionado = null;
          _kmController.clear();
        });
        return;
      }

      // Linha em branco separadora entre falha e sucesso
      // Desativa o indicador de salvamento
      setState(() {
        _salvando = false;
      });

      // Linha em branco separadora entre setState e callback
      // Comentário original do autor mantido byte a byte:
      // Executa o callback informado passando a viagem criada
      // Notifica o callback se fornecido
      if (widget.onViagemIniciada != null) {
        widget.onViagemIniciada!(resultado.viagem!);
      // Caso contrário, fecha a tela se houver rota anterior
      } else if (Navigator.of(context).canPop()) {
        // Comentário original do autor mantido byte a byte:
        // Fecha a rota atual retornando o objeto da viagem
        // Devolve o objeto ViagemModel na navegação
        Navigator.of(context).pop(resultado.viagem);
      }
    // Captura falhas de comunicação e rede
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erroGeral = 'Falha de comunicação: $e';
        });
      }
    }
  }

  // Linha em branco separadora entre métodos de submissão e build

  // Sobrescrita do método build para montagem visual do formulário
  @override
  // Constrói a estrutura visual do card de formulário
  Widget build(BuildContext context) {
    // Comentário original do autor mantido byte a byte:
    // Constrói a estrutura visual do card com alinhamento central
    // Centraliza o card na tela
    return Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Comentário original do autor mantido byte a byte:
                // Linha superior com ícone e textos de cabeçalho
                // Cabeçalho visual com ícone de automóvel e textos
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car_filled,
                        color: Color(0xFF0F172A),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Iniciar Viagem',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Informe o veículo e quilometragem',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),

                // Comentário original do autor mantido byte a byte:
                // Exibe mensagem de erro geral ou de concorrência quando presente
                // Banner de erro de concorrência ou comunicação
                if (_erroGeral != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _erroGeral!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Comentário original do autor mantido byte a byte:
                // Seção de seleção do veículo da frota
                // Rótulo da seção de veículos
                const Text(
                  'Veículo da Frota',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                _construirDropdownVeiculos(),
                const SizedBox(height: 16),

                // Comentário original do autor mantido byte a byte:
                // Seção de seleção da cidade de destino
                // Rótulo da seção de cidade de destino
                const Text(
                  'Cidade de Destino',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                // Dropdown de cidades de destino
                DropdownButtonFormField<String>(
                  initialValue: _cidadeSelecionada,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: Color(0xFF0F172A),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  items: _cidadesDestino.map((cidade) {
                    return DropdownMenuItem<String>(
                      value: cidade,
                      child: Text(cidade, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (novo) {
                    if (novo != null) {
                      setState(() {
                        _cidadeSelecionada = novo;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Comentário original do autor mantido byte a byte:
                // Seção com rótulo e valor da última quilometragem registrada
                // Linha informativa com rótulo de KM inicial e última quilometragem
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Quilometragem Inicial',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (_veiculoSelecionado != null)
                      Text(
                        'Última: ${_veiculoSelecionado!.quilometragemAtual} km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey[700],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Comentário original do autor mantido byte a byte:
                // Campo de entrada de texto numérico da quilometragem
                // Campo de digitação de quilometragem inicial do veículo
                TextField(
                  controller: _kmController,
                  enabled: _veiculoSelecionado != null && !_salvando,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _validarKmEmTempoReal,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.speed_outlined,
                      size: 20,
                      color: Color(0xFF0F172A),
                    ),
                    suffixText: 'km',
                    suffixStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    hintText: _veiculoSelecionado != null
                        ? 'Ex: ${_veiculoSelecionado!.quilometragemAtual}'
                        : 'Selecione o veículo acima',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                    helperText: _veiculoSelecionado != null
                        ? 'Referência do painel: >= ${_veiculoSelecionado!.quilometragemAtual} km'
                        : null,
                    helperStyle: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    errorText: _erroKm,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    filled: _veiculoSelecionado == null,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 24),

                // Comentário original do autor mantido byte a byte:
                // Botão de envio para iniciar a viagem
                // Botão de ação de submissão do formulário
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    key: const Key('botaoIniciarViagem'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _salvando ? null : _submeterInicioViagem,
                    child: _salvando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Iniciar Viagem',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Linha em branco separadora entre build e _construirDropdownVeiculos
  // Comentário original do autor mantido byte a byte:
  // Constrói o widget de seleção de veículos de acordo com o estado dos dados
  // Método auxiliar para construir a área de seleção de veículos da frota
  Widget _construirDropdownVeiculos() {
    // Comentário original do autor mantido byte a byte:
    // Renderiza indicador de progresso quando o estado forçado de carregamento estiver ativo
    // Renderiza layout de carregamento forçado
    if (widget.forcarCarregando) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Carregando veículos disponíveis...',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }

    // Linha em branco separadora entre carregando forçado e erro forçado
    // Comentário original do autor mantido byte a byte:
    // Renderiza caixa de mensagem de erro quando o estado forçado de erro estiver ativo
    // Renderiza caixa de erro forçado
    if (widget.forcarErro != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.forcarErro!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade900),
              ),
            ),
          ],
        ),
      );
    }

    // Linha em branco separadora entre erro forçado e veículos forçados
    // Comentário original do autor mantido byte a byte:
    // Renderiza a lista filtrada quando veículos fixos forem fornecidos
    // Renderiza a lista forçada de veículos
    if (widget.forcarVeiculos != null) {
      final veiculosDisponiveis = widget.forcarVeiculos!
          .where((v) => !v.emUso)
          .toList();
      return _renderizarDropdownOuVazio(veiculosDisponiveis);
    }

    // Linha em branco separadora entre veículos forçados e StreamBuilder
    // Comentário original do autor mantido byte a byte:
    // Constrói o StreamBuilder a partir do fluxo de veículos
    // Resolve o fluxo reativo da frota
    final stream = widget.veiculosStreamOverride ?? _veiculosStream;

    // Constrói o StreamBuilder escutando as atualizações da frota
    return StreamBuilder<List<VeiculoModel>>(
      stream: stream,
      builder: (context, snapshot) {
        // Comentário original do autor mantido byte a byte:
        // Exibe indicador de progresso durante o carregamento inicial da stream
        // Trata estado de espera inicial
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Carregando veículos disponíveis...',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          );
        }

        // Linha em branco separadora entre espera e erro da stream
        // Comentário original do autor mantido byte a byte:
        // Exibe mensagem de erro caso o fluxo retorne erro
        // Trata falha no carregamento dos dados da stream
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Erro ao carregar lista de veículos.',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        }

        // Linha em branco separadora entre erro e extração dos dados
        // Extrai a lista de veículos retornada
        final veiculos = snapshot.data ?? [];
        // Renderiza o menu suspenso ou a mensagem de ausência de veículos
        return _renderizarDropdownOuVazio(veiculos);
      },
    );
  }

  // Linha em branco separadora entre _construirDropdownVeiculos e _renderizarDropdownOuVazio
  // Comentário original do autor mantido byte a byte:
  // Avalia a disponibilidade da lista e retorna o menu dropdown ou mensagem de lista vazia
  // Avalia se há veículos liberados ou se a frota está esgotada
  Widget _renderizarDropdownOuVazio(List<VeiculoModel> veiculos) {
    // Comentário original do autor mantido byte a byte:
    // Limpa a seleção e atualiza a mensagem caso o veículo selecionado não esteja mais na lista
    // Desseleciona se o carro tiver entrado em uso por outro condutor em tempo real
    if (_veiculoSelecionado != null &&
        !veiculos.any((v) => v.id == _veiculoSelecionado!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _veiculoSelecionado = null;
            _kmController.clear();
            _erroGeral = 'O veículo selecionado acabou de entrar em uso por outro motorista. Por favor, selecione outro veículo.';
          });
        }
      });
    }

    // Linha em branco separadora entre desseleção e checagem de frota vazia
    // Comentário original do autor mantido byte a byte:
    // Exibe caixa informativa quando a lista de veículos está sem itens
    // Exibe aviso visual caso não haja carros disponíveis
    if (veiculos.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Nenhum veículo disponível no momento.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Linha em branco separadora entre aviso de vazio e renderização da lista
    // Comentário original do autor mantido byte a byte:
    // Exibe o menu suspenso com os veículos disponíveis
    // Retorna o DropdownButtonFormField com os veículos da frota
    return _renderizarDropdownLista(veiculos);
  }

  // Linha em branco separadora entre _renderizarDropdownOuVazio e _renderizarDropdownLista
  // Comentário original do autor mantido byte a byte:
  // Constrói o campo DropdownButtonFormField preenchido com a lista de veículos
  // Constrói o DropdownButtonFormField populado com os itens da frota
  Widget _renderizarDropdownLista(List<VeiculoModel> veiculos) {
    return DropdownButtonFormField<VeiculoModel>(
      key: ValueKey(_veiculoSelecionado?.id),
      initialValue: _veiculoSelecionado,
      isExpanded: true,
      hint: const Text(
        'Selecione um veículo',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.directions_car_outlined,
          size: 20,
          color: Color(0xFF0F172A),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      items: veiculos.map((veiculo) {
        return DropdownMenuItem<VeiculoModel>(
          value: veiculo,
          child: Text(
            '${veiculo.placa} • ${veiculo.modelo} (${veiculo.capacidade} lug)',
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _salvando
          ? null
          : (VeiculoModel? selecionado) {
              setState(() {
                _veiculoSelecionado = selecionado;
                _erroGeral = null;
                // Comentário original do autor mantido byte a byte:
                // Preenche o campo de texto com a quilometragem atual do veículo selecionado
                // Popula o campo com a leitura mais recente de KM do veículo
                if (selecionado != null) {
                  _kmController.text = selecionado.quilometragemAtual
                      .toString();
                  _validarKmEmTempoReal(_kmController.text);
                } else {
                  _kmController.clear();
                  _erroKm = null;
                }
              });
            },
    );
  }
}

// Linha em branco separadora entre FormularioInicioViagem e TelaInicioViagem
// Comentário original do autor mantido byte a byte:
// Tela de início de viagem exibida na rota inicial do aplicativo
// Widget StatelessWidget que hospeda o formulário com Scaffold e AppBar
class TelaInicioViagem extends StatelessWidget {
  // Construtor constante com chave de identificação do widget
  const TelaInicioViagem({super.key});

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para montagem da tela completa
  @override
  // Constrói o Scaffold com barra superior e corpo
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      // Barra superior com título e estilo oficial
      appBar: AppBar(
        title: const Text('Início da Viagem'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      // Área segura respeitando barras do sistema
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            // Instancia o formulário de início conectando a navegação
            child: FormularioInicioViagem(
              onViagemIniciada: (novaViagem) {
                // Comentário original do autor mantido byte a byte:
                // Redireciona para a tela do motorista passando os dados da viagem nos argumentos
                // Navega para a tela do motorista substituindo a rota atual
                Navigator.of(context)
                    .pushReplacementNamed('/motorista', arguments: novaViagem);
              },
            ),
          ),
        ),
      ),
    );
  }
}
