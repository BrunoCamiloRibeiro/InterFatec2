// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/formulario_encerramento.dart
// Camada: Apresentação / Diálogos e Modais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o diálogo modal (FormularioEncerramento em formato AlertDialog) para
// encerramento da viagem pelo motorista. Permite o preenchimento dos três campos
// obrigatórios da prestação de contas: horário de retorno (com máscara automática HH:mm),
// quilometragem de retorno no hodômetro e quilometragem total rodada. Ao confirmar,
// notifica o callback onConfirmar e invoca a biblioteca de impressão (printing)
// para pré-visualização e geração do documento PDF oficial "Roteiro da Viagem".
//
// PARA QUE SERVE NO PROJETO:
// É a etapa de fechamento da rota na tela do motorista, permitindo registrar
// os dados finais de percurso do veículo e emitir a ficha física de atendimento
// TFD da Unidade Básica de Saúde de Poloni para conferência e arquivo municipal.
//
// ONDE É USADO NO PROJETO:
// - lib/components/footer_pacientes.dart (acionado pelo botão 'Gerar Relatório')
//
// DE ONDE RECEBE DADOS:
// - Instância de ViagemModel repassada pelo motorista
// - Lista de instâncias de PacienteModel da viagem
// - Textos digitados nos campos de retorno e quilometragem
//
// O QUE EXPORTA / EXPÕE:
// - class FormularioEncerramento extends StatefulWidget
// - class _MascaraHorarioFormatter extends TextInputFormatter
//
// ORIGEM HISTÓRICA:
// Criado no commit 94b2c17 pela equipe do projeto na issue #15 (US03 / encerramento
// de viagem). Não provém de template ou scaffold automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart', 'package:flutter/services.dart'
// e 'package:printing/printing.dart'.
// Efeitos colaterais: dispara impressão/visualização nativa com Printing.layoutPdf
// e fecha o diálogo modal através de Navigator.pop.
// ============================================================================

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';
// Importa serviços de digitação e formatação de texto do Flutter
import 'package:flutter/services.dart';
// Importa o pacote printing para emissão e impressão multiplataforma do PDF
import 'package:printing/printing.dart';

// Linha em branco separadora entre pacotes externos e modelos internos
// Importa o modelo PacienteModel para repasse ao gerador de PDF
import '../models/paciente_model.dart';
// Importa o modelo ViagemModel para repasse dos dados ao gerador de PDF
import '../models/viagem_model.dart';
// Importa o serviço de geração do documento PDF oficial TFD
import '../services/relatorio_pdf_service.dart';

