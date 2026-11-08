// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: test/services/codigo_acesso_service_test.dart
// Camada: Testes / Segurança e Autenticação de Pacientes (Testes Unitários)
//
// O QUE ESTE ARQUIVO FAZ:
// Suíte completa de testes unitários e de propriedades matemáticas para
// CodigoAcessoService (Issue #65):
// 1. Formato estrito do código: numérico de 4 a 5 dígitos (1000 a 99999);
// 2. Teste de propriedade com 2.000 gerações pseudo-aleatórias seguras;
// 3. Unicidade de códigos de acesso dentro do escopo da mesma viagem;
// 4. Cálculo e validação de hash SHA-256 com salt por viagem;
// 5. Validação rigorosa de CPFs (algoritmo módulo 11) e normalização de documentos;
// 6. Mascaramento de dados sensíveis para conformidade com a LGPD;
// 7. Resolução hierárquica do identificador civil em todos os casos de borda:
//    (a) CPF do paciente válido;
//    (b) CPF vazio/inválido com acompanhante -> CPF do acompanhante;
//    (c) Sem acompanhante -> outro documento informado (RG, CNH);
//    (d) Nenhum documento -> ignorado com aviso de auditoria anônimo;
//    (e) CPF repetido entre titular e acompanhante;
//    (f) Acompanhante responsável por múltiplos pacientes;
// 8. Proteção contra força bruta (Rate Limiting por CPF e IP):
//    - Bloqueio após 5 tentativas incorretas dentro da janela de 10 minutos;
//    - Duração do bloqueio de 15 minutos e expiração temporal;
//    - Liberação imediata após login bem-sucedido.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/services/codigo_acesso_service.dart';

