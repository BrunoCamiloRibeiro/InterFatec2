import 'package:flutter/material.dart';

class CardVeiculo extends StatelessWidget {
  final Map<String, dynamic> veiculo;
  final VoidCallback? onEditar;
  final VoidCallback? onDetalhes;
  final ValueChanged<String>? onStatusChanged;
  final ValueChanged<String>? onTagSelecionada;

  const CardVeiculo({
    super.key,
    required this.veiculo,
    this.onEditar,
    this.onDetalhes,
    this.onStatusChanged,
    this.onTagSelecionada,
  });

  @override
  Widget build(BuildContext context) {
    final String placa = (veiculo['placa'] ?? 'XXX-1234').toString();
    final String marca = (veiculo['marca'] ?? 'Marca').toString();
    final String modelo = (veiculo['modelo'] ?? 'Modelo').toString();
    final dynamic ano = veiculo['ano'] ?? 'YYYY';
    final String tipoRaw = (veiculo['tipo'] ?? 'carro')
        .toString()
        .toLowerCase();
    final String statusRaw = (veiculo['status'] ?? 'disponivel').toString();
    final dynamic km = veiculo['quilometragemAtual'] ?? 0;
    final dynamic assentos = veiculo['qtdAssentos'] ?? 0;
    final String ultimoMotorista =
        (veiculo['ultimoMotoristaId'] ??
                'Nome do Último Motorista')
            .toString();
    final bool possuiAC = veiculo['possuiAC'] == true;
    final bool possuiPreferencial = veiculo['possuiPreferencial'] == true;
    final String? observacoes = veiculo['observacoes']?.toString();

    // Ícone e tipo de acordo com a categoria
    final (IconData iconeTipo, String labelTipo) = switch (tipoRaw) {
      'van' => (Icons.airport_shuttle_outlined, 'Van'),
      'ambulancia' => (Icons.emergency_outlined, 'Ambulância'),
      'onibus' || 'microonibus' => (Icons.directions_bus_outlined, 'Ônibus'),
      _ => (Icons.directions_car_outlined, 'Carro'),
    };

    // Cores e texto do status no estilo original com Color.lerp
    final (Color corBase, String textoStatus) = switch (statusRaw) {
      'disponivel' => (Colors.green, 'Disponível'),
      'emManutencao' => (Colors.orange, 'Em Manutenção'),
      'emViagem' || 'emUso' => (Colors.blue, 'Em Viagem'),
      'inativo' => (Colors.grey, 'Inativo'),
      _ => (Colors.grey, statusRaw),
    };

    final List<Map<String, dynamic>> statusOpcoes = [
      {'valor': 'disponivel', 'label': 'Disponível', 'cor': Colors.green},
      {'valor': 'emViagem', 'label': 'Em Viagem', 'cor': Colors.blue},
      {'valor': 'emManutencao', 'label': 'Em Manutenção', 'cor': Colors.orange},
      {'valor': 'inativo', 'label': 'Inativo', 'cor': Colors.grey},
    ];

    final String statusNormalizado = switch (statusRaw) {
      'emUso' => 'emViagem',
      'disponivel' || 'emViagem' || 'emManutencao' || 'inativo' => statusRaw,
      _ => 'disponivel',
    };

    return Card(
      elevation: 12, // Estilo original mantido exatamente
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14, // Estilo original mantido exatamente
          children: [
            // IDENTIFICAÇÃO E STATUS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IDENTIFICAÇÃO
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placa,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$marca $modelo · $ano',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    Row(
                      children: [
                        Icon(iconeTipo, size: 20, color: Colors.grey[700]),
                        const SizedBox(width: 5),
                        Text(
                          labelTipo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // STATUS INDICATOR COM ÁREA INTEIRA CLICÁVEL
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: corBase.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      clipBehavior: Clip.antiAlias, // Garante que o splash cubra a pílula toda
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          // O padding fica diretamente no DropdownButton para tornar a área toda clicável
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          value: statusNormalizado,
                          isDense: true,
                          menuWidth: 180,
                          borderRadius: BorderRadius.circular(16),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: Color.lerp(corBase, Colors.black, 0.5),
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            return statusOpcoes.map((op) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: Color.lerp(
                                      corBase,
                                      Colors.black,
                                      0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    textoStatus,
                                    style: TextStyle(
                                      color: Color.lerp(
                                        corBase,
                                        Colors.black,
                                        0.5,
                                      ),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                          items: statusOpcoes.map((op) {
                            final Color cor = op['cor'] as Color;
                            return DropdownMenuItem<String>(
                              value: op['valor'] as String,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: Color.lerp(cor, Colors.black, 0.5),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    op['label'] as String,
                                    style: TextStyle(
                                      color: Color.lerp(cor, Colors.black, 0.5),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (novoStatus) {
                            if (novoStatus != null && onStatusChanged != null) {
                              onStatusChanged!(novoStatus);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // INFORMAÇÕES OPERACIONAIS
            Row(
              spacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    // QUILOMETRAGEM E QTD DE ASSENTOS
                    Row(
                      children: [
                        // QUILOMETRAGEM
                        Row(
                          children: [
                            Icon(
                              Icons.speed_outlined,
                              size: 20,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quilometragem Atual',
                                  style: TextStyle(
                                    color: Color.lerp(
                                      Colors.grey,
                                      Colors.black,
                                      0.5,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '$km km',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // QTD DE ASSENTOS
                        Row(
                          children: [
                            Icon(
                              Icons.chair_outlined,
                              size: 20,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Qtd. de Assentos',
                                  style: TextStyle(
                                    color: Color.lerp(
                                      Colors.grey,
                                      Colors.black,
                                      0.5,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '$assentos',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    // ÚLTIMO MOTORISTA
                    Row(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_outlined,
                              size: 20,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Último Motorista',
                                  style: TextStyle(
                                    color: Color.lerp(
                                      Colors.grey,
                                      Colors.black,
                                      0.5,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  ultimoMotorista,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // TAGS / EXTRAS DO VEÍCULO (CLICÁVEIS PARA FILTRAR)
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (possuiAC)
                  TextButton.icon(
                    onPressed: () {
                      if (onTagSelecionada != null) {
                        onTagSelecionada!('ac');
                      }
                    },
                    icon: const Icon(Icons.ac_unit_outlined, size: 16),
                    label: const Text(
                      'Ar-condicionado',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      foregroundColor: Color.lerp(
                        Colors.blue,
                        Colors.black,
                        0.4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                if (possuiPreferencial)
                  TextButton.icon(
                    onPressed: () {
                      if (onTagSelecionada != null) {
                        onTagSelecionada!('preferencial');
                      }
                    },
                    icon: const Icon(Icons.accessible_outlined, size: 16),
                    label: const Text(
                      'Acesso Preferencial',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Color(0xFF2D2F8D).withValues(alpha: 1),
                      foregroundColor: Color.lerp(
                        Color(0xFF2D2F8D),
                        Colors.white,
                        0.8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
              ],
            ),

            // OBSERVAÇÃO
            if (observacoes != null && observacoes.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.help_outline_outlined,
                                size: 20,
                                color: Color.lerp(
                                  Colors.orange,
                                  Colors.brown,
                                  0.5,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Observação',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color.lerp(
                                    Colors.orange,
                                    Colors.brown,
                                    0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            observacoes,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // BOTÕES DE EDITAR E VER DETALHES (Estilo original 100% preservado)
            const Divider(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.all(20),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadiusGeometry.circular(8),
                        ),
                      ),
                    ),
                    onPressed: onEditar,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 25,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Editar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color.lerp(Colors.grey, Colors.black, 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 100),
                Expanded(
                  child: TextButton(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.all(20),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadiusGeometry.circular(8),
                        ),
                      ),
                    ),
                    onPressed: onDetalhes,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Ver Detalhes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color.lerp(Colors.grey, Colors.black, 0.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.arrow_forward_outlined,
                          size: 25,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
