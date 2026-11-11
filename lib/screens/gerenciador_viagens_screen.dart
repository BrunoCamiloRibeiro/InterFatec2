import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../lista_pessoas.dart';
import '../lista_veiculos.dart';
import '../models/motorista_model.dart';
import '../models/paciente_model.dart';
import '../models/user_role.dart';
import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import '../services/auth_service.dart';
import '../services/paciente_sync_service.dart';
import '../services/viagem_service.dart';

/// Tela principal do Gerenciador de Horários do Dia (Perfil Administrador).
class GerenciadorViagensScreen extends StatefulWidget {
  final ViagemService? viagemServiceOverride;
  final AuthService? authServiceOverride;
  final DateTime? dataInicial;
  final List<VeiculoModel>? veiculosIniciais;
  final List<MotoristaModel>? motoristasIniciais;
  final List<PacienteModel>? pacientesIniciais;

  const GerenciadorViagensScreen({
    super.key,
    this.viagemServiceOverride,
    this.authServiceOverride,
    this.dataInicial,
    this.veiculosIniciais,
    this.motoristasIniciais,
    this.pacientesIniciais,
  });

  @override
  State<GerenciadorViagensScreen> createState() => _GerenciadorViagensScreenState();
}

class _GerenciadorViagensScreenState extends State<GerenciadorViagensScreen> {
  late final ViagemService _viagemService;
  late final AuthService _authService;

  late DateTime _dataSelecionada;
  StreamSubscription<List<ViagemModel>>? _subViagens;
  StreamSubscription<List<VeiculoModel>>? _subVeiculos;
  StreamSubscription<({String? viagemId, PacienteModel paciente})>?
      _subSyncPacientes;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subFirestoreVeiculos;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subFirestoreUsuarios;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subFirestoreViagens;

  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<ViagemModel> _todasViagensDoDia = [];
  List<VeiculoModel> _veiculosCadastrados = [];
  List<PacienteModel> _pacientesCadastrados = [];

  String _filtroTexto = '';
  String _filtroStatus = 'todos'; // todos, planejada, ativa, concluida, cancelada

  @override
  void initState() {
    super.initState();
    _viagemService = widget.viagemServiceOverride ?? ViagemService();
    _authService = widget.authServiceOverride ?? FirebaseAuthService();

    final dataRef = widget.dataInicial ?? DateTime.now();
    _dataSelecionada = DateTime(dataRef.year, dataRef.month, dataRef.day);

    _inicializarDadosBasePessoasEVeiculos();
    _atualizarViagensDoDia();

    _subViagens = _viagemService.todasViagensStream.listen((_) {
      if (mounted) {
        _atualizarViagensDoDia();
      }
    });

    _subVeiculos = _viagemService.veiculosStream.listen((veiculos) {
      if (mounted) {
        setState(() {
          _veiculosCadastrados = veiculos;
        });
      }
    });

    _subSyncPacientes = PacienteSyncService().alteracoesPorViagemStream.listen((evento) {
      if (evento.viagemId == null || evento.viagemId!.trim().isEmpty) {
        final p = evento.paciente;
        _viagemService.atualizarStatusPassageiroNaViagem(
          viagemId: '',
          pacienteId: p.id,
          novoStatus: p.status,
          prontoRetorno: p.prontoRetorno,
          janelaReversao: p.janelaReversao,
          limparJanelaReversao: p.janelaReversao == null,
          persistirRemoto: false,
        );
      }
      if (mounted) {
        setState(() {
          _todasViagensDoDia = _viagemService.obterViagensPorData(_dataSelecionada);
        });
      }
    });
  }

  @override
  void dispose() {
    _subViagens?.cancel();
    _subVeiculos?.cancel();
    _subSyncPacientes?.cancel();
    _subFirestoreVeiculos?.cancel();
    _subFirestoreUsuarios?.cancel();
    _subFirestoreViagens?.cancel();
    super.dispose();
  }

