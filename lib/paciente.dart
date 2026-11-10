// ============================================================================
// ARQUIVO: lib/paciente.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa a tela principal do Módulo do Paciente (StatefulWidget "Paciente"),
// concebida no escopo da Issue #18. Apresenta ao passageiro logado as suas
// informações cadastrais essenciais, status da viagem atual, dados completos da
// consulta médica agendada (local, horário, ponto de partida, acompanhante),
// botões de ação rápida ("Estou Pronto" e "Fui embora / Carona") e a área
// reservada para rastreamento veicular em tempo real (CardTrackingPaciente).
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Apresentação / View (Interface do Usuário com Flutter).
//
// ONDE É USADO (REFERÊNCIAS NO REPOSITÓRIO):
// - lib/screens/auth_gate.dart: Renderizado quando o usuário autenticado possui role "paciente".
// - lib/routes/route_guard.dart: Mapeado na rota protegida "/paciente".
// - test/screens/auth_gate_test.dart: Verificação de redirecionamento do paciente.
//
// DE ONDE RECEBE DADOS:
// - Cloud Firestore: coleção "usuarios" (documento individual do paciente ou consulta com limit(1)).
// - lib/models/paciente_model.dart: conversão e modelagem tipada do paciente.
// - Parâmetros opcionais via construtor:
//   - pacienteId: ID do documento para escuta direta.
//   - pacienteStreamOverride: Stream customizada para testes unitários ou emulação de dados.
// - Componentes filhos consumidos:
//   - lib/components/card_identificacao_paciente.dart
//   - lib/components/card_dados_consulta.dart
//   - lib/components/card_tracking_paciente.dart
//
// O QUE EXPORTA / EXPÕE:
// - class Paciente extends StatefulWidget: Widget da tela do paciente.
// - class _PacienteState: Gerenciador de estado e ciclo de vida da tela.
//
// ORIGEM HISTÓRICA:
// Criado pela equipe na Issue #18 (commit 54f018c e estilizado no commit 6553abd).
// Substituiu a implementação prototípica legada que residia em lib/Outdated/paciente.dart.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:cloud_firestore: escuta reativa em tempo real de documentos no Firestore.
// - package:firebase_core: checagem de inicialização das instâncias do Firebase.
// - package:flutter/material.dart: componentes de UI Material Design.
// - Efeitos colaterais: consome conexões de rede ativas via Stream do Firestore.
//
// INCONSISTÊNCIAS / OBSERVAÇÕES TÉCNICAS:
// - Os botões de ação ("Estou Pronto" e "Fui embora") possuem corpos de callback
//   vazios acompanhados de comentários TODO sinalizando a pendência da Issue #19.
// - Quando pacienteId não é informado e o Firebase está online, a busca consome
//   o primeiro paciente cadastrado (.limit(1)), útil para desenvolvimento, mas
//   não segmentado por usuário logado específico.
// ============================================================================
import 'dart:async';

// Importa a biblioteca oficial do Cloud Firestore para acesso ao banco de dados NoSQL
import 'package:cloud_firestore/cloud_firestore.dart';
// Importa o pacote principal do Firebase Core para verificação de inicialização
import 'package:firebase_core/firebase_core.dart';
// Importa a biblioteca de componentes visuais Material Design do Flutter
import 'package:flutter/material.dart';

// Importa o componente visual que exibe os detalhes da consulta agendada
import 'components/card_dados_consulta.dart';
// Importa o componente visual de identificação do paciente com avatar e status
import 'components/card_identificacao_paciente.dart';
// Importa o componente de mapa e rastreamento da viagem em tempo real
import 'components/card_tracking_paciente.dart';
// Importa o modelo de localização dos motoristas em trânsito
import 'models/localizacao_motorista_model.dart';
// Importa o modelo de dados representativo da entidade Paciente
import 'components/banner_reversao_paciente.dart';
import 'models/paciente_model.dart';
import 'models/viagem_model.dart';
import 'services/auth_service.dart';
import 'services/paciente_sync_service.dart';
import 'services/viagem_service.dart';

