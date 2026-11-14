// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/card_tracking_paciente.dart
// Camada: Apresentação / Componentes Visuais (Components / UI)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o mapa interativo cartográfico baseado em API de mapas (OpenStreetMap /
// flutter_map) e painel de rastreamento veicular em tempo real exibindo a localização
// de todos os motoristas municipais que estiverem com viagens ativas no momento.
// 1) Utiliza API de mapas com tiles cartográficos reais (estradas, cidades, hospitais);
// 2) Verifica e solicita permissão de localização do Android/Web (Geolocator) para
//    exibir a posição do aparelho do próprio paciente ("Você está aqui") no mapa;
// 3) Ouve a Stream reativa de motoristas ativos (LocalizacaoMotoristaService) e plota
//    pins veiculares interativos com identificação de condutor, placa e destino;
// 4) Fornece controles de zoom (+, -), centralização da frota e foco no GPS do usuário;
// 5) Cumpre estritamente a diretriz do projeto: apenas exibe as localizações no mapa,
//    SEM estimativas de tempo (ETA) e SEM cálculo de rotas.
//
// ONDE É USADO NO PROJETO:
// - lib/paciente.dart (seção inferior do painel do passageiro)
// - lib/screens/gerenciador_viagens_screen.dart
// - test/components/card_tracking_paciente_test.dart
//
// DE ONDE RECEBE DADOS:
// - lib/services/localizacao_motorista_service.dart
// - Parâmetro opcional de injeção 'motoristasStreamOverride' para testes unitários.
//
// ORIGEM HISTÓRICA:
// Issue #18, refinado na Issue #65 com integração de API de mapas e permissão de GPS Android.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/localizacao_motorista_model.dart';
import '../services/localizacao_motorista_service.dart';

