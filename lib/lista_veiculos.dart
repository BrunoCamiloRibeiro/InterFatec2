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
  late Future<List<Map<String, dynamic>>> _veiculosFuture;
  List<Map<String, dynamic>> _veiculos = [];

  @override
  void initState() {
    super.initState();
    _veiculosFuture = carregarVeiculos();
  }

  Future<List<Map<String, dynamic>>> carregarVeiculos() async {
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
      // Fallback para visualização caso o json não esteja disponível no bundle
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
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _veiculosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _veiculos.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError && _veiculos.isEmpty) {
              return const Center(
                child: Text('Erro ao carregar os veículos.'),
              );
            }

            final veiculos = _veiculos.isNotEmpty ? _veiculos : (snapshot.data ?? []);

            // Separação de veículos ativos vs pendentes / manutenção usando ExpansionTile
            final veiculosAtivos = veiculos.where((v) {
              final status = (v['status'] ?? '').toString();
              return status == 'disponivel' || status == 'emViagem' || status == 'emUso';
            }).toList();

            final veiculosPendentes = veiculos.where((v) {
              final status = (v['status'] ?? '').toString();
              return status == 'emManutencao' || status == 'inativo';
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // BOTÃO DE NOVO VEÍCULO NO TOPO
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
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // VEÍCULOS ATIVOS / DISPONÍVEIS
                for (final veiculo in veiculosAtivos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _construirCardVeiculo(veiculo),
                  ),

                // VEÍCULOS EM MANUTENÇÃO / INATIVOS COM EXPANSIONTILE
                if (veiculosPendentes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      title: const Text(
                        'Em Manutenção / Inativos',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  // CONSTRUTOR DOS CARDS DE VEÍCULOS
  Widget _construirCardVeiculo(Map<String, dynamic> veiculo) {
    return CardVeiculo(
      veiculo: veiculo,
      onEditar: () => _abrirFormularioEdicao(veiculo),
      onDetalhes: () => _abrirDetalhes(veiculo),
      onStatusChanged: (novoStatus) => _alterarStatusVeiculo(veiculo, novoStatus),
    );
  }

  void _abrirFormularioVeiculo() {
    showDialog(
      context: context,
      builder: (context) => FormularioNovoVeiculo(
        onSalvo: () {
          setState(() {});
        },
      ),
    );
  }

  void _abrirFormularioEdicao(Map<String, dynamic> veiculo) {
    showDialog(
      context: context,
      builder: (context) => FormularioNovoVeiculo(
        veiculoParaEditar: veiculo,
        onSalvo: () {
          setState(() {});
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
        ),
      ),
    ).then((_) {
      setState(() {});
    });
  }
}
