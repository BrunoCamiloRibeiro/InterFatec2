import 'package:flutter/material.dart';

class CardAcompanhante extends StatelessWidget {
  final String nomeAcompanhante;
  final String telAcompanhante;

  const CardAcompanhante({
    super.key,
    required this.nomeAcompanhante,
    required this.telAcompanhante,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Slate 50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0), // Slate 200
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título com ícone lado a lado
          const Row(
            children: [
              Icon(
                Icons.group_add_outlined,
                size: 17,
                color: Colors.blueAccent,
              ),
              SizedBox(width: 6),
              Text(
                'ACOMPANHANTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Nome do acompanhante
          Row(
            children: [
              const Icon(Icons.person_outline, size: 20, color: Colors.black54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nomeAcompanhante,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Telefone do acompanhante (renderizado apenas se existir)
          if (telAcompanhante.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    telAcompanhante,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
