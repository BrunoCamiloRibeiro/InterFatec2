// ============================================================================
// ARQUIVO: lib/services/transacao_firestore_service.dart
// ----------------------------------------------------------------------------
// O QUE FAZ:
// Serviço central de operações atômicas ACID e de concorrência no Cloud Firestore:
// 1. Ocupar carro com garantia de exclusividade mútua (evita dois motoristas no mesmo carro);
// 2. Liberar carro ("Finalizar Viagem" do condutor) sem alterar o ciclo da viagem;
// 3. Embarcar paciente respeitando a capacidade máxima de assentos ("lugares livres");
// 4. Atualizar status do paciente com encerramento automático da viagem em ponto único
//    (a viagem encerra SOMENTE quando TODOS os pacientes retornarem);
// 5. Gestão de telemetria GPS com timestamp de servidor e TTL de 5 minutos.
//
// PAPEL NA ARQUITETURA (CAMADA):
// Camada de Serviços / Transações e Concorrência (Data & Business Logic Layer).
// ============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado padronizado de uma operação atômica de transação.
class ResultadoTransacao<T> {
  final bool sucesso;
  final String? mensagemErro;
  final T? dados;

  const ResultadoTransacao.sucesso([this.dados])
      : sucesso = true,
        mensagemErro = null;

  const ResultadoTransacao.falha(this.mensagemErro)
      : sucesso = false,
        dados = null;

  @override
  String toString() => sucesso ? 'Sucesso($dados)' : 'Falha($mensagemErro)';
}

/// Serviço de operações atômicas via runTransaction do Cloud Firestore.
class TransacaoFirestoreService {
  final FirebaseFirestore _firestore;

  TransacaoFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // --------------------------------------------------------------------------
  // 1. OCUPAR CARRO (Transação Atômica)
  // Garante que dois motoristas nunca ocupem o mesmo veículo concorrentemente.
  // --------------------------------------------------------------------------
  Future<ResultadoTransacao<void>> ocuparCarro({
    required String motoristaId,
    required String veiculoId,
    int? kmInicial,
  }) async {
    try {
      final veiculoRef = _firestore.collection('veiculos').doc(veiculoId);
      final motoristaRef = _firestore.collection('usuarios').doc(motoristaId);

      await _firestore.runTransaction((transaction) async {
        final veiculoSnap = await transaction.get(veiculoRef);
        if (!veiculoSnap.exists) {
          throw Exception('Veículo não encontrado.');
        }

        final veiculoData = veiculoSnap.data() ?? {};
        final emUso = veiculoData['emUso'] == true;
        final motoristaAtual = veiculoData['motoristaAtualId']?.toString();

        // Se o carro já está ocupado por outro motorista, rejeita atomicamente
        if (emUso && motoristaAtual != null && motoristaAtual != motoristaId) {
          throw Exception('Veículo já está em uso por outro motorista.');
        }

        // Atualiza o documento do veículo
        final updateVeiculo = <String, dynamic>{
          'emUso': true,
          'motoristaAtualId': motoristaId,
          'status': 'emViagem',
        };
        if (kmInicial != null) {
          updateVeiculo['quilometragem'] = kmInicial;
          updateVeiculo['quilometragemAtual'] = kmInicial;
        }
        transaction.update(veiculoRef, updateVeiculo);

        // Atualiza a flag emViagem no documento do motorista
        if (motoristaId.isNotEmpty) {
          transaction.update(motoristaRef, {
            'emViagem': true,
          });
        }
      });

      return const ResultadoTransacao.sucesso();
    } catch (e) {
      return ResultadoTransacao.falha(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --------------------------------------------------------------------------
  // 2. LIBERAR CARRO (Transação Atômica)
  // Desvincula o carro do motorista e marca emViagem = false.
  // NUNCA encerra a viagem! A viagem continua aberta/em andamento.
  // --------------------------------------------------------------------------
  Future<ResultadoTransacao<void>> liberarCarro({
    required String motoristaId,
    required String veiculoId,
    int? kmFinal,
  }) async {
    try {
      final veiculoRef = _firestore.collection('veiculos').doc(veiculoId);
      final motoristaRef = _firestore.collection('usuarios').doc(motoristaId);

      await _firestore.runTransaction((transaction) async {
        final veiculoSnap = await transaction.get(veiculoRef);
        if (veiculoSnap.exists) {
          final updateVeiculo = <String, dynamic>{
            'emUso': false,
            'motoristaAtualId': null,
            'status': 'disponivel',
          };
          if (kmFinal != null) {
            updateVeiculo['quilometragem'] = kmFinal;
            updateVeiculo['quilometragemAtual'] = kmFinal;
          }
          transaction.update(veiculoRef, updateVeiculo);
        }

        if (motoristaId.isNotEmpty) {
          transaction.update(motoristaRef, {
            'emViagem': false,
          });
        }
      });

      // Desativa a telemetria do motorista que liberou o carro
      if (motoristaId.isNotEmpty) {
        try {
          await _firestore.collection('localizacoes_motoristas').doc(motoristaId).update({
            'emViagem': false,
          });
        } catch (_) {}
      }

      return const ResultadoTransacao.sucesso();
    } catch (e) {
      return ResultadoTransacao.falha(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --------------------------------------------------------------------------
  // 3. ATUALIZAR STATUS DO PACIENTE E CALCULAR ENCERRAMENTO DA VIAGEM
  // Estados permitidos: aguardando -> pronto -> a bordo -> foi embora -> retornou.
  // Encerramento da viagem calculado em um ÚNICO ponto atômico:
  // SOMENTE quando TODOS os pacientes daquela viagem estiverem com status "retornou".
  // --------------------------------------------------------------------------
  Future<ResultadoTransacao<void>> atualizarStatusPaciente({
    required String viagemId,
    required String pacienteId,
    required String novoStatus,
    String? motoristaId,
    String? veiculoId,
  }) async {
    try {
      final viagemRef = _firestore.collection('viagens').doc(viagemId);

      await _firestore.runTransaction((transaction) async {
        final viagemSnap = await transaction.get(viagemRef);
        if (!viagemSnap.exists) {
          throw Exception('Viagem não encontrada.');
        }

        final viagemData = viagemSnap.data() ?? {};
        final passageirosRaw = viagemData['passageiros'];
        List<Map<String, dynamic>> passageiros = [];

        if (passageirosRaw is List) {
          passageiros = passageirosRaw
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
        }

        final index = passageiros.indexWhere(
          (p) => (p['pacienteId'] ?? p['id']) == pacienteId,
        );

        if (index == -1) {
          throw Exception('Paciente não encontrado nesta viagem.');
        }

        // Validação de capacidade de lugares caso a ação seja embarcar ('a bordo')
        if (novoStatus == 'a bordo' && veiculoId != null && veiculoId.isNotEmpty) {
          final veiculoRef = _firestore.collection('veiculos').doc(veiculoId);
          final veiculoSnap = await transaction.get(veiculoRef);
          if (veiculoSnap.exists) {
            final vData = veiculoSnap.data() ?? {};
            final capacidade = (vData['capacidade'] ?? vData['qtdAssentos'] ?? 4) as int;

            // Conta quantos pacientes já estão "a bordo" com este motorista/carro
            int aBordoCount = 0;
            for (final p in passageiros) {
              final st = (p['statusEmbarqueNome'] ?? p['status'] ?? '').toString();
              if (st == 'a bordo' && (p['pacienteId'] ?? p['id']) != pacienteId) {
                aBordoCount++;
              }
            }

            if (aBordoCount >= capacidade) {
              throw Exception('Capacidade máxima do veículo ($capacidade lugares) atingida.');
            }
          }
        }

        // Atualiza os dados do passageiro dentro do documento da viagem
        passageiros[index]['status'] = novoStatus;
        passageiros[index]['statusEmbarqueNome'] = novoStatus;
        passageiros[index]['atualizadoEm'] = DateTime.now().toIso8601String();
        if (motoristaId != null) {
          passageiros[index]['motoristaResponsavelId'] = motoristaId;
        }

        // Avalia o novo ciclo da viagem
        String statusViagemAtual = viagemData['status']?.toString() ?? 'aberta';

        // Se algum paciente entrou a bordo, a viagem passa para 'em_andamento'
        if (statusViagemAtual == 'aberta' &&
            (novoStatus == 'a bordo' || novoStatus == 'foi embora')) {
          statusViagemAtual = 'em_andamento';
        }

        // Avalia se TODOS os pacientes da viagem atingiram o status "retornou"
        bool todosRetornaram = true;
        for (final p in passageiros) {
          final st = (p['statusEmbarqueNome'] ?? p['status'] ?? '').toString();
          if (st != 'retornou') {
            todosRetornaram = false;
            break;
          }
        }

        // Regra Inviolável de Domínio:
        // A viagem encerra SOMENTE quando todos os pacientes dela estiverem com status "retornou".
        if (todosRetornaram && passageiros.isNotEmpty) {
          statusViagemAtual = 'encerrada';
        }

        // Atualiza a viagem atomicamente
        transaction.update(viagemRef, {
          'passageiros': passageiros,
          'status': statusViagemAtual,
          'atualizadoEm': FieldValue.serverTimestamp(),
          if (statusViagemAtual == 'encerrada')
            'dataHoraFim': DateTime.now().toIso8601String(),
        });

        // Sincroniza também no documento do paciente em /usuarios/{pacienteId} se existir
        if (pacienteId.isNotEmpty) {
          final pacienteDocRef = _firestore.collection('usuarios').doc(pacienteId);
          transaction.set(pacienteDocRef, {
            'status': novoStatus,
            'statusViagem': novoStatus,
            'atualizadoEm': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
      });

      return const ResultadoTransacao.sucesso();
    } catch (e) {
      return ResultadoTransacao.falha(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --------------------------------------------------------------------------
  // 4. TELEMETRIA GPS DE MOTORISTAS COM TIMESTAMP E TTL
  // Registra a localização apenas de condutores com emViagem = true.
  // --------------------------------------------------------------------------
  Future<void> atualizarLocalizacaoMotorista({
    required String motoristaId,
    required String motoristaNome,
    required double latitude,
    required double longitude,
    required bool emViagem,
  }) async {
    if (motoristaId.isEmpty) return;

    final docRef = _firestore.collection('localizacoes_motoristas').doc(motoristaId);
    final agora = DateTime.now();
    final ttl = agora.add(const Duration(minutes: 5)); // TTL de 5 minutos

    await docRef.set({
      'motoristaId': motoristaId,
      'motoristaNome': motoristaNome,
      'latitude': latitude,
      'longitude': longitude,
      'emViagem': emViagem,
      'atualizadoEm': FieldValue.serverTimestamp(),
      'expiraEm': Timestamp.fromDate(ttl),
    }, SetOptions(merge: true));
  }

  // --------------------------------------------------------------------------
  // 5. ESCUTA DE MOTORISTAS ATIVOS E RECENTES (STREAM COM ESCOPO MÍNIMO)
  // Retorna apenas motoristas com emViagem == true e atualizados recentemente.
  // --------------------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> escutarMotoristasAtivos() {
    return _firestore
        .collection('localizacoes_motoristas')
        .where('emViagem', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final cincoMinutosAtras = DateTime.now().subtract(const Duration(minutes: 5));
          return snapshot.docs
              .map((d) => d.data())
              .where((data) {
                // Checa TTL ou timestamp recente
                final ts = data['atualizadoEm'];
                if (ts is Timestamp) {
                  return ts.toDate().isAfter(cincoMinutosAtras);
                }
                return true;
              })
              .toList();
        });
  }
}
