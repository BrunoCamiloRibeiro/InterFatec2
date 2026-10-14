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
    return TimelineTile(
      // Recebendo os parâmetros
      isFirst: isFirst,
      isLast: isLast,
      // Linhas
      beforeLineStyle: LineStyle(color: Colors.blue),
      // Icones
      indicatorStyle: IndicatorStyle(
        width: 30,
        color: Colors.blueAccent,
        iconStyle: IconStyle(iconData: Icons.done, color: Colors.white),
      ),
    );
  }
}
