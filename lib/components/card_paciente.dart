// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/card_paciente.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o card visual e interativo de cada passageiro na lista de viagem
// do motorista (CardPaciente). Exibe as informações do paciente (nome abreviado
// via TextAbbreviator, endereço residencial, telefone), bloco de acompanhante
// (CardAcompanhante), locais de consulta médica e saída, banner colorido de status
// e barra de progresso por segmentos (IndicadorProgresso). Ao toque, exibe
// diálogo modal de confirmação para ações de embarque, desembarque ou baixa.
//
// PARA QUE SERVE NO PROJETO:
// É o elemento central de interação operacional do motorista durante a viagem,
// permitindo visualizar os dados clínicos/logísticos do passageiro e coordenar
// as etapas do transporte individual de saúde.
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (renderizado em ListView.builder para cada paciente da viagem ativa)
//
// DE ONDE RECEBE DADOS:
// Propriedades repassadas pela tela do motorista a partir de instâncias de PacienteModel
// (nomePaciente, enderecoPaciente, telPaciente, localConsulta, localSaida, status,
// nomeAcompanhante e telAcompanhante).
//
// O QUE EXPORTA / EXPÕE:
// - class CardPaciente extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 1fffdd1 pela equipe do projeto para a interface do motorista
// e aprimorado nas issues #10 (acompanhante), #12 (cores de status) e #14 (baixa).
// Não provém de scaffold ou template gerado por ferramentas.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende de 'package:flutter/material.dart' e dos componentes internos.
// Efeitos colaterais: exibe diálogo de alerta via showDialog(context: ...).
// ============================================================================

// Importa o framework Material Design do Flutter com widgets para cartões, listas, ícones e diálogos
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports do framework e imports internos
// Importa o modelo PacienteModel para obtenção centralizada de textos, cores e ícones de status da viagem
import '../models/paciente_model.dart';

// Linha em branco separadora entre modelos e componentes filhos
// Importa o utilitário TextAbbreviator para abreviação inteligente de nomes próprios longos
import '../components/abreviar_textos.dart';
// Importa o indicador segmental de progresso da viagem (IndicadorProgresso)
import '../components/indicador_progresso.dart';
// Importa o bloco visual de acompanhante do paciente (CardAcompanhante)
import '../components/bloco_acompanhante.dart';

// Linha em branco separadora entre imports e a declaração de CardPaciente
// Declaração do widget StatelessWidget CardPaciente
// Elemento: Classe StatelessWidget imutável do Flutter para renderizar o cartão completo do passageiro
class CardPaciente extends StatelessWidget {
  // Atributo nomePaciente: nome completo do paciente a ser atendido no transporte
  // Tipo: String imutável
  final String nomePaciente;
  // Atributo enderecoPaciente: endereço residencial onde o paciente será embarcado ou desembarcado
  // Tipo: String imutável
  final String enderecoPaciente;
  // Atributo telPaciente: número de telefone para contato telefônico com o passageiro
  // Tipo: String imutável
  final String telPaciente;
  // Atributo localConsulta: unidade médica de destino da consulta (ex: Hospital de Base)
  // Tipo: String imutável
  final String localConsulta;
  // Atributo localSaida: ponto de partida especificado para a viagem (ex: UBS Central, Residência)
  // Tipo: String imutável
  final String localSaida;
  // Atributo status: código numérico que identifica a etapa atual do paciente no transporte (0 a 5)
  // Tipo: int imutável
  final int status;
  // Comentário original do autor mantido byte a byte:
  // Dados do acompanhante vinculados ao paciente (Issue #10)
  // Atributo nomeAcompanhante: nome completo do acompanhante do paciente, se houver
  // Tipo: String? anulável
  final String? nomeAcompanhante;
  // Atributo telAcompanhante: telefone para contato com o acompanhante, se houver
  // Tipo: String? anulável
  final String? telAcompanhante;

  // Linha em branco separadora entre atributos e construtor

