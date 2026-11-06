import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/card_veiculo.dart';
import 'components/footer_veiculos.dart';
import 'components/formulario_novo_veiculo.dart';
import 'detalhes_veiculo.dart';

class Veiculos extends StatefulWidget {
  const Veiculos({super.key});

  @override
  State<Veiculos> createState() => _VeiculosState();
}

class _VeiculosState extends State<Veiculos> {
  late Future<List<dynamic>> _veiculosFuture;
  List<Map<String, dynamic>> _veiculos = [];
  String _filtroSelecionado = 'todos';

  @override
  void initState() {
    super.initState();
    _veiculosFuture = carregarVeiculos();
  }

  Future<List<dynamic>> carregarVeiculos() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/dados_veiculos.json',
      );
      final List<dynamic> jsonDecodificado = jsonDecode(jsonString) as List<dynamic>;
      _veiculos = jsonDecodificado
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      return _veiculos;
    } catch (_) {
      _veiculos = [
        {
          "id": "veiculo001",
          "placa": "ABC1D23",
          "tipo": "van",
          "marca": "Renault",
          "modelo": "Master",
          "ano": 2023,
          "qtdAssentos": 15,
          "status": "disponivel",
          "quilometragemAtual": 45280,
          "motoristaResponsavelId": null,
          "ultimoMotoristaId": null,
          "possuiAC": true,
          "possuiPreferencial": false,
          "observacoes": "Veículo utilizado para viagens intermunicipais.",
          "criadoEm": "2026-10-01T08:00:00",
          "atualizadoEm": "2026-10-01T08:00:00",
          "atualizadoPor": null,
        },
        {
          "id": "veiculo002",
          "placa": "DEF4G56",
          "tipo": "ambulancia",
          "marca": "Fiat",
          "modelo": "Ducato",
          "ano": 2022,
          "qtdAssentos": 4,
          "status": "emManutencao",
          "quilometragemAtual": 62150,
          "motoristaResponsavelId": null,
          "ultimoMotoristaId": "motorista001",
          "possuiAC": true,
          "possuiPreferencial": true,
          "observacoes": "Revisão preventiva pendente.",
          "criadoEm": "2026-09-15T10:30:00",
          "atualizadoEm": "2026-10-20T14:00:00",
          "atualizadoPor": "usuario001",
        },
      ];
      return _veiculos;
    }
  }

  void _alterarStatusVeiculo(Map<String, dynamic> veiculo, String novoStatus) {
    setState(() {
      veiculo['status'] = novoStatus;
    });

    final String label = switch (novoStatus) {
      'disponivel' => 'Disponível',
      'emManutencao' => 'Em Manutenção',
      'emViagem' => 'Em Viagem',
      'inativo' => 'Inativo',
      _ => novoStatus,
    };

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
        onSalvar: (novoVeiculo) {
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
        onSalvar: (veiculoAtualizado) {
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
            setState(() {
              _veiculos.removeWhere((v) => v['id'] == veiculo['id']);
            });
          },
        ),
      ),
    );
  }

  Widget _construirCardVeiculo(Map<String, dynamic> veiculo) {
    return CardVeiculo(
      veiculo: veiculo,
      onEditar: () => _abrirFormularioEdicao(veiculo),
      onDetalhes: () => _abrirDetalhes(veiculo),
      onStatusChanged: (novoStatus) => _alterarStatusVeiculo(veiculo, novoStatus),
      onTagSelecionada: (tag) {
        setState(() {
          _filtroSelecionado = tag;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blueGrey[900],
            content: Text(
              tag == 'ac'
                  ? 'Filtro aplicado: Ar-condicionado'
                  : 'Filtro aplicado: Acesso Preferencial',
            ),
          ),
        );
      },
    );
  }

  Widget _construirChipFiltro({
    required String id,
    required String label,
    required IconData icone,
    Color? corIcone,
  }) {
    final bool selecionado = _filtroSelecionado == id;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            _filtroSelecionado = id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selecionado ? Colors.blueGrey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selecionado ? Colors.blueGrey[900]! : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icone,
                size: 14,
                color: selecionado ? Colors.white : (corIcone ?? Colors.grey[700]),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selecionado ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
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

            // APLICAÇÃO DOS FILTROS
            final veiculosFiltrados = _veiculos.where((v) {
              if (_filtroSelecionado == 'todos') return true;
              if (_filtroSelecionado == 'disponivel') return v['status'] == 'disponivel';
              if (_filtroSelecionado == 'emViagem') {
                return v['status'] == 'emViagem' || v['status'] == 'emUso';
              }
              if (_filtroSelecionado == 'emManutencao') return v['status'] == 'emManutencao';
              if (_filtroSelecionado == 'inativo') return v['status'] == 'inativo';
              if (_filtroSelecionado == 'ac') return v['possuiAC'] == true;
              if (_filtroSelecionado == 'preferencial') return v['possuiPreferencial'] == true;
              if (_filtroSelecionado == 'van') {
                return (v['tipo'] ?? '').toString().toLowerCase() == 'van';
              }
              if (_filtroSelecionado == 'ambulancia') {
                return (v['tipo'] ?? '').toString().toLowerCase() == 'ambulancia';
              }
              return true;
            }).toList();

            // Separação de ativos vs pendentes quando filtro é 'todos'
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
                // BOTÃO NOVO VEÍCULO NO TOPO (Estilo original 100% restaurado)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                const SizedBox(height: 14),

                // BARRA HORIZONTAL DE FILTROS (Chips de filtro)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _construirChipFiltro(
                        id: 'todos',
                        label: 'Todos (${_veiculos.length})',
                        icone: Icons.apps_outlined,
                      ),
                      _construirChipFiltro(
                        id: 'disponivel',
                        label: 'Disponíveis',
                        icone: Icons.circle,
                        corIcone: Colors.green,
                      ),
                      _construirChipFiltro(
                        id: 'emViagem',
                        label: 'Em Viagem',
                        icone: Icons.circle,
                        corIcone: Colors.blue,
                      ),
                      _construirChipFiltro(
                        id: 'emManutencao',
                        label: 'Em Manutenção',
                        icone: Icons.circle,
                        corIcone: Colors.orange,
                      ),
                      _construirChipFiltro(
                        id: 'inativo',
                        label: 'Inativos',
                        icone: Icons.circle,
                        corIcone: Colors.grey,
                      ),
                      _construirChipFiltro(
                        id: 'ac',
                        label: 'Ar-condicionado',
                        icone: Icons.ac_unit_outlined,
                        corIcone: Colors.blue,
                      ),
                      _construirChipFiltro(
                        id: 'preferencial',
                        label: 'Acesso Preferencial',
                        icone: Icons.accessible_outlined,
                        corIcone: Colors.purple,
                      ),
                      _construirChipFiltro(
                        id: 'van',
                        label: 'Vans',
                        icone: Icons.airport_shuttle_outlined,
                      ),
                      _construirChipFiltro(
                        id: 'ambulancia',
                        label: 'Ambulâncias',
                        icone: Icons.emergency_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // QUANDO O FILTRO É 'TODOS': MANTÉM ATIVOS NO TOPO E EXPANSIONTILE EMBAIXO
                if (_filtroSelecionado == 'todos') ...[
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
                  // QUANDO UM FILTRO ESPECÍFICO ESTÁ ATIVO
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
                              'Nenhum veículo encontrado para este filtro.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _filtroSelecionado = 'todos';
                                });
                              },
                              child: const Text('Limpar Filtro'),
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
