import 'package:flutter/material.dart';
// import 'package:timeline_tile/timeline_tile.dart';
import '../components/TimelinePassageiro.dart';

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
                      top: BorderSide(color: Colors.blue, width: 5.0),
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
                                TimelinePassageiro(isFirst: true, isLast: false, isPast: true),
                                // Local da Consulta
                                TimelinePassageiro(isFirst: false, isLast: false, isPast: false),
                                // Local de Saída
                                TimelinePassageiro(isFirst: false, isLast: true, isPast: false),
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
                    trailing: Text('13:45', style: TextStyle(fontSize: 18.0)),
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
