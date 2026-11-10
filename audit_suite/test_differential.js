// ============================================================================
// ARQUIVO: audit_suite/test_differential.js
// Teste Diferencial (R3): Comparação entre Visão Admin x Visão Motorista
// ============================================================================

const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'trans-saude' });
}

const db = admin.firestore();

/**
 * Simula a extração de passageiros pelo caminho do Administrador:
 * Em lib/screens/gerenciador_viagens_screen.dart:
 * O Admin lê `viagem.passageiros` diretamente do modelo da viagem.
 */
function obterPacientesCaminhoAdmin(viagemData) {
  const passageiros = viagemData.passageiros || [];
  return passageiros.map((p) => ({
    pacienteId: p.pacienteId,
    nome: p.pacienteNome,
    telefone: p.telefone || p.pacienteTelefone || '',
    acompanhante: p.acompanhanteNome || null,
    statusEmbarque: p.statusEmbarque ?? 0,
    origem: p.localOrigem || '',
    destino: p.localDestino || '',
  }));
}

const fs = require('fs');
const path = require('path');

function verificarSeMotoristaUsaFallbackDeUsuarios() {
  const motoristaPath = fs.existsSync(path.resolve(__dirname, '../lib/motorista.dart'))
    ? path.resolve(__dirname, '../lib/motorista.dart')
    : path.resolve(__dirname, '../Projeto/InterFatec2/lib/motorista.dart');
  const content = fs.readFileSync(motoristaPath, 'utf8');
  const carregarStart = content.indexOf('Stream<List<PacienteModel>> carregarPacientes()');
  const carregarBody = content.substring(carregarStart, carregarStart + 1500);
  return carregarBody.includes("role', isEqualTo: 'paciente'");
}

/**
 * Simula a extração de pacientes pelo caminho do Motorista:
 * Em lib/motorista.dart (carregarPacientes()):
 * Se a viagem possui passageiros cadastrados pelo admin, exibe-os.
 * Se vazia:
 *   - Código legado: buscava todos os pacientes de 'usuarios' (Divergência R3)
 *   - Código corrigido: retorna lista vazia coerente com o admin (R3 atendida)
 */
async function obterPacientesCaminhoMotorista(viagemData, todosPacientesDoBanco) {
  const passageiros = viagemData.passageiros || [];

  if (passageiros.length > 0) {
    return passageiros.map((pv) => ({
      pacienteId: pv.pacienteId,
      nome: pv.pacienteNome,
      telefone: pv.acompanhanteTelefone || '',
      acompanhante: pv.acompanhanteNome || null,
      statusEmbarque: pv.statusEmbarque ?? 0,
      origem: pv.localOrigem || '',
      destino: pv.localDestino || '',
    }));
  }

  // Verifica dinamicamente se o código-fonte ainda usa a query de fallback
  if (verificarSeMotoristaUsaFallbackDeUsuarios()) {
    return todosPacientesDoBanco.map((doc) => ({
      pacienteId: doc.id,
      nome: doc.nome,
      telefone: doc.telefone || '',
      acompanhante: doc.nomeAcompanhante || null,
      statusEmbarque: doc.status ?? 0,
      origem: doc.enderecoPaciente || doc.localSaida || '',
      destino: doc.localConsulta || '',
    }));
  }

  // Com a correção da R3, retorna lista vazia coerente com a visão do admin
  return [];
}

async function runDifferentialTests() {
  console.log('=== TESTE DIFERENCIAL (R3): ADMIN x MOTORISTA ===\n');

  // Busca todos os pacientes do banco para simulação da query de fallback do motorista
  const pacientesSnap = await db.collection('usuarios').where('role', '==', 'paciente').get();
  const todosPacientesBanco = pacientesSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

  // Busca todas as viagens no Firestore
  const viagensSnap = await db.collection('viagens').get();
  const viagens = viagensSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

  // Adiciona viagem de teste sem passageiros (ex: viagem criada direto na estrada)
  viagens.push({
    id: 'viagem_sem_passageiros_teste',
    motoristaId: 'Hu2D3HhYLI1v52zy1Ukb',
    motoristaNome: 'maura',
    status: 'ativa',
    passageiros: [],
    passageirosIds: [],
  });

  const results = [];

  for (const v of viagens) {
    const listaAdmin = obterPacientesCaminhoAdmin(v);
    const listaMotorista = await obterPacientesCaminhoMotorista(v, todosPacientesBanco);

    // Comparação de IDs
    const idsAdmin = listaAdmin.map((p) => p.pacienteId).sort();
    const idsMotorista = listaMotorista.map((p) => p.pacienteId).sort();

    const diferencaQtd = idsAdmin.length !== idsMotorista.length;
    const idsDiferentes = JSON.stringify(idsAdmin) !== JSON.stringify(idsMotorista);

    // Comparação de atributos (verificação de corrupção/troca de campos como telefone)
    let discrepanciaCampos = [];
    if (!idsDiferentes) {
      for (let i = 0; i < listaAdmin.length; i++) {
        const pa = listaAdmin[i];
        const pm = listaMotorista[i];
        if (pa.telefone !== pm.telefone) {
          discrepanciaCampos.push(
            `Paciente ${pa.pacienteId}: Admin vê tel="${pa.telefone}", Motorista vê tel="${pm.telefone}" (bug acompanhanteTelefone)`
          );
        }
      }
    }

    const falhou = diferencaQtd || idsDiferentes || discrepanciaCampos.length > 0;

    results.push({
      viagemId: v.id,
      motorista: v.motoristaNome || v.motoristaId,
      statusViagem: v.status,
      qtdAdmin: listaAdmin.length,
      qtdMotorista: listaMotorista.length,
      idsAdmin,
      idsMotorista,
      discrepanciaCampos,
      status: falhou ? 'FALHOU' : 'PASSOU',
      detalhes: falhou
        ? diferencaQtd || idsDiferentes
          ? `Divergência de Passageiros! Admin vê [${idsAdmin.join(', ')}], mas Motorista vê [${idsMotorista.join(', ')}].`
          : `Divergência de Dados nos Passageiros: ${discrepanciaCampos.join('; ')}`
        : 'Listas idênticas',
    });
  }

  console.log('--- RESULTADOS DO TESTE DIFERENCIAL (R3) ---');
  results.forEach((r) => {
    const icon = r.status === 'PASSOU' ? '✅' : '❌';
    console.log(`${icon} [${r.status}] Viagem "${r.viagemId}" (${r.statusViagem})`);
    console.log(`   Qtd Admin: ${r.qtdAdmin} | Qtd Motorista: ${r.qtdMotorista}`);
    console.log(`   Diagnóstico: ${r.detalhes}\n`);
  });

  return results;
}

if (require.main === module) {
  runDifferentialTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { runDifferentialTests };
