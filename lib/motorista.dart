import 'package:flutter/material.dart';
// import 'package:timeline_tile/timeline_tile.dart';
import '../components/TimelineViagem.dart';

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
                      top: BorderSide(color: Colors.blueGrey[900]!, width: 5.0),
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      'NOME DA PESSOA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            child: Text(
                              '(DD) 9XXXX-XXXX',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Timeline com timeline_tile
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                // Embarque
                                TimelineViagem(
                                  isFirst: true,
                                  isLast: false,
                                  isPast: true,
                                  horario: '01:00',
                                  local: 'Endereço de Embarque',
                                  icone: Icons.location_pin
                                ),
                                // Local da Consulta
                                TimelineViagem(
                                  isFirst: false,
                                  isLast: false,
                                  isPast: false,
                                  horario: '02:00',
                                  local: 'Endereço de Consulta',
                                  icone: Icons.local_hospital_outlined
                                ),
                                // Local de Saída
                                TimelineViagem(
                                  isFirst: false,
                                  isLast: true,
                                  isPast: false,
                                  horario: '03:00',
                                  local: 'Endereço de Desembarque',
                                  icone: Icons.exit_to_app_outlined,
                                ),
                              ],
                            ),
                          ),

                          Container(
                            margin: EdgeInsets.only(top: 4.0),
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
                    // trailing: Text('13:45', style: TextStyle(fontSize: 18.0)),
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
