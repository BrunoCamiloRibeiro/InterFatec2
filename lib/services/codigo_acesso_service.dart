// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/services/codigo_acesso_service.dart
// Camada: Serviços / Segurança e Autenticação de Passageiros (Services)
//
// O QUE ESTE ARQUIVO FAZ:
// Implementa a lógica central de segurança da Issue #65 para acesso de pacientes:
// 1. Geração criptograficamente segura de códigos de acesso numéricos (4 a 5 dígitos);
// 2. Garantia de unicidade de códigos dentro da mesma viagem;
// 3. Cálculo de hash HMAC/SHA-256 para persistência segura e validação de autenticação;
// 4. Rate limiting e proteção contra ataques de força bruta com bloqueio temporário;
// 5. Validação algorítmica de dígitos verificadores do CPF (módulo 11) e normalização;
// 6. Resolução hierárquica do identificador civil (CPF paciente -> acompanhante -> RG/CNH);
// 7. Mascaramento LGPD de dados sensíveis para logs e visualizações (CPF e código).
//
// PARA QUE SERVE NO PROJETO:
// Substitui a senha fixa de pacientes pelo código dinâmico gerado no embarque,
// garantindo conformidade com a LGPD e prevenindo ataques de enumeração e força bruta.
//
// ONDE É USADO NO PROJETO:
// - lib/services/viagem_service.dart (geração do código ao registrar embarque)
// - lib/services/auth_service.dart (autenticação de paciente com CPF + código)
// - lib/screens/login_screen.dart (submissão do formulário de paciente)
// - lib/components/card_paciente.dart (exibição do código após embarque)
// - test/services/codigo_acesso_service_test.dart
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'dart:math' (Random.secure), 'dart:convert' e 'package:crypto/crypto.dart'.
// Mantém cache em memória para rate limiting contra ataques de força bruta.
// ============================================================================

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../models/paciente_model.dart';

/// Resultado da resolução de identidade para login de paciente.
class ResolucaoIdentificador {
  /// Tipo de documento resolvido ('cpf_paciente', 'cpf_acompanhante', 'outro_documento', 'ignorado').
  final String tipo;

  /// Documento normalizado (somente dígitos ou caracteres válidos).
  final String? documentoNormalizado;

  /// ID do paciente titular vinculado.
  final String? pacienteId;

  /// Nome do titular ou acompanhante identificado.
  final String? titularNome;

  /// Se o documento informado é do acompanhante responsável por um ou mais pacientes.
  final bool isAcompanhante;

  /// Mensagem de diagnóstico anônima (sem expor PII) para logs internos.
  final String logAnonimizado;

  const ResolucaoIdentificador({
    required this.tipo,
    this.documentoNormalizado,
    this.pacienteId,
    this.titularNome,
    this.isAcompanhante = false,
    required this.logAnonimizado,
  });
}

/// Serviço especializado no ciclo de vida de códigos de acesso e proteção LGPD.
class CodigoAcessoService {
  /// Gerador criptográfico seguro do sistema operacional.
  static final Random _secureRandom = Random.secure();

  /// Registro de tentativas falhas por identificador (CPF ou IP) para rate limiting.
  /// Identificador -> Lista de timestamps das tentativas nos últimos minutos.
  static final Map<String, List<DateTime>> _tentativasFalhas = {};

  /// Registro de bloqueios ativos com data/hora de liberação.
  /// Identificador -> Timestamp até quando está bloqueado.
  static final Map<String, DateTime> _bloqueiosAtivos = {};

  /// Quantidade máxima de tentativas permitidas antes do bloqueio temporário.
  static const int kMaxTentativas = 5;

  /// Duração do bloqueio temporário após exceder o limite de tentativas.
  static const Duration kDuracaoBloqueio = Duration(minutes: 15);

  /// Janela temporal para contabilização das tentativas falhas.
  static const Duration kJanelaTentativas = Duration(minutes: 10);

