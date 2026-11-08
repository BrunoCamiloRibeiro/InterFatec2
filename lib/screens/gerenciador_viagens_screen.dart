// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/screens/gerenciador_viagens_screen.dart
// Camada: Apresentação / Telas Administrativas (Screens / UI)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa o painel de Gerenciamento Diário de Viagens e Grade de Horários
// ("Gerenciador do Dia" / "Horários de Saída") acessível exclusivamente pelo
// Administrador do sistema de saúde (TFD). Permite ao gestor:
// 1) Selecionar qualquer data com navegação dia a dia e seletor de calendário;
// 2) Visualizar os indicadores consolidados (total de horários, ativos, assentos);
// 3) Filtrar a grade por texto (cidade, motorista, veículo) e por status;
// 4) Criar novos Horários com validação rigorosa de conflitos (veículo, condutor,
//    capacidade de assentos, consultas prévias e pacientes simultâneos);
// 5) Vincular passageiros e acompanhantes a partir das pessoas cadastradas;
// 6) Reordenar o itinerário de embarque (ordem 1..N);
// 7) Duplicar a escala completa de viagens de outro dia para agilizar o trabalho;
// 8) Cancelar horários com exclusão lógica segura e invalidação de credenciais;
// 9) Oferecer layout 100% responsivo para celular (360dp) e desktop.
//
// VOCABULÁRIO ADOTADO:
// Em estrita conformidade com a especificação, as viagens são apresentadas na
// interface exclusivamente sob o vocabulário "Horário" (ex.: "Horário de Saída",
// "Grade de Horários", "Novo Horário", "Duplicar Horários").
//
// ONDE É USADO NO PROJETO:
// - lib/routes/route_guard.dart (rota protegida '/gerenciador-horarios' e '/administrativo')
// - lib/screens/admin_placeholder_screen.dart (incorporado como painel principal)
// - test/gerenciador_viagens_test.dart (testes funcionais e de regras de borda)
// - test/screens/gerenciador_viagens_mobile_web_test.dart (testes de responsividade)
// ============================================================================

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subFirestoreVeiculos;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subFirestoreUsuarios;

  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<ViagemModel> _todasViagensDoDia = [];
  List<VeiculoModel> _veiculosCadastrados = [];
  List<MotoristaModel> _motoristasCadastrados = [];
  List<PacienteModel> _pacientesCadastrados = [];

  String _filtroTexto = '';
  String _filtroStatus = 'todos'; // todos, planejada, ativa, concluida, cancelada

  final bool _carregando = false;

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
  }

  @override
  void dispose() {
    _subViagens?.cancel();
    _subVeiculos?.cancel();
    _subFirestoreVeiculos?.cancel();
    _subFirestoreUsuarios?.cancel();
    super.dispose();
  }

  void _inicializarDadosBasePessoasEVeiculos() {
    _veiculosCadastrados = List<VeiculoModel>.from(
      widget.veiculosIniciais ?? _viagemService.todosVeiculos,
    );
    _motoristasCadastrados = List<MotoristaModel>.from(
      widget.motoristasIniciais ?? const <MotoristaModel>[],
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
          final motoristas = <MotoristaModel>[];
          final pacientes = <PacienteModel>[];
          for (final doc in snapshot.docs) {
            final dados = doc.data();
            final ativo = dados['ativo'];
            final status = dados['status']?.toString().toLowerCase().trim();
            final situacao = dados['situacao']?.toString().toLowerCase().trim();
            if (ativo == false ||
                ativo == 'false' ||
                status == 'inativo' ||
                situacao == 'inativo' ||
                status == 'excluido' ||
                situacao == 'excluido') {
              continue;
            }
            final role = (dados['role'] ?? dados['tipo'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            if (role == 'motorista') {
              motoristas.add(MotoristaModel.fromMap(dados, docId: doc.id));
            } else if (role == 'paciente' || role.isEmpty) {
              pacientes.add(PacienteModel.fromMap(dados, docId: doc.id));
            }
          }
          setState(() {
            _motoristasCadastrados = motoristas;
            _pacientesCadastrados = pacientes;
          });
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
        if (_filtroStatus == 'planejada' && !v.isPlanejada) return false;
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
    final totalPlanejados = _todasViagensDoDia.where((v) => v.isPlanejada).length;
    final totalConcluidos = _todasViagensDoDia.where((v) => v.isConcluida).length;
    final totalCancelados = _todasViagensDoDia.where((v) => v.isCancelada).length;

    int assentosOcupados = 0;
    int assentosTotais = 0;
    for (final v in _todasViagensDoDia.where((v) => !v.isCancelada)) {
      assentosOcupados += v.totalAssentosOcupados;
      final veic = _veiculosCadastrados.firstWhere(
        (ve) => ve.id == v.veiculoId,
        orElse: () => VeiculoModel(
          id: v.veiculoId,
          placa: v.veiculoPlaca,
          modelo: v.veiculoModelo,
          capacidade: 0,
          quilometragemAtual: 0,
        ),
      );
      assentosTotais += veic.capacidade;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _construirMenuLateral(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              if (_carregando)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (viagensExibicao.isEmpty)
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: cor),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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

  Widget _construirCardHorario(ViagemModel viagem) {
    Color corBadge;
    String textoBadge;
    switch (viagem.status.toLowerCase()) {
      case 'ativa':
        corBadge = const Color(0xFF059669);
        textoBadge = 'EM TRÂNSITO (ATIVA)';
        break;
      case 'concluida':
      case 'encerrada':
        corBadge = const Color(0xFF475569);
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

    final veic = _veiculosCadastrados.firstWhere(
      (v) => v.id == viagem.veiculoId,
      orElse: () => VeiculoModel(
        id: viagem.veiculoId,
        placa: viagem.veiculoPlaca,
        modelo: viagem.veiculoModelo,
        capacidade: 0,
        quilometragemAtual: 0,
      ),
    );

    final capacidade = veic.capacidade > 0 ? veic.capacidade : 7;
    final totalOcupados = viagem.totalAssentosOcupados;
    final lotacaoUltrapassada = totalOcupados > capacidade;

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
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: corBadge,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    textoBadge,
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Motorista: ${viagem.motoristaNome}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
                Text(
                  'Veículo: ${viagem.veiculoPlaca} (${viagem.veiculoModelo})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: lotacaoUltrapassada ? Colors.red.shade100 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Assentos: $totalOcupados / $capacidade',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: lotacaoUltrapassada ? Colors.red.shade800 : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
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
            const Divider(height: 16),

            // Lista de passageiros
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Passageiros Agendados (${viagem.passageiros.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Total de Vagas Ocupadas: $totalOcupados',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 8),

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
              ...viagem.passageiros.map((p) => _construirItemPassageiro(p)),
          ],
        ),
      ),
    ),
  );
}

  Widget _construirItemPassageiro(PassageiroViagemModel passageiro) {
    final temAcompanhante = passageiro.acompanhanteNome != null &&
        passageiro.acompanhanteNome!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge com a ordem de embarque
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#${passageiro.ordemEmbarque}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Informações do paciente e acompanhante
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passageiro.pacienteNome,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (temAcompanhante)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, size: 13, color: Color(0xFF0284C7)),
                        const SizedBox(width: 4),
                        Text(
                          'Acompanhante: ${passageiro.acompanhanteNome}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Origem: ${passageiro.localOrigem}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      'Destino: ${passageiro.localDestino}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    if (passageiro.horarioAtendimento.isNotEmpty)
                      Text(
                        'Consulta: ${passageiro.horarioAtendimento}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                  ],
                ),
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
      text: viagemExistente?.nomeHorario ?? '06:00 - Saída Matutina',
    );
    final controllerDestino = TextEditingController(
      text: viagemExistente?.cidadeDestino ?? 'SÃO JOSÉ DO RIO PRETO',
    );
    final controllerObs = TextEditingController(
      text: viagemExistente?.observacoes ?? '',
    );

    String? veiculoId = _veiculosCadastrados.any((v) => v.id == viagemExistente?.veiculoId)
        ? viagemExistente!.veiculoId
        : (_veiculosCadastrados.isNotEmpty ? _veiculosCadastrados.first.id : null);
    String? motoristaId = _motoristasCadastrados.any((m) => m.id == viagemExistente?.motoristaId)
        ? viagemExistente!.motoristaId
        : (_motoristasCadastrados.isNotEmpty ? _motoristasCadastrados.first.id : null);

    List<PassageiroViagemModel> passageirosTemp = viagemExistente != null
        ? List<PassageiroViagemModel>.from(viagemExistente.passageiros)
        : [];

    String? mensagemErroValidacao;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final veiculoSelecionado = _veiculosCadastrados
                    .where((v) => v.id == veiculoId)
                    .firstOrNull ??
                (_veiculosCadastrados.isNotEmpty ? _veiculosCadastrados.first : null);
            final motoristaSelecionado = _motoristasCadastrados
                    .where((m) => m.id == motoristaId)
                    .firstOrNull ??
                (_motoristasCadastrados.isNotEmpty ? _motoristasCadastrados.first : null);

            final totalAssentos =
                passageirosTemp.fold<int>(0, (acc, p) => acc + p.assentosOcupados);
            final capacidade = veiculoSelecionado?.capacidade ?? 0;

            return AlertDialog(
              title: Text(eEdicao ? 'Editar Horário' : 'Novo Horário de Saída'),
              content: SizedBox(
                width: 600,
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

                      // Horário / Nome
                      TextField(
                        key: const Key('campoNomeHorario'),
                        controller: controllerHorario,
                        decoration: const InputDecoration(
                          labelText: 'Horário / Nome de Saída *',
                          hintText: 'Ex.: 06:00 - Barretos (Hospital de Amor)',
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

                      // Dropdown de Veículo
                      DropdownButtonFormField<String>(
                        key: const Key('dropdownVeiculo'),
                        isExpanded: true,
                        initialValue: veiculoId,
                        decoration: const InputDecoration(
                          labelText: 'Veículo Municipal *',
                          isDense: true,
                        ),
                        items: _veiculosCadastrados.map((v) {
                          return DropdownMenuItem(
                            value: v.id,
                            child: Text(
                              '${v.placa} - ${v.modelo} (${v.capacidade} assentos)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              veiculoId = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Dropdown de Motorista
                      DropdownButtonFormField<String>(
                        key: const Key('dropdownMotorista'),
                        isExpanded: true,
                        initialValue: motoristaId,
                        decoration: const InputDecoration(
                          labelText: 'Motorista Responsável *',
                          isDense: true,
                        ),
                        items: _motoristasCadastrados.map((m) {
                          return DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              '${m.nome} (CNH: ${m.cnh})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              motoristaId = val;
                            });
                          }
                        },
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
                            'Passageiros (${passageirosTemp.length}) - Lotação: $totalAssentos / $capacidade',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: totalAssentos > capacidade
                                  ? Colors.red
                                  : const Color(0xFF0F172A),
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
                    if (veiculoSelecionado == null || motoristaSelecionado == null || veiculoId == null || motoristaId == null) {
                      setModalState(() {
                        mensagemErroValidacao = 'Selecione um veículo e um motorista cadastrados.';
                      });
                      return;
                    }
                    if (eEdicao) {
                      final viagemAtualizada = viagemExistente.copyWith(
                        nomeHorario: controllerHorario.text.trim(),
                        cidadeDestino: controllerDestino.text.trim(),
                        observacoes: controllerObs.text.trim(),
                        veiculoId: veiculoSelecionado.id,
                        veiculoPlaca: veiculoSelecionado.placa,
                        veiculoModelo: veiculoSelecionado.modelo,
                        motoristaId: motoristaSelecionado.id,
                        motoristaNome: motoristaSelecionado.nome,
                        passageiros: passageirosTemp,
                      );

                      final res = await _viagemService.atualizarHorarioViagem(
                        viagem: viagemAtualizada,
                        capacidadeVeiculo: veiculoSelecionado.capacidade,
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
                        veiculoId: veiculoSelecionado.id,
                        veiculoPlaca: veiculoSelecionado.placa,
                        veiculoModelo: veiculoSelecionado.modelo,
                        capacidadeVeiculo: veiculoSelecionado.capacidade,
                        motoristaId: motoristaSelecionado.id,
                        motoristaNome: motoristaSelecionado.nome,
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
    String? pacienteIdSelecionado = _pacientesCadastrados.isNotEmpty ? _pacientesCadastrados.first.id : null;
    final controllerOrigem = TextEditingController(text: 'UBS Central Poloni');
    final controllerDestino = TextEditingController(text: cidadeSugerida);
    final controllerHorarioConsulta = TextEditingController(text: '09:00');
    final controllerAcompNome = TextEditingController();
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
              title: const Text('Adicionar Passageiro ao Horário'),
              content: SizedBox(
                width: 500,
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
                              if (novoP.nomeAcompanhante != null) {
                                controllerAcompNome.text = novoP.nomeAcompanhante!;
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
            return AlertDialog(
              title: Text('Reordenar Embarque - ${viagem.tituloHorario}'),
              content: SizedBox(
                width: 500,
                height: 400,
                child: ReorderableListView(
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
                        title: Text(passageirosReordenaveis[i].pacienteNome),
                        subtitle: Text(
                          'Destino: ${passageirosReordenaveis[i].localDestino} (${passageirosReordenaveis[i].horarioAtendimento})',
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
              title: const Text('Duplicar Grade de Horários'),
              content: SizedBox(
                width: 480,
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
          title: const Text('Cancelar Horário de Saída?'),
          content: Text(
            'Tem certeza que deseja cancelar o Horário "${viagem.tituloHorario}" para ${viagem.cidadeDestino}?\n\n'
            'Isso invalidará quaisquer códigos de acesso emitidos e atualizará a grade diária sem apagar o histórico de auditoria (exclusão lógica).',
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
