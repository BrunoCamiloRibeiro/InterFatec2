import 'package:flutter/material.dart';

import 'formulario_encerramento.dart';

// Componente visual do Footer (rodapé) da lista de pacientes do motorista.
// Estrutura compacta em linha única: ocupação de lugares na esquerda e botão que abre o Popup de encerramento na direita.
class FooterPacientes extends StatelessWidget {
  // Quantidade de lugares ocupados atualmente no veículo
  final int lugaresPreenchidos;

  // Capacidade total de lugares do veículo
  final int lugaresTotais;

  // Construtor recebendo os números de lugares preenchidos e totais
  const FooterPacientes({
    super.key,
    required this.lugaresPreenchidos,
    required this.lugaresTotais,
  });

  @override
  Widget build(BuildContext context) {
    // Container compacto do rodapé com fundo branco e linha divisória no topo
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          // Borda superior sutil para separar o Footer da lista de pacientes
          top: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
      ),
      // Linha única horizontal dividindo esquerda (lugares) e direita (botão)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ESQUERDA: Informação do número de passageiros/assentos (preenchidos / total)
          Row(
            children: [
              Icon(
                Icons.event_seat_outlined,
                size: 20,
                color: Colors.blueGrey[900],
              ),
              const SizedBox(width: 8),
              Text(
                'Lugares: $lugaresPreenchidos / $lugaresTotais',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
              ),
            ],
          ),

          // DIREITA: Botão compacto que abre o POPUP do Formulário de Encerramento
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
              'Gerar Relatório',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              // Abre o POPUP do Formulário de Encerramento (Retorno, Km Retorno, Km Rodado)
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const FormularioEncerramento();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
