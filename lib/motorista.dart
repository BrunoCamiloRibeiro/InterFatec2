import 'package:flutter/material.dart';

import 'components/card_paciente.dart'; // DESCOMENTAR ESSA LINHA CASO SEJA NECESSÁRIO USAR A TIMELINE

// import 'package:timeline_tile/timeline_tile.dart';
// import '../components/TimelineViagem.dart'; // DESCOMENTAR ESSA LINHA CASO SEJA NECESSÁRIO USAR A TIMELINE

// STATUS
// embarque
// desembarque_destino
// reembarque
// desembarque_final

class Motorista extends StatelessWidget {
  const Motorista({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Lista de Passageiros'),
        ),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Column(
                spacing: 10,
                children: [
                  CardPaciente(
                    nomePaciente: 'Maria das Graças Aparecida de Jesus dos Santos',
                    enderecoPaciente: 'Rua das Flores, 125 - Centro',
                    telPaciente: '(17) 99123-4567',
                    localConsulta: 'Hospital de Base',
                    localSaida: 'Residência',
                    status: 0,
                  ),
                  CardPaciente(
                    nomePaciente: 'Teste de Nome Extremamente Longo com Muitos Caracteres e Palavras',
                    enderecoPaciente: 'Av. Alberto Andaló, 840',
                    telPaciente: '(17) 99234-5678',
                    localConsulta: 'UBS Central',
                    localSaida: 'Residência',
                    status: 1,
                  ),
                  CardPaciente(
                    nomePaciente: 'Ana Carolina Ferreira',
                    enderecoPaciente: 'Rua São Paulo, 56 - Vila Nova',
                    telPaciente: '(17) 99345-6789',
                    localConsulta: 'Hospital Austa',
                    localSaida: 'Clínica de Fisioterapia',
                    status: 2,
                  ),
                  CardPaciente(
                    nomePaciente: 'Carlos Eduardo Martins',
                    enderecoPaciente: 'Rua dos Ipês, 310',
                    telPaciente: '(17) 99456-7890',
                    localConsulta: 'AME São José do Rio Preto',
                    localSaida: 'Residência',
                    status: 3,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
