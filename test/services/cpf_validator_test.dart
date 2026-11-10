// ============================================================================
// ARQUIVO: test/services/cpf_validator_test.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Testes unitários para o validador oficial de CPF (CpfValidator):
// - Validação de CPFs reais e válidos
// - Rejeição de formatos inválidos, vazios ou com letras
// - Rejeição de CPFs com dígitos repetidos (00000000000 ... 99999999999)
// - Rejeição de CPFs com dígitos verificadores matematicamente incorretos
// - Derivação determinística de e-mail sintético para o Firebase Auth
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/services/cpf_validator.dart';

void main() {
  group('CpfValidator - Validação Matemática e Sanitização', () {
    test('Valida CPFs matematicamente válidos (com e sem pontuação)', () {
      // CPFs válidos oficiais da Receita Federal
      expect(CpfValidator.validar('529.982.247-25'), isTrue);
      expect(CpfValidator.validar('52998224725'), isTrue);
      expect(CpfValidator.validar('180.879.890-23'), isTrue);
      expect(CpfValidator.validar('234.567.890-92'), isTrue);
      expect(CpfValidator.validar('678.901.234-69'), isTrue);
    });

    test('Rejeita CPFs com menos ou mais de 11 dígitos', () {
      expect(CpfValidator.validar(null), isFalse);
      expect(CpfValidator.validar(''), isFalse);
      expect(CpfValidator.validar('123'), isFalse);
      expect(CpfValidator.validar('1234567890'), isFalse);
      expect(CpfValidator.validar('123456789012'), isFalse);
    });

    test('Rejeita sequências de dígitos todos iguais (fraude conhecida)', () {
      for (int i = 0; i <= 9; i++) {
        final repetido = '$i' * 11;
        expect(CpfValidator.validar(repetido), isFalse, reason: 'Deveria rejeitar $repetido');
      }
    });

    test('Rejeita CPFs com dígitos verificadores incorretos', () {
      // 529.982.247-25 é válido; vamos alterar o último dígito
      expect(CpfValidator.validar('529.982.247-24'), isFalse);
      expect(CpfValidator.validar('529.982.247-26'), isFalse);
      expect(CpfValidator.validar('180.879.890-00'), isFalse);
    });

    test('Limpa caracteres não numéricos corretamente', () {
      expect(CpfValidator.limpar('180.879.890-23'), equals('18087989023'));
      expect(CpfValidator.limpar('abc 180 - 879'), equals('180879'));
      expect(CpfValidator.limpar(null), equals(''));
    });

    test('Formata CPF para padrão 000.000.000-00', () {
      expect(CpfValidator.formatar('18087989023'), equals('180.879.890-23'));
      expect(CpfValidator.formatar('180.879.890-23'), equals('180.879.890-23'));
    });

    test('Deriva e-mail sintético institucional', () {
      expect(
        CpfValidator.derivarEmail('180.879.890-23'),
        equals('18087989023@transsaude.sp.gov.br'),
      );
      expect(
        CpfValidator.derivarEmail('52998224725'),
        equals('52998224725@transsaude.sp.gov.br'),
      );
    });
  });
}
