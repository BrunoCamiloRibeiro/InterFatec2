// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/card_tracking_paciente.dart
// Camada: Apresentação / Componentes Visuais (Components / UI)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o mapa interativo e painel de rastreamento veicular em tempo real
// exibindo a localização de todos os motoristas municipais que estiverem
// com viagens ativas no momento.
// 1) Ouve a Stream reativa de motoristas ativos (LocalizacaoMotoristaService);
// 2) Apresenta mapa geográfico interativo com pins veiculares, pulso de sinal
//    e identificação visual do condutor, veículo e município de destino;
// 3) Permite interação de zoom, arrasto e seleção de condutores em trânsito;
// 4) Cumpre estritamente a diretriz do projeto: apenas exibe a localização dos
//    motoristas ativos no mapa, SEM estimativas de rota e SEM cálculo de ETA.
//
// ONDE É USADO NO PROJETO:
// - lib/paciente.dart (seção inferior do painel do passageiro)
// - lib/screens/preview_showcase.dart
// - test/components/card_tracking_paciente_test.dart
//
// DE ONDE RECEBE DADOS:
// - lib/services/localizacao_motorista_service.dart
// - Parâmetro opcional de injeção 'motoristasStreamOverride' para testes unitários.
//
// ORIGEM HISTÓRICA:
// Evolução do componente concebido na Issue #18, implementado na Issue #65.
// ============================================================================

import 'package:flutter/material.dart';

import '../models/localizacao_motorista_model.dart';
import '../services/localizacao_motorista_service.dart';

/// Card interativo de rastreamento em tempo real para o painel do paciente.
class CardTrackingPaciente extends StatefulWidget {
  /// Stream customizada opcional para injeção em testes automatizados
  final Stream<List<LocalizacaoMotoristaModel>>? motoristasStreamOverride;

  const CardTrackingPaciente({
    super.key,
    this.motoristasStreamOverride,
  });

  @override
  State<CardTrackingPaciente> createState() => _CardTrackingPacienteState();
}

