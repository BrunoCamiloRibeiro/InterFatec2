// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/formulario_encerramento.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o diálogo modal (FormularioEncerramento) acionado ao finalizar a viagem,
// estruturando três campos de entrada de dados essenciais da rota (horário de retorno
// com máscara automática "HH:mm", quilometragem final no hodômetro e quilômetros
// totais rodados). Ao confirmar, repassa os dados via callback e dispara o serviço
// de geração e visualização do relatório oficial em PDF (RelatorioPdfService).
//
// PARA QUE SERVE NO PROJETO:
// É o formulário de encerramento da jornada do motorista (US03 / Issue #15),
// garantindo que os dados operacionais de fechamento sejam registrados e que a
// ficha física padronizada de atendimento TFD seja impressa ou visualizada.
//
// ONDE É USADO NO PROJETO:
// - lib/components/footer_pacientes.dart (acionado via showDialog no botão "Gerar Relatório")
//
// DE ONDE RECEBE DADOS:
// Parâmetros repassados pelo rodapé: viagem (ViagemModel) e pacientes (List<PacienteModel>).
//
// O QUE EXPORTA / EXPÕE:
// - class FormularioEncerramento extends StatefulWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit dc0cfec pela equipe na implementação do formulário de encerramento
// e integrado à biblioteca de impressão no commit b2f3972. Não provém de scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart', 'package:flutter/services.dart'
// e 'package:printing/printing.dart'.
// Efeitos colaterais: invoca a impressora/spooler do sistema via Printing.layoutPdf.
// ============================================================================

// Importa o framework Material Design do Flutter com componentes de diálogo, botões e tipografia
import 'package:flutter/material.dart';
// Importa o pacote services do Flutter para manipulação de máscaras e formatadores de entrada de texto
import 'package:flutter/services.dart';
// Importa o pacote externo de impressão para visualização nativa de documentos PDF
import 'package:printing/printing.dart';

// Linha em branco separadora entre pacotes externos e modelos internos
// Importa o modelo PacienteModel para repasse ao gerador de PDF
import '../models/paciente_model.dart';
// Importa o modelo ViagemModel para repasse dos dados ao gerador de PDF
import '../models/viagem_model.dart';
// Importa o serviço de geração do documento PDF oficial TFD
import '../services/relatorio_pdf_service.dart';
// Importa o serviço de gerenciamento de viagens para finalizar sessão e viagens ativas
import '../services/viagem_service.dart';

