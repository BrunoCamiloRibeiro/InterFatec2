// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/abreviar_textos.dart
// Camada: Apresentação / Utilitários de UI (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Fornece a classe utilitária TextAbbreviator com algoritmos para abreviação
// inteligente de nomes próprios e textos longos em português brasileiro.
// Normaliza espaços em branco, identifica stopwords/preposições (de, da, do, com, etc.),
// preserva o primeiro e o último vocábulo, e reduz palavras intermediárias
// longas para a letra inicial seguida de ponto final (ex: "José Carlos Pereira" -> "José C. Pereira"),
// respeitando limites máximos de caracteres e palavras para evitar quebras de layout.
//
// PARA QUE SERVE NO PROJETO:
// É utilizado para exibir nomes de pacientes e locais de consulta de forma
// compacta e legível nos cards da lista do motorista e no painel do paciente,
// prevenindo overflow visual ou sobreposição de textos na interface móvel.
//
// ONDE É USADO NO PROJETO:
// - lib/components/card_identificacao_paciente.dart (abreviação de nome no avatar)
// - lib/components/card_paciente.dart (abreviação de nome e dados do passageiro)
//
// DE ONDE RECEBE DADOS:
// Strings de texto informadas por parâmetros de métodos em componentes de interface.
//
// O QUE EXPORTA / EXPÕE:
// - class TextAbbreviator: classe utilitária com:
//   * static String abbreviate(String text, {int maxCharacters, int maxWords, int keepWords})
//
// ORIGEM HISTÓRICA:
// Criado no commit edf0bfb pela equipe do projeto na tarefa de formatação de
// textos e nomes nos cards. Não provém de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente dos tipos padrão do Dart SDK (RegExp, StringBuffer, List, Set).
// Função pura em memória: determinística, sem efeitos colaterais e sem I/O.
// ============================================================================

// Linha em branco separadora entre cabeçalho de documentação e definição da classe
// Declaração da classe utilitária TextAbbreviator
class TextAbbreviator {
  // Comentário original do autor mantido byte a byte:
  // Palavras de ligação comuns em português brasileiro.
  // Conjunto imutável de stopwords da língua portuguesa que não devem ser abreviadas
  static const Set<String> _stopWords = {
    // Artigos e preposições monossilábicas femininas e masculinas
    'a', 'à', 'às', 'ao', 'aos',
    // Artigos definidos masculinos e femininos
    'o', 'os', 'as',
    // Preposições essenciais e combinações de 'de'
    'de', 'da', 'das', 'do', 'dos',
    // Conjunções e preposições essenciais de lugar
    'e', 'em', 'na', 'nas', 'no', 'nos',
    // Formas contraídas de preposição com artigo indefinido
    'num', 'numa', 'nuns', 'numas',
    // Formas contraídas de preposição 'por' com artigo definido
    'por', 'pela', 'pelas', 'pelo', 'pelos',
    // Preposições indicativas de direção, companhia e posição
    'para', 'pra', 'com', 'sem', 'sob',
    // Preposições indicativas de referência e limite
    'sobre', 'entre', 'até', 'desde',
    // Conjunções subordinativas e alternativas
    'que', 'se', 'ou',
  // Fecha o conjunto literal _stopWords
  };

