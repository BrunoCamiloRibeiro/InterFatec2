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
    final String placa = (veiculo['placa'] ?? '-').toString();
    final String marca = (veiculo['marca'] ?? '').toString().trim();
    final String modelo = (veiculo['modelo'] ?? 'Modelo').toString().trim();
    final dynamic ano = veiculo['ano'] ?? 'YYYY';
    final String descricaoVeiculo = (marca.isNotEmpty &&
            marca.toLowerCase() != 'marca' &&
            !modelo.toLowerCase().startsWith(marca.toLowerCase()))
        ? '$marca $modelo · $ano'
        : '$modelo · $ano';
    final String tipoRaw = (veiculo['tipo'] ?? 'carro')
        .toString()
        .toLowerCase();
    final String statusRaw = (veiculo['status'] ?? 'disponivel').toString();
    final dynamic km = veiculo['quilometragemAtual'] ?? 0;
    final dynamic assentos = veiculo['qtdAssentos'] ?? 0;
    final String rawMotorista =
        (veiculo['ultimoMotoristaNome'] ?? veiculo['ultimoMotoristaId'] ?? '')
            .toString()
            .trim();
    final String ultimoMotorista = (rawMotorista.isEmpty ||
            rawMotorista == 'null' ||
            rawMotorista == 'motorista_atual')
        ? 'Não informado'
        : (rawMotorista == 'mot_inicial_01'
            ? 'Roberto Almeida Prado'
            : rawMotorista);
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placa,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descricaoVeiculo,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(iconeTipo, size: 18, color: Colors.grey[700]),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              labelTipo,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // STATUS INDICATOR COM ÁREA INTEIRA CLICÁVEL
                Container(
                  decoration: BoxDecoration(
                    color: corBase.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      value: statusNormalizado,
                      isDense: true,
                      menuWidth: 175,
                      borderRadius: BorderRadius.circular(16),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: Color.lerp(corBase, Colors.black, 0.5),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return statusOpcoes.map((op) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 9,
                                color: Color.lerp(
                                  corBase,
                                  Colors.black,
                                  0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                textoStatus,
                                style: TextStyle(
                                  color: Color.lerp(
                                    corBase,
                                    Colors.black,
                                    0.5,
                                  ),
                                  fontSize: 13,
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

            // INFORMAÇÕES OPERACIONAIS
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                // QUILOMETRAGEM E QTD DE ASSENTOS
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // QUILOMETRAGEM
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.speed_outlined,
                            size: 20,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // QTD DE ASSENTOS
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.chair_outlined,
                            size: 20,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // ÚLTIMO MOTORISTA
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.person_outline_outlined,
                      size: 20,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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

            // BOTÕES DE EDITAR E VER DETALHES
            const Divider(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                          size: 20,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Editar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color.lerp(Colors.grey, Colors.black, 0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        Flexible(
                          child: Text(
                            'Ver Detalhes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color.lerp(Colors.grey, Colors.black, 0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_outlined,
                          size: 20,
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
