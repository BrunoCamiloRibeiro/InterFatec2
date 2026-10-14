import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';

class TimelinePassageiro extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool isPast;

  const TimelinePassageiro({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Espaço entre os eventos
      height: 70,
      child: TimelineTile(
        // Recebendo os parâmetros
        isFirst: isFirst,
        isLast: isLast,
        // Linhas
        beforeLineStyle: LineStyle(color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[300]!),
        // Icones
        indicatorStyle: IndicatorStyle(
          width: 30,
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[300]!,
          iconStyle: IconStyle(iconData: Icons.done, color: Colors.white),
        ),
      ),
    );
  }
}
