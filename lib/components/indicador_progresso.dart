
import 'package:flutter/material.dart';

class IndicadorProgresso extends StatelessWidget {
  final int valorAtual;
  final int valorMaximo;
  final Color corAtiva;
  final Color corInativa;

  const IndicadorProgresso({
    super.key,
    required this.valorAtual,
    this.valorMaximo = 1,
    required this.corAtiva,
    required this.corInativa,
  });

  @override
  Widget build(BuildContext context) {
    final int progresso = valorAtual.clamp(0, valorMaximo);

    return Row(
      children: List.generate(valorMaximo, (index) {
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(
              right: index < valorMaximo - 1 ? 5 : 0,
            ),
            decoration: BoxDecoration(
              color: index < progresso
                  ? corAtiva
                  : corInativa,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }
}
