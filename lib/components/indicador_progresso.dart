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

// Importa o pacote de componentes e design Material do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a classe do componente
// Declaração do widget StatelessWidget IndicadorProgresso
class IndicadorProgresso extends StatelessWidget {
  // Quantidade de etapas concluídas atualmente
  final int valorAtual;
  // Total de etapas que compõem a barra de progresso (padrão 1)
  final int valorMaximo;
  // Cor aplicada aos segmentos completados
  final Color corAtiva;
  // Cor aplicada aos segmentos ainda pendentes
  final Color corInativa;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados
  const IndicadorProgresso({
    // Chave opcional do widget
    super.key,
    // Parâmetro obrigatório com o valor atual de progresso
    required this.valorAtual,
    // Parâmetro opcional para o valor máximo com padrão 1
    this.valorMaximo = 1,
    // Parâmetro opcional para cor ativa com padrão azul
    this.corAtiva = Colors.blueAccent,
    // Parâmetro opcional para cor inativa com padrão cinza
    this.corInativa = Colors.grey,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para renderização dos segmentos
  @override
  // Constrói a linha horizontal contendo os segmentos proporcionais
  Widget build(BuildContext context) {
    // Restringe o valor atual entre 0 e valorMaximo para evitar índices inválidos
    final int progresso = valorAtual.clamp(0, valorMaximo);

    // Linha em branco separadora entre cálculo e retorno da Row
    // Retorna Row horizontal gerando dinamicamente os segmentos
    return Row(
      // Gera lista de widgets com tamanho igual a valorMaximo
      children: List.generate(valorMaximo, (index) {
        // Expande cada segmento proporcionalmente na largura disponível
        return Expanded(
          child: Container(
            // Altura do traço do segmento em 5 pontos
            height: 5,
            // Margem lateral direita para separar os segmentos (exceto no último)
            margin: EdgeInsets.only(
              right: index < valorMaximo - 1 ? 5 : 0,
            ),
            // Decoração com cantos arredondados e cor ativa ou inativa
            decoration: BoxDecoration(
              color: index < progresso
                  ? corAtiva
                  : corInativa,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }
}
