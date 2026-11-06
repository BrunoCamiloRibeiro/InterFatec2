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

// Importa o pacote de componentes e design Material do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports do framework e imports internos
// Importa o modelo PacienteModel para obtenção centralizada de cores e labels de status
import '../models/paciente_model.dart';
// Importa o utilitário TextAbbreviator para abreviação de nomes longos
import 'abreviar_textos.dart';

// Linha em branco separadora entre imports e a classe do componente
// Comentários originais do autor mantidos byte a byte:
// Componente que exibe os dados de identificação e status do paciente logado
// Também reutilizado na Gestão de Pessoas com callbacks opcionais de edição e inativação
// Declaração do widget StatelessWidget CardIdentificacaoPaciente
class CardIdentificacaoPaciente extends StatelessWidget {
  // Nome completo da pessoa ou paciente
  final String nome;
  // Cadastro de Pessoa Física (CPF) formatado
  final String cpf;
  // Código numérico de status de viagem (padrão 0)
  final int status;
  // Rótulo customizado do badge (se omitido, usa o status da viagem)
  final String? labelBadge;
  // Cor temática do badge
  final Color? corBadge;
  // Número de telefone para contato
  final String? telefone;
  // Informação complementar (ex: local de saída ou veículo)
  final String? detalheExtra;
  // Callback disparado ao clicar no botão Editar
  final VoidCallback? onEditar;
  // Callback disparado ao clicar no botão Inativar
  final VoidCallback? onInativar;
  // Callback disparado ao tocar em qualquer área do card
  final VoidCallback? onTap;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados
  const CardIdentificacaoPaciente({
    // Chave opcional do widget
    super.key,
    // Parâmetro obrigatório para o nome
    required this.nome,
    // Parâmetro obrigatório para o CPF
    required this.cpf,
    // Parâmetro opcional de status com valor padrão 0
    this.status = 0,
    // Parâmetro opcional para rótulo do badge
    this.labelBadge,
    // Parâmetro opcional para cor do badge
    this.corBadge,
    // Parâmetro opcional para telefone
    this.telefone,
    // Parâmetro opcional para detalhe extra
    this.detalheExtra,
    // Parâmetro opcional para callback de edição
    this.onEditar,
    // Parâmetro opcional para callback de inativação
    this.onInativar,
    // Parâmetro opcional para callback de toque no card
    this.onTap,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para montagem do layout do card
  @override
  // Constrói a árvore de widgets do card de identificação
  Widget build(BuildContext context) {
    // Comentário original do autor mantido byte a byte:
    // Reaproveita a definição centralizada de status do PacienteModel quando label customizada não é passada
    // Desestrutura a tupla de status retornada por PacienteModel.dadosStatus
    final (textoPadrao, corPadrao, _) = PacienteModel.dadosStatus(status);
    // Resolve o texto do badge priorizando label customizada
    final badgeTexto = labelBadge ?? textoPadrao;
    // Resolve a cor do badge priorizando cor customizada
    final badgeCor = corBadge ?? corPadrao;

    // Linha em branco separadora entre resolução de dados e montagem do Card
    // Retorna Card com elevação e cantos arredondados
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      // InkWell para fornecer efeito visual de toque (ripple) caso onTap seja fornecido
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        // Padding interno do card
        child: Padding(
          // Comentário original do autor mantido byte a byte:
          // Padding interno aumentado em ~10% (18.0) para melhor respiro visual
          // Espaçamento interno de 18 pontos
          padding: const EdgeInsets.all(18.0),
          // Coluna organizando os elementos verticalmente
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Comentário original do autor mantido byte a byte:
              // Cabeçalho do Card: Label de identificação e Badge de Status / Categoria
              // Linha horizontal com o título do card e a badge colorida
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Texto descritivo da seção superior
                  Text(
                    labelBadge != null
                        ? 'CADASTRO DE PESSOA'
                        : 'IDENTIFICAÇÃO DO PACIENTE',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  // Container da badge com cantos arredondados e fundo translúcido
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeCor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: badgeCor.withValues(alpha: 0.3),
                      ),
                    ),
                    // Texto dentro da badge
                    child: Text(
                      badgeTexto,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeCor,
                      ),
                    ),
                  ),
                ],
              ),
              // Espaçamento vertical de 14 pontos
              const SizedBox(height: 14),

              // Comentário original do autor mantido byte a byte:
              // Perfil: Avatar com iniciais, Nome abreviado e CPF
              // Linha horizontal contendo o avatar e os textos de nome e CPF
              Row(
                children: [
                  // Avatar circular com a primeira letra do nome
                  CircleAvatar(
                    radius: 26.5,
                    backgroundColor: const Color(0xFF0F172A),
                    child: Text(
                      nome.isNotEmpty ? nome[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  // Espaçamento horizontal de 14 pontos
                  const SizedBox(width: 14),
                  // Coluna expandida com nome e CPF
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nome abreviado com limite de 28 caracteres
                        Text(
                          TextAbbreviator.abbreviate(nome, maxCharacters: 28),
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        // Espaçamento vertical de 3 pontos
                        const SizedBox(height: 3),
                        // Texto do CPF formatado
                        Text(
                          'CPF: $cpf',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Linha em branco separadora entre perfil e linhas adicionais
              // Comentário original do autor mantido byte a byte:
              // Linhas adicionais informativas (Telefone e Detalhes de Consulta/Veículo)
              // Renderiza a linha de telefone caso o parâmetro esteja presente
              if (telefone != null && telefone!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      telefone!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ],
              // Renderiza a linha de detalhe extra caso fornecida
              if (detalheExtra != null && detalheExtra!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        detalheExtra!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Linha em branco separadora entre dados e barra de ações
              // Comentário original do autor mantido byte a byte:
              // Barra de ações administrativas (Editar e Inativar) quando fornecidas
              // Renderiza botões de ação se callbacks tiverem sido passados
              if (onEditar != null || onInativar != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 6),
                // Linha alinhada à direita com os botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Botão de Editar
                    if (onEditar != null)
                      TextButton.icon(
                        onPressed: onEditar,
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        label: const Text(
                          'Editar',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // Botão de Inativar
                    if (onInativar != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onInativar,
                        icon: const Icon(
                          Icons.person_off_outlined,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        label: const Text(
                          'Inativar',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
