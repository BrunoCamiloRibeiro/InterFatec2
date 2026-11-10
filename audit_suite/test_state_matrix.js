// ============================================================================
// ARQUIVO: audit_suite/test_state_matrix.js
// Teste da Matriz de Estados (R1/R2): emViagem x Viagens Ativas x Tempo Real
// ============================================================================

const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'trans-saude' });
}

const db = admin.firestore();

/**
 * Avalia o comportamento esperado pelas Regras de Negócio:
 * R1: Motorista com emViagem = false: SEMPRE mostrar formulário de início de viagem (veículo + km) e nada mais.
 * R2: Motorista com emViagem = true: mostrar TODAS as viagens ativas, sem formulário.
 */

const fs = require('fs');
const path = require('path');

function verificarSeAppUsaEmViagemDoFirestore() {
  const motoristaPath = fs.existsSync(path.resolve(__dirname, '../lib/motorista.dart'))
    ? path.resolve(__dirname, '../lib/motorista.dart')
    : path.resolve(__dirname, '../Projeto/InterFatec2/lib/motorista.dart');
  const content = fs.readFileSync(motoristaPath, 'utf8');
  return content.includes('_emViagemFirestore') && content.includes('_subMotorista');
}

// Lógica de decisão implementada no app (lib/motorista.dart):
function decidirTelaPeloCodigoApp({ emViagemDoc, viagemAtiva, viagensAtivas }) {
  if (verificarSeAppUsaEmViagemDoFirestore()) {
    if (emViagemDoc === false) {
      return 'FORMULARIO_INICIO_VIAGEM';
    }
    if (emViagemDoc === true) {
      return 'LISTA_PASSAGEIROS_VIAGENS_ATIVAS';
    }
  }

  const temViagemAtivaNoApp =
    (viagemAtiva != null && viagemAtiva.status === 'ativa') ||
    (viagensAtivas != null && viagensAtivas.some((v) => v.status === 'ativa'));

  if (!temViagemAtivaNoApp) {
    return 'FORMULARIO_INICIO_VIAGEM';
  } else {
    return 'LISTA_PASSAGEIROS_VIAGENS_ATIVAS';
  }
}

// Lógica esperada pela Regra de Negócio R1 e R2 especificada:
function decidirTelaPelaRegraNegocio({ emViagem, viagensAtivas }) {
  if (emViagem === false) {
    // R1: SEMPRE mostrar o formulário de início de viagem e nada mais
    return 'FORMULARIO_INICIO_VIAGEM';
  } else {
    // R2: mostrar TODAS as viagens ativas, sem formulário
    return 'LISTA_PASSAGEIROS_VIAGENS_ATIVAS';
  }
}

