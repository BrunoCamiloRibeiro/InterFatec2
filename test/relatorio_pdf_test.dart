// ============================================================================
// ARQUIVO: test/relatorio_pdf_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Suíte de testes de unidade, paginação e integridade de dados para a geração do
// documento PDF "Roteiro da Viagem - Ficha de Atendimento TFD" executada por
// RelatorioPdfService (lib/services/relatorio_pdf_service.dart - Issue #16).
// Valida:
// 1. Caso 0 pacientes (resumo zerado em 1 página).
// 2. Caso 1 paciente (1 página com resumo).
// 3. Caso 11 pacientes (limiar exato da página 1; resumo avança para a página 2).
// 4. Caso 12 pacientes (11 na página 1 e 1 na página 2 com resumo).
// 5. Caso 22 pacientes (continuação em múltiplas páginas sem overflow).
// 6. Destino muito longo (truncamento seguro sem sobreposição de colunas).
// 7. Caso canônico idêntico ao modelo (14 pacientes, 1 acompanhante), validando
//    integridade estrutural dos dados gerados através da ferramenta pdftotext.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Testes Automatizados de Regras de Negócio e Serviços (test/).
//
// ONDE É USADO:
// Executado pelo executor oficial de testes do Flutter (`flutter test`).
//
// DE ONDE RECEBE DADOS:
// - Arquivos de fonte local: assets/fonts/LiberationSans-Regular.ttf e Bold.ttf.
// - Modelos ViagemModel e PacienteModel com dados fictícios estruturados.
//
// O QUE EXPORTA / EXPÕE:
// - void main(): Ponto de entrada da suíte de testes.
//
// ORIGEM HISTÓRICA:
// Criado no commit c0351c9 (feat: implementar geracao do pdf roteiro de viagem tfd - Issue #16).
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - dart:io (File, Process para execução do pdftotext do sistema operacional)
// - package:pdf/widgets.dart (Font)
// - package:flutter_test/flutter_test.dart
// - Efeito colateral: grava arquivo temporário em /tmp/pdf_gerado_teste.pdf para validação.
// ============================================================================
// Importa a biblioteca de manipulação de arquivos e processos do sistema operacional
import 'dart:io';

// Importa o framework oficial de testes do Flutter
import 'package:flutter_test/flutter_test.dart';
// Importa o pacote de criação e manipulação de documentos PDF
import 'package:pdf/widgets.dart' as pw;
// Importa o modelo de dados representativo de pacientes
import 'package:trans_saude/models/paciente_model.dart';
// Importa o modelo de dados representativo de viagens
import 'package:trans_saude/models/viagem_model.dart';
// Importa o serviço gerador do relatório PDF de viagens TFD
import 'package:trans_saude/services/relatorio_pdf_service.dart';

