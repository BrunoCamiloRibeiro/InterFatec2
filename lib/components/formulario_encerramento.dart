import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../models/paciente_model.dart';
import '../models/viagem_model.dart';
import '../services/relatorio_pdf_service.dart';

// Componente visual em formato de POPUP (AlertDialog) para o Formulário de Encerramento (Issue #15 / US03).
// Contém os 3 campos solicitados: Retorno, Km Retorno e Km Rodado, além da emissão do PDF oficial TFD.
class FormularioEncerramento extends StatefulWidget {
  final ViagemModel? viagem;
  final List<PacienteModel>? pacientes;
  final void Function(String retorno, String kmRetorno, String kmRodado)?
  onConfirmar;

  const FormularioEncerramento({
    super.key,
    this.viagem,
    this.pacientes,
    this.onConfirmar,
  });

  @override
  State<FormularioEncerramento> createState() => _FormularioEncerramentoState();
}

class _FormularioEncerramentoState extends State<FormularioEncerramento> {
  final TextEditingController _retornoController = TextEditingController();
  final TextEditingController _kmRetornoController = TextEditingController();
  final TextEditingController _kmRodadoController = TextEditingController();

  @override
  void dispose() {
    _retornoController.dispose();
    _kmRetornoController.dispose();
    _kmRodadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Popup modal (AlertDialog) exibido sobre a tela da Lista de Passageiros
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Título do Popup com ícone e texto de encerramento
      title: Row(
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            color: Colors.blueGrey[900],
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Formulário de Encerramento',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              ),
            ),
          ),
        ],
      ),
      // Conteúdo rolável do Popup contendo os 3 campos obrigatórios da Issue #15
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CAMPO 1: Retorno (com máscara de horário HH:mm)
              const Text(
                'Retorno',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _retornoController,
                keyboardType: TextInputType.number,
                // Aplica filtro de apenas números e a máscara automática no formato HH:mm
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _MascaraHorarioFormatter(),
                ],
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.access_time_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  ),
                  hintText: '00:00',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // CAMPO 2: Km Retorno
              const Text(
                'Km Retorno',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _kmRetornoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.speed_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  ),
                  suffixText: 'km',
                  hintText: 'Ex: 85650',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // CAMPO 3: Km Rodado
              const Text(
                'Km Rodado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _kmRodadoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.add_road_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  ),
                  suffixText: 'km',
                  hintText: 'Ex: 230',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Botões de ação do Popup (Cancelar e Confirmar)
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            final retorno = _retornoController.text.trim();
            final kmRetorno = _kmRetornoController.text.trim();
            final kmRodado = _kmRodadoController.text.trim();

            widget.onConfirmar?.call(retorno, kmRetorno, kmRodado);

            // Se houver dados de viagem e pacientes disponíveis, aciona a visualização/impressão do PDF
            if (widget.viagem != null && widget.pacientes != null) {
              final v = widget.viagem!;
              final kmRetornoNum = int.tryParse(kmRetorno);
              final kmRodadoNum = int.tryParse(kmRodado);

              await Printing.layoutPdf(
                name: 'Roteiro_Viagem_${v.veiculoPlaca}.pdf',
                onLayout: (format) async {
                  return RelatorioPdfService.gerarRoteiroViagemPdf(
                    viagem: v,
                    pacientes: widget.pacientes!,
                    retornoInformado: retorno.isNotEmpty ? retorno : null,
                    kmRetornoInformado: kmRetornoNum,
                    kmRodadoInformado: kmRodadoNum,
                  );
                },
              );
            }

            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// Formatador simples para aplicar a máscara de horário (HH:mm) enquanto o usuário digita
class _MascaraHorarioFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Limita a no máximo 4 dígitos numéricos (2 para hora e 2 para minuto)
    String digitos = newValue.text;
    if (digitos.length > 4) {
      digitos = digitos.substring(0, 4);
    }

    // Insere os dois-pontos ":" automaticamente após os 2 primeiros dígitos
    String formatado = '';
    for (int i = 0; i < digitos.length; i++) {
      if (i == 2) {
        formatado += ':';
      }
      formatado += digitos[i];
    }

    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}
