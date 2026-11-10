// ============================================================================
// ARQUIVO: audit_suite/test_rules.js
// Teste de Segurança (Etapa 4 e 6): Regras do Firestore (@firebase/rules-unit-testing)
// Cobre para cada ator: um caso permitido e um negado (inclusive paciente após
// a viagem encerrada e tentativa de leitura de outro paciente por LGPD).
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

async function runRulesTests() {
  console.log('=== TESTE DE SECURITY RULES (ETAPA 4 & 6) ===');
  console.log(`Lendo regras de: ${RULES_PATH}`);
  const rules = fs.readFileSync(RULES_PATH, 'utf8');

  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules,
    },
  });

  const results = [];

  // Setup de documentos no Firestore via context admin
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    
    // 1. Administrador
    await db.collection('usuarios').doc('admin_master').set({
      nome: 'Dra. Fernanda Admin',
      cpf: '678.901.234-69',
      role: 'admin',
      ativo: true,
    });

    // 2. Motoristas
    await db.collection('usuarios').doc('motorista_A').set({
      nome: 'Motorista A',
      cpf: '180.879.890-23',
      role: 'motorista',
      ativo: true,
      emViagem: false,
    });

    await db.collection('usuarios').doc('motorista_B').set({
      nome: 'Motorista B',
      cpf: '234.567.890-92',
      role: 'motorista',
      ativo: true,
      emViagem: false,
    });

    // 3. Pacientes (com dados protegidos por LGPD)
    await db.collection('usuarios').doc('paciente_maria').set({
      nome: 'Maria Aparecida',
      cpf: '529.982.247-25',
      telefone: '(17) 99111-2233',
      role: 'paciente',
      ativo: true,
    });

    await db.collection('usuarios').doc('paciente_jose').set({
      nome: 'José Carlos',
      cpf: '345.678.901-75',
      telefone: '(17) 99444-5566',
      role: 'paciente',
      ativo: true,
    });

    // 4. Veículos
    await db.collection('veiculos').doc('veic_spin').set({
      placa: 'ABC-1D23',
      modelo: 'Spin LTZ',
      capacidade: 4,
      emUso: false,
      motoristaAtualId: null,
      quilometragem: 45000,
      ativo: true,
    });

    // 5. Viagens (ativa, aberta e encerrada)
    await db.collection('viagens').doc('viagem_ativa').set({
      destino: 'BARRETOS',
      dataViagem: '2026-11-09',
      status: 'em_andamento',
      codigoAcesso: '5821',
      passageiros: [
        { pacienteId: 'paciente_maria', status: 'a bordo' },
      ],
    });

    await db.collection('viagens').doc('viagem_aberta').set({
      destino: 'RIO PRETO',
      dataViagem: '2026-11-09',
      status: 'aberta',
      codigoAcesso: '1630',
      passageiros: [
        { pacienteId: 'paciente_jose', statusEmbarque: 0 },
      ],
    });

    await db.collection('viagens').doc('viagem_encerrada').set({
      destino: 'RIO PRETO',
      dataViagem: '2026-11-09',
      status: 'encerrada',
      codigoAcesso: '9999',
      passageiros: [
        { pacienteId: 'paciente_jose', status: 'retornou' },
      ],
    });
  });

  // ==========================================================================
  // ATOR 1: ADMINISTRATIVO
  // ==========================================================================
  // Permitido: Admin pode gerenciar veículos
  try {
    const adminCtx = testEnv.authenticatedContext('admin_master');
    const dbAdmin = adminCtx.firestore();
    await assertSucceeds(dbAdmin.collection('veiculos').doc('veic_spin').update({
      quilometragem: 46000,
    }));
    results.push({
      ator: 'ADMIN',
      teste: 'Admin atualizando veículo na frota',
      esperado: 'PERMITIDO',
      obtido: 'PERMITIDO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'ADMIN',
      teste: 'Admin atualizando veículo na frota',
      esperado: 'PERMITIDO',
      obtido: 'FALHOU: ' + err.message,
      status: 'FALHOU',
    });
  }

  // Negado: Exclusão física de usuário é terminantemente proibida (LGPD & SUS)
  try {
    const adminCtx = testEnv.authenticatedContext('admin_master');
    const dbAdmin = adminCtx.firestore();
    await assertFails(dbAdmin.collection('usuarios').doc('paciente_maria').delete());
    results.push({
      ator: 'ADMIN',
      teste: 'Admin tentando exclusão física de usuário (deve proibir; apenas soft delete)',
      esperado: 'NEGADO (assertFails)',
      obtido: 'NEGADO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'ADMIN',
      teste: 'Admin tentando exclusão física de usuário',
      esperado: 'NEGADO (assertFails)',
      obtido: 'PERMITIDO (Falha: exclusão física permitida!)',
      status: 'FALHOU',
    });
  }

  // ==========================================================================
  // ATOR 2: MOTORISTA
  // ==========================================================================
  // Permitido: Motorista atualiza o seu próprio status emViagem
  try {
    const motACtx = testEnv.authenticatedContext('motorista_A');
    const dbMotA = motACtx.firestore();
    await assertSucceeds(dbMotA.collection('usuarios').doc('motorista_A').update({
      emViagem: true,
    }));
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista A atualizando seu próprio emViagem',
      esperado: 'PERMITIDO',
      obtido: 'PERMITIDO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista A atualizando seu próprio emViagem',
      esperado: 'PERMITIDO',
      obtido: 'FALHOU: ' + err.message,
      status: 'FALHOU',
    });
  }

  // Negado: Motorista tentando alterar dados de outro motorista
  try {
    const motACtx = testEnv.authenticatedContext('motorista_A');
    const dbMotA = motACtx.firestore();
    await assertFails(dbMotA.collection('usuarios').doc('motorista_B').get());
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista A tentando ler dados privados de Motorista B',
      esperado: 'NEGADO (assertFails)',
      obtido: 'NEGADO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista A tentando ler dados privados de Motorista B',
      esperado: 'NEGADO (assertFails)',
      obtido: 'PERMITIDO (Falha de isolamento entre motoristas!)',
      status: 'FALHOU',
    });
  }

  // Permitido: Motorista B consulta viagens não encerradas (inclusive 'aberta') com viagem_encerrada no banco
  try {
    const motBCtx = testEnv.authenticatedContext('motorista_B');
    const dbMotB = motBCtx.firestore();
    const snap = await assertSucceeds(
      dbMotB.collection('viagens').where('status', '!=', 'encerrada').get()
    );
    const ids = snap.docs.map((d) => d.id);
    const contemAtiva = ids.includes('viagem_ativa');
    const contemAberta = ids.includes('viagem_aberta');
    const ocultouEncerrada = !ids.includes('viagem_encerrada');
    if (!contemAtiva || !contemAberta || !ocultouEncerrada) {
      throw new Error(`IDs inesperados na consulta: ${ids.join(', ')}`);
    }
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B consulta viagens (status != encerrada) recebendo ativa e aberta',
      esperado: 'PERMITIDO',
      obtido: 'PERMITIDO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B consulta viagens (status != encerrada) recebendo ativa e aberta',
      esperado: 'PERMITIDO',
      obtido: 'FALHOU: ' + err.message,
      status: 'FALHOU',
    });
  }

  // Permitido: Motorista B lê o próprio documento em /usuarios/{uid}
  try {
    const motBCtx = testEnv.authenticatedContext('motorista_B');
    const dbMotB = motBCtx.firestore();
    await assertSucceeds(dbMotB.collection('usuarios').doc('motorista_B').get());
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B lê diretamente seu documento /usuarios/motorista_B',
      esperado: 'PERMITIDO',
      obtido: 'PERMITIDO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B lê diretamente seu documento /usuarios/motorista_B',
      esperado: 'PERMITIDO',
      obtido: 'FALHOU: ' + err.message,
      status: 'FALHOU',
    });
  }

  // Permitido: Motorista B grava sessão em /sessoes_veiculo compatível com SessaoVeiculoModel.toMap()
  try {
    const motBCtx = testEnv.authenticatedContext('motorista_B');
    const dbMotB = motBCtx.firestore();
    await assertSucceeds(
      dbMotB.collection('sessoes_veiculo').doc('sessao_b').set({
        id: 'sessao_b',
        motoristaId: 'motorista_B',
        motoristaNome: 'Motorista B',
        veiculoId: 'veic_spin',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        kmInicial: 45000,
        dataHoraInicio: new Date().toISOString(),
        status: 'ativa',
        viagensIds: ['viagem_ativa', 'viagem_aberta'],
      })
    );
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B grava sessão em /sessoes_veiculo/sessao_b (schema válido)',
      esperado: 'PERMITIDO',
      obtido: 'PERMITIDO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B grava sessão em /sessoes_veiculo/sessao_b (schema válido)',
      esperado: 'PERMITIDO',
      obtido: 'FALHOU: ' + err.message,
      status: 'FALHOU',
    });
  }

  // Permitido: Motorista B grava GPS em /localizacoes_motoristas com campo atualizadoEm
  try {
    const motBCtx = testEnv.authenticatedContext('motorista_B');
    const dbMotB = motBCtx.firestore();
    await assertSucceeds(
      dbMotB.collection('localizacoes_motoristas').doc('motorista_B').set({
        id: 'motorista_B',
        motoristaId: 'motorista_B',
        motoristaNome: 'Motorista B',
        veiculoPlaca: 'ABC-1D23',
        veiculoModelo: 'Spin LTZ',
        cidadeDestino: 'BARRETOS',
        latitude: -20.7389,
        longitude: -49.8217,
        atualizadoEm: new Date().toISOString(),
        emViagem: true,
        viagemId: 'viagem_ativa',
      })
    );
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B grava GPS em /localizacoes_motoristas/motorista_B (atualizadoEm)',
      esperado: 'PERMITIDO',
      obtido: 'PERMITIDO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B grava GPS em /localizacoes_motoristas/motorista_B (atualizadoEm)',
      esperado: 'PERMITIDO',
      obtido: 'FALHOU: ' + err.message,
      status: 'FALHOU',
    });
  }

  // Permitido: Motorista B atualiza passageiros de viagem compartilhada em operação
  try {
    const motBCtx = testEnv.authenticatedContext('motorista_B');
    const dbMotB = motBCtx.firestore();
    await assertSucceeds(
      dbMotB.collection('viagens').doc('viagem_ativa').update({
        passageiros: [
          { pacienteId: 'paciente_maria', status: 'pronto' },
        ],
      })
    );
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B atualiza status de paciente em viagem compartilhada ativa',
      esperado: 'PERMITIDO',
      obtido: 'PERMITIDO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'MOTORISTA',
      teste: 'Motorista B atualiza status de paciente em viagem compartilhada ativa',
      esperado: 'PERMITIDO',
      obtido: 'FALHOU: ' + err.message,
      status: 'FALHOU',
    });
  }

  // ==========================================================================
  // ATOR 3: PACIENTE DE UMA VIAGEM
  // ==========================================================================
  // Permitido: Paciente lê a viagem ativa vinculada ao seu código
  try {
    const pacCtx = testEnv.authenticatedContext('paciente_maria');
    const dbPac = pacCtx.firestore();
    await assertSucceeds(dbPac.collection('viagens').doc('viagem_ativa').get());
    results.push({
      ator: 'PACIENTE',
      teste: 'Paciente lendo viagem ativa/em andamento',
      esperado: 'PERMITIDO',
      obtido: 'PERMITIDO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'PACIENTE',
      teste: 'Paciente lendo viagem ativa/em andamento',
      esperado: 'PERMITIDO',
      obtido: 'FALHOU: ' + err.message,
      status: 'FALHOU',
    });
  }

  // Negado 1 (Requisito Explícito): Paciente após viagem encerrada perde acesso
  try {
    const pacCtx = testEnv.authenticatedContext('paciente_maria');
    const dbPac = pacCtx.firestore();
    await assertFails(dbPac.collection('viagens').doc('viagem_encerrada').get());
    results.push({
      ator: 'PACIENTE',
      teste: 'Paciente tentando ler viagem após encerramento (bloqueio na fonte)',
      esperado: 'NEGADO (assertFails)',
      obtido: 'NEGADO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'PACIENTE',
      teste: 'Paciente tentando ler viagem após encerramento (bloqueio na fonte)',
      esperado: 'NEGADO (assertFails)',
      obtido: 'PERMITIDO (Falha: viagem encerrada ainda exposta ao paciente!)',
      status: 'FALHOU',
    });
  }

  // Negado 2 (Requisito Explícito LGPD): Paciente lendo dados de outro paciente
  try {
    const pacCtx = testEnv.authenticatedContext('paciente_maria');
    const dbPac = pacCtx.firestore();
    await assertFails(dbPac.collection('usuarios').doc('paciente_jose').get());
    results.push({
      ator: 'PACIENTE',
      teste: 'LGPD: Paciente Maria tentando ler dados cadastrais de Paciente José',
      esperado: 'NEGADO (assertFails)',
      obtido: 'NEGADO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'PACIENTE',
      teste: 'LGPD: Paciente Maria tentando ler dados cadastrais de Paciente José',
      esperado: 'NEGADO (assertFails)',
      obtido: 'PERMITIDO (Falha gravíssima de LGPD: paciente leu dado de outro paciente!)',
      status: 'FALHOU',
    });
  }

  // ==========================================================================
  // ATOR 4: NÃO AUTENTICADO
  // ==========================================================================
  // Negado: Usuário não autenticado tentando ler dados de usuários
  try {
    const unauthCtx = testEnv.unauthenticatedContext();
    const dbUnauth = unauthCtx.firestore();
    await assertFails(dbUnauth.collection('usuarios').doc('motorista_A').get());
    results.push({
      ator: 'NÃO AUTENTICADO',
      teste: 'Anônimo tentando ler coleção de usuários',
      esperado: 'NEGADO (assertFails)',
      obtido: 'NEGADO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'NÃO AUTENTICADO',
      teste: 'Anônimo tentando ler coleção de usuários',
      esperado: 'NEGADO (assertFails)',
      obtido: 'PERMITIDO (Falha: leitura sem autenticação permitida!)',
      status: 'FALHOU',
    });
  }

  // Negado: Usuário não autenticado tentando criar veículo
  try {
    const unauthCtx = testEnv.unauthenticatedContext();
    const dbUnauth = unauthCtx.firestore();
    await assertFails(dbUnauth.collection('veiculos').doc('veic_fake').set({
      placa: 'XYZ-9999',
    }));
    results.push({
      ator: 'NÃO AUTENTICADO',
      teste: 'Anônimo tentando criar veículo na frota',
      esperado: 'NEGADO (assertFails)',
      obtido: 'NEGADO',
      status: 'PASSOU',
    });
  } catch (err) {
    results.push({
      ator: 'NÃO AUTENTICADO',
      teste: 'Anônimo tentando criar veículo na frota',
      esperado: 'NEGADO (assertFails)',
      obtido: 'PERMITIDO (Falha: escrita sem autenticação permitida!)',
      status: 'FALHOU',
    });
  }

  await testEnv.cleanup();

  console.log('\n--- RESULTADOS DOS TESTES DE SECURITY RULES ---');
  let totalPassou = 0;
  results.forEach((r, idx) => {
    const icon = r.status === 'PASSOU' ? '✅' : '❌';
    if (r.status === 'PASSOU') totalPassou++;
    console.log(`${icon} [${r.status}] [${r.ator}] ${r.teste}`);
    console.log(`   Esperado: ${r.esperado} | Obtido: ${r.obtido}`);
  });

  console.log(`\nTOTAL: ${totalPassou}/${results.length} testes de regras passaram.`);
  const falhas = results.filter((r) => r.status !== 'PASSOU');
  if (falhas.length > 0) {
    throw new Error(`${falhas.length} teste(s) de regras falharam.`);
  }

  return results;
}

if (require.main === module) {
  runRulesTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { runRulesTests };
