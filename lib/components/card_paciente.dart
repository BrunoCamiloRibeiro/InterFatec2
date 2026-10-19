
import 'package:flutter/material.dart';
import '../components/abreviar_textos.dart';

class CardPaciente extends StatelessWidget {
  final String nomePaciente;
  final String enderecoPaciente;
  final String telPaciente;
  final String localConsulta;
  final String localSaida;
  final int status;

  // Informa ao componente pai o novo status solicitado.
  final ValueChanged<int> onAlterarStatus;

  const CardPaciente({
    super.key,
    required this.nomePaciente,
    required this.enderecoPaciente,
    required this.telPaciente,
    required this.localConsulta,
    required this.localSaida,
    required this.status,
    required this.onAlterarStatus,
  });

  void _confirmarAlteracao(
    BuildContext context,
    int novoStatus,
  ) {
    final acaoTexto = novoStatus > status
        ? 'avançar'
        : 'retroceder';

    final descricaoStatus = switch (novoStatus) {
      0 => 'Pendente',
      1 => 'Embarcou',
      2 => 'Desembarcou',
      3 => 'Reembarcou Volta',
      4 => 'Desembarcou Final',
      // 5 => 'Cancelado',
      _ => 'Desconhecido',
    };

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmação'),
          content: Text(
            'Deseja $acaoTexto o status do passageiro '
            '${nomePaciente.toUpperCase()}?\n\n'
            'Novo status: $descricaoStatus.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onAlterarStatus(novoStatus);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final (Color corStatus, String textoStatus) = switch (status) {
      0 => (Colors.grey, 'Pendente'),
      1 => (Colors.blue, 'Embarcou'),
      2 => (Colors.orange, 'Desembarcou'),
      3 => (Colors.green, 'Concluído'),
      4 => (Colors.red, 'Cancelado'),
      _ => (Colors.black, 'Desconhecido'),
    };

    return Card(
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metade = constraints.maxWidth / 2;

          return Stack(
            children: [
              // Fundo vermelho suave: metade esquerda.
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: metade,
                child: Container(
                  color: Colors.red.withValues(alpha: 0.08),
                ),
              ),

              // Fundo verde suave: metade direita.
              Positioned(
                top: 0,
                bottom: 0,
                left: metade,
                right: 0,
                child: Container(
                  color: Colors.green.withValues(alpha: 0.08),
                ),
              ),

              // Conteúdo do card.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Colors.blueGrey.shade900,
                      width: 5,
                    ),
                  ),
                ),
                child: ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_2_outlined,
                            size: 25,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              TextAbbreviator.abbreviate(
                                nomePaciente,
                                maxCharacters: 30,
                                maxWords: 4,
                                keepWords: 1,
                              ).toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.house_outlined,
                            size: 25,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              enderecoPaciente,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 23,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              telPaciente,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 4),

                      // Local de consulta.
                      Row(
                        children: [
                          const Icon(
                            Icons.local_hospital_outlined,
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              localConsulta,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Local de saída.
                      Row(
                        children: [
                          const Icon(
                            Icons.exit_to_app_outlined,
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              localSaida,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Status atual.
                      Badge(
                        backgroundColor: corStatus,
                        label: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            textoStatus,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Área clicável esquerda: retrocede.
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: metade,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: status > 0
                        ? () => _confirmarAlteracao(
                              context,
                              status - 1,
                            )
                        : null,
                  ),
                ),
              ),

              // Área clicável direita: avança.
              Positioned(
                top: 0,
                bottom: 0,
                left: metade,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: status < 4
                        ? () => _confirmarAlteracao(
                              context,
                              status + 1,
                            )
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
