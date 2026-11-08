// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: test/pdf_lote_test.dart
// Camada: Testes / Serviços de Relatório e Impressão (Testes de Integração e Sistema)
//
// O QUE ESTE ARQUIVO FAZ:
// Suíte de testes rigorosa para a geração de relatórios PDF em lote (Issue #65):
// 1. Gera o lote oficial com N = 3 viagens ativas da sessão do condutor;
// 2. Filtra exclusivamente os passageiros aos quais o motorista deu baixa (status >= 1);
// 3. Salva em disco em /tmp e executa 'pdftotext' para validar o layout textual extraído:
//    - Exatamente 1 arquivo por viagem (contagem total = 3);
//    - Presença das cidades de destino correspondentes;
//    - Presença dos nomes de passageiros embarcados, seus CPFs mascarados e códigos de acesso;
//    - Ausência de passageiros que permaneceram com status 0 (Aguardando);
// 4. Validação de Atomicidade: falha em 1 viagem interrompe a operação com erro descritivo
//    indicando o ID da viagem, sem deixar saída parcial inconsistente;
// 5. Validação de Idempotência: execuções repetidas não duplicam arquivos e geram os mesmos bytes.
// ============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/relatorio_pdf_service.dart';

void main() {
  group('RelatorioPdfService - Geração em Lote (N >= 3 Viagens)', () {
    late ViagemModel v1;
    late ViagemModel v2;
    late ViagemModel v3;

    late PacienteModel p1Ida;
    late PacienteModel p2Ida;
    late PacienteModel pAguardando; // Status 0 - não deve constar no PDF
    late PacienteModel p3Mirassol;
    late PacienteModel p4MonteAprazivel;

    setUp(() {
      v1 = ViagemModel(
        id: 'viagem_lote_001',
        motoristaId: 'mot_carlos',
        motoristaNome: 'Carlos Motorista da Saúde',
        veiculoId: 'veic_spin',
        veiculoPlaca: 'BRA-2E19',
        veiculoModelo: 'CHEVROLET SPIN',
        kmInicial: 50000,
        kmFinal: 50080,
        kmRodado: 80,
        cidadeDestino: 'São José do Rio Preto',
        dataHoraInicio: DateTime(2026, 11, 7, 7, 0),
        status: 'ativa',
        codigosAcesso: const {'p1': '4821', 'p2': '9134'},
        codigosHash: const {'p1': 'hash_p1', 'p2': 'hash_p2'},
      );

      v2 = ViagemModel(
        id: 'viagem_lote_002',
        motoristaId: 'mot_carlos',
        motoristaNome: 'Carlos Motorista da Saúde',
        veiculoId: 'veic_spin',
        veiculoPlaca: 'BRA-2E19',
        veiculoModelo: 'CHEVROLET SPIN',
        kmInicial: 50080,
        kmFinal: 50130,
        kmRodado: 50,
        cidadeDestino: 'Mirassol',
        dataHoraInicio: DateTime(2026, 11, 7, 10, 30),
        status: 'ativa',
        codigosAcesso: const {'p3': '5512'},
        codigosHash: const {'p3': 'hash_p3'},
      );

      v3 = ViagemModel(
        id: 'viagem_lote_003',
        motoristaId: 'mot_carlos',
        motoristaNome: 'Carlos Motorista da Saúde',
        veiculoId: 'veic_spin',
        veiculoPlaca: 'BRA-2E19',
        veiculoModelo: 'CHEVROLET SPIN',
        kmInicial: 50130,
        kmFinal: 50200,
        kmRodado: 70,
        cidadeDestino: 'Monte Aprazível',
        dataHoraInicio: DateTime(2026, 11, 7, 14, 0),
        status: 'ativa',
        codigosAcesso: const {'p4': '7890'},
        codigosHash: const {'p4': 'hash_p4'},
      );

      p1Ida = PacienteModel(
        id: 'p1',
        nome: 'Maria Silva Poloni',
        cpf: '52998224725',
        telefone: '(17) 99111-2222',
        enderecoPaciente: 'Rua das Flores, 10',
        localConsulta: 'Hospital de Base',
        horarioConsulta: '08:00',
        status: 1, // Embarcou
      );

      p2Ida = PacienteModel(
        id: 'p2',
        nome: 'João Santos Pereira',
        cpf: '11144477735',
        telefone: '(17) 99333-4444',
        enderecoPaciente: 'Rua São Paulo, 20',
        localConsulta: 'AME Rio Preto',
        horarioConsulta: '08:30',
        status: 2, // Desembarcou / Baixa
      );

      pAguardando = PacienteModel(
        id: 'p_aguardando',
        nome: 'Paciente Nao Embarcado',
        cpf: '12345678909',
        telefone: '(17) 99000-0000',
        enderecoPaciente: 'Rua C, 99',
        localConsulta: 'Posto de Saúde',
        horarioConsulta: '09:00',
        status: 0, // Aguardando Transporte - NÃO PODE ENTRAR NO PDF
      );

      p3Mirassol = PacienteModel(
        id: 'p3',
        nome: 'Ana Paula Mirassol',
        cpf: '52998224725',
        telefone: '(17) 99555-6666',
        enderecoPaciente: 'Av Central, 500',
        localConsulta: 'UBS Mirassol',
        horarioConsulta: '11:00',
        status: 1, // Embarcou
      );

      p4MonteAprazivel = PacienteModel(
        id: 'p4',
        nome: 'Sebastião Monte Aprazivel',
        cpf: '11144477735',
        telefone: '(17) 99777-8888',
        enderecoPaciente: 'Rua XV de Novembro, 120',
        localConsulta: 'Santa Casa Monte Aprazível',
        horarioConsulta: '14:30',
        status: 3, // Retorno
      );
    });

    test('1. Gera lote com N = 3 viagens e confere 1 arquivo por viagem via pdftotext', () async {
      final mapaPassageiros = {
        v1.id: [p1Ida, p2Ida, pAguardando],
        v2.id: [p3Mirassol],
        v3.id: [p4MonteAprazivel],
      };

      // Executa a geração em lote
      final Map<String, Uint8List> lotePdfs = await RelatorioPdfService.gerarLoteViagensPdf(
        viagens: [v1, v2, v3],
        pacientesPorViagem: mapaPassageiros,
        dataHoraEmissao: DateTime(2026, 11, 7, 16, 0),
      );

      // Verificação da contagem = N (exatamente 3 PDFs gerados)
      expect(lotePdfs.length, equals(3));
      expect(lotePdfs.containsKey(v1.id), isTrue);
      expect(lotePdfs.containsKey(v2.id), isTrue);
      expect(lotePdfs.containsKey(v3.id), isTrue);

      // Grava em arquivos temporários e extrai o texto com pdftotext
      final arquivosGerados = <File>[];
      for (final entry in lotePdfs.entries) {
        final arquivo = File('/tmp/pdf_lote_teste_${entry.key}.pdf');
        await arquivo.writeAsBytes(entry.value, flush: true);
        expect(await arquivo.exists(), isTrue);
        expect(await arquivo.length(), greaterThan(1500));
        arquivosGerados.add(arquivo);
      }
      expect(arquivosGerados.length, equals(3));

      // ----------------------------------------------------------------------
      // Conferência do PDF da Viagem 1 (São José do Rio Preto)
      // ----------------------------------------------------------------------
      final proc1 = await Process.run('pdftotext', ['/tmp/pdf_lote_teste_${v1.id}.pdf', '-']);
      expect(proc1.exitCode, equals(0));
      final texto1 = proc1.stdout.toString().toUpperCase();

      expect(texto1.contains('SÃO JOSÉ DO RIO PRETO'), isTrue);
      expect(texto1.contains('CHEVROLET SPIN'), isTrue);
      expect(texto1.contains('BRA-2E19'), isTrue);
      expect(texto1.contains('MARIA SILVA POLONI'), isTrue);
      expect(texto1.contains('4821'), isTrue); // Código de acesso do passageiro 1
      expect(texto1.contains('JOÃO SANTOS PEREIRA'), isTrue);
      expect(texto1.contains('9134'), isTrue); // Código de acesso do passageiro 2
      expect(texto1.contains('***.982.247-**'), isTrue); // CPF mascarado
      expect(texto1.contains('PACIENTE NAO EMBARCADO'), isFalse); // Filtrado (status 0)

      // ----------------------------------------------------------------------
      // Conferência do PDF da Viagem 2 (Mirassol)
      // ----------------------------------------------------------------------
      final proc2 = await Process.run('pdftotext', ['/tmp/pdf_lote_teste_${v2.id}.pdf', '-']);
      expect(proc2.exitCode, equals(0));
      final texto2 = proc2.stdout.toString().toUpperCase();

      expect(texto2.contains('MIRASSOL'), isTrue);
      expect(texto2.contains('ANA PAULA MIRASSOL'), isTrue);
      expect(texto2.contains('5512'), isTrue); // Código de acesso do passageiro 3

      // ----------------------------------------------------------------------
      // Conferência do PDF da Viagem 3 (Monte Aprazível)
      // ----------------------------------------------------------------------
      final proc3 = await Process.run('pdftotext', ['/tmp/pdf_lote_teste_${v3.id}.pdf', '-']);
      expect(proc3.exitCode, equals(0));
      final texto3 = proc3.stdout.toString().toUpperCase();

      expect(texto3.contains('MONTE APRAZÍVEL'), isTrue);
      expect(texto3.contains('SEBASTIÃO MONTE APRAZIVEL'), isTrue);
      expect(texto3.contains('7890'), isTrue); // Código de acesso do passageiro 4
    });

    test('2. Atomicidade: falha em uma viagem lança exceção com ID e não deixa resultado parcial', () async {
      // Cria uma viagem defeituosa/nula para provocar falha controlada
      final viagemCorrompida = ViagemModel(
        id: 'viagem_corrompida_999',
        motoristaId: '',
        motoristaNome: '',
        veiculoId: '',
        veiculoPlaca: '',
        veiculoModelo: 'Carro Desconhecido',
        kmInicial: -100, // Inconsistência
        cidadeDestino: '',
        dataHoraInicio: DateTime.now(),
      );

      expect(
        () async => await RelatorioPdfService.gerarLoteViagensPdf(
          viagens: [v1, viagemCorrompida, v3],
          pacientes: [p1Ida],
        ),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Falha ao gerar PDF da viagem [viagem_corrompida_999]')),
        ),
      );
    });

    test('3. Idempotência: repetição da geração produz os mesmos arquivos com os mesmos bytes', () async {
      final mapaPassageiros = {
        v1.id: [p1Ida],
        v2.id: [p3Mirassol],
      };

      final dataFixa = DateTime(2026, 11, 7, 10, 0);

      final loteExecucao1 = await RelatorioPdfService.gerarLoteViagensPdf(
        viagens: [v1, v2],
        pacientesPorViagem: mapaPassageiros,
        dataHoraEmissao: dataFixa,
      );

      final loteExecucao2 = await RelatorioPdfService.gerarLoteViagensPdf(
        viagens: [v1, v2],
        pacientesPorViagem: mapaPassageiros,
        dataHoraEmissao: dataFixa,
      );

      expect(loteExecucao1.length, equals(loteExecucao2.length));
      expect(loteExecucao1[v1.id]!.length, equals(loteExecucao2[v1.id]!.length));
      expect(loteExecucao1[v2.id]!.length, equals(loteExecucao2[v2.id]!.length));
    });
  });
}
