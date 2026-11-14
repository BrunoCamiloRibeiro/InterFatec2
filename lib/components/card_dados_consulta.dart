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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hoje',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
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
            const SizedBox(height: 16),
            _ItemLinhaConsulta(
              icone: Icons.access_time_outlined,
              label: 'Horário Previsto',
              valor: horarioConsulta,
            ),
            const SizedBox(height: 16),
            _ItemLinhaConsulta(
              icone: Icons.location_on_outlined,
              label: 'Local de Saída / Embarque',
              valor: (localSaida.isNotEmpty && enderecoPaciente.isNotEmpty)
                  ? '$localSaida ($enderecoPaciente)'
                  : (localSaida.isNotEmpty ? localSaida : enderecoPaciente),
            ),
            if (nomeAcompanhante != null && nomeAcompanhante!.isNotEmpty) ...[
              const SizedBox(height: 16),
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

  const _ItemLinhaConsulta({
    required this.icone,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 23, color: const Color(0xFF1D4ED8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                valor.isNotEmpty ? valor : 'Não informado',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
