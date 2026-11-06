// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/card_dados_consulta.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o card detalhado do agendamento médico (CardDadosConsulta) e suas
// linhas informativas (_ItemLinhaConsulta), exibindo para o paciente o hospital
// ou clínica de destino, o horário agendado com lembrete de antecedência,
// o local de embarque e endereço residencial, além dos dados do acompanhante.
//
// PARA QUE SERVE NO PROJETO:
// É o bloco informativo principal da tela do paciente (lib/paciente.dart),
// proporcionando clareza e previsibilidade sobre o atendimento de saúde fora
// do município, facilitando a pontualidade no embarque e a segurança do usuário.
//
// ONDE É USADO NO PROJETO:
// - lib/paciente.dart (seção central do painel do paciente)
//
// DE ONDE RECEBE DADOS:
// Parâmetros repassados pelo widget pai com os dados do agendamento (localConsulta,
// horarioConsulta, localSaida, enderecoPaciente e nomeAcompanhante).
//
// O QUE EXPORTA / EXPÕE:
// - class CardDadosConsulta extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 5c6320b pela equipe na issue de criação do painel do paciente.
// Não provém de template ou scaffold.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente de 'package:flutter/material.dart'.
// Componente de apresentação puro: sem efeitos colaterais, sem I/O e sem rede.
// ============================================================================

