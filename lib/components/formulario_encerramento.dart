import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../models/paciente_model.dart';
import '../models/viagem_model.dart';
import '../services/relatorio_pdf_service.dart';
import '../services/viagem_service.dart';

/// Compila o relatório PDF TFD em isolate separado para não bloquear a UI.
Future<Uint8List> _compilarPdfEmIsolate(Map<String, dynamic> payload) async {
  final viagemMap = Map<String, dynamic>.from(payload['viagem'] as Map);
  final viagem = ViagemModel.fromMap(
    viagemMap,
    docId: (viagemMap['id'] ?? '').toString(),
  );
  final pacientesRaw = (payload['pacientes'] as List<dynamic>? ?? const []);
  final pacientes = pacientesRaw.map((item) {
    final map = Map<String, dynamic>.from(item as Map);
    return PacienteModel.fromMap(
      map,
      docId: (map['id'] ?? '').toString(),
    );
  }).toList();

  final rawMap = payload['viagemIdPorPaciente'] as Map?;
  final viagemIdPorPaciente = rawMap?.map(
    (k, v) => MapEntry(k.toString(), v.toString()),
  );

  return RelatorioPdfService.gerarRoteiroViagemPdf(
    viagem: viagem,
    pacientes: pacientes,
    retornoInformado: payload['retornoInformado'] as String?,
    kmRetornoInformado: payload['kmRetornoInformado'] as int?,
    kmRodadoInformado: payload['kmRodadoInformado'] as int?,
    viagemIdPorPaciente: viagemIdPorPaciente,
  );
}

/// Diálogo modal para encerramento da jornada do motorista e emissão do PDF TFD.
class FormularioEncerramento extends StatefulWidget {
  final ViagemModel? viagem;
  final List<ViagemModel>? viagens;
  final List<PacienteModel>? pacientes;
  final String? motoristaId;
  final String? motoristaNome;
  final void Function(String retorno, String kmRetorno, String kmRodado)?
      onConfirmar;
  final VoidCallback? onViagemEncerrada;

  const FormularioEncerramento({
    super.key,
    this.viagem,
    this.viagens,
    this.pacientes,
    this.motoristaId,
    this.motoristaNome,
    this.onConfirmar,
    this.onViagemEncerrada,
  });

  @override
  State<FormularioEncerramento> createState() => _FormularioEncerramentoState();
}