  // ===========================================================================
  // 1. GERAÇÃO E HASH DE CÓDIGO DE ACESSO
  // ===========================================================================

  /// Gera um código de acesso aleatório numérico de 4 a 5 dígitos (entre 1000 e 99999).
  ///
  /// Utiliza [Random.secure] garantindo aleatoriedade com entropia do sistema operacional
  /// (nunca Math.random ou pseudo-aleatório comum).
  static String gerarCodigoNumerico() {
    // Sorteia número inteiro no intervalo [1000, 99999] (exatamente 4 a 5 dígitos)
    // 99999 - 1000 + 1 = 99000 valores possíveis
    final valor = 1000 + _secureRandom.nextInt(99000);
    return valor.toString();
  }

  /// Gera um código de acesso numérico garantindo unicidade contra uma lista de códigos existentes.
  ///
  /// Caso ocorra colisão na mesma viagem, realiza novos sorteios criptográficos até obter código único.
  static String gerarCodigoUnicoNaViagem(Iterable<String> codigosExistentes) {
    final setExistente = codigosExistentes.toSet();
    String novoCodigo;
    do {
      novoCodigo = gerarCodigoNumerico();
    } while (setExistente.contains(novoCodigo));
    return novoCodigo;
  }

  /// Calcula o hash SHA-256 criptográfico de um código de acesso com salt exclusivo da viagem.
  ///
  /// O hash impede que mesmo um vazamento do banco NoSQL exponha os códigos em texto plano.
  static String calcularHash(String codigo, String saltViagem) {
    final bytes = utf8.encode('$codigo:$saltViagem:transsaude_segredo');
    return sha256.convert(bytes).toString();
  }

  /// Valida se o código informado confere com o hash armazenado para o salt da viagem.
  static bool validarCodigoContraHash({
    required String codigoDigitado,
    required String hashArmazenado,
    required String saltViagem,
  }) {
    if (codigoDigitado.trim().isEmpty || hashArmazenado.trim().isEmpty) {
      return false;
    }
    final hashCalculado = calcularHash(codigoDigitado.trim(), saltViagem);
    return hashCalculado == hashArmazenado;
  }

  // ===========================================================================
  // 2. NORMALIZAÇÃO E VALIDAÇÃO DE CPF
  // ===========================================================================

  /// Normaliza qualquer string de documento extraindo estritamente os dígitos numéricos (0-9).
  static String normalizarDigitos(String documento) {
    return documento.replaceAll(RegExp(r'\D'), '');
  }

  /// Alias de conveniência para normalização de documentos
  static String normalizarDocumento(String documento) =>
      normalizarDigitos(documento);

  /// Valida se a string fornecida representa um CPF matematicamente válido (algoritmo módulo 11).
  ///
  /// Regras:
  /// - Exatamente 11 dígitos numéricos;
  /// - Rejeita sequências repetidas conhecidas (000.000.000-00, 111.111.111-11, etc.);
  /// - Calcula e valida o 1º dígito verificador;
  /// - Calcula e valida o 2º dígito verificador.
  static bool validarCpf(String cpfBruto) {
    final clean = normalizarDigitos(cpfBruto);
    if (clean.length != 11) return false;

    // Rejeita sequências repetidas (ex: 11111111111)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(clean)) return false;

    // Cálculo do 1º dígito verificador
    int soma1 = 0;
    for (int i = 0; i < 9; i++) {
      soma1 += int.parse(clean[i]) * (10 - i);
    }
    int resto1 = (soma1 * 10) % 11;
    if (resto1 == 10) resto1 = 0;
    if (resto1 != int.parse(clean[9])) return false;

    // Cálculo do 2º dígito verificador
    int soma2 = 0;
    for (int i = 0; i < 10; i++) {
      soma2 += int.parse(clean[i]) * (11 - i);
    }
    int resto2 = (soma2 * 10) % 11;
    if (resto2 == 10) resto2 = 0;
    if (resto2 != int.parse(clean[10])) return false;

    return true;
  }

