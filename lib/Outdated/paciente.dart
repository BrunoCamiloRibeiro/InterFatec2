// ============================================================================
// ARQUIVO: lib/Outdated/paciente.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Implementa um protótipo visual legado da tela do paciente (StatelessWidget "Paciente").
// Exibe informações estáticas sobre o transporte da tarde, status "EM TRÂNSITO",
// dados fictícios do motorista e veículo, além de dois botões simulados de ação:
// "Já consegui Carona" e "Estou pronto", que exibem diálogos de confirmação
// imprimindo mensagens via debugPrint.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Código Legado / Obsoleto arquivado (pasta lib/Outdated/). Substituído na
// evolução do projeto pela tela oficial reativa conectada ao Cloud Firestore
// (lib/paciente.dart).
//
// ONDE É USADO (REFERÊNCIAS NO REPOSITÓRIO):
// - test/widget_test.dart: importado e testado no teste padrão de renderização de widgets.
//
// DE ONDE RECEBE DADOS:
// - Variáveis locais estáticas e constantes definidas diretamente no método build.
//
// O QUE EXPORTA / EXPÕE:
// - class Paciente extends StatelessWidget: Widget da tela legada de paciente.
//
// ORIGEM HISTÓRICA:
// Criado no início do projeto nos commits prototípicos da equipe (commit 22b8657)
// e arquivado para a pasta Outdated no commit 588756d.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// - package:flutter/material.dart: componentes de UI.
// - Efeitos colaterais: chamadas a showDialog e saídas de log no console via debugPrint.
//
// INCONSISTÊNCIAS / OBSERVAÇÕES TÉCNICAS:
// - Construído sem Scaffold e sem conexão com banco de dados em tempo real.
// ============================================================================
// Importa a biblioteca de componentes visuais Material Design do Flutter
import 'package:flutter/material.dart';

// tela do paciente sem Scaffold e usando Material
// Declaração do StatelessWidget legado representando o painel do paciente
class Paciente extends StatelessWidget {
  // Construtor constante com chave opcional
  Paciente({super.key});

