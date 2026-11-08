// ============================================================================
// TESTE DE MIGRAÇÃO DE DADOS: VIAGENS LEGADAS -> SESSÃO DE VEÍCULO
// ----------------------------------------------------------------------------
// Repositório: BrunoCamiloRibeiro/InterFatec2
// Contexto: Issue #65 - Migração com garantia de ausência de registros órfãos
//           e plano de reversão (rollback) testado.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  group('Migração de Dados: Viagens Legadas para Sessão de Veículo (Issue #65)', () {
    late ViagemService viagemService;

    final veiculoTeste = VeiculoModel(
      id: 'veic_spin_01',
      modelo: 'Chevrolet Spin',
      placa: 'BRA-2E19',
      quilometragemAtual: 50000,
      capacidade: 7,
    );

    // Três viagens legadas existentes antes da introdução da Sessão de Veículo (sessaoId == null)
    final viagemLegada1 = ViagemModel(
      id: 'viagem_legada_01',
      motoristaId: 'mot_carlos',
      motoristaNome: 'Carlos Motorista',
      veiculoId: 'veic_spin_01',
      veiculoPlaca: 'BRA-2E19',
      veiculoModelo: 'Chevrolet Spin',
      kmInicial: 50000,
      cidadeDestino: 'São José do Rio Preto',
      dataHoraInicio: DateTime.now().subtract(const Duration(hours: 3)),
      status: 'ativa',
      sessaoId: null, // Legado: sem vínculo de sessão
    );

    final viagemLegada2 = ViagemModel(
      id: 'viagem_legada_02',
      motoristaId: 'mot_carlos',
      motoristaNome: 'Carlos Motorista',
      veiculoId: 'veic_spin_01',
      veiculoPlaca: 'BRA-2E19',
      veiculoModelo: 'Chevrolet Spin',
      kmInicial: 50050,
      cidadeDestino: 'Mirassol',
      dataHoraInicio: DateTime.now().subtract(const Duration(hours: 1)),
      status: 'ativa',
      sessaoId: null, // Legado: sem vínculo de sessão
    );

    setUp(() {
      viagemService = ViagemService();
      viagemService.resetParaTestes(
        veiculosIniciais: [veiculoTeste],
        sessaoAtivaInicial: null,
        viagensAtivasIniciais: [viagemLegada1, viagemLegada2],
      );
    });

    test('1. Consulta pré-migração identifica registros legados sem sessaoId', () {
      final totalAntes = viagemService.viagensAtivas.length;
      final legadasAntes = viagemService.viagensAtivas.where((v) => v.sessaoId == null).length;

      expect(totalAntes, equals(2));
      expect(legadasAntes, equals(2));
      expect(viagemService.sessaoAtiva, isNull);
    });

    test('2. Execução da migração vincula todas as viagens ativas a uma sessão de veículo', () async {
      final relatorioMigracao = await viagemService.migrarViagensLegadasParaSessao();

      expect(relatorioMigracao['sucesso'], isTrue);
      expect(relatorioMigracao['totalViagensMigradas'], equals(2));
      expect(relatorioMigracao['viagensIds'], containsAll(['viagem_legada_01', 'viagem_legada_02']));

      // Consulta pós-migração: zero viagens órfãs
      final legadasDepois = viagemService.viagensAtivas.where((v) => v.sessaoId == null).length;
      expect(legadasDepois, equals(0), reason: 'Nenhuma viagem deve permanecer órfã sem sessaoId');

      // Sessão de veículo foi criada e associada
      expect(viagemService.sessaoAtiva, isNotNull);
      final sessaoCriada = viagemService.sessaoAtiva!;
      expect(sessaoCriada.veiculoPlaca, equals('BRA-2E19'));
      expect(sessaoCriada.motoristaId, equals('mot_carlos'));

      for (final viagem in viagemService.viagensAtivas) {
        expect(viagem.sessaoId, equals(sessaoCriada.id));
      }
    });

    test('3. Plano de reversão (rollback) desfaz o vínculo preservando integridade das viagens', () async {
      // Executa a migração primeiro
      await viagemService.migrarViagensLegadasParaSessao();
      expect(viagemService.viagensAtivas.every((v) => v.sessaoId != null), isTrue);

      // Dispara o rollback
      await viagemService.reverterMigracaoParaTestes(
        viagensIds: ['viagem_legada_01', 'viagem_legada_02'],
      );

      // Confere que o estado foi restaurado sem sessaoId e sem perder dados
      expect(viagemService.viagensAtivas.length, equals(2));
      for (final viagem in viagemService.viagensAtivas) {
        expect(viagem.sessaoId, isNull);
        expect(viagem.veiculoPlaca, equals('BRA-2E19'));
        expect(viagem.status, equals('ativa'));
      }
    });
  });
}