  // Linha em branco separadora entre stopwords e método de abreviação
  // Comentários originais do autor mantidos byte a byte:
  /// Abrevia palavras intermediárias quando o texto é longo.
  ///
  /// [maxCharacters]: limite de caracteres.
  /// [maxWords]: limite de palavras.
  /// [keepWords]: número mínimo de palavras significativas
  /// que devem permanecer inteiras, além da primeira e da última.
  // Método estático puro para abreviar textos que superem os limites configurados
  static String abbreviate(
    // Texto de entrada que será avaliado para abreviação
    String text, {
    // Limite de caracteres antes de iniciar a abreviação (padrão 45)
    int maxCharacters = 45,
    // Limite de quantidade de palavras (padrão 7)
    int maxWords = 7,
    // Palavras do meio mantidas por extenso além das pontas (padrão 1)
    int keepWords = 1,
  // Abre o corpo do método abbreviate
  }) {
    // Comentário original do autor mantido byte a byte:
    // Normaliza espaços e trata entradas vazias.
    // Remove espaços repetidos e aparas nas extremidades
    final normalized = text.trim().replaceAll(
      // Expressão regular que casa com múltiplos espaços contíguos
      RegExp(r'\s+'),
      // Substitui por espaço simples
      ' ',
    );

    // Linha em branco separadora entre normalização e checagem de vazio
    // Se a string normalizada for vazia, retorna imediatamente
    if (normalized.isEmpty) return normalized;

    // Linha em branco separadora entre checagem de vazio e divisão de palavras
    // Quebra a string em lista de palavras individuais
    final words = normalized.split(' ');

    // Linha em branco separadora entre split e verificação de extensão
    // Comentário original do autor mantido byte a byte:
    // Verifica os dois critérios: caracteres OU palavras.
    // Avalia se o texto ultrapassa o limite de caracteres ou limite de palavras
    final isLong =
        normalized.length > maxCharacters ||
        words.length > maxWords;

    // Linha em branco separadora entre avaliação e checagem de tamanho mínimo
    // Não abrevia textos curtos ou frases com 2 ou menos palavras
    if (!isLong || words.length <= 2) {
      // Retorna o texto original normalizado sem modificação
      return normalized;
    // Fecha a checagem de texto curto
    }

    // Linha em branco separadora entre checagem e função getWord
    // Comentário original do autor mantido byte a byte:
    // Identifica a primeira palavra alfabética de cada token.
    // Função local para extrair sequência de letras descartando pontuações
    String getWord(String token) {
      // Expressão regular com suporte a caracteres latinos acentuados
      final match = RegExp(
        r'[A-Za-zÀ-ÖØ-öø-ÿ]+',
      ).firstMatch(token);

      // Retorna o grupo alfabético casado ou o token original se não houver match
      return match?.group(0) ?? token;
    // Fecha a função getWord
    }

    // Linha em branco separadora entre getWord e abbreviateWord
    // Comentário original do autor mantido byte a byte:
    // Abrevia somente palavras significativas.
    // Função local para transformar uma palavra individual na inicial com ponto
    String abbreviateWord(String token) {
      // Localiza o trecho alfabético da palavra
      final match = RegExp(
        r'[A-Za-zÀ-ÖØ-öø-ÿ]+',
      ).firstMatch(token);

      // Se não houver trecho alfabético, retorna o token intacto
      if (match == null) return token;

      // Extrai o texto da palavra encontrada
      final word = match.group(0)!;
      // Converte para minúsculas para verificar no conjunto de stopwords
      final lower = word.toLowerCase();

      // Linha em branco separadora entre extração e regras de descarte
      // Comentário original do autor mantido byte a byte:
      // Nunca abrevia palavras de ligação.
      // Se for preposição ou artigo, preserva sem abreviar
      if (_stopWords.contains(lower)) {
        return token;
      // Fecha checagem de stopWords
      }

      // Linha em branco separadora entre stopwords e palavras curtas
      // Comentário original do autor mantido byte a byte:
      // Palavras muito curtas já são compactas.
      // Palavras de até 2 letras não precisam ser abreviadas
      if (word.length <= 2) return token;

      // Linha em branco separadora entre palavras curtas e formatação
      // Gera a forma abreviada pegando a primeira letra em maiúscula seguida de ponto
      final abbreviation = '${word[0]}.';

      // Linha em branco separadora entre formatação e substituição
      // Substitui o trecho alfabético pela abreviação dentro do token
      return token.replaceRange(
        match.start,
        match.end,
        abbreviation,
      );
    // Fecha a função abbreviateWord
    }

    // Linha em branco separadora entre abbreviateWord e montagem da lista de resultado
    // Comentário original do autor mantido byte a byte:
    // Mantém o início e o final do texto.
    // Clona a lista de palavras para mutação seletiva
    final result = List<String>.from(words);

    // Linha em branco separadora entre clonagem e busca de índices
    // Comentário original do autor mantido byte a byte:
    // Localiza as palavras significativas do meio.
    // Lista que acumulará os índices das palavras candidatas à abreviação
    final middleIndexes = <int>[];

    // Linha em branco separadora entre declaração de lista e laço de iteração
    // Itera pelas palavras intermediárias (excluindo o primeiro índice 0 e o último words.length - 1)
    for (int i = 1; i < words.length - 1; i++) {
      // Extrai o termo alfabético em minúsculas
      final word = getWord(words[i]).toLowerCase();

      // Linha em branco separadora entre extração e checagem de elegibilidade
      // Avalia se o termo tem mais de 2 letras e não é stopword
      if (word.length > 2 && !_stopWords.contains(word)) {
        // Registra o índice como apto para abreviação
        middleIndexes.add(i);
      // Fecha a checagem de elegibilidade
      }
    // Fecha o laço for de índices
    }

    // Linha em branco separadora entre coleta de índices e seleção com base em keepWords
    // Comentário original do autor mantido byte a byte:
    // Preserva algumas palavras intermediárias completas.
    // Seleciona os primeiros índices respeitando o quantitativo keepWords preservado
    final wordsToAbbreviate = middleIndexes.length > keepWords
        ? middleIndexes.take(middleIndexes.length - keepWords)
        : <int>[];

    // Linha em branco separadora entre seleção e aplicação de abreviações
    // Itera pelos índices selecionados e aplica a abreviação no resultado
    for (final index in wordsToAbbreviate) {
      result[index] = abbreviateWord(result[index]);
    // Fecha o laço de aplicação
    }

    // Linha em branco separadora entre laço de aplicação e retorno concatenado
    // Junta as palavras com espaço e retorna a frase abreviada
    return result.join(' ');
  // Fecha o método abbreviate
  }
// Fecha a classe TextAbbreviator
}
