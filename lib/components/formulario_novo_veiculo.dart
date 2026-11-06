import 'package:flutter/material.dart';

class FormularioNovoVeiculo extends StatefulWidget {
  final Map<String, dynamic>? veiculoParaEditar;
  final ValueChanged<Map<String, dynamic>>? onSalvar;

  const FormularioNovoVeiculo({
    super.key,
    this.veiculoParaEditar,
    this.onSalvar,
  });

  @override
  State<FormularioNovoVeiculo> createState() => _FormularioNovoVeiculoState();
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

  late String _tipoSelecionado;
  late String _statusSelecionado;
  String? _motoristaSelecionado;
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

  static const List<String> _motoristasMock = [
    'motorista001',
    'Carlos Silva (Matrícula: 1042)',
    'Mariana Santos (Matrícula: 1055)',
    'Roberto Albuquerque (Matrícula: 1089)',
    'Sem motorista fixo',
  ];

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

    _tipoSelecionado = (v['tipo'] ?? 'van').toString().toLowerCase();
    if (!_tipos.any((t) => t['valor'] == _tipoSelecionado)) {
      _tipoSelecionado = 'van';
    }

    _statusSelecionado = (v['status'] ?? 'disponivel').toString();
    if (!_statusOpcoes.any((s) => s['valor'] == _statusSelecionado)) {
      _statusSelecionado = 'disponivel';
    }

    _motoristaSelecionado =
        v['ultimoMotoristaId']?.toString() ?? v['motoristaResponsavelId']?.toString();

    _possuiAC = v['possuiAC'] == true;
    _possuiPreferencial = v['possuiPreferencial'] == true;
  }

  @override
  void dispose() {
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _kmController.dispose();
    _assentosController.dispose();
    _observacoesController.dispose();
    super.dispose();
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
      'motoristaResponsavelId': _motoristaSelecionado,
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
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _placaController,
                                        // Sem textCapitalization para não disparar re-layout no Windows
                                        validator: (valor) {
                                          if (valor == null || valor.trim().isEmpty) {
                                            return 'Informe a placa';
                                          }
                                          if (valor.trim().length < 7) {
                                            return 'Placa incompleta';
                                          }
                                          return null;
                                        },
                                        decoration: _campoDecoracao(
                                          label: 'Placa *',
                                          hint: 'ABC1D23',
                                          icone: Icons.pin_outlined,
                                        ),
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
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _marcaController,
                                        validator: (valor) => (valor == null || valor.trim().isEmpty)
                                            ? 'Informe a marca'
                                            : null,
                                        decoration: _campoDecoracao(
                                          label: 'Marca *',
                                          hint: 'Renault',
                                          icone: Icons.directions_car_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _modeloController,
                                        validator: (valor) => (valor == null || valor.trim().isEmpty)
                                            ? 'Informe o modelo'
                                            : null,
                                        decoration: _campoDecoracao(
                                          label: 'Modelo *',
                                          hint: 'Master',
                                          icone: Icons.info_outline,
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
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _motoristaSelecionado,
                                  decoration: _campoDecoracao(
                                    label: 'Motorista Responsável',
                                    hint: 'Selecione o motorista',
                                    icone: Icons.person_outline,
                                  ),
                                  items: _motoristasMock.map((m) {
                                    return DropdownMenuItem<String>(
                                      value: m,
                                      child: Text(
                                        m,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (valor) {
                                    _motoristaSelecionado = valor;
                                  },
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
