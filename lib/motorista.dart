
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/card_paciente.dart';

class Motorista extends StatefulWidget {
  const Motorista({super.key});

  @override
  State<Motorista> createState() => _MotoristaState();
}

class _MotoristaState extends State<Motorista> {
  late Future<List<dynamic>> _futurePacientes;

  @override
  void initState() {
    super.initState();
    _futurePacientes = carregarPacientes();
  }

  Future<List<dynamic>> carregarPacientes() async {
    final String jsonString = await rootBundle.loadString(
      'assets/data/dados_pacientes.json',
    );

    return jsonDecode(jsonString) as List<dynamic>;
  }

  void _alterarStatus(int indice, int novoStatus) {
    setState(() {
      final pacientes = _pacientesCarregados;

      if (pacientes == null ||
          indice < 0 ||
          indice >= pacientes.length) {
        return;
      }

      pacientes[indice]['status'] = novoStatus;
    });
  }

  List<dynamic>? _pacientesCarregados;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Lista de Passageiros'),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _futurePacientes,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('Erro ao carregar os pacientes.'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Text('Nenhum paciente encontrado.'),
              );
            }

            // Guarda a lista carregada para atualizar os status
            // sem precisar ler novamente o arquivo JSON.
            _pacientesCarregados ??= snapshot.data!;

            final pacientes = _pacientesCarregados!;

            if (pacientes.isEmpty) {
              return const Center(
                child: Text('Nenhum paciente encontrado.'),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (int i = 0; i < pacientes.length; i++)
                  Builder(
                    builder: (context) {
                      final paciente =
                          pacientes[i] as Map<String, dynamic>;

                      final int status =
                          (paciente['status'] as num?)?.toInt() ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CardPaciente(
                          nomePaciente:
                              paciente['nomePaciente']?.toString() ?? '',
                          enderecoPaciente:
                              paciente['enderecoPaciente']?.toString() ?? '',
                          telPaciente:
                              paciente['telPaciente']?.toString() ?? '',
                          localConsulta:
                              paciente['localConsulta']?.toString() ?? '',
                          localSaida:
                              paciente['localSaida']?.toString() ?? '',
                          status: status,

                          // Callback que recebe o novo status
                          // e atualiza o paciente correspondente.
                          onAlterarStatus: (novoStatus) {
                            _alterarStatus(i, novoStatus);
                          },
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
