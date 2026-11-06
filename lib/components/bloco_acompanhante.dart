// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/bloco_acompanhante.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o componente visual CardAcompanhante, um container estilizado com
// bordas suaves e fundo slate para exibição dos dados de identificação e
// contato do acompanhante de um paciente (nome completo e telefone com ícones
// representativos e tratamento para campos opcionais).
//
// PARA QUE SERVE NO PROJETO:
// Destaca visualmente a presença de um acompanhante no card do passageiro na
// tela do motorista, permitindo que o condutor identifique imediatamente quem
// acompanha o paciente e possua acesso rápido ao telefone de contato.
//
// ONDE É USADO NO PROJETO:
// - lib/components/card_paciente.dart (exibido na seção inferior do card quando há acompanhante)
//
// DE ONDE RECEBE DADOS:
// Parâmetros obrigatórios nomeAcompanhante e telAcompanhante repassados pelo widget pai.
//
// O QUE EXPORTA / EXPÕE:
// - class CardAcompanhante extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit ea418fa pela equipe do projeto na tarefa de exibir variação
// do card de paciente com acompanhante. Não provém de template automático.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente do pacote Material Design do Flutter (package:flutter/material.dart).
// Componente puramente declarativo e imutável: sem efeitos colaterais, sem I/O e sem rede.
// ============================================================================

// Importa o pacote de componentes e design Material do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a classe do componente
// Declaração do widget StatelessWidget CardAcompanhante
class CardAcompanhante extends StatelessWidget {
  // Nome completo do acompanhante do paciente
  final String nomeAcompanhante;
  // Número de telefone para contato com o acompanhante
  final String telAcompanhante;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados obrigatórios
  const CardAcompanhante({
    // Chave de identificação opcional do widget
    super.key,
    // Parâmetro obrigatório para o nome do acompanhante
    required this.nomeAcompanhante,
    // Parâmetro obrigatório para o telefone do acompanhante
    required this.telAcompanhante,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para montagem do layout do card
  @override
  // Constrói a estrutura visual do bloco de acompanhante
  Widget build(BuildContext context) {
    // Retorna container com margem superior, padding interno e borda arredondada
    return Container(
      // Margem superior de 12 pontos para separar dos dados da consulta
      margin: const EdgeInsets.only(top: 12),
      // Espaçamento interno de 10 pontos
      padding: const EdgeInsets.all(10),
      // Decoração visual com fundo cinza-azulado suave e contorno
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Slate 50
        // Arredondamento dos cantos com raio de 12 pontos
        borderRadius: BorderRadius.circular(12),
        // Contorno fino com cor suave
        border: Border.all(
          color: const Color(0xFFE2E8F0), // Slate 200
          width: 1.0,
        ),
      ),
      // Coluna vertical contendo cabeçalho, nome e telefone
      child: Column(
        // Alinha os filhos à esquerda
        crossAxisAlignment: CrossAxisAlignment.start,
        // Filhos da coluna
        children: [
          // Comentário original do autor mantido byte a byte:
          // Título com ícone lado a lado
          // Linha horizontal exibindo o ícone de grupo e rótulo 'ACOMPANHANTE'
          const Row(
            children: [
              // Ícone representativo de adição de grupo/acompanhante
              Icon(
                Icons.group_add_outlined,
                size: 17,
                color: Colors.blueAccent,
              ),
              // Espaçamento horizontal de 6 pontos
              SizedBox(width: 6),
              // Texto do rótulo da seção
              Text(
                'ACOMPANHANTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          // Espaçamento vertical de 6 pontos
          const SizedBox(height: 6),

          // Comentário original do autor mantido byte a byte:
          // Nome do acompanhante
          // Linha com ícone de pessoa e o nome do acompanhante
          Row(
            children: [
              // Ícone de usuário
              const Icon(Icons.person_outline, size: 20, color: Colors.black54),
              // Espaçamento horizontal de 6 pontos
              const SizedBox(width: 6),
              // Texto expandido do nome para evitar estouro de linha
              Expanded(
                child: Text(
                  nomeAcompanhante,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Comentário original do autor mantido byte a byte:
          // Telefone do acompanhante (renderizado apenas se existir)
          // Renderiza a linha de telefone apenas se a string não for vazia
          if (telAcompanhante.trim().isNotEmpty) ...[
            // Espaçamento vertical de 4 pontos
            const SizedBox(height: 4),
            // Linha com ícone de telefone e o número formatado
            Row(
              children: [
                // Ícone de telefone
                const Icon(Icons.phone_outlined, size: 18, color: Colors.black54),
                // Espaçamento horizontal de 6 pontos
                const SizedBox(width: 6),
                // Texto do telefone com expansão horizontal
                Expanded(
                  child: Text(
                    telAcompanhante,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
