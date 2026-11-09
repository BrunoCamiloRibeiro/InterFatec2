import crypto from 'crypto';

const P3_PROJECT = 'trans-saude3';
const P3_KEY = 'AIzaSyAte0BeHORDNz8vsxogwyh4OPP3DdDkXW0';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${P3_PROJECT}/databases/(default)/documents`;

function sha256Hash(codigo, saltViagem) {
  return crypto.createHash('sha256').update(`${codigo}:${saltViagem}:transsaude_segredo`).digest('hex');
}

async function getDoc(collection, id) {
  const url = `${BASE_URL}/${collection}/${id}?key=${P3_KEY}`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Doc ${collection}/${id} not found: ${res.status}`);
  }
  return await res.json();
}

async function getCollection(collection) {
  const url = `${BASE_URL}/${collection}?pageSize=100&key=${P3_KEY}`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Collection ${collection} fetch error: ${res.status}`);
  }
  const data = await res.json();
  return data.documents || [];
}

async function verify() {
  console.log('=== TESTE DE INTEGRAÇÃO REAL NO TRANS-SAUDE3 ===\n');

  // 1. Coleção usuarios
  console.log('1. Verificando usuarios no Firestore real:');
  const usuarios = await getCollection('usuarios');
  console.log(`   Total de usuários retornados: ${usuarios.length}`);
  if (usuarios.length < 10) throw new Error('Poucos usuários em trans-saude3');

  // Verifica Administrador
  const adminDoc = await getDoc('usuarios', 'admin_principal');
  console.log(`   ✓ Admin Principal: nome="${adminDoc.fields.nome.stringValue}", role="${adminDoc.fields.role.stringValue}", senha="${adminDoc.fields.senha?.stringValue || adminDoc.fields.password?.stringValue}"`);

  // Verifica Motorista Carlos Roberto
  const carlosDoc = await getDoc('usuarios', 'motorista_carlos');
  console.log(`   ✓ Motorista Carlos: nome="${carlosDoc.fields.nome.stringValue}", role="${carlosDoc.fields.role.stringValue}", cnh="${carlosDoc.fields.cnh.stringValue}", senha="${carlosDoc.fields.senha.stringValue}"`);

  // Verifica Motorista Roberto Almeida Prado
  const robertoDoc = await getDoc('usuarios', 'mot_inicial_01');
  console.log(`   ✓ Motorista Roberto: nome="${robertoDoc.fields.nome.stringValue}", role="${robertoDoc.fields.role.stringValue}", cnh="${robertoDoc.fields.cnh.stringValue}", senha="${robertoDoc.fields.senha.stringValue}"`);

  // Verifica Paciente
  const pacDoc = await getDoc('usuarios', 'nhkT53OclKj552MmiMN5');
  console.log(`   ✓ Paciente Sebastião: nome="${pacDoc.fields.nome.stringValue}", cpf="${pacDoc.fields.cpf.stringValue}", role="${pacDoc.fields.role.stringValue}"`);

  // 2. Coleção veiculos
  console.log('\n2. Verificando veiculos no Firestore real:');
  const spinDoc = await getDoc('veiculos', 'spin_01');
  console.log(`   ✓ Spin: modelo="${spinDoc.fields.modelo.stringValue}", placa="${spinDoc.fields.placa.stringValue}", capacidade=${spinDoc.fields.capacidade?.integerValue || spinDoc.fields.capacidade?.stringValue}`);

  const masterDoc = await getDoc('veiculos', 'master_01');
  console.log(`   ✓ Master: modelo="${masterDoc.fields.modelo.stringValue}", placa="${masterDoc.fields.placa.stringValue}", capacidade=${masterDoc.fields.capacidade?.integerValue || masterDoc.fields.capacidade?.stringValue}`);

  const ducatoDoc = await getDoc('veiculos', 'ducato_01');
  console.log(`   ✓ Ducato: modelo="${ducatoDoc.fields.modelo.stringValue}", placa="${ducatoDoc.fields.placa.stringValue}", capacidade=${ducatoDoc.fields.capacidade?.integerValue || ducatoDoc.fields.capacidade?.stringValue}`);

  // 3. Coleção viagens
  console.log('\n3. Verificando viagens no Firestore real:');
  const viagemDoc = await getDoc('viagens', 'viagem_ativa_rio_preto_01');
  const fields = viagemDoc.fields;
  console.log(`   ✓ Viagem Ativa: id="${fields.id.stringValue}", destino="${fields.cidadeDestino.stringValue}", status="${fields.status.stringValue}", motorista="${fields.motoristaNome.stringValue}"`);
  
  // Valida códigos e hashes de acesso dos passageiros
  const codigos = fields.codigosAcesso.mapValue.fields;
  const hashes = fields.codigosHash.mapValue.fields;
  for (const [pacId, codObj] of Object.entries(codigos)) {
    const cod = codObj.stringValue;
    const hashGravado = hashes[pacId].stringValue;
    const hashEsperado = sha256Hash(cod, 'viagem_ativa_rio_preto_01');
    if (hashGravado !== hashEsperado) {
      throw new Error(`Hash inválido para paciente ${pacId}!`);
    }
    console.log(`   ✓ Código de acesso conferido para paciente ${pacId}: código=${cod}, hash SHA-256 válido.`);
  }

  // 4. Coleções sessoes_veiculo e localizacoes_motoristas
  console.log('\n4. Verificando sessoes e telemetria:');
  const sessoes = await getCollection('sessoes_veiculo');
  console.log(`   ✓ Sessões de veículo no Firestore: ${sessoes.length}`);
  const localizacoes = await getCollection('localizacoes_motoristas');
  console.log(`   ✓ Localizações de motoristas no Firestore: ${localizacoes.length}`);

  console.log('\n✅ TODAS AS VERIFICAÇÕES DE INTEGRAÇÃO PASSARAM COM SUCESSO NO FIRESTORE TRANS-SAUDE3!');
}

verify().catch(e => {
  console.error('❌ Falha na verificação:', e);
  process.exit(1);
});
