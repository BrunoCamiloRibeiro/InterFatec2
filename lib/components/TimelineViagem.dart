import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';

class TimelineViagem extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool isPast;
  final String horario;
  final String local;
  final IconData? icone;

  const TimelineViagem({
    super.key,
    this.isFirst = false,
    this.isLast = false,
    required this.isPast,
    required this.horario,
    required this.local,
    this.icone,
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
        beforeLineStyle: LineStyle(
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[300]!,
        ),
        // Icones
        indicatorStyle: IndicatorStyle(
          width: 30,
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[300]!,
          iconStyle: IconStyle(
            iconData: isPast ? Icons.done : (icone ?? Icons.timer_outlined),
            color: Colors.white,
          ),
        ),
        // alignment: TimelineAlign.manual,
        // lineXY: 0.17,
        // startChild: Text('00:00'),
        endChild: Card(
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[100]!,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(25),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  horario,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isPast ? FontWeight.bold : FontWeight.normal,
                    color: isPast ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  local,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isPast ? FontWeight.bold : FontWeight.normal,
                    color: isPast ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
