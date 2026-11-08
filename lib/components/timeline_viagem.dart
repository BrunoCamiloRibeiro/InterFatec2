// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/timeline_viagem.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza um nó individual de linha do tempo vertical (TimelineViagem)
// utilizando o pacote timeline_tile. Permite exibir eventos cronológicos do
// itinerário de viagem (embarque, atendimento, desembarque), com indicação
// visual de eventos passados/concluídos (isPast), nós de início e fim da rota
// (isFirst, isLast), ícones temáticos e card com horário e local.
//
// PARA QUE SERVE NO PROJETO:
// Componente reutilizável concebido para estruturar a visão cronológica e
// visual das paradas e etapas do transporte sanitário (TFD).
//
// ONDE É USADO NO PROJETO:
// Não encontrei importações ou usos diretos ativos deste componente no repositório
// no momento (componente visual modular criado para exibição de linha do tempo
// de viagem disponível para integração futura).
//
// DE ONDE RECEBE DADOS:
// Parâmetros repassados pelo construtor: isFirst, isLast, isPast, horario, local e icone.
//
// O QUE EXPORTA / EXPÕE:
// - class TimelineViagem extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit caae1bb pela equipe do projeto ("style(motorista): timeline
// refeita e chamável por método"). Não provém de template ou scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart' e 'package:timeline_tile/timeline_tile.dart'.
// Componente de apresentação puro em memória: sem efeitos colaterais, sem I/O e sem rede.
// ============================================================================

// Importa o framework Material Design do Flutter com widgets para cartões, linhas e tipografia
import 'package:flutter/material.dart';
// Importa o pacote externo timeline_tile para renderização especializada de nós e linhas de tempo verticais
import 'package:timeline_tile/timeline_tile.dart';

// Linha em branco separadora entre imports e comentários de exemplo
// Comentários originais do autor mantidos byte a byte:
// EXEMPLO:
// Embarque
// TimelineViagem(
//   isFirst: true,
//   isLast: false,
//   isPast: true,
//   horario: '01:00',
//   local: 'Endereço de Embarque',
//   icone: Icons.location_pin
// ),
// // Local da Consulta
// TimelineViagem(
//   isFirst: false,
//   isLast: false,
//   isPast: false,
//   horario: '02:00',
//   local: 'Endereço de Consulta',
//   icone: Icons.local_hospital_outlined
// ),
// // Local de Saída
// TimelineViagem(
//   isFirst: false,
//   isLast: true,
//   isPast: false,
//   horario: '03:00',
//   local: 'Endereço de Desembarque',
//   icone: Icons.exit_to_app_outlined,
// ),

