import 'package:flutter/material.dart';

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
              Card(
                elevation: 12,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Colors.blueGrey[900]!,
                        width: 5.0,
                      ),
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
                                  'nome da pessoa'.toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.house_outlined, size: 25),
                                SizedBox(width: 5),
                                Text(
                                  'Endereço Residência',
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
                                  '(DD) 9XXXX-XXXX',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Local Consulta',
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 5),
                                Icon(Icons.local_hospital_outlined, size: 25),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'Local Desembarque',
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 5),
                                Icon(Icons.exit_to_app_outlined, size: 25),
                              ],
                            ),
                          ],
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
                                'Status',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
