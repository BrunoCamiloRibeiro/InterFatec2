import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'components/card_identificacao_paciente.dart';
import 'models/admin_model.dart';
import 'models/motorista_model.dart';
import 'models/paciente_model.dart';

/// ============================================================================
/// VIEWMODEL POLIMÓRFICO: PESSOA ITEM
/// ============================================================================
/// Normaliza entidades distintas (PacienteModel, MotoristaModel, AdminModel) em
/// uma única estrutura de apresentação para a interface, eliminando código
/// duplicado, contadores paralelos e múltiplos loops de renderização.
class PessoaItem {
  /// Identificador único da pessoa (utilizado como chave do documento no Firestore)
  final String id;

  /// Nome completo da pessoa cadastrada
  final String nome;

  /// Cadastro de Pessoa Física (CPF) formatado
  final String cpf;

  /// Telefone principal de contato
  final String telefone;

  /// Papel de acesso no sistema ('paciente', 'motorista' ou 'admin')
  final String role;

  /// Texto exibido na etiqueta/badge do card (ex: "Paciente", "Motorista", "Administrador")
  final String badgeLabel;

  /// Cor temática do badge baseada no papel da pessoa
  final Color badgeCor;

  /// Status de agendamento ou transporte (consumido de PacienteModel.dadosStatus)
  final int status;

  /// Detalhe contextual complementar (ex: local da consulta médica, modelo/placa do veículo ou e-mail)
  final String? detalheExtra;

  /// Indicador de situação cadastral para suporte a exclusão lógica (LGPD/Auditoria)
  final bool ativo;

  const PessoaItem({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.telefone,
    required this.role,
    required this.badgeLabel,
    required this.badgeCor,
    this.status = 0,
    this.detalheExtra,
    this.ativo = true,
  });

  /// Construtor fábrica para converter uma instância de [PacienteModel] em [PessoaItem]
  factory PessoaItem.fromPaciente(PacienteModel p) => PessoaItem(
    id: p.id,
    nome: p.nome,
    cpf: p.cpf,
    telefone: p.telefone,
    role: p.role,
    badgeLabel: 'Paciente',
    badgeCor: const Color(0xFF2563EB),
    status: p.status,
    detalheExtra: p.localConsulta.isNotEmpty
        ? 'Consulta: ${p.localConsulta}'
        : null,
    ativo: p.ativo,
  );

  /// Construtor fábrica para converter uma instância de [MotoristaModel] em [PessoaItem]
  factory PessoaItem.fromMotorista(MotoristaModel m) => PessoaItem(
    id: m.id,
    nome: m.nome,
    cpf: m.cpf,
    telefone: m.telefone,
    role: m.role,
    badgeLabel: 'Motorista',
    badgeCor: const Color(0xFF0F172A),
    status: 0,
    detalheExtra: 'Veículo: ${m.veiculoModelo} (${m.veiculoPlaca})',
    ativo: m.ativo,
  );

  /// Construtor fábrica para converter uma instância de [AdminModel] em [PessoaItem]
  factory PessoaItem.fromAdmin(AdminModel a) => PessoaItem(
    id: a.id,
    nome: a.nome,
    cpf: a.cpf,
    telefone: a.telefone,
    role: a.role,
    badgeLabel: 'Administrador',
    badgeCor: const Color(0xFF7C3AED),
    status: 0,
    detalheExtra: a.email.isNotEmpty ? 'E-mail: ${a.email}' : null,
    ativo: a.ativo,
  );
}

/// ============================================================================
/// TELA DE GESTÃO DE PESSOAS (CRUD - ISSUE #34)
/// ============================================================================
/// Centraliza a consulta, filtragem por perfil, busca reativa por nome/CPF
/// e exclusão lógica de Pacientes, Motoristas e Administradores.
///
/// Padrões de Arquitetura e Boas Práticas Adotados:
/// 1. Consumo em tempo real do Cloud Firestore (coleção 'usuarios').
/// 2. Reciclagem de memória e virtualização de lista com [ListView.builder].
/// 3. Filtragem fora da árvore de renderização (event-driven no [build]).
/// 4. Desacoplamento entre os diálogos de interface e as mutações de estado.
/// 5. Padronização visual com motorista.dart e paciente.dart (fundo branco, AppBar oficial).
class ListaPessoas extends StatefulWidget {
  /// Lista opcional de pacientes para testes de widget ou execução sem backend
  final List<PacienteModel>? mockPacientes;

  /// Lista opcional de motoristas para testes de widget ou execução sem backend
  final List<MotoristaModel>? mockMotoristas;

  /// Lista opcional de administradores para testes de widget ou execução sem backend
  final List<AdminModel>? mockAdmins;

