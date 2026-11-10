import 'package:flutter/material.dart';

import '../components/abreviar_textos.dart';
import '../components/bloco_acompanhante.dart';
import '../components/indicador_progresso.dart';
import '../models/janela_reversao_model.dart';
import '../models/paciente_model.dart';

/// Card informativo de cada passageiro exibido na lista de viagem do motorista.
class CardPaciente extends StatelessWidget {
  final String nomePaciente;
  final String enderecoPaciente;
  final String telPaciente;
  final String localConsulta;
  final String localSaida;
  final int status;
  final String? nomeAcompanhante;
  final String? telAcompanhante;
  final bool prontoRetorno;
  final JanelaReversaoModel? janelaReversao;
  final String? codigoAcesso;

  const CardPaciente({
    super.key,
    required this.nomePaciente,
    required this.enderecoPaciente,
    required this.telPaciente,
    required this.localConsulta,
    required this.localSaida,
    required this.status,
    this.nomeAcompanhante,
    this.telAcompanhante,
    this.prontoRetorno = false,
    this.janelaReversao,
    this.codigoAcesso,
  });

  Widget _construirLinhaInfo({
    required IconData icone,
    required double tamanhoIcone,
    required String texto,
    required TextStyle style,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: tamanhoIcone),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            texto,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _construirChipAlerta({
    required IconData icone,
    required String texto,
    required Color corTexto,
    required Color corFundo,
    FontWeight pesoFonte = FontWeight.bold,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: corTexto.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: corTexto),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 11,
                fontWeight: pesoFonte,
                color: corTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (textoStatus, corStatus, iconeStatus) =
        PacienteModel.dadosStatus(status);

    return Card(
      elevation: 12,
      child: InkWell(
        // O controle operacional fica concentrado no gesto de Swipe (Dismissible)
        // com diálogo de confirmação para evitar toques acidentais.
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_2_outlined, size: 25),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        TextAbbreviator.abbreviate(
                          nomePaciente,
                          maxCharacters: 30,
                          maxWords: 4,
                          keepWords: 1,
                        ).toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (codigoAcesso != null && codigoAcesso!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        flex: 0,
                        child: Tooltip(
                          message: 'Código de acesso temporário do passageiro',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF3B82F6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.key,
                                  size: 12,
                                  color: Color(0xFF60A5FA),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  codigoAcesso!,
                                  key: const ValueKey('codigo_acesso_badge'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                _construirLinhaInfo(
                  icone: Icons.house_outlined,
                  tamanhoIcone: 25,
                  texto: enderecoPaciente,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _construirLinhaInfo(
                  icone: Icons.phone_outlined,
                  tamanhoIcone: 23,
                  texto: telPaciente,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (nomeAcompanhante != null &&
                    nomeAcompanhante!.trim().isNotEmpty)
                  CardAcompanhante(
                    nomeAcompanhante: nomeAcompanhante!,
                    telAcompanhante: telAcompanhante ?? '',
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),
                _construirLinhaInfo(
                  icone: Icons.medical_services_outlined,
                  tamanhoIcone: 20,
                  texto: localConsulta,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _construirLinhaInfo(
                  icone: Icons.exit_to_app_outlined,
                  tamanhoIcone: 20,
                  texto: localSaida,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(iconeStatus, size: 20),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              textoStatus,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color.lerp(
                                  corStatus,
                                  Colors.black,
                                  0.4,
                                )!,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (janelaReversao != null &&
                          janelaReversao!.estaAtiva() &&
                          status == 5) ...[
                        const SizedBox(height: 6),
                        _construirChipAlerta(
                          icone: Icons.schedule,
                          texto: 'Aguardando confirmação do passageiro',
                          corTexto: const Color(0xFFB83227),
                          corFundo: const Color(0xFFFEF2F2),
                          pesoFonte: FontWeight.w600,
                        ),
                      ],
                      if (status == 2 && prontoRetorno) ...[
                        const SizedBox(height: 6),
                        _construirChipAlerta(
                          icone: Icons.check_circle,
                          texto: 'Pronto para Retorno',
                          corTexto: const Color(0xFF16A34A),
                          corFundo: const Color(0xFFECFDF5),
                        ),
                      ],
                      const SizedBox(height: 10),
                      IndicadorProgresso(
                        valorAtual: status,
                        valorMaximo: (status == 0) ? 1 : 4,
                        corAtiva: corStatus.withAlpha(255),
                        corInativa: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
