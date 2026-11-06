// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO
// ============================================================================
// Arquivo: lib/components/card_tracking_paciente.dart
// Camada: Apresentação / Componentes Visuais (Components)
//
// O QUE ESTE ARQUIVO FAZ:
// Renderiza o container visual com layout de espaço reservado (placeholder)
// para a futura funcionalidade de mapa interativo e rastreamento em tempo real
// do veículo municipal do TFD (Tratamento Fora de Domicílio).
//
// PARA QUE SERVE NO PROJETO:
// Reserva e padroniza a área visual destinada ao mapa no painel do paciente
// (lib/paciente.dart), informando amigavelmente ao usuário onde aparecerá a
// localização do veículo durante a viagem.
//
// ONDE É USADO NO PROJETO:
// - lib/paciente.dart (seção inferior do painel do paciente)
//
// DE ONDE RECEBE DADOS:
// Componente de interface estático e desacoplado: não consome dados dinâmicos.
//
// O QUE EXPORTA / EXPÕE:
// - class CardTrackingPaciente extends StatelessWidget
//
// ORIGEM HISTÓRICA:
// Criado no commit 12eeb6a pela equipe do projeto na issue #18 (rastreamento do paciente).
// Não provém de scaffold ou template gerado automaticamente.
//
// DEPENDÊNCIAS EXTERNAS E EFEITOS COLATERAIS:
// Depende exclusivamente de 'package:flutter/material.dart'.
// Componente puramente visual em memória: sem efeitos colaterais de I/O ou rede.
// ============================================================================

// Importa a biblioteca central Material Design do Flutter com widgets de interface gráfica
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a classe do componente
// Comentários originais do autor mantidos byte a byte:
// Componente visual com espaço reservado para o futuro mapa de rastreamento do veículo (Issue #18)
// TODO: Integrar mapa interativo com geolocalização e rota em tempo real
// Declaração do widget StatelessWidget CardTrackingPaciente
// Elemento: Classe StatelessWidget imutável do Flutter que atua como placeholder visual para rastreamento
class CardTrackingPaciente extends StatelessWidget {
  // Construtor constante da classe CardTrackingPaciente
  // Recebe parâmetro opcional super.key para identificação única do elemento na árvore de widgets
  const CardTrackingPaciente({super.key});

  // Linha em branco separadora entre construtor e build

