import 'package:flutter/material.dart';

import '../models/paciente_model.dart';
import '../models/viagem_model.dart';
import '../services/viagem_service.dart';
import 'formulario_encerramento.dart';

/// Rodapé da tela do motorista exibindo lotação do veículo e o botão
/// "Gerar Relatório" que abre o formulário de encerramento.
class FooterPacientes extends StatelessWidget {
  final int lugaresPreenchidos;
  final int lugaresTotais;
  final ViagemModel? viagem;
  final List<ViagemModel>? viagens;
  final List<PacienteModel>? pacientes;
  final VoidCallback? onViagemEncerrada;

  const FooterPacientes({
    super.key,
    required this.lugaresPreenchidos,
    required this.lugaresTotais,
    this.viagem,
    this.viagens,
    this.pacientes,
    this.onViagemEncerrada,
  });

  @override
  Widget build(BuildContext context) {
    final disponiveis =
        (lugaresTotais - lugaresPreenchidos).clamp(0, lugaresTotais);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final escalaTexto = MediaQuery.textScalerOf(context).scale(13);
              final empilhar = constraints.maxWidth < 310 ||
                  (constraints.maxWidth < 380 && escalaTexto > 17);

              final contadorLugares = Row(
                mainAxisSize: empilhar ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Icon(
                    Icons.event_seat_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lugares: $lugaresPreenchidos / $lugaresTotais',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          Text(
                            'Disponíveis: $disponiveis',
                            key: const Key('textoLugaresDisponiveisFooter'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: (lugaresTotais - lugaresPreenchidos) > 0
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFE11D48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

              final botaoRelatorio = ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                onPressed: () => _confirmarEAbrirEncerramento(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_outlined, size: 18),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Gerar Relatório',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (empilhar) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    contadorLugares,
                    const SizedBox(height: 8),
                    botaoRelatorio,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: contadorLugares),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.55,
                    ),
                    child: botaoRelatorio,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarEAbrirEncerramento(BuildContext context) async {
    final bool? querFinalizar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          key: const Key('dialogConfirmarFinalizacaoViagem'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.help_outline,
                color: Colors.blueGrey[900],
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Finalizar Viagem',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Você tem certeza que quer finalizar a viagem?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              key: const Key('botaoCancelarFinalizacao'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              key: const Key('botaoConfirmarFinalizacao'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[900],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Sim, finalizar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (querFinalizar != true || !context.mounted) return;

    final viagensParaEncerrar = (viagens != null && viagens!.isNotEmpty)
        ? viagens!
        : (ViagemService().viagensAtivas.isNotEmpty
            ? ViagemService().viagensAtivas
            : (viagem != null ? <ViagemModel>[viagem!] : const <ViagemModel>[]));

    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return FormularioEncerramento(
          viagem: viagem,
          viagens: viagensParaEncerrar,
          pacientes: pacientes,
          onViagemEncerrada: onViagemEncerrada,
        );
      },
    );
  }
}
