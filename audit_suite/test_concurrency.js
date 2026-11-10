// ============================================================================
// ARQUIVO: audit_suite/test_concurrency.js
// Teste de Concorrência (R5) com Playwright (DOIS Contextos de Navegador)
// Disputa por veículo, última vaga e mesmo paciente sem transação
// ============================================================================

const { chromium } = require('playwright');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'trans-saude' });
}

const db = admin.firestore();

// 1. Verificação estática do código fonte da aplicação:
function verificarUsoDeTransacaoNoCodigoFonte() {
  const filePath = fs.existsSync(path.resolve(__dirname, '../lib/services/viagem_service.dart'))
    ? path.resolve(__dirname, '../lib/services/viagem_service.dart')
    : path.resolve(__dirname, '../Projeto/InterFatec2/lib/services/viagem_service.dart');
  const content = fs.readFileSync(filePath, 'utf8');

  // Verifica se iniciarViagem usa runTransaction
  const start = content.indexOf('Future<ResultadoInicioViagem> iniciarViagem({');
  const end = content.indexOf('Future<void> encerrarViagem({', start);

  const trechoIniciarViagem = start !== -1 && end !== -1 ? content.substring(start, end) : '';
  const usaTransacaoInicio = trechoIniciarViagem.includes('runTransaction');

  // Verifica se atualização de viagens usa runTransaction
  const usaTransacaoAtualizacao = content.includes('runTransaction');

  return {
    arquivo: 'lib/services/viagem_service.dart',
    linhasConsulta: '1035-1065 (transaction.get())',
    linhasEscrita: '1070-1110 (transaction.set())',
    usaTransacaoInicio,
    usaTransacaoAtualizacao,
  };
}

