// ============================================================================
// TESTE AUTOMATIZADO: SIMULAÇÃO DE ATAQUE DE FORÇA BRUTA
// ----------------------------------------------------------------------------
// Repositório: BrunoCamiloRibeiro/InterFatec2
// Contexto: Issue #65 - Comprovação de bloqueio temporário contra força bruta.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/sessao_veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/codigo_acesso_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  group('Simulação de Ataque de Força Bruta (Issue #65)', () {
    late ViagemService viagemService;
    late FirebaseAuthService authService;

    const cpfAlvo = '529.982.247-25';
    const ipAtacante = '192.168.1.150';

    final pacienteAlvo = PacienteModel(
      id: 'pac_alvo_01',
      nome: 'Maria Silva Poloni',
      cpf: cpfAlvo,
      enderecoPaciente: 'Rua das Flores, 10',
      telefone: '(17) 99111-2222',
      localConsulta: 'Hospital de Base',
      localSaida: 'UBS Poloni',
      status: 1,
    );

    const codigoReal = '8492';
    final hashReal = CodigoAcessoService.calcularHash(codigoReal, 'viagem_segura_01');

    final viagemAtiva = ViagemModel(
      id: 'viagem_segura_01',
      motoristaId: 'mot_01',
      motoristaNome: 'Carlos Motorista',
      veiculoId: 'veic_01',
      veiculoPlaca: 'BRA-2E19',
      veiculoModelo: 'Spin',
      kmInicial: 50000,
      cidadeDestino: 'São José do Rio Preto',
      dataHoraInicio: DateTime.now(),
      status: 'ativa',
      codigosAcesso: {pacienteAlvo.id: codigoReal},
      codigosHash: {pacienteAlvo.id: hashReal},
    );

    setUp(() {
      CodigoAcessoService.resetarRateLimitParaTestes();
      viagemService = ViagemService();
      authService = FirebaseAuthService();

      viagemService.resetParaTestes(
        viagensAtivasIniciais: [viagemAtiva],
        sessaoAtivaInicial: SessaoVeiculoModel(
          id: 'sessao_01',
          motoristaId: 'mot_01',
          motoristaNome: 'Carlos Motorista',
          veiculoId: 'veic_01',
          veiculoPlaca: 'BRA-2E19',
          veiculoModelo: 'Spin',
          kmInicial: 50000,
          dataHoraInicio: DateTime.now(),
          viagensIds: [viagemAtiva.id],
        ),
      );
    });

    test('Simula 100 tentativas sucessivas: bloqueia na 5ª falha e rejeita as 95 subsequentes', () async {
      int falhasAutenticacao = 0;
      int bloqueiosRateLimit = 0;

      for (int i = 1; i <= 100; i++) {
        final codigoTentativa = i.toString().padLeft(4, '0');

        try {
          await authService.loginPacienteComCodigo(
            documento: cpfAlvo,
            codigoAcesso: codigoTentativa,
            ipOrigem: ipAtacante,
            pacientesParaTestes: [pacienteAlvo],
          );
          fail('Não deveria autenticar com código falso.');
        } on AuthException catch (e) {
          if (e.code == 'rate-limit-exceeded') {
            bloqueiosRateLimit++;
          } else if (e.code == 'invalid-credentials') {
            falhasAutenticacao++;
          }
        }
      }

      expect(falhasAutenticacao, equals(5),
          reason: 'O sistema deve permitir exatamente 5 tentativas antes do bloqueio');
      expect(bloqueiosRateLimit, equals(95),
          reason: 'As 95 tentativas subsequentes devem ser bloqueadas imediatamente');
      expect(CodigoAcessoService.estaBloqueado(cpfAlvo, ip: ipAtacante), isTrue);

      // Mesmo que o invasor tente o código correto após o bloqueio, deve continuar bloqueado
      expect(
        () async => await authService.loginPacienteComCodigo(
          documento: cpfAlvo,
          codigoAcesso: codigoReal, // Código correto!
          ipOrigem: ipAtacante,
          pacientesParaTestes: [pacienteAlvo],
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'rate-limit-exceeded',
        )),
        reason: 'Invasor bloqueado não consegue autenticar mesmo acertando o código',
      );
    });
  });
}
