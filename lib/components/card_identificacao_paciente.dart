// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/card_identificacao_paciente.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o card reutilizável de identificação de pessoas (CardIdentificacaoPaciente),
// estruturando o avatar circular com a inicial do nome, nome próprio abreviado
// através do TextAbbreviator, CPF, badge colorido de status do transporte ou
// perfil cadastral, linhas informativas de telefone/detalhes e botões opcionais
// de ação para edição e inativação administrativa.
//
// PARA QUE SERVE NO PROJETO:
// É o componente padrão de apresentação de pessoas tanto no painel pessoal do
// paciente (lib/paciente.dart) quanto na tela de gestão de pessoas da equipe
// administrativa (lib/lista_pessoas.dart), unificando a identidade visual.
//
// ONDE É USADO NO PROJETO:
// - lib/paciente.dart (cabeçalho de identificação do paciente logado)
// - lib/lista_pessoas.dart (renderização dos cards de pacientes, motoristas e admins)
//
// DE ONDE RECEBE DADOS:
// Parâmetros repassados pelos widgets pais (nome, cpf, status, labelBadge,
// corBadge, telefone, detalheExtra e callbacks onEditar, onInativar, onTap).
//
// O QUE EXPORTA / EXPÕE:
// - class CardIdentificacaoPaciente extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 916cff5 pela equipe do projeto na issue da tela do paciente
// e adaptado para a gestão de pessoas na issue #34. Não provém de scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart', 'paciente_model.dart' e 'abreviar_textos.dart'.
// Componente de apresentação puro em memória: sem efeitos colaterais de I/O ou rede.
// ============================================================================

// Importa o framework Material Design do Flutter com widgets essenciais (Card, Row, Column, Text, Icon, etc.)
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports do framework e imports internos
// Importa o modelo PacienteModel para obtenção centralizada de cores e labels de status da viagem
import '../models/paciente_model.dart';
// Importa o utilitário TextAbbreviator para abreviação inteligente de nomes próprios longos
import 'abreviar_textos.dart';