// Linha em branco separadora entre imports e a declaração de FormularioEncerramento
// Comentários originais do autor mantidos byte a byte:
// Componente visual em formato de POPUP (AlertDialog) para o Formulário de Encerramento (Issue #15 / US03).
// Contém os 3 campos solicitados: Retorno, Km Retorno e Km Rodado, além da emissão do PDF oficial TFD.
// Declaração do widget StatefulWidget FormularioEncerramento
// Elemento: Classe StatefulWidget mutável do Flutter para gerenciar os estados de digitação dos campos de fechamento
class FormularioEncerramento extends StatefulWidget {
  // Atributo viagem: objeto da viagem ativa que está sendo encerrada (opcional)
  // Tipo: ViagemModel? anulável
  final ViagemModel? viagem;
  // Atributo viagens: lista de N viagens ativas para geração em lote de PDF (Issue #65)
  final List<ViagemModel>? viagens;
  // Atributo pacientes: lista de passageiros vinculados à viagem para emissão do relatório (opcional)
  // Tipo: List<PacienteModel>? anulável
  final List<PacienteModel>? pacientes;
  // Atributo onConfirmar: função callback opcional notificada com os 3 valores digitados ao clicar em Confirmar
  // Tipo: void Function(String retorno, String kmRetorno, String kmRodado)? anulável
  final void Function(String retorno, String kmRetorno, String kmRodado)?
  onConfirmar;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe FormularioEncerramento com parâmetros nomeados
  const FormularioEncerramento({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado opcional: objeto da viagem ativa
    this.viagem,
    // Parâmetro nomeado opcional: N viagens ativas para emissão em lote
    this.viagens,
    // Parâmetro nomeado opcional: lista de pacientes atendidos
    this.pacientes,
    // Parâmetro nomeado opcional: callback de confirmação
    this.onConfirmar,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e createState

  // Anotação indicando sobrescrita do método createState de StatefulWidget
  @override
  // Método createState: instancia a classe de estado que gerencia os controladores de texto
  // Retorna: Instância de _FormularioEncerramentoState
  State<FormularioEncerramento> createState() => _FormularioEncerramentoState();
// Fecha a classe FormularioEncerramento
}

// Linha em branco separadora entre FormularioEncerramento e _FormularioEncerramentoState
// Declaração da classe privada de estado _FormularioEncerramentoState
// Elemento: Classe de estado associada ao StatefulWidget FormularioEncerramento
class _FormularioEncerramentoState extends State<FormularioEncerramento> {
  // Controlador de texto para o campo de horário de retorno (HH:mm)
  // Elemento: Instância de TextEditingController
  final TextEditingController _retornoController = TextEditingController();
  // Controlador de texto para o campo de quilometragem de retorno no hodômetro
  // Elemento: Instância de TextEditingController
  final TextEditingController _kmRetornoController = TextEditingController();
  // Controlador de texto para o campo de quilômetros totais rodados
  // Elemento: Instância de TextEditingController
  final TextEditingController _kmRodadoController = TextEditingController();

  // Linha em branco separadora entre controladores e dispose

  // Anotação indicando sobrescrita do método de descarte do ciclo de vida
  @override
  // Método dispose: libera os recursos de memória alocados pelos controladores de texto ao fechar o diálogo
  void dispose() {
    // Descarta o controlador de retorno
    _retornoController.dispose();
    // Descarta o controlador de KM de retorno
    _kmRetornoController.dispose();
    // Descarta o controlador de KM rodado
    _kmRodadoController.dispose();
    // Executa a finalização da superclasse State
    super.dispose();
  // Fecha o método dispose
  }

  // Linha em branco separadora entre dispose e build

  // Anotação indicando que o método build sobrescreve a definição da classe State
  @override
  // Método build: reconstrói a árvore de widgets correspondente à caixa de diálogo de encerramento
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (AlertDialog estilizado com os campos de entrada e botões de ação)
  Widget build(BuildContext context) {
    // Comentário original do autor mantido byte a byte:
    // Popup modal (AlertDialog) exibido sobre a tela da Lista de Passageiros
    // Retorna a árvore de widgets encabeçada pelo widget AlertDialog do Material Design
    return AlertDialog(
      // Cor de fundo branca sólida para contraste e legibilidade
      backgroundColor: Colors.white,
      // Cantos arredondados com raio geométrico de 12 pixels
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Comentário original do autor mantido byte a byte:
      // Título do Popup com ícone e texto de encerramento
      // Propriedade title de AlertDialog: linha horizontal com ícone de prancheta e título
      title: Row(
        // Propriedade children da Row de título: ícone, espaçamento e texto expandido
        children: [
          // Widget Icon: glifo de prancheta com visto de verificação (assignment_turned_in_outlined)
          Icon(
            Icons.assignment_turned_in_outlined,
            color: Colors.blueGrey[900],
            size: 24,
          // Fecha a instanciação de Icon
          ),
          // Widget SizedBox: espaçamento horizontal constante de 8 pixels lógicos
          const SizedBox(width: 8),
          // Widget Expanded: expande o título para ocupar o espaço horizontal disponível
          Expanded(
            // Propriedade child de Expanded: widget Text do título do modal
            child: Text(
              'Formulário de Encerramento',
              // Propriedade style: formatação tipográfica em negrito
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              // Fecha a TextStyle do título
              ),
            // Fecha o widget Text do título
            ),
          // Fecha o widget Expanded do título
          ),
        // Fecha a lista children da Row de título
        ],
      // Fecha a Row de título
      ),
      // Comentário original do autor mantido byte a byte:
      // Conteúdo rolável do Popup contendo os 3 campos obrigatórios da Issue #15
      // Propriedade content de AlertDialog: área rolável contendo os campos de texto
      content: SingleChildScrollView(
        // Propriedade child de SingleChildScrollView: caixa delimitadora de largura
        child: SizedBox(
          // Largura fixa de 340 pixels lógicos para manter proporção harmoniosa
          width: 340,
          // Propriedade child de SizedBox: coluna vertical empilhando os campos
          child: Column(
            // Ajusta a altura da coluna ao tamanho estritamente necessário pelos filhos
            mainAxisSize: MainAxisSize.min,
            // Alinha os elementos à esquerda no eixo horizontal
            crossAxisAlignment: CrossAxisAlignment.start,
            // Propriedade children da Column de conteúdo: rótulos e campos de texto
            children: [
              // Comentário original do autor mantido byte a byte:
              // CAMPO 1: Retorno (com máscara de horário HH:mm)
              // Widget Text: rótulo textual do campo de horário de retorno
              const Text(
                'Retorno',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              // Fecha o widget Text do rótulo
              ),
              // Widget SizedBox: espaçamento vertical constante de 6 pixels lógicos
              const SizedBox(height: 6),
              // Widget TextField: campo de entrada de texto para o horário de retorno
              TextField(
                // Vincula o controlador de texto específico do horário de retorno
                controller: _retornoController,
                // Define o teclado numérico para facilitar digitação no smartphone
                keyboardType: TextInputType.number,
                // Comentário original do autor mantido byte a byte:
                // Aplica filtro de apenas números e a máscara automática no formato HH:mm
                // Lista de formatadores interceptando a digitação
                inputFormatters: [
                  // Filtra apenas dígitos numéricos (0-9)
                  FilteringTextInputFormatter.digitsOnly,
                  // Invocação do formatador customizado para máscara HH:mm
                  _MascaraHorarioFormatter(),
                // Fecha a lista inputFormatters
                ],
                // Propriedade decoration: estilo visual do campo de entrada
                decoration: InputDecoration(
                  // Ícone de relógio no início do campo
                  prefixIcon: Icon(
                    Icons.access_time_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  // Fecha o Icon
                  ),
                  // Texto de dica (placeholder)
                  hintText: '00:00',
                  // Estilo da dica em cinza claro
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  // Fecha a hintStyle
                  ),
                  // Compacta a altura do campo
                  isDense: true,
                  // Preenchimento interno
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  // Fecha o EdgeInsets.symmetric
                  ),
                  // Borda padrão com cantos arredondados
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  // Fecha a OutlineInputBorder
                  ),
                  // Borda quando habilitado com contorno cinza suave
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  // Fecha a OutlineInputBorder
                  ),
                // Fecha o InputDecoration
                ),
              // Fecha o TextField de retorno
              ),
              // Widget SizedBox: espaçamento vertical constante de 14 pixels lógicos
              const SizedBox(height: 14),

              // Comentário original do autor mantido byte a byte:
              // CAMPO 2: Km Retorno
              // Widget Text: rótulo textual do campo de quilometragem de retorno
              const Text(
                'Km Retorno',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              // Fecha o widget Text do rótulo
              ),
              // Widget SizedBox: espaçamento vertical constante de 6 pixels lógicos
              const SizedBox(height: 6),
              // Widget TextField: campo de entrada de texto para o hodômetro de retorno
              TextField(
                // Vincula o controlador de KM de retorno
                controller: _kmRetornoController,
                // Teclado numérico
                keyboardType: TextInputType.number,
                // Filtro para digitação estritamente numérica
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                // Decoração visual do campo
                decoration: InputDecoration(
                  // Ícone de velocímetro
                  prefixIcon: Icon(
                    Icons.speed_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  // Fecha o Icon
                  ),
                  // Sufixo indicando unidade de quilômetros ('km')
                  suffixText: 'km',
                  // Texto de exemplo no placeholder
                  hintText: 'Ex: 85650',
                  // Estilo da dica
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  // Fecha a hintStyle
                  ),
                  // Densidade compacta
                  isDense: true,
                  // Preenchimento interno
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  // Fecha o EdgeInsets.symmetric
                  ),
                  // Borda com cantos arredondados
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  // Fecha a OutlineInputBorder
                  ),
                  // Borda habilitada com contorno cinza
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  // Fecha a OutlineInputBorder
                  ),
                // Fecha o InputDecoration
                ),
              // Fecha o TextField de km retorno
              ),
              // Widget SizedBox: espaçamento vertical constante de 14 pixels lógicos
              const SizedBox(height: 14),

              // Comentário original do autor mantido byte a byte:
              // CAMPO 3: Km Rodado
              // Widget Text: rótulo textual do campo de quilometragem total rodada
              const Text(
                'Km Rodado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              // Fecha o widget Text do rótulo
              ),
              // Widget SizedBox: espaçamento vertical constante de 6 pixels lógicos
              const SizedBox(height: 6),
              // Widget TextField: campo de entrada para a diferença de quilômetros percorrida
              TextField(
                // Vincula o controlador de KM rodado
                controller: _kmRodadoController,
                // Teclado numérico
                keyboardType: TextInputType.number,
                // Filtro para digitação numérica
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                // Decoração visual do campo
                decoration: InputDecoration(
                  // Ícone de estrada adicionada
                  prefixIcon: Icon(
                    Icons.add_road_outlined,
                    size: 20,
                    color: Colors.blueGrey[900],
                  // Fecha o Icon
                  ),
                  // Sufixo de unidade de medida
                  suffixText: 'km',
                  // Exemplo no placeholder
                  hintText: 'Ex: 230',
                  // Estilo do texto de dica
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  // Fecha a hintStyle
                  ),
                  // Densidade compacta
                  isDense: true,
                  // Preenchimento interno
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  // Fecha o EdgeInsets.symmetric
                  ),
                  // Borda arredondada
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  // Fecha a OutlineInputBorder
                  ),
                  // Borda quando habilitado
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  // Fecha a OutlineInputBorder
                  ),
                // Fecha o InputDecoration
                ),
              // Fecha o TextField de km rodado
              ),
            // Fecha a lista children da Column de conteúdo
            ],
          // Fecha a Column de conteúdo
          ),
        // Fecha o SizedBox
        ),
      // Fecha o SingleChildScrollView
      ),
      // Comentário original do autor mantido byte a byte:
      // Botões de ação do Popup (Cancelar e Confirmar)
      // Propriedade actions de AlertDialog: lista de botões exibidos na base do modal
      actions: [
        // Widget TextButton: botão para cancelar a operação e fechar o diálogo
        TextButton(
          // Callback acionado ao clicar em Cancelar
          onPressed: () {
            // Fecha o diálogo modal desempilhando a rota
            Navigator.of(context).pop();
          // Fecha o onPressed
          },
          // Rótulo textual do botão Cancelar
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.grey.shade700),
          // Fecha a TextStyle de Cancelar
          ),
        // Fecha o TextButton de Cancelar
        ),
        // Widget ElevatedButton: botão destacado para confirmação e emissão do PDF
        ElevatedButton(
          // Propriedade style: customização visual do botão Confirmar
          style: ElevatedButton.styleFrom(
            // Cor de fundo azul acinzentado escuro
            backgroundColor: Colors.blueGrey[900],
            // Cor do texto branca pura
            foregroundColor: Colors.white,
            // Cantos arredondados de 8 pixels
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            // Fecha o RoundedRectangleBorder
            ),
          // Fecha a chamada de ElevatedButton.styleFrom
          ),
          // Callback assíncrono executado ao clicar em Confirmar
          onPressed: () async {
            // Extrai o texto aparado do campo de retorno
            final retorno = _retornoController.text.trim();
            // Extrai o texto aparado do campo de km retorno
            final kmRetorno = _kmRetornoController.text.trim();
            // Extrai o texto aparado do campo de km rodado
            final kmRodado = _kmRodadoController.text.trim();

            // Notifica o callback onConfirmar repassando os valores informados
            widget.onConfirmar?.call(retorno, kmRetorno, kmRodado);

            // Identifica as viagens a serem processadas (N viagens em lote ou viagem única)
            final List<ViagemModel> viagensAlvo =
                (widget.viagens != null && widget.viagens!.isNotEmpty)
                    ? widget.viagens!
                    : (widget.viagem != null
                        ? [widget.viagem!]
                        : const <ViagemModel>[]);

            // Converte a string de KM retorno para inteiro numérico
            final kmRetornoNum = int.tryParse(kmRetorno);
            // Converte a string de KM rodado para inteiro numérico
            final kmRodadoNum = int.tryParse(kmRodado);

            // Finaliza as viagens e a sessão do veículo no serviço
            await ViagemService().encerrarTodasViagens(
              kmFinal: kmRetornoNum,
              kmRodado: kmRodadoNum,
            );

            // Checagem de disponibilidade: se há viagens e pacientes informados, gera e exibe o PDF
            if (viagensAlvo.isNotEmpty && widget.pacientes != null) {

              if (viagensAlvo.length > 1) {
                // Emissão em lote atômica de todas as N viagens ativas (Issue #65)
                final lote = await RelatorioPdfService.gerarLoteViagensPdf(
                  viagens: viagensAlvo,
                  pacientes: widget.pacientes!,
                  retornoInformado: retorno.isNotEmpty ? retorno : null,
                  kmRetornoInformado: kmRetornoNum,
                  kmRodadoInformado: kmRodadoNum,
                );

                for (final v in viagensAlvo) {
                  final bytes = lote[v.id];
                  if (bytes != null) {
                    await Printing.layoutPdf(
                      name: 'Roteiro_Viagem_${v.id}_${v.veiculoPlaca}.pdf',
                      onLayout: (format) async => bytes,
                    );
                  }
                }
              } else {
                // Emissão individual preservando comportamento e assinaturas pré-existentes
                final v = viagensAlvo.first;
                await Printing.layoutPdf(
                  // Nome do arquivo gerado
                  name: 'Roteiro_Viagem_${v.veiculoPlaca}.pdf',
                  // Callback gerador que constrói os bytes do documento PDF via RelatorioPdfService
                  onLayout: (format) async {
                    // Invocação do serviço de relatório oficial
                    return RelatorioPdfService.gerarRoteiroViagemPdf(
                      viagem: v,
                      pacientes: widget.pacientes!,
                      retornoInformado: retorno.isNotEmpty ? retorno : null,
                      kmRetornoInformado: kmRetornoNum,
                      kmRodadoInformado: kmRodadoNum,
                    // Fecha a chamada de gerarRoteiroViagemPdf
                    );
                  // Fecha a função assíncrona onLayout
                  },
                // Fecha a chamada de Printing.layoutPdf
                );
              }
            // Fecha o bloco condicional de geração de PDF
            }

            // Cláusula de segurança: fecha o diálogo apenas se o contexto do widget permanecer montado
            if (context.mounted) {
              // Desempilha e fecha o diálogo modal
              Navigator.of(context).pop();
            // Fecha a checagem context.mounted
            }
          // Fecha a função assíncrona de onPressed
          },
          // Rótulo textual do botão Confirmar
          child: const Text(
            'Confirmar',
            style: TextStyle(fontWeight: FontWeight.bold),
          // Fecha a TextStyle de Confirmar
          ),
        // Fecha o ElevatedButton de Confirmar
        ),
      // Fecha a lista actions de AlertDialog
      ],
    // Fecha o widget AlertDialog
    );
  // Fecha o método build
  }
