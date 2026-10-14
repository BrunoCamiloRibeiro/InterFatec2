import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';

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
                                // 1. Embarque (Início)
                                TimelineTile(
                                  isFirst: true,
                                  alignment: TimelineAlign
                                      .center, // <-- Adicionado aqui
                                  startChild: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text(
                                      '05:30',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        color: Colors.black,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  indicatorStyle: IndicatorStyle(
                                    width: 24,
                                    color: Colors.blue,
                                    iconStyle: IconStyle(
                                      iconData: Icons.location_pin,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  endChild: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Endereço de Embarque',
                                      style: TextStyle(fontSize: 13.0),
                                    ),
                                  ),
                                ),

                                // 2. Consulta (Meio)
                                TimelineTile(
                                  alignment: TimelineAlign
                                      .center, // <-- Adicionado aqui
                                  startChild: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text(
                                      '10:30',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        color: Colors.black,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  indicatorStyle: IndicatorStyle(
                                    width: 24,
                                    color: Colors.blue,
                                    iconStyle: IconStyle(
                                      iconData: Icons.local_hospital_outlined,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  endChild: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Local de Consulta',
                                      style: TextStyle(fontSize: 13.0),
                                    ),
                                  ),
                                ),

                                // 3. Busca (Fim)
                                TimelineTile(
                                  isLast: true,
                                  alignment: TimelineAlign
                                      .center, // <-- Adicionado aqui
                                  startChild: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text(
                                      '13:45',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        color: Colors.black,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  indicatorStyle: IndicatorStyle(
                                    width: 24,
                                    color: Colors.blue,
                                    iconStyle: IconStyle(
                                      iconData: Icons.logout_outlined,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  endChild: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Local de Busca',
                                      style: TextStyle(fontSize: 13.0),
                                    ),
                                  ),
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
