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

// Importa o framework Material Design do Flutter
import 'package:flutter/material.dart';

// Linha em branco separadora entre imports e a classe do componente
// Comentários originais do autor mantidos byte a byte:
// Componente visual com espaço reservado para o futuro mapa de rastreamento do veículo (Issue #18)
// TODO: Integrar mapa interativo com geolocalização e rota em tempo real
// Declaração do widget StatelessWidget CardTrackingPaciente
class CardTrackingPaciente extends StatelessWidget {
  // Construtor constante com chave de identificação do widget
  const CardTrackingPaciente({super.key});

  // Linha em branco separadora entre construtor e build

  // Sobrescrita do método build para montagem do layout do placeholder de mapa
  @override
  // Constrói a estrutura visual do card de rastreamento
  Widget build(BuildContext context) {
    // Retorna Container com altura fixa e bordas arredondadas
    return Container(
      // Altura fixa de 200 pontos
      height: 200,
      // Largura total expandida
      width: double.infinity,
      // Decoração com fundo slate claro e contorno suave
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      // Centraliza os elementos internos
      child: Center(
        // Coluna organizando ícone, textos informativos e etiqueta
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Comentário original do autor mantido byte a byte:
            // Ícone centralizado do mapa
            // Container circular branco com sombra suave contendo o ícone de mapa
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // Ícone de mapa em tom azul
              child: const Icon(
                Icons.map_outlined,
                size: 29,
                color: Color(0xFF2563EB),
              ),
            ),
            // Espaçamento vertical de 12 pontos
            const SizedBox(height: 12),
            // Título descritivo da funcionalidade
            const Text(
              'Rastreamento em Tempo Real',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            // Espaçamento vertical de 4 pontos
            const SizedBox(height: 4),
            // Subtítulo informativo
            const Text(
              'A localização do veículo aparecerá aqui',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            // Espaçamento vertical de 10 pontos
            const SizedBox(height: 10),
            // Container com badge indicativa de espaço reservado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '📍 Espaço Reservado (Tracking em Breve)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
