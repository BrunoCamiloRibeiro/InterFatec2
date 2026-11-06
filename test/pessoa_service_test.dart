import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/services/pessoa_service.dart';

/// ============================================================================
/// SUÍTE DE TESTES UNITÁRIOS: VALIDAÇÃO DE PESSOAS E CONTRATO DE OPERAÇÃO
/// ============================================================================
/// Cobre as regras puras de negócio para cadastro de pessoas (Issue #34):
/// - Algoritmo oficial da Receita Federal (Módulo 11) para validação de CPF.
/// - Regras de formato e higienização cadastral (Nome, Telefone, Papéis do SUS).
/// - Contratos de resposta estruturada para operações assíncronas do Firestore.
void main() {
  group('1. Validação de Negócio e LGPD', () {
    test('Rejeita CPFs nulos ou com formato inválido', () {
      // Valida que entradas vazias, nulas ou truncadas são sumariamente recusadas
      expect(ValidacaoPessoa.isCpfValido(null), isFalse);
      expect(ValidacaoPessoa.isCpfValido(''), isFalse);
      expect(ValidacaoPessoa.isCpfValido('123'), isFalse);
      expect(ValidacaoPessoa.isCpfValido('123.456.789-0'), isFalse);
    });

    test('Rejeita CPFs conhecidos com todos os dígitos repetidos', () {
      // Impede fraudes comuns de CPFs matematicamente válidos mas bloqueados por convenção
      expect(ValidacaoPessoa.isCpfValido('000.000.000-00'), isFalse);
      expect(ValidacaoPessoa.isCpfValido('111.111.111-11'), isFalse);
      expect(ValidacaoPessoa.isCpfValido('999.999.999-99'), isFalse);
    });

    test(
      'Rejeita CPFs com primeiro ou segundo dígito verificador incorreto',
      () {
        // Valida que CPFs com 11 dígitos mas cálculo de módulo incorreto são rejeitados
        expect(ValidacaoPessoa.isCpfValido('123.456.789-00'), isFalse);
      },
    );

    test('Aceita CPFs matematicamente válidos', () {
      // Exemplos de CPFs com dígitos verificadores matematicamente válidos (algoritmo Módulo 11)
      expect(ValidacaoPessoa.isCpfValido('52998224725'), isTrue);
      expect(ValidacaoPessoa.isCpfValido('529.982.247-25'), isTrue);
    });

    test('Rejeita nomes com menos de 3 caracteres', () {
      // Garante integridade cadastral e conformidade com nomes completos no SUS
      final erro = ValidacaoPessoa.validarDados(
        nome: 'Jo',
        cpf: '529.982.247-25',
        telefone: '(14) 99876-5432',
        role: 'paciente',
      );
      expect(erro, contains('pelo menos 3 caracteres'));
    });

    test('Rejeita telefones com formato e quantidade de dígitos inválidos', () {
      // Garante que o telefone possua DDD e número mínimo para contato de emergência
      final erro = ValidacaoPessoa.validarDados(
        nome: 'Maria Silva Santos',
        cpf: '529.982.247-25',
        telefone: '1234',
        role: 'paciente',
      );
      expect(erro, contains('telefone com DDD'));
    });

    test('Rejeita papéis (roles) desconhecidos fora da taxonomia', () {
      // Garante restrição de acesso aos três perfis oficiais do sistema: paciente, motorista e admin
      final erro = ValidacaoPessoa.validarDados(
        nome: 'Maria Silva Santos',
        cpf: '529.982.247-25',
        telefone: '(14) 99876-5432',
        role: 'astronauta',
      );
      expect(erro, contains('Papel de usuário inválido'));
    });

    test('Aprova dados íntegros e completos', () {
      // Garante que dados em formato correto não geram mensagens de erro
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
      // Valida contrato funcional de sucesso para persistência no Firestore
      final res = ResultadoOperacaoPessoa.sucesso('doc_123');
      expect(res.sucesso, isTrue);
      expect(res.id, equals('doc_123'));
      expect(res.mensagemErro, isNull);
    });

    test('Erro encapsula mensagem descritiva', () {
      // Valida contrato funcional de erro amigável para exibição na interface
      final res = ResultadoOperacaoPessoa.erro('Falha de permissão');
      expect(res.sucesso, isFalse);
      expect(res.id, isNull);
      expect(res.mensagemErro, equals('Falha de permissão'));
    });
  });
}
