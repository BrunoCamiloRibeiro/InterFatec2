// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/dialogo_confirmacao_motorista.dart
// Camada: Apresentação / Diálogos e Interação Mobile (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa o modal ergonômico de confirmação de avanço de status do motorista.
// Substitui o padrão rígido do AlertDialog por um layout otimizado para operação
// com suporte veicular em vias irregulares: botões empilhados full-width com
// altura mínima de 54dp-56dp, tipografia escaneável em 1 segundo e feedback tátil.
//
// PARA QUE SERVE NO PROJETO:
// Garante confirmação rápida, inequívoca e segura pelo condutor do veículo,
// eliminando swipes acidentais e falsos toques durante a condução.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Exibe o diálogo modal ergonômico de confirmação de avanço para o motorista.
///
/// Retorna `true` se o motorista tocou em "Confirmar", ou `false` se cancelou/fechou fora.
Future<bool> exibirDialogoConfirmacaoMotorista({
  required BuildContext context,
  required String nomePaciente,
  required String proximoStatusNome,
  required Color proximoStatusCor,
  required IconData proximoStatusIcone,
  String? localDestino,
}) async {
  // Feedback tátil imediato ao abrir o modal após o limiar do gesto
  HapticFeedback.mediumImpact();

  final resultado = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Tag / Badge superior com ícone e cor da próxima etapa
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: proximoStatusCor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(proximoStatusIcone, size: 16, color: proximoStatusCor),
                        const SizedBox(width: 6),
                        Text(
                          'PRÓXIMA ETAPA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: proximoStatusCor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Título: Nome do Passageiro (escaneável em 1 segundo)
              Text(
                nomePaciente,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),

              // 3. Subtítulo / Destino em destaque com a cor semântica do status
              Text(
                proximoStatusNome,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: proximoStatusCor,
                ),
              ),

              if (localDestino != null && localDestino.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        localDestino,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // 4. Botão Primário de Confirmação: Full-Width, Altura 56dp, Destaque total
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  key: const Key('botao_confirmar_dialogo_motorista'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(dialogContext).pop(true);
                  },
                  icon: const Icon(Icons.check_circle, size: 22),
                  label: const Text(
                    'Confirmar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 5. Botão Secundário Cancelar: Largo, Altura 52dp, separado por gap seguro de 12dp
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  key: const Key('botao_cancelar_dialogo_motorista'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  return resultado ?? false;
}
