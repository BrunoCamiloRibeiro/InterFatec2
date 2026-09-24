import 'package:flutter/material.dart';

void main()=> runApp(
   MaterialApp(
    home:Paciente())
   );


Future<void> confirmarCarona(BuildContext context){
  return showDialog<void>(
    context: context,
    builder: (BuildContext context){
      return AlertDialog(
      title: Text('Confirmação'),
      content: Text('Você confirma que já conseguiu carona?'),  
      actions: <Widget>[
        TextButton(child:
        Text("Sim"), onPressed: (){
          Navigator.of(context).pop();
        }),
        TextButton(child:
        Text("Não"), onPressed: (){
          Navigator.of(context).pop();
        }
        ),  
      ],
      );
    },
  );

}

class Paciente extends StatelessWidget {
  const Paciente({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Paciente')),
      body: Center(
        child: Column(
          children: <Widget>[
            ElevatedButton(
              child: Text('Já consegui Carona'),
              onPressed: () {
                confirmarCarona(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
