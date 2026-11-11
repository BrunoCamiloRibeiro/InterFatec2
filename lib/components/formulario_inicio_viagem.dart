import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sessao_veiculo_model.dart';
import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import '../services/validacao_viagem.dart';
import '../services/viagem_service.dart';

/// Formulário para escolha do veículo livre, cidade destino e hodômetro inicial.
class FormularioInicioViagem extends StatefulWidget {
  final ValueChanged<ViagemModel>? onViagemIniciada;
  final ValueChanged<SessaoVeiculoModel>? onVeiculoDeclarado;
  final Stream<List<VeiculoModel>>? veiculosStreamOverride;
  final String motoristaId;
  final String motoristaNome;
  final bool forcarCarregando;
  final String? forcarErro;
  final List<VeiculoModel>? forcarVeiculos;

  const FormularioInicioViagem({
    super.key,
    this.onViagemIniciada,
    this.onVeiculoDeclarado,
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
  final ViagemService _viagemService = ViagemService();
  final TextEditingController _kmController = TextEditingController();

  VeiculoModel? _veiculoSelecionado;
  late final Stream<List<VeiculoModel>> _veiculosStream;

  final List<String> _cidadesDestino = const [
    'São José do Rio Preto',
    'Mirassol',
    'Monte Aprazível',
  ];
  late String _cidadeSelecionada;

  String? _erroKm;
  String? _erroGeral;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _cidadeSelecionada = _cidadesDestino.first;
    _veiculosStream =
        widget.veiculosStreamOverride ??
        _viagemService.carregarVeiculosDisponiveis(
          motoristaId: widget.motoristaId,
        );
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  void _validarKmEmTempoReal(String valor) {
    if (_veiculoSelecionado == null) {
      setState(() => _erroKm = 'Selecione um veículo primeiro.');
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

  Future<void> _submeterInicioViagem() async {
    if (_veiculoSelecionado == null) {
      setState(
        () => _erroGeral = 'Por favor, selecione um veículo disponível.',
      );
      return;
    }

    final validacaoKm = ValidacaoViagem.validarQuilometragem(
      valorDigitado: _kmController.text,
      ultimaKmRegistrada: _veiculoSelecionado!.quilometragemAtual,
    );
    if (!validacaoKm.valido) {
      setState(() => _erroKm = validacaoKm.mensagemErro);
      return;
    }

    final kmDigitada = int.parse(_kmController.text.trim());
    setState(() {
      _salvando = true;
      _erroGeral = null;
    });

    try {
      final declaracao = await _viagemService.declararVeiculo(
        veiculo: _veiculoSelecionado!,
        kmInicial: kmDigitada,
        motoristaId: widget.motoristaId,
        motoristaNome: widget.motoristaNome,
        cidadeDestino: _cidadeSelecionada,
      );
      if (!mounted) return;

      if (!declaracao.sucesso) {
        _falharSubmissao(declaracao.mensagemErro ?? 'Erro ao declarar veículo.');
        return;
      }

      if (widget.onVeiculoDeclarado != null && declaracao.sessao != null) {
        widget.onVeiculoDeclarado!(declaracao.sessao!);
      }

      final resultado = await _viagemService.iniciarViagem(
        veiculo: _veiculoSelecionado!,
        kmInicial: kmDigitada,
        cidadeDestino: _cidadeSelecionada,
        motoristaId: widget.motoristaId,
        motoristaNome: widget.motoristaNome,
      );
      if (!mounted) return;

      if (!resultado.sucesso) {
        _falharSubmissao(resultado.mensagemErro ?? 'Erro ao iniciar viagem.');
        return;
      }

      setState(() => _salvando = false);

      if (widget.onViagemIniciada != null) {
        widget.onViagemIniciada!(resultado.viagem!);
      } else if (Navigator.of(context).canPop()) {
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

  void _falharSubmissao(String mensagem) {
    setState(() {
      _salvando = false;
      _erroGeral = mensagem;
      _veiculoSelecionado = null;
      _kmController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final telaPequena = MediaQuery.sizeOf(context).width < 360;

    return Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: telaPequena ? 16 : 20,
              vertical: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                if (_erroGeral != null) ...[
                  _construirCaixaErro(
                    _erroGeral!,
                    icone: Icons.error_outline,
                    paddingVertical: 12,
                    negrito: true,
                  ),
                  const SizedBox(height: 14),
                ],
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
                      setState(() => _cidadeSelecionada = novo);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Quilometragem Inicial',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
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
                TextField(
                  key: const Key('campoKmInicial'),
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 50),
                  child: ElevatedButton(
                    key: const Key('botaoIniciarViagem'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                              Flexible(
                                child: Text(
                                  'Iniciar Viagem',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  Widget _construirCaixaCarregandoVeiculos() {
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

  Widget _construirCaixaErro(
    String mensagem, {
    required IconData icone,
    double paddingVertical = 10,
    bool negrito = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: paddingVertical, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: negrito ? Colors.red.shade300 : Colors.red.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            negrito ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(
            icone,
            color: negrito ? Colors.red.shade800 : Colors.red.shade700,
            size: negrito ? 20 : 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(
                fontSize: 12,
                fontWeight: negrito ? FontWeight.w600 : FontWeight.normal,
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirDropdownVeiculos() {
    if (widget.forcarCarregando) return _construirCaixaCarregandoVeiculos();

    if (widget.forcarErro != null) {
      return _construirCaixaErro(
        widget.forcarErro!,
        icone: Icons.warning_amber_rounded,
      );
    }

    if (widget.forcarVeiculos != null) {
      final veiculosDisponiveis =
          widget.forcarVeiculos!.where((v) => !v.emUso).toList();
      return _renderizarDropdownOuVazio(veiculosDisponiveis);
    }

    final stream = widget.veiculosStreamOverride ?? _veiculosStream;
    return StreamBuilder<List<VeiculoModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _construirCaixaCarregandoVeiculos();
        }
        if (snapshot.hasError) {
          return _construirCaixaErro(
            'Erro ao carregar lista de veículos.',
            icone: Icons.error_outline,
          );
        }
        return _renderizarDropdownOuVazio(snapshot.data ?? []);
      },
    );
  }

  Widget _renderizarDropdownOuVazio(List<VeiculoModel> veiculos) {
    if (_veiculoSelecionado != null &&
        !veiculos.any((v) => v.id == _veiculoSelecionado!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _veiculoSelecionado = null;
            _kmController.clear();
            _erroGeral =
                'O veículo selecionado acabou de entrar em uso por outro motorista. Por favor, selecione outro veículo.';
          });
        }
      });
    }

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

    return _renderizarDropdownLista(veiculos);
  }

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                if (selecionado != null) {
                  _kmController.text =
                      selecionado.quilometragemAtual.toString();
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
