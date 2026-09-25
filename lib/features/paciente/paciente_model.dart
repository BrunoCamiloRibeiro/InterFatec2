import 'package:flutter/material.dart';
import 'package:trans_saude/core/widgets/custom_dialog.dart';
import 'package:trans_saude/core/widgets/custom_infobox.dart';
import 'package:trans_saude/core/utils/mock_data.dart';
import 'package:trans_saude/models/motorista_model.dart';

void main() => runApp(MaterialApp(home: Paciente()));

class Paciente extends StatelessWidget {
  const Paciente({super.key});

  @override
  Widget build(BuildContext context) {
    // Puxa o JSON de mock_data.dart e converte para o modelo
    final motoristaAtual = MotoristaModel.fromJson(motoristaJson);

    return Scaffold(
      appBar: AppBar(title: Text('Painel')),
      body: Padding(
        padding: EdgeInsets.all(9.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Painel Paciente',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Status do seu transporte de saúde',
              style: TextStyle(color: Colors.grey),
            ),

            SizedBox(height: 20),

            // Renderiza o CustomInfobox com os dados do motorista atual
            CustomInfobox(motorista: motoristaAtual),

            Spacer(),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: Text('Já consegui Carona'),
                  onPressed: () {
                    CustomDialog.mostrar(
                      context: context,
                      title: "Confirmação de Carona",
                      content: "Você confirma que já conseguiu carona?",
                      onConfirmar: (context) {
                        print("O motorista será avisado");
                      },
                      onCancelar: (context) {
                        print("Ação cancelada pelo usuário");
                      },
                    );
                  },
                  
                ),
                   SizedBox(height: 12),

                           ElevatedButton(
              child: Text("Estou pronto"),
              onPressed: () {
                CustomDialog.mostrar(
                  context: context,
                  title: "Confirmação de partida",
                  content: "Tem certeza de que está pronto? O motorista será notificado da sua prontidão.",
                  onConfirmar: (context) {
                    String nomePaciente = "pacienteX";
                    print(
                      "Confirmação enviada! O motorista foi alertado de que $nomePaciente está pronto.",
                    );
                  },
                  onCancelar: (context) {
                    print("O paciente cancelou a ação.");
                  },
                );
              },
            ),      
              ],
            ),      
),
SizedBox(height: 20),  
          ],
        ),
      ),
    );
  }
}