  // ===========================================================================
  // 3. MASCARAMENTO SEGURO (LGPD)
  // ===========================================================================

  /// Mascara um CPF ocultando os dígitos centrais para relatórios e exibição segura.
  ///
  /// Exemplo: "123.456.789-00" ou "12345678900" -> "***.456.789-**"
  static String mascararCpf(String cpf) {
    final clean = normalizarDigitos(cpf);
    if (clean.length != 11) return '***.***.***-**';
    return '***.${clean.substring(3, 6)}.${clean.substring(6, 9)}-**';
  }

  /// Mascara o código de acesso para logs internos de auditoria (sem revelar o segredo).
  ///
  /// Exemplo: "12345" -> "***45", "1234" -> "***4"
  static String mascararCodigo(String codigo) {
    if (codigo.length < 3) return '***';
    return '***${codigo.substring(codigo.length - 2)}';
  }

  // ===========================================================================
  // 4. RATE LIMITING E PROTEÇÃO CONTRA FORÇA BRUTA
  // ===========================================================================

  /// Função interna que verifica se um identificador unitário está bloqueado
  static bool _estaBloqueadoIndividual(String identificador,
      {DateTime? agora}) {
    final cleanId = normalizarDigitos(identificador).isNotEmpty
        ? normalizarDigitos(identificador)
        : identificador.trim().toLowerCase();
    final momentoAtual = agora ?? DateTime.now();

    final bloqueioAte = _bloqueiosAtivos[cleanId];
    if (bloqueioAte != null) {
      if (momentoAtual.isBefore(bloqueioAte)) {
        return true;
      } else {
        // Bloqueio expirou: remove o registro
        _bloqueiosAtivos.remove(cleanId);
        _tentativasFalhas.remove(cleanId);
      }
    }
    return false;
  }

  /// Verifica se um determinado identificador (CPF ou IP) está temporariamente bloqueado.
  static bool estaBloqueado(String identificador,
      {String? ip, DateTime? agora}) {
    if (_estaBloqueadoIndividual(identificador, agora: agora)) return true;
    if (ip != null && _estaBloqueadoIndividual(ip, agora: agora)) return true;
    return false;
  }

  /// Função interna que registra falha para um identificador individual
  static bool _registrarFalhaIndividual(String identificador,
      {DateTime? agora}) {
    final cleanId = normalizarDigitos(identificador).isNotEmpty
        ? normalizarDigitos(identificador)
        : identificador.trim().toLowerCase();
    final momentoAtual = agora ?? DateTime.now();

    final tentativas = _tentativasFalhas.putIfAbsent(cleanId, () => []);
    // Remove tentativas anteriores fora da janela de monitoramento
    tentativas
        .removeWhere((t) => momentoAtual.difference(t) > kJanelaTentativas);
    tentativas.add(momentoAtual);

    if (tentativas.length >= kMaxTentativas) {
      _bloqueiosAtivos[cleanId] = momentoAtual.add(kDuracaoBloqueio);
      return true;
    }
    return false;
  }

  /// Registra uma tentativa falha de autenticação e aplica bloqueio se exceder o limite.
  ///
  /// Retorna `true` se o identificador ou IP acabou de ser bloqueado após esta tentativa.
  static bool registrarTentativaFalha(String identificador,
      {String? ip, DateTime? agora}) {
    final b1 = _registrarFalhaIndividual(identificador, agora: agora);
    final b2 =
        ip != null ? _registrarFalhaIndividual(ip, agora: agora) : false;
    return b1 || b2;
  }

