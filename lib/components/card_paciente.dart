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

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports do framework e imports internos
// Importa o modelo PacienteModel para obtenção de textos, cores e ícones de status
import '../models/paciente_model.dart';

// Linha em branco separadora entre modelos e componentes filhos
// Importa o utilitário TextAbbreviator para abreviação de nomes longos
import '../components/abreviar_textos.dart';
// Importa o indicador segmental de progresso da viagem
import '../components/indicador_progresso.dart';
// Importa o bloco visual de acompanhante do paciente
import '../components/bloco_acompanhante.dart';

// Linha em branco separadora entre imports e a declaração de CardPaciente
// Declaração do widget StatelessWidget CardPaciente
class CardPaciente extends StatelessWidget {
  // Nome completo do paciente atendido
  final String nomePaciente;
  // Endereço de residência onde o paciente foi ou será buscado
  final String enderecoPaciente;
  // Número de telefone para contato com o paciente
  final String telPaciente;
  // Unidade de saúde ou hospital de destino da consulta
  final String localConsulta;
  // Ponto de partida do transporte (ex: Residência)
  final String localSaida;
  // Código numérico indicando o estágio atual da viagem (0 a 5)
  final int status;
  // Comentário original do autor mantido byte a byte:
  // Dados do acompanhante vinculados ao paciente (Issue #10)
  // Nome completo do acompanhante do paciente (opcional)
  final String? nomeAcompanhante;
  // Telefone para contato com o acompanhante (opcional)
  final String? telAcompanhante;

  // Linha em branco separadora entre atributos e construtor

