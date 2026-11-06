import 'package:flutter/material.dart';

import 'components/card_veiculo.dart';
import 'components/footer_veiculos.dart';
import 'components/formulario_novo_veiculo.dart';
import 'components/modal_filtros_veiculo.dart';
import 'controllers/veiculo_controller.dart';
import 'detalhes_veiculo.dart';
import 'models/veiculo_model.dart';

class Veiculos extends StatefulWidget {
  const Veiculos({super.key});

  @override
  State<Veiculos> createState() => _VeiculosState();
}

class _VeiculosState extends State<Veiculos> {
  late Future<List<dynamic>> _veiculosFuture;
  List<Map<String, dynamic>> _veiculos = [];
  final TextEditingController _buscaController = TextEditingController();
  FiltroVeiculos _filtro = FiltroVeiculos();
  final VeiculoController _controller = VeiculoController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_aoAtualizarController);
    _veiculosFuture = _inicializar();
  }

  void _aoAtualizarController() {
    if (mounted) {
      setState(() {
        _veiculos = _controller.todosVeiculos.map((v) => v.toMap()).toList();
      });
    }
  }

  Future<List<dynamic>> _inicializar() async {
    await _controller.carregarVeiculos();
    _veiculos = _controller.todosVeiculos.map((v) => v.toMap()).toList();
    return _veiculos;
  }

  @override
  void dispose() {
    _controller.removeListener(_aoAtualizarController);
    _buscaController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> carregarVeiculos() async {
    return _inicializar();
  }

  void _alterarStatusVeiculo(Map<String, dynamic> veiculo, String novoStatus) {
    final statusEnum = StatusVeiculo.fromString(novoStatus);
    _controller.alterarStatus(veiculo['id'].toString(), statusEnum);

    setState(() {
      veiculo['status'] = novoStatus;
    });

    final String label = statusEnum.label;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blueGrey[900],
        content: Text(
          'Status de ${veiculo['placa']} alterado para "$label"',
        ),
      ),
    );
  }

  void _abrirFormularioVeiculo() {
    showDialog(
      context: context,
      builder: (context) => FormularioNovoVeiculo(
        placasExistentes: _veiculos.map((v) => (v['placa'] ?? '').toString()).toList(),
        onSalvar: (novoVeiculo) {
          final model = VeiculoModel.fromMap(novoVeiculo);
          _controller.adicionarVeiculo(model);
          setState(() {
            _veiculos.insert(0, novoVeiculo);
          });
        },
      ),
    );
  }

  void _abrirFormularioEdicao(Map<String, dynamic> veiculo) {
    showDialog(
      context: context,
      builder: (context) => FormularioNovoVeiculo(
        veiculoParaEditar: veiculo,
        placasExistentes: _veiculos
            .where((v) => v['id'] != veiculo['id'])
            .map((v) => (v['placa'] ?? '').toString())
            .toList(),
        onSalvar: (veiculoAtualizado) {
          final model = VeiculoModel.fromMap(veiculoAtualizado);
          _controller.atualizarVeiculo(model);
          setState(() {
            final idx = _veiculos.indexWhere((v) => v['id'] == veiculoAtualizado['id']);
            if (idx != -1) {
              _veiculos[idx] = veiculoAtualizado;
            }
          });
        },
      ),
    );
  }

  void _abrirDetalhes(Map<String, dynamic> veiculo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesVeiculo(
          veiculo: veiculo,
          onStatusChanged: (novoStatus) {
            _alterarStatusVeiculo(veiculo, novoStatus);
          },
          onExcluir: () {
            _controller.removerVeiculo(veiculo['id'].toString());
            setState(() {
              _veiculos.removeWhere((v) => v['id'] == veiculo['id']);
            });
          },
        ),
      ),
    );
  }

  // Abertura do Modal Bottom Sheet de Filtros (Padrão mobile clássico)
  void _abrirModalFiltros() async {
    final novoFiltro = await showModalBottomSheet<FiltroVeiculos>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModalFiltrosVeiculo(filtroAtual: _filtro),
    );

    if (novoFiltro != null) {
      setState(() {
        _filtro = novoFiltro;
      });
    }
  }

  Widget _construirCardVeiculo(Map<String, dynamic> veiculo) {
    return CardVeiculo(
      veiculo: veiculo,
      onEditar: () => _abrirFormularioEdicao(veiculo),
      onDetalhes: () => _abrirDetalhes(veiculo),
      onStatusChanged: (novoStatus) => _alterarStatusVeiculo(veiculo, novoStatus),
      onTagSelecionada: (tag) {
        setState(() {
          if (tag == 'ac') {
            _filtro.possuiAC = true;
          } else if (tag == 'preferencial') {
            _filtro.possuiPreferencial = true;
          }
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blueGrey[900],
            content: Text(
              tag == 'ac'
                  ? 'Filtro aplicado: Com Ar-condicionado'
                  : 'Filtro aplicado: Acesso Preferencial',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Lista de Veículos'),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _veiculosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _veiculos.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // APLICAÇÃO DOS FILTROS (Busca por texto + Critérios do Modal)
            final query = _buscaController.text.trim().toLowerCase();

            final veiculosFiltrados = _veiculos.where((v) {
              // 1. Filtro de Busca por Texto
              if (query.isNotEmpty) {
                final placa = (v['placa'] ?? '').toString().toLowerCase();
                final modelo = (v['modelo'] ?? '').toString().toLowerCase();
                final marca = (v['marca'] ?? '').toString().toLowerCase();
                final match = placa.contains(query) || modelo.contains(query) || marca.contains(query);
                if (!match) return false;
              }

              // 2. Filtro de Status
              if (_filtro.status != 'todos') {
                final status = (v['status'] ?? '').toString();
                if (_filtro.status == 'emViagem') {
                  if (status != 'emViagem' && status != 'emUso') return false;
                } else if (status != _filtro.status) {
                  return false;
                }
              }

              // 3. Filtro de Tipo de Veículo
              if (_filtro.tipo != 'todos') {
                final tipo = (v['tipo'] ?? '').toString().toLowerCase();
                if (tipo != _filtro.tipo) return false;
              }

              // 4. Filtro de Opcionais
              if (_filtro.possuiAC && v['possuiAC'] != true) return false;
              if (_filtro.possuiPreferencial && v['possuiPreferencial'] != true) return false;

              // 5. Filtro de Capacidade de Assentos
              if (_filtro.faixaAssentos != 'todos') {
                final assentos = int.tryParse(v['qtdAssentos']?.toString() ?? '') ?? 0;
                if (_filtro.faixaAssentos == 'ate_5' && assentos > 5) return false;
                if (_filtro.faixaAssentos == '6_a_15' && (assentos < 6 || assentos > 15)) {
                  return false;
                }
                if (_filtro.faixaAssentos == 'mais_15' && assentos <= 15) return false;
              }

              return true;
            }).toList();

            final bool semFiltrosAtivos = !_filtro.temFiltrosAtivos && query.isEmpty;

            // Separação de ativos vs pendentes quando não há filtros aplicados
            final veiculosAtivos = veiculosFiltrados.where((v) {
              final status = (v['status'] ?? '').toString();
              return status == 'disponivel' || status == 'emViagem' || status == 'emUso';
            }).toList();

            final veiculosPendentes = veiculosFiltrados.where((v) {
              final status = (v['status'] ?? '').toString();
              return status == 'emManutencao' || status == 'inativo';
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // PADRÃO VISUAL: BARRA DE PESQUISA + BOTÃO DE FILTROS MODAL AO LADO
                Row(
                  children: [
                    // CAMPO DE BUSCA
                    Expanded(
                      child: TextField(
                        controller: _buscaController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar por placa, modelo ou marca...',
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[700]),
                          suffixIcon: _buscaController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _buscaController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // PEQUENO BOTÃO DE FILTRO COM BADGE INDICADOR
                    Badge(
                      isLabelVisible: _filtro.temFiltrosAtivos,
                      label: Text(
                        '${_filtro.quantidadeFiltrosAtivos}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      backgroundColor: Colors.green[700],
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _abrirModalFiltros,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _filtro.temFiltrosAtivos
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _filtro.temFiltrosAtivos
                                  ? Colors.green.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Icon(
                            Icons.tune_outlined,
                            size: 22,
                            color: _filtro.temFiltrosAtivos
                                ? Colors.green.shade800
                                : Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // LINHA COM O BOTÃO NOVO VEÍCULO (Estilo original 100% preservado)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Indicador de filtros ativos caso existam
                    if (_filtro.temFiltrosAtivos || query.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            '${veiculosFiltrados.length} resultado(s)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () {
                              _buscaController.clear();
                              setState(() {
                                _filtro.limpar();
                              });
                            },
                            child: const Text('Limpar'),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),

                    // BOTÃO NOVO VEÍCULO (Preservado exatamente com padding vertical 20)
                    ElevatedButton.icon(
                      onPressed: _abrirFormularioVeiculo,
                      icon: const Icon(Icons.add_outlined),
                      label: const Text(
                        'Novo Veículo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700], // Fundo verde
                        foregroundColor: Colors.white, // Texto e ícone brancos
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 20, // Padding vertical 20 original
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // QUANDO NÃO HÁ FILTROS: MANTÉM ATIVOS NO TOPO E EXPANSIONTILE EMBAIXO
                if (semFiltrosAtivos) ...[
                  for (final veiculo in veiculosAtivos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _construirCardVeiculo(veiculo),
                    ),
                  if (veiculosPendentes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        title: Text(
                          'Em Manutenção / Inativos (${veiculosPendentes.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        initiallyExpanded: false,
                        backgroundColor: Colors.grey[300],
                        minTileHeight: 70,
                        children: [
                          for (final veiculo in veiculosPendentes)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _construirCardVeiculo(veiculo),
                            ),
                        ],
                      ),
                    ),
                ] else ...[
                  // QUANDO HÁ FILTROS ATIVOS OU BUSCA
                  if (veiculosFiltrados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.filter_list_off_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum veículo encontrado para os filtros selecionados.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _buscaController.clear();
                                setState(() {
                                  _filtro.limpar();
                                });
                              },
                              child: const Text('Limpar Filtros e Busca'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final veiculo in veiculosFiltrados)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _construirCardVeiculo(veiculo),
                      ),
                ],
              ],
            );
          },
        ),
      ),

      // RODAPÉ COM RESUMO DA FROTA
      bottomNavigationBar: FooterVeiculos(
        veiculosDisponiveis: _veiculos.where((v) => v['status'] == 'disponivel').length,
        veiculosTotais: _veiculos.length,
      ),
    );
  }
}