  // Construtor principal da classe CardPaciente
  // Recebe parâmetros nomeados para inicialização de todos os atributos do passageiro
  CardPaciente({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado obrigatório: nome completo do passageiro
    required this.nomePaciente,
    // Parâmetro nomeado obrigatório: endereço residencial
    required this.enderecoPaciente,
    // Parâmetro nomeado obrigatório: telefone de contato
    required this.telPaciente,
    // Parâmetro nomeado obrigatório: local da consulta médica
    required this.localConsulta,
    // Parâmetro nomeado obrigatório: local de partida/saída
    required this.localSaida,
    // Parâmetro nomeado obrigatório: código de status numérico da viagem
    required this.status,
    // Parâmetro nomeado opcional: nome do acompanhante
    this.nomeAcompanhante,
    // Parâmetro nomeado opcional: telefone do acompanhante
    this.telAcompanhante,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Anotação indicando que o método build sobrescreve a definição de StatelessWidget
  @override
  // Método build: constrói a árvore de widgets correspondente ao card do paciente na lista do motorista
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (instância de Card elevado com detecção de toque InkWell)
  Widget build(BuildContext context) {
    // Invocação de PacienteModel.dadosStatus: resolve a tupla de status a partir do código numérico
    // Elemento: Desestruturação de tupla (textoStatus: String, corStatus: Color, iconeStatus: IconData)
    final (textoStatus, corStatus, iconeStatus) = PacienteModel.dadosStatus(
      status,
    );

    // Linha em branco separadora entre resolução de dados e montagem do Card
    // Widget Card: componente de cartão elevado com bordas arredondadas e sombra destacada
    // Elemento: Classe Card de 'package:flutter/material.dart'
    return Card(
      // Propriedade elevation: elevação da sombra em pixels lógicos (12 pontos para forte destaque na lista)
      elevation: 12,
      // Propriedade child de Card: widget interativo InkWell que responde a toques do condutor
      // Widget InkWell: adiciona comportamento tátil com efeito de onda ao tocar no card
      child: InkWell(
        // Comentário original do autor mantido byte a byte:
        // O InkWell fica logo DENTRO do Card por conta da animação
        // Propriedade onTap: callback acionado quando o usuário toca em qualquer região do card
        onTap: () {
          // Expressão switch de padrão do Dart 3: mapeia o código de status numérico para o rótulo da ação a ser confirmada
          String acaoTexto = switch (status) {
            // Se o status for 0 (Aguardando), a próxima ação operacional é o embarque do paciente
            0 => 'o embarque',
            // Se o status for 1 (Em Trânsito), a próxima ação operacional é o desembarque na consulta
            1 => 'o desembarque',
            // Se o status for 2 (Na Consulta), a próxima ação operacional é a conclusão do transporte
            2 => 'a conclusão',
            // Caso padrão coringa (_) para quaisquer outros valores de status
            _ => 'esta alteração',
          // Fecha a expressão switch
          };

          // Linha em branco separadora entre cálculo do texto e abertura do diálogo
          // Função showDialog: exibe uma caixa de diálogo modal flutuante na tela atual
          // Recebe: context (BuildContext) e builder (função construtora do diálogo)
          showDialog(
            // Contexto de build da árvore de elementos
            context: context,
            // Função builder que constrói o diálogo AlertDialog
            builder: (BuildContext context) {
              // Widget AlertDialog: caixa de alerta com título, conteúdo explicativo e botões de ação
              return AlertDialog(
                // Propriedade title: título do diálogo modal de confirmação
                title: Text('Confirmação'),
                // Propriedade content: corpo textual da mensagem solicitando confirmação do motorista
                content: Text(
                  // Interpolação de strings formatando o nome da ação e do paciente em letras maiúsculas
                  'Deseja confirmar ${acaoTexto.toUpperCase()} do passageiro ${nomePaciente.toUpperCase()}?',
                // Fecha o widget Text do conteúdo do diálogo
                ),
                // Propriedade actions: lista de botões alinhados na base do diálogo
                actions: [
                  // Widget TextButton: botão para cancelar a operação sem aplicar nenhuma alteração
                  TextButton(
                    // Callback executado ao clicar em Cancelar
                    onPressed: () {
                      // Navigator.of(context).pop(): fecha a tela modal do diálogo desempilhando-a
                      Navigator.of(context).pop();
                    // Fecha a função anônima de onPressed
                    },
                    // Rótulo textual do botão Cancelar
                    child: Text('Cancelar'),
                  // Fecha o widget TextButton de Cancelar
                  ),
                  // Widget TextButton: botão para confirmar a alteração operacional de status
                  TextButton(
                    // Callback executado ao clicar em Confirmar
                    onPressed: () {
                      // Comentário original do autor mantido byte a byte:
                      // IMPLEMENTAR A LÓGICA DE ATUALIZAÇÃO DE STATUS AQUI
                      // Navigator.of(context).pop(): fecha a tela modal do diálogo desempilhando-a
                      Navigator.of(context).pop();
                    // Fecha a função anônima de onPressed
                    },
                    // Rótulo textual do botão Confirmar
                    child: Text('Confirmar'),
                  // Fecha o widget TextButton de Confirmar
                  ),
                // Fecha a lista de ações do AlertDialog
                ],
              // Fecha o widget AlertDialog
              );
            // Fecha a função builder do diálogo
            },
          // Fecha a chamada da função showDialog
          );
        // Fecha a função anônima de onTap do InkWell
        },
        // Propriedade child de InkWell: container decorativo que envolve o conteúdo visual do card
        // Widget Container: caixa de layout com padding e decoração de borda
        child: Container(
          // Propriedade padding: preenchimento interno de 10 pixels lógicos em todas as direções
          padding: EdgeInsets.all(10),
          // Propriedade decoration: define as bordas do container
          decoration: BoxDecoration(
            // Propriedade border: borda do container
            border: Border(
              // Comentário original do autor mantido byte a byte:
              // left: BorderSide(color: Colors.blueGrey[900]!, width: 5.0),
            // Fecha a instanciação de Border
            ),
          // Fecha a instanciação de BoxDecoration
          ),
          // Propriedade child de Container: widget ListTile que organiza título e subtítulo
          // Widget ListTile: componente do Material Design para itens de lista estruturados
          child: ListTile(
            // Comentário original do autor mantido byte a byte:
            // TITLE: Apenas as informações do paciente (Nome, Endereço, Telefone)
            // Propriedade title de ListTile: coluna vertical com dados pessoais do paciente
            title: Column(
              // Propriedade crossAxisAlignment: alinha os elementos à esquerda no eixo horizontal
              crossAxisAlignment: CrossAxisAlignment.start,
              // Propriedade children da Column de título: linhas com nome, endereço, telefone e acompanhante
              children: [
                // Widget Row: organiza horizontalmente o ícone de pessoa e o nome abreviado do paciente
                Row(
                  // Propriedade children da Row de nome: ícone, espaçamento e texto expandido
                  children: [
                    // Widget Icon: glifo gráfico de pessoa (person_2_outlined) com tamanho de 25 pontos
                    const Icon(Icons.person_2_outlined, size: 25),
                    // Widget SizedBox: espaçamento horizontal constante de 5 pixels lógicos
                    const SizedBox(width: 5),
                    // Widget Expanded: expande o nome para preencher o espaço horizontal sem transbordar
                    Expanded(
                      // Propriedade child de Expanded: widget Text com o nome do paciente abreviado
                      child: Text(
                        // Invocação do utilitário TextAbbreviator.abbreviate para encurtamento inteligente
                        TextAbbreviator.abbreviate(
                          // Parâmetro posicional: string com o nome completo do paciente
                          nomePaciente,
                          // Parâmetro nomeado: limite máximo de 30 caracteres
                          maxCharacters: 30,
                          // Parâmetro nomeado: limite de no máximo 4 palavras
                          maxWords: 4,
                          // Parâmetro nomeado: preserva 1 palavra do meio por extenso
                          keepWords: 1,
                        // Converte o texto final para letras maiúsculas
                        ).toUpperCase(),
                        // Comentário original do autor mantido byte a byte:
                        // nomePaciente.toUpperCase(),
                        // Comentários originais do autor mantidos byte a byte:
                        maxLines: 2, // Permite até X linhas para nomes grandes
                        overflow: TextOverflow
                            .ellipsis, // Coloca '...' se passar de 2 linhas
                        // Propriedade style: formatação tipográfica em negrito
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      // Fecha o widget Text do nome
                      ),
                    // Fecha o widget Expanded do nome
                    ),
                  // Fecha a lista children da Row de nome
                  ],
                // Fecha a Row de nome do paciente
                ),
                // Widget Row: organiza horizontalmente o ícone de casa e o endereço do paciente
                Row(
                  // Propriedade children da Row de endereço: ícone, espaçamento e texto expandido
                  children: [
                    // Widget Icon: glifo de contorno de casa (house_outlined) com tamanho de 25 pontos
                    const Icon(Icons.house_outlined, size: 25),
                    // Widget SizedBox: espaçamento horizontal constante de 5 pixels lógicos
                    const SizedBox(width: 5),
                    // Widget Expanded: expande o endereço para preencher o espaço horizontal
                    Expanded(
                      // Propriedade child de Expanded: widget Text com o endereço residencial
                      child: Text(
                        // String contendo o endereço residencial do passageiro
                        enderecoPaciente,
                        // Propriedade maxLines: limita a exibição a no máximo 2 linhas
                        maxLines: 2,
                        // Propriedade overflow: adiciona reticências (...) caso exceda o limite
                        overflow: TextOverflow.ellipsis,
                        // Propriedade style: formatação tipográfica do endereço
                        style: const TextStyle(
                          // Tamanho da fonte de 15 pixels lógicos
                          fontSize: 15.0,
                          // Peso em negrito para facilitar leitura pelo motorista
                          fontWeight: FontWeight.bold,
                        // Fecha a TextStyle do endereço
                        ),
                      // Fecha o widget Text do endereço
                      ),
                    // Fecha o widget Expanded do endereço
                    ),
                  // Fecha a lista children da Row de endereço
                  ],
                // Fecha a Row de endereço do paciente
                ),
                // Widget Row: organiza horizontalmente o ícone de telefone e o número de contato
                Row(
                  // Propriedade children da Row de telefone: ícone, espaçamento e texto expandido
                  children: [
                    // Widget Icon: glifo de contorno de telefone (phone_outlined) com tamanho de 23 pontos
                    const Icon(Icons.phone_outlined, size: 23),
                    // Widget SizedBox: espaçamento horizontal constante de 5 pixels lógicos
                    const SizedBox(width: 5),
                    // Widget Expanded: expande o telefone para preencher o espaço horizontal
                    Expanded(
                      // Propriedade child de Expanded: widget Text com o telefone
                      child: Text(
                        // String contendo o número telefônico do passageiro
                        telPaciente,
                        // Propriedade maxLines: limita a 2 linhas
                        maxLines: 2,
                        // Propriedade overflow: reticências em caso de estouro
                        overflow: TextOverflow.ellipsis,
                        // Propriedade style: formatação tipográfica do telefone
                        style: const TextStyle(
                          // Tamanho da fonte de 13.5 pixels lógicos
                          fontSize: 13.5,
                          // Peso em negrito
                          fontWeight: FontWeight.bold,
                        // Fecha a TextStyle do telefone
                        ),
                      // Fecha o widget Text do telefone
                      ),
                    // Fecha o widget Expanded do telefone
                    ),
                  // Fecha a lista children da Row de telefone
                  ],
                // Fecha a Row de telefone do paciente
                ),
                // Comentário original do autor mantido byte a byte:
                // Exibe o card do acompanhante caso esteja preenchido
                // Renderização condicional: exibe o componente CardAcompanhante se houver acompanhante válido
                if (nomeAcompanhante != null &&
                    nomeAcompanhante!.trim().isNotEmpty)
                  // Widget CardAcompanhante: componente dedicado para exibir os dados do acompanhante
                  CardAcompanhante(
                    // Passa o nome do acompanhante garantidamente não nulo
                    nomeAcompanhante: nomeAcompanhante!,
                    // Comentário original do autor mantido byte a byte:
                    telAcompanhante:
                        telAcompanhante ??
                        '', // Fallback vazio caso nulo no Firestore
                  // Fecha a chamada de CardAcompanhante
                  ),
              // Fecha a lista children da Column de título
              ],
            // Fecha a Column de título
            ),

            // Linha em branco separadora entre title e subtitle
            // Comentário original do autor mantido byte a byte:
            // SUBTITLE: Locais de Consulta/Saída e o Status logo abaixo
            // Propriedade subtitle de ListTile: coluna vertical contendo locais de consulta, saída e badge de status
            subtitle: Column(
              // Propriedade crossAxisAlignment: alinha à esquerda
              crossAxisAlignment: CrossAxisAlignment.start,
              // Propriedade children da Column de subtítulo: divisória, locais de consulta/saída e caixa de status
              children: [
                // Widget SizedBox: espaçamento vertical de 8 pixels lógicos
                SizedBox(height: 8),
                // Widget Divider: linha divisória horizontal separando título de subtítulo
                Divider(),
                // Widget SizedBox: espaçamento vertical de 4 pixels lógicos
                SizedBox(height: 4),
                // Comentário original do autor mantido byte a byte:
                // Local de Consulta
                // Widget Row: organiza horizontalmente o ícone médico e o nome do local de consulta
                Row(
                  // Propriedade children da Row de local de consulta: ícone, espaçamento e texto expandido
                  children: [
                    // Widget Icon: glifo de maleta médica (medical_services_outlined) com tamanho de 20 pontos
                    const Icon(Icons.medical_services_outlined, size: 20),
                    // Widget SizedBox: espaçamento horizontal constante de 5 pixels lógicos
                    const SizedBox(width: 5),
                    // Widget Expanded: expande o local de consulta evitando overflow
                    Expanded(
                      // Propriedade child de Expanded: widget Text do local de consulta
                      child: Text(
                        // String contendo o nome da unidade de saúde ou hospital
                        localConsulta,
                        // Comentário original do autor mantido byte a byte:
                        maxLines: 2, // Alterado de 1 para 2
                        // Propriedade overflow: trunca com reticências se exceder 2 linhas
                        overflow: TextOverflow.ellipsis,
                        // Propriedade style: formatação tipográfica do local de consulta
                        style: const TextStyle(
                          // Tamanho da fonte de 14 pixels lógicos
                          fontSize: 14,
                          // Peso em negrito
                          fontWeight: FontWeight.bold,
                        // Fecha a TextStyle do local de consulta
                        ),
                      // Fecha o widget Text do local de consulta
                      ),
                    // Fecha o widget Expanded do local de consulta
                    ),
                  // Fecha a lista children da Row de local de consulta
                  ],
                // Fecha a Row de local de consulta
                ),
                // Widget SizedBox: espaçamento vertical de 4 pixels lógicos
                SizedBox(height: 4),
                // Comentário original do autor mantido byte a byte:
                // Local de Saída
                // Widget Row: organiza horizontalmente o ícone de saída e a descrição do local de embarque
                Row(
                  // Propriedade children da Row de local de saída: ícone, espaçamento e texto expandido
                  children: [
                    // Widget Icon: glifo de porta de saída (exit_to_app_outlined) com tamanho de 20 pontos
                    const Icon(Icons.exit_to_app_outlined, size: 20),
                    // Widget SizedBox: espaçamento horizontal constante de 5 pixels lógicos
                    const SizedBox(width: 5),
                    // Widget Expanded: expande o texto do local de saída
                    Expanded(
                      // Propriedade child de Expanded: widget Text do local de saída
                      child: Text(
                        // String contendo a descrição do local de saída/embarque
                        localSaida,
                        // Comentário original do autor mantido byte a byte:
                        maxLines: 2, // Alterado de 1 para 2
                        // Propriedade overflow: trunca com reticências se exceder 2 linhas
                        overflow: TextOverflow.ellipsis,
                        // Propriedade style: formatação tipográfica do local de saída
                        style: const TextStyle(
                          // Tamanho da fonte de 14 pixels lógicos
                          fontSize: 14,
                          // Peso em negrito
                          fontWeight: FontWeight.bold,
                        // Fecha a TextStyle do local de saída
                        ),
                      // Fecha o widget Text do local de saída
                      ),
                    // Fecha o widget Expanded do local de saída
                    ),
                  // Fecha a lista children da Row de local de saída
                  ],
                // Fecha a Row de local de saída
                ),
                // Widget SizedBox: espaçamento vertical de 8 pixels lógicos
                SizedBox(height: 8),
                // Comentários originais do autor mantidos byte a byte:
                // Badge de Status
                // Badge(
                //   backgroundColor: corStatus,
                //   label: Container(
                //     padding: EdgeInsets.symmetric(
                //       horizontal: 8.0,
                //       vertical: 2.0,
                //     ),
                //     child: Text(
                //       textoStatus,
                //       style: TextStyle(fontSize: 12.0, color: Colors.white),
                //     ),
                //   ),
                // ),
                // Widget Container: caixa visual com cantos arredondados e cor translúcida de status
                Container(
                  // Propriedade padding: preenchimento interno constante de 12 pixels lógicos
                  padding: const EdgeInsets.all(12),
                  // Propriedade decoration: estilo visual de cantos arredondados e cor suave
                  decoration: BoxDecoration(
                    // Cor de fundo com 20% de opacidade sobre a cor primária do status
                    color: corStatus.withValues(alpha: 0.2),
                    // Cantos arredondados com raio geométrico de 12 pixels
                    borderRadius: BorderRadius.circular(12),
                  // Fecha a instanciação de BoxDecoration
                  ),
                  // Propriedade child de Container: coluna vertical contendo linha de status e barra de progresso
                  child: Column(
                    // Propriedade children da Column da caixa de status: linha com ícone/texto e indicador segmental
                    children: [
                      // Widget Row: organiza horizontalmente o ícone e o texto do status atual
                      Row(
                        // Propriedade children da Row de status: ícone, espaçamento e texto
                        children: [
                          // Widget Icon: glifo representativo da etapa atual (iconeStatus)
                          Icon(iconeStatus, size: 20),
                          // Widget SizedBox: espaçamento horizontal constante de 5 pixels lógicos
                          const SizedBox(width: 5),
                          // Widget Expanded: expande o texto do status para ocupar a linha sem transbordar
                          Expanded(
                            // Propriedade child de Expanded: widget Text do status
                            child: Text(
                              // String com a descrição do status resolvido
                              textoStatus,
                              // Limita a exibição a 1 linha
                              maxLines: 1,
                              // Trunca com reticências caso necessário
                              overflow: TextOverflow.ellipsis,
                              // Propriedade style: formatação tipográfica do status
                              style: TextStyle(
                                // Tamanho da fonte de 14 pixels lógicos
                                fontSize: 14,
                                // Peso em negrito para destaque visual
                                fontWeight: FontWeight.bold,
                                // Comentário original do autor mantido byte a byte:
                                color: Color.lerp(
                                  corStatus,
                                  Colors.black,
                                  0.4,
                                )!, // Escurece o texto
                              // Fecha a TextStyle do status
                              ),
                            // Fecha o widget Text do status
                            ),
                          // Fecha o widget Expanded do status
                          ),
                        // Fecha a lista children da Row de status
                        ],
                      // Fecha a Row de status
                      ),
                      // Widget SizedBox: espaçamento vertical de 10 pixels lógicos acima da barra de progresso
                      SizedBox(height: 10),
                      // Invocação do widget IndicadorProgresso: renderiza os segmentos coloridos da viagem
                      IndicadorProgresso(
                        // Valor numérico da etapa atual do paciente
                        valorAtual: status,
                        // Valor máximo de etapas: 1 se status for 0, senão 4
                        valorMaximo: (status == 0) ? 1 : 4,
                        // Cor ativa com opacidade total (alpha 255)
                        corAtiva: corStatus.withAlpha(255),
                        // Cor inativa dos segmentos não alcançados (cinza)
                        corInativa: Colors.grey,
                      // Fecha a invocação de IndicadorProgresso
                      ),
                    // Fecha a lista children da Column da caixa de status
                    ],
                  // Fecha a Column da caixa de status
                  ),
                // Fecha o Container da caixa de status
                ),
              // Fecha a lista children da Column de subtítulo
              ],
            // Fecha a Column de subtítulo
            ),
          // Fecha o widget ListTile
          ),
        // Fecha o widget Container interno do card
        ),
      // Fecha o widget InkWell
      ),
    // Fecha o widget Card retornado
    );
  // Fecha o método build
  }
// Fecha a declaração da classe CardPaciente
}