void main() {
  setUp(() {
    CodigoAcessoService.resetarRateLimitParaTestes();
  });

  tearDown(() {
    CodigoAcessoService.resetarRateLimitParaTestes();
  });

  group('CodigoAcessoService - Formato e Propriedades Criptográficas', () {
    test('1. Código gerado é puramente numérico e possui exatamente 4 ou 5 dígitos', () {
      final codigo = CodigoAcessoService.gerarCodigoNumerico();
      expect(codigo, matches(RegExp(r'^\d{4,5}$')));
      final valorNumerico = int.parse(codigo);
      expect(valorNumerico, greaterThanOrEqualTo(1000));
      expect(valorNumerico, lessThanOrEqualTo(99999));
    });

    test('2. Teste de Propriedade: 2000 gerações consecutivas mantêm formato e limites 4-5 dígitos', () {
      final gerados = <String>{};
      for (int i = 0; i < 2000; i++) {
        final cod = CodigoAcessoService.gerarCodigoNumerico();
        expect(cod.length, inInclusiveRange(4, 5));
        expect(int.tryParse(cod), isNotNull);
        final numVal = int.parse(cod);
        expect(numVal >= 1000 && numVal <= 99999, isTrue);
        gerados.add(cod);
      }
      // Garante alta dispersão de entropia: em 2000 sorteios, deve haver ampla variedade
      expect(gerados.length, greaterThan(1500));
    });

    test('3. Unicidade dentro da viagem: nunca gera código já existente na coleção', () {
      final existentes = <String>{'1234', '5678', '99999', '1000'};
      for (int i = 0; i < 50; i++) {
        final novo = CodigoAcessoService.gerarCodigoUnicoNaViagem(existentes);
        expect(existentes.contains(novo), isFalse);
        expect(novo, matches(RegExp(r'^\d{4,5}$')));
      }
    });

    test('4. Hash criptográfico com salt da viagem é determinístico e isolado por viagem', () {
      const codigo = '12345';
      const viagem1 = 'viagem_001';
      const viagem2 = 'viagem_002';

      final hash1 = CodigoAcessoService.calcularHash(codigo, viagem1);
      final hash1Repetido = CodigoAcessoService.calcularHash(codigo, viagem1);
      final hash2 = CodigoAcessoService.calcularHash(codigo, viagem2);

      expect(hash1, equals(hash1Repetido));
      expect(hash1, isNot(equals(hash2)));
      expect(hash1.length, equals(64)); // SHA-256 hex string

      expect(
        CodigoAcessoService.validarCodigoContraHash(
          codigoDigitado: codigo,
          saltViagem: viagem1,
          hashArmazenado: hash1,
        ),
        isTrue,
      );

      expect(
        CodigoAcessoService.validarCodigoContraHash(
          codigoDigitado: '54321',
          saltViagem: viagem1,
          hashArmazenado: hash1,
        ),
        isFalse,
      );
    });
  });

  group('CodigoAcessoService - Validação de CPF e Mascaramento LGPD', () {
    test('5. Validação de CPFs conhecidos (válidos vs dígitos verificadores corrompidos)', () {
      // CPFs válidos conhecidos
      expect(CodigoAcessoService.validarCpf('123.456.789-09'), isTrue);
      expect(CodigoAcessoService.validarCpf('52998224725'), isTrue);
      expect(CodigoAcessoService.validarCpf('11144477735'), isTrue);

      // CPFs com dígitos inválidos ou repetidos
      expect(CodigoAcessoService.validarCpf('111.111.111-11'), isFalse);
      expect(CodigoAcessoService.validarCpf('00000000000'), isFalse);
      expect(CodigoAcessoService.validarCpf('123.456.789-00'), isFalse);
      expect(CodigoAcessoService.validarCpf('123'), isFalse);
      expect(CodigoAcessoService.validarCpf(''), isFalse);
    });

    test('6. Normalização de documentos extrai estritamente dígitos', () {
      expect(CodigoAcessoService.normalizarDigitos(' 123.456.789-00 '), equals('12345678900'));
      expect(CodigoAcessoService.normalizarDigitos('RG 12.345.678-X'), equals('12345678'));
      expect(CodigoAcessoService.normalizarDocumento('ABC 999'), equals('999'));
    });

    test('7. Mascaramento LGPD não revela CPF nem código completo', () {
      expect(CodigoAcessoService.mascararCpf('12345678909'), equals('***.456.789-**'));
      expect(CodigoAcessoService.mascararCpf('123.456.789-09'), equals('***.456.789-**'));
      expect(CodigoAcessoService.mascararCodigo('1234'), equals('***34'));
      expect(CodigoAcessoService.mascararCodigo('12345'), equals('***45'));
    });
  });

  group('CodigoAcessoService - Resolução Hierárquica do Identificador', () {
    test('8. Caso (a): CPF titular do paciente é prioridade máxima', () {
      final res = CodigoAcessoService.resolverIdentificador(
        cpfPaciente: '529.982.247-25',
        cpfAcompanhante: '111.444.777-35',
        outroDocumento: 'RG 45.123.456-7',
        pacienteId: 'p1',
        pacienteNome: 'João Silva',
      );
      expect(res.tipo, equals('cpf_paciente'));
      expect(res.documentoNormalizado, equals('52998224725'));
      expect(res.isAcompanhante, isFalse);
    });

    test('9. Caso (b): CPF do paciente ausente/inválido resolve para CPF do acompanhante', () {
      final res = CodigoAcessoService.resolverIdentificador(
        cpfPaciente: '', // Criança sem CPF cadastrado
        cpfAcompanhante: '529.982.247-25', // Mãe/Pai acompanhante
        outroDocumento: 'Certidão 123',
        pacienteId: 'p_crianca',
        pacienteNome: 'Enzo Criança',
      );
      expect(res.tipo, equals('cpf_acompanhante'));
      expect(res.documentoNormalizado, equals('52998224725'));
      expect(res.isAcompanhante, isTrue);
    });

    test('10. Caso (c): Sem acompanhante e sem CPF resolve para outro documento (RG/CNH)', () {
      final res = CodigoAcessoService.resolverIdentificador(
        cpfPaciente: null,
        cpfAcompanhante: null,
        outroDocumento: 'RG 451234567',
        pacienteId: 'p_idoso',
        pacienteNome: 'Idoso Teste',
      );
      expect(res.tipo, equals('outro_documento'));
      expect(res.documentoNormalizado, equals('RG 451234567'));
      expect(res.isAcompanhante, isFalse);
    });

    test('11. Caso (d): Nenhum documento disponível é ignorado com log anonimizado', () {
      final res = CodigoAcessoService.resolverIdentificador(
        cpfPaciente: null,
        cpfAcompanhante: null,
        outroDocumento: null,
      );
      expect(res.tipo, equals('ignorado'));
      expect(res.documentoNormalizado, isNull);
      expect(res.logAnonimizado, contains('sem documento'));
    });

    test('12. Caso (e): CPF repetido entre titular e acompanhante resolve com sucesso', () {
      const mesmoCpf = '529.982.247-25';
      final res = CodigoAcessoService.resolverIdentificador(
        cpfPaciente: mesmoCpf,
        cpfAcompanhante: mesmoCpf,
        outroDocumento: null,
      );
      expect(res.tipo, equals('cpf_paciente'));
      expect(res.documentoNormalizado, equals('52998224725'));
    });

    test('13. Caso (f): Acompanhante atendendo múltiplos pacientes resolve o CPF compartilhado', () {
      const cpfMae = '529.982.247-25';
      final pacienteFilho1 = PacienteModel(
        id: 'filho_1',
        nome: 'Filho Um',
        cpf: '',
        telefone: '17999990001',
        enderecoPaciente: 'Rua A',
        localConsulta: 'Hospital',
        cpfAcompanhante: cpfMae,
        nomeAcompanhante: 'Mãe Teste',
      );
      final pacienteFilho2 = PacienteModel(
        id: 'filho_2',
        nome: 'Filho Dois',
        cpf: '',
        telefone: '17999990002',
        enderecoPaciente: 'Rua A',
        localConsulta: 'Hospital',
        cpfAcompanhante: cpfMae,
        nomeAcompanhante: 'Mãe Teste',
      );

      final res1 = CodigoAcessoService.resolverIdentificadorLogin(pacienteFilho1);
      final res2 = CodigoAcessoService.resolverIdentificadorLogin(pacienteFilho2);

      expect(res1.documentoNormalizado, equals('52998224725'));
      expect(res2.documentoNormalizado, equals('52998224725'));
      expect(res1.isAcompanhante, isTrue);
      expect(res2.isAcompanhante, isTrue);
    });
  });

  group('CodigoAcessoService - Rate Limiting e Prevenção contra Força Bruta', () {
    test('14. Bloqueia após 5 tentativas incorretas consecutivas e desbloqueia após 15 minutos', () {
      const idAlvo = '52998224725';
      final t0 = DateTime(2026, 11, 7, 10, 0, 0);

      expect(CodigoAcessoService.estaBloqueado(idAlvo, agora: t0), isFalse);

      // 4 tentativas com falha
      for (int i = 1; i <= 4; i++) {
        final bloqueou = CodigoAcessoService.registrarTentativaFalha(
          idAlvo,
          agora: t0.add(Duration(seconds: i * 10)),
        );
        expect(bloqueou, isFalse);
        expect(CodigoAcessoService.estaBloqueado(idAlvo, agora: t0.add(Duration(seconds: i * 10))), isFalse);
      }

      // 5ª tentativa falha: aciona o bloqueio temporário
      final bloqueouNaQuinta = CodigoAcessoService.registrarTentativaFalha(
        idAlvo,
        agora: t0.add(const Duration(seconds: 50)),
      );
      expect(bloqueouNaQuinta, isTrue);

      // Bloqueado aos 10 minutos
      final tDuranteBloqueio = t0.add(const Duration(minutes: 10));
      expect(CodigoAcessoService.estaBloqueado(idAlvo, agora: tDuranteBloqueio), isTrue);

      // Desbloqueado aos 16 minutos (passou a janela de 15 min de punição)
      final tAposExpiracao = t0.add(const Duration(minutes: 16));
      expect(CodigoAcessoService.estaBloqueado(idAlvo, agora: tAposExpiracao), isFalse);
    });

    test('15. Bloqueio por IP funciona em conjunto com CPF', () {
      const cpf = '52998224725';
      const ip = '192.168.1.100';
      final agora = DateTime(2026, 11, 7, 12, 0, 0);

      // Registra 5 falhas associando CPF e IP
      for (int i = 0; i < 5; i++) {
        CodigoAcessoService.registrarTentativaFalha(cpf, ip: ip, agora: agora);
      }

      expect(CodigoAcessoService.estaBloqueado(cpf, agora: agora), isTrue);
      expect(CodigoAcessoService.estaBloqueado('outro_cpf', ip: ip, agora: agora), isTrue);
    });

    test('16. Sucesso no login limpa o histórico de falhas imediatamente', () {
      const idAlvo = '52998224725';
      final t0 = DateTime(2026, 11, 7, 10, 0, 0);

      // 4 falhas registradas
      for (int i = 0; i < 4; i++) {
        CodigoAcessoService.registrarTentativaFalha(idAlvo, agora: t0);
      }

      // Autenticação com sucesso limpa as tentativas
      CodigoAcessoService.registrarSucesso(idAlvo);

      // Uma nova falha agora começa do zero (não bloqueia na 1ª tentativa)
      final bloqueou = CodigoAcessoService.registrarTentativaFalha(idAlvo, agora: t0);
      expect(bloqueou, isFalse);
    });
  });
}
