// ============================================================================
// SCRIPT DE SIMULAÇÃO DE ATAQUE DE FORÇA BRUTA (ISSUE #65)
// ----------------------------------------------------------------------------
// Execução: flutter test tool/simular_forca_bruta.dart
// Comprova que um ataque massivo de códigos numéricos (4 a 5 dígitos)
// é bloqueado temporariamente por IP e CPF após a 5ª tentativa falha.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trans_saude/models/paciente_model.dart';
import 'package:trans_saude/models/sessao_veiculo_model.dart';
import 'package:trans_saude/models/viagem_model.dart';
import 'package:trans_saude/services/auth_service.dart';
import 'package:trans_saude/services/codigo_acesso_service.dart';
import 'package:trans_saude/services/viagem_service.dart';

void main() {
  test('Simulação de Ataque de Força Bruta: 100 requisições contra código de acesso', () async {
    print('\n====================================================================');
    print('SIMULAÇÃO DE ATAQUE DE FORÇA BRUTA - CÓDIGOS DE ACESSO (ISSUE #65)');
    print('====================================================================');

    CodigoAcessoService.resetarRateLimitParaTestes();
    final viagemService = ViagemService();
    final authService = FirebaseAuthService();

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

    print('Alvo sob ataque: CPF $cpfAlvo | IP Atacante: $ipAtacante');
    print('Iniciando envio sequencial de 100 tentativas com códigos falsos...');
    print('--------------------------------------------------------------------');

    int tentativasPermitidasAntesDoBloqueio = 0;
    int tentativasBloqueadasImediatamente = 0;

    for (int i = 1; i <= 100; i++) {
      final codigoTentativa = i.toString().padLeft(4, '0');

      try {
        await authService.loginPacienteComCodigo(
          documento: cpfAlvo,
          codigoAcesso: codigoTentativa,
          ipOrigem: ipAtacante,
          pacientesParaTestes: [pacienteAlvo],
        );
        fail('Tentativa não deveria ter sucesso');
      } on AuthException catch (e) {
        if (e.code == 'rate-limit-exceeded') {
          tentativasBloqueadasImediatamente++;
          if (tentativasBloqueadasImediatamente == 1) {
            print('Tentativa $i: [BLOQUEADO] Rate limit ativado na 5ª falha! Mensagem: "${e.message}"');
          }
        } else {
          tentativasPermitidasAntesDoBloqueio++;
          print('Tentativa $i ($codigoTentativa): Falha normal de autenticação (Falha $tentativasPermitidasAntesDoBloqueio de 5 permitidas).');
        }
      }
    }

    print('--------------------------------------------------------------------');
    print('RELATÓRIO DE COMPROVAÇÃO DE DEFESA:');
    print('- Total de tentativas executadas: 100');
    print('- Tentativas computadas antes do bloqueio: $tentativasPermitidasAntesDoBloqueio (esperado: 5)');
    print('- Tentativas bloqueadas sem processamento: $tentativasBloqueadasImediatamente (esperado: 95)');
    print('- Status de Bloqueio Ativo: ${CodigoAcessoService.estaBloqueado(cpfAlvo, ip: ipAtacante)}');
    print('====================================================================\n');

    expect(tentativasPermitidasAntesDoBloqueio, equals(5));
    expect(tentativasBloqueadasImediatamente, equals(95));
    expect(CodigoAcessoService.estaBloqueado(cpfAlvo, ip: ipAtacante), isTrue);
  });
}