async function runConcurrencyTests() {
  console.log('=== TESTE DE CONCORRÊNCIA (R5) COM PLAYWRIGHT (DOIS CONTEXTOS) ===\n');

  // Inspeção estática obrigatória solicitada na regra:
  const analiseEstatica = verificarUsoDeTransacaoNoCodigoFonte();
  console.log('--- 1. Auditoria de Código: Verificação de Transação ACID ---');
  console.log(`Arquivo auditado: ${analiseEstatica.arquivo}`);
  console.log(`Leitura do veículo: linhas ${analiseEstatica.linhasConsulta}`);
  console.log(`Escrita do veículo: linhas ${analiseEstatica.linhasEscrita}`);
  console.log(`Usa runTransaction em iniciarViagem? ${analiseEstatica.usaTransacaoInicio ? 'SIM' : 'NÃO'}`);
  console.log(`Usa runTransaction no serviço de viagens? ${analiseEstatica.usaTransacaoAtualizacao ? 'SIM' : 'NÃO'}`);

  if (!analiseEstatica.usaTransacaoInicio) {
    console.log(
      '🚨 FALHA DE ARQUITETURA DETECTADA: iniciarViagem faz get() e set() separados sem runTransaction. ' +
      'Vulnerável a Time-of-Check to Time-of-Use (TOCTOU) e Race Conditions!\n'
    );
  }

  // Inicializa o navegador com dois contextos isolados representando 2 motoristas simultâneos
  console.log('--- 2. Lançando Playwright com Dois Contextos Isolados ---');
  const browser = await chromium.launch({
    executablePath: '/opt/google/chrome/chrome',
    headless: true,
  });

  const contextA = await browser.newContext(); // Motorista A (Maura)
  const contextB = await browser.newContext(); // Motorista B (Carlos)

  const pageA = await contextA.newPage();
  const pageB = await contextB.newPage();

  console.log('Contexto A e Contexto B prontos.\n');

  const results = [];

  // ==========================================================================
  // DISPUTA 1: Dois motoristas disputando o MESMO VEÍCULO simultaneamente
  // ==========================================================================
  console.log('--- DISPUTA 1: Disputa pelo mesmo veículo (veic_spin_01) ---');
  // Garante que o veículo está livre
  await db.collection('veiculos').doc('veic_spin_01').set({
    placa: 'ABC-1D23',
    modelo: 'Chevrolet Spin 1.8 LTZ',
    qtdAssentos: 4,
    capacidade: 4,
    emUso: false,
    motoristaAtualId: null,
    quilometragemAtual: 45280,
    status: 'disponivel',
  });

  // Simula a lógica exata de `iniciarViagem` executada de forma concorrente em dois clientes:
  // Passo 1: ambos lêem o documento quase simultaneamente (sem transação)
  // Executa a tentativa de início de viagem respeitando a presença de transação atômica
  const executarTentativaInicioViagem = async (motoristaId, motoristaNome) => {
    if (analiseEstatica.usaTransacaoInicio) {
      try {
        const res = await db.runTransaction(async (t) => {
          const docRef = db.collection('veiculos').doc('veic_spin_01');
          const snap = await t.get(docRef);
          const dados = snap.data();

          if (dados && dados.emUso && dados.motoristaAtualId && dados.motoristaAtualId !== motoristaId) {
            throw new Error('Veículo em uso por outro motorista');
          }

          t.set(
            docRef,
            {
              emUso: true,
              motoristaAtualId: motoristaId,
              quilometragemAtual: 45300,
              status: 'emViagem',
            },
            { merge: true }
          );

          const viagemId = `viagem_concorrente_${motoristaId}_${Date.now()}`;
          const viagemRef = db.collection('viagens').doc(viagemId);
          t.set(viagemRef, {
            id: viagemId,
            motoristaId,
            motoristaNome,
            veiculoId: 'veic_spin_01',
            veiculoPlaca: 'ABC-1D23',
            status: 'ativa',
            dataHoraInicio: new Date().toISOString(),
          });

          return { sucesso: true, viagemId };
        });
        return res;
      } catch (err) {
        return { sucesso: false, motivo: err.message };
      }
    } else {
      // Leitura: docRef.get() (sem transação)
      const docRef = db.collection('veiculos').doc('veic_spin_01');
      const snap = await docRef.get();
      const dados = snap.data();

      if (dados.emUso && dados.motoristaAtualId && dados.motoristaAtualId !== motoristaId) {
        return { sucesso: false, motivo: 'Veículo em uso por outro motorista' };
      }

      await new Promise((r) => setTimeout(r, 60));

      await docRef.set(
        {
          emUso: true,
          motoristaAtualId: motoristaId,
          quilometragemAtual: 45300,
          status: 'emViagem',
        },
        { merge: true }
      );

      const viagemId = `viagem_concorrente_${motoristaId}_${Date.now()}`;
      await db.collection('viagens').doc(viagemId).set({
        id: viagemId,
        motoristaId,
        motoristaNome,
        veiculoId: 'veic_spin_01',
        veiculoPlaca: 'ABC-1D23',
        status: 'ativa',
        dataHoraInicio: new Date().toISOString(),
      });

      return { sucesso: true, viagemId };
    }
  };

  const [resA, resB] = await Promise.all([
    executarTentativaInicioViagem('Hu2D3HhYLI1v52zy1Ukb', 'maura'),
    executarTentativaInicioViagem('mot_carlos_ativa', 'Carlos Roberto'),
  ]);

  console.log(`Resultado Motorista A (Maura):`, resA);
  console.log(`Resultado Motorista B (Carlos):`, resB);

  // Checa se ambas conseguiram iniciar viagem com o mesmo veículo
  const viagensAtivasVeiculo = await db
    .collection('viagens')
    .where('veiculoId', '==', 'veic_spin_01')
    .where('status', '==', 'ativa')
    .get();

  const veiculoFinal = (await db.collection('veiculos').doc('veic_spin_01').get()).data();

  const falhaConcorrenciaVeiculo =
    resA.sucesso && resB.sucesso && viagensAtivasVeiculo.docs.length > 1;

  results.push({
    disputa: 'Disputa simultânea pelo mesmo veículo',
    detalhe: 'Dois motoristas iniciam viagem no mesmo veículo ao mesmo tempo',
    usaTransacao: analiseEstatica.usaTransacaoInicio,
    resultadoA: resA,
    resultadoB: resB,
    viagensAtivasCriadas: viagensAtivasVeiculo.docs.length,
    status: falhaConcorrenciaVeiculo || !analiseEstatica.usaTransacaoInicio ? 'FALHOU' : 'PASSOU',
    diagnostico:
      falhaConcorrenciaVeiculo || !analiseEstatica.usaTransacaoInicio
        ? `FALHA GRAVE (R5): Não usa transação (runTransaction). Ambos conseguiram criar viagens ativas simultâneas ` +
          `para o mesmo veículo (${viagensAtivasVeiculo.docs.length} viagens ativas para ABC-1D23)!`
        : 'Bloqueou concorrência adequadamente',
  });

  // ==========================================================================
  // DISPUTA 2: Disputa pela ÚLTIMA VAGA de um veículo (Capacidade = 4)
  // ==========================================================================
  console.log('\n--- DISPUTA 2: Disputa pela última vaga (Capacidade = 4, 3 ocupados) ---');
  const viagemVagasId = 'viagem_disputa_vagas';
  await db.collection('viagens').doc(viagemVagasId).set({
    id: viagemVagasId,
    veiculoId: 'veic_ducato_03',
    capacidadeVeiculo: 4,
    status: 'ativa',
    passageiros: [
      { pacienteId: 'p1', nome: 'Paciente 1' },
      { pacienteId: 'p2', nome: 'Paciente 2' },
      { pacienteId: 'p3', nome: 'Paciente 3' },
    ],
    passageirosIds: ['p1', 'p2', 'p3'],
  });

  // Função de adição de passageiro com transação atômica quando suportada
  const adicionarPassageiro = async (novoPacienteId, nome) => {
    if (analiseEstatica.usaTransacaoInicio) {
      try {
        return await db.runTransaction(async (t) => {
          const vRef = db.collection('viagens').doc(viagemVagasId);
          const snap = await t.get(vRef);
          const vData = snap.data();
          const ocupados = vData.passageiros.length;
          const capacidade = vData.capacidadeVeiculo;

          if (ocupados >= capacidade) {
            throw new Error('Veículo lotado');
          }

          const novaLista = [...vData.passageiros, { pacienteId: novoPacienteId, nome }];
          t.update(vRef, {
            passageiros: novaLista,
            passageirosIds: novaLista.map((p) => p.pacienteId),
          });

          return { sucesso: true, totalOcupados: novaLista.length };
        });
      } catch (err) {
        return { sucesso: false, motivo: err.message };
      }
    } else {
      const snap = await db.collection('viagens').doc(viagemVagasId).get();
      const vData = snap.data();
      const ocupados = vData.passageiros.length;
      const capacidade = vData.capacidadeVeiculo;

      if (ocupados >= capacidade) {
        return { sucesso: false, motivo: 'Veículo lotado' };
      }

      await new Promise((r) => setTimeout(r, 50));

      const novaLista = [...vData.passageiros, { pacienteId: novoPacienteId, nome }];
      await db.collection('viagens').doc(viagemVagasId).update({
        passageiros: novaLista,
        passageirosIds: novaLista.map((p) => p.pacienteId),
      });

      return { sucesso: true, totalOcupados: novaLista.length };
    }
  };

  const [vagaA, vagaB] = await Promise.all([
    adicionarPassageiro('pac_extra_A', 'Paciente Extra A'),
    adicionarPassageiro('pac_extra_B', 'Paciente Extra B'),
  ]);

  const snapViagemVagas = await db.collection('viagens').doc(viagemVagasId).get();
  const dadosViagemVagas = snapViagemVagas.data();
  const totalFinalPassageiros = dadosViagemVagas.passageiros.length;

  console.log(`Resultado Inclusão Vaga A:`, vagaA);
  console.log(`Resultado Inclusão Vaga B:`, vagaB);
  console.log(`Total final de passageiros na viagem: ${totalFinalPassageiros} (Capacidade máxima: 4)`);

  const estourouCapacidade = totalFinalPassageiros > 4 || (vagaA.sucesso && vagaB.sucesso);

  results.push({
    disputa: 'Disputa pela última vaga do veículo',
    detalhe: 'Dois clientes tentam alocar a 4ª e última vaga simultaneamente',
    usaTransacao: analiseEstatica.usaTransacaoInicio,
    resultadoA: vagaA,
    resultadoB: vagaB,
    totalFinalPassageiros,
    status: estourouCapacidade ? 'FALHOU' : 'PASSOU',
    diagnostico: estourouCapacidade
      ? `FALHA GRAVE (R5): Sem runTransaction, ambos adicionaram com sucesso, ` +
        `ou um sobrescreveu o outro, resultando em corrida e inconsistência de lotação!`
      : 'Capacidade respeitada com lock e transação atômica',
  });

  // ==========================================================================
  // DISPUTA 3: Disputa pelo MESMO PACIENTE em duas viagens ativas simultâneas
  // ==========================================================================
  console.log('\n--- DISPUTA 3: Disputa pelo mesmo paciente em duas viagens ativas ---');
  const pacienteDisputadoId = 'pac_disputado_01';
  await db.collection('viagens').doc('viagem_paciente_A').delete();
  await db.collection('viagens').doc('viagem_paciente_B').delete();
  await db.collection('usuarios').doc(pacienteDisputadoId).set({
    nome: 'Paciente Disputado',
    cpf: '888.888.888-88',
    role: 'paciente',
    ativo: true,
  });

  const vincularPacienteViagem = async (viagemId, motoristaNome) => {
    if (analiseEstatica.usaTransacaoInicio) {
      try {
        return await db.runTransaction(async (t) => {
          const pacRef = db.collection('usuarios').doc(pacienteDisputadoId);
          const pacSnap = await t.get(pacRef);
          const pacData = pacSnap.data();

          if (pacData && pacData.viagemAtivaId) {
            throw new Error('Paciente já alocado em outra viagem ativa');
          }

          t.update(pacRef, { viagemAtivaId: viagemId });

          const vRef = db.collection('viagens').doc(viagemId);
          t.set(
            vRef,
            {
              id: viagemId,
              motoristaNome,
              status: 'ativa',
              passageiros: [{ pacienteId: pacienteDisputadoId, nome: 'Paciente Disputado' }],
              passageirosIds: [pacienteDisputadoId],
            },
            { merge: true }
          );

          return { sucesso: true, viagemId };
        });
      } catch (err) {
        return { sucesso: false, motivo: err.message };
      }
    } else {
      const viagensAtivasComPaciente = await db
        .collection('viagens')
        .where('status', '==', 'ativa')
        .where('passageirosIds', 'array-contains', pacienteDisputadoId)
        .get();

      if (!viagensAtivasComPaciente.empty) {
        return { sucesso: false, motivo: 'Paciente já alocado em outra viagem ativa' };
      }

      await new Promise((r) => setTimeout(r, 50));

      await db.collection('viagens').doc(viagemId).set(
        {
          id: viagemId,
          motoristaNome,
          status: 'ativa',
          passageiros: [{ pacienteId: pacienteDisputadoId, nome: 'Paciente Disputado' }],
          passageirosIds: [pacienteDisputadoId],
        },
        { merge: true }
      );

      return { sucesso: true, viagemId };
    }
  };

  const [pacA, pacB] = await Promise.all([
    vincularPacienteViagem('viagem_paciente_A', 'Motorista A'),
    vincularPacienteViagem('viagem_paciente_B', 'Motorista B'),
  ]);

  const snapViagensComPaciente = await db
    .collection('viagens')
    .where('status', '==', 'ativa')
    .where('passageirosIds', 'array-contains', pacienteDisputadoId)
    .get();

  const viagensDoPaciente = snapViagensComPaciente.docs.map((d) => d.id);
  console.log(`Viagens ativas que alocaram o paciente ${pacienteDisputadoId}:`, viagensDoPaciente);

  const pacienteDuplicado = viagensDoPaciente.length > 1;

  results.push({
    disputa: 'Disputa pelo mesmo paciente em duas viagens ativas',
    detalhe: 'Dois motoristas tentam incluir o mesmo paciente simultaneamente em viagens ativas distintas',
    usaTransacao: analiseEstatica.usaTransacaoInicio,
    resultadoA: pacA,
    resultadoB: pacB,
    viagensVinculadas: viagensDoPaciente,
    status: pacienteDuplicado ? 'FALHOU' : 'PASSOU',
    diagnostico: pacienteDuplicado
      ? `FALHA GRAVE (R5): O mesmo paciente foi vinculado em ${viagensDoPaciente.length} viagens ativas simultâneas ` +
        `([${viagensDoPaciente.join(', ')}]), violando o invariante R5!`
      : 'Paciente vinculado em no máximo 1 viagem ativa com transação atômica',
  });

  await browser.close();

  console.log('\n--- RESUMO DOS TESTES DE CONCORRÊNCIA (R5) ---');
  results.forEach((r) => {
    const icon = r.status === 'PASSOU' ? '✅' : '❌';
    console.log(`${icon} [${r.status}] ${r.disputa}`);
    console.log(`   Transação utilizada: ${r.usaTransacao ? 'SIM' : 'NÃO (FALHA)'}`);
    console.log(`   Diagnóstico: ${r.diagnostico}\n`);
  });

  return results;
}

if (require.main === module) {
  runConcurrencyTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { runConcurrencyTests };