  /// Registra autenticação bem-sucedida, limpando histórico de falhas do identificador e IP.
  static void registrarSucesso(String identificador, {String? ip}) {
    final cleanId = normalizarDigitos(identificador).isNotEmpty
        ? normalizarDigitos(identificador)
        : identificador.trim().toLowerCase();
    _tentativasFalhas.remove(cleanId);
    _bloqueiosAtivos.remove(cleanId);
    if (ip != null) {
      final cleanIp = ip.trim().toLowerCase();
      _tentativasFalhas.remove(cleanIp);
      _bloqueiosAtivos.remove(cleanIp);
    }
  }

  /// Reseta registros de rate limiting (utilizado em suítes de testes automatizados).
  static void resetarRateLimitParaTestes() {
    _tentativasFalhas.clear();
    _bloqueiosAtivos.clear();
  }

  // ===========================================================================
  // 5. RESOLUÇÃO HIERÁRQUICA DO IDENTIFICADOR CIVIL
  // ===========================================================================

  /// Resolve o identificador de login de acordo com a ordem de precedência:
  /// (a) CPF do paciente cadastrado;
  /// (b) se vazio, CPF do acompanhante (caso típico: crianças e idosos);
  /// (c) se sem acompanhante, outro documento informado (RG, CNH);
  /// (d) se não houver nada, ignora com log interno sem dados sensíveis.
  static ResolucaoIdentificador resolverIdentificador({
    required String? cpfPaciente,
    required String? cpfAcompanhante,
    required String? outroDocumento,
    String? pacienteId,
    String? pacienteNome,
  }) {
    final cleanCpfPaciente = normalizarDigitos(cpfPaciente ?? '');
    final cleanCpfAcompanhante = normalizarDigitos(cpfAcompanhante ?? '');
    final cleanOutroDoc = (outroDocumento ?? '').trim();

    // (a) CPF do paciente válido e presente
    if (cleanCpfPaciente.isNotEmpty && validarCpf(cleanCpfPaciente)) {
      return ResolucaoIdentificador(
        tipo: 'cpf_paciente',
        documentoNormalizado: cleanCpfPaciente,
        pacienteId: pacienteId,
        titularNome: pacienteNome,
        isAcompanhante: false,
        logAnonimizado: 'Identificador resolvido via CPF titular do paciente',
      );
    }

    // (b) CPF do acompanhante (caso o do paciente seja ausente ou inválido)
    if (cleanCpfAcompanhante.isNotEmpty && validarCpf(cleanCpfAcompanhante)) {
      return ResolucaoIdentificador(
        tipo: 'cpf_acompanhante',
        documentoNormalizado: cleanCpfAcompanhante,
        pacienteId: pacienteId,
        titularNome: pacienteNome,
        isAcompanhante: true,
        logAnonimizado: 'Identificador resolvido via CPF do acompanhante responsável',
      );
    }

    // (c) Outro documento (RG, CNH) informado
    if (cleanOutroDoc.isNotEmpty) {
      return ResolucaoIdentificador(
        tipo: 'outro_documento',
        documentoNormalizado: cleanOutroDoc,
        pacienteId: pacienteId,
        titularNome: pacienteNome,
        isAcompanhante: false,
        logAnonimizado: 'Identificador resolvido via documento alternativo cadastrado',
      );
    }

    // (d) Nenhum documento válido disponível: ignora registrando log anônimo
    return const ResolucaoIdentificador(
      tipo: 'ignorado',
      documentoNormalizado: null,
      pacienteId: null,
      titularNome: null,
      isAcompanhante: false,
      logAnonimizado:
          'Aviso de auditoria: paciente agendado sem documento cadastrado válido',
    );
  }

  /// Resolve o identificador civil de login diretamente a partir de um [PacienteModel]
  static ResolucaoIdentificador resolverIdentificadorLogin(
      PacienteModel paciente) {
    return resolverIdentificador(
      cpfPaciente: paciente.cpf,
      cpfAcompanhante: paciente.cpfAcompanhante,
      outroDocumento: paciente.rg ?? paciente.cnh,
      pacienteId: paciente.id,
      pacienteNome: paciente.nome,
    );
  }
}
