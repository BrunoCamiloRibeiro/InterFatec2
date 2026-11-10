import 'package:flutter/material.dart';
import 'components/card_veiculo.dart';
import 'components/dialog_excluir_veiculo.dart';
import 'components/formulario_novo_veiculo.dart';
import 'controllers/veiculo_controller.dart';
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
    DialogExcluirVeiculo.mostrar(
      context,
      id: veiculo['id']?.toString() ?? '',
      placa: veiculo['placa']?.toString() ?? '',
      modelo: '${veiculo['marca']} ${veiculo['modelo']}',
      onConfirmar: () {
        if (widget.onExcluir != null) {
          widget.onExcluir!();
        }
        Navigator.of(context).pop(); // Retorna à lista
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final veiculo = widget.veiculo;
    final String placa = (veiculo['placa'] ?? '-').toString();
    final String criadoEm = (veiculo['criadoEm'] ?? '-').toString();
    final String atualizadoEm = (veiculo['atualizadoEm'] ?? '-').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Veículo $placa',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => _abrirEdicao(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Excluir',
            onPressed: () => _confirmarExclusao(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // CARD PRINCIPAL DO VEÍCULO (Estilo original idêntico)
            CardVeiculo(
              veiculo: veiculo,
              onEditar: () => _abrirEdicao(context),
              onDetalhes: () {},
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
            ExpansionTile(
              initiallyExpanded: true,
              backgroundColor: Colors.grey[100],
              minTileHeight: 60,
              title: const Text(
                'Mais Informações',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final escala = MediaQuery.textScalerOf(context).scale(13);
                      final empilhar = constraints.maxWidth < 310 || escala > 19;

                      final cardCadastro = Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.calendar_today_outlined, color: Colors.grey[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Data de Cadastro',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color.lerp(Colors.grey, Colors.black, 0.5),
                                  ),
                                ),
                                Text(
                                  criadoEm,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final cardAtualizacao = Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.update_outlined, color: Colors.grey[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Última Atualização',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color.lerp(Colors.grey, Colors.black, 0.5),
                                  ),
                                ),
                                Text(
                                  atualizadoEm,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
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
                ),
              ],
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
    );
  }
}
