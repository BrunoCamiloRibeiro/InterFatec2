import 'package:flutter/material.dart';

void main() => runApp(const ListaPassageiros());

Color corStatus = Colors.redAccent;

class ListaPassageiros extends StatelessWidget {
  const ListaPassageiros({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Lista de Passageiros')),
        // Estilização do Scaffold
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
                      top: BorderSide(
                        color: Colors.blue,
                        width: 5.0,
                      ), //substituir cor por variável dinâmica posteriormente
                    ),
                  ),
                  child: ListTile(
                    // leading: Icon(
                    //   Icons.person, // Ícone padrão de usuário
                    //   size:
                    //       40.0, // Tamanho do ícone (ajuste conforme necessário)
                    //   color: Colors.grey, // Opcional: cor do ícone
                    // ), // Foto?
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
                            // margin: EdgeInsets.only(bottom: 4),
                            child: Text(
                              '(DD) 9XXXX-XXXX',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Locais de Consulta e Busca
                          Container(
                            margin: EdgeInsets.all(5),
                            padding: EdgeInsets.all(5),
                            // elevation: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Endereço de Embarque',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    // fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Local de Consulta',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    // fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Local de Busca',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    // fontWeight: FontWeight.bold,
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
                                    color: Colors.white, // Opcional: define a cor do texto para contrastar com o fundo
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      '13:45',
                      style: TextStyle(
                        fontSize: 18.0,
                        //fontWeight: FontWeight.bold, // Opcional: deixa o texto em negrito
                        //color: Colors.grey, // Ideia: definir a cor de acordo com horário atual
                      ),
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
