// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/bloco_acompanhante.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o componente visual CardAcompanhante, um container estilizado com
// bordas suaves e fundo slate para exibição dos dados de identificação e
// contato do acompanhante de um paciente (nome completo e telefone com ícones
// representativos e tratamento para campos opcionais).
//
// PARA QUE SERVE NO PROJETO:
// Destaca visualmente a presença de um acompanhante no card do passageiro na
// tela do motorista, permitindo que o condutor identifique imediatamente quem
// acompanha o paciente e possua acesso rápido ao telefone de contato.
//
// ONDE É USADO NO PROJETO:
// - lib/components/card_paciente.dart (exibido na seção inferior do card quando há acompanhante)
//
// DE ONDE RECEBE DADOS:
// Parâmetros obrigatórios nomeAcompanhante e telAcompanhante repassados pelo widget pai.
//
// O QUE EXPORTA / EXPÕE:
// - class CardAcompanhante extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit ea418fa pela equipe do projeto na tarefa de exibir variação
// do card de paciente com acompanhante. Não provém de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente do pacote Material Design do Flutter (package:flutter/material.dart).
// Componente puramente declarativo e imutável: sem efeitos colaterais, sem I/O e sem rede.
// ============================================================================

// Importa a biblioteca de componentes visuais Material Design do framework Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a classe do componente
// Declaração do widget StatelessWidget CardAcompanhante
// Elemento: Classe StatelessWidget imutável do Flutter para renderização visual dos dados do acompanhante
class CardAcompanhante extends StatelessWidget {
  // Atributo nomeAcompanhante: nome completo do acompanhante cadastrado
  // Tipo: String imutável
  final String nomeAcompanhante;
  // Atributo telAcompanhante: telefone de contato do acompanhante
  // Tipo: String imutável
  final String telAcompanhante;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe CardAcompanhante
  // Recebe parâmetros nomeados obrigatórios para garantir preenchimento completo dos campos
  const CardAcompanhante({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado obrigatório para o nome do acompanhante
    required this.nomeAcompanhante,
    // Parâmetro nomeado obrigatório para o número de telefone do acompanhante
    required this.telAcompanhante,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Anotação indicando que o método build sobrescreve a definição da classe StatelessWidget
  @override
  // Método build: constrói a árvore de widgets correspondente ao bloco visual de acompanhante
  // Recebe: context (BuildContext contendo a localização do widget na hierarquia da tela)
  // Retorna: Widget (a árvore visual de nós iniciada pelo Container estético)
  Widget build(BuildContext context) {
    // Widget Container: caixa de layout retangular decorada com espaçamento, borda e fundo estilizado
    // Elemento: Classe Container de 'package:flutter/widgets.dart'
    // Retorna: Um container decorado contendo os dados do acompanhante
    return Container(
      // Propriedade margin: define o espaçamento externo acima do bloco para separá-lo do conteúdo anterior
      // EdgeInsets.only(top: 12): aplica margem superior constante de 12 pixels lógicos
      margin: const EdgeInsets.only(top: 12),
      // Propriedade padding: define o preenchimento interno constante de 10 pixels em todas as direções
      padding: const EdgeInsets.all(10),
      // Propriedade decoration: define a estilização visual (cor de fundo, raio dos cantos e contorno da borda)
      // Recebe: Uma instância de BoxDecoration
      decoration: BoxDecoration(
        // Propriedade color: cor de preenchimento do fundo do container
        // O valor 0xFFF8FAFC é um cinza muito claro com leve matiz azulada (Slate 50)
        // Comentário original do autor mantido byte a byte:
        color: const Color(0xFFF8FAFC), // Slate 50
        // Propriedade borderRadius: arredonda os quatro cantos do container com raio geométrico de 12 pixels
        borderRadius: BorderRadius.circular(12),
        // Propriedade border: contorno ao redor do container
        // Border.all: cria borda sólida com espessura de 1.0 pixel e cor Slate 200 (0xFFE2E8F0)
        border: Border.all(
          // Comentário original do autor mantido byte a byte:
          color: const Color(0xFFE2E8F0), // Slate 200
          // Espessura do traço da borda em pixels lógicos
          width: 1.0,
        // Fecha a chamada do construtor Border.all
        ),
      // Fecha a instanciação de BoxDecoration
      ),
      // Propriedade child de Container: widget filho que organiza os elementos em sequência vertical
      // Widget Column: organiza seus filhos verticalmente em coluna
      child: Column(
        // Propriedade crossAxisAlignment: alinha os elementos à esquerda no eixo horizontal
        crossAxisAlignment: CrossAxisAlignment.start,
        // Propriedade children: lista de widgets alinhados verticalmente dentro do container
        children: [
          // Comentário original do autor mantido byte a byte:
          // Título com ícone lado a lado
          // Widget Row: organiza o ícone de acompanhante e o rótulo textual lado a lado no eixo horizontal
          const Row(
            // Propriedade children da Row de cabeçalho: ícone, espaçamento e texto do título
            children: [
              // Widget Icon: glifo gráfico representando a adição de um grupo de pessoas
              // Icons.group_add_outlined: ícone de contorno do pacote Material
              Icon(
                Icons.group_add_outlined,
                // Dimensão do ícone de 17 pixels lógicos
                size: 17,
                // Cor azul destacada (blueAccent) para indicar visualmente a categoria de acompanhante
                color: Colors.blueAccent,
              // Fecha a instanciação do Icon
              ),
              // Widget SizedBox: espaçamento horizontal constante de 6 pixels entre o ícone e o rótulo
              SizedBox(width: 6),
              // Widget Text: exibe o título em maiúsculas 'ACOMPANHANTE'
              Text(
                'ACOMPANHANTE',
                // Propriedade style: formatação tipográfica do título de acompanhante
                style: TextStyle(
                  // Tamanho reduzido da fonte (11 pontos) para texto secundário de rótulo
                  fontSize: 11,
                  // Peso da fonte em negrito para facilitar a leitura rápida
                  fontWeight: FontWeight.bold,
                  // Cor ardósia escura (0xFF334155, Slate 700)
                  color: Color(0xFF334155),
                  // Espaçamento entre letras de 0.5 pixels
                  letterSpacing: 0.5,
                // Fecha a TextStyle do título
                ),
              // Fecha o Text do título
              ),
            // Fecha a lista children da Row de cabeçalho
            ],
          // Fecha o widget Row de cabeçalho
          ),
          // Widget SizedBox: espaçamento vertical constante de 6 pixels entre o cabeçalho e o nome
          const SizedBox(height: 6),

          // Comentário original do autor mantido byte a byte:
          // Nome do acompanhante
          // Widget Row: organiza horizontalmente o ícone de usuário e o nome do acompanhante
          Row(
            // Propriedade children da Row de nome: ícone de usuário, espaçamento e nome expandido
            children: [
              // Widget Icon: ícone de contorno de pessoa (Icons.person_outline)
              const Icon(Icons.person_outline, size: 20, color: Colors.black54),
              // Widget SizedBox: espaçamento horizontal constante de 6 pixels
              const SizedBox(width: 6),
              // Widget Expanded: expande o texto para preencher o espaço horizontal disponível sem estourar o card
              Expanded(
                // Propriedade child de Expanded: widget Text contendo o nome do acompanhante
                child: Text(
                  // String com o nome completo recebido no atributo nomeAcompanhante
                  nomeAcompanhante,
                  // Propriedade style: tipografia destacada para o nome
                  style: const TextStyle(
                    // Tamanho da fonte de 13.5 pixels
                    fontSize: 13.5,
                    // Peso negrito para dar ênfase à identificação
                    fontWeight: FontWeight.bold,
                  // Fecha a TextStyle do nome
                  ),
                  // Propriedade maxLines: limita o texto a no máximo 1 linha
                  maxLines: 1,
                  // Propriedade overflow: insere reticências (...) caso o nome ultrapasse a largura da linha
                  overflow: TextOverflow.ellipsis,
                // Fecha o widget Text do nome
                ),
              // Fecha o widget Expanded do nome
              ),
            // Fecha a lista children da Row de nome
            ],
          // Fecha o widget Row de nome
          ),

          // Comentário original do autor mantido byte a byte:
          // Telefone do acompanhante (renderizado apenas se existir)
          // Expressão condicional com operador spread (...): renderiza o bloco de telefone se houver texto
          if (telAcompanhante.trim().isNotEmpty) ...[
            // Widget SizedBox: espaçamento vertical constante de 4 pixels acima da linha de telefone
            const SizedBox(height: 4),
            // Widget Row: organiza horizontalmente o ícone de telefone e o número
            Row(
              // Propriedade children da Row de telefone: ícone, espaçamento e número de telefone
              children: [
                // Widget Icon: ícone de contorno de telefone (Icons.phone_outlined)
                const Icon(Icons.phone_outlined, size: 18, color: Colors.black54),
                // Widget SizedBox: espaçamento horizontal constante de 6 pixels
                const SizedBox(width: 6),
                // Widget Expanded: expande o número de telefone evitando overflow visual
                Expanded(
                  // Propriedade child de Expanded: widget Text contendo o telefone formatado
                  child: Text(
                    // String com o telefone de contato
                    telAcompanhante,
                    // Propriedade style: formatação tipográfica do telefone
                    style: const TextStyle(
                      // Tamanho de 12.5 pixels
                      fontSize: 12.5,
                      // Peso semi-negrito (w600)
                      fontWeight: FontWeight.w600,
                      // Cor preta suave (black87)
                      color: Colors.black87,
                    // Fecha a TextStyle do telefone
                    ),
                    // Propriedade maxLines: limita a 1 linha
                    maxLines: 1,
                    // Propriedade overflow: trunca com reticências se necessário
                    overflow: TextOverflow.ellipsis,
                  // Fecha o widget Text do telefone
                  ),
                // Fecha o widget Expanded do telefone
                ),
              // Fecha a lista children da Row de telefone
              ],
            // Fecha o widget Row de telefone
            ),
          // Fecha a lista condicional do spread de telefone
          ],
        // Fecha a lista children da Column do bloco
        ],
      // Fecha o widget Column do bloco
      ),
    // Fecha o widget Container do bloco de acompanhante
    );
  // Fecha o método build
  }
// Fecha a classe CardAcompanhante
}
