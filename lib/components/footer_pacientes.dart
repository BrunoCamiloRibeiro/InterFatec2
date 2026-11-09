// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/footer_pacientes.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o rodapé compacto e fixo (FooterPacientes) da tela de viagens do
// motorista, apresentando a contagem de assentos ocupados versus a lotação total
// do veículo municipal e o botão de ação rápida "Gerar Relatório", responsável
// por disparar o modal FormularioEncerramento para baixa final e emissão do PDF.
//
// PARA QUE SERVE NO PROJETO:
// Fornece ao condutor a visualização imediata da capacidade do veículo durante
// a rota e o atalho de encerramento do transporte de saúde, repassando os dados
// da viagem ativa e da lista de passageiros para o diálogo de finalização.
//
// ONDE É USADO NO PROJETO:
// - lib/motorista.dart (posicionado como bottomNavigationBar do Scaffold principal)
//
// DE ONDE RECEBE DADOS:
// Parâmetros repassados pelo motorista.dart: lugaresPreenchidos, lugaresTotais,
// instância opcional de ViagemModel e lista opcional de PacienteModel.
//
// O QUE EXPORTA / EXPÕE:
// - class FooterPacientes extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 588756d pela equipe do projeto na tarefa de footer compacto.
// Não provém de template ou scaffold gerado automaticamente.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente do framework Material do Flutter e modelos internos.
// Efeitos colaterais: abre o diálogo modal showDialog exibindo FormularioEncerramento.
// ============================================================================

// Importa o framework Material Design do Flutter com widgets de interface para botões, ícones e barra inferior
import 'package:flutter/material.dart';

// Linha em branco separadora entre framework e modelos internos
// Importa o modelo PacienteModel para repasse da lista de passageiros ao formulário de encerramento
import '../models/paciente_model.dart';
// Importa o modelo ViagemModel para repasse dos dados da viagem ativa ao formulário de encerramento
import '../models/viagem_model.dart';
// Importa o formulário de encerramento (FormularioEncerramento) disparado ao clicar no botão de relatório
import 'formulario_encerramento.dart';
// Importa o serviço de gerenciamento de viagens para recuperar N viagens ativas (Issue #65)
import '../services/viagem_service.dart';

// Linha em branco separadora entre imports e a declaração de FooterPacientes
// Comentários originais do autor mantidos byte a byte:
// Componente visual do Footer (rodapé) da lista de pacientes do motorista.
// Estrutura compacta em linha única: ocupação de lugares na esquerda e botão que abre o Popup de encerramento na direita.
// Declaração do widget StatelessWidget FooterPacientes
// Elemento: Classe StatelessWidget imutável do Flutter para renderização da barra de rodapé da viagem
class FooterPacientes extends StatelessWidget {
  // Comentário original do autor mantido byte a byte:
  // Quantidade de lugares ocupados atualmente no veículo
  // Atributo lugaresPreenchidos: número inteiro de passageiros e acompanhantes embarcados
  // Tipo: int imutável
  final int lugaresPreenchidos;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Capacidade total de lugares do veículo
  // Atributo lugaresTotais: capacidade máxima de passageiros suportada pelo veículo municipal
  // Tipo: int imutável
  final int lugaresTotais;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Dados da viagem ativa e pacientes para geração do PDF de encerramento
  // Atributo viagem: instância com os dados da viagem atual em andamento (opcional)
  // Tipo: ViagemModel? anulável
  final ViagemModel? viagem;
  // Lista opcional de todas as viagens ativas da sessão do motorista
  final List<ViagemModel>? viagens;
  // Atributo pacientes: lista contendo os pacientes vinculados ao transporte (opcional)
  // Tipo: List<PacienteModel>? anulável
  final List<PacienteModel>? pacientes;
  // Callback opcional acionado assim que a viagem é encerrada pelo motorista
  final VoidCallback? onViagemEncerrada;

