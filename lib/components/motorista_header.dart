// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/motorista_header.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o cabeçalho interativo superior da tela do motorista (MotoristaHeader),
// estruturando um seletor horizontal de viagens com botões acessíveis de navegação
// (setas anterior e próxima com área de toque mínima de 48dp), título centralizado
// da viagem ativa e linha secundária compacta opcional com dados do condutor,
// destino, veículo e horário previsto de saída.
//
// PARA QUE SERVE NO PROJETO:
// Permite ao motorista alternar facilmente entre viagens da sua escala diária e
// consultar rapidamente na parte superior da tela os parâmetros essenciais da rota.
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (posicionado no topo da tela do motorista)
// - test/components/motorista_header_test.dart (testes de widget e acessibilidade)
//
// DE ONDE RECEBE DADOS:
// Parâmetros repassados pelo motorista.dart: tituloViagem, callbacks onAnterior e
// onProxima, e strings opcionais motoristaNome, destino, veiculo e saida.
//
// O QUE EXPORTA / EXPÕE:
// - class MotoristaHeader extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 23644b1 pela equipe do projeto na issue #13 (header de viagens
// com seletor de setas). Não provém de template ou scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente do framework Material do Flutter (package:flutter/material.dart).
// Componente de apresentação puro: sem efeitos colaterais de I/O, rede ou estado global.
// ============================================================================

// Importa o framework Material Design do Flutter com widgets para botões de ícone, contêineres e tipografia
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a classe MotoristaHeader
// Comentários originais do autor mantidos byte a byte:
/// Componente visual do cabeçalho da tela do motorista (Issue #13).
///
/// Exibe um seletor horizontal em card com navegação entre viagens (setas anterior/próxima)
/// e o rótulo da viagem centralizado. Permite opcionalmente exibir uma linha secundária
/// compacta com detalhes da viagem caso sejam informados.
// Declaração do widget StatelessWidget MotoristaHeader
// Elemento: Classe StatelessWidget imutável do Flutter para renderizar o cabeçalho superior do motorista
class MotoristaHeader extends StatelessWidget {
  // Comentário original do autor mantido byte a byte:
  /// Rótulo ou título da viagem atual já formatado (ex: "Viagem #1", "Viagem 001").
  // Atributo tituloViagem: título textual da viagem exibido no centro do cabeçalho
  // Tipo: String imutável
  final String tituloViagem;

  // Linha em branco separadora entre atributos
  // Comentários originais do autor mantidos byte a byte:
  /// Callback acionado ao tocar na seta de viagem anterior.
  /// Se nulo, a seta permanece visualmente desabilitada.
  // Atributo onAnterior: função callback de navegação para a viagem anterior (ou nulo se for a primeira)
  // Tipo: VoidCallback? anulável
  final VoidCallback? onAnterior;

