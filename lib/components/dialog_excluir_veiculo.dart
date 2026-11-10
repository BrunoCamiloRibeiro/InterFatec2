import 'package:flutter/material.dart';
import '../controllers/veiculo_controller.dart';

class DialogExcluirVeiculo extends StatelessWidget {
  final String id;
  final String placa;
  final String modelo;
  final VoidCallback? onConfirmar;

  const DialogExcluirVeiculo({
    super.key,
    required this.id,
    required this.placa,
    required this.modelo,
    this.onConfirmar,
  });

  static Future<bool?> mostrar(
    BuildContext context, {
    required String id,
    required String placa,
    required String modelo,
    VoidCallback? onConfirmar,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DialogExcluirVeiculo(
        id: id,
        placa: placa,
        modelo: modelo,
        onConfirmar: onConfirmar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Confirmação'),
      content: SingleChildScrollView(
        child: Text(
          'Deseja confirmar a exclusão do veículo ${placa.toUpperCase()} ($modelo)?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red[700],
          ),
          onPressed: () {
            // Exclusão real no controller
            VeiculoController().removerVeiculo(id);
            Navigator.of(context).pop(true);
            if (onConfirmar != null) {
              onConfirmar!();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red[700],
                duration: const Duration(seconds: 2),
                content: Text('Veículo $placa excluído com sucesso!'),
              ),
            );
          },
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