  // Construtor principal da classe CardPaciente com parâmetros nomeados
  CardPaciente({
    // Chave de identificação opcional do widget
    super.key,
    // Parâmetro obrigatório para o nome do paciente
    required this.nomePaciente,
    // Parâmetro obrigatório para o endereço do paciente
    required this.enderecoPaciente,
    // Parâmetro obrigatório para o telefone do paciente
    required this.telPaciente,
    // Parâmetro obrigatório para o local da consulta médica
    required this.localConsulta,
    // Parâmetro obrigatório para o local de saída
    required this.localSaida,
    // Parâmetro obrigatório para o código numérico de status
    required this.status,
    // Parâmetro opcional para o nome do acompanhante
    this.nomeAcompanhante,
    // Parâmetro opcional para o telefone do acompanhante
    this.telAcompanhante,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para renderização visual do card
  @override
  // Constrói a árvore de widgets do CardPaciente
  Widget build(BuildContext context) {
    // Desestrutura os dados visuais (texto, cor e ícone) correspondentes ao status atual
    final (textoStatus, corStatus, iconeStatus) = PacienteModel.dadosStatus(
      status,
    );

    // Linha em branco separadora entre resolução de dados e montagem do Card
    // Retorna Card com elevação acentuada de 12 pontos
    return Card(
      elevation: 12,
      // InkWell para capturar toques com feedback visual de onda
      child: InkWell(
        // Comentário original do autor mantido byte a byte:
        // O InkWell fica logo DENTRO do Card por conta da animação
        // Callback executado ao tocar no card do passageiro
        onTap: () {
          // Determina a descrição textual da ação conforme o status numérico atual
          String acaoTexto = switch (status) {
            // Se estiver aguardando transporte (0), a ação é confirmar o embarque
            0 => 'o embarque',
            // Se já tiver embarcado (1), a ação é confirmar o desembarque na consulta
            1 => 'o desembarque',
            // Se estiver desembarcado (2), a ação é confirmar a conclusão ou reembarque
            2 => 'a conclusão',
            // Caso genérico para outros estados
            _ => 'esta alteração',
          };

          // Linha em branco separadora entre cálculo do texto e abertura do diálogo
          // Exibe diálogo modal de confirmação na tela
          showDialog(
            context: context,
            builder: (BuildContext context) {
              // Retorna AlertDialog com título, mensagem e botões de ação
              return AlertDialog(
                title: Text('Confirmação'),
                content: Text(
                  'Deseja confirmar ${acaoTexto.toUpperCase()} do passageiro ${nomePaciente.toUpperCase()}?',
                ),
                actions: [
                  // Botão de texto para cancelamento da ação
                  TextButton(
                    onPressed: () {
                      // Fecha o diálogo modal sem aplicar alterações
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancelar'),
                  ),
                  // Botão de texto para confirmação da ação
                  TextButton(
                    onPressed: () {
                      // Comentário original do autor mantido byte a byte:
                      // IMPLEMENTAR A LÓGICA DE ATUALIZAÇÃO DE STATUS AQUI
                      // Fecha o diálogo modal
                      Navigator.of(context).pop();
                    },
                    child: Text('Confirmar'),
                  ),
                ],
              );
            },
          );
        },
        // Container com preenchimento interno de 10 pontos
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(
              // Comentário original do autor mantido byte a byte:
              // left: BorderSide(color: Colors.blueGrey[900]!, width: 5.0),
            ),
          ),
          // ListTile organizando título com dados pessoais e subtítulo com dados logísticos
          child: ListTile(
            // Comentário original do autor mantido byte a byte:
            // TITLE: Apenas as informações do paciente (Nome, Endereço, Telefone)
            // Coluna contendo os dados pessoais do passageiro
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha horizontal com ícone de pessoa e nome abreviado
                Row(
                  children: [
                    const Icon(Icons.person_2_outlined, size: 25),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        TextAbbreviator.abbreviate(
                          nomePaciente,
                          maxCharacters: 30,
                          maxWords: 4,
                          keepWords: 1,
                        ).toUpperCase(),
                        // Comentário original do autor mantido byte a byte:
                        // nomePaciente.toUpperCase(),
                        // Comentários originais do autor mantidos byte a byte:
                        maxLines: 2, // Permite até X linhas para nomes grandes
                        overflow: TextOverflow
                            .ellipsis, // Coloca '...' se passar de 2 linhas
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                // Linha horizontal com ícone de casa e endereço residencial
                Row(
                  children: [
                    const Icon(Icons.house_outlined, size: 25),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        enderecoPaciente,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                // Linha horizontal com ícone de telefone e número para contato
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 23),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        telPaciente,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                // Comentário original do autor mantido byte a byte:
                // Exibe o card do acompanhante caso esteja preenchido
                // Renderiza o componente CardAcompanhante condicionalmente se preenchido
                if (nomeAcompanhante != null &&
                    nomeAcompanhante!.trim().isNotEmpty)
                  CardAcompanhante(
                    nomeAcompanhante: nomeAcompanhante!,
                    // Comentário original do autor mantido byte a byte:
                    telAcompanhante:
                        telAcompanhante ??
                        '', // Fallback vazio caso nulo no Firestore
                  ),
              ],
            ),

            // Linha em branco separadora entre title e subtitle
            // Comentário original do autor mantido byte a byte:
            // SUBTITLE: Locais de Consulta/Saída e o Status logo abaixo
            // Coluna contendo os locais de consulta/saída e o badge de status
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Divider(),
                SizedBox(height: 4),
                // Comentário original do autor mantido byte a byte:
                // Local de Consulta
                // Linha horizontal com ícone de hospital e nome do local de consulta
                Row(
                  children: [
                    const Icon(Icons.medical_services_outlined, size: 20),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        localConsulta,
                        // Comentário original do autor mantido byte a byte:
                        maxLines: 2, // Alterado de 1 para 2
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                // Comentário original do autor mantido byte a byte:
                // Local de Saída
                // Linha horizontal com ícone de saída e descrição do ponto de partida
                Row(
                  children: [
                    const Icon(Icons.exit_to_app_outlined, size: 20),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        localSaida,
                        // Comentário original do autor mantido byte a byte:
                        maxLines: 2, // Alterado de 1 para 2
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
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
                // Container estilizado com fundo translúcido na cor do status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(iconeStatus, size: 20),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              textoStatus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                // Comentário original do autor mantido byte a byte:
                                color: Color.lerp(
                                  corStatus,
                                  Colors.black,
                                  0.4,
                                )!, // Escurece o texto
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      // Indicador de progresso com segmentos
                      IndicadorProgresso(
                        valorAtual: status,
                        valorMaximo: (status == 0) ? 1 : 4,
                        corAtiva: corStatus.withAlpha(255),
                        corInativa: Colors.grey,
                      ),
                    ],
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
