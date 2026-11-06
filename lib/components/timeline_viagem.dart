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

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o pacote externo timeline_tile para renderização de nós e linhas de tempo
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
class TimelineViagem extends StatelessWidget {
  // Indica se este nó é o primeiro elemento da linha do tempo
  final bool isFirst;
  // Indica se este nó é o último elemento da linha do tempo
  final bool isLast;
  // Indica se o evento já ocorreu no passado
  final bool isPast;
  // Horário previsto ou realizado do evento
  final String horario;
  // Descrição do endereço ou local do evento
  final String local;
  // Ícone temático representativo da etapa
  final IconData? icone;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados
  const TimelineViagem({
    // Chave opcional do widget
    super.key,
    // Parâmetro opcional de primeiro nó (padrão falso)
    this.isFirst = false,
    // Parâmetro opcional de último nó (padrão falso)
    this.isLast = false,
    // Parâmetro obrigatório para evento passado
    required this.isPast,
    // Parâmetro obrigatório para horário
    required this.horario,
    // Parâmetro obrigatório para local
    required this.local,
    // Parâmetro opcional para ícone temático
    this.icone,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para montagem do layout do nó de timeline
  @override
  // Constrói a estrutura visual do TimelineTile
  Widget build(BuildContext context) {
    // Retorna SizedBox com altura fixa de 70 pontos
    return SizedBox(
      // Comentário original do autor mantido byte a byte:
      // Espaço entre os eventos
      // Altura delimitada em 70 pontos
      height: 70,
      // Widget do pacote timeline_tile
      child: TimelineTile(
        // Comentários originais do autor mantidos byte a byte:
        // Recebendo os parâmetros
        // Configura se o nó é o primeiro
        isFirst: isFirst,
        // Configura se o nó é o último
        isLast: isLast,
        // Comentários originais do autor mantidos byte a byte:
        // Linhas
        // Estilo da linha anterior ao nó
        beforeLineStyle: LineStyle(
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[300]!,
        ),
        // Comentários originais do autor mantidos byte a byte:
        // Icones
        // Estilo do indicador circular central
        indicatorStyle: IndicatorStyle(
          width: 30,
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[300]!,
          iconStyle: IconStyle(
            iconData: isPast ? Icons.done : (icone ?? Icons.timer_outlined),
            color: Colors.white,
          ),
        ),
        // Comentários originais do autor mantidos byte a byte:
        // alignment: TimelineAlign.manual,
        // lineXY: 0.17,
        // startChild: Text('00:00'),
        // Card à direita com horário e local
        endChild: Card(
          color: isPast ? Colors.blueGrey[900]! : Colors.blueGrey[100]!,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(25),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              // Comentário original do autor mantido byte a byte:
              // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Texto do horário
                Text(
                  horario,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isPast ? FontWeight.bold : FontWeight.normal,
                    color: isPast ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: 12),
                // Texto do local
                Text(
                  local,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isPast ? FontWeight.bold : FontWeight.normal,
                    color: isPast ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
