import 'package:flutter/material.dart';

import '../models/paciente_model.dart';
import 'abreviar_textos.dart';

// Componente que exibe os dados de identificação e status do paciente logado
class CardIdentificacaoPaciente extends StatelessWidget {
  final String nome;
  final String cpf;
  final int status;

  const CardIdentificacaoPaciente({
    super.key,
    required this.nome,
    required this.cpf,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Reaproveita a definição centralizada de status do PacienteModel
    final (textoStatus, corStatus, _) = PacienteModel.dadosStatus(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        // Padding interno aumentado em ~10% (18.0) para melhor respiro visual
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do Card: Label de identificação e Badge de Status (~10% maior)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'IDENTIFICAÇÃO DO PACIENTE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: corStatus.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    textoStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: corStatus,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Perfil: Avatar com iniciais, Nome abreviado e CPF (~10% maiores)
            Row(
              children: [
                CircleAvatar(
                  radius: 26.5,
                  backgroundColor: const Color(0xFF0F172A),
                  child: Text(
                    nome.isNotEmpty ? nome[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TextAbbreviator.abbreviate(nome, maxCharacters: 28),
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'CPF: $cpf',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
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
