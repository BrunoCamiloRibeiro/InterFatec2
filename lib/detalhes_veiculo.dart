import 'package:flutter/material.dart';
import 'components/card_veiculo.dart';
import 'components/dialog_excluir_veiculo.dart';
import 'components/formulario_novo_veiculo.dart';
import 'controllers/veiculo_controller.dart';
import 'models/firestore_parse_utils.dart';
import 'models/veiculo_model.dart';

class DetalhesVeiculo extends StatefulWidget {
  final Map<String, dynamic> veiculo;
  final ValueChanged<String>? onStatusChanged;
  final VoidCallback? onExcluir;

  const DetalhesVeiculo({
    super.key,
    required this.veiculo,
    this.onStatusChanged,
    this.onExcluir,
  });

  @override
  State<DetalhesVeiculo> createState() => _DetalhesVeiculoState();
}

class _DetalhesVeiculoState extends State<DetalhesVeiculo> {
  void _abrirEdicao(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FormularioNovoVeiculo(
        veiculoParaEditar: widget.veiculo,
        onSalvar: (veiculoAtualizado) {
          setState(() {
            widget.veiculo.addAll(veiculoAtualizado);
          });
          VeiculoController().atualizarVeiculo(VeiculoModel.fromMap(widget.veiculo));
        },
      ),
    );
  }

  void _confirmarExclusao(BuildContext context) {
    final veiculo = widget.veiculo;
    final emUso = veiculo['emUso'] == true ||
        veiculo['status']?.toString().trim().toLowerCase() == 'em uso';
    DialogExcluirVeiculo.mostrar(
      context,
      id: veiculo['id']?.toString() ?? '',
      placa: veiculo['placa']?.toString() ?? '',
      modelo: '${veiculo['marca']} ${veiculo['modelo']}',
      emUso: emUso,
      onConfirmar: () {
        if (widget.onExcluir != null) {
          widget.onExcluir!();
        }
        Navigator.of(context).pop(); // Retorna à lista
      },
    );
  }

  String _formatarData(dynamic valor) {
    final dt = parsearDataFirestore(valor)?.toLocal();
    if (dt == null) return '-';
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    final hora = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${dt.year} às $hora:$min';
  }

  Widget _construirInfoData({
    required IconData icone,
    required String rotulo,
    required String valor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: const Color(0xFF475569), size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rotulo,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final veiculo = widget.veiculo;
    final String placa = (veiculo['placa'] ?? '-').toString();
    final String criadoEm = _formatarData(veiculo['criadoEm']);
    final String atualizadoEm = _formatarData(veiculo['atualizadoEm']);
    final String rawMotorista =
        (veiculo['ultimoMotoristaNome'] ?? veiculo['ultimoMotoristaId'] ?? '')
            .toString()
            .trim();
    final String ultimoMotorista = (rawMotorista.isEmpty ||
            rawMotorista == 'null' ||
            rawMotorista == 'motorista_atual')
        ? 'Não informado'
        : rawMotorista;
    final bool possuiAC = veiculo['possuiAC'] == true;
    final bool possuiPreferencial = veiculo['possuiPreferencial'] == true;
    final String? observacoes = veiculo['observacoes']?.toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Veículo $placa',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // CARD PRINCIPAL DO VEÍCULO (sem ações duplicadas de rodapé)
            CardVeiculo(
              veiculo: veiculo,
              exibirAcoesRodape: false,
              onStatusChanged: (novoStatus) {
                setState(() {
                  veiculo['status'] = novoStatus;
                });
                VeiculoController().alterarStatus(
                  veiculo['id'].toString(),
                  StatusVeiculo.fromString(novoStatus),
                );
                if (widget.onStatusChanged != null) {
                  widget.onStatusChanged!(novoStatus);
                }
              },
            ),

            const SizedBox(height: 16),

            // SEÇÃO COM EXPANSIONTILE: INFORMAÇÕES ADICIONAIS
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: true,
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                shape: const Border(),
                collapsedShape: const Border(),
                minTileHeight: 56,
                title: const Text(
                  'Mais Informações',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _construirInfoData(
                          icone: Icons.person_outline_outlined,
                          rotulo: 'Último Motorista',
                          valor: ultimoMotorista,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final escala =
                                MediaQuery.textScalerOf(context).scale(13);
                            final empilhar =
                                constraints.maxWidth < 310 || escala > 19;

                            final cardCadastro = _construirInfoData(
                              icone: Icons.calendar_today_outlined,
                              rotulo: 'Data de Cadastro',
                              valor: criadoEm,
                            );

                            final cardAtualizacao = _construirInfoData(
                              icone: Icons.update_outlined,
                              rotulo: 'Última Atualização',
                              valor: atualizadoEm,
                            );

                            if (empilhar) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  cardCadastro,
                                  const SizedBox(height: 12),
                                  cardAtualizacao,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cardCadastro),
                                const SizedBox(width: 12),
                                Expanded(child: cardAtualizacao),
                              ],
                            );
                          },
                        ),
                        if (possuiAC || possuiPreferencial) ...[
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, badgeConstraints) {
                              return Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (possuiAC)
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: badgeConstraints.maxWidth,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.ac_unit_outlined,
                                              size: 16,
                                              color: Color.lerp(
                                                Colors.blue,
                                                Colors.black,
                                                0.4,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Ar-condicionado',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color.lerp(
                                                    Colors.blue,
                                                    Colors.black,
                                                    0.4,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (possuiPreferencial)
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: badgeConstraints.maxWidth,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2D2F8D),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.accessible_outlined,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Acesso Preferencial',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                        if (observacoes != null && observacoes.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.help_outline_outlined,
                                      size: 18,
                                      color: Color.lerp(
                                        Colors.orange,
                                        Colors.brown,
                                        0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Observação',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color.lerp(
                                            Colors.orange,
                                            Colors.brown,
                                            0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  observacoes,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // BOTÕES DE AÇÃO NA BASE
            LayoutBuilder(
              builder: (context, constraints) {
                final escala = MediaQuery.textScalerOf(context).scale(14);
                final empilhar = constraints.maxWidth < 330 || escala > 19;

                final botaoExcluir = OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _confirmarExclusao(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Excluir Veículo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );

                final botaoEditar = ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _abrirEdicao(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Editar Veículo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );

                if (empilhar) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      botaoExcluir,
                      const SizedBox(height: 12),
                      botaoEditar,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: botaoExcluir),
                    const SizedBox(width: 14),
                    Expanded(child: botaoEditar),
                  ],
                );
              },
            ),
          ],
          ),
        ),
      ),
    );
  }
}
