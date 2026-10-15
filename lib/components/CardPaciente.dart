import 'package:flutter/material.dart';

class CardPaciente extends StatelessWidget {
  final String nome_paciente;
  final String endereco_paciente;
  final String tel_paciente;
  final String local_consulta;
  final String local_saida;
  final int status;

  const CardPaciente({
    super.key,
    required this.nome_paciente,
    required this.endereco_paciente,
    required this.tel_paciente,
    required this.local_consulta,
    required this.local_saida,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (Color corStatus, String textoStatus) = switch (status) {
      0 => (Colors.grey, 'Pendente'),
      1 => (Colors.blue, 'Embarcou'),
      2 => (Colors.orange, 'Desembarcou'),
      3 => (Colors.green, 'Concluído'),
      4 => (Colors.red, 'Cancelado'),
      _ => (Colors.black, 'Desconhecido'),
    };

    return Card(
      elevation: 12,
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Colors.blueGrey[900]!, width: 5.0),
          ),
        ),
        child: ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Joga o nome pra esquerda e a coluna pra direita
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_2_outlined, size: 25),
                      SizedBox(width: 5),
                      Text(
                        nome_paciente.toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.house_outlined, size: 25),
                      SizedBox(width: 5),
                      Text(
                        endereco_paciente,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 23),
                      SizedBox(width: 5),
                      Text(
                        tel_paciente,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            local_consulta,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.local_hospital_outlined, size: 25),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            local_saida,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.exit_to_app_outlined, size: 25),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          subtitle: Row(
            children: [
              Container(
                margin: EdgeInsets.only(top: 10),
                child: Badge(
                  backgroundColor: corStatus,
                  label: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      textoStatus,
                      style: TextStyle(fontSize: 12.0, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