// Linha em branco separadora entre imports e a classe do componente
// Comentários originais do autor mantidos byte a byte:
// Componente que exibe os dados de identificação e status do paciente logado
// Também reutilizado na Gestão de Pessoas com callbacks opcionais de edição e inativação
// Declaração do widget StatelessWidget CardIdentificacaoPaciente
// Elemento: Classe StatelessWidget imutável do Flutter para renderização do card de identificação
class CardIdentificacaoPaciente extends StatelessWidget {
  // Atributo nome: armazena o nome completo da pessoa física
  // Tipo: String imutável
  final String nome;
  // Atributo cpf: armazena o Cadastro de Pessoa Física devidamente formatado
  // Tipo: String imutável
  final String cpf;
  // Atributo status: código numérico representando a etapa atual da viagem (0 a 5)
  // Tipo: int imutável com valor padrão 0
  final int status;
  // Atributo labelBadge: rótulo textual opcional para sobrescrever o texto padrão do badge
  // Tipo: String? anulável
  final String? labelBadge;
  // Atributo corBadge: cor personalizada opcional para sobrescrever a cor padrão do badge
  // Tipo: Color? anulável
  final Color? corBadge;
  // Atributo telefone: número telefônico opcional da pessoa para contato
  // Tipo: String? anulável
  final String? telefone;
  // Atributo detalheExtra: texto informativo adicional (ex: local de saída ou veículo)
  // Tipo: String? anulável
  final String? detalheExtra;
  // Atributo onEditar: função de callback opcional disparada ao pressionar o botão Editar
  // Tipo: VoidCallback? (void Function()?)
  final VoidCallback? onEditar;
  // Atributo onInativar: função de callback opcional disparada ao pressionar o botão Inativar
  // Tipo: VoidCallback? (void Function()?)
  final VoidCallback? onInativar;
  // Atributo onTap: função de callback opcional disparada ao clicar na área geral do card
  // Tipo: VoidCallback? (void Function()?)
  final VoidCallback? onTap;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe CardIdentificacaoPaciente
  // Recebe parâmetros nomeados para inicialização de todos os atributos da classe
  const CardIdentificacaoPaciente({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado obrigatório: nome completo da pessoa
    required this.nome,
    // Parâmetro nomeado obrigatório: número do CPF formatado
    required this.cpf,
    // Parâmetro nomeado opcional: código de status da viagem com valor default 0
    this.status = 0,
    // Parâmetro nomeado opcional: rótulo customizado para o badge
    this.labelBadge,
    // Parâmetro nomeado opcional: cor customizada para o badge
    this.corBadge,
    // Parâmetro nomeado opcional: telefone para contato
    this.telefone,
    // Parâmetro nomeado opcional: texto complementar de detalhe
    this.detalheExtra,
    // Parâmetro nomeado opcional: callback para a ação de edição
    this.onEditar,
    // Parâmetro nomeado opcional: callback para a ação de inativação
    this.onInativar,
    // Parâmetro nomeado opcional: callback para a ação de toque no card
    this.onTap,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Anotação indicando que o método build sobrescreve a definição da superclasse StatelessWidget
  @override
  // Método build: reconstrói a árvore de widgets correspondente ao card sempre que instanciado
  // Recebe: context (BuildContext contendo a localização do widget na árvore de elementos)
  // Retorna: Widget (a raiz visual do componente, que neste caso é um Card)
  Widget build(BuildContext context) {
    // Comentário original do autor mantido byte a byte:
    // Reaproveita a definição centralizada de status do PacienteModel quando label customizada não é passada
    // Desestrutura o registro tupla retornado por PacienteModel.dadosStatus(status)
    // textoPadrao: String com a descrição textual do status (ex: 'Aguardando', 'Em Trânsito')
    // corPadrao: Color correspondente à cor semântica do status (ex: âmbar, azul, verde)
    // _: terceiro campo descartado (ícone de status)
    final (textoPadrao, corPadrao, _) = PacienteModel.dadosStatus(status);
    // Resolve o texto do badge utilizando o operador de coalescência nula (??): se labelBadge for nulo, usa textoPadrao
    final badgeTexto = labelBadge ?? textoPadrao;
    // Resolve a cor do badge utilizando coalescência nula (??): se corBadge for nulo, usa corPadrao
    final badgeCor = corBadge ?? corPadrao;

    // Linha em branco separadora entre resolução de dados e montagem do Card
    // Retorna a árvore de widgets encabeçada pelo widget Card do Material Design
    return Card(
      // Propriedade elevation: define a elevação da sombra projetada pelo card (2 pontos de sombra suave)
      elevation: 2,
      // Propriedade shape: define o formato geométrico com cantos arredondados de raio 16
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Propriedade clipBehavior: recorta o conteúdo interno com suavização de serrilhado (anti-aliasing)
      clipBehavior: Clip.antiAlias,
      // Propriedade child de Card: recebe o widget filho interativo InkWell
      // Widget InkWell: adiciona resposta tátil com efeito visual de onda (ripple) ao toque
      child: InkWell(
        // Propriedade onTap: callback acionado ao tocar na superfície do card (repassa o onTap recebido)
        onTap: onTap,
        // Propriedade borderRadius: limita a animação de onda ao mesmo raio arredondado de 16 pontos do card
        borderRadius: BorderRadius.circular(16),
        // Propriedade child de InkWell: recebe o widget Padding para espaçamento interno
        // Widget Padding: aplica margem interna em torno de todos os elementos filhos
        child: Padding(
          // Comentário original do autor mantido byte a byte:
          // Padding interno aumentado em ~10% (18.0) para melhor respiro visual
          // Propriedade padding: define espaçamento constante de 18 pixels lógicos em todas as direções
          padding: const EdgeInsets.all(18.0),
          // Propriedade child de Padding: recebe a Column que organiza verticalmente os blocos do card
          // Widget Column: organiza seus filhos sequencialmente de cima para baixo no eixo vertical
          child: Column(
            // Propriedade crossAxisAlignment: alinha os elementos à esquerda (início da linha no eixo horizontal)
            crossAxisAlignment: CrossAxisAlignment.start,
            // Propriedade children: lista sequencial de widgets filhos exibidos na coluna
            children: [
              // Comentário original do autor mantido byte a byte:
              // Cabeçalho do Card: Label de identificação e Badge de Status / Categoria
              // Widget Row: organiza o título e a badge horizontalmente lado a lado
              Row(
                // Propriedade mainAxisAlignment: alinha os itens distribuindo espaço entre eles (um na esquerda, outro na direita)
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // Propriedade children: lista de widgets alinhados horizontalmente no topo do card
                children: [
                  // Widget Text envolto em Expanded: exibe o rótulo descritivo superior em letras maiúsculas sem overflow
                  Expanded(
                    child: Text(
                      // Expressão ternária condicional: exibe 'CADASTRO DE PESSOA' se labelBadge foi informado, senão 'IDENTIFICAÇÃO DO PACIENTE'
                      labelBadge != null
                          ? 'CADASTRO DE PESSOA'
                          : 'IDENTIFICAÇÃO DO PACIENTE',
                      overflow: TextOverflow.ellipsis,
                      // Propriedade style: formatação tipográfica do rótulo
                      style: const TextStyle(
                        // Tamanho reduzido da fonte (12 pontos) para texto secundário
                        fontSize: 12,
                        // Espessura negrito para facilitar leitura
                        fontWeight: FontWeight.bold,
                        // Espaçamento entre letras (tracking) de 0.5 pontos
                        letterSpacing: 0.5,
                        // Cor cinza ardósia suave (Slate 500)
                        color: Color(0xFF64748B),
                      // Fecha a constante TextStyle do rótulo
                      ),
                    // Fecha o widget Text do cabeçalho
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Widget Container: caixa delimitadora do badge com cantos arredondados e borda sutil
                  Container(
                    // Propriedade padding: preenchimento interno de 12 horizontal e 5 vertical
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    // Fecha o EdgeInsets.symmetric
                    ),
                    // Propriedade decoration: estilo visual de fundo, cantos e bordas do badge
                    decoration: BoxDecoration(
                      // Cor de fundo translúcida calculada com 10% de opacidade sobre a cor base do badge
                      color: badgeCor.withValues(alpha: 0.1),
                      // Cantos arredondados com raio de 12 pontos
                      borderRadius: BorderRadius.circular(12),
                      // Borda com espessura padrão na cor do badge a 30% de opacidade
                      border: Border.all(
                        color: badgeCor.withValues(alpha: 0.3),
                      // Fecha o Border.all
                      ),
                    // Fecha o BoxDecoration do badge
                    ),
                    // Propriedade child de Container: texto descritivo centralizado no badge
                    // Widget Text: renderiza a mensagem textual do status ou categoria
                    child: Text(
                      // Conteúdo textual resolvido da variável badgeTexto
                      badgeTexto,
                      // Propriedade style: formatação tipográfica do texto do badge
                      style: TextStyle(
                        // Tamanho da fonte de 12 pontos
                        fontSize: 12,
                        // Espessura negrito para destacar a categoria
                        fontWeight: FontWeight.bold,
                        // Cor idêntica à cor do badge para harmonização visual
                        color: badgeCor,
                      // Fecha o TextStyle do badge
                      ),
                    // Fecha o widget Text do badge
                    ),
                  // Fecha o Container do badge
                  ),
                // Fecha a lista children da Row de cabeçalho
                ],
              // Fecha o widget Row de cabeçalho
              ),
              // Widget SizedBox: espaçamento vertical constante de 14 pontos entre o cabeçalho e o perfil
              const SizedBox(height: 14),

              // Comentário original do autor mantido byte a byte:
              // Perfil: Avatar com iniciais, Nome abreviado e CPF
              // Widget Row: exibe o avatar circular à esquerda e os textos de nome e CPF à direita
              Row(
                // Propriedade children: lista de widgets alinhados horizontalmente no bloco de perfil
                children: [
                  // Widget CircleAvatar: renderiza o círculo com a inicial do nome da pessoa
                  CircleAvatar(
                    // Raio do círculo em pixels lógicos (26.5 pontos, diâmetro total de 53 pontos)
                    radius: 26.5,
                    // Cor de fundo do avatar: azul ardósia muito escuro (Slate 900)
                    backgroundColor: const Color(0xFF0F172A),
                    // Propriedade child de CircleAvatar: texto contendo a letra inicial
                    // Widget Text: renderiza a primeira letra em maiúsculo ou caractere 'P' caso vazio
                    child: Text(
                      // Expressão condicional: se o nome não for vazio, extrai a primeira letra em maiúscula; senão 'P'
                      nome.isNotEmpty ? nome[0].toUpperCase() : 'P',
                      // Propriedade style: formatação tipográfica da inicial
                      style: const TextStyle(
                        // Cor do texto branca para alto contraste sobre o fundo escuro
                        color: Colors.white,
                        // Espessura em negrito
                        fontWeight: FontWeight.bold,
                        // Tamanho aumentado da fonte para 20 pontos
                        fontSize: 20,
                      // Fecha a constante TextStyle do avatar
                      ),
                    // Fecha o widget Text da inicial
                    ),
                  // Fecha o widget CircleAvatar
                  ),
                  // Widget SizedBox: espaçamento horizontal constante de 14 pontos entre o avatar e o texto
                  const SizedBox(width: 14),
                  // Widget Expanded: expande o widget filho para preencher todo o espaço horizontal restante na Row pai.
                  // Elemento: Classe Expanded do Flutter (widgets/basic.dart).
                  // Recebe: flex (fator de flexibilidade, padrão 1) e child (o widget filho a ser expandido).
                  // Retorna: Um widget do tipo Expanded que distribui o espaço flexível na linha horizontal.
                  Expanded(
                    // Propriedade child de Expanded: define o widget único gerenciado e dimensionado pelo Expanded.
                    // Recebe: Um widget filho, neste caso uma Column contendo as informações verticais do paciente.
                    child: Column(
                      // Propriedade crossAxisAlignment: define o alinhamento dos filhos no eixo cruzado (horizontal da Column).
                      // Recebe: O valor enumerador CrossAxisAlignment.start da biblioteca widgets/basic.dart do Flutter.
                      // Efeito: Alinha os widgets de texto à esquerda (início da linha na direção de leitura da esquerda para a direita).
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // Propriedade children: lista ordenada de widgets filhos que serão empilhados verticalmente nesta Column.
                      // Recebe: Uma List<Widget> contendo o nome abreviado, espaçamento vertical e CPF formatado.
                      children: [
                        // Comentário original do autor mantido byte a byte:
                        // Nome abreviado com limite de 28 caracteres
                        // Widget Text: renderiza uma cadeia de caracteres estilizada na tela da aplicação.
                        // Elemento: Classe Text de 'package:flutter/widgets.dart'.
                        // Recebe: A String a ser renderizada como argumento posicional obrigatório e parâmetros nomeados de estilo (style).
                        // Retorna: Um widget renderizável contendo o parágrafo de texto no framework do Flutter.
                        Text(
                          // Invocação do método estático TextAbbreviator.abbreviate:
                          // O que é TextAbbreviator: Classe utilitária importada de 'abreviar_textos.dart' para encurtamento inteligente de nomes.
                          // Método abbreviate: função estática pura que abrevia os nomes intermediários mantendo o primeiro e o último nome completos.
                          // Recebe: nome (String com o nome completo a abreviar) e maxCharacters (int nomeado indicando limite máximo, aqui 28 caracteres).
                          // Retorna: String abreviada formatada (ex: 'Maria S. Silva') que cabe perfeitamente no espaço do card sem quebra feia.
                          TextAbbreviator.abbreviate(nome, maxCharacters: 28),
                          // Propriedade style: define as diretrizes tipográficas e de cor para o texto renderizado.
                          // Recebe: Uma instância de TextStyle configurando tamanho, espessura e tonalidade da fonte.
                          style: const TextStyle(
                            // Propriedade fontSize: tamanho do corpo da fonte tipográfica em pixels lógicos (16.5).
                            fontSize: 16.5,
                            // Propriedade fontWeight: peso ou espessura do traço tipográfico (FontWeight.bold = negrito, w700).
                            fontWeight: FontWeight.bold,
                            // Propriedade color: cor do texto definida pela classe Color do 'dart:ui' / Material.
                            // O valor 0xFF0F172A é um inteiro hexadecimal ARGB representando ardósia muito escura (Slate 900), garantindo alto contraste e legibilidade.
                            color: Color(0xFF0F172A),
                          // Fecha a instanciação constante de TextStyle
                          ),
                        // Fecha a invocação e construção do widget Text do nome abreviado
                        ),
                        // Widget SizedBox: espaçamento vertical constante de 3 pontos entre nome e CPF
                        const SizedBox(height: 3),
                        // Widget Text: renderiza o texto do CPF formatado
                        Text(
                          // Interpolação de string combinando o prefixo fixo 'CPF: ' com a variável cpf recebida
                          'CPF: $cpf',
                          // Propriedade style: estilo tipográfico secundário do CPF
                          style: const TextStyle(
                            // Tamanho reduzido da fonte (13 pontos) para informação secundária
                            fontSize: 13,
                            // Cor cinza ardósia intermediária (Slate 500)
                            color: Color(0xFF64748B),
                          // Fecha a constante TextStyle do CPF
                          ),
                        // Fecha o widget Text do CPF
                        ),
                      // Fecha a lista children da Column de identificação
                      ],
                    // Fecha o widget Column de identificação
                    ),
                  // Fecha o widget Expanded de identificação
                  ),
                // Fecha a lista children da Row de perfil
                ],
              // Fecha o widget Row de perfil
              ),

              // Linha em branco separadora entre perfil e linhas adicionais
              // Comentário original do autor mantido byte a byte:
              // Linhas adicionais informativas (Telefone e Detalhes de Consulta/Veículo)
              // Renderização condicional por operador spread (...): exibe bloco de telefone se informado e não vazio
              if (telefone != null && telefone!.isNotEmpty) ...[
                // Espaçamento vertical constante de 12 pontos acima do telefone
                const SizedBox(height: 12),
                // Widget Row: exibe ícone de telefone e número lado a lado
                Row(
                  // Propriedade children: lista de widgets alinhados na linha de telefone
                  children: [
                    // Widget Icon: exibe o glifo outline de telefone
                    const Icon(
                      // Identificador do ícone phone_outlined do pacote Material Icons
                      Icons.phone_outlined,
                      // Dimensão do ícone em pixels lógicos (16 pontos)
                      size: 16,
                      // Cor cinza ardósia para o ícone
                      color: Color(0xFF64748B),
                    // Fecha o construtor constante de Icon
                    ),
                    // Widget SizedBox: espaçamento horizontal constante de 6 pontos entre ícone e número
                    const SizedBox(width: 6),
                    // Widget Text: renderiza o número do telefone com operador de afirmação não-nula (!)
                    Text(
                      // Conteúdo textual do telefone garantidamente não nulo neste bloco condicional
                      telefone!,
                      // Propriedade style: formatação tipográfica do telefone
                      style: const TextStyle(
                        // Tamanho da fonte de 13 pontos
                        fontSize: 13,
                        // Cor cinza escuro (Slate 700) para leitura agradável
                        color: Color(0xFF334155),
                      // Fecha a constante TextStyle do telefone
                      ),
                    // Fecha o widget Text do telefone
                    ),
                  // Fecha a lista children da Row de telefone
                  ],
                // Fecha o widget Row de telefone
                ),
              // Fecha o bloco condicional de telefone
              ],
              // Renderização condicional por operador spread (...): exibe detalhe extra se informado e não vazio
              if (detalheExtra != null && detalheExtra!.isNotEmpty) ...[
                // Espaçamento vertical constante de 6 pontos
                const SizedBox(height: 6),
                // Widget Row: exibe ícone informativo e o texto complementar
                Row(
                  // Propriedade children: lista de widgets alinhados na linha de detalhe extra
                  children: [
                    // Widget Icon: exibe o glifo outline de informação
                    const Icon(
                      // Identificador do ícone info_outline do pacote Material Icons
                      Icons.info_outline,
                      // Dimensão do ícone de 16 pontos
                      size: 16,
                      // Cor cinza ardósia para o ícone
                      color: Color(0xFF64748B),
                    // Fecha o construtor constante de Icon
                    ),
                    // Widget SizedBox: espaçamento horizontal constante de 6 pontos
                    const SizedBox(width: 6),
                    // Widget Expanded: expande o texto para evitar estouro horizontal caso o detalhe seja longo
                    Expanded(
                      // Propriedade child de Expanded: widget Text do detalhe extra
                      child: Text(
                        // Conteúdo textual do detalhe extra garantidamente não nulo
                        detalheExtra!,
                        // Propriedade style: formatação tipográfica do detalhe extra
                        style: const TextStyle(
                          // Tamanho de 13 pontos
                          fontSize: 13,
                          // Cor cinza escuro (Slate 700)
                          color: Color(0xFF334155),
                        // Fecha a constante TextStyle do detalhe extra
                        ),
                        // Propriedade overflow: trunca com reticências (...) caso o texto exceda a largura
                        overflow: TextOverflow.ellipsis,
                      // Fecha o widget Text do detalhe extra
                      ),
                    // Fecha o widget Expanded do detalhe extra
                    ),
                  // Fecha a lista children da Row de detalhe extra
                  ],
                // Fecha o widget Row de detalhe extra
                ),
              // Fecha o bloco condicional de detalhe extra
              ],

              // Linha em branco separadora entre dados e barra de ações
              // Comentário original do autor mantido byte a byte:
              // Barra de ações administrativas (Editar e Inativar) quando fornecidas
              // Renderização condicional: exibe barra de ações caso ao menos um dos callbacks seja diferente de nulo
              if (onEditar != null || onInativar != null) ...[
                // Espaçamento vertical constante de 12 pontos acima da divisória
                const SizedBox(height: 12),
                // Widget Divider: linha divisória horizontal separando o corpo do card das ações
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                // Espaçamento vertical constante de 6 pontos abaixo da divisória
                const SizedBox(height: 6),
                // Widget Wrap: alinha os botões de ação à direita do card com quebra responsiva sem overflow
                Wrap(
                  // Propriedade alignment: alinha os filhos no final horizontal (à direita)
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  // Propriedade children: lista de botões exibidos na barra de ações
                  children: [
                    // Renderização condicional do botão Editar se o callback onEditar foi informado
                    if (onEditar != null)
                      // Widget TextButton.icon: botão de texto plano com ícone à esquerda do rótulo
                      TextButton.icon(
                        // Callback acionado ao pressionar o botão Editar
                        onPressed: onEditar,
                        // Ícone do botão: lápis de edição em azul
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Color(0xFF2563EB),
                        // Fecha o widget Icon de edição
                        ),
                        // Rótulo textual do botão Editar
                        label: const Text(
                          'Editar',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          // Fecha o TextStyle de Editar
                          ),
                        // Fecha o widget Text de Editar
                        ),
                      // Fecha o widget TextButton.icon de Editar
                      ),
                    // Renderização condicional do botão Inativar se o callback onInativar foi informado
                    if (onInativar != null)
                      // Widget TextButton.icon: botão de texto com ícone para inativação
                      TextButton.icon(
                        // Callback acionado ao pressionar o botão Inativar
                        onPressed: onInativar,
                        // Ícone do botão: pessoa desabilitada em vermelho
                        icon: const Icon(
                          Icons.person_off_outlined,
                          size: 16,
                          color: Color(0xFFDC2626),
                        // Fecha o widget Icon de inativação
                        ),
                        // Rótulo textual do botão Inativar
                        label: const Text(
                          'Inativar',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          // Fecha o TextStyle de Inativar
                          ),
                        // Fecha o widget Text de Inativar
                        ),
                      // Fecha o widget TextButton.icon de Inativar
                      ),
                  // Fecha a lista children da Wrap de botões de ação
                  ],
                // Fecha o widget Wrap de botões de ação
                ),
              // Fecha o bloco condicional da barra de ações
              ],
            // Fecha a lista children da Column principal do card
            ],
          // Fecha o widget Column principal do card
          ),
        // Fecha o widget Padding interno do card
        ),
      // Fecha o widget InkWell do card
      ),
    // Fecha o widget Card retornado
    );
  // Fecha o método build
  }
// Fecha a declaração da classe CardIdentificacaoPaciente
}