  // Anotação indicando sobrescrita do método build de StatelessWidget
  @override
  // Método build: reconstrói a árvore de widgets correspondente ao placeholder do mapa
  // Recebe: context (BuildContext com o contexto de renderização)
  // Retorna: Widget (instância de Container configurado com bordas arredondadas e mensagens informativas)
  Widget build(BuildContext context) {
    // Widget Container: caixa de layout decorada simulando o painel de mapa com altura definida
    // Elemento: Classe Container de 'package:flutter/widgets.dart'
    return Container(
      // Propriedade height: altura fixa de 200 pixels lógicos para o espaço do mapa
      height: 200,
      // Propriedade width: largura total preenchendo 100% da dimensão horizontal disponível (double.infinity)
      width: double.infinity,
      // Propriedade decoration: estilo visual com fundo cinza-azulado e borda sutil
      decoration: BoxDecoration(
        // Cor de fundo ardósia muito clara (0xFFF1F5F9, Slate 100)
        color: const Color(0xFFF1F5F9),
        // Cantos arredondados com raio geométrico de 16 pixels
        borderRadius: BorderRadius.circular(16),
        // Borda perimetral sólida com espessura de 1.5 pixels e cor Slate 300 (0xFFCBD5E1)
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      // Fecha a instanciação de BoxDecoration
      ),
      // Propriedade child de Container: widget Center para alinhamento centralizado do conteúdo interno
      // Widget Center: alinha seu filho exatamente no centro geométrico da caixa
      child: Center(
        // Propriedade child de Center: widget Column empilhando verticalmente o ícone e os textos
        // Widget Column: organiza os filhos em sequência vertical
        child: Column(
          // Propriedade mainAxisAlignment: centraliza os filhos ao longo do eixo vertical principal
          mainAxisAlignment: MainAxisAlignment.center,
          // Propriedade children da Column: lista com container do ícone, títulos e badge de aviso
          children: [
            // Comentário original do autor mantido byte a byte:
            // Ícone centralizado do mapa
            // Widget Container: caixa circular branca com sombra sutil contendo o ícone de mapa
            Container(
              // Largura fixa de 55 pixels lógicos
              width: 55,
              // Altura fixa de 55 pixels lógicos
              height: 55,
              // Propriedade decoration: círculo branco com sombra projetada suave
              decoration: BoxDecoration(
                // Cor de fundo branca pura
                color: Colors.white,
                // Formato geométrico circular (BoxShape.circle)
                shape: BoxShape.circle,
                // Lista de sombras decorativas projetadas pelo círculo
                boxShadow: [
                  // Instância de BoxShadow aplicando sombra difusa
                  BoxShadow(
                    // Cor preta com 6% de opacidade para sombra bem leve
                    color: Colors.black.withValues(alpha: 0.06),
                    // Raio de desfoque de 8 pixels lógicos
                    blurRadius: 8,
                    // Deslocamento vertical de 2 pixels lógicos
                    offset: const Offset(0, 2),
                  // Fecha a BoxShadow
                  ),
                // Fecha a lista boxShadow
                ],
              // Fecha a instanciação de BoxDecoration
              ),
              // Propriedade child de Container: ícone de mapa centralizado
              // Widget Icon: glifo map_outlined em tom azul vibrante
              child: const Icon(
                // Identificador do ícone map_outlined
                Icons.map_outlined,
                // Dimensão do ícone de 29 pixels lógicos
                size: 29,
                // Cor azul vibrante (0xFF2563EB, Blue 600)
                color: Color(0xFF2563EB),
              // Fecha a instanciação de Icon
              ),
            // Fecha o Container circular do ícone
            ),
            // Widget SizedBox: espaçamento vertical constante de 12 pixels lógicos
            const SizedBox(height: 12),
            // Widget Text: título descritivo da funcionalidade
            const Text(
              // Texto principal do placeholder
              'Rastreamento em Tempo Real',
              // Propriedade style: formatação tipográfica do título
              style: TextStyle(
                // Tamanho da fonte de 15.5 pixels lógicos
                fontSize: 15.5,
                // Peso negrito para destaque visual
                fontWeight: FontWeight.bold,
                // Cor ardósia muito escura (0xFF0F172A, Slate 900)
                color: Color(0xFF0F172A),
              // Fecha a TextStyle do título
              ),
            // Fecha o widget Text do título
            ),
            // Widget SizedBox: espaçamento vertical constante de 4 pixels lógicos
            const SizedBox(height: 4),
            // Widget Text: mensagem secundária orientando o usuário
            const Text(
              // Texto explicativo sobre onde aparecerá a localização
              'A localização do veículo aparecerá aqui',
              // Propriedade style: formatação tipográfica suave em cinza
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            // Fecha o widget Text secundário
            ),
            // Widget SizedBox: espaçamento vertical constante de 10 pixels lógicos
            const SizedBox(height: 10),
            // Widget Container: badge indicando status de espaço reservado
            Container(
              // Propriedade padding: preenchimento interno de 12 pixels na horizontal e 5 na vertical
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              // Propriedade decoration: fundo cinza suave com cantos arredondados
              decoration: BoxDecoration(
                // Cor cinza claro (0xFFE2E8F0, Slate 200)
                color: const Color(0xFFE2E8F0),
                // Cantos arredondados com raio geométrico de 8 pixels
                borderRadius: BorderRadius.circular(8),
              // Fecha a instanciação de BoxDecoration
              ),
              // Propriedade child de Container: texto do badge com emoji de alfinete
              child: const Text(
                // Mensagem do badge
                '📍 Espaço Reservado (Tracking em Breve)',
                // Propriedade style: tipografia compacta em negrito
                style: TextStyle(
                  // Tamanho da fonte reduzido de 11 pixels lógicos
                  fontSize: 11,
                  // Peso negrito para destaque
                  fontWeight: FontWeight.bold,
                  // Cor ardósia escura (0xFF475569, Slate 600)
                  color: Color(0xFF475569),
                // Fecha a TextStyle do badge
                ),
              // Fecha o widget Text do badge
              ),
            // Fecha o Container do badge
            ),
          // Fecha a lista children da Column do placeholder
          ],
        // Fecha a Column do placeholder
        ),
      // Fecha o widget Center
      ),
    // Fecha o widget Container do placeholder
    );
  // Fecha o método build
  }
// Fecha a classe CardTrackingPaciente
}