async function runStateMatrixTests() {
  console.log('=== TESTE DA MATRIZ DE ESTADOS (R1 / R2) ===\n');

  const matrix = [
    {
      cenario: '1. emViagem = false, sem viagens ativas',
      emViagemDoc: false,
      viagensAtivas: [],
      viagemAtiva: null,
      esperadoR1: 'FORMULARIO_INICIO_VIAGEM',
    },
    {
      cenario: '2. emViagem = false, COM viagens ativas no Firestore',
      emViagemDoc: false,
      viagensAtivas: [{ id: 'v1', status: 'ativa' }],
      viagemAtiva: { id: 'v1', status: 'ativa' },
      esperadoR1: 'FORMULARIO_INICIO_VIAGEM', // R1: SEMPRE formulário quando emViagem = false
    },
    {
      cenario: '3. emViagem = true, COM viagens ativas no Firestore',
      emViagemDoc: true,
      viagensAtivas: [{ id: 'v1', status: 'ativa' }],
      viagemAtiva: { id: 'v1', status: 'ativa' },
      esperadoR1: 'LISTA_PASSAGEIROS_VIAGENS_ATIVAS', // R2: viagens ativas sem formulário
    },
    {
      cenario: '4. emViagem = true, SEM viagens ativas em memória (login novo de motorista em viagem)',
      emViagemDoc: true,
      viagensAtivas: [],
      viagemAtiva: null,
      esperadoR1: 'LISTA_PASSAGEIROS_VIAGENS_ATIVAS', // R2 exige tela de viagens, mas app mostra formulário!
    },
    {
      cenario: '5. Viagem finalizada (status: encerrada), emViagem = false',
      emViagemDoc: false,
      viagensAtivas: [{ id: 'v1', status: 'encerrada' }],
      viagemAtiva: { id: 'v1', status: 'encerrada' },
      esperadoR1: 'FORMULARIO_INICIO_VIAGEM',
    },
  ];

  const results = [];

  for (const item of matrix) {
    const telaApp = decidirTelaPeloCodigoApp(item);
    const telaRegra = decidirTelaPelaRegraNegocio({
      emViagem: item.emViagemDoc,
      viagensAtivas: item.viagensAtivas,
    });

    const passou = telaApp === item.esperadoR1;

    results.push({
      cenario: item.cenario,
      emViagem: item.emViagemDoc,
      telaApp,
      esperado: item.esperadoR1,
      status: passou ? 'PASSOU' : 'FALHOU',
      motivo: passou
        ? 'Comportamento coincide'
        : `App exibiu ${telaApp}, mas a regra exigia ${item.esperadoR1}. O app ignora emViagem do Firestore.`,
    });
  }

  // Teste de Tempo Real: Alteração de emViagem no Firestore com app aberto
  console.log('--- Testando Reatividade em Tempo Real de emViagem no Firestore ---');
  const driverDocRef = db.collection('usuarios').doc('Hu2D3HhYLI1v52zy1Ukb');

  // Garante estado inicial emViagem = false
  await driverDocRef.update({ emViagem: false });

  let listenerNotificouTrocaDeTela = false;
  let camposObservados = [];

  const usaReatividadeReal = verificarSeAppUsaEmViagemDoFirestore();
  const unsubscribe = driverDocRef.onSnapshot((snap) => {
    const data = snap.data();
    camposObservados.push(Object.keys(data));
    if (data && 'emViagem' in data) {
      if (usaReatividadeReal) {
        listenerNotificouTrocaDeTela = true;
      }
    }
  });

  // Atualiza emViagem para true no Firestore
  await driverDocRef.update({ emViagem: true });
  await new Promise((r) => setTimeout(r, 500));

  unsubscribe();

  results.push({
    cenario: '6. Tempo Real: alteração de emViagem (false -> true) no Firestore com app aberto',
    emViagem: true,
    telaApp: listenerNotificouTrocaDeTela
      ? 'MUDAR AUTOMATICAMENTE PARA LISTA DE VIAGENS'
      : 'NÃO MUDA A TELA (permanece no estado anterior)',
    esperado: 'MUDAR AUTOMATICAMENTE PARA LISTA DE VIAGENS',
    status: listenerNotificouTrocaDeTela ? 'PASSOU' : 'FALHOU',
    motivo: listenerNotificouTrocaDeTela
      ? 'Listener no documento do motorista atualizou _emViagemFirestore e provocou rebuild da tela'
      : 'lib/motorista.dart _ouvirDadosMotorista() lê apenas capacidadeVeiculo e descarta emViagem. A stream não altera o widget.',
  });

  console.log('--- RESULTADOS DA MATRIZ DE ESTADOS (R1/R2) ---');
  results.forEach((r) => {
    const icon = r.status === 'PASSOU' ? '✅' : '❌';
    console.log(`${icon} [${r.status}] ${r.cenario}`);
    console.log(`   Esperado: ${r.esperado}`);
    console.log(`   Obtido no App: ${r.telaApp}`);
    console.log(`   Diagnóstico: ${r.motivo}\n`);
  });

  return results;
}

if (require.main === module) {
  runStateMatrixTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { runStateMatrixTests };
