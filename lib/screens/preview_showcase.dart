// ============================================================================
// CABEÇALHO DE DOCUMENTAÇÃO DE ARQUIVO: preview_showcase.dart
// ============================================================================
// Camada: Apresentação / Previews para Demonstração e Captura de Telas
//
// O QUE ESTE ARQUIVO FAZ:
// Fornece widgets de demonstração pré-configurados com dados representativos
// de teste para validação visual, captura de evidências/screenshots para PRs
// e conferência de uniformidade visual da interface (AppBar, cores, cards).
// ============================================================================

import 'package:flutter/material.dart';
import '../components/formulario_encerramento.dart';
import '../models/paciente_model.dart';
import '../models/user_role.dart';
import '../models/veiculo_model.dart';
import '../models/viagem_model.dart';
import '../motorista.dart';
import '../paciente.dart';
import '../screens/gerenciador_viagens_screen.dart';
import '../services/auth_service.dart';
import '../services/viagem_service.dart';

class _FakePreviewAuthService implements AuthService {
  @override
  Future<UserRole> login(String cpf, String senha) async => UserRole.admin;
  @override
  Future<UserRole> loginPacienteComCodigo({
    required String documento,
    required String codigoAcesso,
    String? ipOrigem,
    List<PacienteModel>? pacientesParaTestes,
  }) async =>
      UserRole.paciente;
  @override
  Future<void> logout() async {}
  @override
  Stream<String?> get authStateChanges => const Stream.empty();
  @override
  Future<UserRole> resolveUserRole(String uid, {bool forceRefresh = false}) async =>
      UserRole.admin;
  @override
  UserRole? getCachedRole(String uid) => UserRole.admin;
  @override
  void clearRoleCache() {}
  @override
  String? get currentUserId => 'admin_preview';
}