class _FormularioEncerramentoState extends State<FormularioEncerramento> {
  final TextEditingController _retornoController = TextEditingController();
  final TextEditingController _kmRetornoController = TextEditingController();
  final TextEditingController _kmRodadoController = TextEditingController();
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _kmRetornoController.addListener(_aoMudarKmRetorno);
  }

  int get _kmInicialBase {
    final sessaoAtiva = ViagemService().sessaoAtiva;
    final motFiltro = widget.motoristaId?.trim() ?? '';
    final sessaoPertenceAoMotorista = sessaoAtiva != null &&
        (motFiltro.isEmpty ||
            sessaoAtiva.motoristaId.trim().isEmpty ||
            sessaoAtiva.motoristaId.trim() == motFiltro);
    if (sessaoPertenceAoMotorista && sessaoAtiva.kmInicial > 0) {
      return sessaoAtiva.kmInicial;
    }
    return widget.viagem?.kmInicial ??
        widget.viagens?.firstOrNull?.kmInicial ??
        ViagemService().viagemAtiva?.kmInicial ??
        0;
  }

  void _aoMudarKmRetorno() {
    final kmRet = int.tryParse(_kmRetornoController.text.trim());
    if (kmRet != null && kmRet >= _kmInicialBase) {
      final diff = kmRet - _kmInicialBase;
      if (_kmRodadoController.text != diff.toString()) {
        _kmRodadoController.text = diff.toString();
      }
    }
  }

  @override
  void dispose() {
    _kmRetornoController.removeListener(_aoMudarKmRetorno);
    _retornoController.dispose();
    _kmRetornoController.dispose();
    _kmRodadoController.dispose();
    super.dispose();
  }

  Widget _construirCampo({
    required String rotulo,
    required TextEditingController controller,
    required List<TextInputFormatter> formatters,
    required IconData icone,
    required String hint,
    String? sufixo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: formatters,
          decoration: InputDecoration(
            prefixIcon: Icon(icone, size: 20, color: Colors.blueGrey[900]),
            suffixText: sufixo,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmarEncerramento() {
    setState(() => _processando = true);

    final retorno = _retornoController.text.trim();
    final kmRetorno = _kmRetornoController.text.trim();
    var kmRodado = _kmRodadoController.text.trim();

    final kmRetornoNum = int.tryParse(kmRetorno);
    final kmIni = _kmInicialBase;

    if (kmRetornoNum != null && kmRetornoNum < kmIni) {
      setState(() => _processando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Km de retorno ($kmRetornoNum km) não pode ser menor que o Km inicial ($kmIni km).',
          ),
        ),
      );
      return;
    }

    int? kmRodadoNum = int.tryParse(kmRodado);
    if (kmRetornoNum != null && kmRetornoNum >= kmIni) {
      final diff = kmRetornoNum - kmIni;
      kmRodadoNum ??= diff;
      if (kmRodado.isEmpty) {
        kmRodado = diff.toString();
      }
    }

    widget.onConfirmar?.call(retorno, kmRetorno, kmRodado);

    final listaViagensAlvo = widget.viagem != null
        ? <ViagemModel>[widget.viagem!]
        : ((widget.viagens != null && widget.viagens!.isNotEmpty)
            ? <ViagemModel>[widget.viagens!.first]
            : null);

    final listaParaRelatorio = ViagemService().obterViagensParaRelatorio(
      viagensExplicitas: listaViagensAlvo,
      viagemUnica: widget.viagem,
    );

    final pacientesSnapshot = widget.pacientes != null
        ? List<PacienteModel>.from(widget.pacientes!)
        : null;

    final viagensSnapshot = listaParaRelatorio.map((v) {
      final passageirosSinc = v.passageiros.map((p) {
        final st = ViagemService().resolverStatusEfetivoPassageiro(
          p,
          viagemId: v.id,
          pacientesContexto: pacientesSnapshot,
        );
        return p.copyWith(statusEmbarque: st);
      }).toList();
      final concluiu = v.isConcluida ||
          ViagemService().todosPacientesVoltaram(
            v.copyWith(passageiros: passageirosSinc),
            pacientesContexto: pacientesSnapshot,
          );
      return v.copyWith(
        status: concluiu ? 'encerrada' : 'ativa',
        codigosAcesso: concluiu
            ? const <String, String>{}
            : Map<String, String>.from(v.codigosAcesso),
        passageiros: passageirosSinc,
      );
    }).toList();

    final todasViagensConcluidas = viagensSnapshot.isNotEmpty &&
        viagensSnapshot.every((v) => v.isConcluida);

    // Atualiza estado e sessão do motorista imediatamente antes da geração do PDF (Zero-Wait UI).
    unawaited(
      ViagemService().encerrarTodasViagens(
        kmFinal: kmRetornoNum,
        kmRodado: kmRodadoNum,
        viagensExplicitas: viagensSnapshot,
        pacientes: pacientesSnapshot,
        motoristaId: widget.motoristaId,
        encerrarViagensDefinitivamente: false,
        finalizarSessaoMotorista: true,
      ),
    );

    final messenger = ScaffoldMessenger.maybeOf(context);
    final viagemFallback = widget.viagem ?? ViagemService().viagemAtiva;

    widget.onViagemEncerrada?.call();

    if (context.mounted) {
      Navigator.of(context).pop(true);
    }

    messenger?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              todasViagensConcluidas
                  ? 'Viagem encerrada. Preparando relatório PDF em segundo plano...'
                  : 'Sessão encerrada (pendências mantidas). Preparando relatório PDF em segundo plano...',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ],
        ),
      ),
    );

    unawaited(
      _gerarEExibirPdfEmSegundoPlano(
        viagensSnapshot: viagensSnapshot,
        viagemFallback: viagemFallback,
        pacientesSnapshot: pacientesSnapshot,
        retorno: retorno,
        kmRetornoNum: kmRetornoNum,
        kmRodadoNum: kmRodadoNum,
      ),
    );
  }

  Future<void> _gerarEExibirPdfEmSegundoPlano({
    required List<ViagemModel> viagensSnapshot,
    required ViagemModel? viagemFallback,
    required List<PacienteModel>? pacientesSnapshot,
    required String retorno,
    required int? kmRetornoNum,
    required int? kmRodadoNum,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final viagemFocoAtual =
        viagensSnapshot.isNotEmpty ? viagensSnapshot.first : viagemFallback;

    List<ViagemModel> viagensParaPdf = viagensSnapshot;
    try {
      final todasDoDia =
          await ViagemService().obterTodasViagensDoDiaParaRelatorio(
        viagemEncerradaAtual: viagemFocoAtual,
      );
      if (todasDoDia.isNotEmpty) {
        viagensParaPdf = todasDoDia;
      }
    } catch (_) {}

    final vBase = viagemFocoAtual ??
        (viagensParaPdf.isNotEmpty
            ? viagensParaPdf.first
            : ViagemModel(
                id: 'relatorio_${DateTime.now().millisecondsSinceEpoch}',
                motoristaId: '',
                motoristaNome: '',
                veiculoId: '',
                veiculoPlaca: '',
                veiculoModelo: '',
                kmInicial: 0,
                cidadeDestino: 'TFD',
                dataHoraInicio: DateTime.now(),
                status: 'encerrada',
              ));

    final mapaPacientesConsolidados = <String, PacienteModel>{};
    final mapaViagemIdPorPaciente = <String, String>{};
    final codigosConsolidados = <String, String>{...vBase.codigosAcesso};
    final idsPassageirosConsolidados = <String>[];
    final destinos = <String>[];

    if (viagensParaPdf.isNotEmpty) {
      for (final v in viagensParaPdf) {
        if (v.cidadeDestino.trim().isNotEmpty &&
            !destinos.contains(v.cidadeDestino.trim())) {
          destinos.add(v.cidadeDestino.trim());
        }
        codigosConsolidados.addAll(v.codigosAcesso);
        final pacsDaViagem = ViagemService().obterPacientesParaViagemRelatorio(
          v,
          pacientesInformados: v.id == vBase.id ? pacientesSnapshot : null,
        );
        for (final p in pacsDaViagem) {
          mapaPacientesConsolidados[p.id] = p;
          mapaViagemIdPorPaciente[p.id] = v.id;
          if (!idsPassageirosConsolidados.contains(p.id)) {
            idsPassageirosConsolidados.add(p.id);
          }
        }
      }
    } else if (pacientesSnapshot != null) {
      for (final p in pacientesSnapshot) {
        mapaPacientesConsolidados[p.id] = p;
        if (vBase.id.isNotEmpty) {
          mapaViagemIdPorPaciente[p.id] = vBase.id;
        }
        if (!idsPassageirosConsolidados.contains(p.id)) {
          idsPassageirosConsolidados.add(p.id);
        }
      }
    }

    final motNomePdf = (vBase.motoristaNome.trim().isNotEmpty &&
            vBase.motoristaNome.trim() != 'motorista_atual')
        ? vBase.motoristaNome.trim()
        : ((widget.motoristaNome?.trim().isNotEmpty == true &&
                widget.motoristaNome!.trim() != 'motorista_atual')
            ? widget.motoristaNome!.trim()
            : '');

    final viagemParaPdf = vBase.copyWith(
      motoristaNome: motNomePdf,
      cidadeDestino:
          destinos.isNotEmpty ? destinos.join(' / ') : vBase.cidadeDestino,
      passageirosIds: idsPassageirosConsolidados,
      codigosAcesso: codigosConsolidados,
    );
    final listaPacientesPdf = mapaPacientesConsolidados.values.toList();

    final placaLimpa = viagemParaPdf.veiculoPlaca.trim().isNotEmpty
        ? viagemParaPdf.veiculoPlaca.trim()
        : 'TFD';
    final nomeArquivoPdf = 'Roteiro_Viagem_$placaLimpa.pdf';

    Uint8List? pdfBytes;
    try {
      final emAmbienteDeTeste = WidgetsBinding.instance.runtimeType
          .toString()
          .contains('TestWidgetsFlutterBinding');
      if (!emAmbienteDeTeste) {
        final payload = <String, dynamic>{
          'viagem': {...viagemParaPdf.toMap(), 'id': viagemParaPdf.id},
          'pacientes':
              listaPacientesPdf.map((p) => {...p.toMap(), 'id': p.id}).toList(),
          'retornoInformado': retorno.isNotEmpty ? retorno : null,
          'kmRetornoInformado': kmRetornoNum,
          'kmRodadoInformado': kmRodadoNum,
          'viagemIdPorPaciente': mapaViagemIdPorPaciente,
        };
        pdfBytes = await compute(_compilarPdfEmIsolate, payload);
      } else {
        pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
          viagem: viagemParaPdf,
          pacientes: listaPacientesPdf,
          retornoInformado: retorno.isNotEmpty ? retorno : null,
          kmRetornoInformado: kmRetornoNum,
          kmRodadoInformado: kmRodadoNum,
          viagemIdPorPaciente: mapaViagemIdPorPaciente,
        );
      }
    } catch (_) {}

    if (pdfBytes != null &&
        pdfBytes.isNotEmpty &&
        WidgetsBinding.instance is WidgetsFlutterBinding) {
      try {
        final bytes = pdfBytes;
        await Printing.layoutPdf(
          name: nomeArquivoPdf,
          onLayout: (format) async => bytes,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _construirCampo(
                rotulo: 'Retorno',
                controller: _retornoController,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _MascaraHorarioFormatter(),
                ],
                icone: Icons.access_time_outlined,
                hint: '00:00',
              ),
              const SizedBox(height: 14),
              _construirCampo(
                rotulo: 'Km Retorno',
                controller: _kmRetornoController,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                icone: Icons.speed_outlined,
                hint: 'Ex: 85650',
                sufixo: 'km',
              ),
              const SizedBox(height: 14),
              _construirCampo(
                rotulo: 'Km Rodado',
                controller: _kmRodadoController,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                icone: Icons.add_road_outlined,
                hint: 'Ex: 230',
                sufixo: 'km',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processando ? null : () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _processando ? null : _confirmarEncerramento,
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Formatador que aplica a máscara HH:mm enquanto o motorista digita.
class _MascaraHorarioFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text;
    if (digitos.length > 4) {
      digitos = digitos.substring(0, 4);
    }

    var formatado = '';
    for (int i = 0; i < digitos.length; i++) {
      if (i == 2) formatado += ':';
      formatado += digitos[i];
    }

    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}
