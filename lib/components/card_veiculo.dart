import 'package:flutter/material.dart';

/// Linha padronizada de metadado (ícone + rótulo + valor) usada nos cards e detalhes de veículo.
class InfoCampoVeiculo extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;
  final double tamanhoIcone;
  final double tamanhoRotulo;
  final double tamanhoValor;
  final FontWeight pesoValor;

  const InfoCampoVeiculo({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.valor,
    this.tamanhoIcone = 22,
    this.tamanhoRotulo = 13,
    this.tamanhoValor = 16.5,
    this.pesoValor = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: tamanhoIcone, color: const Color(0xFF475569)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rotulo,
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontSize: tamanhoRotulo,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: TextStyle(
                  fontSize: tamanhoValor,
                  fontWeight: pesoValor,
                  color: const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CardVeiculo extends StatelessWidget {
  final Map<String, dynamic> veiculo;
  final VoidCallback? onEditar;
  final VoidCallback? onDetalhes;
  final ValueChanged<String>? onStatusChanged;
  final bool exibirAcoesRodape;

  const CardVeiculo({
    super.key,
    required this.veiculo,
    this.onEditar,
    this.onDetalhes,
    this.onStatusChanged,
    this.exibirAcoesRodape = true,
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
            LayoutBuilder(
              builder: (context, constraints) {
                final escala = MediaQuery.textScalerOf(context).scale(13);
                final empilhar = constraints.maxWidth < 270 || escala > 18;

                final identificacao = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placa,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descricaoVeiculo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(iconeTipo, size: 20, color: const Color(0xFF475569)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            labelTipo,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final statusBadgeRaw = Container(
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
                          final Color corOp = op['cor'] as Color;
                          final String labelOp = op['label'] as String;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 9,
                                color: Color.lerp(
                                  corOp,
                                  Colors.black,
                                  0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                labelOp,
                                style: TextStyle(
                                  color: Color.lerp(
                                    corOp,
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
                              Flexible(
                                child: Text(
                                  op['label'] as String,
                                  style: TextStyle(
                                    color: Color.lerp(cor, Colors.black, 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                );

                final statusBadge = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: empilhar
                        ? constraints.maxWidth
                        : constraints.maxWidth * 0.48,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: empilhar
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: statusBadgeRaw,
                  ),
                );

                if (empilhar) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identificacao,
                      const SizedBox(height: 10),
                      statusBadge,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IDENTIFICAÇÃO
                    Expanded(child: identificacao),
                    const SizedBox(width: 8),

                    // STATUS INDICATOR COM ÁREA INTEIRA CLICÁVEL
                    statusBadge,
                  ],
                );
              },
            ),

            // INFORMAÇÕES OPERACIONAIS RESUMIDAS (KM E ASSENTOS EM DESTAQUE)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final escala = MediaQuery.textScalerOf(context).scale(15);
                  final empilhar = constraints.maxWidth < 245 || escala > 22;

                  final campoKm = InfoCampoVeiculo(
                    icone: Icons.speed_outlined,
                    rotulo: 'Quilometragem Atual',
                    valor: '$km km',
                  );
                  final campoAssentos = InfoCampoVeiculo(
                    icone: Icons.chair_outlined,
                    rotulo: 'Qtd. de Assentos',
                    valor: '$assentos',
                  );

                  if (empilhar) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        campoKm,
                        const SizedBox(height: 10),
                        campoAssentos,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: campoKm),
                      const SizedBox(width: 12),
                      Expanded(child: campoAssentos),
                    ],
                  );
                },
              ),
            ),

            if (exibirAcoesRodape) ...[
              const Divider(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _construirBotaoRodape(
                    icone: Icons.edit_outlined,
                    rotulo: 'Editar',
                    onPressed: onEditar,
                  ),
                  const SizedBox(width: 12),
                  _construirBotaoRodape(
                    icone: Icons.arrow_forward_outlined,
                    rotulo: 'Ver Detalhes',
                    onPressed: onDetalhes,
                    iconeDepois: true,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _construirBotaoRodape({
    required IconData icone,
    required String rotulo,
    required VoidCallback? onPressed,
    bool iconeDepois = false,
  }) {
    const corTexto = Color(0xFF475569);
    final iconeWidget = Icon(icone, size: 20, color: corTexto);
    final textoWidget = Flexible(
      child: Text(
        rotulo,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: corTexto,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment:
              iconeDepois ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: iconeDepois
              ? [textoWidget, const SizedBox(width: 8), iconeWidget]
              : [iconeWidget, const SizedBox(width: 8), textoWidget],
        ),
      ),
    );
  }
}
