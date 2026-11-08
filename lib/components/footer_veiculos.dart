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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ESQUERDA: Quantidade de veículos disponíveis / totais
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 20,
                      color: Colors.blueGrey[900],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
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
              const SizedBox(width: 8),

              // DIREITA: Botão compacto para gerar relatório da frota (apenas visual)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.assignment_outlined, size: 18),
                label: const Text(
                  'Relatório Frota',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Relatório da Frota'),
                        content: Text(
                          'Resumo operacional da frota:\n\n'
                          '• Total de veículos: $veiculosTotais\n'
                          '• Disponíveis: $veiculosDisponiveis\n'
                          '• Em manutenção / outros: ${veiculosTotais - veiculosDisponiveis}\n\n'
                          '(Funcionalidade visual)',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Fechar'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
