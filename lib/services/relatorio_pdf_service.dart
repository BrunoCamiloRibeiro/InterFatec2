// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/relatorio_pdf_service.dart
// Camada: Domínio / Serviços de Relatório e Impressão (Services)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa a geração em formato PDF vetorial do documento oficial:
// "Roteiro da Viagem - Ficha de Atendimento TFD" (Unidade Básica de Saúde de Poloni).
// Segue rigorosamente a especificação visual e milimétrica obtida do modelo
// físico oficial em folha padrão A4 (210 x 297 mm / 595.28 x 841.89 pt).
// Configura tipografia embutida TrueType (Liberation Sans / Helvetica), cabeçalho
// institucional em todas as páginas, relação de passageiros e data de emissão
// na página 1, bloco de resumo contábil na última página e quebra dinâmica de
// páginas por altura vertical disponível por bloco de paciente.
//
// PARA QUE SERVE NO PROJETO:
// Gera a ficha impressa que os motoristas levam em viagem para controle de
// assinatura, conferência de passageiros e prestação de contas na Secretaria
// Municipal de Saúde de Poloni ao término do deslocamento.
//
// ONDE É USADO NO PROJETO:
// - lib/components/formulario_encerramento.dart (disparo de impressão e exportação)
// - test/relatorio_pdf_test.dart (testes de layout, casos limites e fidelidade visual)
//
// DE ONDE RECEBE DADOS:
// - Instância de ViagemModel (motorista, veículo, KM inicial/final, data e destino)
// - Lista de instâncias de PacienteModel (nomes, endereços, horários e acompanhantes)
// - Fontes TrueType carregadas via rootBundle em 'assets/fonts/LiberationSans-*.ttf'
//
// O QUE EXPORTA / EXPÕE:
// - class RelatorioPdfService
//   * Constantes de layout e tipografia milimétrica
//   * static Future<Uint8List> gerarRoteiroViagemPdf(...)
//
// ORIGEM HISTÓRICA:
// Desenvolvido pela equipe de desenvolvimento no commit c0351c9 para a issue #16
// ("gerar-o-pdf"). Não provém de template ou scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:pdf/pdf.dart', 'package:pdf/widgets.dart',
// 'package:intl/intl.dart' e 'package:flutter/services.dart' (rootBundle).
// Operação funcional sem escrita em banco de dados: lê ativos de fontes embutidas
// e retorna um buffer de memória em bytes (Uint8List).
// ============================================================================

// Importa suporte a buffers de bytes binários em memória para retorno do PDF gerado
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/paciente_model.dart';
import '../models/viagem_model.dart';
import 'codigo_acesso_service.dart';

/// Serviço especializado na geração do documento PDF oficial:
/// "Roteiro da Viagem - Ficha de Atendimento TFD" da Unidade Básica de Saúde de Poloni.
///
/// Este serviço implementa a especificação visual exata obtida a partir da medição
/// milimétrica do documento padrão da prefeitura (A4: 210 x 297 mm / 595.28 x 841.89 pt).
/// Todo o layout é construído com coordenadas precisas, controle rígido de tipografia
/// (Liberation Sans / Helvetica), quebra de página dinâmica por capacidade vertical
/// e tratamento robusto de limites para evitar sobreposição de textos.
class RelatorioPdfService {
  // ===========================================================================
  // CONSTANTES DE LAYOUT MILIMÉTRICO (em pontos tipográficos do padrão PDF: 72 pt = 1 polegada = 25.4 mm)
  // ===========================================================================

  /// Margem esquerda da folha (medida: 14.8 mm -> 42.0 pt).
  /// Delimita o alinhamento de início de todos os blocos de dados.
  static const double kMargemEsquerda = 42.0;

  /// Margem direita da folha (medida: 14.8 mm -> 42.0 pt).
  /// Delimita o alinhamento final e limite direito dos textos e tabelas.
  static const double kMargemDireita = 42.0;

  /// Margem superior inicial (medida: 5.5 mm -> 15.6 pt).
  /// Ponto vertical de onde se inicia a renderização do cabeçalho institucional.
  static const double kMargemSuperior = 15.6;

  /// Margem inferior de segurança (medida: 10.6 mm -> 30.0 pt).
  /// Limite inferior que nenhuma seção ou bloco pode ultrapassar.
  static const double kMargemInferior = 30.0;

  /// Largura total da folha no padrão ISO A4 (595.28 pt = 210 mm).
  static const double kLarguraPagina = 595.28;

  /// Altura total da folha no padrão ISO A4 (841.89 pt = 297 mm).
  static const double kAlturaPagina = 841.89;

  /// Altura vertical fixa ocupada por cada bloco de paciente (pitch entre passageiros).
  /// Medida real entre o topo do paciente N e o topo do paciente N+1: 17.9 mm -> 50.7 pt.
  static const double kAlturaBlocoPaciente = 54.0;

  /// Altura total ocupada pelo bloco 'Resumo' e linha de assinatura na última página.
  /// Compreende o título, contadores, linhas de Km/Retorno e a linha da assinatura (33.5 mm -> 95.0 pt).
  static const double kAlturaBlocoResumo = 95.0;

  /// Altura vertical ocupada pelo cabeçalho na Página 1 (55.0 mm -> 156.0 pt).
  /// Inclui os dados institucionais da UBS, dados da viagem, o título "Relação de Passageiros" e espaçamento.
  static const double kAlturaCabecalhoPagina1 = 156.0;

