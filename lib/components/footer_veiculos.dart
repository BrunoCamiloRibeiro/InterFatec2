import 'package:flutter/material.dart';

// Componente visual do Footer (rodapé) da lista de veículos.
// Mantém o exato padrão do FooterPacientes com ocupação na esquerda e botão na direita.
class FooterVeiculos extends StatelessWidget {
  final int veiculosDisponiveis;
  final int veiculosTotais;

  const FooterVeiculos({
    super.key,
    required this.veiculosDisponiveis,
    required this.veiculosTotais,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 20,
                color: Colors.blueGrey[900],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Veículos: $veiculosDisponiveis / $veiculosTotais',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
