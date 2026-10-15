import 'package:flutter/material.dart';

class CardPaciente extends StatelessWidget {
  final String nome_paciente;
  final String endereco_paciente;
  final String tel_paciente;
  final String local_consulta;
  final String local_saida;
  final int status;

  CardPaciente({
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
      child: InkWell(
        // O InkWell fica logo DENTRO do Card por conta da animação
        onTap: () {
          String acaoTexto = switch (status) {
            0 => 'o embarque',
            1 => 'o desembarque',
            2 => 'a conclusão',
            _ => 'esta alteração',
          };

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Confirmação'),
                content: Text(
                  'Deseja confirmar ${acaoTexto.toUpperCase()} do passageiro ${nome_paciente.toUpperCase()}?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      // IMPLEMENTAR A LÓGICA DE ATUALIZAÇÃO DE STATUS AQUI
                      Navigator.of(context).pop();
                    },
                    child: Text('Confirmar'),
                  ),
                ],
              );
            },
          );
        },
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.blueGrey[900]!, width: 5.0),
            ),
          ),
          child: ListTile(
            // TITLE: Apenas as informações do paciente (Nome, Endereço, Telefone)
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_2_outlined, size: 25),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        nome_paciente.toUpperCase(),
                        maxLines: 2, // Permite até 2 linhas para nomes grandes
                        overflow: TextOverflow
                            .ellipsis, // Coloca '...' se passar de 2 linhas
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.house_outlined, size: 25),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        endereco_paciente,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 23),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        tel_paciente,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // SUBTITLE: Locais de Consulta/Saída e o Status logo abaixo
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Divider(),
                SizedBox(height: 4),
                // Local de Consulta
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined, size: 20),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        local_consulta,
                        maxLines: 2, // Alterado de 1 para 2
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                // Local de Saída
                Row(
                  children: [
                    const Icon(Icons.exit_to_app_outlined, size: 20),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        local_saida,
                        maxLines: 2, // Alterado de 1 para 2
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Badge de Status
                Badge(
                  backgroundColor: corStatus,
                  label: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      textoStatus,
                      style: TextStyle(fontSize: 12.0, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