/// Preview do Gerenciador de Viagens (Horários do Dia) com grade completa
class GerenciadorViagensPreview extends StatelessWidget {
  const GerenciadorViagensPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);

    final service = ViagemService();
    service.resetParaTestes(
      veiculosIniciais: const [
        VeiculoModel(
          id: 'v1',
          placa: 'ABC-1D23',
          modelo: 'Chevrolet Spin 7L',
          capacidade: 7,
          quilometragemAtual: 45200,
        ),
        VeiculoModel(
          id: 'v2',
          placa: 'DEF-5E67',
          modelo: 'Renault Master Minibus',
          capacidade: 16,
          quilometragemAtual: 82150,
        ),
        VeiculoModel(
          id: 'v3',
          placa: 'GHI-9J01',
          modelo: 'Fiat Doblò Essence',
          capacidade: 6,
          quilometragemAtual: 63400,
        ),
      ],
      todasViagensIniciais: [
        ViagemModel(
          id: 'h1',
          motoristaId: 'm1',
          motoristaNome: 'Antônio Carlos',
          veiculoId: 'v1',
          veiculoPlaca: 'ABC-1D23',
          veiculoModelo: 'Chevrolet Spin 7L',
          kmInicial: 45200,
          cidadeDestino: 'BARRETOS',
          nomeHorario: '06:00 - Saída Barretos (Hospital de Amor)',
          dataViagem: dataHoje,
          dataHoraInicio: DateTime(dataHoje.year, dataHoje.month, dataHoje.day, 6, 0),
          status: 'ativa',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p1',
              pacienteNome: 'Maria Aparecida da Silva',
              acompanhanteNome: 'José Carlos da Silva',
              localOrigem: 'Av. Brasil, 1200 - Centro',
              localDestino: 'Hospital de Amor - Oncologia',
              horarioAtendimento: '09:00',
              ordemEmbarque: 1,
              statusEmbarque: 1,
            ),
            PassageiroViagemModel(
              pacienteId: 'p2',
              pacienteNome: 'Sebastião Ferreira',
              localOrigem: 'Rua das Flores, 45 - Jd. América',
              localDestino: 'Hospital de Amor - Radioterapia',
              horarioAtendimento: '10:30',
              ordemEmbarque: 2,
              statusEmbarque: 0,
            ),
          ],
        ),
        ViagemModel(
          id: 'h2',
          motoristaId: 'm2',
          motoristaNome: 'João da Silva',
          veiculoId: 'v2',
          veiculoPlaca: 'DEF-5E67',
          veiculoModelo: 'Renault Master Minibus',
          kmInicial: 82150,
          cidadeDestino: 'SÃO PAULO',
          nomeHorario: '07:30 - Saída São Paulo (HC / InCor)',
          dataViagem: dataHoje,
          dataHoraInicio: DateTime(dataHoje.year, dataHoje.month, dataHoje.day, 7, 30),
          status: 'planejada',
          passageiros: const [
            PassageiroViagemModel(
              pacienteId: 'p3',
              pacienteNome: 'Benedita dos Santos',
              acompanhanteNome: 'Cláudia Santos',
              localOrigem: 'Rua São Paulo, 310',
              localDestino: 'Hospital das Clínicas FMUSP',
              horarioAtendimento: '11:00',
              ordemEmbarque: 1,
              statusEmbarque: 0,
            ),
            PassageiroViagemModel(
              pacienteId: 'p4',
              pacienteNome: 'Francisco de Assis',
              localOrigem: 'Av. Paulista, 80',
              localDestino: 'InCor - Cardiologia',
              horarioAtendimento: '13:00',
              ordemEmbarque: 2,
              statusEmbarque: 0,
            ),
          ],
        ),
        ViagemModel(
          id: 'h3',
          motoristaId: 'm3',
          motoristaNome: 'Carlos Souza',
          veiculoId: 'v3',
          veiculoPlaca: 'GHI-9J01',
          veiculoModelo: 'Fiat Doblò Essence',
          kmInicial: 63400,
          cidadeDestino: 'RIBEIRÃO PRETO',
          nomeHorario: '13:00 - Saída Ribeirão Preto (HCRP)',
          dataViagem: dataHoje,
          dataHoraInicio: DateTime(dataHoje.year, dataHoje.month, dataHoje.day, 13, 0),
          status: 'planejada',
          passageiros: const [],
        ),
      ],
    );

    return GerenciadorViagensScreen(
      viagemServiceOverride: service,
      authServiceOverride: _FakePreviewAuthService(),
      dataInicial: dataHoje,
    );
  }
}

/// Preview da tela do Motorista em Viagem Ativa com passageiros
class MotoristaViagemPreview extends StatelessWidget {
  const MotoristaViagemPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final viagem = ViagemModel(
      id: 'h1',
      motoristaId: 'm1',
      motoristaNome: 'Antônio Carlos',
      veiculoId: 'v1',
      veiculoPlaca: 'ABC-1D23',
      veiculoModelo: 'Chevrolet Spin 7L',
      kmInicial: 45200,
      cidadeDestino: 'BARRETOS',
      nomeHorario: '06:00 - Saída Barretos',
      dataViagem: hoje,
      dataHoraInicio: DateTime(hoje.year, hoje.month, hoje.day, 6, 0),
      status: 'ativa',
      passageiros: const [
        PassageiroViagemModel(
          pacienteId: 'p1',
          pacienteNome: 'Maria Aparecida da Silva',
          acompanhanteNome: 'José Carlos da Silva',
          localOrigem: 'Av. Brasil, 1200 - Centro',
          localDestino: 'Hospital de Amor - Oncologia',
          horarioAtendimento: '09:00',
          ordemEmbarque: 1,
          statusEmbarque: 1,
        ),
        PassageiroViagemModel(
          pacienteId: 'p2',
          pacienteNome: 'Sebastião Ferreira',
          localOrigem: 'Rua das Flores, 45 - Jd. América',
          localDestino: 'Hospital de Amor - Radioterapia',
          horarioAtendimento: '10:30',
          ordemEmbarque: 2,
          statusEmbarque: 0,
        ),
      ],
    );