/// Card interativo de rastreamento em tempo real com API de mapas para o paciente.
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
  final MapController _mapController = MapController();

  String? _motoristaSelecionadoId;
  LatLng? _posicaoDispositivo;
  bool _solicitandoGps = false;
  bool _jaCentralizouMotorista = false;
  LocationPermission? _permissaoGps;

  // Centro padrão regional (Poloni - SP / Região Noroeste Paulista)
  static const LatLng _centroPadrao = LatLng(-20.7389, -49.8217);

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
      // Em tempo de execução, verifica a localização do aparelho
      _verificarLocalizacaoInicial();
    } else {
      _pulseController.value = 0.5;
    }
  }

  Future<void> _verificarLocalizacaoInicial() async {
    try {
      final perm = await _localizacaoService.solicitarPermissaoLocalizacao();
      if (!mounted) return;
      setState(() {
        _permissaoGps = perm;
      });
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        await _atualizarPosicaoAparelho(moverCamera: true);
      }
    } catch (_) {}
  }

  Future<void> _pedirPermissaoEAtualizarGps() async {
    if (_solicitandoGps) return;
    setState(() {
      _solicitandoGps = true;
    });

    try {
      final perm = await _localizacaoService.solicitarPermissaoLocalizacao();
      if (!mounted) return;
      setState(() {
        _permissaoGps = perm;
      });

      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        await _atualizarPosicaoAparelho(moverCamera: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permissão de localização necessária para exibir sua posição no mapa.',
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF0F172A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _solicitandoGps = false;
        });
      }
    }
  }

  Future<void> _atualizarPosicaoAparelho({bool moverCamera = false}) async {
    try {
      final pos = await _localizacaoService.obterPosicaoDispositivoAtual();
      if (pos != null && mounted) {
        final novaPosicao = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _posicaoDispositivo = novaPosicao;
        });
        await _localizacaoService.garantirLocalizacaoViagemAtivaComGpsDispositivo(
          pos.latitude,
          pos.longitude,
        );
        if (moverCamera && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              _mapController.move(novaPosicao, 14.5);
            } catch (_) {}
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Stream<List<LocalizacaoMotoristaModel>> _obterStream() {
    if (widget.motoristasStreamOverride != null) {
      return widget.motoristasStreamOverride!;
    }
    return _localizacaoService.obterMotoristasAtivosStream();
  }

  void _centralizarFrota(List<LocalizacaoMotoristaModel> motoristas) {
    if (motoristas.isEmpty) {
      if (_posicaoDispositivo != null) {
        _mapController.move(_posicaoDispositivo!, 13.0);
      } else {
        _mapController.move(_centroPadrao, 10.0);
      }
      return;
    }

    if (motoristas.length == 1) {
      final m = motoristas.first;
      _mapController.move(LatLng(m.latitude, m.longitude), 12.0);
      return;
    }

    double minLat = motoristas.first.latitude;
    double maxLat = motoristas.first.latitude;
    double minLng = motoristas.first.longitude;
    double maxLng = motoristas.first.longitude;

    for (final m in motoristas) {
      if (m.latitude < minLat) minLat = m.latitude;
      if (m.latitude > maxLat) maxLat = m.latitude;
      if (m.longitude < minLng) minLng = m.longitude;
      if (m.longitude > maxLng) maxLng = m.longitude;
    }

    final centro = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(centro, 10.0);
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

        if (motoristasAtivos.isNotEmpty && !_jaCentralizouMotorista) {
          _jaCentralizouMotorista = true;
          final alvo = LatLng(
            motoristasAtivos.first.latitude,
            motoristasAtivos.first.longitude,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              _mapController.move(alvo, 14.0);
            } catch (_) {}
          });
        } else if (motoristasAtivos.isEmpty) {
          _jaCentralizouMotorista = false;
        }

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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cabeçalho com indicador de status ao vivo
                _construirCabecalho(motoristasAtivos.length),
                const SizedBox(height: 12),

                // 2. Banner de status do GPS do dispositivo
                _construirBarraStatusGps(),
                const SizedBox(height: 10),

                // 3. Mapa Interativo com API de Mapas
                _construirContainerMapa(motoristasAtivos, motoristaFocado),
                const SizedBox(height: 12),

                // 4. Seletor e Ficha de Detalhes dos Motoristas Ativos
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
    final badgeStatus = Container(
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
          Flexible(
            child: Text(
              eAtivo ? '$totalAtivos em trânsito' : 'Sem viagens ativas',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: eAtivo ? const Color(0xFF15803D) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Text(
                    'Localização dos Motoristas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  badgeStatus,
                ],
              ),
              const SizedBox(height: 3),
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
      ],
    );
  }

  Widget _construirBarraStatusGps() {
    final gpsAtivo = _posicaoDispositivo != null;
    final gpsNegado = _permissaoGps == LocationPermission.denied ||
        _permissaoGps == LocationPermission.deniedForever;

    final botaoGps = TextButton(
      onPressed: _pedirPermissaoEAtualizarGps,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: _solicitandoGps
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              gpsAtivo
                  ? 'Atualizar GPS'
                  : (gpsNegado ? 'Permitir GPS' : 'Ativar GPS'),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: gpsAtivo
                    ? const Color(0xFF1D4ED8)
                    : (gpsNegado
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF0F172A)),
              ),
            ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: gpsAtivo
            ? const Color(0xFFEFF6FF)
            : (gpsNegado ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: gpsAtivo
              ? const Color(0xFFBFDBFE)
              : (gpsNegado ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final linhaGps = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  gpsAtivo
                      ? Icons.gps_fixed
                      : (gpsNegado ? Icons.location_disabled : Icons.gps_not_fixed),
                  size: 16,
                  color: gpsAtivo
                      ? const Color(0xFF2563EB)
                      : (gpsNegado
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gpsAtivo
                      ? 'Localização do seu aparelho ativa (exibida no mapa)'
                      : (gpsNegado
                          ? 'Permissão de GPS não concedida'
                          : 'Ative a localização do aparelho para ver sua posição'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: gpsAtivo
                        ? const Color(0xFF1E40AF)
                        : (gpsNegado
                            ? const Color(0xFF991B1B)
                            : const Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          );

          final escala = MediaQuery.textScalerOf(context).scale(12);
          final empilhar = constraints.maxWidth < 310 ||
              (constraints.maxWidth < 380 && escala > 16);

          if (empilhar) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                linhaGps,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: botaoGps),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: linhaGps),
              const SizedBox(width: 8),
              Flexible(flex: 0, child: botaoGps),
            ],
          );
        },
      ),
    );
  }

  Widget _construirContainerMapa(
    List<LocalizacaoMotoristaModel> motoristas,
    LocalizacaoMotoristaModel focado,
  ) {
    final centroInicial = motoristas.isNotEmpty
        ? LatLng(motoristas.first.latitude, motoristas.first.longitude)
        : (_posicaoDispositivo ?? _centroPadrao);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 215,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Stack(
          children: [
            // 1. Mapa Real Interativo (OpenStreetMap / FlutterMap)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: centroInicial,
                initialZoom: 10.5,
                minZoom: 4.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // Camada de Tiles Cartográficos Oficiais (OpenStreetMap)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'br.gov.sp.fatec.trans_saude',
                  tileProvider: NetworkTileProvider(),
                  errorTileCallback: (tile, error, stackTrace) {
                    // Trata falhas de conectividade de forma silenciosa e resiliente
                  },
                ),

                // Camada de Marcadores Reais dos Veículos e do Dispositivo
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final markers = <Marker>[];

                    // Marcador do aparelho do paciente ("Você está aqui")
                    if (_posicaoDispositivo != null) {
                      markers.add(
                        Marker(
                          point: _posicaoDispositivo!,
                          width: 80,
                          height: 60,
                          child: _construirPinUsuario(),
                        ),
                      );
                    }

                    // Marcadores dos motoristas ativos em trânsito
                    for (final m in motoristas) {
                      final isSelected = (_motoristaSelecionadoId == m.motoristaId) ||
                          (_motoristaSelecionadoId == null &&
                              motoristas.isNotEmpty &&
                              motoristas.first == m);

                      markers.add(
                        Marker(
                          point: LatLng(m.latitude, m.longitude),
                          width: 110,
                          height: 64,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _motoristaSelecionadoId = m.motoristaId;
                              });
                              _mapController.move(
                                LatLng(m.latitude, m.longitude),
                                13.0,
                              );
                            },
                            child: _construirPinMotorista(m, isSelected),
                          ),
                        ),
                      );
                    }

                    return MarkerLayer(markers: markers);
                  },
                ),
              ],
            ),

            // Controles de zoom e centralização sobrepostos (+ / - / my_location)
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _botaoControleMapa(
                    icon: Icons.add,
                    tooltip: 'Aumentar Zoom',
                    onTap: () {
                      final zoomAtual = _mapController.camera.zoom;
                      if (zoomAtual < 17.5) {
                        _mapController.move(
                          _mapController.camera.center,
                          zoomAtual + 1.0,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  _botaoControleMapa(
                    icon: Icons.remove,
                    tooltip: 'Diminuir Zoom',
                    onTap: () {
                      final zoomAtual = _mapController.camera.zoom;
                      if (zoomAtual > 5.0) {
                        _mapController.move(
                          _mapController.camera.center,
                          zoomAtual - 1.0,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  _botaoControleMapa(
                    icon: Icons.my_location,
                    tooltip: 'Minha Localização',
                    onTap: () async {
                      if (_posicaoDispositivo != null) {
                        _mapController.move(_posicaoDispositivo!, 14.0);
                      } else {
                        await _pedirPermissaoEAtualizarGps();
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  _botaoControleMapa(
                    icon: Icons.directions_bus_rounded,
                    tooltip: 'Centralizar Frota',
                    onTap: () {
                      setState(() {
                        _motoristaSelecionadoId = null;
                      });
                      _centralizarFrota(motoristas);
                    },
                  ),
                ],
              ),
            ),

            // Legenda compacta de orientação e escala
            Positioned(
              left: 10,
              bottom: 10,
              right: 50,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 12, color: Color(0xFF0F172A)),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'OpenStreetMap • Tempo Real',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirPinUsuario() {
    final pulso = _pulseController.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 3),
            ],
          ),
          child: const Text(
            'Você',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 22 + (pulso * 10),
              height: 22 + (pulso * 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 1.0 - pulso),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirPinMotorista(LocalizacaoMotoristaModel m, bool isSelected) {
    final corDestaque = isSelected ? const Color(0xFF16A34A) : const Color(0xFF0F172A);
    final primeiroNome = m.motoristaNome.split(" ").first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tag com nome e placa
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: corDestaque, width: isSelected ? 1.5 : 1.0),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            'Condutor $primeiroNome',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: corDestaque,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        // Ícone do veículo com borda e sombra
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: corDestaque,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_car,
            size: 14,
            color: Colors.white,
          ),
        ),
      ],
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
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
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
                _mapController.move(LatLng(m.latitude, m.longitude), 13.0);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isLocalizacaoDesatualizada(LocalizacaoMotoristaModel m) {
    return DateTime.now().difference(m.ultimaAtualizacao).inMinutes >= 10;
  }

  String _formatarPosicaoComHorario(LocalizacaoMotoristaModel m) {
    final dt = m.ultimaAtualizacao.toLocal();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final base = 'Atualizado às $hh:$mm';
    return _isLocalizacaoDesatualizada(m) ? '$base (desatualizado)' : base;
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
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    m.veiculoPlaca,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.navigation_rounded,
                  size: 16, color: Color(0xFF475569)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Destino: ${m.cidadeDestino}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed, size: 15, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatarPosicaoComHorario(m),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _isLocalizacaoDesatualizada(m)
                              ? const Color(0xFFB45309)
                              : const Color(0xFF475569),
                          fontWeight: _isLocalizacaoDesatualizada(m)
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _mapController.move(LatLng(m.latitude, m.longitude), 13.5);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.center_focus_strong,
                          size: 16,
                          color: Color(0xFF0369A1),
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Focar no Mapa',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