  void _inicializarDadosBasePessoasEVeiculos() {
    _veiculosCadastrados = List<VeiculoModel>.from(
      widget.veiculosIniciais ?? _viagemService.todosVeiculos,
    );
    _pacientesCadastrados = List<PacienteModel>.from(
      widget.pacientesIniciais ?? const <PacienteModel>[],
    );

    if (_isFirebaseDisponivel()) {
      try {
        _subFirestoreVeiculos = FirebaseFirestore.instance
            .collection('veiculos')
            .snapshots()
            .listen((snapshot) {
          if (!mounted) return;
          setState(() {
            _veiculosCadastrados = snapshot.docs
                .map((d) => VeiculoModel.fromMap(d.data(), docId: d.id))
                .toList();
          });
        });

        _subFirestoreUsuarios = FirebaseFirestore.instance
            .collection('usuarios')
            .snapshots()
            .listen((snapshot) {
          if (!mounted) return;
          final pacientes = <PacienteModel>[];
          for (final doc in snapshot.docs) {
            final dados = doc.data();
            if (_documentoEstaInativo(dados)) continue;
            final role = (dados['role'] ?? dados['tipo'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            if (role == 'paciente' || role.isEmpty) {
              pacientes.add(PacienteModel.fromMap(dados, docId: doc.id));
            }
          }
          setState(() {
            _pacientesCadastrados = pacientes;
          });
        });

        _subFirestoreViagens = FirebaseFirestore.instance
            .collection('viagens')
            .snapshots()
            .listen((snapshot) {
          if (!mounted) return;
          final viagensRemotas = snapshot.docs
              .map((d) => ViagemModel.fromMap(d.data(), docId: d.id))
              .toList();
          _viagemService.sincronizarViagensRemotas(viagensRemotas);
          _atualizarViagensDoDia();
        });
      } catch (_) {}
    }
  }
  void _atualizarViagensDoDia() {
    setState(() {
      _todasViagensDoDia = _viagemService.obterViagensPorData(_dataSelecionada);
    });
  }

  void _mudarDia(int offsetDias) {
    setState(() {
      _dataSelecionada = _dataSelecionada.add(Duration(days: offsetDias));
      _atualizarViagensDoDia();
    });
  }

  Future<void> _selecionarDataCalendario() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'SELECIONAR DATA DA GRADE DE HORÁRIOS',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );
    if (escolhida != null && mounted) {
      setState(() {
        _dataSelecionada = DateTime(escolhida.year, escolhida.month, escolhida.day);
        _atualizarViagensDoDia();
      });
    }
  }

  List<ViagemModel> get _viagensFiltradas {
    return _todasViagensDoDia.where((v) {
      if (_filtroStatus != 'todos') {
        if (_filtroStatus == 'planejada' && !v.isPlanejada && !v.isAberta) return false;
        if (_filtroStatus == 'ativa' && !v.isAtiva) return false;
        if (_filtroStatus == 'concluida' && !v.isConcluida) return false;
        if (_filtroStatus == 'cancelada' && !v.isCancelada) return false;
      }
      if (_filtroTexto.trim().isNotEmpty) {
        final busca = _filtroTexto.toLowerCase().trim();
        final matchTitulo = v.tituloHorario.toLowerCase().contains(busca);
        final matchDestino = v.cidadeDestino.toLowerCase().contains(busca);
        final matchMotorista = v.motoristaNome.toLowerCase().contains(busca);
        final matchVeiculo = '${v.veiculoPlaca} ${v.veiculoModelo}'.toLowerCase().contains(busca);
        final matchPassageiro = v.passageiros.any(
          (p) =>
              p.pacienteNome.toLowerCase().contains(busca) ||
              (p.acompanhanteNome?.toLowerCase().contains(busca) ?? false),
        );
        return matchTitulo || matchDestino || matchMotorista || matchVeiculo || matchPassageiro;
      }
      return true;
    }).toList();
  }

  bool _documentoEstaInativo(Map<String, dynamic> dados) {
    final ativo = dados['ativo'];
    final status = dados['status']?.toString().toLowerCase().trim();
    final situacao = dados['situacao']?.toString().toLowerCase().trim();
    return ativo == false ||
        ativo == 'false' ||
        status == 'inativo' ||
        situacao == 'inativo' ||
        status == 'excluido' ||
        situacao == 'excluido';
  }

  VeiculoModel _resolverVeiculoDaViagem(ViagemModel viagem) {
    return _veiculosCadastrados.firstWhere(
      (ve) =>
          (viagem.veiculoId.isNotEmpty && ve.id == viagem.veiculoId) ||
          (viagem.veiculoPlaca.isNotEmpty && ve.placa == viagem.veiculoPlaca),
      orElse: () => VeiculoModel(
        id: viagem.veiculoId,
        placa: viagem.veiculoPlaca,
        modelo: viagem.veiculoModelo,
        capacidade: 0,
        quilometragemAtual: 0,
      ),
    );
  }

  String _formatarDataBrasileira(DateTime dt) {
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    final ano = dt.year.toString();
    return '$dia/$mes/$ano';
  }

  bool _isDataHoje(DateTime dt) {
    final hoje = DateTime.now();
    return dt.year == hoje.year && dt.month == hoje.month && dt.day == hoje.day;
  }

