class TextAbbreviator {
  // Palavras de ligação comuns em português brasileiro.
  static const Set<String> _stopWords = {
    'a', 'à', 'às', 'ao', 'aos',
    'o', 'os', 'as',
    'de', 'da', 'das', 'do', 'dos',
    'e', 'em', 'na', 'nas', 'no', 'nos',
    'num', 'numa', 'nuns', 'numas',
    'por', 'pela', 'pelas', 'pelo', 'pelos',
    'para', 'pra', 'com', 'sem', 'sob',
    'sobre', 'entre', 'até', 'desde',
    'que', 'se', 'ou',
  };

  /// Abrevia palavras intermediárias quando o texto é longo.
  ///
  /// [maxCharacters]: limite de caracteres.
  /// [maxWords]: limite de palavras.
  /// [keepWords]: número mínimo de palavras significativas
  /// que devem permanecer inteiras, além da primeira e da última.
  static String abbreviate(
    String text, {
    int maxCharacters = 45,
    int maxWords = 7,
    int keepWords = 1,
  }) {
    // Normaliza espaços e trata entradas vazias.
    final normalized = text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (normalized.isEmpty) return normalized;

    final words = normalized.split(' ');

    // Verifica os dois critérios: caracteres OU palavras.
    final isLong =
        normalized.length > maxCharacters ||
        words.length > maxWords;

    if (!isLong || words.length <= 2) {
      return normalized;
    }

    // Identifica a primeira palavra alfabética de cada token.
    String getWord(String token) {
      final match = RegExp(
        r'[A-Za-zÀ-ÖØ-öø-ÿ]+',
      ).firstMatch(token);

      return match?.group(0) ?? token;
    }

    // Abrevia somente palavras significativas.
    String abbreviateWord(String token) {
      final match = RegExp(
        r'[A-Za-zÀ-ÖØ-öø-ÿ]+',
      ).firstMatch(token);

      if (match == null) return token;

      final word = match.group(0)!;
      final lower = word.toLowerCase();

      // Nunca abrevia palavras de ligação.
      if (_stopWords.contains(lower)) {
        return token;
      }

      // Palavras muito curtas já são compactas.
      if (word.length <= 2) return token;

      final abbreviation = '${word[0]}.';

      return token.replaceRange(
        match.start,
        match.end,
        abbreviation,
      );
    }

    // Mantém o início e o final do texto.
    final result = List<String>.from(words);

    // Localiza as palavras significativas do meio.
    final middleIndexes = <int>[];

    for (int i = 1; i < words.length - 1; i++) {
      final word = getWord(words[i]).toLowerCase();

      if (word.length > 2 && !_stopWords.contains(word)) {
        middleIndexes.add(i);
      }
    }

    // Preserva algumas palavras intermediárias completas.
    final wordsToAbbreviate = middleIndexes.length > keepWords
        ? middleIndexes.take(middleIndexes.length - keepWords)
        : <int>[];

    for (final index in wordsToAbbreviate) {
      result[index] = abbreviateWord(result[index]);
    }

    return result.join(' ');
  }
}