  // Sobrescrita do método de construção da árvore de widgets
  @override
  // Constrói a interface gráfica da tela legada do paciente
  Widget build(BuildContext context) {
    // Título estático do transporte agendado
    final String titulo = "Seu Transporte da Tarde";
    // Status textual simulado
    final String status = "EM TRÂNSITO";
    // Nome do motorista atribuído fictício
    final String motoristaNome = "Carlos Roberto";
    // Informações fictícias do veículo
    final String veiculoInfo = "Spin Prata • Placa: ABC-1D23";

    // Retorna elemento Material raiz com fundo branco
    return Material(
      // Fundo branco
      color: Colors.white,
      // Área segura para proteger contra entalhes de tela
      child: SafeArea(
        // Espaçamento uniforme de 16 pixels
        child: Padding(
          // Recuo em todas as direções
          padding: EdgeInsets.all(16.0),
          // Coluna vertical com os elementos visuais
          child: Column(
            // Alinha à esquerda
            crossAxisAlignment: CrossAxisAlignment.start,
            // Lista de filhos da tela
            children: <Widget>[
              // botão voltar já que não tem AppBar do Scaffold
              // Linha personalizada de retorno simulando uma barra superior
              Row(
                // Filhos da linha
                children: [
                  // Botão com ícone para retroceder
                  IconButton(
                    // Ícone com seta preta para a esquerda
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                    // Ação de retorno ao tocar
                    onPressed: () {
                      // Desempilha a tela atual
                      Navigator.pop(context);
                    // Fechamento do callback onPressed
                    },
                  // Fechamento do IconButton
                  ),
                  // Título curto na barra de retorno
                  Text(
                    // Texto do título
                    'Painel',
                    // Estilo em negrito
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  // Fechamento do Text
                  ),
                // Fechamento dos filhos da Row
                ],
              // Fechamento da Row
              ),
              // Espaçador vertical
              SizedBox(height: 10),
              // Título principal da página
              Text(
                // Texto principal
                'Painel Paciente',
                // Estilo tipográfico de destaque
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              // Fechamento do Text
              ),
              // Subtítulo descritivo
              Text(
                // Texto descritivo
                'Status do seu transporte de saúde',
                // Cor cinza suave
                style: TextStyle(color: Colors.grey),
              // Fechamento do Text
              ),
              // Espaçador vertical
              SizedBox(height: 20),
              // Contêiner Material para o card informativo do transporte
              Material(
                // Fundo branco
                color: Colors.white,
                // Elevação de sombra de 2 pixels
                elevation: 2,
                // Cantos arredondados de 8 pixels
                borderRadius: BorderRadius.circular(8),
                // Espaçamento interno do card
                child: Padding(
                  // Recuo uniforme de 16 pixels
                  padding: EdgeInsets.all(16),
                  // Coluna com os dados do transporte
                  child: Column(
                    // Alinha os dados à esquerda
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Filhos do card
                    children: [
                      // Título do transporte
                      Text(
                        // Texto do título
                        titulo,
                        // Estilo tipográfico em negrito
                        style: TextStyle(
                          // Peso em negrito
                          fontWeight: FontWeight.bold,
                          // Tamanho de 16 pixels
                          fontSize: 16,
                        // Fechamento do TextStyle
                        ),
                      // Fechamento do Text
                      ),
                      // Espaçador vertical sutil
                      SizedBox(height: 4),
                      // Tag visual do status em trânsito
                      Material(
                        // Fundo cinza suave
                        color: Colors.grey.shade200,
                        // Cantos arredondados de 12 pixels
                        borderRadius: BorderRadius.circular(12),
                        // Espaçamento interno da tag
                        child: Padding(
                          // Recuo horizontal e vertical compacto
                          padding: EdgeInsets.symmetric(
                            // Recuo horizontal de 10 pixels
                            horizontal: 10,
                            // Recuo vertical de 4 pixels
                            vertical: 4,
                          // Fechamento do EdgeInsets
                          ),
                          // Texto do status com cor azul
                          child: Text(
                            // Texto do status
                            status,
                            // Estilo com texto azul e negrito
                            style: TextStyle(
                              // Cor azul destacada
                              color: Colors.blue,
                              // Peso em negrito
                              fontWeight: FontWeight.bold,
                              // Tamanho de 12 pixels
                              fontSize: 12,
                            // Fechamento do TextStyle
                            ),
                          // Fechamento do Text
                          ),
                        // Fechamento do Padding
                        ),
                      // Fechamento do Material
                      ),
                      // Espaçador vertical
                      SizedBox(height: 16),
                      // Linha com informações do motorista e veículo
                      Row(
                        // Filhos da linha
                        children: [
                          // Espaçador horizontal
                          SizedBox(width: 12),
                          // Coluna com os textos do motorista
                          Column(
                            // Alinha à esquerda
                            crossAxisAlignment: CrossAxisAlignment.start,
                            // Textos de identificação
                            children: [
                              // Nome do motorista
                              Text(
                                // Interpolação com o nome
                                'Motorista: $motoristaNome',
                                // Estilo em negrito
                                style: TextStyle(fontWeight: FontWeight.bold),
                              // Fechamento do Text
                              ),
                              // Detalhes do veículo e placa
                              Text(
                                // Informações do automóvel
                                veiculoInfo,
                                // Estilo em cinza suave
                                style: TextStyle(
                                  // Cor cinza intermediária
                                  color: Colors.grey.shade600,
                                  // Tamanho de 12 pixels
                                  fontSize: 12,
                                // Fechamento do TextStyle
                                ),
                              // Fechamento do Text
                              ),
                            // Fechamento dos filhos da Column
                            ],
                          // Fechamento da Column
                          ),
                        // Fechamento dos filhos da Row
                        ],
                      // Fechamento da Row
                      ),
                    // Fechamento dos filhos da Column do card
                    ],
                  // Fechamento da Column
                  ),
                // Fechamento do Padding
                ),
              // Fechamento do Material
              ),
              // Espaçador elástico que empurra os botões para a parte inferior
              Spacer(),
              // Centraliza os botões de ação na horizontal
              Center(
                // Linha de botões de ação
                child: Row(
                  // Ocupa o tamanho mínimo horizontal
                  mainAxisSize: MainAxisSize.min,
                  // Alinha os botões ao centro
                  crossAxisAlignment: CrossAxisAlignment.center,
                  // Filhos da linha de ação
                  children: [
                    // Botão para registrar desistência / carona
                    ElevatedButton(
                      // Texto do botão
                      child: Text('Já consegui Carona'),
                      // Ação ao pressionar o botão de carona
                      onPressed: () {
                        // Exibe diálogo modal de confirmação
                        _mostrarDialog(
                          // Contexto
                          context: context,
                          // Título do diálogo
                          titulo: "Confirmação de Carona",
                          // Mensagem confirmatória
                          mensagem: "Você confirma que já conseguiu carona?",
                          // Callback de confirmação
                          onConfirmar: () {
                            // Imprime log no console de debug
                            debugPrint("O motorista será avisado");
                          // Fechamento do callback onConfirmar
                          },
                          // Callback de cancelamento
                          onCancelar: () {
                            // Imprime log de cancelamento no console
                            debugPrint("Ação cancelada pelo usuário");
                          // Fechamento do callback onCancelar
                          },
                        // Fechamento da chamada _mostrarDialog
                        );
                      // Fechamento do onPressed
                      },
                    // Fechamento do ElevatedButton
                    ),
                    // Espaçamento horizontal entre os botões
                    SizedBox(width: 12),
                    // Botão para sinalizar prontidão para viagem
                    ElevatedButton(
                      // Texto do botão
                      child: Text("Estou pronto"),
                      // Ação ao pressionar o botão Estou Pronto
                      onPressed: () {
                        // Exibe diálogo modal de confirmação
                        _mostrarDialog(
                          // Contexto
                          context: context,
                          // Título do diálogo
                          titulo: "Confirmação de partida",
                          // Mensagem confirmatória
                          mensagem: "Tem certeza de que está pronto? O motorista será notificado da sua prontidão.",
                          // Callback de confirmação
                          onConfirmar: () {
                            // Variável de nome de paciente simulado
                            final nomePaciente = "pacienteX";
                            // Imprime no console de debug
                            debugPrint(
                              "Confirmação enviada! O motorista foi alertado de que $nomePaciente está pronto.",
                            // Fechamento da string
                            );
                          // Fechamento do callback onConfirmar
                          },
                          // Callback de cancelamento
                          onCancelar: () {
                            // Imprime log de cancelamento no console
                            debugPrint("O paciente cancelou a ação.");
                          // Fechamento do callback onCancelar
                          },
                        // Fechamento da chamada _mostrarDialog
                        );
                      // Fechamento do onPressed
                      },
                    // Fechamento do ElevatedButton
                    ),
                  // Fechamento dos filhos da Row
                  ],
                // Fechamento da Row
                ),
              // Fechamento do Center
              ),
              // Espaçador vertical inferior
              SizedBox(height: 20),
            // Fechamento dos filhos da Column
            ],
          // Fechamento da Column
          ),
        // Fechamento do Padding
        ),
      // Fechamento do SafeArea
      ),
    // Fechamento do Material
    );
  // Fechamento do método build
  }