class _CardTrackingPacienteState extends State<CardTrackingPaciente>
    with SingleTickerProviderStateMixin {
  late final LocalizacaoMotoristaService _localizacaoService;
  late final AnimationController _pulseController;

  String? _motoristaSelecionadoId;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _localizacaoService = LocalizacaoMotoristaService();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Em testes automatizados, repetição infinita bloqueia pumpAndSettle()
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnvironment) {
      _pulseController.repeat();
    } else {
      _pulseController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Stream<List<LocalizacaoMotoristaModel>> _obterStream() {
    if (widget.motoristasStreamOverride != null) {
      return widget.motoristasStreamOverride!;
    }
    return _localizacaoService.obterMotoristasAtivosStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LocalizacaoMotoristaModel>>(
      stream: _obterStream(),
      initialData: _localizacaoService.motoristasAtivos,
      builder: (context, snapshot) {
        final todosMotoristas = snapshot.data ?? [];
        final motoristasAtivos =
            todosMotoristas.where((m) => m.emViagem).toList();

        // Se o motorista selecionado não estiver mais ativo, reseta seleção
        if (_motoristaSelecionadoId != null &&
            !motoristasAtivos.any((m) => m.motoristaId == _motoristaSelecionadoId)) {
          _motoristaSelecionadoId = null;
        }

        final motoristaFocado = motoristasAtivos.firstWhere(
          (m) => m.motoristaId == _motoristaSelecionadoId,
          orElse: () => motoristasAtivos.isNotEmpty
              ? motoristasAtivos.first
              : LocalizacaoMotoristaModel(
                  id: '',
                  motoristaId: '',
                  motoristaNome: '',
                  veiculoPlaca: '',
                  veiculoModelo: '',
                  cidadeDestino: '',
                  latitude: -20.7389,
                  longitude: -49.8217,
                  ultimaAtualizacao: DateTime.now(),
                ),
        );

        return Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cabeçalho com indicador de status ao vivo
                _construirCabecalho(motoristasAtivos.length),
                const SizedBox(height: 12),

                // 2. Mapa Interativo
                _construirContainerMapa(motoristasAtivos, motoristaFocado),
                const SizedBox(height: 12),

                // 3. Seletor e Ficha de Detalhes dos Motoristas Ativos
                if (motoristasAtivos.isNotEmpty) ...[
                  _construirSeletorMotoristas(motoristasAtivos),
                  const SizedBox(height: 10),
                  _construirCardDetalhesMotorista(motoristaFocado),
                ] else
                  _construirEstadoSemMotoristas(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _construirCabecalho(int totalAtivos) {
    final eAtivo = totalAtivos > 0;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.map_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Localização dos Motoristas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Visualização da frota ativa em tempo real',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: eAtivo ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: eAtivo ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: eAtivo ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                eAtivo ? '$totalAtivos em trânsito' : 'Sem viagens ativas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: eAtivo ? const Color(0xFF15803D) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirContainerMapa(
    List<LocalizacaoMotoristaModel> motoristas,
    LocalizacaoMotoristaModel focado,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Stack(
          children: [
            // Pintura vetorial personalizada do mapa regional
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: _MapaRegionalPainter(
                    motoristas: motoristas,
                    motoristaFocadoId: _motoristaSelecionadoId ??
                        (motoristas.isNotEmpty ? motoristas.first.motoristaId : null),
                    pulseValue: _pulseController.value,
                    zoom: _zoomLevel,
                  ),
                );
              },
            ),

            // Controles de zoom sobrepostos (+ / -)
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _botaoControleMapa(
                    icon: Icons.add,
                    tooltip: 'Aumentar Zoom',
                    onTap: () {
                      setState(() {
                        if (_zoomLevel < 1.8) _zoomLevel += 0.2;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  _botaoControleMapa(
                    icon: Icons.remove,
                    tooltip: 'Diminuir Zoom',
                    onTap: () {
                      setState(() {
                        if (_zoomLevel > 0.8) _zoomLevel -= 0.2;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  _botaoControleMapa(
                    icon: Icons.my_location,
                    tooltip: 'Centralizar Frota',
                    onTap: () {
                      setState(() {
                        _zoomLevel = 1.0;
                        _motoristaSelecionadoId = null;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Legenda compacta de orientação geográfica regional
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me, size: 12, color: Color(0xFF0F172A)),
                    SizedBox(width: 4),
                    Text(
                      'Poloni • Barretos • S. J. Rio Preto',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoControleMapa({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
          ),
        ),
      ),
    );
  }

  Widget _construirSeletorMotoristas(List<LocalizacaoMotoristaModel> motoristas) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: motoristas.map((m) {
          final isSelected = (_motoristaSelecionadoId == m.motoristaId) ||
              (_motoristaSelecionadoId == null && motoristas.first == m);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: CircleAvatar(
                backgroundColor: isSelected ? Colors.white : const Color(0xFF0F172A),
                radius: 12,
                child: Icon(
                  Icons.directions_car,
                  size: 13,
                  color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                ),
              ),
              label: Text(
                '${m.motoristaNome.split(" ").first} • ${m.veiculoPlaca}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              selectedColor: const Color(0xFF0F172A),
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                ),
              ),
              onSelected: (_) {
                setState(() {
                  _motoristaSelecionadoId = m.motoristaId;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _construirCardDetalhesMotorista(LocalizacaoMotoristaModel m) {
    if (m.motoristaId.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_circle_rounded,
                  size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m.motoristaNome,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.veiculoPlaca,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.navigation_rounded,
                  size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Destino: ${m.cidadeDestino}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.gps_fixed, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Posição: ${m.latitude.toStringAsFixed(4)}, ${m.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoSemMotoristas() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Color(0xFF64748B)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nenhum motorista com viagem ativa no momento. Assim que um veículo iniciar a rota, o ponto aparecerá no mapa.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter que desenha o mapa da região noroeste paulista e os pins dos motoristas
class _MapaRegionalPainter extends CustomPainter {
  final List<LocalizacaoMotoristaModel> motoristas;
  final String? motoristaFocadoId;
  final double pulseValue;
  final double zoom;

  _MapaRegionalPainter({
    required this.motoristas,
    required this.motoristaFocadoId,
    required this.pulseValue,
    required this.zoom,
  });

  // Limites geográficos do mapa (Noroeste Paulista)
  static const double _minLat = -21.15;
  static const double _maxLat = -20.45;
  static const double _minLng = -50.10;
  static const double _maxLng = -48.50;

  Offset _geoToCanvas(double lat, double lng, Size size) {
    final xRatio = (lng - _minLng) / (_maxLng - _minLng);
    final yRatio = (lat - _minLat) / (_maxLat - _minLat);

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final rawX = xRatio * size.width;
    final rawY = (1.0 - yRatio) * size.height;

    // Aplica zoom centrado
    final scaledX = centerX + (rawX - centerX) * zoom;
    final scaledY = centerY + (rawY - centerY) * zoom;

    return Offset(scaledX, scaledY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    // 1. Linhas de rodovias regionais (SP-310 Washington Luís / SP-326 Faria Lima)
    final roadPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 3.5 * zoom
      ..style = PaintingStyle.stroke;

    final minorRoadPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 2.0 * zoom
      ..style = PaintingStyle.stroke;

    // Poloni: (-20.7389, -49.8217)
    final pPoloni = _geoToCanvas(-20.7389, -49.8217, size);
    // Mirassol: (-20.8194, -49.5028)
    final pMirassol = _geoToCanvas(-20.8194, -49.5028, size);
    // São José do Rio Preto: (-20.8113, -49.3758)
    final pRioPreto = _geoToCanvas(-20.8113, -49.3758, size);
    // Barretos: (-20.5572, -48.5678)
    final pBarretos = _geoToCanvas(-20.5572, -48.5678, size);
    // Monte Aprazível: (-20.7711, -49.7144)
    final pMonte = _geoToCanvas(-20.7711, -49.7144, size);

    // Traçado das rodovias estaduais
    final path = Path()
      ..moveTo(pPoloni.dx, pPoloni.dy)
      ..lineTo(pMonte.dx, pMonte.dy)
      ..lineTo(pMirassol.dx, pMirassol.dy)
      ..lineTo(pRioPreto.dx, pRioPreto.dy);

    final pathBarretos = Path()
      ..moveTo(pPoloni.dx, pPoloni.dy)
      ..quadraticBezierTo(
        (pPoloni.dx + pBarretos.dx) / 2,
        pPoloni.dy - 20,
        pBarretos.dx,
        pBarretos.dy,
      );

    canvas.drawPath(path, roadPaint);
    canvas.drawPath(pathBarretos, minorRoadPaint);

    // 2. Marcadores das cidades de referência
    _desenharCidade(canvas, pPoloni, 'Poloni (Sede)', true);
    _desenharCidade(canvas, pRioPreto, 'S. J. Rio Preto (HB)', false);
    _desenharCidade(canvas, pBarretos, 'Barretos (H. Amor)', false);
    _desenharCidade(canvas, pMirassol, 'Mirassol', false);

    // 3. Marcadores dos Motoristas Ativos
    for (int i = 0; i < motoristas.length; i++) {
      final m = motoristas[i];
      final pos = _geoToCanvas(m.latitude, m.longitude, size);
      final isFocado = (m.motoristaId == motoristaFocadoId) ||
          (motoristaFocadoId == null && i == 0);

      _desenharPinMotorista(canvas, pos, m, isFocado);
    }
  }

  void _desenharCidade(Canvas canvas, Offset pos, String nome, bool isSede) {
    final dotPaint = Paint()
      ..color = isSede ? const Color(0xFF0F172A) : const Color(0xFF64748B)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pos, isSede ? 5 : 3.5, dotPaint);

    final textSpan = TextSpan(
      text: nome,
      style: TextStyle(
        color: isSede ? const Color(0xFF0F172A) : const Color(0xFF475569),
        fontSize: isSede ? 10.5 : 9.5,
        fontWeight: isSede ? FontWeight.bold : FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(pos.dx - (textPainter.width / 2), pos.dy + 6),
    );
  }

  void _desenharPinMotorista(
    Canvas canvas,
    Offset pos,
    LocalizacaoMotoristaModel m,
    bool isFocado,
  ) {
    // 1. Radar / Anel pulsante de sinal ativo
    final radarRadius = (16.0 + (pulseValue * 14.0)) * (isFocado ? 1.2 : 1.0);
    final radarPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(
        alpha: (1.0 - pulseValue).clamp(0.0, 0.7),
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, radarRadius, radarPaint);

    // 2. Círculo externo do Pin
    final pinOuterPaint = Paint()
      ..color = isFocado ? const Color(0xFF0F172A) : const Color(0xFF0369A1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, isFocado ? 13 : 11, pinOuterPaint);

    // 3. Círculo interno branco
    final pinInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, isFocado ? 10.5 : 8.5, pinInnerPaint);

    // 4. Ponto central indicando o veículo
    final centerDotPaint = Paint()
      ..color = isFocado ? const Color(0xFF059669) : const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, isFocado ? 5.5 : 4.5, centerDotPaint);

    // 5. Etiqueta descritiva com placa e primeiro nome
    final nomeCurto = m.motoristaNome.split(' ').first;
    final tagText = '$nomeCurto • ${m.veiculoPlaca}';
    final tagSpan = TextSpan(
      text: tagText,
      style: TextStyle(
        color: isFocado ? Colors.white : const Color(0xFF0F172A),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    final tagPainter = TextPainter(
      text: tagSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final tagWidth = tagPainter.width + 12;
    final tagHeight = tagPainter.height + 6;
    final tagRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy - 22),
        width: tagWidth,
        height: tagHeight,
      ),
      const Radius.circular(6),
    );

    final tagBgPaint = Paint()
      ..color = isFocado ? const Color(0xFF0F172A) : Colors.white
      ..style = PaintingStyle.fill;
    final tagBorderPaint = Paint()
      ..color = isFocado ? Colors.white : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(tagRect, tagBgPaint);
    canvas.drawRRect(tagRect, tagBorderPaint);

    tagPainter.paint(
      canvas,
      Offset(pos.dx - (tagPainter.width / 2), pos.dy - 22 - (tagPainter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _MapaRegionalPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.zoom != zoom ||
        oldDelegate.motoristaFocadoId != motoristaFocadoId ||
        oldDelegate.motoristas.length != motoristas.length;
  }
}
