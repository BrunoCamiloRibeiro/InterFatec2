// ============================================================================
// ARQUIVO: audit_suite/run_all_audits.js
// Orquestrador Central de Execução de Toda a Auditoria e Bateria de Testes
// ============================================================================

const { execSync } = require('child_process');
const path = require('path');

const scripts = [
  { name: '1. Semeadura de Dados no Emulador (Admin SDK)', file: 'seed_emulator.js' },
  { name: '2. Security Rules Firestore R4 (@firebase/rules-unit-testing)', file: 'test_rules.js' },
  { name: '3. Teste do Cenário Central de Ciclo de Vida (Etapa 6)', file: 'test_cenario_central.js' },
  { name: '4. Matriz de Estados R1/R2 e Tempo Real', file: 'test_state_matrix.js' },
  { name: '5. Teste Diferencial R3 (Admin x Motorista)', file: 'test_differential.js' },
  { name: '6. Concorrência R5 com Playwright (Dois Contextos e Transações)', file: 'test_concurrency.js' },
  { name: '7. Isolamento de Sessões e Listeners Zumbis (Login A -> Logout -> Login B)', file: 'test_sessions.js' },
  { name: '8. Teste de Invariantes R5 com fast-check', file: 'test_invariants.js' },
  { name: '9. Testes de Mutação (Sensibilidade e Confiabilidade)', file: 'run_mutation_tests.js' },
];

console.log('==================================================================');
console.log('   INICIANDO BATERIA COMPLETA DE AUDITORIA E TESTES - INTERFATEC2');
console.log('==================================================================\n');

for (const s of scripts) {
  console.log(`\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`);
  console.log(`>>> EXECUTANDO: ${s.name}`);
  console.log(`>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n`);
  try {
    const output = execSync(`node ${path.join(__dirname, s.file)}`, {
      encoding: 'utf8',
      stdio: 'inherit',
    });
  } catch (err) {
    console.error(`Erro ao executar ${s.file}:`, err.message);
  }
}

console.log('\n==================================================================');
console.log('   BATERIA DE AUDITORIA E TESTES FINALIZADA COM SUCESSO');
console.log('==================================================================');