// Tela principal do Módulo do Paciente (Issue #18)
// Centraliza a identificação, dados da consulta agendada, tracking e botões de ação
// Declaração do StatefulWidget Paciente para a tela do passageiro
class Paciente extends StatefulWidget {
  // Identificador opcional do paciente autenticado
  // Chave de documento no Firestore utilizada para carregar os dados específicos do usuário
  final String? pacienteId;
  // Stream customizada de paciente injetada externamente (útil para testes unitários)
  // Fluxo reativo injetável para testes automatizados sem dependência de backend real
  final Stream<PacienteModel?>? pacienteStreamOverride;
  final PacienteSyncService? syncServiceOverride;
  // Stream customizada de motoristas ativos em trânsito para testes unitários
  final Stream<List<LocalizacaoMotoristaModel>>? motoristasStreamOverride;

  // Construtor constante da classe Paciente que aceita propriedades opcionais de injeção
  const Paciente({
    super.key,
    this.pacienteId,
    this.pacienteStreamOverride,
    this.syncServiceOverride,
    this.motoristasStreamOverride,
  });

  // Sobrescrita que cria o estado mutável associado a este widget
  @override
  // Instancia e retorna a classe de estado privada _PacienteState
  State<Paciente> createState() => _PacienteState();
// Fechamento da classe Paciente
}

// Classe de estado privada que gerencia o ciclo de vida e a construção da UI do paciente
class _PacienteState extends State<Paciente> {
  late final PacienteSyncService _syncService;
  late Stream<PacienteModel?> _pacienteStream;
  StreamSubscription<List<ViagemModel>>? _viagensSub;
  StreamSubscription<({String? viagemId, PacienteModel paciente})>? _syncPorViagemSub;
  StreamSubscription<({String? viagemId, String pacienteId, String mensagem, PacienteModel estadoRevertido})>? _falhasSyncSub;
  bool _processandoAcao = false;

  @override
  void initState() {
    super.initState();
    _syncService = widget.syncServiceOverride ?? PacienteSyncService();
    _pacienteStream = _carregarPaciente();
    _viagensSub = ViagemService().todasViagensStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _syncPorViagemSub = _syncService.alteracoesPorViagemStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _falhasSyncSub = _syncService.falhasPorViagemStream.listen((falha) {
      final idViagem = falha.viagemId;
      if (idViagem != null && idViagem.isNotEmpty) {
        unawaited(
          ViagemService().atualizarStatusPassageiroNaViagem(
            viagemId: idViagem,
            pacienteId: falha.pacienteId,
            novoStatus: falha.estadoRevertido.status,
            prontoRetorno: falha.estadoRevertido.prontoRetorno,
            janelaReversao: falha.estadoRevertido.janelaReversao,
            limparJanelaReversao: falha.estadoRevertido.janelaReversao == null,
            persistirRemoto: false,
          ),
        );
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(falha.mensagem),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
      }
    });
  }

