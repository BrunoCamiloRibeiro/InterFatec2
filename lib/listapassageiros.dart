import 'package:flutter/material.dart';

void main() => runApp(const ListaPassageiros());

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
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.blue,
                        width: 3.0,
                      ), //substituir cor por variável dinâmica posteriormente
                    ),
                  ),
                  child: ListTile(
                    leading: FlutterLogo(size: 56.0), // Foto?
                    title: Text('NOME DA PESSOA'),
                    subtitle: Text('Destino/Lugar a buscar'),
                    // trailing: Icon(Icons.more_vert),
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
