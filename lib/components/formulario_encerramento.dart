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

import 'dart:async';

// Importa o framework Material Design do Flutter com componentes de diálogo, botões e tipografia
import 'package:flutter/foundation.dart';
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

/// Função top-level executada em Isolate separado via [compute] para compilação
/// não-bloqueante do relatório PDF oficial TFD.
Future<Uint8List> _compilarPdfEmIsolate(Map<String, dynamic> payload) async {
  final viagemMap = Map<String, dynamic>.from(payload['viagem'] as Map);
  final viagem = ViagemModel.fromMap(
    viagemMap,
    docId: (viagemMap['id'] ?? '').toString(),
  );
  final pacientesRaw = (payload['pacientes'] as List<dynamic>? ?? const []);
  final pacientes = pacientesRaw.map((item) {
    final map = Map<String, dynamic>.from(item as Map);
    return PacienteModel.fromMap(
      map,
      docId: (map['id'] ?? '').toString(),
    );
  }).toList();

  return RelatorioPdfService.gerarRoteiroViagemPdf(
    viagem: viagem,
    pacientes: pacientes,
    retornoInformado: payload['retornoInformado'] as String?,
    kmRetornoInformado: payload['kmRetornoInformado'] as int?,
    kmRodadoInformado: payload['kmRodadoInformado'] as int?,
  );
}

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
  // Callback opcional acionado após o fechamento efetivo da viagem para redirecionar o motorista
  final VoidCallback? onViagemEncerrada;

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
    // Parâmetro nomeado opcional: callback ao encerrar viagem
    this.onViagemEncerrada,
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
  // Trava contra múltiplos cliques concorrentes no encerramento
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _kmRetornoController.addListener(_aoMudarKmRetorno);
  }

  int get _kmInicialBase {
    return widget.viagem?.kmInicial ??
        widget.viagens?.firstOrNull?.kmInicial ??
        ViagemService().viagemAtiva?.kmInicial ??
        0;
  }

  void _aoMudarKmRetorno() {
    final kmRet = int.tryParse(_kmRetornoController.text.trim());
    if (kmRet != null) {
      final kmIni = _kmInicialBase;
      if (kmRet >= kmIni) {
        final diff = kmRet - kmIni;
        if (_kmRodadoController.text != diff.toString()) {
          _kmRodadoController.text = diff.toString();
        }
      }
    }
  }

  // Linha em branco separadora entre controladores e dispose

  // Anotação indicando sobrescrita do método de descarte do ciclo de vida
  @override
  // Método dispose: libera os recursos de memória alocados pelos controladores de texto ao fechar o diálogo
  void dispose() {
    _kmRetornoController.removeListener(_aoMudarKmRetorno);
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
          onPressed: _processando
              ? null
              : () {
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
          // Callback assíncrono executado ao clicar em Confirmar (Zero-Wait UI: fecha no 1º toque < 16 ms)
          onPressed: _processando
              ? null
              : () {
                  setState(() {
                    _processando = true;
                  });

                  // Extrai o texto aparado do campo de retorno
                  final retorno = _retornoController.text.trim();
                  // Extrai o texto aparado do campo de km retorno
                  final kmRetorno = _kmRetornoController.text.trim();
                  // Extrai o texto aparado do campo de km rodado
                  var kmRodado = _kmRodadoController.text.trim();

                  final kmRetornoNum = int.tryParse(kmRetorno);
                  final kmIni = _kmInicialBase;

                  // Validação direta de odômetro: kmRetorno >= kmInicial (eliminando caso 1111 vs 1222)
                  if (kmRetornoNum != null && kmRetornoNum < kmIni) {
                    setState(() {
                      _processando = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          'Km de retorno ($kmRetornoNum km) não pode ser menor que o Km inicial ($kmIni km).',
                        ),
                      ),
                    );
                    return;
                  }

                  // Cálculo de KM rodado automático
                  int? kmRodadoNum = int.tryParse(kmRodado);
                  if (kmRetornoNum != null && kmRetornoNum >= kmIni) {
                    final diff = kmRetornoNum - kmIni;
                    kmRodadoNum ??= diff;
                    if (kmRodado.isEmpty) {
                      kmRodado = diff.toString();
                    }
                  }

                  // Notifica o callback onConfirmar repassando os valores informados
                  widget.onConfirmar?.call(retorno, kmRetorno, kmRodado);

                  // Identifica todas as viagens a serem processadas (incluindo as que auto-concluíram durante a sessão do motorista)
                  final listaParaRelatorio = ViagemService().obterViagensParaRelatorio(
                    viagensExplicitas: widget.viagens,
                    viagemUnica: widget.viagem,
                  );

                  // Cria snapshot imutável das viagens preservando os códigos de acesso para o PDF
                  final List<ViagemModel> viagensSnapshot = listaParaRelatorio
                      .map(
                        (v) => v.copyWith(
                          codigosAcesso: Map<String, String>.from(v.codigosAcesso),
                          passageiros: List.from(v.passageiros),
                        ),
                      )
                      .toList();
                  final List<PacienteModel>? pacientesSnapshot =
                      widget.pacientes != null
                          ? List<PacienteModel>.from(widget.pacientes!)
                          : null;

                  // 1. Finaliza a viagem própria do motorista e atualiza o serviço imediatamente em memória (< 1 ms)
                  unawaited(
                    ViagemService().encerrarTodasViagens(
                      kmFinal: kmRetornoNum,
                      kmRodado: kmRodadoNum,
                      viagensExplicitas: viagensSnapshot,
                      pacientes: pacientesSnapshot,
                    ),
                  );

                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final viagemFallback = widget.viagem ?? ViagemService().viagemAtiva;

                  // 2. Notifica a tela do motorista para limpar o estado local e redirecionar ao FormularioInicioViagem
                  widget.onViagemEncerrada?.call();

                  // 3. Fecha o diálogo modal imediatamente ao primeiro toque (< 16 ms)
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }

                  // 4. Exibe barra de progresso não-intrusiva e dispara compilação do PDF e impressão em background
                  messenger?.showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF0F172A),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Viagem encerrada. Preparando relatório PDF em segundo plano...',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  unawaited(
                    Future<void>.delayed(
                      const Duration(milliseconds: 50),
                      () async {
                        final vBase = viagensSnapshot.isNotEmpty
                            ? viagensSnapshot.first
                            : (viagemFallback ??
                                ViagemModel(
                                  id: 'relatorio_${DateTime.now().millisecondsSinceEpoch}',
                                  motoristaId: '',
                                  motoristaNome: '',
                                  veiculoId: '',
                                  veiculoPlaca: '',
                                  veiculoModelo: '',
                                  kmInicial: 0,
                                  cidadeDestino: 'TFD',
                                  dataHoraInicio: DateTime.now(),
                                  status: 'encerrada',
                                ));

                        final mapaPacientesConsolidados = <String, PacienteModel>{};
                        final codigosConsolidados = <String, String>{
                          ...vBase.codigosAcesso,
                        };
                        final idsPassageirosConsolidados = <String>[];
                        final destinos = <String>[];

                        if (viagensSnapshot.isNotEmpty) {
                          for (final v in viagensSnapshot) {
                            if (v.cidadeDestino.trim().isNotEmpty &&
                                !destinos.contains(v.cidadeDestino.trim())) {
                              destinos.add(v.cidadeDestino.trim());
                            }
                            codigosConsolidados.addAll(v.codigosAcesso);
                            final pacsDaViagem = ViagemService()
                                .obterPacientesParaViagemRelatorio(
                              v,
                              pacientesInformados: pacientesSnapshot,
                            );
                            for (final p in pacsDaViagem) {
                              mapaPacientesConsolidados[p.id] = p;
                              if (!idsPassageirosConsolidados.contains(p.id)) {
                                idsPassageirosConsolidados.add(p.id);
                              }
                            }
                          }
                        } else if (pacientesSnapshot != null) {
                          for (final p in pacientesSnapshot) {
                            mapaPacientesConsolidados[p.id] = p;
                            if (!idsPassageirosConsolidados.contains(p.id)) {
                              idsPassageirosConsolidados.add(p.id);
                            }
                          }
                        }

                        final viagemParaPdf = vBase.copyWith(
                          cidadeDestino: destinos.isNotEmpty
                              ? destinos.join(' / ')
                              : vBase.cidadeDestino,
                          passageirosIds: idsPassageirosConsolidados,
                          codigosAcesso: codigosConsolidados,
                        );
                        final listaPacientesPdf =
                            mapaPacientesConsolidados.values.toList();

                        final placaLimpa = viagemParaPdf.veiculoPlaca.trim().isNotEmpty
                            ? viagemParaPdf.veiculoPlaca.trim()
                            : 'TFD';
                        final nomeArquivoPdf = 'Roteiro_Viagem_$placaLimpa.pdf';

                        Uint8List? pdfBytes;
                        try {
                          final emAmbienteDeTeste = WidgetsBinding
                              .instance
                              .runtimeType
                              .toString()
                              .contains('TestWidgetsFlutterBinding');
                          if (!emAmbienteDeTeste) {
                            final payload = <String, dynamic>{
                              'viagem': {
                                ...viagemParaPdf.toMap(),
                                'id': viagemParaPdf.id,
                              },
                              'pacientes': listaPacientesPdf
                                  .map((p) => {...p.toMap(), 'id': p.id})
                                  .toList(),
                              'retornoInformado':
                                  retorno.isNotEmpty ? retorno : null,
                              'kmRetornoInformado': kmRetornoNum,
                              'kmRodadoInformado': kmRodadoNum,
                            };
                            pdfBytes = await compute(
                              _compilarPdfEmIsolate,
                              payload,
                            );
                          } else {
                            pdfBytes =
                                await RelatorioPdfService.gerarRoteiroViagemPdf(
                              viagem: viagemParaPdf,
                              pacientes: listaPacientesPdf,
                              retornoInformado:
                                  retorno.isNotEmpty ? retorno : null,
                              kmRetornoInformado: kmRetornoNum,
                              kmRodadoInformado: kmRodadoNum,
                            );
                          }
                        } catch (_) {}

                        if (pdfBytes != null &&
                            pdfBytes.isNotEmpty &&
                            WidgetsBinding.instance is WidgetsFlutterBinding) {
                          try {
                            final bytes = pdfBytes;
                            await Printing.layoutPdf(
                              name: nomeArquivoPdf,
                              onLayout: (format) async => bytes,
                            );
                          } catch (_) {}
                        }
                      },
                    ),
                  );
                // Fecha a função de onPressed
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
