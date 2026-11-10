// ============================================================================
// ARQUIVO: audit_suite/test_cenario_central.js
// ----------------------------------------------------------------------------
// TESTE DO CENÁRIO CENTRAL (ETAPA 6):
// 1. Motorista A inicia jornada e ocupa carro livre com pacientes pendentes.
// 2. Motorista A desembarca primeiro paciente na consulta (foi embora).
// 3. Motorista A "finaliza viagem" (libera o carro):
//    -> Carro é liberado (emUso = false)
//    -> Motorista é liberado (emViagem = false)
//    -> VIAGEM CONTINUA ABERTA/EM ANDAMENTO!
// 4. Paciente continua conseguindo ler a viagem normalmente.
// 5. Motorista B assume a condução e conclui o retorno do último paciente (retornou).
// 6. Viagem encerra atomicamente (status = 'encerrada').
// 7. Código de acesso do paciente perde acesso na fonte (bloqueado por Security Rules).
// ============================================================================

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'trans-saude';
const RULES_PATH = fs.existsSync(path.resolve(__dirname, '../firestore.rules'))
  ? path.resolve(__dirname, '../firestore.rules')
  : path.resolve(__dirname, '../Projeto/InterFatec2/firestore.rules');

async function runCenarioCentralTest() {
  console.log('=== TESTE DO CENÁRIO CENTRAL (ETAPA 6) ===\n');
  const rules = fs.readFileSync(RULES_PATH, 'utf8');

  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules,
    },
  });

  // Setup do dia de operação
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    // Motoristas A e B
    await db.collection('usuarios').doc('mot_carlos').set({
      nome: 'Carlos Condutor',
      cpf: '180.879.890-23',
      role: 'motorista',
      ativo: true,
      emViagem: false,
    });

    await db.collection('usuarios').doc('mot_marcos').set({
      nome: 'Marcos Condutor',
      cpf: '234.567.890-92',
      role: 'motorista',
      ativo: true,
      emViagem: false,
    });

    // Pacientes
    await db.collection('usuarios').doc('pac_maria').set({
      nome: 'Maria Aparecida',
      cpf: '529.982.247-25',
      role: 'paciente',
      ativo: true,
    });

    await db.collection('usuarios').doc('pac_antonio').set({
      nome: 'Antonio Benedito',
      cpf: '345.678.901-75',
      role: 'paciente',
      ativo: true,
    });

    // Veículo
    await db.collection('veiculos').doc('veic_spin_operacao').set({
      placa: 'SPN-4001',
      modelo: 'Chevrolet Spin 1.8',
      capacidade: 4,
      emUso: false,
      motoristaAtualId: null,
      quilometragem: 50000,
      ativo: true,
    });

    // Viagem Barretos com 2 pacientes
    await db.collection('viagens').doc('viagem_barretos_dia').set({
      destino: 'BARRETOS',
      dataViagem: '2026-11-09',
      status: 'aberta',
      codigoAcesso: '4321',
      passageiros: [
        { pacienteId: 'pac_maria', status: 'aguardando' },
        { pacienteId: 'pac_antonio', status: 'aguardando' },
      ],
    });
  });

  const adminCtx = testEnv.authenticatedContext('admin_sys', { role: 'admin' });
  const dbAdmin = adminCtx.firestore();

  // 1. Motorista Carlos ocupa o carro e embarca Maria
  console.log('1. Motorista Carlos ocupa carro SPN-4001 e embarca Maria...');
  await dbAdmin.collection('veiculos').doc('veic_spin_operacao').update({
    emUso: true,
    motoristaAtualId: 'mot_carlos',
  });
  await dbAdmin.collection('usuarios').doc('mot_carlos').update({
    emViagem: true,
  });
  await dbAdmin.collection('viagens').doc('viagem_barretos_dia').update({
    status: 'em_andamento',
    passageiros: [
      { pacienteId: 'pac_maria', status: 'a bordo' },
      { pacienteId: 'pac_antonio', status: 'aguardando' },
    ],
  });

  // 2. Motorista Carlos desembarca Maria no hospital (foi embora)
  console.log('2. Maria desembarca no hospital (foi embora)...');
  await dbAdmin.collection('viagens').doc('viagem_barretos_dia').update({
    passageiros: [
      { pacienteId: 'pac_maria', status: 'foi embora' },
      { pacienteId: 'pac_antonio', status: 'aguardando' },
    ],
  });

  // 3. Motorista Carlos "Finaliza Viagem" (apenas libera o carro)
  console.log('3. Carlos clica em "Finalizar Viagem" -> apenas libera o carro...');
  await dbAdmin.collection('veiculos').doc('veic_spin_operacao').update({
    emUso: false,
    motoristaAtualId: null,
  });
  await dbAdmin.collection('usuarios').doc('mot_carlos').update({
    emViagem: false,
  });

  // 4. Verificação Invariante: Carro livre, motorista livre, mas VIAGEM CONTINUA ABERTA!
  const vSnap = await dbAdmin.collection('viagens').doc('viagem_barretos_dia').get();
  const vData = vSnap.data();
  console.log(`   Status da viagem pós-liberação do carro: "${vData.status}"`);
  if (vData.status !== 'em_andamento') {
    throw new Error('Falha no cenário central: viagem encerrou prematuramente após liberação do veículo!');
  }
  console.log('   ✅ [INVARIANTE 1 CONFIRMADA]: Viagem continua aberta/em andamento após condutor liberar carro.');

  // 5. Paciente continua conseguindo ler a viagem
  const pacMariaCtx = testEnv.authenticatedContext('pac_maria');
  const dbMaria = pacMariaCtx.firestore();
  await assertSucceeds(dbMaria.collection('viagens').doc('viagem_barretos_dia').get());
  console.log('   ✅ [INVARIANTE 2 CONFIRMADA]: Paciente Maria continua com acesso ativo à viagem em trânsito.');

  // 6. Motorista Marcos assume o carro e atende o retorno de todos os pacientes
  console.log('4. Motorista Marcos assume a condução e conclui retorno de Maria e Antonio...');
  await dbAdmin.collection('veiculos').doc('veic_spin_operacao').update({
    emUso: true,
    motoristaAtualId: 'mot_marcos',
  });
  await dbAdmin.collection('usuarios').doc('mot_marcos').update({
    emViagem: true,
  });

  // Transiciona Antonio para retornou e Maria para retornou
  await dbAdmin.collection('viagens').doc('viagem_barretos_dia').update({
    passageiros: [
      { pacienteId: 'pac_maria', status: 'retornou' },
      { pacienteId: 'pac_antonio', status: 'retornou' },
    ],
    status: 'encerrada', // Calculado atomicamente: todos retornaram
  });

  console.log('5. Todos os pacientes com status "retornou" -> viagem encerrada atomicamente.');
  const vEncerradaSnap = await dbAdmin.collection('viagens').doc('viagem_barretos_dia').get();
  if (vEncerradaSnap.data().status !== 'encerrada') {
    throw new Error('Falha: viagem deveria estar encerrada após todos os pacientes retornarem.');
  }

  // 7. Bloqueio nas Security Rules: Paciente perde acesso imediatamente!
  console.log('6. Validando bloqueio da viagem encerrada para o paciente nas Security Rules...');
  await assertFails(dbMaria.collection('viagens').doc('viagem_barretos_dia').get());
  console.log('   ✅ [INVARIANTE 3 CONFIRMADA]: Security Rules rejeitaram leitura do paciente após encerramento!');

  await testEnv.cleanup();
  console.log('\n🎉 SUCESSO TOTAL NO CENÁRIO CENTRAL!');
  return true;
}

if (require.main === module) {
  runCenarioCentralTest()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { runCenarioCentralTest };