  // Linha em branco separadora entre atributos
  // Comentários originais do autor mantidos byte a byte:
  /// Callback acionado ao tocar na seta de próxima viagem.
  /// Se nulo, a seta permanece visualmente desabilitada.
  // Atributo onProxima: função callback de navegação para a próxima viagem (ou nulo se for a última)
  // Tipo: VoidCallback? anulável
  final VoidCallback? onProxima;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Campos opcionais descritos na Issue #13:
  // Atributo motoristaNome: nome do condutor da viagem
  // Tipo: String? anulável
  final String? motoristaNome;
  // Atributo destino: município ou instituição de destino da viagem
  // Tipo: String? anulável
  final String? destino;
  // Atributo veiculo: identificador ou placa do automóvel utilizado
  // Tipo: String? anulável
  final String? veiculo;
  // Atributo saida: horário previsto de partida do transporte
  // Tipo: String? anulável
  final String? saida;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe MotoristaHeader
  // Recebe parâmetros nomeados para inicialização de todos os dados do cabeçalho
  const MotoristaHeader({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado obrigatório: título da viagem
    required this.tituloViagem,
    // Parâmetro nomeado opcional: callback para a viagem anterior
    this.onAnterior,
    // Parâmetro nomeado opcional: callback para a próxima viagem
    this.onProxima,
    // Parâmetros opcionais para dados secundários do transporte
    this.motoristaNome,
    this.destino,
    this.veiculo,
    this.saida,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e getter auxiliar
  // Comentário original do autor mantido byte a byte:
  /// Verifica se ao menos um dos campos secundários opcionais foi fornecido e não está vazio.
  // Getter computado _possuiDadosSecundarios: avalia se há informações secundárias válidas para exibição
  // Retorna: bool (true se ao menos um campo secundário tiver caracteres não vazios após trim)
  bool get _possuiDadosSecundarios {
    // Avaliação lógica com operador OR (||) e chamadas com operador de navegação segura (?.)
    return (motoristaNome?.trim().isNotEmpty == true) ||
        (destino?.trim().isNotEmpty == true) ||
        (veiculo?.trim().isNotEmpty == true) ||
        (saida?.trim().isNotEmpty == true);
  // Fecha o corpo do getter
  }

  // Linha em branco separadora entre getter e build

  // Anotação indicando que o método build sobrescreve a definição de StatelessWidget
  @override
  // Método build: reconstrói a árvore de widgets correspondente ao cabeçalho interativo
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (instância de Container com o seletor de viagens e eventuais detalhes secundários)
  Widget build(BuildContext context) {
    // Avalia se o callback de viagem anterior foi fornecido
    final bool anteriorHabilitado = onAnterior != null;
    // Avalia se o callback de próxima viagem foi fornecido
    final bool proximaHabilitado = onProxima != null;

    // Linha em branco separadora entre flags e retorno do Container
    // Widget Container: caixa de layout decorada envolvendo todo o cabeçalho
    // Elemento: Classe Container de 'package:flutter/widgets.dart'
    return Container(
      // Propriedade width: preenche 100% da largura horizontal disponível (double.infinity)
      width: double.infinity,
      // Propriedade decoration: formato visual com cantos arredondados, fundo branco e borda sutil
      decoration: BoxDecoration(
        // Cor de fundo branca pura
        color: Colors.white,
        // Cantos arredondados com raio geométrico de 10 pixels
        borderRadius: BorderRadius.circular(10),
        // Borda perimetral de 1.0 pixel com cor cinza claro (grey.shade300)
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
      // Fecha a instanciação de BoxDecoration
      ),
      // Propriedade padding: preenchimento interno constante de 4 pixels horizontal e vertical
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      // Propriedade child de Container: coluna que empilha a linha do seletor e a linha secundária
      // Widget Column: organiza verticalmente os filhos ajustando sua altura ao conteúdo mínimo
      child: Column(
        // Propriedade mainAxisSize: limita a altura da coluna ao tamanho exato dos seus filhos (MainAxisSize.min)
        mainAxisSize: MainAxisSize.min,
        // Propriedade children da Column do cabeçalho: linha do seletor e linha de dados secundários
        children: [
          // Widget Row: organiza horizontalmente a seta anterior, o título e a seta próxima
          Row(
            // Propriedade children da Row de navegação: botão anterior, título expandido e botão próximo
            children: [
              // Widget IconButton: botão acessível com ícone de seta para a esquerda (viagem anterior)
              // Elemento: Classe IconButton com restrições mínimas de área de toque acessível (48x48dp)
              IconButton(
                // Propriedade constraints: estabelece dimensões mínimas de 48 pixels para atender às diretrizes de acessibilidade WCAG
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                // Propriedade icon: glifo de seta anterior (arrow_back_ios_new)
                icon: Icon(
                  // Identificador do ícone Material
                  Icons.arrow_back_ios_new,
                  // Dimensão do ícone de 20 pixels lógicos
                  size: 20,
                  // Cor dinâmica: azul escuro se ativo, cinza suave se desabilitado
                  color: anteriorHabilitado
                      ? Colors.blueGrey[900]
                      : Colors.grey[400],
                // Fecha a instanciação de Icon
                ),
                // Propriedade tooltip: texto de dica de acessibilidade para leitores de tela
                tooltip: 'Viagem anterior',
                // Propriedade onPressed: repassa o callback onAnterior (se nulo, desabilita visualmente o botão)
                onPressed: onAnterior,
              // Fecha o widget IconButton anterior
              ),
              // Widget Expanded: expande o título para ocupar todo o espaço central entre as duas setas
              Expanded(
                // Propriedade child de Expanded: widget Text centralizado do título da viagem
                child: Text(
                  // String com o título da viagem (ex: 'Viagem #1')
                  tituloViagem,
                  // Alinhamento centralizado do texto
                  textAlign: TextAlign.center,
                  // Limita a exibição a 1 linha única
                  maxLines: 1,
                  // Trunca com reticências (...) caso o título seja excessivamente longo
                  overflow: TextOverflow.ellipsis,
                  // Propriedade style: formatação tipográfica em negrito com tom azul escuro
                  style: TextStyle(
                    // Tamanho da fonte de 16 pixels lógicos
                    fontSize: 16,
                    // Peso negrito para dar destaque ao título da viagem ativa
                    fontWeight: FontWeight.bold,
                    // Cor azul acinzentado escuro (blueGrey[900])
                    color: Colors.blueGrey[900],
                  // Fecha a TextStyle do título
                  ),
                // Fecha o widget Text do título
                ),
              // Fecha o widget Expanded do título
              ),
              // Widget IconButton: botão acessível com ícone de seta para a direita (próxima viagem)
              // Elemento: Classe IconButton com restrições mínimas de acessibilidade de 48x48dp
              IconButton(
                // Propriedade constraints: estabelece dimensões mínimas de 48 pixels lógicos
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                // Propriedade icon: glifo de seta próxima (arrow_forward_ios)
                icon: Icon(
                  // Identificador do ícone Material
                  Icons.arrow_forward_ios,
                  // Dimensão do ícone de 20 pixels lógicos
                  size: 20,
                  // Cor dinâmica: azul escuro se ativo, cinza se desabilitado
                  color: proximaHabilitado
                      ? Colors.blueGrey[900]
                      : Colors.grey[400],
                // Fecha a instanciação de Icon
                ),
                // Propriedade tooltip: texto acessível para leitores de tela
                tooltip: 'Próxima viagem',
                // Propriedade onPressed: repassa o callback onProxima
                onPressed: onProxima,
              // Fecha o widget IconButton próximo
              ),
            // Fecha a lista children da Row de navegação
            ],
          // Fecha a Row de navegação
          ),
          // Comentário original do autor mantido byte a byte:
          // Linha secundária compacta renderizada SOMENTE se algum campo opcional for informado
          // Renderização condicional por operador spread (...): exibe detalhes complementares se _possuiDadosSecundarios for verdadeiro
          if (_possuiDadosSecundarios) ...[
            // Widget Divider: linha horizontal divisória fina com altura de 4 pixels e espessura de 0.8 pixels
            const Divider(height: 4, thickness: 0.8),
            // Widget Padding: preenchimento em torno da linha secundária de dados
            Padding(
              // Espaçamento interno de 10 pixels horizontal e 6 vertical
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              // Propriedade child de Padding: widget Wrap que ajusta fluidamente os chips de dados secundários
              // Widget Wrap: distribui os itens horizontalmente permitindo quebra de linha harmoniosa se o espaço faltar
              child: Wrap(
                // Espaçamento horizontal entre os itens no Wrap (12 pixels)
                spacing: 12,
                // Espaçamento vertical entre as linhas de quebra do Wrap (4 pixels)
                runSpacing: 4,
                // Alinhamento horizontal centralizado dos itens no Wrap
                alignment: WrapAlignment.center,
                // Alinhamento vertical centralizado dos itens no eixo cruzado
                crossAxisAlignment: WrapCrossAlignment.center,
                // Propriedade children do Wrap: lista condicional de itens com ícone e texto
                children: [
                  // Renderização condicional do motorista: exibe chip se motoristaNome for informado
                  if (motoristaNome?.trim().isNotEmpty == true)
                    // Invocação do widget privado _ItemDadoSecundario
                    _ItemDadoSecundario(
                      // Ícone de usuário/motorista
                      icone: Icons.person_outline,
                      // String aparada com o nome do condutor
                      valor: motoristaNome!.trim(),
                    // Fecha a chamada de _ItemDadoSecundario do motorista
                    ),
                  // Renderização condicional do destino: exibe chip se destino for informado
                  if (destino?.trim().isNotEmpty == true)
                    // Invocação de _ItemDadoSecundario
                    _ItemDadoSecundario(
                      // Ícone de localização/alfinete de mapa
                      icone: Icons.location_on_outlined,
                      // String aparada com o destino da viagem
                      valor: destino!.trim(),
                    // Fecha a chamada de _ItemDadoSecundario do destino
                    ),
                  // Renderização condicional do veículo: exibe chip se veiculo for informado
                  if (veiculo?.trim().isNotEmpty == true)
                    // Invocação de _ItemDadoSecundario
                    _ItemDadoSecundario(
                      // Ícone de transporte/ônibus
                      icone: Icons.directions_bus_outlined,
                      // String aparada com a identificação do veículo
                      valor: veiculo!.trim(),
                    // Fecha a chamada de _ItemDadoSecundario do veículo
                    ),
                  // Renderização condicional do horário de saída: exibe chip se saida for informada
                  if (saida?.trim().isNotEmpty == true)
                    // Invocação de _ItemDadoSecundario
                    _ItemDadoSecundario(
                      // Ícone de relógio
                      icone: Icons.access_time_outlined,
                      // String aparada com o horário de partida
                      valor: saida!.trim(),
                    // Fecha a chamada de _ItemDadoSecundario do horário de saída
                    ),
                // Fecha a lista children do Wrap de dados secundários
                ],
              // Fecha o widget Wrap
              ),
            // Fecha o widget Padding de dados secundários
            ),
          // Fecha o bloco condicional spread de dados secundários
          ],
        // Fecha a lista children da Column do cabeçalho
        ],
      // Fecha a Column do cabeçalho
      ),
    // Fecha o widget Container do cabeçalho
    );
  // Fecha o método build
  }
// Fecha a classe MotoristaHeader
}

// Linha em branco separadora entre MotoristaHeader e _ItemDadoSecundario
// Comentário original do autor mantido byte a byte:
/// Item visual compacto para informações secundárias com ícone e texto
// Widget StatelessWidget privado que compõe cada pílula de detalhe secundário
// Elemento: Classe StatelessWidget privada encapsulada para padronizar o layout compacto de cada informação
class _ItemDadoSecundario extends StatelessWidget {
  // Atributo icone: glifo gráfico característico da informação exibida
  // Tipo: IconData imutável
  final IconData icone;
  // Atributo valor: texto descritivo do dado
  // Tipo: String imutável
  final String valor;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe _ItemDadoSecundario com parâmetros nomeados obrigatórios
  const _ItemDadoSecundario({required this.icone, required this.valor});

  // Linha em branco separadora entre construtor e build

  // Anotação indicando que o método build sobrescreve StatelessWidget
  @override
  // Método build: constrói a pequena linha horizontal com ícone e texto
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (Row com alinhamento compacto)
  Widget build(BuildContext context) {
    // Widget Row: organiza horizontalmente o ícone e o texto
    return Row(
      // Propriedade mainAxisSize: ajusta a largura ao espaço mínimo necessário (MainAxisSize.min)
      mainAxisSize: MainAxisSize.min,
      // Propriedade children da Row do item secundário: ícone, espaçamento e texto flexível
      children: [
        // Widget Icon: glifo gráfico em tamanho compacto de 14 pixels lógicos
        Icon(icone, size: 14, color: const Color(0xFF64748B)),
        // Widget SizedBox: espaçamento horizontal constante de 4 pixels lógicos
        const SizedBox(width: 4),
        // Widget Flexible: permite que o texto se ajuste sem quebrar o layout caso o espaço seja restrito
        Flexible(
          // Propriedade child de Flexible: widget Text contendo a string do valor
          child: Text(
            // String com o conteúdo textual do item
            valor,
            // Limita a exibição a no máximo 1 linha
            maxLines: 1,
            // Trunca com reticências (...) em caso de estouro horizontal
            overflow: TextOverflow.ellipsis,
            // Propriedade style: formatação tipográfica compacta
            style: const TextStyle(
              // Tamanho da fonte de 12 pixels lógicos
              fontSize: 12,
              // Peso médio (w500)
              fontWeight: FontWeight.w500,
              // Cor cinza ardósia intermediária (0xFF64748B, Slate 500)
              color: Color(0xFF64748B),
            // Fecha a TextStyle do item secundário
            ),
          // Fecha o widget Text do item secundário
          ),
        // Fecha o widget Flexible do item secundário
        ),
      // Fecha a lista children da Row do item secundário
      ],
    // Fecha a Row do item secundário
    );
  // Fecha o método build de _ItemDadoSecundario
  }
// Fecha a declaração da classe _ItemDadoSecundario
}
