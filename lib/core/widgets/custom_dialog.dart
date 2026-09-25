import 'package:flutter/material.dart';

class CustomDialog {
  static Future<void> mostrar({
    required BuildContext context,
    required String title,
    required String content,
    required void Function(BuildContext) onConfirmar,
    void Function(BuildContext)? onCancelar,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text('Sim'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirmar(context);
              },
            ),
            TextButton(child: Text('Não'), 
            onPressed: () {
            Navigator.of(context).pop();
            if (onCancelar !=  null) onCancelar(context);  
            }),

          ],
        );
      },
    );
  }
}
