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
      return jsonDecode(jsonString) as List<dynamic>;
    } catch (_) {
      // Fallback para visualização caso o json não esteja disponível no bundle
      return [
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
    }
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('Erro ao carregar os veículos.'),
              );
            }

            final veiculos = snapshot.data ?? [];

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
      bottomNavigationBar: FutureBuilder<List<dynamic>>(
        future: _veiculosFuture,
        builder: (context, snapshot) {
          final veiculos = snapshot.data ?? [];
          final disponiveis = veiculos.where((v) => v['status'] == 'disponivel').length;
          return FooterVeiculos(
            veiculosDisponiveis: disponiveis,
            veiculosTotais: veiculos.length,
          );
        },
      ),
    );
  }

  // CONSTRUTOR DOS CARDS DE VEÍCULOS
  Widget _construirCardVeiculo(dynamic veiculo) {
    final mapaVeiculo = Map<String, dynamic>.from(veiculo as Map);
    return CardVeiculo(
      veiculo: mapaVeiculo,
      onEditar: () => _abrirFormularioEdicao(mapaVeiculo),
      onDetalhes: () => _abrirDetalhes(mapaVeiculo),
    );
  }

  void _abrirFormularioVeiculo() {
    showDialog(
      context: context,
      builder: (context) => const FormularioNovoVeiculo(),
    );
  }

  void _abrirFormularioEdicao(Map<String, dynamic> veiculo) {
    showDialog(
      context: context,
      builder: (context) => FormularioNovoVeiculo(
        veiculoParaEditar: veiculo,
      ),
    );
  }

  void _abrirDetalhes(Map<String, dynamic> veiculo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesVeiculo(veiculo: veiculo),
      ),
    );
  }
}