  @override
  void dispose() {
    _viagensSub?.cancel();
    _syncPorViagemSub?.cancel();
    _falhasSyncSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Paciente oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pacienteId != widget.pacienteId ||
        oldWidget.pacienteStreamOverride != widget.pacienteStreamOverride) {
      _pacienteStream = _carregarPaciente();
    }
  }

  Future<void> _solicitarCancelamentoComConfirmacao(PacienteModel paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tem certeza dessa ação?'),
        content: const Text(
          'Deseja realmente informar que foi embora ou pegou carona? '
          'Você terá até 5 minutos para desfazer esta ação antes da consolidação.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB83227),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _processandoAcao = true);
    try {
      final (viagemAtual, _) = _localizarViagemEPassageiro(
        paciente.id,
        cpf: paciente.cpf,
      );
      final idViagem = viagemAtual?.id;
      if (idViagem != null) {
        _syncService.registrarPacienteEmMemoriaSeAusente(
          paciente,
          viagemId: idViagem,
        );
      }
      final key = '${paciente.id}_cancel_${DateTime.now().millisecondsSinceEpoch}';
      final res = await _syncService.solicitarCancelamento(
        pacienteId: paciente.id,
        atorId: paciente.id,
        atorRole: 'paciente',
        viagemId: idViagem,
        idempotencyKey: key,
      );
      if (res.sucesso && idViagem != null) {
        unawaited(
          ViagemService().atualizarStatusPassageiroNaViagem(
            viagemId: idViagem,
            pacienteId: paciente.id,
            novoStatus: res.paciente?.status ?? 5,
            prontoRetorno: res.paciente?.prontoRetorno ?? false,
            janelaReversao: res.paciente?.janelaReversao,
            limparJanelaReversao: res.paciente?.janelaReversao == null,
            persistirRemoto: false,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.mensagem),
          backgroundColor: res.sucesso ? const Color(0xFFB83227) : Colors.black87,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao processar: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processandoAcao = false);
      }
    }
  }

  Future<void> _sinalizarProntoComConfirmacao(PacienteModel paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tem certeza dessa ação?'),
        content: const Text(
          'Deseja avisar ao motorista que sua consulta médica terminou e você está pronto para o retorno? '
          'Você terá até 1 minuto para desfazer este aviso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _processandoAcao = true);
    try {
      final (viagemAtual, _) = _localizarViagemEPassageiro(
        paciente.id,
        cpf: paciente.cpf,
      );
      final idViagem = viagemAtual?.id;
      if (idViagem != null) {
        _syncService.registrarPacienteEmMemoriaSeAusente(
          paciente,
          viagemId: idViagem,
        );
      }
      final key = '${paciente.id}_pronto_${DateTime.now().millisecondsSinceEpoch}';
      final res = await _syncService.sinalizarPronto(
        pacienteId: paciente.id,
        atorId: paciente.id,
        atorRole: 'paciente',
        viagemId: idViagem,
        idempotencyKey: key,
      );
      if (res.sucesso && idViagem != null) {
        unawaited(
          ViagemService().atualizarStatusPassageiroNaViagem(
            viagemId: idViagem,
            pacienteId: paciente.id,
            novoStatus: res.paciente?.status ?? paciente.status,
            prontoRetorno: res.paciente?.prontoRetorno ?? true,
            janelaReversao: res.paciente?.janelaReversao,
            limparJanelaReversao: res.paciente?.janelaReversao == null,
            persistirRemoto: false,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.mensagem),
          backgroundColor: res.sucesso ? const Color(0xFF16A34A) : Colors.black87,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao processar: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processandoAcao = false);
      }
    }
  }

  Future<void> _executarDesfazer(PacienteModel paciente) async {
    final janela = paciente.janelaReversao;
    if (janela == null) return;

    setState(() => _processandoAcao = true);
    try {
      final (viagemAtual, _) = _localizarViagemEPassageiro(
        paciente.id,
        cpf: paciente.cpf,
      );
      final idViagem = viagemAtual?.id;
      if (idViagem != null) {
        _syncService.registrarPacienteEmMemoriaSeAusente(
          paciente,
          viagemId: idViagem,
        );
      }
      final key = '${paciente.id}_undo_${DateTime.now().millisecondsSinceEpoch}';
      final res = (janela.acao == 'cancelamento_carona')
          ? await _syncService.desfazerCancelamento(
              pacienteId: paciente.id,
              atorId: paciente.id,
              atorRole: 'paciente',
              viagemId: idViagem,
              idempotencyKey: key,
            )
          : await _syncService.desfazerPronto(
              pacienteId: paciente.id,
              atorId: paciente.id,
              atorRole: 'paciente',
              viagemId: idViagem,
              idempotencyKey: key,
            );
      if (res.sucesso && idViagem != null && res.paciente != null) {
        unawaited(
          ViagemService().atualizarStatusPassageiroNaViagem(
            viagemId: idViagem,
            pacienteId: paciente.id,
            novoStatus: res.paciente!.status,
            prontoRetorno: res.paciente!.prontoRetorno,
            janelaReversao: res.paciente!.janelaReversao,
            limparJanelaReversao: res.paciente!.janelaReversao == null,
            persistirRemoto: false,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.mensagem),
          backgroundColor: res.sucesso ? const Color(0xFF2563EB) : Colors.black87,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao desfazer: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processandoAcao = false);
      }
    }
  }
  // Verifica se o Firebase foi inicializado
  // Checa a disponibilidade do Firebase para decidir entre backend real ou fallback mockado
  bool _isFirebaseDisponivel() {
    // Tenta acessar a lista de aplicativos Firebase registrados
    try {
      // Retorna verdadeiro caso a lista de instâncias Firebase não esteja vazia
      return Firebase.apps.isNotEmpty;
    // Captura exceções em ambientes de teste sem Firebase inicializado
    } catch (_) {
      // Retorna falso sinalizando a ausência de conexão Firebase
      return false;
    // Fechamento do bloco catch
    }
  // Fechamento do método _isFirebaseDisponivel
  }

  // Localiza a viagem e o passageiro vinculados ao paciente autenticado
  (ViagemModel?, PassageiroViagemModel?) _localizarViagemEPassageiro(
    String pacienteId, {
    String? cpf,
  }) {
    final cpfLimpo = cpf?.replaceAll(RegExp(r'\D'), '') ?? '';
    final viagens = ViagemService().todasViagens;
    final idViagemAuth = FirebaseAuthService.pacienteViagemId?.trim();
    final ordenadas = [
      if (idViagemAuth != null && idViagemAuth.isNotEmpty)
        ...viagens.where((v) => v.id == idViagemAuth),
      ...viagens.where(
        (v) =>
            v.id != idViagemAuth && v.isAtiva && !v.isCancelada && !v.isConcluida,
      ),
      ...viagens.where(
        (v) =>
            v.id != idViagemAuth &&
            v.isPlanejada &&
            !v.isCancelada &&
            !v.isConcluida,
      ),
      ...viagens.where(
        (v) => v.id != idViagemAuth && !v.isAtiva && !v.isPlanejada,
      ),
    ];

    for (final v in ordenadas) {
      for (final p in v.passageiros) {
        if (p.pacienteId == pacienteId) {
          return (v, p);
        }
        if (cpfLimpo.isNotEmpty && p.pacienteCpf != null) {
          final pCpfLimpo = p.pacienteCpf!.replaceAll(RegExp(r'\D'), '');
          if (pCpfLimpo == cpfLimpo) {
            return (v, p);
          }
        }
      }
    }
    return (null, null);
  }

  PacienteModel _enriquecerComDadosViagem(PacienteModel paciente) {
    final (viagemEncontrada, pv) =
        _localizarViagemEPassageiro(paciente.id, cpf: paciente.cpf);
    if (pv == null) return paciente;

    final pMem = viagemEncontrada != null
        ? _syncService.obterPacienteMemoria(
            pv.pacienteId,
            viagemId: viagemEncontrada.id,
          )
        : null;
    final usarEstadoViagem =
        widget.pacienteStreamOverride == null && viagemEncontrada != null;
    final statusEfetivo =
        usarEstadoViagem ? (pMem?.status ?? pv.statusEmbarque) : paciente.status;
    final prontoRetornoEfetivo = usarEstadoViagem
        ? (pMem?.prontoRetorno ?? pv.prontoRetorno)
        : paciente.prontoRetorno;
    final janelaReversaoEfetiva = usarEstadoViagem
        ? (pMem?.janelaReversao ?? pv.janelaReversao)
        : paciente.janelaReversao;

    final localConsultaVazio = paciente.localConsulta.trim().isEmpty ||
        paciente.localConsulta.trim() == 'Local da consulta não informado';
    final localSaidaVazio = paciente.localSaida.trim().isEmpty;
    final horarioVazio = paciente.horarioConsulta.trim().isEmpty;
    final acompNomeVazio =
        paciente.nomeAcompanhante == null || paciente.nomeAcompanhante!.trim().isEmpty;
    final acompTelVazio =
        paciente.telAcompanhante == null || paciente.telAcompanhante!.trim().isEmpty;

    return PacienteModel(
      id: paciente.id,
      nome: (paciente.nome.trim().isEmpty || paciente.nome == 'Paciente sem nome') &&
              pv.pacienteNome.trim().isNotEmpty
          ? pv.pacienteNome.trim()
          : paciente.nome,
      cpf: (paciente.cpf.trim().isEmpty || paciente.cpf == '000.000.000-00') &&
              pv.pacienteCpf != null &&
              pv.pacienteCpf!.trim().isNotEmpty
          ? pv.pacienteCpf!.trim()
          : paciente.cpf,
      telefone: paciente.telefone,
      enderecoPaciente: paciente.enderecoPaciente,
      localConsulta: localConsultaVazio && pv.localDestino.trim().isNotEmpty
          ? pv.localDestino.trim()
          : paciente.localConsulta,
      localSaida: localSaidaVazio && pv.localOrigem.trim().isNotEmpty
          ? pv.localOrigem.trim()
          : paciente.localSaida,
      horarioConsulta: horarioVazio && pv.horarioAtendimento.trim().isNotEmpty
          ? pv.horarioAtendimento.trim()
          : paciente.horarioConsulta,
      status: statusEfetivo,
      nomeAcompanhante: acompNomeVazio &&
              pv.acompanhanteNome != null &&
              pv.acompanhanteNome!.trim().isNotEmpty
          ? pv.acompanhanteNome!.trim()
          : paciente.nomeAcompanhante,
      telAcompanhante: acompTelVazio &&
              pv.acompanhanteTelefone != null &&
              pv.acompanhanteTelefone!.trim().isNotEmpty
          ? pv.acompanhanteTelefone!.trim()
          : paciente.telAcompanhante,
      cpfAcompanhante: paciente.cpfAcompanhante,
      rg: paciente.rg,
      cnh: paciente.cnh,
      role: paciente.role,
      ativo: paciente.ativo,
      criadoEm: paciente.criadoEm,
      prontoRetorno: prontoRetornoEfetivo,
      janelaReversao: janelaReversaoEfetiva,
      ultimaIdempotencyKey: paciente.ultimaIdempotencyKey,
    );
  }

  PacienteModel? _buscarPacienteEmViagem(String docId) {
    final (viagem, pv) = _localizarViagemEPassageiro(docId);
    if (pv == null) return null;
    final pMem = viagem != null
        ? _syncService.obterPacienteMemoria(pv.pacienteId, viagemId: viagem.id)
        : null;
    final modelo = PacienteModel(
      id: pv.pacienteId,
      nome: pv.pacienteNome,
      cpf: pv.pacienteCpf ?? '000.000.000-00',
      telefone: pv.pacienteTelefone ?? 'Telefone não informado',
      enderecoPaciente: 'Endereço não informado',
      localConsulta: pv.localDestino.trim().isNotEmpty
          ? pv.localDestino.trim()
          : 'Local da consulta não informado',
      localSaida: pv.localOrigem.trim(),
      horarioConsulta: pv.horarioAtendimento.trim(),
      status: pMem?.status ?? pv.statusEmbarque,
      nomeAcompanhante: pv.acompanhanteNome,
      telAcompanhante: pv.acompanhanteTelefone,
      prontoRetorno: pMem?.prontoRetorno ?? pv.prontoRetorno,
      janelaReversao: pMem?.janelaReversao ?? pv.janelaReversao,
    );
    if (viagem != null) {
      _syncService.registrarPacienteEmMemoriaSeAusente(
        modelo,
        viagemId: viagem.id,
      );
    }
    return modelo;
  }

  // Retorna a stream de dados do paciente ativo em tempo real
  // Função que produz o fluxo reativo do paciente corrente
  Stream<PacienteModel?> _carregarPaciente() {
    // Permite injeção de stream para testes automatizados
    // Se foi injetada uma stream simulada de paciente no construtor
    if (widget.pacienteStreamOverride != null) {
      // Retorna diretamente a stream mockada recebida
      return widget.pacienteStreamOverride!;
    // Fechamento da condicional de stream injetada
    }

    // Se o serviço do Firebase estiver ativo e operacional
    if (_isFirebaseDisponivel()) {
      final idParam = widget.pacienteId?.trim();
      final idAuth = FirebaseAuthService().currentUserId?.trim();
      final docIdAlvo = (idParam != null && idParam.isNotEmpty)
          ? idParam
          : ((idAuth != null && idAuth.isNotEmpty) ? idAuth : null);

      if (docIdAlvo != null && docIdAlvo.isNotEmpty) {
        return FirebaseFirestore.instance
            .collection('usuarios')
            .doc(docIdAlvo)
            .snapshots()
            .map((doc) {
              if (doc.exists && doc.data() != null) {
                final dados = doc.data()!;
                final ativo = dados['ativo'];
                final status = dados['status']?.toString().toLowerCase().trim();
                final situacao = dados['situacao']?.toString().toLowerCase().trim();
                if (ativo == false ||
                    ativo == 'false' ||
                    status == 'inativo' ||
                    situacao == 'inativo' ||
                    status == 'excluido' ||
                    situacao == 'excluido') {
                  return null;
                }
                final base = PacienteModel.fromMap(dados, docId: doc.id);
                final (viagemBase, _) =
                    _localizarViagemEPassageiro(base.id, cpf: base.cpf);
                final enriquecido = _enriquecerComDadosViagem(base);
                _syncService.registrarPacienteEmMemoriaSeAusente(
                  enriquecido,
                  viagemId: viagemBase?.id,
                );
                return enriquecido;
              }
              return _buscarPacienteEmViagem(docIdAlvo);
            });
      }

      return FirebaseFirestore.instance
          .collection('usuarios')
          .where('role', isEqualTo: 'paciente')
          .snapshots()
          .map((snapshot) {
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
              final base = PacienteModel.fromMap(dados, docId: doc.id);
              final (viagemBase, _) =
                  _localizarViagemEPassageiro(base.id, cpf: base.cpf);
              final enriquecido = _enriquecerComDadosViagem(base);
              _syncService.registrarPacienteEmMemoriaSeAusente(
                enriquecido,
                viagemId: viagemBase?.id,
              );
              return enriquecido;
            }
            return null;
          });
    }

    // Retorna stream nula caso o Firebase não esteja inicializado e não haja streamOverride
    return Stream.value(null);
  // Fechamento do método _carregarPaciente
  }

  // Método que constrói a árvore de widgets da tela do paciente
  @override
  // Recebe o contexto de renderização do Flutter
  Widget build(BuildContext context) {
    // Construtor reativo baseado na Stream de dados do paciente
    return StreamBuilder<PacienteModel?>(
      // Conecta o construtor à stream de dados do paciente
      stream: _pacienteStream,
      // Construtor da interface baseado no snapshot da stream
      builder: (context, snapshot) {
        // Estado de carregamento inicial
        // Se a stream ainda estiver aguardando conexão e não houver dados em cache
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          // Exibe tela com fundo branco e indicador de progresso centralizado
          return const Scaffold(
            // Cor de fundo branca
            backgroundColor: Colors.white,
            // Corpo com círculo de progresso
            body: Center(child: CircularProgressIndicator()),
          // Fechamento do Scaffold de carregamento
          );
        // Fechamento do if de aguardando
        }

        // Extrai o objeto paciente do snapshot atual (enriquecido com dados da viagem quando disponíveis)
        final rawPaciente = snapshot.data;
        final paciente = rawPaciente != null
            ? _enriquecerComDadosViagem(rawPaciente)
            : null;

        // Caso nenhum registro seja localizado
        // Se o paciente for nulo (não encontrado no banco de dados)
        if (paciente == null) {
          // Renderiza tela informativa de ausência de dados
          return Scaffold(
            // Cor de fundo branca padronizada
            backgroundColor: Colors.white,
            // Barra de navegação com título
            appBar: AppBar(title: const Text('Painel do Paciente')),
            // Corpo centralizado com mensagem explicativa
            body: const Center(
              // Texto informativo em tom cinza
              child: Text(
                // Mensagem de dados ausentes
                'Nenhum dado de paciente encontrado.',
                // Estilo tipográfico com cor suave
                style: TextStyle(color: Color(0xFF64748B)),
              // Fechamento do Text
              ),
            // Fechamento do Center
            ),
          // Fechamento do Scaffold
          );
        // Fechamento do if de paciente nulo
        }

        // Avaliação de timer ativo e regras de habilitação dos botões de ação:
        // A janela de reversão só é válida se estiver ativa no tempo E consistente com o estado atual:
        // - 'cancelamento_carona' só tem sentido se o paciente estiver em status 5 (Cancelado).
        // - 'pronto_retorno' só tem sentido se o paciente estiver em status 2 (Desembarcou) com prontoRetorno == true.
        final bool isJanelaValida = paciente.janelaReversao != null &&
            paciente.janelaReversao!.estaAtiva() &&
            ((paciente.janelaReversao!.acao == 'cancelamento_carona' && paciente.status == 5) ||
             (paciente.janelaReversao!.acao == 'pronto_retorno' && paciente.status == 2 && paciente.prontoRetorno));

        final bool temTimerAtivo = isJanelaValida;

        // Quando o paciente se encontra dentro da van (Status 1: Embarcou para Ida ou
        // Status 3: Reembarcou para Volta), ambos os botões devem ficar cinzas e
        // inacessíveis, pois ele já está a bordo do veículo em trânsito.
        // O botão "Fui embora" só pode ser acionado quando NÃO está na van (Status 0 ou 2).
        final bool fuiEmboraHabilitado = !temTimerAtivo &&
            !_processandoAcao &&
            (paciente.status == 0 || paciente.status == 2);

        // O botão "Estou Pronto" só pode ser acionado quando desembarcou na consulta (Status 2)
        // e ainda não avisou o motorista. Nos demais status (0, 1, 3, 4, 5) fica cinza e inacessível.
        final bool estouProntoHabilitado = !temTimerAtivo &&
            !_processandoAcao &&
            !paciente.prontoRetorno &&
            paciente.status == 2;

        // Rótulo de apoio explicativo para estados desabilitados (acessibilidade / blindagem cognitiva):
        String? mensagemApoio;
        if (temTimerAtivo) {
          if (paciente.janelaReversao?.acao == 'cancelamento_carona') {
            mensagemApoio = 'Cancelamento em andamento. Você pode desfazer no banner acima.';
          } else {
            mensagemApoio = 'Prontidão sinalizada. Você pode desfazer no banner acima.';
          }
        } else if (paciente.status == 1) {
          mensagemApoio = 'Você está a bordo da van a caminho da consulta médica.';
        } else if (paciente.status == 3) {
          mensagemApoio = 'Você está a bordo da van retornando para sua residência.';
        } else if (paciente.status == 2 && paciente.prontoRetorno) {
          mensagemApoio = 'Motorista já avisado. Aguarde o veículo no ponto de encontro.';
        } else if (paciente.status == 4) {
          mensagemApoio = 'Transporte concluído com sucesso. Tenha um ótimo dia!';
        } else if (paciente.status == 5) {
          mensagemApoio = 'Agendamento cancelado.';
        }

        // Renderiza a estrutura completa da tela quando os dados do paciente estão disponíveis
        return Scaffold(
          // Fundo padronizado com as demais telas do aplicativo
          backgroundColor: const Color(0xFFF8FAFC),
          // Barra de navegação superior da tela com identidade visual consistente
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 2,
            // Botão de navegação na extremidade esquerda
            leading: IconButton(
              // Ícone com seta de retrocesso
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              // Ação disparada ao clicar no botão de voltar
              onPressed: () {
                // Se puder desempilhar rota atual, volta para a tela anterior
                if (Navigator.of(context).canPop()) {
                  // Desempilha a rota atual
                  Navigator.of(context).pop();
                // Caso contrário, substitui a rota pela página raiz
                } else {
                  // Navega para a rota raiz '/'
                  Navigator.of(context).pushReplacementNamed('/');
                // Fechamento da condicional if/else
                }
              // Fechamento do callback onPressed
              },
            // Fechamento do IconButton
            ),
            // Título central da barra de navegação
            title: const Text(
              'Painel do Paciente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                key: const Key('botaoLogoutPaciente'),
                icon: const Icon(Icons.logout),
                color: Colors.white,
                tooltip: 'Sair da conta',
                onPressed: () async {
                  await FirebaseAuthService().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          // Fechamento do AppBar
          ),
          // Layout responsivo adaptável a 100% da largura da tela, assim como a Lista de Passageiros
          // Área protegida contra entalhes e barras de status do sistema
          body: SafeArea(
            // Habilita rolagem vertical para comportar todos os blocos e cartões
            child: SingleChildScrollView(
              // Margem interna uniforme de 16 pixels ao redor do conteúdo
              padding: const EdgeInsets.all(16.0),
              // Coluna que empilha os blocos verticalmente
              child: Column(
                // Estende os filhos horizontalmente ocupando toda a largura da tela
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // Lista de widgets filhos da tela do paciente
                children: [
                  // 1. COMPONENTE: Card de Identificação do Paciente
                  // Exibe nome, CPF e status com avatar
                  CardIdentificacaoPaciente(
                    // Nome completo do paciente
                    nome: paciente.nome,
                    // CPF do paciente
                    cpf: paciente.cpf,
                    // Status numérico da etapa da viagem
                    status: paciente.status,
                  // Fechamento do CardIdentificacaoPaciente
                  ),
                  // Espaçamento vertical entre os cards
                  const SizedBox(height: 16),

                  // 2. COMPONENTE: Card com Dados da Consulta
                  // Exibe local da consulta, horário, ponto de saída, endereço e acompanhante
                  CardDadosConsulta(
                    // Hospital ou unidade de atendimento
                    localConsulta: paciente.localConsulta,
                    // Horário agendado do atendimento médico
                    horarioConsulta: paciente.horarioConsulta,
                    // Ponto de partida do paciente
                    localSaida: paciente.localSaida,
                    // Endereço de residência do passageiro
                    enderecoPaciente: paciente.enderecoPaciente,
                    // Nome do acompanhante se cadastrado
                    nomeAcompanhante: paciente.nomeAcompanhante,
                  // Fechamento do CardDadosConsulta
                  ),
                  // Espaçamento vertical entre os cards
                  const SizedBox(height: 16),

                  // BANNER DE REVERSÃO / UNDO (Issue #19)
                  if (temTimerAtivo && paciente.janelaReversao != null)
                    BannerReversaoPaciente(
                      janela: paciente.janelaReversao!,
                      carregando: _processandoAcao,
                      onDesfazer: () => _executarDesfazer(paciente),
                    ),

                  // 3. BOTÕES DE AÇÃO: Primário ("Estou Pronto") e Secundário ("Fui embora")
                  // Enquanto houver timer ativo (janela de reversão de carona ou pronto), os botões
                  // permanecem visíveis, porém inacessíveis com estilo cinza (disabled).
                  // Ao desfazer a ação, ou se a janela não estiver ativa, os botões voltam a ser clicáveis.
                  // Altura de 54dp e FittedBox garantem resiliência a escalas de 150% a 200%.
                  Row(
                    children: [
                      // Botão Secundário: Fui embora (Carona)
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton.icon(
                            key: const Key('botao_fui_embora'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: fuiEmboraHabilitado
                                    ? const Color(0xFFB83227)
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: fuiEmboraHabilitado
                                  ? const Color(0xFFFFFDF8)
                                  : const Color(0xFFF1F5F9),
                            ),
                            icon: Icon(
                              Icons.cancel_outlined,
                              color: fuiEmboraHabilitado
                                  ? const Color(0xFFB83227)
                                  : Colors.grey.shade400,
                              size: 18,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Fui embora',
                                style: TextStyle(
                                  color: fuiEmboraHabilitado
                                      ? const Color(0xFFB83227)
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            onPressed: fuiEmboraHabilitado
                                ? () => _solicitarCancelamentoComConfirmacao(paciente)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Botão Primário: Estou Pronto
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            key: const Key('botao_estou_pronto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: estouProntoHabilitado
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                              disabledForegroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: estouProntoHabilitado ? 2 : 0,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                paciente.prontoRetorno ? 'Pronto (Avisado)' : 'Estou Pronto',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            onPressed: estouProntoHabilitado
                                ? () => _sinalizarProntoComConfirmacao(paciente)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Rótulo de apoio para estados inativos (elimina sensação de app travado e reduz ansiedade)
                  if (mensagemApoio != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const Key('mensagem_apoio_botoes_inativos'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                mensagemApoio,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // 4. COMPONENTE: Card com Mapa de Rastreamento dos Motoristas Ativos
                  // Exibe a localização em tempo real de todos os motoristas em trânsito
                  CardTrackingPaciente(
                    motoristasStreamOverride: widget.motoristasStreamOverride,
                  ),
                // Fechamento da lista children da Column
                ],
              // Fechamento da Column
              ),
            // Fechamento do SingleChildScrollView
            ),
          // Fechamento do SafeArea
          ),
        // Fechamento do Scaffold
        );
      // Fechamento do builder do StreamBuilder
      },
    // Fechamento do StreamBuilder
    );
  // Fechamento do método build
  }
// Fechamento da classe _PacienteState
}
