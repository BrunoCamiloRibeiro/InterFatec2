import 'dart:convert'; // Converte o texto JSON em objetos Dart usando jsonDecode()

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Disponibiliza rootBundle, usado para ler o arquivo JSON dos assets do aplicativo

import 'components/card_paciente.dart';

class Motorista extends StatelessWidget {
  const Motorista({super.key});

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
          future: carregarPacientes(),
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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final paciente in pacientes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CardPaciente(
                      nomePaciente: paciente['nomePaciente'],
                      enderecoPaciente: paciente['enderecoPaciente'],
                      telPaciente: paciente['telPaciente'],
                      localConsulta: paciente['localConsulta'],
                      localSaida: paciente['localSaida'],
                      status: paciente['status'],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
