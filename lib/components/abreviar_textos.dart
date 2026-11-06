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
// Elemento: Classe utilitária com construtor padrão privado implícito e métodos estáticos puros
class TextAbbreviator {
  // Comentário original do autor mantido byte a byte:
  // Palavras de ligação comuns em português brasileiro.
  // Constante estática _stopWords: conjunto imutável de stopwords da língua portuguesa
  // Elemento: Set<String> imutável (const) para consulta em tempo constante O(1)
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
  // Método estático abbreviate: função pura que encurta nomes ou textos longos
  // Recebe: text (String obrigatória) e parâmetros nomeados opcionais (maxCharacters, maxWords, keepWords)
  // Retorna: String com o texto formatado e com os nomes intermediários abreviados
  static String abbreviate(
    // Parâmetro posicional obrigatório: texto de entrada a ser avaliado e abreviado
    String text, {
    // Parâmetro nomeado opcional: quantidade máxima de caracteres permitida antes de abreviar (padrão 45)
    int maxCharacters = 45,
    // Parâmetro nomeado opcional: quantidade máxima de palavras permitida antes de abreviar (padrão 7)
    int maxWords = 7,
    // Parâmetro nomeado opcional: quantidade de palavras intermediárias significativas preservadas (padrão 1)
    int keepWords = 1,
  // Abre o corpo do método abbreviate
  }) {
    // Comentário original do autor mantido byte a byte:
    // Normaliza espaços e trata entradas vazias.
    // Variável normalized: string com espaços extras colapsados e extremidades aparadas
    // Elemento: Encadeamento de text.trim() com replaceAll aplicando expressão regular
    final normalized = text.trim().replaceAll(
      // Expressão regular RegExp(r'\s+'): casa com uma ou mais ocorrências consecutivas de whitespace (espaços, tabs, quebras)
      RegExp(r'\s+'),
      // String de substituição: substitui qualquer sequência de espaços por um único caractere de espaço em branco
      ' ',
    // Fecha a chamada do método replaceAll
    );

    // Linha em branco separadora entre normalização e checagem de vazio
    // Cláusula de guarda condicional: se a string for vazia após normalização, retorna imediatamente
    if (normalized.isEmpty) return normalized;

    // Linha em branco separadora entre checagem de vazio e divisão de palavras
    // Variável words: lista contendo os tokens individuais obtidos pela divisão nos espaços
    // Elemento: normalized.split(' ') retorna List<String>
    final words = normalized.split(' ');

    // Linha em branco separadora entre split e verificação de extensão
    // Comentário original do autor mantido byte a byte:
    // Verifica os dois critérios: caracteres OU palavras.
    // Variável isLong: flag booleana indicando se o texto excede os limites estabelecidos
    final isLong =
        // Critério 1: comprimento total em caracteres maior que maxCharacters
        normalized.length > maxCharacters ||
        // Critério 2: quantidade total de palavras maior que maxWords
        words.length > maxWords;

    // Linha em branco separadora entre avaliação e checagem de tamanho mínimo
    // Cláusula de guarda: não abrevia se não for longo ou se tiver 2 ou menos palavras (apenas primeiro e último nome)
    if (!isLong || words.length <= 2) {
      // Retorna a string normalizada intacta sem modificações
      return normalized;
    // Fecha a checagem de texto curto
    }

    // Linha em branco separadora entre checagem e função getWord
    // Comentário original do autor mantido byte a byte:
    // Identifica a primeira palavra alfabética de cada token.
    // Função local getWord: isola os caracteres alfabéticos de uma palavra descartando pontuações adjacentes
    // Recebe: token (String com a palavra potencialmente pontuada)
    // Retorna: String contendo somente a parte alfabética
    String getWord(String token) {
      // Executa a expressão regular no token capturando letras do alfabeto incluindo caracteres latinos acentuados
      final match = RegExp(
        // Padrão regex cobrindo letras maiúsculas e minúsculas latinas básicas e acentuadas (À-ÿ)
        r'[A-Za-zÀ-ÖØ-öø-ÿ]+',
      // Invocação de firstMatch para obter a primeira ocorrência
      ).firstMatch(token);

      // Operador de navegação segura e coalescência nula: retorna o grupo casado ou o próprio token original
      return match?.group(0) ?? token;
    // Fecha a função getWord
    }

    // Linha em branco separadora entre getWord e abbreviateWord
    // Comentário original do autor mantido byte a byte:
    // Abrevia somente palavras significativas.
    // Função local abbreviateWord: transforma uma palavra intermediária em sua inicial maiúscula seguida de ponto
    // Recebe: token (String com a palavra a ser avaliada para abreviação)
    // Retorna: String contendo a abreviação (ex: "Carlos" -> "C.") ou o token original se não for elegível
    String abbreviateWord(String token) {
      // Localiza o trecho alfabético da palavra com a regex de letras latinas
      final match = RegExp(
        r'[A-Za-zÀ-ÖØ-öø-ÿ]+',
      ).firstMatch(token);

      // Cláusula de guarda: se não houver trecho alfabético válido, retorna o token intacto
      if (match == null) return token;

      // Extrai o trecho casado garantidamente não nulo com o operador !
      final word = match.group(0)!;
      // Converte a palavra para letras minúsculas para verificar no conjunto de stopwords
      final lower = word.toLowerCase();

      // Linha em branco separadora entre extração e regras de descarte
      // Comentário original do autor mantido byte a byte:
      // Nunca abrevia palavras de ligação.
      // Cláusula de guarda: se o vocábulo for uma stopword da língua portuguesa (de, da, do, etc.), preserva sem abreviar
      if (_stopWords.contains(lower)) {
        return token;
      // Fecha checagem de stopWords
      }

      // Linha em branco separadora entre stopwords e palavras curtas
      // Comentário original do autor mantido byte a byte:
      // Palavras muito curtas já são compactas.
      // Cláusula de guarda: palavras de até 2 letras já são compactas e não devem ser abreviadas
      if (word.length <= 2) return token;

      // Linha em branco separadora entre palavras curtas e formatação
      // Interpolação de string: cria a abreviação pegando a primeira letra em maiúscula seguida de ponto final
      final abbreviation = '${word[0]}.';

      // Linha em branco separadora entre formatação e substituição
      // Invocação de token.replaceRange: substitui o trecho alfabético preservando eventuais pontuações adjacentes
      return token.replaceRange(
        // Índice de início do casamento
        match.start,
        // Índice de fim do casamento
        match.end,
        // Texto abreviado de substituição
        abbreviation,
      );
    // Fecha a função abbreviateWord
    }

    // Linha em branco separadora entre abbreviateWord e montagem da lista de resultado
    // Comentário original do autor mantido byte a byte:
    // Mantém o início e o final do texto.
    // Variável result: cópia mutável da lista de palavras para aplicar as abreviações nos índices selecionados
    final result = List<String>.from(words);

    // Linha em branco separadora entre clonagem e busca de índices
    // Comentário original do autor mantido byte a byte:
    // Localiza as palavras significativas do meio.
    // Variável middleIndexes: lista de inteiros acumulando os índices das palavras candidatas à abreviação
    final middleIndexes = <int>[];

    // Linha em branco separadora entre declaração de lista e laço de iteração
    // Laço for: percorre as palavras intermediárias, excluindo propositalmente o primeiro índice (0) e o último (words.length - 1)
    for (int i = 1; i < words.length - 1; i++) {
      // Extrai o termo alfabético em letras minúsculas usando getWord
      final word = getWord(words[i]).toLowerCase();

      // Linha em branco separadora entre extração e checagem de elegibilidade
      // Condicional: avalia se a palavra tem mais de 2 letras e não é stopword
      if (word.length > 2 && !_stopWords.contains(word)) {
        // Adiciona o índice i à lista de índices intermediários elegíveis
        middleIndexes.add(i);
      // Fecha a checagem de elegibilidade
      }
    // Fecha o laço for de índices
    }

    // Linha em branco separadora entre coleta de índices e seleção com base em keepWords
    // Comentário original do autor mantido byte a byte:
    // Preserva algumas palavras intermediárias completas.
    // Expressão ternária: seleciona os primeiros índices respeitando o quantitativo de palavras preservadas (keepWords)
    final wordsToAbbreviate = middleIndexes.length > keepWords
        ? middleIndexes.take(middleIndexes.length - keepWords)
        : <int>[];

    // Linha em branco separadora entre seleção e aplicação de abreviações
    // Laço for-in: percorre os índices selecionados para aplicar a abreviação no array de resultado
    for (final index in wordsToAbbreviate) {
      // Substitui o token pelo resultado de abbreviateWord
      result[index] = abbreviateWord(result[index]);
    // Fecha o laço de aplicação
    }

    // Linha em branco separadora entre laço de aplicação e retorno concatenado
    // Invocação de result.join(' '): concatena todos os tokens separados por espaço simples
    return result.join(' ');
  // Fecha o método abbreviate
  }
// Fecha a classe TextAbbreviator
}