// Fecha a classe _FormularioEncerramentoState
}

// Linha em branco separadora entre formulário e formatador de máscara
// Comentário original do autor mantido byte a byte:
// Formatador simples para aplicar a máscara de horário (HH:mm) enquanto o usuário digita
// Declaração da classe privada _MascaraHorarioFormatter estendendo TextInputFormatter
// Elemento: Classe privada para interceptar e formatar digitação de horário
class _MascaraHorarioFormatter extends TextInputFormatter {
  // Anotação indicando sobrescrita do método de formatação
  @override
  // Método formatEditUpdate: recebe o valor anterior e o novo valor digitado, retornando o valor com a máscara aplicada
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Comentário original do autor mantido byte a byte:
    // Limita a no máximo 4 dígitos numéricos (2 para hora e 2 para minuto)
    // Variável digitos: armazena a string contendo os caracteres digitados
    String digitos = newValue.text;
    // Condicional de truncamento: se o tamanho for superior a 4 caracteres, trunca nos primeiros 4
    if (digitos.length > 4) {
      digitos = digitos.substring(0, 4);
    // Fecha a checagem de tamanho
    }

    // Linha em branco separadora entre truncamento e inserção de dois-pontos
    // Comentário original do autor mantido byte a byte:
    // Insere os dois-pontos ":" automaticamente após os 2 primeiros dígitos
    // Variável formatado: string acumuladora para montagem do horário com máscara
    String formatado = '';
    // Laço for: percorre cada caractere inserindo o separador ':' após o segundo dígito
    for (int i = 0; i < digitos.length; i++) {
      // Se for a posição de índice 2 (terceiro caractere), insere os dois-pontos
      if (i == 2) {
        formatado += ':';
      // Fecha o if
      }
      // Concatena o dígito na string formatada
      formatado += digitos[i];
    // Fecha o laço for
    }

    // Linha em branco separadora entre laço de formatação e retorno
    // Retorna nova instância de TextEditingValue com o texto formatado e o cursor posicionado no final
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  // Fecha o método formatEditUpdate
  }
// Fecha a classe _MascaraHorarioFormatter
}
