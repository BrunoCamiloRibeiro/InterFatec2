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
                .where((p) => p['status'] == 0)
                .toList();
            final pacientesAtivos = pacientes
                .where((p) => p['status'] != 0)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // PACIENTES ATIVOS
                ExpansionTile(
                  title: Text('Em Viagem'),
                  initiallyExpanded: true,
                  children: [
                    for (final paciente in pacientesAtivos)
                      _construirCardPaciente(paciente),
                  ],
                ),
                // PACIENTES PENDENTES
                ExpansionTile(
                  title: Text('Pendentes'),
                  initiallyExpanded: false,
                  children: [
                    for (final paciente in pacientesPendentes)
                      _construirCardPaciente(paciente),
                  ],
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
  // CONSTRUTOR DOS CARDS DE PACIENTES
  Widget _construirCardPaciente(dynamic paciente) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(paciente['nomePaciente']), // trocar isso pelo ID depois
        direction: switch (paciente['status'] as int) {
          0 => DismissDirection.endToStart,
          4 => DismissDirection.startToEnd,
          5 => DismissDirection.none,
          _ => DismissDirection.horizontal,
        },

        background: Container(
          padding: EdgeInsets.only(left: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(100),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, color: Colors.white, size: 50),
              Text('Retroceder', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        secondaryBackground: Container(
          padding: EdgeInsets.only(right: 16),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(100),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_forward, color: Colors.white, size: 50),
              Text('Avançar', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          final int statusAtual = paciente['status'] as int;
          int novoStatus = statusAtual;

          if (direction == DismissDirection.startToEnd) {
            // LÓGICA DE RETROCEDER STATUS
            if (statusAtual > 0 && statusAtual < 5) {
              novoStatus = statusAtual - 1;
            }
          } else if (direction == DismissDirection.endToStart) {
            // INSERIR LÓGICA DE AVANÇAR STATUS
            if (statusAtual >= 0 && statusAtual < 4) {
              novoStatus = statusAtual + 1;
            }
          }
          if (novoStatus != statusAtual) {
            setState(() {
              paciente['status'] = novoStatus;
            });
          }
          return false; // Serve para fazer o Flutter não eliminar completamente o elemento o Card do Paciente
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
    );
  }
}

