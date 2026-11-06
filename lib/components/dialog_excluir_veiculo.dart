import 'package:flutter/material.dart';

class DialogExcluirVeiculo extends StatelessWidget {
  final String placa;
  final String modelo;
  final VoidCallback? onConfirmar;

  const DialogExcluirVeiculo({
    super.key,
    required this.placa,
    required this.modelo,
    this.onConfirmar,
  });

  static Future<bool?> mostrar(
    BuildContext context, {
    required String placa,
    required String modelo,
    VoidCallback? onConfirmar,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DialogExcluirVeiculo(
        placa: placa,
        modelo: modelo,
        onConfirmar: onConfirmar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmação'),
      content: Text(
        'Deseja confirmar a exclusão do veículo ${placa.toUpperCase()} ($modelo)?',
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
            Navigator.of(context).pop(true);
            if (onConfirmar != null) {
              onConfirmar!();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red[700],
                  content: Text('Veículo $placa excluído! (Apenas visual)'),
                ),
              );
            }
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
