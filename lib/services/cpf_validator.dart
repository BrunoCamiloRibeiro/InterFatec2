// ============================================================================
// ARQUIVO: lib/services/cpf_validator.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa a validação matemática oficial do Cadastro de Pessoas Físicas (CPF)
// da Receita Federal do Brasil (módulo 11), sanitização de caracteres e
// derivação de e-mail sintético determinístico para o Firebase Authentication.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Serviços / Utilitários de Domínio e Segurança.
//
// ONDE É USADO:
// - lib/services/auth_service.dart (validação prévia antes de autenticar)
// - lib/screens/login_screen.dart (validação síncrona no formulário)
// - lib/components/formulario_pessoa.dart (validação no cadastro de pessoas)
// - test/services/cpf_validator_test.dart (testes unitários exaustivos)
// ============================================================================

/// Utilitário oficial de validação e sanitização de CPF.
class CpfValidator {
  const CpfValidator._();

  /// Remove qualquer caractere não numérico da string informada.
  static String limpar(String? cpf) {
    if (cpf == null) return '';
    return cpf.replaceAll(RegExp(r'\D'), '');
  }

  /// Valida se a string fornecida representa um CPF matematicamente válido.
  ///
  /// Requisitos:
  /// 1. Exatamente 11 dígitos numéricos após limpeza.
  /// 2. Rejeição de sequências com todos os dígitos idênticos (ex.: 111.111.111-11).
  /// 3. Verificação exata do 1º e do 2º dígitos verificadores pelo algoritmo módulo 11.
  static bool validar(String? cpf) {
    final digitos = limpar(cpf);

    // Checagem de comprimento
    if (digitos.length != 11) return false;

    // Checagem de números repetidos conhecidos (todos dígitos iguais)
    final todosIguais = RegExp(r'^(\d)\1{10}$').hasMatch(digitos);
    if (todosIguais) return false;

    // Cálculo do primeiro dígito verificador (pesos de 10 a 2)
    int soma1 = 0;
    for (int i = 0; i < 9; i++) {
      soma1 += int.parse(digitos[i]) * (10 - i);
    }
    int resto1 = (soma1 * 10) % 11;
    if (resto1 == 10 || resto1 == 11) resto1 = 0;
    if (resto1 != int.parse(digitos[9])) return false;

    // Cálculo do segundo dígito verificador (pesos de 11 a 2)
    int soma2 = 0;
    for (int i = 0; i < 10; i++) {
      soma2 += int.parse(digitos[i]) * (11 - i);
    }
    int resto2 = (soma2 * 10) % 11;
    if (resto2 == 10 || resto2 == 11) resto2 = 0;
    if (resto2 != int.parse(digitos[10])) return false;

    return true;
  }

  /// Formata uma sequência de 11 dígitos numéricos no padrão 000.000.000-00.
  static String formatar(String? cpf) {
    final digitos = limpar(cpf);
    if (digitos.length != 11) return digitos;
    return '${digitos.substring(0, 3)}.${digitos.substring(3, 6)}.${digitos.substring(6, 9)}-${digitos.substring(9, 11)}';
  }

  /// Deriva o e-mail sintético determinístico aceito pelo Firebase Auth.
  /// Exemplo: '180.879.890-23' -> '18087989023@transsaude.sp.gov.br'
  static String derivarEmail(String? cpf, {String dominio = 'transsaude.sp.gov.br'}) {
    final digitos = limpar(cpf);
    return '$digitos@$dominio';
  }
}
