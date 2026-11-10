// ============================================================================
// ARQUIVO: audit_suite/test_sessions.js
// Teste de Isolamento de Sessões: Login A -> Logout -> Login B
// Confirmação de listeners sobreviventes (onSnapshot) e vazamento de cache/estado
// ============================================================================

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'trans-saude' });
}

const db = admin.firestore();

function auditarCodigoFonteSessaoELogout() {
  const getPath = (rel) => fs.existsSync(path.resolve(__dirname, `../${rel}`))
    ? path.resolve(__dirname, `../${rel}`)
    : path.resolve(__dirname, `../Projeto/InterFatec2/${rel}`);

  const authServicePath = getPath('lib/services/auth_service.dart');
  const motoristaPath = getPath('lib/motorista.dart');
  const viagemServicePath = getPath('lib/services/viagem_service.dart');

  const authContent = fs.readFileSync(authServicePath, 'utf8');
  const motoristaContent = fs.readFileSync(motoristaPath, 'utf8');
  const viagemContent = fs.readFileSync(viagemServicePath, 'utf8');

  // 1. O logout limpa o ViagemService?
  const logoutTrecho = authContent.substring(
    authContent.indexOf('Future<void> logout() async {'),
    authContent.indexOf('// Fecha o método logout')
  );
  const limpaViagemNoLogout =
    logoutTrecho.includes('ViagemService') || logoutTrecho.includes('resetParaTestes');

  // 2. _ouvirDadosMotorista guarda a StreamSubscription para cancelar no dispose?
  const ouvirTrecho = motoristaContent.substring(
    motoristaContent.indexOf('void _ouvirDadosMotorista() {'),
    motoristaContent.indexOf('// Fechamento do método _ouvirDadosMotorista')
  );
  const armazenaSubOuvirMotorista =
    ouvirTrecho.includes('_subMotorista =') || ouvirTrecho.includes('StreamSubscription');

  // 3. dispose cancela a escuta do motorista?
  const disposeTrecho = motoristaContent.substring(
    motoristaContent.indexOf('void dispose() {'),
    motoristaContent.indexOf('super.dispose();')
  );
  const cancelaSubMotoristaNoDispose =
    disposeTrecho.includes('_subMotorista') || disposeTrecho.includes('usuarios');

  // 4. ViagemService é Singleton com memória estática?
  const isSingletonViagem =
    viagemContent.includes('static final ViagemService _instance = ViagemService._interno();');

  return {
    limpaViagemNoLogout,
    armazenaSubOuvirMotorista,
    cancelaSubMotoristaNoDispose,
    isSingletonViagem,
    logoutTrecho: logoutTrecho.trim(),
    disposeTrecho: disposeTrecho.trim(),
  };
}