  @override
  Widget build(BuildContext context) {
    final viagensExibicao = _viagensFiltradas;
    final totalHorarios = _todasViagensDoDia.length;
    final totalAtivos = _todasViagensDoDia.where((v) => v.isAtiva).length;
    final totalPlanejados =
        _todasViagensDoDia.where((v) => v.isPlanejada || v.isAberta).length;
    final totalConcluidos = _todasViagensDoDia.where((v) => v.isConcluida).length;
    final totalCancelados = _todasViagensDoDia.where((v) => v.isCancelada).length;

    int assentosOcupados = 0;
    int assentosTotais = 0;
    for (final v in _todasViagensDoDia.where((v) => !v.isCancelada)) {
      assentosOcupados += _calcularAssentosComBaixa(v);
      assentosTotais += _resolverVeiculoDaViagem(v).capacidade;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _construirMenuLateral(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gerenciador de Horários',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                'Escala e Grade Diária',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('botaoGestaoPessoasAppBar'),
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Gestão de Pessoas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ListaPessoas()),
              );
            },
          ),
          IconButton(
            key: const Key('botaoLogoutAdmin'),
            icon: const Icon(Icons.logout),
            tooltip: 'Encerrar Sessão',
            onPressed: () async {
              await _authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de navegação e seleção de data do dia
              _construirBarraData(),
              const SizedBox(height: 14),

              // Indicadores e estatísticas da grade diária
              _construirPainelIndicadores(
                total: totalHorarios,
                ativos: totalAtivos,
                planejados: totalPlanejados,
                concluidos: totalConcluidos,
                cancelados: totalCancelados,
                assentosOcupados: assentosOcupados,
                assentosTotais: assentosTotais,
              ),
              const SizedBox(height: 14),

              // Barra de busca e filtros de status
              _construirBarraFiltros(),
              const SizedBox(height: 14),

              // Lista com os cartões dos Horários
              if (viagensExibicao.isEmpty)
                _construirEstadoVazio()
              else
                ...viagensExibicao.map((v) => _construirCardHorario(v)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('botaoNovoHorarioFAB'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Novo Horário', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _abrirModalNovoOuEditarHorario(null),
      ),
    );
  }

  Widget _construirBarraData() {
    final eHoje = _isDataHoje(_dataSelecionada);
    final textoData = '${eHoje ? "Hoje, " : ""}${_formatarDataBrasileira(_dataSelecionada)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 10,
        children: [
          // Controles de data (anterior, seletor, próxima)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('botaoDiaAnterior'),
                icon: const Icon(Icons.chevron_left),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Dia Anterior',
                onPressed: () => _mudarDia(-1),
              ),
              Flexible(
                child: InkWell(
                  key: const Key('botaoSeletorDataCalendario'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: _selecionarDataCalendario,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0F172A)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            textoData,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('botaoProximoDia'),
                icon: const Icon(Icons.chevron_right),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Próximo Dia',
                onPressed: () => _mudarDia(1),
              ),
            ],
          ),

          // Ações do topo: Duplicar de outro dia e Novo Horário
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('botaoDuplicarHorarios'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Duplicar de outro dia'),
                onPressed: _abrirModalDuplicarHorarios,
              ),
              ElevatedButton.icon(
                key: const Key('botaoNovoHorarioBarra'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo Horário'),
                onPressed: () => _abrirModalNovoOuEditarHorario(null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirPainelIndicadores({
    required int total,
    required int ativos,
    required int planejados,
    required int concluidos,
    required int cancelados,
    required int assentosOcupados,
    required int assentosTotais,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final larguraItem = constraints.maxWidth < 600
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 24) / 4;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _itemIndicador(
              titulo: 'Horários no Dia',
              valor: '$total',
              subtitulo: '$planejados planejados',
              cor: const Color(0xFF0F172A),
              icone: Icons.schedule,
              largura: larguraItem,
            ),
            _itemIndicador(
              titulo: 'Em Trânsito (Ativos)',
              valor: '$ativos',
              subtitulo: 'viagens em andamento',
              cor: const Color(0xFF059669),
              icone: Icons.directions_bus,
              largura: larguraItem,
            ),
            _itemIndicador(
              titulo: 'Assentos Ocupados',
              valor: '$assentosOcupados / $assentosTotais',
              subtitulo: 'lotação da frota',
              cor: const Color(0xFF0284C7),
              icone: Icons.event_seat,
              largura: larguraItem,
            ),
            _itemIndicador(
              titulo: 'Finalizadas / Canceladas',
              valor: '$concluidos / $cancelados',
              subtitulo: 'baixa operacional',
              cor: const Color(0xFF475569),
              icone: Icons.check_circle_outline,
              largura: larguraItem,
            ),
          ],
        );
      },
    );
  }

  Widget _itemIndicador({
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color cor,
    required IconData icone,
    required double largura,
  }) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icone, size: 16, color: cor),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _construirBarraFiltros() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          TextField(
            key: const Key('campoBuscaHorario'),
            decoration: InputDecoration(
              hintText: 'Buscar por horário, cidade, motorista, veículo ou paciente...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _filtroTexto.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _filtroTexto = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              isDense: true,
            ),
            onChanged: (val) {
              setState(() {
                _filtroTexto = val;
              });
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipFiltroStatus('Todos', 'todos'),
                _chipFiltroStatus('Planejadas', 'planejada'),
                _chipFiltroStatus('Ativas', 'ativa'),
                _chipFiltroStatus('Concluídas', 'concluida'),
                _chipFiltroStatus('Canceladas', 'cancelada'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltroStatus(String rotulo, String valor) {
    final selecionado = _filtroStatus == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: selecionado,
        label: Text(rotulo),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
          color: selecionado ? Colors.white : const Color(0xFF0F172A),
        ),
        selectedColor: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFF1F5F9),
        checkmarkColor: Colors.white,
        onSelected: (_) {
          setState(() {
            _filtroStatus = valor;
          });
        },
      ),
    );
  }

  Widget _construirEstadoVazio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.schedule_send, size: 54, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'Nenhum Horário cadastrado nesta data',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crie um novo Horário de Saída para o dia ou duplique a grade de uma data anterior.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Duplicar de outro dia'),
                onPressed: _abrirModalDuplicarHorarios,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Criar Novo Horário'),
                onPressed: () => _abrirModalNovoOuEditarHorario(null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _resolverStatusEfetivoPassageiro(
    ViagemModel viagem,
    PassageiroViagemModel passageiro,
  ) {
    final pacSync = PacienteSyncService().obterPacienteMemoria(
      passageiro.pacienteId,
      viagemId: viagem.id,
    );
    int statusEfetivo = pacSync?.status ?? passageiro.statusEmbarque;
    if (viagem.isConcluida && statusEfetivo != 5) {
      statusEfetivo = 4;
    }
    return statusEfetivo;
  }

  int _calcularAssentosComBaixa(ViagemModel viagem) {
    int total = 0;
    for (final p in viagem.passageiros) {
      final st = _resolverStatusEfetivoPassageiro(viagem, p);
      if (st >= 1 && st <= 3) {
        total += p.assentosOcupados;
      }
    }
    return total;
  }

  Widget _construirCardHorario(ViagemModel viagem) {
    Color corBadge;
    String textoBadge;
    switch (viagem.status.toLowerCase()) {
      case 'ativa':
      case 'em_andamento':
      case 'em andamento':
        corBadge = const Color(0xFF059669);
        textoBadge = 'EM TRÂNSITO (ATIVA)';
        break;
      case 'aberta':
        corBadge = const Color(0xFF0284C7);
        textoBadge = 'ABERTA';
        break;
      case 'concluida':
      case 'encerrada':
        corBadge = const Color(0xFF15803D);
        textoBadge = 'CONCLUÍDA';
        break;
      case 'cancelada':
        corBadge = const Color(0xFFE11D48);
        textoBadge = 'CANCELADA';
        break;
      case 'planejada':
      default:
        corBadge = const Color(0xFF0284C7);
        textoBadge = 'PLANEJADA';
        break;
    }

    final preenchidosBaixa = _calcularAssentosComBaixa(viagem);

    // Regra de borda: verificar se há pacientes sem CPF
    final temPacienteSemCpf = viagem.passageiros.any(
      (p) => p.pacienteCpf == null || p.pacienteCpf!.trim().isEmpty,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: viagem.isCancelada ? Colors.red.shade200 : Colors.grey.shade200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: Key('cardHorario_${viagem.id}'),
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            title: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: corBadge.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    viagem.tituloHorario,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: corBadge,
                    ),
                  ),
                ),
                Text(
                  viagem.cidadeDestino,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: corBadge,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    textoBadge,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            trailing: Container(
              key: Key('contagemAssentos_${viagem.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_seat_rounded,
                    size: 14,
                    color: Color(0xFF334155),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$preenchidosBaixa',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          children: [
            if (viagem.isConcluida)
              Container(
                key: Key('bannerViagemConcluida_${viagem.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Color(0xFF15803D),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          'Viagem concluída pelo motorista',
                          if (viagem.kmInicial > 0) 'KM Saída: ${viagem.kmInicial}',
                          if (viagem.kmFinal != null && viagem.kmFinal! > 0)
                            'KM Retorno: ${viagem.kmFinal}',
                          if (viagem.kmRodado != null && viagem.kmRodado! > 0)
                            'KM Rodado: ${viagem.kmRodado} km',
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Alerta se houver paciente sem documento
            if (temPacienteSemCpf)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Aviso: Há paciente(s) sem CPF cadastrado neste Horário. Eles constam na escala de embarque, mas não poderão acessar o app até regularização.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),

            // Ações do Horário: Editar, Reordenar, Cancelar
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (!viagem.isConcluida && !viagem.isCancelada) ...[
                  OutlinedButton.icon(
                    key: Key('botaoReordenar_${viagem.id}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.swap_vert, size: 15),
                    label: const Text('Reordenar'),
                    onPressed: viagem.passageiros.length > 1
                        ? () => _abrirModalReordenarPassageiros(viagem)
                        : null,
                  ),
                  OutlinedButton.icon(
                    key: Key('botaoEditarHorario_${viagem.id}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.edit, size: 15),
                    label: const Text('Editar'),
                    onPressed: () => _abrirModalNovoOuEditarHorario(viagem),
                  ),
                ],
                if (!viagem.isCancelada)
                  OutlinedButton.icon(
                    key: Key('botaoCancelarHorario_${viagem.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE11D48),
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text('Cancelar Horário'),
                    onPressed: () => _confirmarCancelamentoHorario(viagem),
                  ),
              ],
            ),
            const Divider(height: 14),

            if (viagem.passageiros.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Nenhum passageiro adicionado a este horário ainda. Clique em "Editar" para adicionar.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              )
            else
              ...viagem.passageiros.map((p) => _construirItemPassageiro(viagem, p)),
          ],
        ),
      ),
    ),
  );
}

  Widget _construirItemPassageiro(ViagemModel viagem, PassageiroViagemModel passageiro) {
    final codigoAcesso = viagem.codigosAcesso[passageiro.pacienteId]?.trim();
    final horarioAtend = passageiro.horarioAtendimento.trim();

    // Resolve o status e a prontidão isolados para esta viagem específica
    final pacSync = PacienteSyncService().obterPacienteMemoria(
      passageiro.pacienteId,
      viagemId: viagem.id,
    );
    final statusEfetivo = _resolverStatusEfetivoPassageiro(viagem, passageiro);
    final prontoRetornoEfetivo =
        pacSync?.prontoRetorno ?? passageiro.prontoRetorno;

    final (nomeStatus, corStatus, iconeStatus) =
        PacienteModel.dadosStatus(statusEfetivo);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do passageiro: [Horário] + Nome (igual ao card da viagem)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (horarioAtend.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    horarioAtend,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              Text(
                passageiro.pacienteNome,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 1. Status (em coluna)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                key: ValueKey('status_passageiro_admin_${passageiro.pacienteId}'),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: corStatus.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: corStatus.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconeStatus, size: 12, color: corStatus),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        nomeStatus,
                        style: TextStyle(
                          color: corStatus,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (statusEfetivo == 2 && prontoRetornoEfetivo)
                Container(
                  key: ValueKey('pronto_retorno_admin_${passageiro.pacienteId}'),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF16A34A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active, size: 12, color: Color(0xFF15803D)),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Pronto p/ Retorno',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Origem (destacada)
          Row(
            children: [
              const Icon(Icons.my_location_rounded, size: 13, color: Color(0xFF334155)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Origem: ${passageiro.localOrigem}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),

          // 3. Destino (destacado)
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: Color(0xFF0F172A)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Destino: ${passageiro.localDestino}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),

          // 4. Código de acesso do passageiro
          if (codigoAcesso != null && codigoAcesso.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.key,
                    size: 12,
                    color: Color(0xFF60A5FA),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Código: $codigoAcesso',
                      key: ValueKey('codigo_acesso_admin_${passageiro.pacienteId}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (passageiro.observacoes != null && passageiro.observacoes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Obs: ${passageiro.observacoes}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIÁLOGOS E MODAIS (Novo Horário, Duplicação, Reordenação e Exclusão)
  // ============================================================================

  Future<void> _abrirModalNovoOuEditarHorario(ViagemModel? viagemExistente) async {
    final eEdicao = viagemExistente != null;

    final controllerHorario = TextEditingController(
      text: viagemExistente?.nomeHorario ?? '06:00',
    );
    final controllerDestino = TextEditingController(
      text: viagemExistente?.cidadeDestino ?? 'SÃO JOSÉ DO RIO PRETO',
    );
    final controllerObs = TextEditingController(
      text: viagemExistente?.observacoes ?? '',
    );

    List<PassageiroViagemModel> passageirosTemp = viagemExistente != null
        ? List<PassageiroViagemModel>.from(viagemExistente.passageiros)
        : [];

    String? mensagemErroValidacao;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalAssentos =
                passageirosTemp.fold<int>(0, (acc, p) => acc + p.assentosOcupados);

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(eEdicao ? 'Editar Horário' : 'Novo Horário de Saída'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mensagemErroValidacao != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Text(
                            mensagemErroValidacao!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                          ),
                        ),

                      // Horário de Saída
                      TextField(
                        key: const Key('campoNomeHorario'),
                        controller: controllerHorario,
                        decoration: const InputDecoration(
                          labelText: 'Horário de Saída *',
                          hintText: 'Ex.: 06:00',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Cidade Destino
                      TextField(
                        key: const Key('campoCidadeDestino'),
                        controller: controllerDestino,
                        decoration: const InputDecoration(
                          labelText: 'Cidade de Destino *',
                          hintText: 'Ex.: BARRETOS',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Observações
                      TextField(
                        controller: controllerObs,
                        decoration: const InputDecoration(
                          labelText: 'Observações do Horário',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Gestão de Passageiros
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Passageiros (${passageirosTemp.length}) - Vagas previstas: $totalAssentos (veículo escolhido pelo motorista)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          TextButton.icon(
                            key: const Key('botaoAdicionarPassageiroModal'),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('Adicionar'),
                            onPressed: () async {
                              final novoPassageiro = await _abrirModalSelecionarPassageiro(
                                ordemSugerida: passageirosTemp.length + 1,
                                cidadeSugerida: controllerDestino.text,
                              );
                              if (novoPassageiro != null) {
                                setModalState(() {
                                  passageirosTemp.add(novoPassageiro);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (passageirosTemp.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Nenhum passageiro vinculado. Clique em "Adicionar" para selecionar pessoas cadastradas.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        )
                      else
                        ...passageirosTemp.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final p = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Text('#${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${p.pacienteNome}${p.acompanhanteNome != null && p.acompanhanteNome!.isNotEmpty ? " (+ Acomp: ${p.acompanhanteNome})" : ""} [${p.horarioAtendimento}]',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setModalState(() {
                                      passageirosTemp.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  key: const Key('botaoSalvarHorarioModal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (eEdicao) {
                      final viagemAtualizada = viagemExistente.copyWith(
                        nomeHorario: controllerHorario.text.trim(),
                        cidadeDestino: controllerDestino.text.trim(),
                        observacoes: controllerObs.text.trim(),
                        motoristaId: '',
                        motoristaNome: '',
                        passageiros: passageirosTemp,
                      );

                      final res = await _viagemService.atualizarHorarioViagem(
                        viagem: viagemAtualizada,
                        roleRequisitante: UserRole.admin,
                      );

                      if (!res.sucesso) {
                        setModalState(() {
                          mensagemErroValidacao = res.mensagemErro;
                        });
                        return;
                      }
                    } else {
                      final res = await _viagemService.criarHorarioViagem(
                        data: _dataSelecionada,
                        horario: controllerHorario.text.trim(),
                        motoristaId: '',
                        motoristaNome: '',
                        cidadeDestino: controllerDestino.text.trim(),
                        passageiros: passageirosTemp,
                        observacoes: controllerObs.text.trim(),
                        roleRequisitante: UserRole.admin,
                      );

                      if (!res.sucesso) {
                        setModalState(() {
                          mensagemErroValidacao = res.mensagemErro;
                        });
                        return;
                      }
                    }

                    if (context.mounted) {
                      final idsNovos = passageirosTemp
                          .where((p) => p.statusEmbarque == 0)
                          .map((p) => p.pacienteId)
                          .toSet();
                      if (idsNovos.isNotEmpty) {
                        _pacientesCadastrados = _pacientesCadastrados.map((pac) {
                          if (idsNovos.contains(pac.id)) {
                            return pac.copyWith(
                              status: 0,
                              prontoRetorno: false,
                              limparJanelaReversao: true,
                            );
                          }
                          return pac;
                        }).toList();
                      }
                      Navigator.of(ctx).pop();
                      _atualizarViagensDoDia();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            eEdicao ? 'Horário atualizado com sucesso!' : 'Novo Horário criado com sucesso!',
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  child: Text(eEdicao ? 'Salvar Alterações' : 'Criar Horário'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<PassageiroViagemModel?> _abrirModalSelecionarPassageiro({
    required int ordemSugerida,
    required String cidadeSugerida,
  }) async {
    final primeiroPac = _pacientesCadastrados.firstOrNull;
    String? pacienteIdSelecionado = primeiroPac?.id;
    final controllerOrigem = TextEditingController(
      text: (primeiroPac != null && primeiroPac.enderecoPaciente.trim().isNotEmpty)
          ? primeiroPac.enderecoPaciente.trim()
          : 'UBS Central Poloni',
    );
    final controllerDestino = TextEditingController(
      text: (primeiroPac != null && primeiroPac.localConsulta.trim().isNotEmpty)
          ? primeiroPac.localConsulta.trim()
          : cidadeSugerida,
    );
    final controllerHorarioConsulta = TextEditingController(
      text: (primeiroPac != null && primeiroPac.horarioConsulta.trim().isNotEmpty)
          ? primeiroPac.horarioConsulta.trim()
          : '09:00',
    );
    final controllerAcompNome = TextEditingController(
      text: primeiroPac?.nomeAcompanhante ?? '',
    );
    final controllerObs = TextEditingController();

    return showDialog<PassageiroViagemModel>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSubModalState) {
            final pacienteObj = _pacientesCadastrados
                    .where((p) => p.id == pacienteIdSelecionado)
                    .firstOrNull ??
                (_pacientesCadastrados.isNotEmpty ? _pacientesCadastrados.first : null);

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: const Text('Adicionar Passageiro ao Horário'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seletor de Paciente (pessoas já cadastradas, sem recadastrar)
                      DropdownButtonFormField<String>(
                        key: const Key('dropdownSelecionarPaciente'),
                        isExpanded: true,
                        initialValue: pacienteIdSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Selecione o Paciente *',
                          isDense: true,
                        ),
                        items: _pacientesCadastrados.map((pac) {
                          final doc = pac.cpf.isNotEmpty ? 'CPF: ${pac.cpf}' : 'Sem CPF';
                          return DropdownMenuItem(
                            value: pac.id,
                            child: Text(
                              '${pac.nome} ($doc)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSubModalState(() {
                              pacienteIdSelecionado = val;
                              final novoP = _pacientesCadastrados.firstWhere((p) => p.id == val);
                              controllerAcompNome.text = novoP.nomeAcompanhante ?? '';
                              if (novoP.horarioConsulta.trim().isNotEmpty) {
                                controllerHorarioConsulta.text = novoP.horarioConsulta.trim();
                              }
                              if (novoP.localConsulta.trim().isNotEmpty) {
                                controllerDestino.text = novoP.localConsulta.trim();
                              }
                              if (novoP.enderecoPaciente.trim().isNotEmpty) {
                                controllerOrigem.text = novoP.enderecoPaciente.trim();
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Nome do Acompanhante (opcional)
                      TextField(
                        key: const Key('campoAcompanhanteNome'),
                        controller: controllerAcompNome,
                        decoration: const InputDecoration(
                          labelText: 'Acompanhante (Opcional - ocupa +1 vaga)',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Horário da Consulta
                      TextField(
                        key: const Key('campoHorarioConsulta'),
                        controller: controllerHorarioConsulta,
                        decoration: const InputDecoration(
                          labelText: 'Horário do Atendimento Médico *',
                          hintText: 'Ex.: 09:30',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Origem
                      TextField(
                        controller: controllerOrigem,
                        decoration: const InputDecoration(
                          labelText: 'Local de Embarque / Origem *',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Destino
                      TextField(
                        controller: controllerDestino,
                        decoration: const InputDecoration(
                          labelText: 'Destino / Local de Atendimento *',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Obs
                      TextField(
                        controller: controllerObs,
                        decoration: const InputDecoration(
                          labelText: 'Observações (Cadeirante, Jejum, etc.)',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  key: const Key('botaoConfirmarPassageiro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (pacienteObj == null) return;
                    final passageiro = PassageiroViagemModel(
                      pacienteId: pacienteObj.id,
                      pacienteNome: pacienteObj.nome,
                      pacienteCpf: pacienteObj.cpf,
                      pacienteTelefone: pacienteObj.telefone.trim().isNotEmpty
                          ? pacienteObj.telefone.trim()
                          : null,
                      acompanhanteNome: controllerAcompNome.text.trim().isNotEmpty
                          ? controllerAcompNome.text.trim()
                          : null,
                      localOrigem: controllerOrigem.text.trim(),
                      localDestino: controllerDestino.text.trim(),
                      horarioAtendimento: controllerHorarioConsulta.text.trim(),
                      ordemEmbarque: ordemSugerida,
                      observacoes: controllerObs.text.trim(),
                    );
                    Navigator.of(ctx).pop(passageiro);
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _abrirModalReordenarPassageiros(ViagemModel viagem) async {
    final passageirosReordenaveis = List<PassageiroViagemModel>.from(viagem.passageiros);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setReorderState) {
            final tamanhoTela = MediaQuery.sizeOf(ctx);
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(
                'Reordenar Embarque - ${viagem.tituloHorario}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              content: SizedBox(
                width: (tamanhoTela.width - 88).clamp(200.0, 500.0),
                height: (tamanhoTela.height * 0.5).clamp(220.0, 400.0),
                child: ReorderableListView(
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    setReorderState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = passageirosReordenaveis.removeAt(oldIndex);
                      passageirosReordenaveis.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int i = 0; i < passageirosReordenaveis.length; i++)
                      ListTile(
                        key: ValueKey('itemPassageiroReorder_${passageirosReordenaveis[i].pacienteId}_$i'),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          child: Text('${i + 1}'),
                        ),
                        title: Text(
                          passageirosReordenaveis[i].pacienteNome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Destino: ${passageirosReordenaveis[i].localDestino} (${passageirosReordenaveis[i].horarioAtendimento})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.drag_handle),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  key: const Key('botaoSalvarReordenacao'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await _viagemService.reordenarPassageiros(
                      viagem.id,
                      passageirosReordenaveis,
                      roleRequisitante: UserRole.admin,
                    );
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      _atualizarViagensDoDia();
                    }
                  },
                  child: const Text('Salvar Nova Ordem'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _abrirModalDuplicarHorarios() async {
    DateTime dataOrigem = _dataSelecionada.subtract(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDupState) {
            final viagensOrigem = _viagemService.obterViagensPorData(dataOrigem);

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: const Text('Duplicar Grade de Horários'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecione o dia de origem para copiar os horários, veículos, motoristas e passageiros para o dia selecionado:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        leading: const Icon(Icons.calendar_today, color: Color(0xFF0F172A)),
                        title: Text(
                          'Data de Origem: ${_formatarDataBrasileira(dataOrigem)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${viagensOrigem.length} Horário(s) encontrados nesta data'),
                        trailing: const Icon(Icons.edit_calendar),
                        onTap: () async {
                          final escolhida = await showDatePicker(
                            context: context,
                            initialDate: dataOrigem,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (escolhida != null) {
                            setDupState(() {
                              dataOrigem = DateTime(escolhida.year, escolhida.month, escolhida.day);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Destino da Cópia: ${_formatarDataBrasileira(_dataSelecionada)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  key: const Key('botaoConfirmarDuplicacao'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: viagensOrigem.isEmpty
                      ? null
                      : () async {
                          await _viagemService.duplicarViagensDeOutroDia(
                            dataOrigem: dataOrigem,
                            dataDestino: _dataSelecionada,
                            roleRequisitante: UserRole.admin,
                          );
                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            _atualizarViagensDoDia();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${viagensOrigem.length} Horário(s) duplicados com sucesso!',
                                ),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        },
                  child: const Text('Confirmar Duplicação'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarCancelamentoHorario(ViagemModel viagem) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Cancelar Horário de Saída?'),
          content: SingleChildScrollView(
            child: Text(
              'Tem certeza que deseja cancelar o Horário "${viagem.tituloHorario}" para ${viagem.cidadeDestino}?\n\n'
              'Isso invalidará quaisquer códigos de acesso emitidos e atualizará a grade diária sem apagar o histórico de auditoria (exclusão lógica).',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              key: const Key('botaoConfirmarCancelamentoDialog'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sim, Cancelar Horário'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await _viagemService.cancelarOuExcluirHorarioViagem(
        viagem.id,
        softDelete: true,
        roleRequisitante: UserRole.admin,
      );
      if (mounted) {
        _atualizarViagensDoDia();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horário cancelado com sucesso.'),
            backgroundColor: Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  /// Menu lateral deslizante (Drawer) contendo todos os módulos administrativos
  Widget _construirMenuLateral(BuildContext context) {
    return Drawer(
      key: const Key('menuLateralAdmin'),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            color: const Color(0xFF0F172A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 34,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'TransSaúde Municipal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PAINEL DO ADMINISTRADOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  key: const Key('menuItemHorarios'),
                  leading: const Icon(Icons.schedule, color: Color(0xFF0284C7)),
                  title: const Text(
                    'Gerenciador de Horários',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  subtitle: const Text('Escala e grade diária de viagens'),
                  selected: true,
                  selectedTileColor: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  key: const Key('menuItemGestaoPessoas'),
                  leading: const Icon(Icons.people_alt_outlined, color: Color(0xFF334155)),
                  title: const Text(
                    'Gestão de Pessoas',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Pacientes, Motoristas e Admins'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ListaPessoas()),
                    );
                  },
                ),
                ListTile(
                  key: const Key('menuItemGestaoVeiculos'),
                  leading: const Icon(Icons.directions_car_outlined, color: Color(0xFF334155)),
                  title: const Text(
                    'Gestão de Veículos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Controle da frota municipal'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const Veiculos()),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('botaoLogoutAdminCorpo'),
            leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
            title: const Text(
              'Encerrar Sessão',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await _authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
