import 'package:flutter/material.dart';

class FormularioNovoPassageiro extends StatelessWidget {
  const FormularioNovoPassageiro({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      // TÍTULO
      title: Row(
        children: [
          Icon(
            Icons.person_add_alt_1_outlined,
            color: Colors.blueGrey[900],
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Novo Passageiro',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              ),
            ),
          ),
        ],
      ),

      // CAMPOS DO FORMULÁRIO
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _campo(
                'Nome do Passageiro',
                'Nome completo',
                Icons.person_outline,
              ),
              const SizedBox(height: 14),

              _campo(
                'Endereço',
                'Endereço do passageiro',
                Icons.location_on_outlined,
              ),
              const SizedBox(height: 14),

              _campo('Telefone', '(00) 00000-0000', Icons.phone_outlined),
              const SizedBox(height: 14),

              _campo('Local de Saída', 'Ex: Residência', Icons.trip_origin),
              const SizedBox(height: 14),

              _campo(
                'Local da Consulta',
                'Ex: Hospital de Base',
                Icons.local_hospital_outlined,
              ),
            ],
          ),
        ),
      ),

      // BOTÕES
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // CONSTRUTOR DOS CAMPOS
  Widget _campo(String titulo, String dica, IconData icone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(icone, size: 20, color: Colors.blueGrey[900]),
            hintText: dica,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }
}
