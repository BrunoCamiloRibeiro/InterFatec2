import 'package:flutter/material.dart';

/// Componente visual do cabeçalho da tela do motorista (Issue #13).
///
/// Exibe um seletor horizontal em card com navegação entre viagens (setas anterior/próxima)
/// e o rótulo da viagem centralizado. Permite opcionalmente exibir uma linha secundária
/// compacta com detalhes da viagem caso sejam informados.
class MotoristaHeader extends StatelessWidget {
  /// Rótulo ou título da viagem atual já formatado (ex: "Viagem #1", "Viagem 001").
  final String tituloViagem;

  /// Callback acionado ao tocar na seta de viagem anterior.
  /// Se nulo, a seta permanece visualmente desabilitada.
  final VoidCallback? onAnterior;

  /// Callback acionado ao tocar na seta de próxima viagem.
  /// Se nulo, a seta permanece visualmente desabilitada.
  final VoidCallback? onProxima;

  // Campos opcionais descritos na Issue #13:
  final String? motoristaNome;
  final String? destino;
  final String? veiculo;
  final String? saida;

  const MotoristaHeader({
    super.key,
    required this.tituloViagem,
    this.onAnterior,
    this.onProxima,
    this.motoristaNome,
    this.destino,
    this.veiculo,
    this.saida,
  });

  /// Verifica se ao menos um dos campos secundários opcionais foi fornecido e não está vazio.
  bool get _possuiDadosSecundarios {
    return (motoristaNome?.trim().isNotEmpty == true) ||
        (destino?.trim().isNotEmpty == true) ||
        (veiculo?.trim().isNotEmpty == true) ||
        (saida?.trim().isNotEmpty == true);
  }

  @override
  Widget build(BuildContext context) {
    final bool anteriorHabilitado = onAnterior != null;
    final bool proximaHabilitado = onProxima != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: anteriorHabilitado
                      ? Colors.blueGrey[900]
                      : Colors.grey[400],
                ),
                tooltip: 'Viagem anterior',
                onPressed: onAnterior,
              ),
              Expanded(
                child: Text(
                  tituloViagem,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: proximaHabilitado
                      ? Colors.blueGrey[900]
                      : Colors.grey[400],
                ),
                tooltip: 'Próxima viagem',
                onPressed: onProxima,
              ),
            ],
          ),
          // Linha secundária compacta renderizada SOMENTE se algum campo opcional for informado
          if (_possuiDadosSecundarios) ...[
            const Divider(height: 4, thickness: 0.8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (motoristaNome?.trim().isNotEmpty == true)
                    _ItemDadoSecundario(
                      icone: Icons.person_outline,
                      valor: motoristaNome!.trim(),
                    ),
                  if (destino?.trim().isNotEmpty == true)
                    _ItemDadoSecundario(
                      icone: Icons.location_on_outlined,
                      valor: destino!.trim(),
                    ),
                  if (veiculo?.trim().isNotEmpty == true)
                    _ItemDadoSecundario(
                      icone: Icons.directions_bus_outlined,
                      valor: veiculo!.trim(),
                    ),
                  if (saida?.trim().isNotEmpty == true)
                    _ItemDadoSecundario(
                      icone: Icons.access_time_outlined,
                      valor: saida!.trim(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Item visual compacto para informações secundárias com ícone e texto
class _ItemDadoSecundario extends StatelessWidget {
  final IconData icone;
  final String valor;

  const _ItemDadoSecundario({required this.icone, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