  /// Stream customizada para injeção de dependência em testes automatizados
  final Stream<List<PessoaItem>>? streamOverride;

  const ListaPessoas({
    super.key,
    this.mockPacientes,
    this.mockMotoristas,
    this.mockAdmins,
    this.streamOverride,
  });

  @override
  State<ListaPessoas> createState() => _ListaPessoasState();
}

class _ListaPessoasState extends State<ListaPessoas> {
  /// Controlador do campo de texto de pesquisa
  final TextEditingController _buscaController = TextEditingController();

  /// Papel selecionado para filtragem ('todos', 'paciente', 'motorista' ou 'admin')
  String _filtroRole = 'todos';

  /// Termo de busca normalizado em caixa baixa para comparação case-insensitive
  String _termoBusca = '';

  /// Inscrição ativa no stream do Firestore (cancelada no [dispose])
  StreamSubscription<List<PessoaItem>>? _inscricaoUsuarios;

  /// Coleção principal de todas as pessoas carregadas
  List<PessoaItem> _todasPessoas = [];

  /// Coleção pré-filtrada que alimenta diretamente o [ListView.builder]
  List<PessoaItem> _pessoasFiltradas = [];

  /// Contadores consolidados calculados em passada única
  int _totalPacientes = 0;
  int _totalMotoristas = 0;
  int _totalAdmins = 0;

  /// Mensagem de erro descritiva para exibição de alerta em caso de falhas
  String? _erroGeral;

  /// Bloqueia interações concorrentes durante requisições assíncronas
  bool _salvando = false;

  /// Indica se a tela ainda está aguardando o primeiro carregamento de dados
  bool _carregando = true;

  /// Verifica se o Firebase foi inicializado nesta sessão do aplicativo
  bool _isFirebaseDisponivel() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();

    // Identifica se dados mockados foram explicitamente fornecidos (comum em testes)
    final temMockExplicitamente =
        widget.mockPacientes != null ||
        widget.mockMotoristas != null ||
        widget.mockAdmins != null;

    // Inicialização síncrona com dados de fallback/testes
    final pacientesIniciais =
        widget.mockPacientes ??
        (temMockExplicitamente
            ? <PacienteModel>[]
            : [
                PacienteModel(
                  id: 'pac_1',
                  nome: 'Maria Silva Santos',
                  cpf: '123.456.789-00',
                  telefone: '(14) 99876-5432',
                  enderecoPaciente: 'Rua das Flores, 123',
                  localConsulta: 'Hospital de Base',
                  status: 0,
                ),
                PacienteModel(
                  id: 'pac_2',
                  nome: 'Carlos Eduardo Oliveira',
                  cpf: '234.567.890-11',
                  telefone: '(14) 99123-4567',
                  enderecoPaciente: 'Av. Brasil, 450',
                  localConsulta: 'AME Bauru',
                  status: 1,
                ),
              ]);

    final motoristasIniciais =
        widget.mockMotoristas ??
        (temMockExplicitamente
            ? <MotoristaModel>[]
            : [
                MotoristaModel(
                  id: 'mot_1',
                  nome: 'João de Deus Pereira',
                  cpf: '456.789.012-33',
                  telefone: '(14) 99777-8899',
                  email: 'joao@saude.sp.gov.br',
                  cnh: '01234567890',
                  veiculoModelo: 'Chevrolet Spin',
                  veiculoPlaca: 'BRA2E19',
                ),
              ]);

    final adminsIniciais =
        widget.mockAdmins ??
        (temMockExplicitamente
            ? <AdminModel>[]
            : [
                AdminModel(
                  id: 'adm_1',
                  nome: 'Dra. Fernanda Vasconcelos',
                  cpf: '678.901.234-55',
                  email: 'fernanda.admin@saude.sp.gov.br',
                  telefone: '(14) 99111-0022',
                  role: 'admin',
                ),
              ]);

    // Unificação na lista polimórfica
    _todasPessoas = [
      ...pacientesIniciais.map(PessoaItem.fromPaciente),
      ...motoristasIniciais.map(PessoaItem.fromMotorista),
      ...adminsIniciais.map(PessoaItem.fromAdmin),
    ];
    _atualizarFiltros();
    _carregando = false;

    // Listener para reagir à digitação de busca do usuário
    _buscaController.addListener(() {
      final novoTermo = _buscaController.text.trim().toLowerCase();
      if (novoTermo != _termoBusca) {
        setState(() {
          _termoBusca = novoTermo;
          _atualizarFiltros();
        });
      }
    });