// Importa a biblioteca central Material Design do Flutter com componentes visuais essenciais
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e CardDadosConsulta
// Comentário original do autor mantido byte a byte:
// Componente que exibe os detalhes do agendamento médico e da logística de embarque
// Declaração do widget StatelessWidget CardDadosConsulta
// Elemento: Classe StatelessWidget do Flutter para exibição consolidada dos dados do agendamento de saúde
class CardDadosConsulta extends StatelessWidget {
  // Atributo localConsulta: nome do hospital, clínica ou unidade de saúde de destino da consulta
  // Tipo: String imutável
  final String localConsulta;
  // Atributo horarioConsulta: horário previsto para o atendimento médico agendado (ex: "08:30")
  // Tipo: String imutável
  final String horarioConsulta;
  // Atributo localSaida: ponto de partida ou referência de embarque do transporte (ex: UBS Central, Residência)
  // Tipo: String imutável
  final String localSaida;
  // Atributo enderecoPaciente: logradouro residencial completo cadastrado para o paciente
  // Tipo: String imutável
  final String enderecoPaciente;
  // Atributo nomeAcompanhante: nome completo do acompanhante autorizado (opcional)
  // Tipo: String? anulável
  final String? nomeAcompanhante;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe CardDadosConsulta
  // Recebe parâmetros nomeados para inicialização de todos os dados do agendamento médico
  const CardDadosConsulta({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado obrigatório: nome do local da consulta médica
    required this.localConsulta,
    // Parâmetro nomeado obrigatório: horário do agendamento
    required this.horarioConsulta,
    // Parâmetro nomeado obrigatório: local de saída/embarque
    required this.localSaida,
    // Parâmetro nomeado obrigatório: endereço residencial completo do paciente
    required this.enderecoPaciente,
    // Parâmetro nomeado opcional: nome do acompanhante do paciente
    this.nomeAcompanhante,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Anotação indicando que o método build sobrescreve a definição da classe StatelessWidget
  @override
  // Método build: constrói a árvore de widgets correspondente ao card de dados do agendamento
  // Recebe: context (BuildContext contendo a localização do widget na hierarquia de elementos)
  // Retorna: Widget (instância de Card estilizado contendo a coluna de informações)
  Widget build(BuildContext context) {
    // Widget Card: componente retangular elevado do Material Design com cantos arredondados e sombra suave
    // Elemento: Classe Card de 'package:flutter/material.dart'
    // Retorna: Card contendo a coluna vertical de dados do agendamento
    return Card(
      // Propriedade elevation: elevação da sombra projetada pelo card em pixels lógicos (2 pontos para leve destaque)
      elevation: 2,
      // Propriedade shape: define os contornos geométricos com cantos arredondados de raio 16
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Propriedade child de Card: widget Padding que aplica espaçamento interno em todas as direções
      // Widget Padding: aplica margem interna constante em volta do conteúdo
      child: Padding(
        // Comentário original do autor mantido byte a byte:
        // Padding aumentado em ~15% (de 16 para 18.5)
        // EdgeInsets.symmetric: espaçamento interno horizontal e vertical de 18.5 pixels lógicos
        padding: const EdgeInsets.symmetric(horizontal: 18.5, vertical: 18.5),
        // Propriedade child de Padding: widget Column que empilha verticalmente as seções do card
        // Widget Column: organiza seus filhos sequencialmente de cima para baixo
        child: Column(
          // Propriedade crossAxisAlignment: alinha os elementos filhos à esquerda no eixo horizontal
          crossAxisAlignment: CrossAxisAlignment.start,
          // Propriedade children: lista sequencial de widgets filhos exibidos na coluna
          children: [
            // Comentário original do autor mantido byte a byte:
            // Cabeçalho da Seção (~15% maior)
            // Widget Row: organiza horizontalmente o título da seção e o rótulo temporal 'Hoje'
            Row(
              // Propriedade mainAxisAlignment: distribui o espaço uniformemente entre as extremidades (espaço entre os filhos)
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // Propriedade children da Row de cabeçalho: título e indicador de data
              children: [
                // Widget Text: exibe o rótulo em caixa alta 'DADOS DO AGENDAMENTO'
                const Text(
                  // Texto estático do cabeçalho da seção
                  'DADOS DO AGENDAMENTO',
                  // Propriedade style: formatação tipográfica do cabeçalho
                  style: TextStyle(
                    // Tamanho da fonte aumentado para 12.5 pixels lógicos
                    fontSize: 12.5,
                    // Peso negrito para dar destaque ao título da seção
                    fontWeight: FontWeight.bold,
                    // Espaçamento entre letras de 0.5 pixels
                    letterSpacing: 0.5,
                    // Cor cinza ardósia suave (0xFF64748B, Slate 500)
                    color: Color(0xFF64748B),
                  // Fecha a TextStyle do título da seção
                  ),
                // Fecha o widget Text do título
                ),
                // Widget Text: exibe o indicador temporal de agendamento ('Hoje')
                Text(
                  // String com o texto fixo 'Hoje'
                  'Hoje',
                  // Propriedade style: formatação visual suave para a indicação de hoje
                  style: TextStyle(
                    // Tamanho da fonte de 12.5 pixels
                    fontSize: 12.5,
                    // Peso semi-negrito (w600)
                    fontWeight: FontWeight.w600,
                    // Cor cinza intermediária (grey.shade500)
                    color: Colors.grey.shade500,
                  // Fecha a TextStyle de 'Hoje'
                  ),
                // Fecha o widget Text de 'Hoje'
                ),
              // Fecha a lista children da Row de cabeçalho
              ],
            // Fecha o widget Row de cabeçalho
            ),
            // Widget Divider: linha divisória horizontal sutil separando o cabeçalho dos itens
            // height: 22 define a altura total do espaço ocupado pela divisória
            const Divider(height: 22),

            // Comentário original do autor mantido byte a byte:
            // Item 1: Local da Consulta Médica
            // Invocação do widget privado _ItemLinhaConsulta para o local de atendimento
            _ItemLinhaConsulta(
              // Ícone representativo de hospital/estabelecimento de saúde
              icone: Icons.local_hospital_outlined,
              // Rótulo textual da informação
              label: 'Local da Consulta',
              // Valor textual recebido no atributo localConsulta
              valor: localConsulta,
            // Fecha a invocação de _ItemLinhaConsulta para o local da consulta
            ),
            // Widget SizedBox: espaçamento vertical constante de 14 pixels lógicos entre as linhas
            const SizedBox(height: 14),

            // Comentário original do autor mantido byte a byte:
            // Item 2: Horário Agendado
            // Invocação do widget privado _ItemLinhaConsulta para o horário da consulta com texto de aviso
            _ItemLinhaConsulta(
              // Ícone representativo de relógio de parede / horário
              icone: Icons.access_time_outlined,
              // Rótulo textual da informação
              label: 'Horário Previsto',
              // Valor textual recebido no atributo horarioConsulta
              valor: horarioConsulta,
              // Detalhe extra com recomendação de antecedência exibido em azul
              detalheExtra: '(Chegar com antecedência)',
            // Fecha a invocação de _ItemLinhaConsulta para o horário previsto
            ),
            // Widget SizedBox: espaçamento vertical constante de 14 pixels lógicos entre as linhas
            const SizedBox(height: 14),

            // Comentário original do autor mantido byte a byte:
            // Item 3: Local de Embarque e Residência
            // Invocação de _ItemLinhaConsulta combinando o local de saída especificado com o endereço residencial
            _ItemLinhaConsulta(
              // Ícone de alfinete de mapa/localização geográfica
              icone: Icons.location_on_outlined,
              // Rótulo textual indicando embarque e endereço
              label: 'Local de Saída / Embarque',
              // Expressão ternária condicional: se localSaida não for vazio, concatena local com endereço entre parênteses; senão exibe apenas endereço
              valor: localSaida.isNotEmpty
                  ? '$localSaida ($enderecoPaciente)'
                  : enderecoPaciente,
            // Fecha a invocação de _ItemLinhaConsulta para o local de saída/embarque
            ),

            // Comentário original do autor mantido byte a byte:
            // Item 4: Informação de Acompanhante (se houver vaga reservada)
            // Renderização condicional por operador spread (...): exibe linha de acompanhante se preenchido
            if (nomeAcompanhante != null && nomeAcompanhante!.isNotEmpty) ...[
              // Widget SizedBox: espaçamento vertical constante de 14 pixels lógicos
              const SizedBox(height: 14),
              // Invocação de _ItemLinhaConsulta para exibição dos dados do acompanhante
              _ItemLinhaConsulta(
                // Ícone de contorno representando grupo de pessoas
                icone: Icons.people_outline,
                // Rótulo textual da linha
                label: 'Acompanhante',
                // Valor textual com interpolação do nome do acompanhante
                valor: '$nomeAcompanhante',
              // Fecha a invocação de _ItemLinhaConsulta para o acompanhante
              ),
            // Fecha o bloco condicional spread de acompanhante
            ],
          // Fecha a lista children da Column do card
          ],
        // Fecha o widget Column do card
        ),
      // Fecha o widget Padding do card
      ),
    // Fecha o widget Card retornado
    );
  // Fecha o método build
  }
// Fecha a declaração da classe CardDadosConsulta
}

// Linha em branco separadora entre CardDadosConsulta e _ItemLinhaConsulta
// Comentário original do autor mantido byte a byte:
// Item interno com ícone temático, rótulo e valor dimensionados com ~15% de aumento
// Widget StatelessWidget privado que compõe cada linha temática do card
// Elemento: Classe StatelessWidget privada encapsulada para padronizar o layout de cada item informativo
class _ItemLinhaConsulta extends StatelessWidget {
  // Atributo icone: glifo gráfico característico exibido no container decorado à esquerda
  // Tipo: IconData imutável
  final IconData icone;
  // Atributo label: texto do cabeçalho da informação exibido em caixa alta
  // Tipo: String imutável
  final String label;
  // Atributo valor: texto principal contendo a informação ou dado cadastral
  // Tipo: String imutável
  final String valor;
  // Atributo detalheExtra: texto opcional de aviso exibido em azul ao lado do valor
  // Tipo: String? anulável
  final String? detalheExtra;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante da classe _ItemLinhaConsulta
  // Recebe parâmetros nomeados para compor visualmente a linha informativa
  const _ItemLinhaConsulta({
    // Parâmetro nomeado obrigatório: dado de ícone
    required this.icone,
    // Parâmetro nomeado obrigatório: rótulo textual
    required this.label,
    // Parâmetro nomeado obrigatório: conteúdo textual
    required this.valor,
    // Parâmetro nomeado opcional: texto complementar
    this.detalheExtra,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Anotação indicando sobrescrita do método build de StatelessWidget
  @override
  // Método build: constrói a árvore de widgets correspondente à linha com ícone e textos
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (Row contendo o container do ícone e a coluna de textos)
  Widget build(BuildContext context) {
    // Widget Row: organiza horizontalmente o container do ícone à esquerda e os textos à direita
    // Elemento: Classe Row do Flutter
    return Row(
      // Propriedade crossAxisAlignment: alinha os filhos no topo (start) para alinhamento harmonioso com múltiplas linhas de texto
      crossAxisAlignment: CrossAxisAlignment.start,
      // Propriedade children da Row de item: container com ícone, espaçamento e textos expandidos
      children: [
        // Comentário original do autor mantido byte a byte:
        // Container do ícone aumentado em ~15% (de 32x32 para 37x37)
        // Widget Container: caixa quadrada com cantos arredondados e cor azul claro suave de fundo
        Container(
          // Largura fixa do container em pixels lógicos (37 pontos)
          width: 37,
          // Altura fixa do container em pixels lógicos (37 pontos)
          height: 37,
          // Propriedade decoration: formato visual com cantos arredondados e fundo azul suave
          decoration: BoxDecoration(
            // Cor azul claro muito suave (0xFFEFF6FF, Blue 50)
            color: const Color(0xFFEFF6FF),
            // Cantos arredondados com raio geométrico de 10 pixels
            borderRadius: BorderRadius.circular(10),
          // Fecha a instanciação de BoxDecoration
          ),
          // Propriedade child de Container: widget Icon centralizado dentro da caixa
          // Widget Icon: renderiza o glifo icone recebido com cor azul vibrante
          child: Icon(icone, size: 21, color: const Color(0xFF2563EB)),
        // Fecha o widget Container do ícone
        ),
        // Widget SizedBox: espaçamento horizontal constante de 12 pixels lógicos entre ícone e textos
        const SizedBox(width: 12),
        // Widget Expanded: expande a coluna de textos para ocupar todo o espaço restante na linha
        Expanded(
          // Propriedade child de Expanded: coluna vertical empilhando o rótulo e a linha de valor
          child: Column(
            // Propriedade crossAxisAlignment: alinha os textos à esquerda
            crossAxisAlignment: CrossAxisAlignment.start,
            // Propriedade children da Column de texto: rótulo, espaçamento e linha de valor/detalhe
            children: [
              // Widget Text: exibe o rótulo da informação em letras maiúsculas
              Text(
                // Invocação do método toUpperCase() na string do rótulo
                label.toUpperCase(),
                // Propriedade style: formatação tipográfica do rótulo
                style: const TextStyle(
                  // Tamanho da fonte de 11.5 pixels lógicos
                  fontSize: 11.5,
                  // Peso negrito para fácil identificação da categoria
                  fontWeight: FontWeight.bold,
                  // Cor cinza ardósia intermediária (0xFF64748B, Slate 500)
                  color: Color(0xFF64748B),
                // Fecha a TextStyle do rótulo
                ),
              // Fecha o widget Text do rótulo
              ),
              // Widget SizedBox: espaçamento vertical constante de 2 pixels lógicos entre rótulo e valor
              const SizedBox(height: 2),
              // Widget Row: organiza horizontalmente o valor principal e eventual detalhe complementar
              Row(
                // Propriedade children da Row de valor: texto do valor expandido e detalhe condicional
                children: [
                  // Widget Expanded: expande o texto do valor evitando corte feio
                  Expanded(
                    // Propriedade child de Expanded: widget Text com o conteúdo do valor
                    child: Text(
                      // Expressão condicional: se o valor não estiver vazio exibe-o; senão exibe 'Não informado'
                      valor.isNotEmpty ? valor : 'Não informado',
                      // Propriedade style: formatação tipográfica principal do valor
                      style: const TextStyle(
                        // Tamanho da fonte destacado de 15 pixels lógicos
                        fontSize: 15,
                        // Peso da fonte semi-negrito (w600)
                        fontWeight: FontWeight.w600,
                        // Cor ardósia muito escura (0xFF0F172A, Slate 900) para máxima legibilidade
                        color: Color(0xFF0F172A),
                      // Fecha a TextStyle do valor
                      ),
                    // Fecha o widget Text do valor
                    ),
                  // Fecha o widget Expanded do valor
                  ),
                  // Renderização condicional por operador spread (...): exibe detalhe extra se fornecido
                  if (detalheExtra != null) ...[
                    // Widget SizedBox: espaçamento horizontal constante de 6 pixels lógicos antes do detalhe
                    const SizedBox(width: 6),
                    // Widget Text: renderiza a mensagem de aviso em cor azul destacada
                    Text(
                      // String do detalhe extra garantidamente não nula neste bloco condicional
                      detalheExtra!,
                      // Propriedade style: formatação tipográfica do detalhe
                      style: const TextStyle(
                        // Tamanho da fonte de 12.5 pixels
                        fontSize: 12.5,
                        // Cor azul petróleo (0xFF0284C7, Sky 600)
                        color: Color(0xFF0284C7),
                        // Peso médio da fonte (w500)
                        fontWeight: FontWeight.w500,
                      // Fecha a TextStyle do detalhe extra
                      ),
                    // Fecha o widget Text do detalhe extra
                    ),
                  // Fecha o bloco condicional spread do detalhe extra
                  ],
                // Fecha a lista children da Row de valor
                ],
              // Fecha o widget Row de valor
              ),
            // Fecha a lista children da Column de texto
            ],
          // Fecha o widget Column de texto
          ),
        // Fecha o widget Expanded da coluna de texto
        ),
      // Fecha a lista children da Row principal do item
      ],
    // Fecha o widget Row principal do item
    );
  // Fecha o método build de _ItemLinhaConsulta
  }
// Fecha a declaração da classe _ItemLinhaConsulta
}
