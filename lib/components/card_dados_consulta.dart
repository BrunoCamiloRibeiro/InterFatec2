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

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e CardDadosConsulta
// Comentário original do autor mantido byte a byte:
// Componente que exibe os detalhes do agendamento médico e da logística de embarque
// Declaração do widget StatelessWidget CardDadosConsulta
class CardDadosConsulta extends StatelessWidget {
  // Local de atendimento médico no município de destino (ex: Hospital de Base)
  final String localConsulta;
  // Horário previsto para a realização da consulta médica
  final String horarioConsulta;
  // Ponto de saída do transporte (ex: Residência ou UBS)
  final String localSaida;
  // Endereço residencial completo do paciente
  final String enderecoPaciente;
  // Nome completo do acompanhante do paciente se houver
  final String? nomeAcompanhante;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados
  const CardDadosConsulta({
    // Chave opcional do widget
    super.key,
    // Parâmetro obrigatório para o local da consulta
    required this.localConsulta,
    // Parâmetro obrigatório para o horário da consulta
    required this.horarioConsulta,
    // Parâmetro obrigatório para o local de saída
    required this.localSaida,
    // Parâmetro obrigatório para o endereço do paciente
    required this.enderecoPaciente,
    // Parâmetro opcional para o nome do acompanhante
    this.nomeAcompanhante,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para montagem do layout do card
  @override
  // Constrói a estrutura visual do card com as informações de agendamento
  Widget build(BuildContext context) {
    // Retorna Card estilizado com cantos arredondados e elevação
    return Card(
      // Elevação suave de 2 pontos para destaque sobre o fundo
      elevation: 2,
      // Forma com cantos arredondados de 16 pontos de raio
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Padding interno do card
      child: Padding(
        // Comentário original do autor mantido byte a byte:
        // Padding aumentado em ~15% (de 16 para 18.5)
        // Espaçamento interno horizontal e vertical
        padding: const EdgeInsets.symmetric(horizontal: 18.5, vertical: 18.5),
        // Coluna organizando os itens em sequência vertical
        child: Column(
          // Alinha os filhos à esquerda
          crossAxisAlignment: CrossAxisAlignment.start,
          // Lista de filhos da coluna
          children: [
            // Comentário original do autor mantido byte a byte:
            // Cabeçalho da Seção (~15% maior)
            // Linha com título da seção e indicação de data
            Row(
              // Espaça os elementos entre as extremidades
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rótulo da seção em caixa alta
                const Text(
                  'DADOS DO AGENDAMENTO',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                // Indicador temporal do agendamento
                Text(
                  'Hoje',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            // Linha divisória horizontal com altura de 22 pontos
            const Divider(height: 22),

            // Comentário original do autor mantido byte a byte:
            // Item 1: Local da Consulta Médica
            // Linha informativa do local de atendimento médico
            _ItemLinhaConsulta(
              icone: Icons.local_hospital_outlined,
              label: 'Local da Consulta',
              valor: localConsulta,
            ),
            // Espaçamento vertical de 14 pontos
            const SizedBox(height: 14),

            // Comentário original do autor mantido byte a byte:
            // Item 2: Horário Agendado
            // Linha informativa do horário da consulta com detalhe extra
            _ItemLinhaConsulta(
              icone: Icons.access_time_outlined,
              label: 'Horário Previsto',
              valor: horarioConsulta,
              detalheExtra: '(Chegar com antecedência)',
            ),
            // Espaçamento vertical de 14 pontos
            const SizedBox(height: 14),

            // Comentário original do autor mantido byte a byte:
            // Item 3: Local de Embarque e Residência
            // Linha informativa do local de saída combinando ponto e endereço
            _ItemLinhaConsulta(
              icone: Icons.location_on_outlined,
              label: 'Local de Saída / Embarque',
              valor: localSaida.isNotEmpty
                  ? '$localSaida ($enderecoPaciente)'
                  : enderecoPaciente,
            ),

            // Comentário original do autor mantido byte a byte:
            // Item 4: Informação de Acompanhante (se houver vaga reservada)
            // Renderiza condicionalmente o item de acompanhante se cadastrado
            if (nomeAcompanhante != null && nomeAcompanhante!.isNotEmpty) ...[
              // Espaçamento vertical de 14 pontos
              const SizedBox(height: 14),
              // Linha informativa com dados do acompanhante
              _ItemLinhaConsulta(
                icone: Icons.people_outline,
                label: 'Acompanhante',
                valor: '$nomeAcompanhante',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Linha em branco separadora entre CardDadosConsulta e _ItemLinhaConsulta
// Comentário original do autor mantido byte a byte:
// Item interno com ícone temático, rótulo e valor dimensionados com ~15% de aumento
// Widget StatelessWidget privado que compõe cada linha temática do card
class _ItemLinhaConsulta extends StatelessWidget {
  // Ícone característico da linha de informação
  final IconData icone;
  // Rótulo descritivo do campo (ex: 'LOCAL DA CONSULTA')
  final String label;
  // Valor textual do dado cadastral
  final String valor;
  // Texto complementar exibido em destaque azul (opcional)
  final String? detalheExtra;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados
  const _ItemLinhaConsulta({
    // Parâmetro obrigatório para o ícone
    required this.icone,
    // Parâmetro obrigatório para o rótulo
    required this.label,
    // Parâmetro obrigatório para o valor
    required this.valor,
    // Parâmetro opcional para o detalhe extra
    this.detalheExtra,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para montagem do layout do item
  @override
  // Constrói a linha com ícone à esquerda e coluna de textos à direita
  Widget build(BuildContext context) {
    // Retorna Row com alinhamento superior
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comentário original do autor mantido byte a byte:
        // Container do ícone aumentado em ~15% (de 32x32 para 37x37)
        // Container arredondado com fundo azul suave
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          // Ícone centralizado com tamanho de 21 pontos
          child: Icon(icone, size: 21, color: const Color(0xFF2563EB)),
        ),
        // Espaçamento horizontal de 12 pontos
        const SizedBox(width: 12),
        // Coluna expandida com rótulo, valor e detalhe extra
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Texto do rótulo em letras maiúsculas
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              // Espaçamento vertical de 2 pontos
              const SizedBox(height: 2),
              // Linha horizontal contendo o valor e o detalhe extra opcional
              Row(
                children: [
                  // Texto do valor expandido para quebra limpa
                  Expanded(
                    child: Text(
                      valor.isNotEmpty ? valor : 'Não informado',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  // Se houver detalhe extra, exibe-o ao lado
                  if (detalheExtra != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      detalheExtra!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
