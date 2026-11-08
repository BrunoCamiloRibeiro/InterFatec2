import 'package:flutter/material.dart';

class FormularioNovoVeiculo extends StatefulWidget {
  final Map<String, dynamic>? veiculoParaEditar;
  final ValueChanged<Map<String, dynamic>>? onSalvar;
  final List<String>? placasExistentes;

  const FormularioNovoVeiculo({
    super.key,
    this.veiculoParaEditar,
    this.onSalvar,
    this.placasExistentes,
  });

  @override
  State<FormularioNovoVeiculo> createState() => _FormularioNovoVeiculoState();
}

class _StatusPlacaInfo {
  final IconData icone;
  final Color cor;
  final String mensagem;

  const _StatusPlacaInfo({
    required this.icone,
    required this.cor,
    required this.mensagem,
  });
}

class _FormularioNovoVeiculoState extends State<FormularioNovoVeiculo> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _placaController;
  late final TextEditingController _marcaController;
  late final TextEditingController _modeloController;
  late final TextEditingController _anoController;
  late final TextEditingController _kmController;
  late final TextEditingController _assentosController;
  late final TextEditingController _observacoesController;

  late final FocusNode _marcaFocusNode;
  late final FocusNode _modeloFocusNode;

  late final ValueNotifier<_StatusPlacaInfo?> _avisoPlacaNotifier;

  late String _tipoSelecionado;
  late String _statusSelecionado;
  late bool _possuiAC;
  late bool _possuiPreferencial;

  bool get _isEdicao => widget.veiculoParaEditar != null;

  static const List<Map<String, String>> _tipos = [
    {'valor': 'van', 'nome': 'Van'},
    {'valor': 'ambulancia', 'nome': 'Ambulância'},
    {'valor': 'microonibus', 'nome': 'Micro-ônibus'},
    {'valor': 'carro', 'nome': 'Carro de Apoio'},
  ];

  static const List<Map<String, String>> _statusOpcoes = [
    {'valor': 'disponivel', 'nome': 'Disponível'},
    {'valor': 'emManutencao', 'nome': 'Em Manutenção'},
    {'valor': 'emViagem', 'nome': 'Em Viagem'},
    {'valor': 'inativo', 'nome': 'Inativo'},
  ];

  // Base de sugestões para marcas e modelos de frotas e suporte
  static const Map<String, List<String>> _modelosPorMarca = {
    'Renault': ['Master', 'Kangoo', 'Trafic', 'Logan', 'Sandero', 'Duster', 'Kwid'],
    'Fiat': ['Ducato', 'Fiorino', 'Doblò', 'Scudo', 'Toro', 'Strada', 'Argo', 'Cronos', 'Mobi'],
    'Mercedes-Benz': ['Sprinter', 'Vito', 'Accelo'],
    'Iveco': ['Daily', 'Daily Minibus'],
    'Ford': ['Transit', 'Ranger', 'Ka'],
    'Chevrolet': ['Spin', 'Onix', 'Tracker', 'S10', 'Montana'],
    'Volkswagen': ['Kombi', 'Crafter', 'Delivery Express', 'Gol', 'Voyage', 'Polo', 'T-Cross', 'Virtus', 'Saveiro'],
    'Toyota': ['Hiace', 'Hilux', 'Corolla', 'Yaris', 'Etios'],
    'Hyundai': ['HR', 'HB20', 'Creta'],
    'Citroën': ['Jumper', 'Jumpy', 'Berlingo', 'C3', 'Aircross'],
    'Peugeot': ['Boxer', 'Expert', 'Partner', '208'],
    'Marcopolo': ['Volare V8L', 'Volare Attack 8', 'Volare Fly 9', 'Senior'],
  };

  static final List<String> _marcasSugeridas = _modelosPorMarca.keys.toList();

  @override
  void initState() {
    super.initState();
    final v = widget.veiculoParaEditar ?? {};

    _placaController = TextEditingController(text: v['placa']?.toString() ?? '');
    _marcaController = TextEditingController(text: v['marca']?.toString() ?? '');
    _modeloController = TextEditingController(text: v['modelo']?.toString() ?? '');
    _anoController = TextEditingController(
      text: v['ano'] != null ? v['ano'].toString() : DateTime.now().year.toString(),
    );
    _kmController = TextEditingController(
      text: v['quilometragemAtual'] != null ? v['quilometragemAtual'].toString() : '0',
    );
    _assentosController = TextEditingController(
      text: v['qtdAssentos'] != null ? v['qtdAssentos'].toString() : '15',
    );
    _observacoesController = TextEditingController(
      text: v['observacoes']?.toString() ?? '',
    );

    _marcaFocusNode = FocusNode();
    _modeloFocusNode = FocusNode();
    _avisoPlacaNotifier = ValueNotifier<_StatusPlacaInfo?>(null);

    _placaController.addListener(_verificarPlaca);
    if (_placaController.text.isNotEmpty) {
      _verificarPlaca();
    }

    _tipoSelecionado = (v['tipo'] ?? 'van').toString().toLowerCase();
    if (!_tipos.any((t) => t['valor'] == _tipoSelecionado)) {
      _tipoSelecionado = 'van';
    }

    _statusSelecionado = (v['status'] ?? 'disponivel').toString();
    if (!_statusOpcoes.any((s) => s['valor'] == _statusSelecionado)) {
      _statusSelecionado = 'disponivel';
    }

    _possuiAC = v['possuiAC'] == true;
    _possuiPreferencial = v['possuiPreferencial'] == true;
  }

  @override
  void dispose() {
    _placaController.removeListener(_verificarPlaca);
    _avisoPlacaNotifier.dispose();
    _marcaFocusNode.dispose();
    _modeloFocusNode.dispose();
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _kmController.dispose();
    _assentosController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  bool _placaJaExiste(String placaLimpa) {
    final placas = widget.placasExistentes ?? const ['ABC1D23', 'DEF4G56'];
    final placaOriginal = widget.veiculoParaEditar?['placa']
        ?.toString()
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    // Em modo de edição, se a placa for a mesma original do veículo, não é duplicada
    if (_isEdicao && placaOriginal != null && placaOriginal == placaLimpa) {
      return false;
    }

    return placas.any((p) {
      final pLimpa = p.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      if (_isEdicao && placaOriginal != null && pLimpa == placaOriginal) {
        return false;
      }
      return pLimpa == placaLimpa;
    });
  }

  void _verificarPlaca() {
    final texto = _placaController.text;
    final limpa = texto.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    if (limpa.length < 7) {
      _avisoPlacaNotifier.value = null;
      return;
    }

    // 1. Verifica duplicidade
    if (_placaJaExiste(limpa)) {
      _avisoPlacaNotifier.value = const _StatusPlacaInfo(
        icone: Icons.cancel_outlined,
        cor: Colors.red,
        mensagem: 'Já existe outro veículo cadastrado com esta placa.',
      );
      return;
    }

    // 2. Padrão Mercosul (LLLNLNN - 3 letras, 1 número, 1 letra, 2 números)
    final isMercosul = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$').hasMatch(limpa);
    if (isMercosul) {
      _avisoPlacaNotifier.value = const _StatusPlacaInfo(
        icone: Icons.check_circle_outline,
        cor: Colors.green,
        mensagem: 'Padrão Mercosul válido (ABC1D23).',
      );
      return;
    }

    // 3. Padrão Antigo (LLLNNNN - 3 letras e 4 números, ex: placa cinza)
    final isAntiga = RegExp(r'^[A-Z]{3}[0-9]{4}$').hasMatch(limpa);
    if (isAntiga) {
      _avisoPlacaNotifier.value = const _StatusPlacaInfo(
        icone: Icons.info_outline,
        cor: Colors.blueGrey,
        mensagem: 'Padrão antigo (placa cinza). Válido para circulação.',
      );
      return;
    }

    // 4. Fora de ambos os padrões (aviso visual informativo, não bloqueante)
    _avisoPlacaNotifier.value = const _StatusPlacaInfo(
      icone: Icons.warning_amber_rounded,
      cor: Colors.orange,
      mensagem: 'Aviso: Formato fora do padrão Mercosul (ABC1D23) ou antigo (ABC1234).',
    );
  }

  List<String> _obterSugestoesMarca(String query) {
    if (query.trim().isEmpty) return const [];
    final q = query.trim().toLowerCase();
    return _marcasSugeridas.where((m) => m.toLowerCase().contains(q)).toList();
  }

  List<String> _obterSugestoesModelo(String query) {
    if (query.trim().isEmpty) return const [];
    final q = query.trim().toLowerCase();
    final marcaAtual = _marcaController.text.trim();
    List<String> pool;
    if (marcaAtual.isNotEmpty && _modelosPorMarca.containsKey(marcaAtual)) {
      pool = _modelosPorMarca[marcaAtual]!;
    } else {
      pool = _modelosPorMarca.values.expand((m) => m).toSet().toList();
    }
    return pool.where((m) => m.toLowerCase().contains(q)).toList();
  }

  Widget _construirCampoAutocomplete({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icone,
    required List<String> Function(String query) opcoesCallback,
    String? Function(String?)? validator,
    void Function(String)? onSelecionado,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.trim().isEmpty) {
              return const Iterable<String>.empty();
            }
            return opcoesCallback(textEditingValue.text);
          },
          onSelected: (String selecao) {
            controller.text = selecao;
            if (onSelecionado != null) onSelecionado(selecao);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                shadowColor: Colors.black38,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 190,
                    maxWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 260,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (BuildContext context, int index) {
                      final String opcao = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(opcao),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(icone, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  opcao,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
            return TextFormField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              validator: validator,
              decoration: _campoDecoracao(
                label: label,
                hint: hint,
                icone: icone,
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _campoDecoracao({
    required String label,
    required IconData icone,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icone, size: 20, color: Colors.grey[700]),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
      ),
    );
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final agora = DateTime.now().toIso8601String();
    final placa = _placaController.text.trim().toUpperCase();

    final dadosVeiculo = {
      'id': widget.veiculoParaEditar?['id'] ?? 'veiculo_${DateTime.now().millisecondsSinceEpoch}',
      'placa': placa,
      'tipo': _tipoSelecionado,
      'marca': _marcaController.text.trim(),
      'modelo': _modeloController.text.trim(),
      'ano': int.tryParse(_anoController.text.trim()) ?? DateTime.now().year,
      'qtdAssentos': int.tryParse(_assentosController.text.trim()) ?? 15,
      'status': _statusSelecionado,
      'quilometragemAtual': int.tryParse(_kmController.text.trim()) ?? 0,
      'ultimoMotoristaId': widget.veiculoParaEditar?['ultimoMotoristaId'],
      'possuiAC': _possuiAC,
      'possuiPreferencial': _possuiPreferencial,
      'observacoes': _observacoesController.text.trim().isNotEmpty
          ? _observacoesController.text.trim()
          : null,
      'criadoEm': widget.veiculoParaEditar?['criadoEm'] ?? agora,
      'atualizadoEm': agora,
      'atualizadoPor': widget.veiculoParaEditar?['atualizadoPor'],
    };

    if (widget.onSalvar != null) {
      widget.onSalvar!(dadosVeiculo);
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
        content: Text(
          _isEdicao
              ? 'Veículo $placa atualizado com sucesso!'
              : 'Veículo $placa cadastrado com sucesso!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Usamos SingleChildScrollView com altura fixa e sem resize a cada caractere
    // Isso evita completamente o tremor / piscar ao digitar no Windows e Mobile
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CABEÇALHO DO DIALOG
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isEdicao ? Icons.edit_outlined : Icons.add_circle_outline,
                        color: Colors.green[700],
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isEdicao ? 'Editar Veículo' : 'Novo Veículo',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // FORMULÁRIO COM SCROLL SUAVE E EXPANSIONTILE ESTÁVEL
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 1. IDENTIFICAÇÃO DO VEÍCULO (EXPANSIONTILE)
                      ExpansionTile(
                        initiallyExpanded: true,
                        maintainState: true,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        backgroundColor: Colors.grey[50],
                        collapsedBackgroundColor: Colors.grey[100],
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        title: const Text(
                          '1. Identificação do Veículo',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        leading: Icon(Icons.badge_outlined, color: Colors.grey[800]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          TextFormField(
                                            controller: _placaController,
                                            validator: (valor) {
                                              final limpa = (valor ?? '')
                                                  .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
                                                  .toUpperCase();
                                              if (limpa.isEmpty) {
                                                return 'Informe a placa';
                                              }
                                              if (limpa.length < 7) {
                                                return 'A placa deve ter 7 dígitos';
                                              }
                                              if (_placaJaExiste(limpa)) {
                                                return 'Esta placa já pertence a outro veículo';
                                              }
                                              // Placa fora do padrão Mercosul/antigo NÃO bloqueia, apenas alerta visualmente
                                              return null;
                                            },
                                            decoration: _campoDecoracao(
                                              label: 'Placa *',
                                              hint: 'Ex: ABC1D23 ou ABC1234',
                                              icone: Icons.pin_outlined,
                                            ),
                                          ),
                                          ValueListenableBuilder<_StatusPlacaInfo?>(
                                            valueListenable: _avisoPlacaNotifier,
                                            builder: (context, info, _) {
                                              if (info == null) return const SizedBox.shrink();
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 6, left: 4),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(info.icone, size: 16, color: info.cor),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        info.mensagem,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: info.cor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _anoController,
                                        keyboardType: TextInputType.number,
                                        validator: (valor) {
                                          if (valor == null || valor.trim().isEmpty) {
                                            return 'Informe o ano';
                                          }
                                          final num = int.tryParse(valor.trim());
                                          if (num == null || num < 1980 || num > DateTime.now().year + 1) {
                                            return 'Ano inválido';
                                          }
                                          return null;
                                        },
                                        decoration: _campoDecoracao(
                                          label: 'Ano *',
                                          hint: '2024',
                                          icone: Icons.calendar_today_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _construirCampoAutocomplete(
                                        controller: _marcaController,
                                        focusNode: _marcaFocusNode,
                                        label: 'Marca *',
                                        hint: 'Ex: Renault, Fiat',
                                        icone: Icons.directions_car_outlined,
                                        opcoesCallback: _obterSugestoesMarca,
                                        validator: (valor) => (valor == null || valor.trim().isEmpty)
                                            ? 'Informe a marca'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _construirCampoAutocomplete(
                                        controller: _modeloController,
                                        focusNode: _modeloFocusNode,
                                        label: 'Modelo *',
                                        hint: 'Ex: Master, Ducato',
                                        icone: Icons.info_outline,
                                        opcoesCallback: _obterSugestoesModelo,
                                        validator: (valor) => (valor == null || valor.trim().isEmpty)
                                            ? 'Informe o modelo'
                                            : null,
                                        onSelecionado: (modeloSelecionado) {
                                          // Autopreenchimento inteligente da marca se ainda estiver em branco
                                          if (_marcaController.text.trim().isEmpty) {
                                            for (final entry in _modelosPorMarca.entries) {
                                              if (entry.value.contains(modeloSelecionado)) {
                                                _marcaController.text = entry.key;
                                                break;
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 2. CATEGORIA E STATUS (EXPANSIONTILE)
                      ExpansionTile(
                        initiallyExpanded: true,
                        maintainState: true,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        backgroundColor: Colors.grey[50],
                        collapsedBackgroundColor: Colors.grey[100],
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        title: const Text(
                          '2. Classificação & Status',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        leading: Icon(Icons.category_outlined, color: Colors.grey[800]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _tipoSelecionado,
                                  decoration: _campoDecoracao(
                                    label: 'Tipo de Veículo',
                                    icone: Icons.local_shipping_outlined,
                                  ),
                                  items: _tipos.map((tipo) {
                                    return DropdownMenuItem<String>(
                                      value: tipo['valor'],
                                      child: Text(tipo['nome']!),
                                    );
                                  }).toList(),
                                  onChanged: (valor) {
                                    if (valor != null) {
                                      _tipoSelecionado = valor;
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _statusSelecionado,
                                  decoration: _campoDecoracao(
                                    label: 'Status do Veículo',
                                    icone: Icons.flag_outlined,
                                  ),
                                  items: _statusOpcoes.map((st) {
                                    return DropdownMenuItem<String>(
                                      value: st['valor'],
                                      child: Text(st['nome']!),
                                    );
                                  }).toList(),
                                  onChanged: (valor) {
                                    if (valor != null) {
                                      _statusSelecionado = valor;
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 3. CAPACIDADE E OPERAÇÃO (EXPANSIONTILE)
                      ExpansionTile(
                        initiallyExpanded: false,
                        maintainState: true,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        backgroundColor: Colors.grey[50],
                        collapsedBackgroundColor: Colors.grey[100],
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        title: const Text(
                          '3. Capacidade & Operação',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        leading: Icon(Icons.speed_outlined, color: Colors.grey[800]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _assentosController,
                                        keyboardType: TextInputType.number,
                                        validator: (val) {
                                          final n = int.tryParse(val ?? '');
                                          if (n == null || n <= 0) return 'Mínimo 1';
                                          return null;
                                        },
                                        decoration: _campoDecoracao(
                                          label: 'Qtd. Assentos *',
                                          hint: 'Ex: 15',
                                          icone: Icons.chair_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _kmController,
                                        keyboardType: TextInputType.number,
                                        validator: (val) {
                                          final n = int.tryParse(val ?? '');
                                          if (n == null || n < 0) return 'Km inválido';
                                          return null;
                                        },
                                        decoration: _campoDecoracao(
                                          label: 'Km Atual *',
                                          hint: 'Ex: 45000',
                                          icone: Icons.speed_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 4. OPCIONAIS E EQUIPAMENTOS (EXPANSIONTILE)
                      ExpansionTile(
                        initiallyExpanded: false,
                        maintainState: true,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        backgroundColor: Colors.grey[50],
                        collapsedBackgroundColor: Colors.grey[100],
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        title: const Text(
                          '4. Opcionais & Equipamentos',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        leading: Icon(Icons.tune_outlined, color: Colors.grey[800]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Ar-condicionado'),
                                  subtitle: const Text('Climatização para os passageiros'),
                                  secondary: Icon(
                                    Icons.ac_unit_outlined,
                                    color: Colors.blue.shade700,
                                  ),
                                  value: _possuiAC,
                                  onChanged: (val) => setState(() => _possuiAC = val),
                                ),
                                const Divider(height: 1),
                                SwitchListTile(
                                  title: const Text('Acesso Preferencial / PCD'),
                                  subtitle: const Text('Plataforma ou assento adaptado'),
                                  secondary: Icon(
                                    Icons.accessible_outlined,
                                    color: Colors.purple.shade700,
                                  ),
                                  value: _possuiPreferencial,
                                  onChanged: (val) =>
                                      setState(() => _possuiPreferencial = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 5. OBSERVAÇÕES (EXPANSIONTILE)
                      ExpansionTile(
                        initiallyExpanded: false,
                        maintainState: true,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        backgroundColor: Colors.grey[50],
                        collapsedBackgroundColor: Colors.grey[100],
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        title: const Text(
                          '5. Observações & Alertas',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        leading: Icon(Icons.notes_outlined, color: Colors.grey[800]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextFormField(
                              controller: _observacoesController,
                              maxLines: 3,
                              decoration: _campoDecoracao(
                                label: 'Observações / Histórico de Manutenção',
                                hint: 'Insira qualquer detalhe ou aviso sobre o veículo...',
                                icone: Icons.edit_note_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BOTÕES DE AÇÃO NA BASE DO DIALOG
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _salvar,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      _isEdicao ? 'Salvar Alterações' : 'Salvar Veículo',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