  /// Altura vertical ocupada pelo cabeçalho em páginas de continuação (44.4 mm -> 126.0 pt).
  /// Não inclui a faixa "Relação de Passageiros", que é exclusiva da primeira página.
  static const double kAlturaCabecalhoContinuacao = 126.0;

  /// Altura reservada na base da Página 1 para a linha 'Emitido em' (12.3 mm -> 35.0 pt).
  static const double kAlturaRodapeEmissao = 35.0;

  static (pw.Font, pw.Font) _resolverFontes({
    pw.Font? fonteRegular,
    pw.Font? fonteBold,
  }) {
    return (
      fonteRegular ?? pw.Font.helvetica(),
      fonteBold ?? pw.Font.helveticaBold(),
    );
  }

  /// Normaliza o número da requisição para no máximo 6 caracteres limpos,
  /// evitando quebra de linha e sobreposição vertical no cabeçalho quando
  /// o ID da viagem é um identificador longo (ex.: 'horario_2026_11_8_1762645200000').
  static String _formatarNumeroRequisicao(String idBruto) {
    final limpo = idBruto.trim();
    if (limpo.isEmpty) return '025059';
    if (limpo.length <= 8 && !limpo.contains('_')) {
      return limpo.padLeft(6, '0');
    }
    final digitos = limpo.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.length >= 6) {
      return digitos.substring(digitos.length - 6);
    }
    if (digitos.isNotEmpty) {
      return digitos.padLeft(6, '0');
    }
    return limpo.substring(0, limpo.length > 6 ? 6 : limpo.length).toUpperCase();
  }

  // ===========================================================================
  // MÉTODO PRINCIPAL DE GERAÇÃO DO DOCUMENTO
  // ===========================================================================

  /// Gera os bytes binários do documento PDF (formato A4) pronto para impressão ou pré-visualização.
  ///
  /// Parâmetros:
  /// - [viagem]: Instância do [ViagemModel] com as informações da corrida (motorista, veículo, horários, kms, destino).
  /// - [pacientes]: Lista de [PacienteModel] contendo os passageiros agendados para a viagem.
  /// - [numeroRequisicao]: Número opcional da requisição municipal. Se nulo ou vazio, utiliza o id formatado ou fallback padrão.
  /// - [dataHoraEmissao]: Timestamp da impressão do documento. Se nulo, utiliza a data/hora atual ([DateTime.now]).
  /// - [retornoInformado]: Horário de retorno registrado no encerramento (ex: "16:45").
  /// - [kmSaidaInformado]: Odômetro de saída fornecido manualmente (sobrescreve [viagem.kmInicial] se presente).
  /// - [kmRetornoInformado]: Odômetro de chegada fornecido no encerramento.
  /// - [kmRodadoInformado]: Total de quilômetros percorridos calculado ou informado.
  /// - [usarDoisPontosHorario]: Se verdadeiro (`true`), formata horários como "HH:mm:ss" (padrão formal). Se falso (`false`), formata com espaços ("HH mm ss") replicando o efeito visual do scan original.
  /// - [fonteRegular]: Fonte TrueType regular customizada (ex: LiberationSans-Regular). Se omitida, recorre a Helvetica nativa.
  /// - [fonteBold]: Fonte TrueType negrito customizada (ex: LiberationSans-Bold). Se omitida, recorre a Helvetica-Bold nativa.
  ///
  /// Retorna um [Future<Uint8List>] contendo o fluxo binário do PDF montado.
  static Future<Uint8List> gerarRoteiroViagemPdf({
    required ViagemModel viagem,
    required List<PacienteModel> pacientes,
    String? numeroRequisicao,
    DateTime? dataHoraEmissao,
    String? retornoInformado,
    int? kmSaidaInformado,
    int? kmRetornoInformado,
    int? kmRodadoInformado,
    bool usarDoisPontosHorario = true,
    pw.Font? fonteRegular,
    pw.Font? fonteBold,
    Map<String, String>? viagemIdPorPaciente,
  }) async {
    // Validação de sanidade: quilometragem não pode ser negativa
    if (viagem.kmInicial < 0 || (kmSaidaInformado != null && kmSaidaInformado < 0)) {
      throw ArgumentError('Quilometragem inicial não pode ser negativa: ${viagem.kmInicial}');
    }

    // 1. Inicializa a estrutura de documento em memória do pacote pdf/widgets
    final doc = pw.Document();

    // 2. Define as fontes tipográficas com fallback nativo instantâneo para Helvetica
    final (fRegular, fBold) = _resolverFontes(
      fonteRegular: fonteRegular,
      fonteBold: fonteBold,
    );

    // 3. Define a data e hora de emissão oficial do documento
    final emisso = dataHoraEmissao ?? DateTime.now();

    // 4. Formata o número da requisição com 6 dígitos numéricos (ex: "025059")
    final requisicao = (numeroRequisicao != null && numeroRequisicao.trim().isNotEmpty)
        ? numeroRequisicao.trim()
        : _formatarNumeroRequisicao(viagem.id);

    // 5. Totalização matemática rigorosa conforme regras municipais do TFD
    // Total de Pacientes: contagem cardinal da lista de passageiros principais
    final int totalPacientes = pacientes.length;

    // Total de Acompanhantes: passageiros que possuem nome de acompanhante preenchido e não-vazio
    final int totalAcompanhantes = pacientes
        .where(
          (p) =>
              p.nomeAcompanhante != null &&
              p.nomeAcompanhante!.trim().isNotEmpty,
        )
        .length;

    // Total Geral: soma aritmética exata dos passageiros transportados (Pacientes + Acompanhantes)
    final int totalGeral = totalPacientes + totalAcompanhantes;

    // 6. Executa o algoritmo de paginação dinâmica calculando a capacidade vertical real
    final List<List<PacienteModel>> paginasPacientes = _calcularPaginacao(
      pacientes: pacientes,
    );

    // Garante no mínimo uma página mesmo quando a lista de pacientes for vazia (caso de teste 0 pacientes)
    final int totalPaginas = paginasPacientes.isEmpty
        ? 1
        : paginasPacientes.length;

    // 7. Itera construindo cada uma das páginas calculadas
    for (int numPagina = 1; numPagina <= totalPaginas; numPagina++) {
      // Identificadores de estado da página
      final bool isPrimeiraPagina = (numPagina == 1);
      final bool isUltimaPagina = (numPagina == totalPaginas);

      // Obtém o lote de pacientes atribuído para a página corrente
      final List<PacienteModel> pacientesDestaPagina =
          paginasPacientes.isNotEmpty ? paginasPacientes[numPagina - 1] : [];

      // Adiciona uma página ao documento com o padrão A4 sem margens externas automáticas
      // (as margens são controladas milimetricamente pelo Stack interno)
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // CAMADA 1: Cabeçalho institucional e identificação da viagem
                // Exibido em todas as páginas para manter a rastreabilidade das vias impressas
                _buildCabecalho(
                  viagem: viagem,
                  requisicao: requisicao,
                  isPrimeiraPagina: isPrimeiraPagina,
                  usarDoisPontosHorario: usarDoisPontosHorario,
                  fRegular: fRegular,
                  fBold: fBold,
                ),

                // CAMADA 2: Grade contínua de passageiros da página
                // O Y inicial varia: 124.0 pt na página 1 (abaixo de 'Relação de Passageiros')
                // e 105.0 pt nas páginas seguintes (logo após o destino principal)
                _buildListaPacientes(
                  pacientes: pacientesDestaPagina,
                  yInicial: isPrimeiraPagina
                      ? kAlturaCabecalhoPagina1
                      : kAlturaCabecalhoContinuacao,
                  usarDoisPontosHorario: usarDoisPontosHorario,
                  fRegular: fRegular,
                  fBold: fBold,
                  codigosAcesso: viagem.codigosAcesso,
                  viagemIdPorPaciente: viagemIdPorPaciente,
                  viagemIdPadrao: viagem.id,
                ),

                // CAMADA 3: Rodapé com carimbo temporal 'Emitido em'
                // Presente EXCLUSIVAMENTE na Página 1, conforme evidência do modelo oficial
                if (isPrimeiraPagina)
                  _buildRodapeEmissao(
                    dataEmissao: emisso,
                    usarDoisPontosHorario: usarDoisPontosHorario,
                    fRegular: fRegular,
                  ),

                // CAMADA 4: Bloco de Resumo (Totais, Kms, Horário de Retorno e Assinatura do Motorista)
                // Exibido EXCLUSIVAMENTE na ÚLTIMA PÁGINA do documento
                if (isUltimaPagina)
                  _buildBlocoResumo(
                    totalPacientes: totalPacientes,
                    totalAcompanhantes: totalAcompanhantes,
                    totalGeral: totalGeral,
                    retorno: retornoInformado,
                    kmSaida: kmSaidaInformado ?? viagem.kmInicial,
                    kmRetorno: kmRetornoInformado ?? viagem.kmFinal,
                    kmRodado: kmRodadoInformado ?? viagem.kmRodado,
                    yInicialResumo: _calcularYInicioResumo(
                      numPacientesNaPagina: pacientesDestaPagina.length,
                      isPrimeiraPagina: isPrimeiraPagina,
                    ),
                    fRegular: fRegular,
                    fBold: fBold,
                  ),
              ],
            );
          },
        ),
      );
    }

    // 8. Serializa e compila a árvore de widgets em bytes binários PDF
    return doc.save();
  }

  // ===========================================================================
  // GERAÇÃO EM LOTE DE TODAS AS N VIAGENS ATIVAS (Issue #65)
  // ===========================================================================

  /// Gera em lote um documento PDF oficial para cada uma das N viagens ativas do condutor.
  ///
  /// - Considera todas as N viagens ativas informadas em [viagens];
  /// - Filtra apenas os passageiros com baixa/embarque registrado (status >= 1);
  /// - Atômico: Se a renderização de qualquer uma das viagens falhar, a operação é interrompida
  ///   imediatamente e lança uma exceção com o ID da viagem causadora da falha, não deixando
  ///   resultado parcial inconsistente;
  /// - Idempotente: Execuções subsequentes com os mesmos dados de viagem e passageiros retornam
  ///   sempre o mesmo mapa ordenado de buffers binários.
  ///
  /// Retorna um [Map<String, Uint8List>] indexado pelo ID da viagem correspondente.
  static Future<Map<String, Uint8List>> gerarLoteViagensPdf({
    required List<ViagemModel> viagens,
    Map<String, List<PacienteModel>>? pacientesPorViagem,
    List<PacienteModel>? pacientes,
    DateTime? dataHoraEmissao,
    String? retornoInformado,
    int? kmSaidaInformado,
    int? kmRetornoInformado,
    int? kmRodadoInformado,
    bool usarDoisPontosHorario = true,
    pw.Font? fonteRegular,
    pw.Font? fonteBold,
  }) async {
    // Retorna mapa vazio se nenhuma viagem ativa for fornecida
    if (viagens.isEmpty) {
      return const <String, Uint8List>{};
    }

    final emisso = dataHoraEmissao ?? DateTime.now();
    final Map<String, Uint8List> lotePdfs = {};

    // Itera sequencialmente sobre cada uma das N viagens ativas
    for (final viagem in viagens) {
      try {
        final listaBase = pacientesPorViagem?[viagem.id] ??
            pacientes ??
            const <PacienteModel>[];
        // Filtra apenas os passageiros aos quais o motorista deu baixa/embarcou (status >= 1)
        final passageirosComBaixa =
            listaBase.where((p) => p.status >= 1).toList();

        final pdfBytes = await gerarRoteiroViagemPdf(
          viagem: viagem,
          pacientes: passageirosComBaixa,
          dataHoraEmissao: emisso,
          retornoInformado: retornoInformado,
          kmSaidaInformado: kmSaidaInformado ?? viagem.kmInicial,
          kmRetornoInformado: kmRetornoInformado ?? viagem.kmFinal,
          kmRodadoInformado: kmRodadoInformado ?? viagem.kmRodado,
          usarDoisPontosHorario: usarDoisPontosHorario,
          fonteRegular: fonteRegular,
          fonteBold: fonteBold,
        );

        if (pdfBytes.isEmpty) {
          throw Exception(
            'O documento gerado para a viagem ${viagem.id} resultou em zero bytes.',
          );
        }

        lotePdfs[viagem.id] = pdfBytes;
      } catch (erro) {
        // Atomicidade: lança exceção imediata identificando qual viagem falhou
        throw Exception('Falha ao gerar PDF da viagem [${viagem.id}]: $erro');
      }
    }

    return Map.unmodifiable(lotePdfs);
  }

  // ===========================================================================
  // ALGORITMOS DE PAGINAÇÃO E COORDENADAS DINÂMICAS
  // ===========================================================================

  /// Determina dinamicamente a divisão dos pacientes entre as páginas.
  ///
  /// Em vez de fixar um valor estático (como "11"), a regra é derivada matematicamente
  /// a partir da altura disponível na página dividida pelo pitch vertical de cada paciente:
  ///
  /// - Página 1 sem resumo: Limite vertical seguro antes do rodapé de emissão (700.0 pt).
  ///   Espaço útil = 700.0 pt - 124.0 pt (cabeçalho P1) = 576.0 pt.
  ///   Capacidade = piso(576.0 / 50.7) = 11 pacientes.
  ///
  /// - Página 1 com resumo: Caso o número de pacientes seja pequeno o suficiente
  ///   para acomodar os pacientes e o resumo (95.0 pt) na mesma folha:
  ///   Espaço útil = 576.0 pt - 95.0 pt = 481.0 pt.
  ///   Capacidade = piso(481.0 / 50.7) = 9 pacientes.
  ///
  /// - Páginas de continuação (Página 2+): Cabeçalho menor (105.0 pt) e sem rodapé de emissão.
  ///   Espaço útil sem resumo = (841.89 pt - 30.0 pt) - 105.0 pt = 706.89 pt -> ~13 pacientes.
  ///   Espaço útil com resumo = 706.89 pt - 95.0 pt = 611.89 pt -> ~12 pacientes.
  static List<List<PacienteModel>> _calcularPaginacao({
    required List<PacienteModel> pacientes,
  }) {
    // Caso especial: lista vazia retorna uma página sem pacientes
    if (pacientes.isEmpty) {
      return [[]];
    }

    final List<List<PacienteModel>> resultado = [];
    int indiceAtual = 0;

    // Cálculo da capacidade da Página 1 sem resumo
    const double espacoDisponivelP1 = 700.0 - kAlturaCabecalhoPagina1;
    final int maxP1SemResumo = (espacoDisponivelP1 / kAlturaBlocoPaciente)
        .floor();

    // Cálculo da capacidade da Página 1 com resumo (quando cabe tudo em 1 folha)
    const double espacoDisponivelP1ComResumo =
        espacoDisponivelP1 - kAlturaBlocoResumo;
    final int maxP1ComResumo =
        (espacoDisponivelP1ComResumo / kAlturaBlocoPaciente).floor();

    // Cenário A: Todos os pacientes cabem na Página 1 com o Resumo
    if (pacientes.length <= maxP1ComResumo) {
      resultado.add(pacientes);
      return resultado;
    }

    // Cenário B: Não cabe com o resumo na Página 1.
    // Preenche a Página 1 até a capacidade máxima de pacientes (11 no padrão do modelo)
    final int qtdP1 = pacientes.length >= maxP1SemResumo
        ? maxP1SemResumo
        : pacientes.length;
    resultado.add(pacientes.sublist(0, qtdP1));
    indiceAtual = qtdP1;

    // Capacidade das páginas de continuação (páginas 2 em diante)
    const double limiteInferiorCont = kAlturaPagina - kMargemInferior;
    const double espacoDisponivelContSemResumo =
        limiteInferiorCont - kAlturaCabecalhoContinuacao;
    final int maxContSemResumo =
        (espacoDisponivelContSemResumo / kAlturaBlocoPaciente).floor();

    const double espacoDisponivelContComResumo =
        espacoDisponivelContSemResumo - kAlturaBlocoResumo;
    final int maxContComResumo =
        (espacoDisponivelContComResumo / kAlturaBlocoPaciente).floor();

    // Itera fatiando os pacientes restantes pelas páginas subsequentes
    while (indiceAtual < pacientes.length) {
      final int restantes = pacientes.length - indiceAtual;
      // Se os restantes cabem nesta página juntamente com o bloco de Resumo
      if (restantes <= maxContComResumo) {
        resultado.add(pacientes.sublist(indiceAtual));
        break;
      } else {
        // Preenche com a capacidade máxima sem resumo e cria uma nova folha
        final int qtd = restantes >= maxContSemResumo
            ? maxContSemResumo
            : restantes;
        resultado.add(pacientes.sublist(indiceAtual, indiceAtual + qtd));
        indiceAtual += qtd;
      }
    }

    return resultado;
  }

  /// Calcula a coordenada Y exata em que o bloco 'Resumo' deve ser posicionado na última página.
  ///
  /// Garante que o resumo fique harmonicamente posicionado logo abaixo do último paciente
  /// da página, respeitando o espaçamento do modelo escaneado e prevenindo estouro da margem inferior.
  static double _calcularYInicioResumo({
    required int numPacientesNaPagina,
    required bool isPrimeiraPagina,
  }) {
    // Coordenada onde terminam os cabeçalhos
    final double yBase = isPrimeiraPagina
        ? kAlturaCabecalhoPagina1
        : kAlturaCabecalhoContinuacao;

    // Coordenada inferior do último bloco de paciente desenhado
    final double yAposPacientes =
        yBase + (numPacientesNaPagina * kAlturaBlocoPaciente);

    // Limite máximo de início do Resumo para nunca colidir com o rodapé 'Emitido em'
    // na Página 1 (722.15 pt) nem com a margem inferior nas páginas seguintes
    final double limiteMaximoTopoResumo = isPrimeiraPagina
        ? (722.15 - 10.0 - kAlturaBlocoResumo)
        : (kAlturaPagina - kMargemInferior - kAlturaBlocoResumo);

    // No modelo escaneado (página 2 com 3 pacientes), o resumo começa em ~336 pt
    // 105.0 pt + (3 * 50.7 pt) = 257.1 pt -> margem observada de ~78 pt abaixo do último paciente
    if (yAposPacientes + 78.0 <= limiteMaximoTopoResumo) {
      return yAposPacientes + 78.0;
    } else if (yAposPacientes + 20.0 <= limiteMaximoTopoResumo) {
      // Espaçamento compacto seguro para páginas mais cheias
      return yAposPacientes + 20.0;
    } else {
      return (yAposPacientes + 8.0).clamp(yBase, limiteMaximoTopoResumo);
    }
  }

  // ===========================================================================
  // COMPONENTES DE RENDERIZAÇÃO VISUAL (WIDGETS PDF)
  // ===========================================================================

  /// Constrói o cabeçalho superior do documento contendo os dados institucionais da UBS
  /// e as linhas de identificação da viagem (Motorista, Veículo, Saída, Requisição e Destino).
  ///
  /// O cabeçalho é posicionado no topo de todas as páginas para manter a identificação
  /// do transporte caso as folhas sejam separadas na unidade de saúde.
  static pw.Widget _buildCabecalho({
    required ViagemModel viagem,
    required String requisicao,
    required bool isPrimeiraPagina,
    required bool usarDoisPontosHorario,
    required pw.Font fRegular,
    required pw.Font fBold,
  }) {
    // Formatação da data e hora da saída da viagem
    final dataHoraSaidaFormatada = _formatarDataHora(
      viagem.dataHoraInicio,
      usarDoisPontosHorario,
    );
    final modeloLimpo = viagem.veiculoModelo.trim();
    final placaLimpa = viagem.veiculoPlaca.trim();
    final textoVeiculo = (modeloLimpo.isNotEmpty && placaLimpa.isNotEmpty)
        ? '$modeloLimpo - $placaLimpa'
        : (modeloLimpo.isNotEmpty ? modeloLimpo : placaLimpa);

    return pw.Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Margem superior até o título municipal
          pw.SizedBox(height: kMargemSuperior),

          // LINHA 1 DO CABEÇALHO: Nome da Unidade Básica de Saúde em destaque
          pw.Text(
            'UNIDADE BASICA DE SAUDE DE POLONI',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: fBold,
              fontSize: 15.0,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 2.0),

          // LINHA 2 DO CABEÇALHO: Dados institucionais, endereço, CNPJ e telefone de contato
          pw.Text(
            'RUA ANTONIO MENDES, 140   SANTO ANTONIO POLONI-SP CEP 15162036 CNPJ 10 782 870/0001-13 Fone 17 38199910',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: fRegular,
              fontSize: 7.5,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 8.0),

          // LINHA 3 DO CABEÇALHO: Título oficial do documento operacional
          pw.Text(
            'Roteiro da Viagem - Ficha de Atendimento TFD',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: fBold,
              fontSize: 11.5,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 6.0),

          // BLOCO DE METADADOS DA VIAGEM: Informações da escala e do veículo
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: kMargemEsquerda),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Linha de dados 1: Motorista (flex 3), Veículo (flex 5) e Horário de Saída (largura fixa)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Campo: Motorista escalado
                    pw.Expanded(
                      flex: 3,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 8.0),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Motorista',
                              style: pw.TextStyle(
                                font: fRegular,
                                fontSize: 6.0,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.Text(
                              viagem.motoristaNome.toUpperCase(),
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              style: pw.TextStyle(
                                font: fBold,
                                fontSize: 8.5,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Campo: Veículo (Modelo e Placa)
                    pw.Expanded(
                      flex: 5,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 8.0),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Veículo',
                              style: pw.TextStyle(
                                font: fRegular,
                                fontSize: 6.0,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.Text(
                              textoVeiculo.toUpperCase(),
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              style: pw.TextStyle(
                                font: fRegular,
                                fontSize: 8.5,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Campo: Data e Hora de Saída
                    pw.SizedBox(
                      width: 105.0,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Saída',
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 6.0,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Text(
                            dataHoraSaidaFormatada,
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 8.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5.0),

                // Linha de dados 2: Número de Requisição e Destino Principal da Viagem
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Campo: Requisição (largura fixa 86.0 pt)
                    pw.SizedBox(
                      width: 86.0,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Requisição',
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 6.0,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Text(
                            requisicao,
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 8.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Campo: Destino Principal (município sede do atendimento)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Destino Principal',
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 6.0,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Text(
                            viagem.cidadeDestino.toUpperCase(),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 8.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SUB-TÍTULO "Relação de Passageiros"
          // Exclusivo da Página 1, com espaçamento e linha divisória antes do primeiro passageiro
          if (isPrimeiraPagina) ...[
            pw.SizedBox(height: 10.0),
            pw.Text(
              'Relação de Passageiros',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: fBold,
                fontSize: 11.5,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 5.0),
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: kMargemEsquerda),
              height: 0.5,
              color: PdfColors.grey400,
            ),
          ],
        ],
      ),
    );
  }

  /// Renderiza a lista de passageiros com posicionamento milimétrico individual.
  ///
  /// Cada paciente é acomodado em uma área fixa de altura [kAlturaBlocoPaciente] (50.7 pt),
  /// contendo exatamente 2 linhas de informações conforme a ficha original:
  ///
  /// - Linha 1 do paciente:
  ///   - Paciente: Nome completo (largura 227.0 pt, negrito 7.5 pt)
  ///   - Telefone: Contato do paciente (largura 79.0 pt, negrito 7.5 pt)
  ///   - Acompanhantes: "0" ou "1 NOME ACOMPANHANTE" (expandido, regular 7.5 pt)
  ///   - Telefone acompanhante: Contato do acompanhante (largura 78.0 pt, regular 7.5 pt)
  ///
  /// - Linha 2 do paciente:
  ///   - Endereço: Logradouro do paciente (largura 195.0 pt, regular 7.0 pt)
  ///   - Local de Saída: Ponto de embarque. Se for "Residência" ou vazio, fica em branco (largura 123.0 pt)
  ///   - Destino: Hospital ou clínica de destino (expandido, corte protegido contra sobreposição)
  ///   - Consulta: Horário agendado do procedimento médico (largura fixa 55.0 pt, regular 7.0 pt)
  static pw.Widget _buildListaPacientes({
    required List<PacienteModel> pacientes,
    required double yInicial,
    required bool usarDoisPontosHorario,
    required pw.Font fRegular,
    required pw.Font fBold,
    Map<String, String>? codigosAcesso,
    Map<String, String>? viagemIdPorPaciente,
    String? viagemIdPadrao,
  }) {
    final List<pw.Widget> blocos = [];

    // Itera sobre a lista de pacientes da página gerando cada caixa posicionado
    for (int i = 0; i < pacientes.length; i++) {
      final p = pacientes[i];
      // Calcula o topo Y de cada paciente somando o pitch constante
      final double yPos = yInicial + (i * kAlturaBlocoPaciente);

      // Tratamento de presença de acompanhante:
      // Se houver acompanhante, formata como "1   NOME", caso contrário exibe "0"
      final bool temAcomp =
          (p.nomeAcompanhante != null && p.nomeAcompanhante!.trim().isNotEmpty);
      final String textoAcomp = temAcomp
          ? '1   ${p.nomeAcompanhante!.trim().toUpperCase()}'
          : '0';
      final String telAcomp = (temAcomp && p.telAcompanhante != null)
          ? p.telAcompanhante!.trim()
          : '';

      // Código de acesso temporário do paciente (Issue #65)
      final String? codigo = codigosAcesso?[p.id];
      // ID da viagem do passageiro (exibido antes do CPF quando disponível)
      final String idViagemPac = (viagemIdPorPaciente?[p.id]?.trim().isNotEmpty == true)
          ? viagemIdPorPaciente![p.id]!.trim()
          : (viagemIdPadrao?.trim() ?? '');
      // CPF mascarado para conformidade com LGPD (Issue #65)
      final String cpfMascarado = (p.cpf.isNotEmpty)
          ? CodigoAcessoService.mascararCpf(p.cpf)
          : '';
      final String labelPaciente = (idViagemPac.isNotEmpty && !idViagemPac.startsWith('relatorio_'))
          ? (cpfMascarado.isNotEmpty
              ? 'Viagem: $idViagemPac | CPF: $cpfMascarado'
              : 'Viagem: $idViagemPac')
          : (cpfMascarado.isNotEmpty
              ? 'Paciente (CPF: $cpfMascarado)'
              : 'Paciente');

      // Formatação do horário da consulta com validação de formato
      final String horarioConsultaFmt = _formatarHorario(
        p.horarioConsulta,
        usarDoisPontosHorario,
      );

      // Cria o container posicionado absoluto do passageiro com alinhamento vertical de colunas
      blocos.add(
        pw.Positioned(
          left: kMargemEsquerda,
          right: kMargemDireita,
          top: yPos,
          child: pw.Container(
            height: kAlturaBlocoPaciente - 6.0,
            padding: const pw.EdgeInsets.only(bottom: 4.0),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                // LINHA SUPERIOR DO BLOCO DO PACIENTE
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Coluna 1 (205 pt): ID da Viagem antes do CPF e Nome do Paciente
                    pw.Container(
                      width: 205.0,
                      padding: const pw.EdgeInsets.only(right: 8.0),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            labelPaciente,
                            maxLines: 2,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 5.2,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            p.nome.toUpperCase(),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fBold,
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Coluna 2 (105 pt): Telefone e Código de Acesso
                    pw.Container(
                      width: 105.0,
                      padding: const pw.EdgeInsets.only(right: 8.0),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            (codigo != null && codigo.isNotEmpty)
                                ? 'Telefone / Cód: $codigo'
                                : 'Telefone',
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 5.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            p.telefone,
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fBold,
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Coluna 3 (Expandida): Acompanhantes
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 8.0),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Acompanhantes',
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              style: pw.TextStyle(
                                font: fRegular,
                                fontSize: 5.5,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              textoAcomp,
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              style: pw.TextStyle(
                                font: fRegular,
                                fontSize: 7.5,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Coluna 4 (83 pt): Telefone do Acompanhante
                    pw.SizedBox(
                      width: 83.0,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Telefone acompanhante',
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 5.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            telAcomp,
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4.0),

                // LINHA INFERIOR DO BLOCO DO PACIENTE (colunas perfeitamente alinhadas às de cima)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Coluna 1 (205 pt): Endereço residencial do paciente
                    pw.Container(
                      width: 205.0,
                      padding: const pw.EdgeInsets.only(right: 8.0),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Endereço',
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 5.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            p.enderecoPaciente.toUpperCase(),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 7.0,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Coluna 2 (105 pt): Local de Saída específico (ex: "SANTA CASA")
                    pw.Container(
                      width: 105.0,
                      padding: const pw.EdgeInsets.only(right: 8.0),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Local de Saída',
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 5.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            (p.localSaida == 'Residência' ||
                                    p.localSaida.isEmpty)
                                ? ''
                                : p.localSaida.toUpperCase(),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 7.0,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Coluna 3 (Expandida): Destino / Clínica / Hospital da Consulta
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 8.0),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Destino',
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              style: pw.TextStyle(
                                font: fRegular,
                                fontSize: 5.5,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              p.localConsulta.toUpperCase(),
                              maxLines: 2,
                              style: pw.TextStyle(
                                font: fRegular,
                                fontSize: 6.8,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Coluna 4 (83 pt): Horário agendado da Consulta
                    pw.SizedBox(
                      width: 83.0,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Consulta',
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 5.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            horarioConsultaFmt,
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              font: fRegular,
                              fontSize: 7.0,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Retorna todos os blocos posicionados sobrepostos na pilha da página
    return pw.Stack(children: blocos);
  }

  /// Constrói o rodapé com carimbo temporal 'Emitido em DD/MM/AAAA HH:mm:ss'.
  ///
  /// Conforme medido no modelo oficial, este elemento existe EXCLUSIVAMENTE na Página 1,
  /// posicionado no canto inferior direito a Y = 722.15 pt.
  static pw.Widget _buildRodapeEmissao({
    required DateTime dataEmissao,
    required bool usarDoisPontosHorario,
    required pw.Font fRegular,
  }) {
    // Formatação da data em padrão brasileiro DD/MM/AAAA
    final String dataFmt = DateFormat('dd/MM/yyyy').format(dataEmissao);

    // Formatação da hora respeitando o parâmetro de dois-pontos
    final String horaFmt = usarDoisPontosHorario
        ? DateFormat('HH:mm:ss').format(dataEmissao)
        : DateFormat('HH mm ss').format(dataEmissao);

    return pw.Positioned(
      right: kMargemDireita,
      top: 722.15,
      child: pw.Text(
        'Emitido em  $dataFmt $horaFmt',
        style: pw.TextStyle(
          font: fRegular,
          fontSize: 7.0,
          color: PdfColors.black,
        ),
      ),
    );
  }

  /// Constrói o bloco de fechamento 'Resumo' e a linha para assinatura do motorista.
  ///
  /// Exibido EXCLUSIVAMENTE na última página do documento, reúne:
  /// - Contadores consolidados: Total de Pacientes, Total de Acompanhantes e Total Geral.
  /// - Campos operacionais de encerramento: Retorno, Km Saída, Km Retorno e Km Rodado.
  /// - Linha contínua para assinatura manual física do motorista da viagem.
  static pw.Widget _buildBlocoResumo({
    required int totalPacientes,
    required int totalAcompanhantes,
    required int totalGeral,
    required String? retorno,
    required int? kmSaida,
    required int? kmRetorno,
    required int? kmRodado,
    required double yInicialResumo,
    required pw.Font fRegular,
    required pw.Font fBold,
  }) {
    return pw.Positioned(
      left: 0,
      right: 0,
      top: yInicialResumo,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Título centralizado 'Resumo'
          pw.Text(
            'Resumo',
            style: pw.TextStyle(
              font: fBold,
              fontSize: 10.5,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 5.0),

          // Grade horizontal com as métricas e campos de preenchimento
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 31.0),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Métrica 1: Total de Pacientes (largura 71 pt)
                pw.SizedBox(
                  width: 71.0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total de Pacientes',
                        style: pw.TextStyle(
                          font: fRegular,
                          fontSize: 6.0,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 3.0),
                      pw.Text(
                        '$totalPacientes',
                        style: pw.TextStyle(
                          font: fRegular,
                          fontSize: 8.0,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Métrica 2: Total de Acompanhantes (largura 95 pt)
                pw.SizedBox(
                  width: 95.0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total de Acompanhantes',
                        style: pw.TextStyle(
                          font: fRegular,
                          fontSize: 6.0,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 3.0),
                      pw.Text(
                        '$totalAcompanhantes',
                        style: pw.TextStyle(
                          font: fRegular,
                          fontSize: 8.0,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Métrica 3: Total Geral (soma de pacientes e acompanhantes, largura 105 pt)
                pw.SizedBox(
                  width: 105.0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Geral',
                        style: pw.TextStyle(
                          font: fRegular,
                          fontSize: 6.0,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 3.0),
                      pw.Text(
                        '$totalGeral',
                        style: pw.TextStyle(
                          font: fRegular,
                          fontSize: 8.0,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Campo com linha: Horário de Retorno
                pw.Expanded(
                  child: _buildCampoLinha(
                    rotulo: 'Retorno',
                    valor: retorno,
                    fRegular: fRegular,
                  ),
                ),
                pw.SizedBox(width: 10.0),

                // Campo com linha: Km de Saída do odômetro
                pw.Expanded(
                  child: _buildCampoLinha(
                    rotulo: 'Km Saída',
                    valor: (kmSaida != null && kmSaida > 0) ? '$kmSaida' : null,
                    fRegular: fRegular,
                  ),
                ),
                pw.SizedBox(width: 10.0),

                // Campo com linha: Km de Retorno do odômetro
                pw.Expanded(
                  child: _buildCampoLinha(
                    rotulo: 'Km Retorno',
                    valor: (kmRetorno != null && kmRetorno > 0)
                        ? '$kmRetorno'
                        : null,
                    fRegular: fRegular,
                  ),
                ),
                pw.SizedBox(width: 10.0),

                // Campo com linha: Total de Km Rodado
                pw.Expanded(
                  child: _buildCampoLinha(
                    rotulo: 'Km Rodado',
                    valor: (kmRodado != null && kmRodado > 0)
                        ? '$kmRodado'
                        : null,
                    fRegular: fRegular,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25.0),

          // Linha horizontal física para assinatura manual da ficha pelo motorista
          pw.Container(width: 330.0, height: 0.75, color: PdfColors.black),
          pw.SizedBox(height: 4.0),
          pw.Text(
            'Assinatura do Motorista',
            style: pw.TextStyle(
              font: fRegular,
              fontSize: 7.5,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói um campo com rótulo descritivo superior e linha sublinhada inferior.
  ///
  /// Se o [valor] for informado (ex: encerramento preenchido no app), renderiza o texto
  /// alinhado acima da linha. Se for nulo/vazio, reserva o espaço em branco para
  /// anotação manual com caneta pelo motorista na via física.
  static pw.Widget _buildCampoLinha({
    required String rotulo,
    required String? valor,
    required pw.Font fRegular,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Rótulo do campo em corpo pequeno
        pw.Text(
          rotulo,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            font: fRegular,
            fontSize: 6.0,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 2.0),
        // Exibição do valor preenchido ou espaçamento vazio para caneta
        if (valor != null && valor.isNotEmpty)
          pw.Text(
            valor,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              font: fRegular,
              fontSize: 8.0,
              color: PdfColors.black,
            ),
          )
        else
          pw.SizedBox(height: 10.0),
        // Linha sublinhada demarcatória preta
        pw.Container(height: 0.75, color: PdfColors.black),
      ],
    );
  }

  // ===========================================================================
  // MÉTODOS AUXILIARES DE FORMATAÇÃO E SANITIZAÇÃO
  // ===========================================================================

  /// Formata uma instância [DateTime] para a linha de Saída ("DD/MM/AAAA   HH:mm:ss").
  ///
  /// O parâmetro [usarDoisPontos] define se o separador da hora será ":" ou " ".
  static String _formatarDataHora(DateTime dt, bool usarDoisPontos) {
    final String data = DateFormat('dd/MM/yyyy').format(dt);
    final String hora = usarDoisPontos
        ? DateFormat('HH:mm:ss').format(dt)
        : DateFormat('HH mm ss').format(dt);
    return '$data   $hora';
  }

  /// Formata e padroniza a string de horário de consulta médica.
  ///
  /// - Se o horário estiver vazio, retorna string vazia.
  /// - Se [usarDoisPontos] for falso, substitui ":" por espaços replicando o padrão do scan.
  /// - Se a string contiver apenas hora e minuto (ex: "12:30"), adiciona os segundos ":00"
  ///   para manter a uniformidade visual com o modelo municipal original.
  static String _formatarHorario(String horario, bool usarDoisPontos) {
    if (horario.trim().isEmpty) return '';
    final String limpo = horario.trim();
    if (!usarDoisPontos) {
      return limpo.replaceAll(':', ' ');
    }
    // Caso receba "HH:mm" (tamanho 5), completa com segundos ":00"
    if (limpo.length == 5 && limpo.contains(':')) {
      return '$limpo:00';
    }
    return limpo;
  }
}