// Linha em branco separadora entre imports e a declaração de FormularioEncerramento
// Comentários originais do autor mantidos byte a byte:
// Componente visual em formato de POPUP (AlertDialog) para o Formulário de Encerramento (Issue #15 / US03).
// Contém os 3 campos solicitados: Retorno, Km Retorno e Km Rodado, além da emissão do PDF oficial TFD.
// Declaração do widget StatefulWidget FormularioEncerramento
class FormularioEncerramento extends StatefulWidget {
  // Instância da viagem ativa que está sendo encerrada
  final ViagemModel? viagem;
  // Lista de passageiros vinculados à viagem para impressão
  final List<PacienteModel>? pacientes;
  // Callback opcional notificado com os valores digitados ao confirmar
  final void Function(String retorno, String kmRetorno, String kmRodado)?
  onConfirmar;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante inicializando os parâmetros nomeados
  const FormularioEncerramento({
    // Chave opcional do widget
    super.key,
    // Parâmetro opcional para a viagem ativa
    this.viagem,
    // Parâmetro opcional para a lista de pacientes
    this.pacientes,
    // Parâmetro opcional para o callback de confirmação
    this.onConfirmar,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e createState

  // Cria o estado mutável associado a este diálogo modal
  @override
  // Instancia a classe de estado _FormularioEncerramentoState
  State<FormularioEncerramento> createState() => _FormularioEncerramentoState();
// Fecha a classe FormularioEncerramento
}

// Linha em branco separadora entre FormularioEncerramento e _FormularioEncerramentoState
// Classe de estado privada que gerencia os campos de entrada do modal
class _FormularioEncerramentoState extends State<FormularioEncerramento> {
  // Controlador de texto do campo de horário de retorno
  final TextEditingController _retornoController = TextEditingController();
  // Controlador de texto do campo de quilometragem de retorno
  final TextEditingController _kmRetornoController = TextEditingController();
  // Controlador de texto do campo de quilometragem percorrida
  final TextEditingController _kmRodadoController = TextEditingController();

  // Linha em branco separadora entre controladores e dispose

  // Ciclo de vida: descarte dos controladores ao fechar o diálogo
  @override
  // Libera os recursos alocados pelos TextEditingControllers
  void dispose() {
    // Descarta o controlador de retorno
    _retornoController.dispose();
    // Descarta o controlador de KM de retorno
    _kmRetornoController.dispose();
    // Descarta o controlador de KM rodado
    _kmRodadoController.dispose();
    // Executa a finalização da superclasse
    super.dispose();
  // Fecha o método dispose
  }

  // Linha em branco separadora entre dispose e build

  // Sobrescrita do método build para montagem do diálogo modal
  @override
  // Constrói o layout visual do AlertDialog
  Widget build(BuildContext context) {
    // Comentário original do autor mantido byte a byte:
    // Popup modal (AlertDialog) exibido sobre a tela da Lista de Passageiros
    // Retorna AlertDialog com cantos arredondados e fundo branco
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Comentário original do autor mantido byte a byte:
      // Título do Popup com ícone e texto de encerramento
      // Cabeçalho do modal com ícone de prancheta concluída
      title: Row(
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            color: Colors.blueGrey[900],
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Formulário de Encerramento',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              ),
            ),
          ),
        ],
      ),
      // Comentário original do autor mantido byte a byte:
      // Conteúdo rolável do Popup contendo os 3 campos obrigatórios da Issue #15
      // Conteúdo com rolagem para telas compactas
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Comentário original do autor mantido byte a byte:
              // CAMPO 1: Retorno (com máscara de horário HH:mm)
              // Rótulo do campo de horário de retorno
              const Text(
                'Retorno',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              // Campo de texto para inserção do horário de chegada
              TextField(
                controller: _retornoController,
                keyboardType: TextInputType.number,
                // Comentário original do autor mantido byte a byte:
                // Aplica filtro de apenas números e a máscara automática no formato HH:mm
                // Filtro para digitação numérica e formatador customizado HH:mm
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _MascaraHorarioFormatter(),
                ],
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.access_time_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  ),
                  hintText: '00:00',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Comentário original do autor mantido byte a byte:
              // CAMPO 2: Km Retorno
              // Rótulo do campo de quilometragem de retorno
              const Text(
                'Km Retorno',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              // Campo de texto para inserção do hodômetro no retorno
              TextField(
                controller: _kmRetornoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.speed_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  ),
                  suffixText: 'km',
                  hintText: 'Ex: 85650',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Comentário original do autor mantido byte a byte:
              // CAMPO 3: Km Rodado
              // Rótulo do campo de total de quilômetros percorridos
              const Text(
                'Km Rodado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              // Campo de texto para inserção da diferença rodada
              TextField(
                controller: _kmRodadoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.add_road_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  ),
                  suffixText: 'km',
                  hintText: 'Ex: 230',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Comentário original do autor mantido byte a byte:
      // Botões de ação do Popup (Cancelar e Confirmar)
      // Lista de botões do diálogo modal
      actions: [
        // Botão Cancelar para fechar o diálogo
        TextButton(
          onPressed: () {
            // Fecha o diálogo sem salvar alterações
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        // Botão Confirmar para submeter dados e disparar layout do PDF
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            // Extrai e limpa os valores digitados nos três campos
            final retorno = _retornoController.text.trim();
            final kmRetorno = _kmRetornoController.text.trim();
            final kmRodado = _kmRodadoController.text.trim();

            // Notifica o callback com os valores fornecidos
            widget.onConfirmar?.call(retorno, kmRetorno, kmRodado);

            // Comentário original do autor mantido byte a byte:
            // Se houver dados de viagem e pacientes disponíveis, aciona a visualização/impressão do PDF
            // Dispara a impressão do documento oficial TFD se houver dados da viagem
            if (widget.viagem != null && widget.pacientes != null) {
              final v = widget.viagem!;
              final kmRetornoNum = int.tryParse(kmRetorno);
              final kmRodadoNum = int.tryParse(kmRodado);

              // Abre o spooler de impressão nativo com os bytes gerados pelo RelatorioPdfService
              await Printing.layoutPdf(
                name: 'Roteiro_Viagem_${v.veiculoPlaca}.pdf',
                onLayout: (format) async {
                  return RelatorioPdfService.gerarRoteiroViagemPdf(
                    viagem: v,
                    pacientes: widget.pacientes!,
                    retornoInformado: retorno.isNotEmpty ? retorno : null,
                    kmRetornoInformado: kmRetornoNum,
                    kmRodadoInformado: kmRodadoNum,
                  );
                },
              );
            }

            // Fecha o diálogo modal caso o contexto continue montado
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// Linha em branco separadora entre formulário e formatador de máscara
// Comentário original do autor mantido byte a byte:
// Formatador simples para aplicar a máscara de horário (HH:mm) enquanto o usuário digita
// Classe privada TextInputFormatter para inserção automática de ':' em horários
class _MascaraHorarioFormatter extends TextInputFormatter {
  // Sobrescreve formatEditUpdate para interceptar caracteres digitados
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Comentário original do autor mantido byte a byte:
    // Limita a no máximo 4 dígitos numéricos (2 para hora e 2 para minuto)
    // Extrai o texto da nova edição
    String digitos = newValue.text;
    // Trunca se ultrapassar 4 dígitos
    if (digitos.length > 4) {
      digitos = digitos.substring(0, 4);
    }

    // Linha em branco separadora entre truncamento e inserção de dois-pontos
    // Comentário original do autor mantido byte a byte:
    // Insere os dois-pontos ":" automaticamente após os 2 primeiros dígitos
    // Variável para acumular o texto formatado com separador
    String formatado = '';
    // Itera pelos caracteres inserindo ':' no índice 2
    for (int i = 0; i < digitos.length; i++) {
      if (i == 2) {
        formatado += ':';
      }
      formatado += digitos[i];
    }

    // Linha em branco separadora entre laço de formatação e retorno
    // Retorna novo TextEditingValue com a máscara e cursor no final
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}