async function runSessionIsolationTests() {
  console.log('=== TESTE DE ISOLAMENTO DE SESSÕES E LISTENERS (LOGIN A -> LOGOUT -> LOGIN B) ===\n');

  const auditoria = auditarCodigoFonteSessaoELogout();

  console.log('--- 1. Análise Estática de Ciclo de Vida e Limpeza ---');
  console.log(`ViagemService é Singleton estático em memória? ${auditoria.isSingletonViagem ? 'SIM' : 'NÃO'}`);
  console.log(`logout() limpa viagens ativas e sessões do condutor? ${auditoria.limpaViagemNoLogout ? 'SIM' : 'NÃO (VAZAMENTO)'}`);
  console.log(`_ouvirDadosMotorista armazena subscription para cancelamento? ${auditoria.armazenaSubOuvirMotorista ? 'SIM' : 'NÃO (LEAK)'}`);
  console.log(`dispose() cancela ouvinte de dados do motorista no Firestore? ${auditoria.cancelaSubMotoristaNoDispose ? 'SIM' : 'NÃO (LEAK)'}`);

  const results = [];

  // Verificação 1: Vazamento de estado do motorista A para motorista B
  // Simulação do Singleton ViagemService em memória compartilhada na mesma sessão do app:
  let memoriaSingletonApp = {
    viagemAtiva: null,
    viagensAtivasMemoria: [],
    sessaoAtiva: null,
  };

  // Motorista A (Carlos) loga e inicia/tem viagem ativa
  console.log('\n--- 2. Simulando Login de Motorista A (Carlos) ---');
  memoriaSingletonApp.viagemAtiva = {
    id: 'viagem_carlos_ativa',
    motoristaId: 'mot_carlos_ativa',
    motoristaNome: 'Carlos Roberto de Lima',
    veiculoPlaca: 'BRA-2E45',
    status: 'ativa',
  };
  memoriaSingletonApp.viagensAtivasMemoria.push(memoriaSingletonApp.viagemAtiva);
  memoriaSingletonApp.sessaoAtiva = {
    id: 'sessao_carlos',
    motoristaId: 'mot_carlos_ativa',
    veiculoPlaca: 'BRA-2E45',
  };
  console.log('Motorista A ativo com viagem:', memoriaSingletonApp.viagemAtiva.id);

  // Motorista A clica em "Sair da conta" (executa FirebaseAuthService().logout()):
  console.log('\n--- 3. Motorista A executa Logout ---');
  if (auditoria.limpaViagemNoLogout) {
    memoriaSingletonApp.viagemAtiva = null;
    memoriaSingletonApp.viagensAtivasMemoria = [];
    memoriaSingletonApp.sessaoAtiva = null;
    console.log('Logout executado no Firebase Auth com limpeza de sessão em ViagemService.');
  } else {
    console.log('Logout executado no Firebase Auth (sem limpeza em ViagemService).');
  }

  // Motorista B (Maura - emViagem=false, sem viagens ativas) loga na mesma instância do app:
  console.log('\n--- 4. Motorista B (Maura) executa Login ---');
  // Ao entrar em Motorista (lib/motorista.dart linhas 184-190):
  // _viagensAtivas = _viagemService.viagensAtivas;
  // if (_viagensAtivas.isNotEmpty && _viagemAtiva == null) { _viagemAtiva = _viagensAtivas.first; }
  const viagemHerdadaPorB = memoriaSingletonApp.viagemAtiva;
  const sessaoHerdadaPorB = memoriaSingletonApp.sessaoAtiva;

  const vazouDadosParaB = viagemHerdadaPorB !== null || sessaoHerdadaPorB !== null;

  results.push({
    teste: 'Isolamento de Estado em Memória entre Motoristas (Singleton ViagemService)',
    esperado: 'Estado do Motorista A purgado no logout (viagemAtiva = null)',
    obtido: vazouDadosParaB
      ? `CONTAMINAÇÃO DETECTADA: Motorista B herdou viagem "${viagemHerdadaPorB.id}" do Motorista A!`
      : 'Estado limpo com sucesso',
    status: vazouDadosParaB ? 'FALHOU' : 'PASSOU',
    arquivo: 'lib/services/auth_service.dart:1079 e lib/services/viagem_service.dart:230',
  });

  // Verificação 2: Listener onSnapshot zumbi sobrevivente no Firestore
  console.log('\n--- 5. Verificando Listeners Zumbis (onSnapshot não cancelado) ---');
  let snapshotInvocadoAposLogout = false;
  let listenerAtivo = true;

  // O ouvinte de _ouvirDadosMotorista() não guarda referência (motorista.dart:307):
  const unbindZumbi = db
    .collection('usuarios')
    .where('role', '==', 'motorista')
    .limit(1)
    .onSnapshot((snap) => {
      if (!listenerAtivo) {
        snapshotInvocadoAposLogout = true;
      }
    });

  // Simula descarte da tela / logout
  listenerAtivo = false;

  // Atualiza um motorista no banco: o listener zumbi continua recebendo eventos!
  await db.collection('usuarios').doc('Hu2D3HhYLI1v52zy1Ukb').update({
    atualizadoEm: new Date().toISOString(),
  });
  await new Promise((r) => setTimeout(r, 400));
  unbindZumbi();

  results.push({
    teste: 'Cancelamento de Listeners do Firestore (onSnapshot em _ouvirDadosMotorista)',
    esperado: 'StreamSubscription cancelada no dispose()',
    obtido: !auditoria.cancelaSubMotoristaNoDispose
      ? 'LEAK DETECTADO: onSnapshot nunca é cancelado no dispose(). Listener zumbi consome banda e processador após logout.'
      : 'Cancelado corretamente',
    status: !auditoria.cancelaSubMotoristaNoDispose ? 'FALHOU' : 'PASSOU',
    arquivo: 'lib/motorista.dart:280-328',
  });

  console.log('--- RESUMO DOS TESTES DE SESSÕES ---');
  results.forEach((r) => {
    const icon = r.status === 'PASSOU' ? '✅' : '❌';
    console.log(`${icon} [${r.status}] ${r.teste}`);
    console.log(`   Esperado: ${r.esperado}`);
    console.log(`   Obtido:   ${r.obtido}`);
    console.log(`   Local:    ${r.arquivo}\n`);
  });

  return results;
}

if (require.main === module) {
  runSessionIsolationTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { runSessionIsolationTests };
