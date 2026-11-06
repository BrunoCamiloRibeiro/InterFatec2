import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/services/pessoa_service.dart';

void main() {
  group('1. Validação de Negócio e LGPD', () {
    test('Rejeita CPFs nulos ou com formato inválido', () {
      expect(ValidacaoPessoa.isCpfValido(null), isFalse);
      expect(ValidacaoPessoa.isCpfValido(''), isFalse);
      expect(ValidacaoPessoa.isCpfValido('123'), isFalse);
      expect(ValidacaoPessoa.isCpfValido('123.456.789-0'), isFalse);
    });

    test('Rejeita CPFs conhecidos com todos os dígitos repetidos', () {
      expect(ValidacaoPessoa.isCpfValido('000.000.000-00'), isFalse);
      expect(ValidacaoPessoa.isCpfValido('111.111.111-11'), isFalse);
      expect(ValidacaoPessoa.isCpfValido('999.999.999-99'), isFalse);
    });

    test(
      'Rejeita CPFs com primeiro ou segundo dígito verificador incorreto',
      () {
        // 123.456.789-00 tem dígitos verificadores inválidos
        expect(ValidacaoPessoa.isCpfValido('123.456.789-00'), isFalse);
      },
    );

    test('Aceita CPFs matematicamente válidos', () {
      // Exemplos de CPFs com dígitos verificadores matematicamente válidos (algoritmo Módulo 11)
      expect(ValidacaoPessoa.isCpfValido('52998224725'), isTrue);
      expect(ValidacaoPessoa.isCpfValido('529.982.247-25'), isTrue);
    });

    test('Rejeita nomes com menos de 3 caracteres', () {
      final erro = ValidacaoPessoa.validarDados(
        nome: 'Jo',
        cpf: '529.982.247-25',
        telefone: '(14) 99876-5432',
        role: 'paciente',
      );
      expect(erro, contains('pelo menos 3 caracteres'));
    });

    test('Rejeita telefones com formato e quantidade de dígitos inválidos', () {
      final erro = ValidacaoPessoa.validarDados(
        nome: 'Maria Silva Santos',
        cpf: '529.982.247-25',
        telefone: '1234',
        role: 'paciente',
      );
      expect(erro, contains('telefone com DDD'));
    });

    test('Rejeita papéis (roles) desconhecidos fora da taxonomia', () {
      final erro = ValidacaoPessoa.validarDados(
        nome: 'Maria Silva Santos',
        cpf: '529.982.247-25',
        telefone: '(14) 99876-5432',
        role: 'astronauta',
      );
      expect(erro, contains('Papel de usuário inválido'));
    });

    test('Aprova dados íntegros e completos', () {
      final erro = ValidacaoPessoa.validarDados(
        nome: 'Maria Silva Santos',
        cpf: '529.982.247-25',
        telefone: '(14) 99876-5432',
        role: 'paciente',
      );
      expect(erro, isNull);
    });
  });

  group('2. ResultadoOperacaoPessoa - Contrato de Resposta', () {
    test('Sucesso encapsula id sem erros', () {
      final res = ResultadoOperacaoPessoa.sucesso('doc_123');
      expect(res.sucesso, isTrue);
      expect(res.id, equals('doc_123'));
      expect(res.mensagemErro, isNull);
    });

    test('Erro encapsula mensagem descritiva', () {
      final res = ResultadoOperacaoPessoa.erro('Falha de permissão');
      expect(res.sucesso, isFalse);
      expect(res.id, isNull);
      expect(res.mensagemErro, equals('Falha de permissão'));
    });
  });
}
