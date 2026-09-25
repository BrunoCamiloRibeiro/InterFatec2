import 'package:flutter/material.dart';

// tela do paciente sem Scaffold e usando Material
class Paciente extends StatelessWidget {
  Paciente({super.key});

  @override
  Widget build(BuildContext context) {
    final String titulo = "Seu Transporte da Tarde";
    final String status = "EM TRÂNSITO";
    final String motoristaNome = "Carlos Roberto";
    final String veiculoInfo = "Spin Prata • Placa: ABC-1D23";

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // botão voltar já que não tem AppBar do Scaffold
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Text(
                    'Painel',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Painel Paciente',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                'Status do seu transporte de saúde',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Material(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Motorista: $motoristaNome',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                veiculoInfo,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Spacer(),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      child: Text('Já consegui Carona'),
                      onPressed: () {
                        _mostrarDialog(
                          context: context,
                          titulo: "Confirmação de Carona",
                          mensagem: "Você confirma que já conseguiu carona?",
                          onConfirmar: () {
                            debugPrint("O motorista será avisado");
                          },
                          onCancelar: () {
                            debugPrint("Ação cancelada pelo usuário");
                          },
                        );
                      },
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      child: Text("Estou pronto"),
                      onPressed: () {
                        _mostrarDialog(
                          context: context,
                          titulo: "Confirmação de partida",
                          mensagem: "Tem certeza de que está pronto? O motorista será notificado da sua prontidão.",
                          onConfirmar: () {
                            final nomePaciente = "pacienteX";
                            debugPrint(
                              "Confirmação enviada! O motorista foi alertado de que $nomePaciente está pronto.",
                            );
                          },
                          onCancelar: () {
                            debugPrint("O paciente cancelou a ação.");
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
      ),
    );
  }

  void _mostrarDialog({
    required BuildContext context,
    required String titulo,
    required String mensagem,
    required VoidCallback onConfirmar,
    VoidCallback? onCancelar,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensagem),
          actions: <Widget>[
            TextButton(
              child: Text('Sim'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirmar();
              },
            ),
            TextButton(
              child: Text('Não'),
              onPressed: () {
                Navigator.of(context).pop();
                if (onCancelar != null) onCancelar();
              },
            ),
          ],
        );
      },
    );
  }
}
