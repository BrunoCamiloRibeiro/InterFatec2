/// Utilitário para abreviar nomes próprios e textos longos sem cortar sentido.
class TextAbbreviator {
  // Palavras de ligação comuns em português brasileiro (nunca abreviadas).
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

  static final RegExp _letrasLatinas = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]+');

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
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return normalized;

    final words = normalized.split(' ');
    final isLong = normalized.length > maxCharacters || words.length > maxWords;
    if (!isLong || words.length <= 2) return normalized;

    String getWord(String token) {
      return _letrasLatinas.firstMatch(token)?.group(0) ?? token;
    }

    String abbreviateWord(String token) {
      final match = _letrasLatinas.firstMatch(token);
      if (match == null) return token;

      final word = match.group(0)!;
      if (_stopWords.contains(word.toLowerCase()) || word.length <= 2) {
        return token;
      }
      return token.replaceRange(match.start, match.end, '${word[0]}.');
    }

    final result = List<String>.from(words);
    final middleIndexes = <int>[];
    for (int i = 1; i < words.length - 1; i++) {
      final word = getWord(words[i]).toLowerCase();
      if (word.length > 2 && !_stopWords.contains(word)) {
        middleIndexes.add(i);
      }
    }

    final wordsToAbbreviate = middleIndexes.length > keepWords
        ? middleIndexes.take(middleIndexes.length - keepWords)
        : <int>[];

    for (final index in wordsToAbbreviate) {
      result[index] = abbreviateWord(result[index]);
    }

    return result.join(' ');
  }
}