    // Inicia a sincronização com o banco de dados remoto
    _iniciarEscutaFirebase();
  }

  /// Conecta e escuta as mudanças em tempo real na coleção 'usuarios' do Firestore
  void _iniciarEscutaFirebase() {
    // Permite injeção de stream externa para testes de integração
    if (widget.streamOverride != null) {
      _inscricaoUsuarios = widget.streamOverride!.listen((pessoas) {
        if (!mounted) return;
        setState(() {
          _todasPessoas = pessoas;
          _carregando = false;
          _atualizarFiltros();
        });
      });
      return;
    }

    if (_isFirebaseDisponivel()) {
      _inscricaoUsuarios = FirebaseFirestore.instance
          .collection('usuarios')
          .snapshots()
          .map((snapshot) {
            final lista = <PessoaItem>[];
            for (final doc in snapshot.docs) {
              try {
                final dados = doc.data();

                // Respeita a regra de exclusão lógica (ignora inativados)
                final ativo = dados['ativo'];
                if (ativo == false || ativo == 'false') continue;

                final rawRole = dados['role'];
                final role = (rawRole != null)
                    ? rawRole.toString().trim().toLowerCase()
                    : 'paciente';

                // Converte o documento bruto do Firestore no modelo adequado
                if (role == 'admin' || role == 'administrador') {
                  final admin = AdminModel.fromMap(dados, docId: doc.id);
                  lista.add(PessoaItem.fromAdmin(admin));
                } else if (role == 'motorista') {
                  final motorista = MotoristaModel.fromMap(dados, docId: doc.id);
                  lista.add(PessoaItem.fromMotorista(motorista));
                } else {
                  final paciente = PacienteModel.fromMap(dados, docId: doc.id);
                  lista.add(PessoaItem.fromPaciente(paciente));
                }
              } catch (e) {
                // Previne que um registro com formato corrompido quebre toda a listagem
                debugPrint('Aviso: documento ${doc.id} ignorado: $e');
              }
            }
            return lista;
          })
          .listen(
            (pessoas) {
              if (!mounted) return;
              setState(() {
                // Atualiza a lista caso o Firestore possua registros
                if (pessoas.isNotEmpty) {
                  _todasPessoas = pessoas;
                }
                _carregando = false;
                _erroGeral = null;
                _atualizarFiltros();
              });
            },
            onError: (dynamic erro) {
              if (!mounted) return;
              final msg = erro != null ? erro.toString() : 'Erro de conexão';
              setState(() {
                _erroGeral = 'Falha ao sincronizar com o banco: $msg';
                _carregando = false;
              });
            },
          );
    }
  }

  @override
  void dispose() {
    // Libera a inscrição do stream para evitar vazamentos de memória (memory leaks)
    _inscricaoUsuarios?.cancel();
    // Descarta o controlador de texto
    _buscaController.dispose();
    super.dispose();
  }

  /// Executa a contagem e a filtragem unificadas em uma única passada O(N)
  /// eliminando iterações repetidas e cálculos concorrentes dentro do build
  void _atualizarFiltros() {
    int pacientes = 0;
    int motoristas = 0;
    int admins = 0;
    final filtrados = <PessoaItem>[];

    for (final p in _todasPessoas) {
      // 1. Contabiliza totais consolidados por papel em passada única
      if (p.role == 'paciente') {
        pacientes++;
      } else if (p.role == 'motorista') {
        motoristas++;
      } else if (p.role == 'admin' || p.role == 'administrador') {
        admins++;
      }

      // 2. Aplica filtro de papel da aba selecionada
      final correspondeAba = switch (_filtroRole) {
        'todos' => true,
        'paciente' => p.role == 'paciente',
        'motorista' => p.role == 'motorista',
        'admin' => p.role == 'admin' || p.role == 'administrador',
        _ => true,
      };

      if (!correspondeAba) continue;

      // 3. Aplica filtro textual de busca por Nome ou CPF
      if (_termoBusca.isNotEmpty &&
          !p.nome.toLowerCase().contains(_termoBusca) &&
          !p.cpf.contains(_termoBusca)) {
        continue;
      }

      filtrados.add(p);
    }

    _totalPacientes = pacientes;
    _totalMotoristas = motoristas;
    _totalAdmins = admins;
    _pessoasFiltradas = filtrados;
  }

  /// Diálogo puro de confirmação: apresenta as justificativas de governança e auditoria
  Future<bool?> _mostrarConfirmacaoInativacao(String nome) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text(
              'Inativar Registro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja inativar $nome?\n\n'
          'Conforme as regras de governança e auditoria, o registro ficará indisponível para novos agendamentos.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Inativação'),
          ),
        ],
      ),
    );
  }

  /// Executa o fluxo de inativação lógica no Firestore e atualiza o estado local
  Future<void> _aoInativar(PessoaItem pessoa) async {
    final confirmado = await _mostrarConfirmacaoInativacao(pessoa.nome);
    if (confirmado == true && mounted) {
      setState(() {
        _salvando = true;
      });

      // Aplica a exclusão lógica no Cloud Firestore (ativo = false)
      if (_isFirebaseDisponivel()) {
        try {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(pessoa.id)
              .update({'ativo': false});
        } catch (e) {
          if (mounted) {
            setState(() {
              _erroGeral = 'Falha ao inativar no Firebase: $e';
            });
          }
        }
      }

      // Atualiza a memória local para resposta visual imediata ao usuário
      setState(() {
        _todasPessoas.removeWhere(
          (p) => p.id == pessoa.id && p.role == pessoa.role,
        );
        _atualizarFiltros();
        _salvando = false;
      });
    }
  }

  /// Constrói o banner de alerta em caso de falha de comunicação ou sincronização
  Widget _construirMensagemErro() {
    if (_erroGeral == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _erroGeral!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o campo de busca com bordas suaves e ícones padronizados
  Widget _construirCampoBusca() {
    return TextField(
      controller: _buscaController,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: Color(0xFF64748B),
        ),
        suffixIcon: _termoBusca.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                onPressed: () => _buscaController.clear(),
              )
            : null,
        hintText: 'Buscar por nome ou CPF...',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Constrói um ChoiceChip individual para a barra de seleção de papéis
  Widget _construirChipFiltro(String role, String label) {
    final ativo = _filtroRole == role;
    return ChoiceChip(
      label: Text(label),
      selected: ativo,
      selectedColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: ativo ? Colors.white : const Color(0xFF475569),
        fontWeight: ativo ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {
          _filtroRole = role;
          _atualizarFiltros();
        });
      },
    );
  }

  /// Constrói a linha horizontal de abas de filtro com contadores automáticos
  Widget _construirBarraFiltros({
    required int totalGeral,
    required int totalPacientes,
    required int totalMotoristas,
    required int totalAdmins,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _construirChipFiltro('todos', 'Todos ($totalGeral)'),
          const SizedBox(width: 8),
          _construirChipFiltro('paciente', 'Pacientes ($totalPacientes)'),
          const SizedBox(width: 8),
          _construirChipFiltro('motorista', 'Motoristas ($totalMotoristas)'),
          const SizedBox(width: 8),
          _construirChipFiltro('admin', 'Administradores ($totalAdmins)'),
        ],
      ),
    );
  }

  /// Constrói o estado vazio amigável quando nenhum registro atende aos critérios
  Widget _construirEstadoVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhuma pessoa encontrada',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tente buscar com outro nome ou número de CPF.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói a lista virtualizada de cards reaproveitando [CardIdentificacaoPaciente]
  Widget _construirListaPessoas() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pessoasFiltradas.isEmpty) {
      return _construirEstadoVazio();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _pessoasFiltradas.length,
      itemBuilder: (context, index) {
        final pessoa = _pessoasFiltradas[index];
        return Padding(
          // Chave composta para garantir unicidade absoluta entre diferentes papéis
          key: ValueKey('${pessoa.role}_${pessoa.id}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: CardIdentificacaoPaciente(
            nome: pessoa.nome,
            cpf: pessoa.cpf,
            status: pessoa.status,
            labelBadge: pessoa.badgeLabel,
            corBadge: pessoa.badgeCor,
            telefone: pessoa.telefone,
            detalheExtra: pessoa.detalheExtra,
            onEditar: () {},
            onInativar: () => _aoInativar(pessoa),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fundo branco padronizado com o tema de motorista.dart e paciente.dart
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Retorna à tela anterior ou navega para a rota raiz
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
        title: const Text('Gestão de Pessoas'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _salvando
            ? null
            : () {
                // TODO: Abrir formulário de cadastro de pessoas
              },
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Novo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner de alerta de erros
              _construirMensagemErro(),

              // Campo de entrada de busca
              _construirCampoBusca(),
              const SizedBox(height: 12),

              // Barra de filtros por categoria com rolagem horizontal
              _construirBarraFiltros(
                totalGeral: _todasPessoas.length,
                totalPacientes: _totalPacientes,
                totalMotoristas: _totalMotoristas,
                totalAdmins: _totalAdmins,
              ),
              const SizedBox(height: 14),

              // Área de listagem virtualizada de pessoas
              Expanded(child: _construirListaPessoas()),
            ],
          ),
        ),
      ),
    );
  }
}