    return Motorista(
      viagemInicial: viagem,
      pacientesStreamOverride: Stream.value([
        PacienteModel(
          id: 'p1',
          nome: 'Maria Aparecida da Silva',
          cpf: '123.456.789-00',
          telefone: '(16) 99887-1122',
          enderecoPaciente: 'Av. Brasil, 1200 - Centro',
          localConsulta: 'Hospital de Amor - Oncologia',
          localSaida: 'Av. Brasil, 1200 - Centro',
          horarioConsulta: '09:00',
          status: 1, // Embarcou
          nomeAcompanhante: 'José Carlos da Silva',
        ),
        PacienteModel(
          id: 'p2',
          nome: 'Sebastião Ferreira',
          cpf: '571.098.984-31',
          telefone: '(16) 99776-3344',
          enderecoPaciente: 'Rua das Flores, 45 - Jd. América',
          localConsulta: 'Hospital de Amor - Radioterapia',
          localSaida: 'Rua das Flores, 45 - Jd. América',
          horarioConsulta: '10:30',
          status: 0, // Aguardando
        ),
      ]),
    );
  }
}

/// Preview do Diálogo de Confirmação de Finalização da Viagem
class MotoristaConfirmacaoPreview extends StatelessWidget {
  const MotoristaConfirmacaoPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const MotoristaViagemPreview(),
        Container(
          color: Colors.black.withOpacity(0.54),
          alignment: Alignment.center,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Finalizar Viagem',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Você tem certeza que quer finalizar a viagem?',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () {},
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {},
                child: const Text('Sim, Finalizar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Preview do Formulário de Encerramento (KM retorno, horário e PDF)
class MotoristaEncerramentoPreview extends StatelessWidget {
  const MotoristaEncerramentoPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final viagem = ViagemModel(
      id: 'h1',
      motoristaId: 'm1',
      motoristaNome: 'Antônio Carlos',
      veiculoId: 'v1',
      veiculoPlaca: 'ABC-1D23',
      veiculoModelo: 'Chevrolet Spin 7L',
      kmInicial: 45200,
      cidadeDestino: 'BARRETOS',
      nomeHorario: '06:00 - Saída Barretos',
      dataViagem: hoje,
      dataHoraInicio: DateTime(hoje.year, hoje.month, hoje.day, 6, 0),
      status: 'ativa',
    );

    return Stack(
      children: [
        const MotoristaViagemPreview(),
        Container(
          color: Colors.black.withOpacity(0.54),
          alignment: Alignment.center,
          child: FormularioEncerramento(
            viagem: viagem,
            viagens: [viagem],
            pacientes: [
              PacienteModel(
                id: 'p1',
                nome: 'Maria Aparecida da Silva',
                cpf: '123.456.789-00',
                telefone: '(16) 99887-1122',
                enderecoPaciente: 'Av. Brasil, 1200 - Centro',
                localConsulta: 'Hospital de Amor',
                localSaida: 'Av. Brasil, 1200',
                horarioConsulta: '09:00',
                status: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Preview do Painel de Acompanhamento do Paciente
class PacientePainelPreview extends StatelessWidget {
  const PacientePainelPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Paciente(
      pacienteId: 'p1',
      pacienteStreamOverride: Stream.value(
        PacienteModel(
          id: 'p1',
          nome: 'Maria Aparecida da Silva',
          cpf: '123.456.789-00',
          telefone: '(16) 99887-1122',
          enderecoPaciente: 'Av. Brasil, 1200 - Centro',
          localConsulta: 'Hospital de Amor - Barretos (Oncologia)',
          localSaida: 'Av. Brasil, 1200 - Centro',
          horarioConsulta: '09:00',
          status: 1, // Em trânsito
          nomeAcompanhante: 'José Carlos da Silva',
        ),
      ),
    );
  }
}
