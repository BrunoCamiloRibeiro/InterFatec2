import 'package:flutter/material.dart';

import '../models/paciente_model.dart';
import 'abreviar_textos.dart';

// Componente que exibe os dados de identificação e status do paciente logado
// Também reutilizado na Gestão de Pessoas com callbacks opcionais de edição e inativação
class CardIdentificacaoPaciente extends StatelessWidget {
  final String nome;
  final String cpf;
  final int status;
  final String? labelBadge;
  final Color? corBadge;
  final String? telefone;
  final String? detalheExtra;
  final VoidCallback? onEditar;
  final VoidCallback? onInativar;
  final VoidCallback? onTap;

  const CardIdentificacaoPaciente({
    super.key,
    required this.nome,
    required this.cpf,
    this.status = 0,
    this.labelBadge,
    this.corBadge,
    this.telefone,
    this.detalheExtra,
    this.onEditar,
    this.onInativar,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Reaproveita a definição centralizada de status do PacienteModel quando label customizada não é passada
    final (textoPadrao, corPadrao, _) = PacienteModel.dadosStatus(status);
    final badgeTexto = labelBadge ?? textoPadrao;
    final badgeCor = corBadge ?? corPadrao;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          // Padding interno aumentado em ~10% (18.0) para melhor respiro visual
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho do Card: Label de identificação e Badge de Status / Categoria
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    labelBadge != null
                        ? 'CADASTRO DE PESSOA'
                        : 'IDENTIFICAÇÃO DO PACIENTE',
                    style: const TextStyle(
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
                      color: badgeCor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: badgeCor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      badgeTexto,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeCor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Perfil: Avatar com iniciais, Nome abreviado e CPF
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

              // Linhas adicionais informativas (Telefone e Detalhes de Consulta/Veículo)
              if (telefone != null && telefone!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      telefone!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ],
              if (detalheExtra != null && detalheExtra!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        detalheExtra!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Barra de ações administrativas (Editar e Inativar) quando fornecidas
              if (onEditar != null || onInativar != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onEditar != null)
                      TextButton.icon(
                        onPressed: onEditar,
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        label: const Text(
                          'Editar',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (onInativar != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onInativar,
                        icon: const Icon(
                          Icons.person_off_outlined,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        label: const Text(
                          'Inativar',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
