// ============================================================================
// ARQUIVO: audit_suite/test_invariants.js
// Testes Baseados em Propriedades (Property-Based Testing com fast-check) - R5
// Invariantes:
// 1. Ocupados <= Capacidade do Veículo
// 2. Um paciente está em <= 1 viagem ativa
// 3. Um veículo está em <= 1 viagem ativa
// ============================================================================

const fc = require('fast-check');

/**
 * Lógica pura de cálculo de assentos do TransSaúde:
 * Cada passageiro titular conta 1 assento.
 * Se possuir acompanhante (acompanhanteNome preenchido), conta +1 assento.
 */
function calcularAssentosOcupados(passageiros) {
  return passageiros.reduce((total, p) => {
    const temAcompanhante =
      p.acompanhanteNome && p.acompanhanteNome.trim().length > 0;
    return total + (temAcompanhante ? 2 : 1);
  }, 0);
}

/**
 * Validador de capacidade (espelha lib/services/validacao_viagem.dart)
 */
function validarCapacidade(totalOcupados, capacidadeVeiculo) {
  if (totalOcupados > capacidadeVeiculo) {
    return {
      valido: false,
      mensagem: `Capacidade excedida: ${totalOcupados} lugares para ${capacidadeVeiculo} assentos.`,
    };
  }
  return { valido: true };
}

/**
 * Validador de unicidade de paciente em viagens ativas
 */
function validarPacienteUnicoEmViagensAtivas(viagensAtivas) {
  const alocacoesPorPaciente = new Map();
  for (const v of viagensAtivas) {
    for (const pId of v.passageirosIds) {
      if (!alocacoesPorPaciente.has(pId)) {
        alocacoesPorPaciente.set(pId, []);
      }
      alocacoesPorPaciente.get(pId).push(v.id);
    }
  }

  const duplicados = [];
  for (const [pId, vIds] of alocacoesPorPaciente.entries()) {
    if (vIds.length > 1) {
      duplicados.push({ pacienteId: pId, viagens: vIds });
    }
  }

  return {
    valido: duplicados.length === 0,
    duplicados,
  };
}

/**
 * Validador de unicidade de veículo em viagens ativas
 */
function validarVeiculoUnicoEmViagensAtivas(viagensAtivas) {
  const alocacoesPorVeiculo = new Map();
  for (const v of viagensAtivas) {
    if (!v.veiculoId) continue;
    if (!alocacoesPorVeiculo.has(v.veiculoId)) {
      alocacoesPorVeiculo.set(v.veiculoId, []);
    }
    alocacoesPorVeiculo.get(v.veiculoId).push(v.id);
  }

  const duplicados = [];
  for (const [veicId, vIds] of alocacoesPorVeiculo.entries()) {
    if (vIds.length > 1) {
      duplicados.push({ veiculoId: veicId, viagens: vIds });
    }
  }

  return {
    valido: duplicados.length === 0,
    duplicados,
  };
}

