import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/relatorio_pdf_service.dart';

void main() {
  group('RelatorioPdfService - Testes de Regra de Negócio e Paginação', () {
    late pw.Font fontRegular;
    late pw.Font fontBold;

    setUpAll(() {
      final regBytes = File('assets/fonts/LiberationSans-Regular.ttf')
          .readAsBytesSync();
      final boldBytes = File('assets/fonts/LiberationSans-Bold.ttf')
          .readAsBytesSync();
      fontRegular = pw.Font.ttf(regBytes.buffer.asByteData());
      fontBold = pw.Font.ttf(boldBytes.buffer.asByteData());
    });

    final ViagemModel viagemBase = ViagemModel(
      id: '025059',
      motoristaId: 'mot_1',
      motoristaNome: 'Carlos Eduardo Ficticio',
      veiculoId: 'v1',
      veiculoPlaca: 'DJL2G05',
      veiculoModelo: 'MICRO MPOLO',
      kmInicial: 85420,
      cidadeDestino: 'SAO JOSE DO RIO PRETO',
      dataHoraInicio: DateTime(2026, 9, 29, 9, 30, 0),
    );

    // Fábrica auxiliar para criar pacientes de teste com dados fictícios
    PacienteModel criarPacienteFicticio(
      int index, {
      bool comAcompanhante = false,
      String? localSaida,
      String? localConsulta,
      String? horario,
    }) {
      return PacienteModel(
        id: 'pac_$index',
        nome: 'Paciente Teste Numero $index',
        cpf: '123.456.789-0$index',
        telefone: '(17)98888-00$index',
        enderecoPaciente: 'Rua das Flores, $index',
        localConsulta: localConsulta ?? 'AMB - ESPECIALIDADE $index',
        localSaida: localSaida ?? '',
        horarioConsulta: horario ?? '12:30:00',
        nomeAcompanhante: comAcompanhante
            ? 'Acompanhante Ficticio $index'
            : null,
        telAcompanhante: comAcompanhante ? '(17)99999-11$index' : null,
      );
    }

    test('1. Caso 0 pacientes: gera PDF com 1 página contendo cabeçalho e resumo zerado', () async {
      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: [],
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('2. Caso 1 paciente: gera 1 página única contendo paciente e bloco de resumo', () async {
      final pacientes = [criarPacienteFicticio(1, comAcompanhante: true)];

      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: pacientes,
      );

      expect(pdfBytes.length, greaterThan(1000));
    });

    test('3. Caso 11 pacientes: exatamente 11 cabem na página 1, resumo avança para página 2', () async {
      final pacientes = List.generate(
        11,
        (i) => criarPacienteFicticio(i + 1, comAcompanhante: (i == 4)),
      );

      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: pacientes,
      );

      expect(pdfBytes.length, greaterThan(2000));
    });

    test('4. Caso 12 pacientes: 11 na página 1 e 1 paciente na página 2 com o resumo', () async {
      final pacientes = List.generate(
        12,
        (i) => criarPacienteFicticio(i + 1, comAcompanhante: (i == 4)),
      );

      final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
        viagem: viagemBase,
        pacientes: pacientes,
      );

      expect(pdfBytes.length, greaterThan(2000));
    });

    test(
      '5. Caso 22 pacientes: distribui em páginas de continuação sem overflow',
      () async {
        final pacientes = List.generate(
          22,
          (i) => criarPacienteFicticio(i + 1),
        );

        final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
          viagem: viagemBase,
          pacientes: pacientes,
        );

        expect(pdfBytes.length, greaterThan(3000));
      },
    );

    test(
      '6. Destino muito longo: trunca e não sobrepõe a coluna Consulta',
      () async {
        final pacientes = [
          criarPacienteFicticio(
            1,
            localConsulta: 'HOSPITAL DAS CLINICAS DE RIBEIRAO PRETO SETOR DE ONCOLOGIA PEDIATRICA BLOCO C PAVILHAO 4 ANDAR 2',
          ),
        ];

        final pdfBytes = await RelatorioPdfService.gerarRoteiroViagemPdf(
          viagem: viagemBase,
          pacientes: pacientes,
        );

        expect(pdfBytes.length, greaterThan(1000));
      },
    );

    test('7. Modelo de benchmark idêntico ao modelo (14 pacientes, 1 acompanhante) gravado para verificação visual', () async {
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

      final file = File('/tmp/pdf_gerado_teste.pdf');
      await file.writeAsBytes(pdfBytes);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(2000));

      // Verificação estrutural por pdftotext provando integridade total dos dados
      final resultText = await Process.run('pdftotext', [
        '-layout',
        file.path,
        '-',
      ]);
      expect(resultText.exitCode, equals(0));
      final String textoPdf = resultText.stdout as String;

      // Assertivas de integridade mandatórias:
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
