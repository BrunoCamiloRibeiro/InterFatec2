import 'dart:convert'; // Converte o texto JSON em objetos Dart usando jsonDecode()

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Disponibiliza rootBundle, usado para ler o arquivo JSON dos assets do aplicativo

import 'components/card_paciente.dart';
import 'components/footer_pacientes.dart';

class Motorista extends StatefulWidget {
  const Motorista({super.key});

  @override
  State<Motorista> createState() => _MotoristaState();
}

class _MotoristaState extends State<Motorista> {
  late Future<List<dynamic>> _pacientesFuture;

  @override
  void initState() {
    super.initState();
    _pacientesFuture = carregarPacientes();
  }

  Future<List<dynamic>> carregarPacientes() async {
    final String jsonString = await rootBundle.loadString(
      'assets/data/dados_pacientes.json',
    );

    return jsonDecode(jsonString) as List<dynamic>;
  }

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
          future: _pacientesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('Erro ao carregar os pacientes.'),
              );
            }

            final pacientes = snapshot.data ?? [];

            final pacientesPendentes = pacientes
                .where((paciente) => paciente['status'] == 0)
                .toList();

            final pacientesAtivos = pacientes
                .where((paciente) => paciente['status'] != 0)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // LISTA EXPANSÍVEL DE PENDENTES
                if (pacientesPendentes.isNotEmpty)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      leading: const Icon(
                        Icons.pending_actions,
                        color: Colors.grey,
                      ),
                      title: const Text(
                        'Pendentes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${pacientesPendentes.length} passageiros',
                      ),
                      children: [
                        for (final paciente in pacientesPendentes)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                            child: Dismissible(
                              key: ValueKey(paciente['nomePaciente']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 16),
                                color: Colors.red.withAlpha(100),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Colors.green.withAlpha(100),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                final int statusAtual =
                                    paciente['status'] as int;

                                if (direction == DismissDirection.endToStart &&
                                    statusAtual < 4) {
                                  setState(() {
                                    paciente['status'] = statusAtual + 1;
                                  });
                                }

                                return false;
                              },
                              child: CardPaciente(
                                nomePaciente: paciente['nomePaciente'],
                                enderecoPaciente: paciente['enderecoPaciente'],
                                telPaciente: paciente['telPaciente'],
                                localConsulta: paciente['localConsulta'],
                                localSaida: paciente['localSaida'],
                                status: paciente['status'],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // LISTA PRINCIPAL
                for (final paciente in pacientesAtivos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey(paciente['nomePaciente']),
                      direction: switch (paciente['status'] as int) {
                        4 => DismissDirection.startToEnd,
                        5 => DismissDirection.none,
                        _ => DismissDirection.horizontal,
                      },
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(100),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(100),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        final int statusAtual = paciente['status'] as int;
                        int novoStatus = statusAtual;

                        if (direction == DismissDirection.startToEnd) {
                          if (statusAtual > 0 && statusAtual < 5) {
                            novoStatus = statusAtual - 1;
                          }
                        } else if (direction == DismissDirection.endToStart) {
                          if (statusAtual >= 0 && statusAtual < 4) {
                            novoStatus = statusAtual + 1;
                          }
                        }

                        if (novoStatus != statusAtual) {
                          setState(() {
                            paciente['status'] = novoStatus;
                          });
                        }

                        return false;
                      },
                      child: CardPaciente(
                        nomePaciente: paciente['nomePaciente'],
                        enderecoPaciente: paciente['enderecoPaciente'],
                        telPaciente: paciente['telPaciente'],
                        localConsulta: paciente['localConsulta'],
                        localSaida: paciente['localSaida'],
                        status: paciente['status'],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      // Rodapé compacto fixo na parte inferior da tela do motorista
      bottomNavigationBar: const FooterPacientes(
        lugaresPreenchidos: 7,
        lugaresTotais: 15,
      ),
    );
  }
}