  // Método auxiliar para exibição de diálogos de confirmação com opções Sim e Não
  void _mostrarDialog({
    // Contexto de montagem obrigatório
    required BuildContext context,
    // Título textual obrigatório do diálogo
    required String titulo,
    // Mensagem descritiva obrigatória
    required String mensagem,
    // Callback executado ao confirmar com Sim
    required VoidCallback onConfirmar,
    // Callback opcional executado ao cancelar com Não
    VoidCallback? onCancelar,
  // Fechamento dos parâmetros
  }) {
    // Abre a caixa de diálogo modal
    showDialog(
      // Contexto da tela
      context: context,
      // Construtor do widget do diálogo
      builder: (BuildContext context) {
        // Retorna o AlertDialog configurado
        return AlertDialog(
          // Título do diálogo
          title: Text(titulo),
          // Conteúdo textual do diálogo
          content: Text(mensagem),
          // Botões de resposta
          actions: <Widget>[
            // Botão afirmativo
            TextButton(
              // Rótulo Sim
              child: Text('Sim'),
              // Ação ao clicar em Sim
              onPressed: () {
                // Fecha o diálogo modal
                Navigator.of(context).pop();
                // Invoca a ação de confirmação
                onConfirmar();
              // Fechamento do onPressed
              },
            // Fechamento do TextButton
            ),
            // Botão negativo
            TextButton(
              // Rótulo Não
              child: Text('Não'),
              // Ação ao clicar em Não
              onPressed: () {
                // Fecha o diálogo modal
                Navigator.of(context).pop();
                // Invoca o cancelamento caso fornecido
                if (onCancelar != null) onCancelar();
              // Fechamento do onPressed
              },
            // Fechamento do TextButton
            ),
          // Fechamento da lista actions
          ],
        // Fechamento do AlertDialog
        );
      // Fechamento do builder
      },
    // Fechamento do showDialog
    );
  // Fechamento do método _mostrarDialog
  }
// Fechamento da classe Paciente
}
