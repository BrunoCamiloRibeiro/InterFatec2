import 'package:flutter/material.dart';

class Paciente extends StatelessWidget {
  const Paciente({super.key});

  @override
  Widget build(BuildContext context) {
    final String titulo = "Seu Transporte da Tarde";
    final String status = "EM TRÂNSITO";
    final String motoristaNome = "Carlos Roberto";
    final String veiculoInfo = "Spin Prata • Placa: ABC-1D23";

    return Scaffold(
      appBar: AppBar(title: const Text('Painel')),
      body: Padding(
        padding: const EdgeInsets.all(9.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Painel Paciente',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Status do seu transporte de saúde',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motorista: $motoristaNome',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
            const Spacer(),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ElevatedButton(
                    child: const Text('Já consegui Carona'),
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
                  const SizedBox(width: 12),
                  ElevatedButton(
                    child: const Text("Estou pronto"),
                    onPressed: () {
                      _mostrarDialog(
                        context: context,
                        titulo: "Confirmação de partida",
                        mensagem:
                            "Tem certeza de que está pronto? O motorista será notificado da sua prontidão.",
                        onConfirmar: () {
                          const nomePaciente = "pacienteX";
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
            const SizedBox(height: 20),
          ],
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
              child: const Text('Sim'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirmar();
              },
            ),
            TextButton(
              child: const Text('Não'),
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