// Linha em branco separadora entre comentários de exemplo e a classe
// Declaração do widget StatelessWidget TimelineViagem
// Elemento: Classe StatelessWidget imutável do Flutter para renderizar um nó visual da linha do tempo da viagem
class TimelineViagem extends StatelessWidget {
  // Atributo isFirst: flag booleana indicando se este nó é o primeiro da linha do tempo
  // Tipo: bool imutável (padrão false)
  final bool isFirst;
  // Atributo isLast: flag booleana indicando se este nó é o último da linha do tempo
  // Tipo: bool imutável (padrão false)
  final bool isLast;
  // Atributo isPast: flag booleana indicando se o evento desta parada já foi concluído/passado
  // Tipo: bool imutável
  final bool isPast;
  // Atributo horario: horário previsto ou efetivo em formato de string (ex: "08:30")
  // Tipo: String imutável
  final String horario;
  // Atributo local: descrição textual do endereço ou ponto de parada
  // Tipo: String imutável
  final String local;
  // Atributo icone: glifo gráfico customizado opcional para o marcador circular
  // Tipo: IconData? anulável
  final IconData? icone;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe TimelineViagem
  // Recebe parâmetros nomeados para inicialização das propriedades do nó temporal
  const TimelineViagem({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado opcional: define se é o primeiro nó com valor padrão false
    this.isFirst = false,
    // Parâmetro nomeado opcional: define se é o último nó com valor padrão false
    this.isLast = false,
    // Parâmetro nomeado obrigatório: indica se a etapa já ocorreu
    required this.isPast,
    // Parâmetro nomeado obrigatório: texto do horário
    required this.horario,
    // Parâmetro nomeado obrigatório: descrição do local
    required this.local,
    // Parâmetro nomeado opcional: ícone temático
    this.icone,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Anotação indicando sobrescrita do método build de StatelessWidget
  @override
  // Método build: reconstrói a árvore de widgets correspondente ao nó da timeline
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (SizedBox com altura fixa contendo o TimelineTile)
  Widget build(BuildContext context) {
    // Widget SizedBox: caixa com dimensões restritas delimitando o espaçamento vertical entre paradas
    // Elemento: Classe SizedBox de 'package:flutter/widgets.dart'
    return SizedBox(
      // Comentário original do autor mantido byte a byte:
      // Espaço entre os eventos
      // Propriedade height: altura constante de 70 pixels lógicos para o segmento
      height: 70,
      // Propriedade child de SizedBox: widget TimelineTile do pacote timeline_tile
      // Widget TimelineTile: componente especializado que renderiza linha conectora, indicador circular e conteúdo lateral
      child: TimelineTile(
        // Comentários originais do autor mantidos byte a byte:
        // Recebendo os parâmetros
        // Propriedade isFirst: oculta a linha conectora superior caso seja o primeiro elemento
        isFirst: isFirst,
        // Propriedade isLast: oculta a linha conectora inferior caso seja o último elemento
        isLast: isLast,
        // Comentários originais do autor mantidos byte a byte:
        // Linhas
        // Propriedade beforeLineStyle: estilo da linha conectora superior (cor escura se já concluído, cinza se pendente)
        beforeLineStyle: LineStyle(
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[300]!,
        // Fecha a LineStyle
        ),
        // Comentários originais do autor mantidos byte a byte:
        // Icones
        // Propriedade indicatorStyle: configuração do nó circular intermediário
        indicatorStyle: IndicatorStyle(
          // Largura e diâmetro do nó circular em 30 pixels lógicos
          width: 30,
          // Cor do círculo: azul escuro se concluído, cinza suave se pendente
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[300]!,
          // Propriedade iconStyle: estilo do ícone inserido no centro do círculo
          iconStyle: IconStyle(
            // Ícone: 'done' (visto) se concluído, senão o ícone informado ou relógio padrão (timer_outlined)
            iconData: isPast ? Icons.done : (icone ?? Icons.timer_outlined),
            // Cor do ícone em branco puro para alto contraste
            color: Colors.white,
          // Fecha o IconStyle
          ),
        // Fecha o IndicatorStyle
        ),
        // Comentários originais do autor mantidos byte a byte:
        // alignment: TimelineAlign.manual,
        // lineXY: 0.17,
        // startChild: Text('00:00'),
        // Propriedade endChild: widget posicionado à direita do nó, contendo o cartão informativo com horário e local
        endChild: Card(
          // Cor do fundo do Card: azul escuro se passado, cinza muito claro se pendente
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[100]!,
          // Elevação suave de 3 pixels lógicos
          elevation: 3,
          // Propriedade shape: bordas fortemente arredondadas com raio de 25 pixels
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(25),
          // Fecha o RoundedRectangleBorder
          ),
          // Propriedade child de Card: Container com preenchimento interno
          child: Container(
            // Preenchimento interno de 16 pixels horizontal e 12 vertical
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // Propriedade child de Container: Row contendo horário e local da parada
            child: Row(
              // Comentário original do autor mantido byte a byte:
              // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              // Propriedade children da Row de informações: texto de horário, espaçamento e texto de local
              children: [
                // Widget Text: exibe o horário formatado do evento
                Text(
                  // String com o horário (ex: "01:00")
                  horario,
                  // Propriedade style: formatação tipográfica com variação de peso e cor conforme o status
                  style: TextStyle(
                    // Tamanho da fonte de 14 pixels lógicos
                    fontSize: 14,
                    // Peso da fonte: negrito se concluído, normal se pendente
                    fontWeight: isPast ? FontWeight.bold : FontWeight.normal,
                    // Cor do texto: branca se fundo escuro, preta se fundo claro
                    color: isPast ? Colors.white : Colors.black,
                  // Fecha a TextStyle do horário
                  ),
                // Fecha o widget Text do horário
                ),
                // Widget SizedBox: espaçamento horizontal de 12 pixels lógicos entre horário e local
                SizedBox(width: 12),
                // Widget Text: exibe o endereço ou nome do local de parada
                Text(
                  // String com o local (ex: "Endereço de Embarque")
                  local,
                  // Propriedade style: formatação harmonizada com o horário
                  style: TextStyle(
                    // Tamanho da fonte de 14 pixels lógicos
                    fontSize: 14,
                    // Peso da fonte: negrito se concluído, normal se pendente
                    fontWeight: isPast ? FontWeight.bold : FontWeight.normal,
                    // Cor do texto: branca se fundo escuro, preta se fundo claro
                    color: isPast ? Colors.white : Colors.black,
                  // Fecha a TextStyle do local
                  ),
                // Fecha o widget Text do local
                ),
              // Fecha a lista children da Row
              ],
            // Fecha a Row
            ),
          // Fecha o Container interno do card
          ),
        // Fecha o Card endChild
        ),
      // Fecha o TimelineTile
      ),
    // Fecha o SizedBox
    );
  // Fecha o método build
  }
// Fecha a classe TimelineViagem
}
