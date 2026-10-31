import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import '../services/validacao_viagem.dart';
import '../services/viagem_service.dart';

// Formulário para seleção de veículo, cidade de destino e inserção de quilometragem inicial
class FormularioInicioViagem extends StatefulWidget {
  // Callback executado ao iniciar a viagem com sucesso
  final ValueChanged<ViagemModel>? onViagemIniciada;

  // Stream para fornecimento da lista de veículos
  final Stream<List<VeiculoModel>>? veiculosStreamOverride;

  // Identificador do motorista autenticado
  final String motoristaId;
  // Nome do motorista autenticado
  final String motoristaNome;

  // Indicador para exibir estado de carregamento
  final bool forcarCarregando;
  // Mensagem para exibir estado de erro
  final String? forcarErro;
  // Lista fixa de veículos para exibição
  final List<VeiculoModel>? forcarVeiculos;

  const FormularioInicioViagem({
    super.key,
    this.onViagemIniciada,
    this.veiculosStreamOverride,
    this.motoristaId = 'motorista_atual',
    this.motoristaNome = 'Motorista da Saúde',
    this.forcarCarregando = false,
    this.forcarErro,
    this.forcarVeiculos,
  });

  @override
  State<FormularioInicioViagem> createState() => _FormularioInicioViagemState();
}

class _FormularioInicioViagemState extends State<FormularioInicioViagem> {
  // Instância do serviço de viagens
  final ViagemService _viagemService = ViagemService();

  // Controlador de texto do campo de quilometragem
  final TextEditingController _kmController = TextEditingController();

  // Veículo selecionado pelo motorista no Dropdown
  VeiculoModel? _veiculoSelecionado;

  // Stream com a lista de veículos disponíveis
  late final Stream<List<VeiculoModel>> _veiculosStream;

  // Cidades de destino disponíveis para seleção
  final List<String> _cidadesDestino = const [
    'São José do Rio Preto',
    'Mirassol',
    'Monte Aprazível',
  ];
  // Cidade de destino atualmente selecionada
  late String _cidadeSelecionada;

  // Mensagem de erro de validação do campo de quilometragem
  String? _erroKm;
  // Mensagem de erro geral ou de concorrência
  String? _erroGeral;

  // Indicador de requisição em andamento
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Inicializa com a primeira cidade da lista
    _cidadeSelecionada = _cidadesDestino.first;
    // Inicializa o fluxo de veículos com o parâmetro fornecido ou o método do serviço
    _veiculosStream =
        widget.veiculosStreamOverride ??
        _viagemService.carregarVeiculosDisponiveis(
          motoristaId: widget.motoristaId,
        );

