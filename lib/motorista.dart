import 'package:flutter/material.dart';

import '../components/CardPaciente.dart'; // DESCOMENTAR ESSA LINHA CASO SEJA NECESSÁRIO USAR A TIMELINE

// import 'package:timeline_tile/timeline_tile.dart';
// import '../components/TimelineViagem.dart'; // DESCOMENTAR ESSA LINHA CASO SEJA NECESSÁRIO USAR A TIMELINE

// STATUS
// embarque
// desembarque_destino
// reembarque
// desembarque_final
Color corStatus = Colors.redAccent;

class Motorista extends StatelessWidget {
  const Motorista({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Lista de Passageiros')),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(16),
            children: <Widget>[
              Column(
                spacing: 10,
                children: [
                  CardPaciente(
                    nome_paciente: 'Maria Aparecida Santos',
                    endereco_paciente: 'Rua das Flores, 125 - Centro',
                    tel_paciente: '(17) 99123-4567',
                    local_consulta: 'Hospital de Base',
                    local_saida: 'Residência',
                    status: 0,
                  ),
                  CardPaciente(
                    nome_paciente: 'João Pedro Oliveira',
                    endereco_paciente: 'Av. Alberto Andaló, 840',
                    tel_paciente: '(17) 99234-5678',
                    local_consulta: 'UBS Central',
                    local_saida: 'Residência',
                    status: 1,
                  ),
                  CardPaciente(
                    nome_paciente: 'Ana Carolina Ferreira',
                    endereco_paciente: 'Rua São Paulo, 56 - Vila Nova',
                    tel_paciente: '(17) 99345-6789',
                    local_consulta: 'Hospital Austa',
                    local_saida: 'Clínica de Fisioterapia',
                    status: 2,
                  ),
                  CardPaciente(
                    nome_paciente: 'Carlos Eduardo Martins',
                    endereco_paciente: 'Rua dos Ipês, 310',
                    tel_paciente: '(17) 99456-7890',
                    local_consulta: 'AME São José do Rio Preto',
                    local_saida: 'Residência',
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
