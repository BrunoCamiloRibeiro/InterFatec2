// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/indicador_progresso.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o widget IndicadorProgresso, uma barra horizontal composta por
// múltiplos segmentos retangulares arredondados para representar graficamente
// o progresso de etapas ou estágios numéricos concluídos (ex: etapas da viagem).
//
// PARA QUE SERVE NO PROJETO:
// É utilizado dentro do CardPaciente (lib/components/card_paciente.dart) para
// fornecer feedback visual intuitivo e imediato ao motorista sobre o estágio
// da viagem de cada paciente (aguardando, embarcado, desembarcado, etc.).
//
// ONDE É USADO NO PROJETO:
// - lib/components/card_paciente.dart (barra segmental sob o status do passageiro)
//
// DE ONDE RECEBE DADOS:
// Parâmetros repassados pelo widget pai: valorAtual, valorMaximo, corAtiva e corInativa.
//
// O QUE EXPORTA / EXPÕE:
// - class IndicadorProgresso extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 616f43d pela equipe do projeto na tarefa de implementar o
// indicador de progresso para motoristas. Não provém de template ou scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente do pacote Material Design do Flutter (package:flutter/material.dart).
// Componente de apresentação puro: determinístico, sem efeitos colaterais, sem I/O e sem rede.
// ============================================================================

// Importa a biblioteca de componentes e design Material do Flutter (Row, Expanded, Container, Color, etc.)
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a classe do componente
// Declaração do widget StatelessWidget IndicadorProgresso
// Elemento: Classe StatelessWidget imutável do Flutter para renderizar barras de progresso segmentadas
class IndicadorProgresso extends StatelessWidget {
  // Atributo valorAtual: quantidade inteira de etapas concluídas até o momento
  // Tipo: int imutável
  final int valorAtual;
  // Atributo valorMaximo: quantidade total de etapas/segmentos que compõem a barra completa (padrão 1)
  // Tipo: int imutável
  final int valorMaximo;
  // Atributo corAtiva: cor visual aplicada aos segmentos já concluídos ou ativos
  // Tipo: Color imutável
  final Color corAtiva;
  // Atributo corInativa: cor visual aplicada aos segmentos futuros ou pendentes
  // Tipo: Color imutável
  final Color corInativa;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe IndicadorProgresso
  // Recebe parâmetros nomeados com valores padrão convenientes para cores e limites
  const IndicadorProgresso({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado obrigatório: valor da etapa atual concluída
    required this.valorAtual,
    // Parâmetro nomeado opcional: quantidade máxima de segmentos com valor padrão 1
    this.valorMaximo = 1,
    // Parâmetro nomeado opcional: cor ativa com valor padrão Colors.blueAccent
    this.corAtiva = Colors.blueAccent,
    // Parâmetro nomeado opcional: cor inativa com valor padrão Colors.grey
    this.corInativa = Colors.grey,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Anotação indicando sobrescrita do método build de StatelessWidget
  @override
  // Método build: reconstrói a barra de segmentos dinamicamente a partir dos limites informados
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (Row contendo a lista de segmentos distribuídos horizontalmente)
  Widget build(BuildContext context) {
    // Invocação de valorAtual.clamp(0, valorMaximo): limita matematicamente o progresso entre 0 e valorMaximo
    // Elemento: Função pura de restrição de intervalo numérico para evitar erros visuais ou índices fora de faixa
    // Retorna: int contendo o progresso seguro
    final int progresso = valorAtual.clamp(0, valorMaximo);

    // Linha em branco separadora entre cálculo e retorno da Row
    // Widget Row: organiza horizontalmente a lista de segmentos lado a lado
    // Elemento: Classe Row do Flutter
    return Row(
      // Propriedade children de Row: lista gerada pela função utilitária List.generate
      // List.generate cria dinamicamente uma List<Widget> de tamanho valorMaximo executando a função geradora para cada índice
      children: List.generate(valorMaximo, (index) {
        // Widget Expanded: expande cada segmento proporcionalmente para que todos dividam a largura por igual
        // Elemento: Classe Expanded de 'package:flutter/widgets.dart'
        return Expanded(
          // Propriedade child de Expanded: Container que desenha a barra do segmento individual
          // Widget Container: caixa retangular decorada com cantos arredondados
          child: Container(
            // Propriedade height: altura fixa do traço do segmento em pixels lógicos (5 pontos)
            height: 5,
            // Propriedade margin: define margem externa direita entre segmentos adjacentes
            // EdgeInsets.only: aplica espaçamento lateral direito de 5 pixels para todos os segmentos exceto o último (index == valorMaximo - 1)
            margin: EdgeInsets.only(
              // Expressão ternária: se for antes do último segmento aplica 5 pixels de margem à direita, senão 0
              right: index < valorMaximo - 1 ? 5 : 0,
            // Fecha o EdgeInsets.only
            ),
            // Propriedade decoration: formato visual do segmento com cantos arredondados e cor ativa/inativa
            decoration: BoxDecoration(
              // Expressão ternária condicional de cor: se o índice for menor que progresso aplica corAtiva, senão corInativa
              color: index < progresso
                  ? corAtiva
                  : corInativa,
              // Propriedade borderRadius: arredonda os quatro cantos do segmento com raio de 10 pixels
              borderRadius: BorderRadius.circular(10),
            // Fecha a instanciação de BoxDecoration
            ),
          // Fecha o widget Container do segmento
          ),
        // Fecha o widget Expanded do segmento
        );
      // Fecha a função geradora anônima de List.generate
      }),
    // Fecha o widget Row
    );
  // Fecha o método build
  }
// Fecha a declaração da classe IndicadorProgresso
}
