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

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre framework e modelos internos
// Importa o modelo PacienteModel para repasse ao formulário de encerramento
import '../models/paciente_model.dart';
// Importa o modelo ViagemModel para repasse dos dados da viagem ativa
import '../models/viagem_model.dart';
// Importa o formulário de encerramento exibido no diálogo modal
import 'formulario_encerramento.dart';

// Linha em branco separadora entre imports e a declaração de FooterPacientes
// Comentários originais do autor mantidos byte a byte:
// Componente visual do Footer (rodapé) da lista de pacientes do motorista.
// Estrutura compacta em linha única: ocupação de lugares na esquerda e botão que abre o Popup de encerramento na direita.
// Declaração do widget StatelessWidget FooterPacientes
class FooterPacientes extends StatelessWidget {
  // Comentário original do autor mantido byte a byte:
  // Quantidade de lugares ocupados atualmente no veículo
  // Inteiro com o total de passageiros e acompanhantes embarcados
  final int lugaresPreenchidos;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Capacidade total de lugares do veículo
  // Inteiro com a lotação máxima suportada pelo automóvel
  final int lugaresTotais;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Dados da viagem ativa e pacientes para geração do PDF de encerramento
  // Instância da viagem em andamento
  final ViagemModel? viagem;
  // Lista de pacientes vinculados ao transporte
  final List<PacienteModel>? pacientes;

  // Linha em branco separadora entre atributos e construtor
  // Comentário original do autor mantido byte a byte:
  // Construtor recebendo os números de lugares preenchidos e totais
  // Construtor constante inicializando os dados do rodapé
  const FooterPacientes({
    // Chave opcional do widget
    super.key,
    // Parâmetro obrigatório para assentos ocupados
    required this.lugaresPreenchidos,
    // Parâmetro obrigatório para total de assentos
    required this.lugaresTotais,
    // Parâmetro opcional para a viagem ativa
    this.viagem,
    // Parâmetro opcional para a lista de pacientes
    this.pacientes,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para montagem visual do footer
  @override
  // Constrói a estrutura visual da barra de rodapé
  Widget build(BuildContext context) {
    // Comentário original do autor mantido byte a byte:
    // Container compacto do rodapé com fundo branco e linha divisória no topo
    // Retorna Container com preenchimento horizontal e vertical
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          // Comentário original do autor mantido byte a byte:
          // Borda superior sutil para separar o Footer da lista de pacientes
          // Linha divisória superior sutil em tom cinza claro
          top: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
      ),
      // Comentário original do autor mantido byte a byte:
      // Linha única horizontal dividindo esquerda (lugares) e direita (botão)
      // Row horizontal distribuindo os elementos entre as extremidades
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Comentário original do autor mantido byte a byte:
          // ESQUERDA: Informação do número de passageiros/assentos (preenchidos / total)
          // Linha com ícone de assento e texto de lotação
          Row(
            children: [
              Icon(
                Icons.event_seat_outlined,
                size: 20,
                color: Colors.blueGrey[900],
              ),
              const SizedBox(width: 8),
              Text(
                'Lugares: $lugaresPreenchidos / $lugaresTotais',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
              ),
            ],
          ),

          // Linha em branco separadora entre esquerda e direita
          // Comentário original do autor mantido byte a byte:
          // DIREITA: Botão compacto que abre o POPUP do Formulário de Encerramento
          // Botão elevado estilizado com ícone de prancheta
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[900],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.assignment_outlined, size: 18),
            label: const Text(
              'Gerar Relatório',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              // Comentário original do autor mantido byte a byte:
              // Abre o POPUP do Formulário de Encerramento (Retorno, Km Retorno, Km Rodado e Emissão PDF)
              // Dispara o diálogo modal contendo o formulário de encerramento
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return FormularioEncerramento(
                    viagem: viagem,
                    pacientes: pacientes,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
