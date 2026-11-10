// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/banner_reversao_paciente.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o banner reativo de Janela de Reversão (Undo) e contagem regressiva
// na tela do paciente (Issue #19). Exibe o tempo restante calculado a partir
// do timestamp UTC de expiração do servidor e o botão para desfazer a ação
// ("Desfazer cancelamento" em até 5 min ou "Desfazer aviso de pronto" em até 1 min).
//
// PARA QUE SERVE NO PROJETO:
// Dá feedback visual e transparência ao cidadão/paciente após ele acionar "Fui embora"
// ou "Estou Pronto", permitindo reverter a decisão com 1 toque enquanto a janela
// do servidor permanecer aberta.
//
// ONDE É USADO NO PROJETO:
// - lib/paciente.dart (exibido acima dos botões de ação quando houver janela ativa)
// - test/components/banner_reversao_paciente_test.dart
//
// DE ONDE RECEBE DADOS:
// Instância de JanelaReversaoModel associada ao PacienteModel atual e callback onDesfazer.
//
// O QUE EXPORTA / EXPÕE:
// - class BannerReversaoPaciente extends StatefulWidget
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/janela_reversao_model.dart';

/// Componente visual animado que apresenta a contagem regressiva da janela de Undo.
class BannerReversaoPaciente extends StatefulWidget {
  /// Janela de reversão recebida do modelo do paciente.
  final JanelaReversaoModel janela;

  /// Callback acionado quando o usuário toca no botão de desfazer.
  final VoidCallback onDesfazer;

  /// Se uma requisição de reversão está sendo processada no momento.
  final bool carregando;

  /// Provedor opcional de tempo atual (útil para testes unitários determinísticos).
  final DateTime Function()? relogio;

  const BannerReversaoPaciente({
    super.key,
    required this.janela,
    required this.onDesfazer,
    this.carregando = false,
    this.relogio,
  });

  @override
  State<BannerReversaoPaciente> createState() => _BannerReversaoPacienteState();
}

class _BannerReversaoPacienteState extends State<BannerReversaoPaciente> {
  Timer? _timerTicker;
  late Duration _tempoRestante;

  DateTime _obterAgora() {
    return (widget.relogio != null ? widget.relogio!() : DateTime.now()).toUtc();
  }

  @override
  void initState() {
    super.initState();
    _atualizarTempo();
    // Inicia o timer que redesenha os segundos restantes a cada 1 segundo
    _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _atualizarTempo();
      }
    });
  }

  @override
  void didUpdateWidget(covariant BannerReversaoPaciente oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.janela != widget.janela) {
      _atualizarTempo();
    }
  }

  void _atualizarTempo() {
    final agora = _obterAgora();
    setState(() {
      _tempoRestante = widget.janela.tempoRestante(agora: agora);
    });
  }

  @override
  void dispose() {
    _timerTicker?.cancel();
    super.dispose();
  }

  String _formatarTempo(Duration duration) {
    final minutos = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    final bool expirou = _tempoRestante == Duration.zero;
    final bool isCancelamento = widget.janela.acao == 'cancelamento_carona';

    final Color corTema = isCancelamento
        ? const Color(0xFFB83227)
        : const Color(0xFF2563EB);
    final Color corFundo = isCancelamento
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFEFF6FF);

    final duracaoTotalSegundos = isCancelamento ? 300.0 : 60.0;
    final progresso = (_tempoRestante.inSeconds / duracaoTotalSegundos).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: corTema.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: corTema.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isCancelamento
                    ? Icons.warning_amber_rounded
                    : Icons.access_time_filled_rounded,
                color: corTema,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCancelamento
                      ? 'Cancelamento Solicitado'
                      : 'Prontidão Sinalizada',
                  style: TextStyle(
                    color: corTema,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: corTema.withValues(alpha: 0.3)),
                ),
                child: Text(
                  expirou ? 'Expirado' : _formatarTempo(_tempoRestante),
                  style: TextStyle(
                    color: corTema,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            expirou
                ? 'O prazo para reversão terminou. A alteração foi consolidada.'
                : (isCancelamento
                    ? 'Você avisou que não utilizará o transporte. Caso mude de ideia, desfaça abaixo.'
                    : 'O motorista foi avisado que sua consulta médica terminou.'),
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progresso,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(corTema),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: ElevatedButton(
              key: const Key('botao_desfazer_reversao'),
              style: ElevatedButton.styleFrom(
                backgroundColor: expirou ? Colors.grey : corTema,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 1,
              ),
              onPressed: (expirou || widget.carregando) ? null : widget.onDesfazer,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  widget.carregando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.undo_rounded, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.carregando
                          ? 'Revertendo...'
                          : (isCancelamento
                              ? 'Desfazer Cancelamento'
                              : 'Desfazer Aviso de Pronto'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