  // Linha em branco separadora entre atributos e construtor
  // Comentário original do autor mantido byte a byte:
  // Construtor recebendo os números de lugares preenchidos e totais
  // Construtor constante da classe FooterPacientes com parâmetros nomeados
  const FooterPacientes({
    // Parâmetro opcional de chave de identificação do widget na árvore do Flutter
    super.key,
    // Parâmetro nomeado obrigatório: quantidade de assentos ocupados
    required this.lugaresPreenchidos,
    // Parâmetro nomeado obrigatório: total de assentos do veículo
    required this.lugaresTotais,
    // Parâmetro nomeado opcional: objeto da viagem ativa
    this.viagem,
    // Parâmetro nomeado opcional: lista de viagens ativas da sessão
    this.viagens,
    // Parâmetro nomeado opcional: lista de pacientes transportados
    this.pacientes,
    // Parâmetro nomeado opcional: callback ao encerrar viagem
    this.onViagemEncerrada,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Anotação indicando que o método build sobrescreve a definição de StatelessWidget
  @override
  // Método build: constrói a árvore de widgets correspondente à barra de rodapé fixada na tela do condutor
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (instância de Container decorado com fundo branco e divisória superior)
  Widget build(BuildContext context) {
    // Comentário original do autor mantido byte a byte:
    // Container compacto do rodapé com fundo branco e linha divisória no topo
    // Widget Container: caixa de layout decorada com preenchimento interno e borda superior divisória
    // Elemento: Classe Container de 'package:flutter/widgets.dart'
    return Container(
      // Propriedade decoration: estilo visual com fundo branco e linha de borda no topo
      decoration: BoxDecoration(
        // Cor de fundo branca sólida para contraste com a lista
        color: Colors.white,
        // Propriedade border: borda customizada do container
        border: Border(
          // Comentário original do autor mantido byte a byte:
          // Borda superior sutil para separar o Footer da lista de pacientes
          // Borda superior sutil com espessura de 1.0 pixel e cor cinza clara (grey.shade300)
          top: BorderSide(color: Colors.grey.shade300, width: 1.0),
        // Fecha a instanciação de Border
        ),
      // Fecha a instanciação de BoxDecoration
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // Propriedade padding: preenchimento interno constante de 16 horizontal e 10 vertical em pixels lógicos
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          // Comentário original do autor mantido byte a byte:
          // Linha única horizontal dividindo esquerda (lugares) e direita (botão)
          // Propriedade child de Container: widget Row distribuindo ocupação de lugares e botão de relatório
          // Widget Row: organiza horizontalmente os itens entre as extremidades
          child: Row(
        // Propriedade mainAxisAlignment: afasta os filhos posicionando um na extrema esquerda e outro na extrema direita
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // Propriedade children da Row principal do rodapé: bloco de lugares e botão de encerramento
        children: [
          // Comentário original do autor mantido byte a byte:
          // ESQUERDA: Informação do número de passageiros/assentos (preenchidos / total)
          // Widget Row: organiza o ícone de assento e o texto de contagem lado a lado
          Row(
            // Propriedade children da Row de assentos: ícone, espaçamento e texto com contagem
            children: [
              // Widget Icon: glifo gráfico de assento de veículo (event_seat_outlined)
              Icon(
                // Identificador do ícone
                Icons.event_seat_outlined,
                // Dimensão do ícone de 20 pixels lógicos
                size: 20,
                // Cor azul acinzentado escuro (blueGrey[900])
                color: Colors.blueGrey[900],
              // Fecha a instanciação de Icon
              ),
              // Widget SizedBox: espaçamento horizontal constante de 8 pixels lógicos
              const SizedBox(width: 8),
              // Coluna compacta com lugares preenchidos/totais e lugares disponíveis
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Widget Text: exibe a contagem formatada de lugares preenchidos e totais
                  Text(
                    // Interpolação de strings exibindo 'Lugares: X / Y'
                    'Lugares: $lugaresPreenchidos / $lugaresTotais',
                    // Propriedade style: formatação tipográfica em negrito
                    style: TextStyle(
                      // Tamanho da fonte de 14 pixels lógicos
                      fontSize: 14,
                      // Peso da fonte em negrito
                      fontWeight: FontWeight.bold,
                      // Cor azul acinzentado escuro harmonizada com o ícone
                      color: Colors.blueGrey[900],
                    // Fecha a TextStyle de contagem
                    ),
                  // Fecha o widget Text de contagem
                  ),
                  Text(
                    'Disponíveis: ${(lugaresTotais - lugaresPreenchidos).clamp(0, lugaresTotais)}',
                    key: const Key('textoLugaresDisponiveisFooter'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (lugaresTotais - lugaresPreenchidos) > 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            // Fecha a lista children da Row de assentos
            ],
          // Fecha a Row de assentos
          ),

          // Linha em branco separadora entre esquerda e direita
          // Comentário original do autor mantido byte a byte:
          // DIREITA: Botão compacto que abre o POPUP do Formulário de Encerramento
          // Widget ElevatedButton.icon: botão elevado com ícone e texto para emissão do relatório de encerramento
          ElevatedButton.icon(
            // Propriedade style: customização de cores, padding, cantos e elevação do botão
            style: ElevatedButton.styleFrom(
              // Cor de fundo azul acinzentado escuro (blueGrey[900])
              backgroundColor: Colors.blueGrey[900],
              // Cor do texto e ícone branca pura (white)
              foregroundColor: Colors.white,
              // Preenchimento interno compacto de 14 horizontal e 10 vertical
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              // Cantos arredondados com raio geométrico de 8 pixels
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              // Fecha o RoundedRectangleBorder
              ),
              // Elevação da sombra de 2 pixels lógicos
              elevation: 2,
            // Fecha a chamada de ElevatedButton.styleFrom
            ),
            // Propriedade icon: ícone de prancheta de tarefas (assignment_outlined)
            icon: const Icon(Icons.assignment_outlined, size: 18),
            // Propriedade label: texto do botão 'Gerar Relatório'
            label: const Text(
              // Rótulo textual da ação
              'Gerar Relatório',
              // Propriedade style: tipografia compacta em negrito
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            // Fecha o widget Text do rótulo
            ),
            // Propriedade onPressed: callback executado ao clicar no botão
            onPressed: () async {
              // Pergunta de confirmação obrigatória antes de finalizar a viagem
              final bool? querFinalizar = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    key: const Key('dialogConfirmarFinalizacaoViagem'),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: Colors.blueGrey[900],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Finalizar Viagem',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                      ],
                    ),
                    content: const Text(
                      'Você tem certeza que quer finalizar a viagem?',
                      style: TextStyle(fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        key: const Key('botaoCancelarFinalizacao'),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      ElevatedButton(
                        key: const Key('botaoConfirmarFinalizacao'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[900],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text(
                          'Sim, finalizar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
              );

              // Se o condutor cancelar ou fechar o diálogo, não prossegue
              if (querFinalizar != true || !context.mounted) return;

              // Comentário original do autor mantido byte a byte:
              // Abre o POPUP do Formulário de Encerramento (Retorno, Km Retorno, Km Rodado e Emissão PDF)
              // Função showDialog: exibe caixa de diálogo modal flutuante na tela
              final viagensParaEncerrar = (viagens != null && viagens!.isNotEmpty)
                  ? viagens!
                  : (ViagemService().viagensAtivas.isNotEmpty
                      ? ViagemService().viagensAtivas
                      : (viagem != null ? <ViagemModel>[viagem!] : const <ViagemModel>[]));

              showDialog<bool>(
                // Contexto de build da tela
                context: context,
                // Função builder que instancia o FormularioEncerramento
                builder: (BuildContext context) {
                  // Widget FormularioEncerramento: formulário com campos de retorno e botão de emissão do PDF
                  return FormularioEncerramento(
                    // Repassa o objeto da viagem ativa
                    viagem: viagem,
                    // Repassa a lista de todas as N viagens ativas (Issue #65)
                    viagens: viagensParaEncerrar,
                    // Repassa a lista de pacientes transportados
                    pacientes: pacientes,
                    // Notifica o encerramento para redirecionar o motorista ao início de viagem
                    onViagemEncerrada: onViagemEncerrada,
                  // Fecha a instanciação de FormularioEncerramento
                  );
                // Fecha a função builder do diálogo
                },
              // Fecha a chamada de showDialog
              );
            // Fecha a função anônima de onPressed
            },
          // Fecha o widget ElevatedButton.icon
          ),
        // Fecha a lista children da Row principal do rodapé
        ],
      // Fecha o widget Row principal do rodapé
      ),
        ),
      ),
    // Fecha o widget Container do rodapé
    );
  // Fecha o método build
  }
// Fecha a classe FooterPacientes
}
