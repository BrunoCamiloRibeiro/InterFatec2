import 'package:flutter/material.dart';

/// Card que exibe os detalhes do agendamento médico e da logística de embarque.
class CardDadosConsulta extends StatelessWidget {
  final String localConsulta;
  final String horarioConsulta;
  final String localSaida;
  final String enderecoPaciente;
  final String? nomeAcompanhante;

  const CardDadosConsulta({
    super.key,
    required this.localConsulta,
    required this.horarioConsulta,
    required this.localSaida,
    required this.enderecoPaciente,
    this.nomeAcompanhante,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.5, vertical: 18.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'DADOS DO AGENDAMENTO',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Hoje',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            _ItemLinhaConsulta(
              icone: Icons.local_hospital_outlined,
              label: 'Local da Consulta',
              valor: localConsulta,
            ),
            const SizedBox(height: 14),
            _ItemLinhaConsulta(
              icone: Icons.access_time_outlined,
              label: 'Horário Previsto',
              valor: horarioConsulta,
              detalheExtra: '(Chegar com antecedência)',
            ),
            const SizedBox(height: 14),
            _ItemLinhaConsulta(
              icone: Icons.location_on_outlined,
              label: 'Local de Saída / Embarque',
              valor: localSaida.isNotEmpty
                  ? '$localSaida ($enderecoPaciente)'
                  : enderecoPaciente,
            ),
            if (nomeAcompanhante != null && nomeAcompanhante!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ItemLinhaConsulta(
                icone: Icons.people_outline,
                label: 'Acompanhante',
                valor: '$nomeAcompanhante',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemLinhaConsulta extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valor;
  final String? detalheExtra;

  const _ItemLinhaConsulta({
    required this.icone,
    required this.label,
    required this.valor,
    this.detalheExtra,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 21, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    valor.isNotEmpty ? valor : 'Não informado',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (detalheExtra != null)
                    Text(
                      detalheExtra!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