    // Valida a lista forçada de veículos quando fornecida
    if (widget.forcarVeiculos != null && widget.forcarVeiculos!.isNotEmpty) {
      final disponivel = widget.forcarVeiculos!
          .where((v) => !v.emUso)
          .firstOrNull;
      if (disponivel != null) {
        // Mantém seleção vazia para exigir escolha pelo usuário
      }
    }
  }

  @override
  void dispose() {
    // Libera os recursos do controlador de texto
    _kmController.dispose();
    super.dispose();
  }

  // Executa a validação da quilometragem informada com base no veículo selecionado
  void _validarKmEmTempoReal(String valor) {
    if (_veiculoSelecionado == null) {
      setState(() {
        _erroKm = 'Selecione um veículo primeiro.';
      });
      return;
    }

    final resultado = ValidacaoViagem.validarQuilometragem(
      valorDigitado: valor,
      ultimaKmRegistrada: _veiculoSelecionado!.quilometragemAtual,
    );

    setState(() {
      _erroKm = resultado.valido ? null : resultado.mensagemErro;
      _erroGeral = null;
    });
  }

  // Valida os campos preenchidos e envia a requisição de início de viagem ao serviço
  Future<void> _submeterInicioViagem() async {
    // Valida se há veículo selecionado
    if (_veiculoSelecionado == null) {
      setState(() {
        _erroGeral = 'Por favor, selecione um veículo disponível.';
      });
      return;
    }

    // Valida a quilometragem digitada contra o registro do veículo
    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: _kmController.text,
      ultimaKmRegistrada: _veiculoSelecionado!.quilometragemAtual,
    );

    if (!validacaoKm.valido) {
      setState(() {
        _erroKm = validacaoKm.mensagemErro;
      });
      return;
    }

    final kmDigitada = int.parse(_kmController.text.trim());

    setState(() {
      _salvando = true;
      _erroGeral = null;
    });

    try {
      // Envia a solicitação de início de viagem para o serviço de viagens
      final resultado = await _viagemService.iniciarViagem(
        veiculo: _veiculoSelecionado!,
        kmInicial: kmDigitada,
        cidadeDestino: _cidadeSelecionada,
        motoristaId: widget.motoristaId,
        motoristaNome: widget.motoristaNome,
      );

      if (!mounted) return;

      // Trata retorno sem sucesso exibindo a mensagem recebida e limpando a seleção
      if (!resultado.sucesso) {
        setState(() {
          _salvando = false;
          _erroGeral = resultado.mensagemErro ?? 'Erro ao iniciar viagem.';
          _veiculoSelecionado = null;
          _kmController.clear();
        });
        return;
      }

      setState(() {
        _salvando = false;
      });

      // Executa o callback informado passando a viagem criada
      if (widget.onViagemIniciada != null) {
        widget.onViagemIniciada!(resultado.viagem!);
      } else if (Navigator.of(context).canPop()) {
        // Fecha a rota atual retornando o objeto da viagem
        Navigator.of(context).pop(resultado.viagem);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erroGeral = 'Falha de comunicação: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Constrói a estrutura visual do card com alinhamento central
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
                // Linha superior com ícone e textos de cabeçalho
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

                // Exibe mensagem de erro geral ou de concorrência quando presente
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

                // Seção de seleção do veículo da frota
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

                // Seção de seleção da cidade de destino
                const Text(
                  'Cidade de Destino',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
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

                // Seção com rótulo e valor da última quilometragem registrada
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
                // Campo de entrada de texto numérico da quilometragem
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

                // Botão de envio para iniciar a viagem
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

  // Constrói o widget de seleção de veículos de acordo com o estado dos dados
  Widget _construirDropdownVeiculos() {
    // Renderiza indicador de progresso quando o estado forçado de carregamento estiver ativo
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

    // Renderiza caixa de mensagem de erro quando o estado forçado de erro estiver ativo
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

    // Renderiza a lista filtrada quando veículos fixos forem fornecidos
    if (widget.forcarVeiculos != null) {
      final veiculosDisponiveis = widget.forcarVeiculos!
          .where((v) => !v.emUso)
          .toList();
      return _renderizarDropdownOuVazio(veiculosDisponiveis);
    }

    // Constrói o StreamBuilder a partir do fluxo de veículos
    final stream = widget.veiculosStreamOverride ?? _veiculosStream;

    return StreamBuilder<List<VeiculoModel>>(
      stream: stream,
      builder: (context, snapshot) {
        // Exibe indicador de progresso durante o carregamento inicial da stream
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

        // Exibe mensagem de erro caso o fluxo retorne erro
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

        final veiculos = snapshot.data ?? [];
        return _renderizarDropdownOuVazio(veiculos);
      },
    );
  }

  // Avalia a disponibilidade da lista e retorna o menu dropdown ou mensagem de lista vazia
  Widget _renderizarDropdownOuVazio(List<VeiculoModel> veiculos) {
    // Limpa a seleção e atualiza a mensagem caso o veículo selecionado não esteja mais na lista
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

    // Exibe caixa informativa quando a lista de veículos está sem itens
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

    // Exibe o menu suspenso com os veículos disponíveis
    return _renderizarDropdownLista(veiculos);
  }

  // Constrói o campo DropdownButtonFormField preenchido com a lista de veículos
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
                // Preenche o campo de texto com a quilometragem atual do veículo selecionado
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

// Tela de início de viagem exibida na rota inicial do aplicativo
class TelaInicioViagem extends StatelessWidget {
  const TelaInicioViagem({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Início da Viagem'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: FormularioInicioViagem(
              onViagemIniciada: (novaViagem) {
                // Redireciona para a tela do motorista passando os dados da viagem nos argumentos
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