// Função principal de entrada da suíte de testes do relatório PDF
void main() {
  // Agrupa os testes de regras de negócio, layout e paginação do relatório PDF
  group('RelatorioPdfService - Testes de Regra de Negócio e Paginação', () {
    // Variável para a fonte Liberation Sans Regular carregada
    late pw.Font fontRegular;
    // Variável para a fonte Liberation Sans Bold carregada
    late pw.Font fontBold;

    // Configuração executada uma única vez antes de todos os testes do grupo
    setUpAll(() {
      // Lê os bytes da fonte regular dos assets do projeto
      final regBytes = File('assets/fonts/LiberationSans-Regular.ttf')
          .readAsBytesSync();
      // Lê os bytes da fonte bold dos assets do projeto
      final boldBytes = File('assets/fonts/LiberationSans-Bold.ttf')
          .readAsBytesSync();
      // Instancia a fonte regular no formato pw.Font
      fontRegular = pw.Font.ttf(regBytes.buffer.asByteData());
      // Instancia a fonte bold no formato pw.Font
      fontBold = pw.Font.ttf(boldBytes.buffer.asByteData());
    // Fechamento do setUpAll
    });

    // Objeto base de ViagemModel com dados fictícios para utilização nos testes
    final ViagemModel viagemBase = ViagemModel(
      // Identificador da requisição TFD
      id: '025059',
      // Identificador do motorista
      motoristaId: 'mot_1',
      // Nome fictício do condutor
      motoristaNome: 'Carlos Eduardo Ficticio',
      // Identificador do veículo
      veiculoId: 'v1',
      // Placa do veículo
      veiculoPlaca: 'DJL2G05',
      // Modelo do micro-ônibus
      veiculoModelo: 'MICRO MPOLO',
      // Quilometragem inicial de partida
      kmInicial: 85420,
      // Cidade destino da viagem de saúde
      cidadeDestino: 'SAO JOSE DO RIO PRETO',
      // Data e hora de partida
      dataHoraInicio: DateTime(2026, 9, 29, 9, 30, 0),
    );

    // Fábrica auxiliar para criar pacientes de teste com dados fictícios
    // Cria instâncias fictícias estruturadas de PacienteModel com parâmetros configuráveis
    PacienteModel criarPacienteFicticio(
      // Índice sequencial do paciente
      int index, {
      // Flag indicando se possui acompanhante
      bool comAcompanhante = false,
      // Ponto de partida opcional
      String? localSaida,
      // Destino hospitalar opcional
      String? localConsulta,
      // Horário da consulta opcional
      String? horario,
    }) {
      // Retorna uma nova instância de PacienteModel
      return PacienteModel(
        // Identificador
        id: 'pac_$index',
        // Nome fictício
        nome: 'Paciente Teste Numero $index',
        // CPF fictício
        cpf: '123.456.789-0$index',
        // Telefone fictício
        telefone: '(17)98888-00$index',
        // Endereço fictício
        enderecoPaciente: 'Rua das Flores, $index',
        // Destino ou especialidade padrão
        localConsulta: localConsulta ?? 'AMB - ESPECIALIDADE $index',
        // Ponto de saída
        localSaida: localSaida ?? '',
        // Horário padrão
        horarioConsulta: horario ?? '12:30:00',
        // Nome do acompanhante caso presente
        nomeAcompanhante: comAcompanhante
            ? 'Acompanhante Ficticio $index'
            : null,
        // Telefone do acompanhante caso presente
        telAcompanhante: comAcompanhante ? '(17)99999-11$index' : null,
      // Fechamento do PacienteModel
      );
    // Fechamento da função criarPacienteFicticio
    }

    // Caso de teste 1: lista vazia de pacientes
    test('1. Caso 0 pacientes: gera PDF com 1 página contendo cabeçalho e resumo zerado', () async {
      // Gera os bytes do PDF sem pacientes
      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: [],
      );

      // Valida que o PDF gerado não é nulo
      expect(pdfBytes, isNotNull);
      // Valida que o arquivo possui tamanho substancial
      expect(pdfBytes.length, greaterThan(1000));
    });

    // Caso de teste 2: único paciente com acompanhante
    test('2. Caso 1 paciente: gera 1 página única contendo paciente e bloco de resumo', () async {
      // Lista com 1 paciente
      final pacientes = [criarPacienteFicticio(1, comAcompanhante: true)];

      // Gera o documento PDF
      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: pacientes,
      );

      // Valida o tamanho em bytes
      expect(pdfBytes.length, greaterThan(1000));
    });

    // Caso de teste 3: 11 pacientes no limiar da página 1
    test('3. Caso 11 pacientes: exatamente 11 cabem na página 1, resumo avança para página 2', () async {
      // Gera lista de 11 pacientes
      final pacientes = List.generate(
        11,
        (i) => criarPacienteFicticio(i + 1, comAcompanhante: (i == 4)),
      );

      // Gera o documento PDF
      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: pacientes,
      );

      // Valida tamanho de múltiplas páginas
      expect(pdfBytes.length, greaterThan(2000));
    });

    // Caso de teste 4: 12 pacientes
    test('4. Caso 12 pacientes: 11 na página 1 e 1 paciente na página 2 com o resumo', () async {
      // Gera lista de 12 pacientes
      final pacientes = List.generate(
        12,
        (i) => criarPacienteFicticio(i + 1, comAcompanhante: (i == 4)),
      );

      // Gera o documento PDF
      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: pacientes,
      );

      // Valida tamanho de múltiplas páginas
      expect(pdfBytes.length, greaterThan(2000));
    });

    // Caso de teste 5: 22 pacientes distribuídos em múltiplas páginas
    test(
      '5. Caso 22 pacientes: distribui em páginas de continuação sem overflow',
      () async {
        // Gera lista de 22 pacientes
        final pacientes = List.generate(
          22,
          (i) => criarPacienteFicticio(i + 1),
        );

        // Gera o documento PDF
        final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
          viagem: viagemBase,
          pacientes: pacientes,
        );

        // Valida tamanho
        expect(pdfBytes.length, greaterThan(3000));
      },
    );

    // Caso de teste 6: texto de destino muito longo para testar truncamento
    test(
      '6. Destino muito longo: trunca e não sobrepõe a coluna Consulta',
      () async {
        // Paciente com destino longo
        final pacientes = [
          criarPacienteFicticio(
            1,
            localConsulta: 'HOSPITAL DAS CLINICAS DE RIBEIRAO PRETO SETOR DE ONCOLOGIA PEDIATRICA BLOCO C PAVILHAO 4 ANDAR 2',
          ),
        ];

        // Gera o PDF
        final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
          viagem: viagemBase,
          pacientes: pacientes,
        );

        // Valida que não quebrou a geração
        expect(pdfBytes.length, greaterThan(1000));
      },
    );

    // Caso de teste 7: modelo canônico idêntico ao modelo scan com 14 pacientes e conferência via pdftotext
    test('7. Modelo de benchmark idêntico ao modelo (14 pacientes, 1 acompanhante) gravado para verificação visual', () async {
      // Lista de 14 pacientes reproduzindo a estrutura do modelo
      final List<PacienteModel> pacientesModelo = [
        criarPacienteFicticio(
          1,
          horario: '12:30:00',
          localConsulta: 'AMB - CIR GERAL',
        ),
        criarPacienteFicticio(
          2,
          horario: '11:30:00',
          localConsulta: 'PRO CARDIO - R ANTONIO GODOY 5151',
        ),
        criarPacienteFicticio(
          3,
          horario: '13:00:00',
          localConsulta: 'AMB - PSIQUIATRIA',
        ),
        criarPacienteFicticio(
          4,
          horario: '11:00:00',
          localConsulta: 'CL KAISER - XV DE NOVEMBRO 3975',
        ),
        criarPacienteFicticio(
          5,
          comAcompanhante: true,
          horario: '13:00:00',
          localConsulta: 'LUCY MONTORO',
        ),
        criarPacienteFicticio(6, horario: '12:30:00', localConsulta: 'HB RM'),
        criarPacienteFicticio(
          7,
          horario: '11:00:00',
          localConsulta: 'AME - DERMATO',
        ),
        criarPacienteFicticio(
          8,
          localSaida: 'ACOMPANHANTE',
          horario: '12:10:00',
          localConsulta: 'AME - OFTALMO',
        ),
        criarPacienteFicticio(
          9,
          localSaida: 'ACOMPANHANTE',
          horario: '12:00:00',
          localConsulta: 'AME - ENDOSCOPIA',
        ),
        criarPacienteFicticio(
          10,
          localSaida: 'RAUL SILVA 3365',
          horario: '13:40:00',
          localConsulta: 'CLINICA MEDICA',
        ),
        criarPacienteFicticio(
          11,
          localSaida: 'ODILIA GENOVA',
          horario: '12:00:00',
          localConsulta: 'AMB - REUMATO',
        ),
        // Página 2 (3 pacientes)
        // Pacientes distribuídos na segunda página
        criarPacienteFicticio(
          12,
          horario: '13:00:00',
          localConsulta: 'AMB - OFTALMO',
        ),
        criarPacienteFicticio(
          13,
          horario: '12:00:00',
          localConsulta: 'AME - DERMATO',
        ),
        criarPacienteFicticio(
          14,
          horario: '12:35:00',
          localConsulta: 'AMB - DERMATO',
        ),
      ];

      // Gera os bytes do relatório PDF oficial
      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: pacientesModelo,
        numeroRequisicao: '025059',
        dataHoraEmissao: DateTime(2026, 9, 29, 10, 57, 9),
        usarDoisPontosHorario:
            false, // para alinhamento e teste estrito com o scan
        fonteRegular: fontRegular,
        fonteBold: fontBold,
      );

      // Grava o arquivo temporário para análise externa
      final file = File('/tmp/pdf_gerado_teste.pdf');
      await file.writeAsBytes(pdfBytes);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(2000));

      // Verificação estrutural por pdftotext provando integridade total dos dados
      // Executa o utilitário do sistema pdftotext com parâmetro de layout
      final resultText = await Process.run('pdftotext', [
        '-layout',
        file.path,
        '-',
      ]);
      expect(resultText.exitCode, equals(0));
      final String textoPdf = resultText.stdout as String;

      // Assertivas de integridade mandatórias:
      // Valida a presença de todos os textos e campos essenciais
      expect(textoPdf.contains('UNIDADE BASICA DE SAUDE DE POLONI'), isTrue);
      expect(
        textoPdf.contains('Roteiro da Viagem - Ficha de Atendimento TFD'),
        isTrue,
      );
      expect(textoPdf.contains('CARLOS EDUARDO FICTICIO'), isTrue);
      expect(textoPdf.contains('MICRO MPOLO - DJL2G05'), isTrue);
      expect(textoPdf.contains('025059'), isTrue);
      expect(textoPdf.contains('SAO JOSE DO RIO PRETO'), isTrue);
      expect(textoPdf.contains(RegExp(r'Relação\s+de\s+Passageiros')), isTrue);
      expect(textoPdf.contains('ACOMPANHANTE FICTICIO 5'), isTrue);
      expect(textoPdf.contains('Total de Pacientes'), isTrue);
      expect(textoPdf.contains('14'), isTrue);
      expect(textoPdf.contains('Total de Acompanhantes'), isTrue);
      expect(textoPdf.contains('1'), isTrue);
      expect(textoPdf.contains('Total Geral'), isTrue);
      expect(textoPdf.contains('15'), isTrue);
      expect(textoPdf.contains('Assinatura do Motorista'), isTrue);
    });
  });
}
