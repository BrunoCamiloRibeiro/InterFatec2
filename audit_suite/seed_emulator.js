// ============================================================================
// ARQUIVO: audit_suite/seed_emulator.js
// Semeia o Firebase Local Emulator Suite com os dados do Passo 1 da Auditoria
// ============================================================================

const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'trans-saude' });
}

const db = admin.firestore();
const auth = admin.auth();

async function cleanCollection(colName) {
  const snap = await db.collection(colName).get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

async function seed() {
  console.log('--- Limpando coleções no Emulador ---');
  await cleanCollection('usuarios');
  await cleanCollection('veiculos');
  await cleanCollection('viagens');

  console.log('--- Semeando Usuários (Motoristas, Admin, Pacientes) ---');

  // Motorista Maura (R1: emViagem = false)
  // Observação da Auditoria: 'senha: 12345' gravada em texto puro no Firestore (falha LGPD)
  // No Firebase Auth, o SDK exige mínimo de 6 caracteres. Usamos '123456' no Auth e '12345' no doc.
  const mauraData = {
    nome: 'maura',
    cpf: '180.879.890-23',
    senha: '12345', // Texto puro no documento (inconsistência / falha de segurança)
    email: '18087989023@transsaude.sp.gov.br',
    telefone: '(17) 99180-8798',
    cnh: '18087989023',
    veiculoModelo: 'Chevrolet Spin 1.8 LTZ',
    veiculoPlaca: 'ABC-1D23',
    capacidadeVeiculo: 4,
    role: 'motorista',
    ativo: true,
    status: 'ativo', // Inconsistência duplicada: ativo (bool) vs status (string)
    emViagem: false,
    criadoEm: new Date().toISOString(),
  };

  await db.collection('usuarios').doc('Hu2D3HhYLI1v52zy1Ukb').set(mauraData);
  try {
    await auth.createUser({
      uid: 'Hu2D3HhYLI1v52zy1Ukb',
      email: '18087989023@transsaude.sp.gov.br',
      password: '123456',
      displayName: 'maura',
    });
  } catch (e) {
    await auth.updateUser('Hu2D3HhYLI1v52zy1Ukb', { password: '123456' });
  }

  // Motorista Carlos (R2: emViagem = true com viagem ativa)
  const carlosData = {
    nome: 'Carlos Roberto de Lima',
    cpf: '234.567.890-92',
    senha: '12345',
    email: '23456789092@transsaude.sp.gov.br',
    telefone: '(17) 99234-5678',
    cnh: '23456789092',
    veiculoModelo: 'Renault Master Minibus',
    veiculoPlaca: 'BRA-2E45',
    capacidadeVeiculo: 15,
    role: 'motorista',
    ativo: true,
    status: 'ativo',
    emViagem: true,
    criadoEm: new Date().toISOString(),
  };

  await db.collection('usuarios').doc('mot_carlos_ativa').set(carlosData);
  try {
    await auth.createUser({
      uid: 'mot_carlos_ativa',
      email: '23456789092@transsaude.sp.gov.br',
      password: '123456',
      displayName: 'Carlos Roberto de Lima',
    });
  } catch (e) {
    await auth.updateUser('mot_carlos_ativa', { password: '123456' });
  }

  // Motorista Marcos (R5: emViagem = true com viagem lotada)
  const marcosData = {
    nome: 'Marcos Pereira da Costa',
    cpf: '345.678.901-75',
    senha: '12345',
    email: '34567890175@transsaude.sp.gov.br',
    telefone: '(17) 99345-6789',
    cnh: '34567890175',
    veiculoModelo: 'Fiat Ducato Ambulância',
    veiculoPlaca: 'POL-3F67',
    capacidadeVeiculo: 4,
    role: 'motorista',
    ativo: true,
    status: 'ativo',
    emViagem: true,
    criadoEm: new Date().toISOString(),
  };

  await db.collection('usuarios').doc('mot_marcos_lotado').set(marcosData);
  try {
    await auth.createUser({
      uid: 'mot_marcos_lotado',
      email: '34567890175@transsaude.sp.gov.br',
      password: '123456',
      displayName: 'Marcos Pereira da Costa',
    });
  } catch (e) {
    await auth.updateUser('mot_marcos_lotado', { password: '123456' });
  }

  // Administrador
  const adminData = {
    nome: 'Dra. Fernanda Vasconcelos',
    cpf: '678.901.234-69',
    email: '67890123469@transsaude.sp.gov.br',
    telefone: '(17) 99789-0123',
    role: 'admin',
    ativo: true,
    status: 'ativo',
    criadoEm: new Date().toISOString(),
  };

  await db.collection('usuarios').doc('usr_admin_master').set(adminData);
  try {
    await auth.createUser({
      uid: 'usr_admin_master',
      email: '67890123469@transsaude.sp.gov.br',
      password: '123456',
      displayName: 'Dra. Fernanda Vasconcelos',
    });
  } catch (e) {
    await auth.updateUser('usr_admin_master', { password: '123456' });
  }

  // Pacientes (com CPFs válidos e prontuários)
  const pacientes = [
    { id: 'pac_01', nome: 'Maria Aparecida dos Santos', cpf: '111.222.333-96', status: 1 },
    { id: 'pac_02', nome: 'José Carlos de Oliveira', cpf: '222.333.444-05', status: 0 },
    { id: 'pac_03', nome: 'Ana Paula Rodrigues', cpf: '333.444.555-08', status: 1 },
    { id: 'pac_04', nome: 'Sebastião Ferreira Lima', cpf: '444.555.666-19', status: 1 },
    { id: 'pac_05', nome: 'Francisca das Chagas', cpf: '555.666.777-20', status: 1 },
    { id: 'pac_06', nome: 'Antonio Benedito', cpf: '666.777.888-30', status: 1 },
    { id: 'pac_07', nome: 'Clara Nunes Pereira', cpf: '777.888.999-41', status: 0 },
  ];

  for (const p of pacientes) {
    await db.collection('usuarios').doc(p.id).set({
      nome: p.nome,
      cpf: p.cpf,
      telefone: '(17) 99000-0000',
      enderecoPaciente: `Rua Paciente ${p.id}, 100`,
      localConsulta: 'Hospital Geral',
      localSaida: 'Residência',
      horarioConsulta: '08:00',
      status: p.status,
      role: 'paciente',
      ativo: true,
      criadoEm: new Date().toISOString(),
    });
  }

  console.log('--- Semeando Veículos ---');
  const veiculos = [
    {
      id: 'veic_spin_01',
      placa: 'ABC-1D23',
      modelo: 'Chevrolet Spin 1.8 LTZ',
      marca: 'Chevrolet',
      tipo: 'carro',
      qtdAssentos: 4,
      capacidade: 4,
      quilometragemAtual: 45280,
      ultimaKmRegistrada: 45280,
      emUso: false,
      status: 'disponivel',
    },
    {
      id: 'veic_master_02',
      placa: 'BRA-2E45',
      modelo: 'Renault Master Minibus',
      marca: 'Renault',
      tipo: 'van',
      qtdAssentos: 15,
      capacidade: 15,
      quilometragemAtual: 82150,
      ultimaKmRegistrada: 82150,
      emUso: true,
      status: 'emViagem',
      motoristaAtualId: 'mot_carlos_ativa',
    },
    {
      id: 'veic_ducato_03',
      placa: 'POL-3F67',
      modelo: 'Fiat Ducato Ambulância',
      marca: 'Fiat',
      tipo: 'ambulancia',
      qtdAssentos: 4,
      capacidade: 4,
      quilometragemAtual: 63250,
      ultimaKmRegistrada: 63250,
      emUso: true,
      status: 'emViagem',
      motoristaAtualId: 'mot_marcos_lotado',
    },
    {
      id: 'veic_onibus_04',
      placa: 'BUS-9K88',
      modelo: 'Mercedes-Benz Sprinter 516',
      marca: 'Mercedes-Benz',
      tipo: 'van',
      qtdAssentos: 20,
      capacidade: 20,
      quilometragemAtual: 110400,
      ultimaKmRegistrada: 110400,
      emUso: false,
      status: 'disponivel',
    },
  ];

  for (const v of veiculos) {
    await db.collection('veiculos').doc(v.id).set(v);
  }

  console.log('--- Semeando Viagens ---');
  const viagens = [
    {
      id: 'viagem_carlos_ativa',
      motoristaId: 'mot_carlos_ativa',
      motoristaNome: 'Carlos Roberto de Lima',
      veiculoId: 'veic_master_02',
      veiculoPlaca: 'BRA-2E45',
      veiculoModelo: 'Renault Master Minibus',
      kmInicial: 82150,
      cidadeDestino: 'SÃO JOSÉ DO RIO PRETO',
      nomeHorario: '07:00 - Rio Preto AME/HB',
      codigoAcesso: '7101',
      dataViagem: new Date().toISOString(),
      dataHoraInicio: new Date().toISOString(),
      status: 'ativa',
      passageiros: [
        {
          pacienteId: 'pac_01',
          pacienteNome: 'Maria Aparecida dos Santos',
          localOrigem: 'Rua A, 100',
          localDestino: 'Hospital de Base',
          ordemEmbarque: 1,
          statusEmbarque: 1,
        },
        {
          pacienteId: 'pac_02',
          pacienteNome: 'José Carlos de Oliveira',
          localOrigem: 'Rua B, 200',
          localDestino: 'AME Rio Preto',
          ordemEmbarque: 2,
          statusEmbarque: 0,
        },
      ],
      passageirosIds: ['pac_01', 'pac_02'],
    },
    {
      id: 'viagem_marcos_lotada',
      motoristaId: 'mot_marcos_lotado',
      motoristaNome: 'Marcos Pereira da Costa',
      veiculoId: 'veic_ducato_03',
      veiculoPlaca: 'POL-3F67',
      veiculoModelo: 'Fiat Ducato Ambulância',
      kmInicial: 63250,
      cidadeDestino: 'BARRETOS',
      nomeHorario: '06:00 - Barretos Hospital de Amor',
      codigoAcesso: '6202',
      dataViagem: new Date().toISOString(),
      dataHoraInicio: new Date().toISOString(),
      status: 'ativa',
      passageiros: [
        {
          pacienteId: 'pac_03',
          pacienteNome: 'Ana Paula Rodrigues',
          localOrigem: 'Rua C, 300',
          localDestino: 'Hospital de Amor',
          ordemEmbarque: 1,
          statusEmbarque: 1,
        },
        {
          pacienteId: 'pac_04',
          pacienteNome: 'Sebastião Ferreira Lima',
          localOrigem: 'Rua D, 400',
          localDestino: 'Hospital de Amor',
          ordemEmbarque: 2,
          statusEmbarque: 1,
        },
        {
          pacienteId: 'pac_05',
          pacienteNome: 'Francisca das Chagas',
          localOrigem: 'Rua E, 500',
          localDestino: 'Hospital de Amor',
          ordemEmbarque: 3,
          statusEmbarque: 1,
        },
        {
          pacienteId: 'pac_06',
          pacienteNome: 'Antonio Benedito',
          localOrigem: 'Rua F, 600',
          localDestino: 'Hospital de Amor',
          ordemEmbarque: 4,
          statusEmbarque: 1,
        },
      ],
      passageirosIds: ['pac_03', 'pac_04', 'pac_05', 'pac_06'],
    },
    {
      // Viagem de Retorno da Tarde (Rio Preto -> Município):
      // Demonstra pac_01 aparecendo em mais de uma viagem no mesmo dia de operação!
      id: 'viagem_retorno_riopreto',
      cidadeDestino: 'SÃO JOSÉ DO RIO PRETO (RETORNO)',
      nomeHorario: '16:30 - Retorno Rio Preto Hospitais',
      codigoAcesso: '1630',
      dataViagem: new Date().toISOString(),
      status: 'aberta',
      veiculoId: 'veic_spin_01',
      veiculoPlaca: 'ABC-1D23',
      veiculoModelo: 'Chevrolet Spin 1.8 LTZ',
      passageiros: [
        {
          pacienteId: 'pac_01',
          pacienteNome: 'Maria Aparecida dos Santos',
          localOrigem: 'Hospital de Base',
          localDestino: 'Residência',
          ordemEmbarque: 1,
          statusEmbarque: 0,
        },
        {
          pacienteId: 'pac_07',
          pacienteNome: 'Clara Nunes Pereira',
          localOrigem: 'AME Rio Preto',
          localDestino: 'Residência',
          ordemEmbarque: 2,
          statusEmbarque: 0,
        },
      ],
      passageirosIds: ['pac_01', 'pac_07'],
    },
    {
      // Viagem de Retorno da Tarde (Barretos -> Município):
      // Demonstra pac_03 e pac_06 também em viagem de retorno!
      id: 'viagem_retorno_barretos',
      cidadeDestino: 'BARRETOS (RETORNO)',
      nomeHorario: '17:00 - Retorno Barretos Hospital de Amor',
      codigoAcesso: '1700',
      dataViagem: new Date().toISOString(),
      status: 'aberta',
      veiculoId: 'veic_onibus_04',
      veiculoPlaca: 'BUS-9K88',
      veiculoModelo: 'Mercedes-Benz Sprinter 516',
      passageiros: [
        {
          pacienteId: 'pac_03',
          pacienteNome: 'Ana Paula Rodrigues',
          localOrigem: 'Hospital de Amor',
          localDestino: 'Residência',
          ordemEmbarque: 1,
          statusEmbarque: 0,
        },
        {
          pacienteId: 'pac_06',
          pacienteNome: 'Antonio Benedito',
          localOrigem: 'Hospital de Amor',
          localDestino: 'Residência',
          ordemEmbarque: 2,
          statusEmbarque: 0,
        },
      ],
      passageirosIds: ['pac_03', 'pac_06'],
    },
    {
      id: 'viagem_finalizada_ontem',
      motoristaId: 'Hu2D3HhYLI1v52zy1Ukb',
      motoristaNome: 'maura',
      veiculoId: 'veic_spin_01',
      veiculoPlaca: 'ABC-1D23',
      veiculoModelo: 'Chevrolet Spin 1.8 LTZ',
      kmInicial: 45000,
      kmFinal: 45280,
      kmRodado: 280,
      cidadeDestino: 'BARRETOS',
      codigoAcesso: '9999',
      status: 'encerrada',
      passageiros: [],
      passageirosIds: [],
    },
  ];

  for (const vi of viagens) {
    await db.collection('viagens').doc(vi.id).set(vi);
  }

  console.log('✅ Dados semeados com sucesso no Local Emulator Suite!');
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Falha ao semear emulador:', err);
    process.exit(1);
  });