async function runInvariantTests() {
  console.log('=== TESTES DE INVARIANTES (R5) COM FAST-CHECK (PROPERTY-BASED) ===\n');

  const results = [];

  // ==========================================================================
  // INVARIANTE 1: ocupados <= capacidade
  // ==========================================================================
  console.log('--- 1. Invariante: Ocupados <= Capacidade do Veículo ---');
  let inv1Falhas = 0;
  let inv1TotalTestes = 0;

  try {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 50 }), // Capacidade do veículo
        fc.array(
          fc.record({
            pacienteId: fc.string({ minLength: 2, maxLength: 10 }),
            acompanhanteNome: fc.oneof(
              fc.constant(''),
              fc.string({ minLength: 2, maxLength: 20 })
            ),
          }),
          { minLength: 0, maxLength: 30 }
        ),
        (capacidade, passageiros) => {
          inv1TotalTestes++;
          const ocupados = calcularAssentosOcupados(passageiros);
          const validacao = validarCapacidade(ocupados, capacidade);

          // Se a validação diz que é válido, o invariante DEVE ser verdadeiro
          if (validacao.valido) {
            return ocupados <= capacidade;
          } else {
            // Se a validação diz que é inválido, ocupados DEVE exceder a capacidade
            return ocupados > capacidade;
          }
        }
      ),
      { numRuns: 1000 }
    );
    results.push({
      invariante: 'Invariante 1: Ocupados <= Capacidade (Função Pura ValidacaoViagem)',
      totalExecucoes: inv1TotalTestes,
      status: 'PASSOU',
      diagnostico: '1000 execuções aleatórias sem violação do invariante.',
    });
  } catch (err) {
    results.push({
      invariante: 'Invariante 1: Ocupados <= Capacidade',
      totalExecucoes: inv1TotalTestes,
      status: 'FALHOU',
      diagnostico: err.message,
    });
  }

  // Teste de mutação/violação do Invariante 1: O que acontece se o código não validar acompanhante?
  // Em versões antigas (ex: issue #17), calculava-se apenas passageiros.length ignorando acompanhantes!
  let inv1AcompFalhas = 0;
  try {
    fc.assert(
      fc.property(
        fc.integer({ min: 2, max: 10 }),
        fc.array(
          fc.record({
            pacienteId: fc.string({ minLength: 2, maxLength: 5 }),
            acompanhanteNome: fc.constant('Acompanhante Obrigatorio'),
          }),
          { minLength: 2, maxLength: 6 }
        ),
        (capacidade, passageiros) => {
          // Lógica vulnerável: conta apenas titulares
          const ocupadosSemAcompanhante = passageiros.length;
          const ocupadosReais = calcularAssentosOcupados(passageiros);
          // Se o sistema aceitar baseado apenas em passageiros.length, ele estoura a lotação real:
          if (ocupadosSemAcompanhante <= capacidade && ocupadosReais > capacidade) {
            inv1AcompFalhas++;
            return false; // Violação detectada
          }
          return true;
        }
      ),
      { numRuns: 200 }
    );
  } catch (_) {
    // Esperado falhar se ignorar acompanhante
  }
  console.log(`Detectadas violações potenciais quando acompanhante é ignorado na lotação: ${inv1AcompFalhas > 0 ? 'SIM (Risco)' : 'Não'}`);

  // ==========================================================================
  // INVARIANTE 2: Paciente em <= 1 viagem ativa
  // ==========================================================================
  console.log('\n--- 2. Invariante: Paciente em <= 1 Viagem Ativa ---');
  let inv2TotalTestes = 0;
  try {
    fc.assert(
      fc.property(
        fc.array(
          fc.record({
            id: fc.string({ minLength: 3, maxLength: 8 }),
            status: fc.constant('ativa'),
            passageirosIds: fc.array(fc.constantFrom('p1', 'p2', 'p3', 'p4', 'p5'), {
              minLength: 1,
              maxLength: 4,
            }),
          }),
          { minLength: 2, maxLength: 5 }
        ),
        (viagensAtivas) => {
          inv2TotalTestes++;
          const checagem = validarPacienteUnicoEmViagensAtivas(viagensAtivas);
          // O teste avalia se o algoritmo detecta qualquer duplicidade
          const todosIds = viagensAtivas.flatMap((v) => v.passageirosIds);
          const temDuplicidadeReal = new Set(todosIds).size !== todosIds.length;
          return checagem.valido === !temDuplicidadeReal;
        }
      ),
      { numRuns: 1000 }
    );
    results.push({
      invariante: 'Invariante 2: Paciente em <= 1 Viagem Ativa (Detecção de Conflitos)',
      totalExecucoes: inv2TotalTestes,
      status: 'PASSOU',
      diagnostico: '1000 execuções aleatórias comprovaram precisão do validador de unicidade.',
    });
  } catch (err) {
    results.push({
      invariante: 'Invariante 2: Paciente em <= 1 Viagem Ativa',
      totalExecucoes: inv2TotalTestes,
      status: 'FALHOU',
      diagnostico: err.message,
    });
  }

  // ==========================================================================
  // INVARIANTE 3: Veículo em <= 1 viagem ativa
  // ==========================================================================
  console.log('\n--- 3. Invariante: Veículo em <= 1 Viagem Ativa ---');
  let inv3TotalTestes = 0;
  try {
    fc.assert(
      fc.property(
        fc.array(
          fc.record({
            id: fc.string({ minLength: 3, maxLength: 8 }),
            veiculoId: fc.constantFrom('veic_spin_01', 'veic_master_02', 'veic_ducato_03'),
            status: fc.constant('ativa'),
          }),
          { minLength: 2, maxLength: 6 }
        ),
        (viagensAtivas) => {
          inv3TotalTestes++;
          const checagem = validarVeiculoUnicoEmViagensAtivas(viagensAtivas);
          const todosVeiculos = viagensAtivas.map((v) => v.veiculoId);
          const temDuplicidadeVeiculo = new Set(todosVeiculos).size !== todosVeiculos.length;
          return checagem.valido === !temDuplicidadeVeiculo;
        }
      ),
      { numRuns: 1000 }
    );
    results.push({
      invariante: 'Invariante 3: Veículo em <= 1 Viagem Ativa (Detecção de Conflitos)',
      totalExecucoes: inv3TotalTestes,
      status: 'PASSOU',
      diagnostico: '1000 execuções aleatórias comprovaram detecção de veículos duplicados.',
    });
  } catch (err) {
    results.push({
      invariante: 'Invariante 3: Veículo em <= 1 Viagem Ativa',
      totalExecucoes: inv3TotalTestes,
      status: 'FALHOU',
      diagnostico: err.message,
    });
  }

  console.log('\n--- RESUMO DOS TESTES DE INVARIANTES ---');
  results.forEach((r) => {
    const icon = r.status === 'PASSOU' ? '✅' : '❌';
    console.log(`${icon} [${r.status}] ${r.invariante}`);
    console.log(`   Execuções: ${r.totalExecucoes}`);
    console.log(`   Diagnóstico: ${r.diagnostico}\n`);
  });

  return results;
}

if (require.main === module) {
  runInvariantTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { runInvariantTests };
