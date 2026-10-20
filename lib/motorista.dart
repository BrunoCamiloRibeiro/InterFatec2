import 'dart:convert'; // Converte o texto JSON em objetos Dart usando jsonDecode()

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Disponibiliza rootBundle, usado para ler o arquivo JSON dos assets do aplicativo

import 'components/card_paciente.dart';

class Motorista extends StatefulWidget {
  const Motorista({super.key});

  @override
  State<Motorista> createState() => _MotoristaState();
}

class _MotoristaState extends State<Motorista> {
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
                    child: Dismissible(
                      key: ValueKey(
                        paciente['nomePaciente'],
                      ), // trocar isso pelo ID depois
                      direction: DismissDirection.horizontal,
                      background: Container(
                        padding: EdgeInsets.only(left: 16),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(100),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                      secondaryBackground: Container(
                        padding: EdgeInsets.only(right: 16),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(100),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // INSERIR LÓGICA DE RETROCEDER STATUS
                          // Possivel ideia: ter múltiplas listas e ao puxar ela se move para outra lista
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puxado da Esquerda para a Direita')));
                        } else if (direction == DismissDirection.endToStart) {
                          // INSERIR LÓGICA DE AVANÇAR STATUS
                          // Possivel ideia: ter múltiplas listas e ao puxar ela se move para outra lista
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puxado da Direita para a Esquerda')));
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
    );
  }
}
