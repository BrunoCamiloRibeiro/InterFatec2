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

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a classe MotoristaHeader
// Comentários originais do autor mantidos byte a byte:
/// Componente visual do cabeçalho da tela do motorista (Issue #13).
///
/// Exibe um seletor horizontal em card com navegação entre viagens (setas anterior/próxima)
/// e o rótulo da viagem centralizado. Permite opcionalmente exibir uma linha secundária
/// compacta com detalhes da viagem caso sejam informados.
// Declaração do widget StatelessWidget MotoristaHeader
class MotoristaHeader extends StatelessWidget {
  // Comentário original do autor mantido byte a byte:
  /// Rótulo ou título da viagem atual já formatado (ex: "Viagem #1", "Viagem 001").
  // Título da viagem em exibição
  final String tituloViagem;

  // Linha em branco separadora entre atributos
  // Comentários originais do autor mantidos byte a byte:
  /// Callback acionado ao tocar na seta de viagem anterior.
  /// Se nulo, a seta permanece visualmente desabilitada.
  // Callback opcional de navegação para a viagem anterior
  final VoidCallback? onAnterior;

  // Linha em branco separadora entre atributos
  // Comentários originais do autor mantidos byte a byte:
  /// Callback acionado ao tocar na seta de próxima viagem.
  /// Se nulo, a seta permanece visualmente desabilitada.
  // Callback opcional de navegação para a próxima viagem
  final VoidCallback? onProxima;

  // Linha em branco separadora entre atributos
  // Comentário original do autor mantido byte a byte:
  // Campos opcionais descritos na Issue #13:
  // Nome do motorista condutor da viagem
  final String? motoristaNome;
  // Cidade de destino da viagem
  final String? destino;
  // Modelo e placa do veículo utilizado
  final String? veiculo;
  // Horário previsto de saída
  final String? saida;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados
  const MotoristaHeader({
    // Chave opcional do widget
    super.key,
    // Parâmetro obrigatório para o título da viagem
    required this.tituloViagem,
    // Callback opcional para viagem anterior
    this.onAnterior,
    // Callback opcional para próxima viagem
    this.onProxima,
    // Dados secundários opcionais
    this.motoristaNome,
    this.destino,
    this.veiculo,
    this.saida,
  // Fecha a lista de parâmetros do construtor
  });

  // Linha em branco separadora entre construtor e getter auxiliar
  // Comentário original do autor mantido byte a byte:
  /// Verifica se ao menos um dos campos secundários opcionais foi fornecido e não está vazio.
  // Getter computado para verificar presença de dados complementares
  bool get _possuiDadosSecundarios {
    // Avalia se algum dos 4 campos secundários possui texto não vazio
    return (motoristaNome?.trim().isNotEmpty == true) ||
        (destino?.trim().isNotEmpty == true) ||
        (veiculo?.trim().isNotEmpty == true) ||
        (saida?.trim().isNotEmpty == true);
  }

  // Linha em branco separadora entre getter e build

  // Sobrescrita do método build para montagem visual do cabeçalho
  @override
  // Constrói a estrutura visual do MotoristaHeader
  Widget build(BuildContext context) {
    // Determina se o botão anterior está ativo
    final bool anteriorHabilitado = onAnterior != null;
    // Determina se o botão próximo está ativo
    final bool proximaHabilitado = onProxima != null;

    // Linha em branco separadora entre flags e retorno do Container
    // Retorna Container com borda arredondada e fundo branco
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      // Coluna contendo a linha principal de navegação e a linha secundária
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Linha horizontal com seta anterior, título e seta próxima
          Row(
            children: [
              // Botão de navegação anterior com restrição mínima de acessibilidade de 48dp
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: anteriorHabilitado
                      ? Colors.blueGrey[900]
                      : Colors.grey[400],
                ),
                tooltip: 'Viagem anterior',
                onPressed: onAnterior,
              ),
              // Título centralizado ocupando o espaço restante
              Expanded(
                child: Text(
                  tituloViagem,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
              ),
              // Botão de próxima navegação com restrição mínima de acessibilidade de 48dp
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: proximaHabilitado
                      ? Colors.blueGrey[900]
                      : Colors.grey[400],
                ),
                tooltip: 'Próxima viagem',
                onPressed: onProxima,
              ),
            ],
          ),
          // Comentário original do autor mantido byte a byte:
          // Linha secundária compacta renderizada SOMENTE se algum campo opcional for informado
          // Renderiza condicionalmente se houver informações secundárias
          if (_possuiDadosSecundarios) ...[
            const Divider(height: 4, thickness: 0.8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Item de motorista
                  if (motoristaNome?.trim().isNotEmpty == true)
                    _ItemDadoSecundario(
                      icone: Icons.person_outline,
                      valor: motoristaNome!.trim(),
                    ),
                  // Item de destino
                  if (destino?.trim().isNotEmpty == true)
                    _ItemDadoSecundario(
                      icone: Icons.location_on_outlined,
                      valor: destino!.trim(),
                    ),
                  // Item de veículo
                  if (veiculo?.trim().isNotEmpty == true)
                    _ItemDadoSecundario(
                      icone: Icons.directions_bus_outlined,
                      valor: veiculo!.trim(),
                    ),
                  // Item de horário de saída
                  if (saida?.trim().isNotEmpty == true)
                    _ItemDadoSecundario(
                      icone: Icons.access_time_outlined,
                      valor: saida!.trim(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Linha em branco separadora entre MotoristaHeader e _ItemDadoSecundario
// Comentário original do autor mantido byte a byte:
/// Item visual compacto para informações secundárias com ícone e texto
// Widget StatelessWidget privado que compõe cada pílula de detalhe secundário
class _ItemDadoSecundario extends StatelessWidget {
  // Ícone característico do campo
  final IconData icone;
  // Valor textual do campo
  final String valor;

  // Linha em branco separadora entre atributos e construtor

  // Construtor constante com parâmetros nomeados obrigatórios
  const _ItemDadoSecundario({required this.icone, required this.valor});

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para renderização do item secundário
  @override
  // Constrói a linha horizontal compacta com ícone e texto
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ícone reduzido de 14 pontos
        Icon(icone, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        // Texto compacto com elipse se exceder
        Flexible(
          child: Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
