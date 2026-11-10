# ETAPA 1 — MODELO DE DOMÍNIO E ARQUITETURA DE DADOS (INTERFATEC2)

**Data**: 09/11/2026  
**Documento**: `docs/dominio.md`  
**Autor**: Engenheiro de Software Sênior  
**Projeto**: TransSaúde (InterFatec2)  
**Backend**: Google Firebase (Authentication, Cloud Firestore, Security Rules)

---

## 1. Visão Geral do Domínio

O sistema **TransSaúde** atende à operação de Transporte Sanitário Eletivo (Tratamento Fora de Domicílio - TFD) de um município, conectando três atores principais:
1. **Administrativo**: planeja viagens, cadastra pessoas e veículos, atribui pacientes e supervisiona a frota.
2. **Motorista**: escolhe um veículo livre para a jornada, transporta pacientes de uma ou mais viagens simultâneas, atualiza o status de embarque/desembarque e libera o veículo ao final do percurso.
3. **Paciente / Acompanhante**: acessa sem senha através de código de acesso de 4 a 5 dígitos vinculado à sua viagem, sinaliza prontidão ("Estou pronto"), confirma término de atendimento ("Fui embora") e visualiza a localização em tempo real do condutor.

---

## 2. Três Ciclos de Vida Independentes

O sistema é governado por três máquinas de estado finitas e desacopladas entre si:

```
+-----------------------------------------------------------------------------------+
| 1. CICLO DA VIAGEM                                                                |
|                                                                                   |
|   [ aberta ] -------------> [ em_andamento ] -------------> [ encerrada ]         |
|        |                          |                                               |
|        +--- Primeiro paciente ----+--- SOMENTE quando TODOS retornarem            |
|             vai "a bordo"              (Ação do motorista NUNCA encerra)          |
+-----------------------------------------------------------------------------------+

+-----------------------------------------------------------------------------------+
| 2. CICLO DO MOTORISTA E VEÍCULO (emViagem)                                        |
|                                                                                   |
|   [ LIVRE ] <============================================> [ OCUPADO ]            |
|   emViagem = false                                         emViagem = true        |
|   (Exibe seleção de carro)                                 (Exibe só viagens)     |
|              \                                            /                       |
|               +--- Motorista escolhe carro livre --------+                        |
|               +--- "Finalizar viagem" libera o carro ----+                        |
+-----------------------------------------------------------------------------------+

+-----------------------------------------------------------------------------------+
| 3. CICLO DO PACIENTE NA VIAGEM                                                    |
|                                                                                   |
|   [ aguardando ] ---> [ pronto ] ---> [ a bordo ] ---> [ foi embora ]             |
|          |                                                    |                   |
|          +----------------------------------------------------+                   |
|                                                               |                   |
|                                                               v                   |
|                                                           [ a bordo ]             |
|                                                               |                   |
|                                                               v                   |
|                                                           [ retornou ]            |
+-----------------------------------------------------------------------------------+
```

### 2.1 Ciclo de Vida da Viagem (`viagens`)
- **Estados**:
  - `aberta`: Viagem criada pelo administrativo, com pacientes designados, mas nenhum paciente embarcou ainda.
  - `em_andamento`: Pelo menos um paciente da viagem foi marcado como `a bordo` ou `foi embora`.
  - `encerrada`: **Todos** os pacientes da viagem atingiram o status `retornou`.
- **Tabela de Transições da Viagem**:

| Estado Origem | Evento Disparador | Estado Destino | Regra / Invariante |
| :--- | :--- | :--- | :--- |
| `aberta` | Primeiro paciente marcado como `a bordo` | `em_andamento` | Transição automática calculada em transação atômica. |
| `em_andamento` | Último paciente pendente transiciona para `retornou` | `encerrada` | **SOMENTE quando `count(status != 'retornou') == 0`**. |
| `encerrada` | Ação explícita de reabertura pelo administrador | `em_andamento` | Restrita exclusivamente ao papel administrativo. |

> [!IMPORTANT]
> **Regra de Ouro**: O encerramento da viagem **NUNCA** ocorre por clique do motorista em "Finalizar Viagem". A ação do motorista apenas libera o veículo que ele estava dirigindo (`emViagem = false`). A viagem permanece aberta/em andamento até que o último paciente dela seja deixado em casa com status `retornou`.

---

### 2.2 Ciclo de Vida do Motorista e do Veículo (`emViagem`)
- **Estados do Motorista**:
  - `emViagem == false` (Livre): Motorista autenticado, sem nenhum veículo vinculado no momento.
  - `emViagem == true` (Ocupado): Motorista em posse de um veículo, executando rotas de transporte.
- **Estados do Veículo**:
  - `emUso == false` (Disponível): Veículo estacionado, apto para ser selecionado por qualquer motorista livre.
  - `emUso == true` (Em Uso): Veículo alocado para um motorista específico (`motoristaAtualId == motoristaId`).
- **Regra de Tela do Motorista**:
  - Se `emViagem == false`: A tela exibe **obrigatoriamente o formulário de escolha de veículo**, listando apenas veículos com `emUso == false`.
  - Se `emViagem == true`: A tela exibe **exclusivamente as viagens ativas e a lista de passageiros**.
- **Tabela de Transições de Motorista / Veículo**:

| Estado Atual | Ação | Próximo Estado | Operação Atômica (Transação Firestore) |
| :--- | :--- | :--- | :--- |
| Motorista Livre (`emViagem=false`), Carro Livre (`emUso=false`) | Motorista seleciona veículo e confirma início | Motorista Ocupado (`emViagem=true`), Carro Ocupado (`emUso=true`) | `usuarios/{motoristaId}.emViagem = true` <br> `veiculos/{veiculoId}.emUso = true` <br> `veiculos/{veiculoId}.motoristaAtualId = motoristaId` |
| Motorista Ocupado (`emViagem=true`), Carro Ocupado (`emUso=true`) | Motorista clica em "Liberar Carro / Finalizar" | Motorista Livre (`emViagem=false`), Carro Livre (`emUso=false`) | `usuarios/{motoristaId}.emViagem = false` <br> `veiculos/{veiculoId}.emUso = false` <br> `veiculos/{veiculoId}.motoristaAtualId = null` |

> [!NOTE]
> Se o motorista liberar o carro com pacientes ainda na consulta (`foi embora`) ou aguardando retorno, o veículo fica livre para outro motorista (ou o mesmo motorista no turno seguinte) assumir. A viagem continua aberta!

---

### 2.3 Ciclo de Vida do Paciente na Viagem
- **Estados Estritos**:
  1. `aguardando`: Estado inicial; aguardando embarque no município de origem.
  2. `pronto`: Paciente informou que está pronto para ser recolhido no ponto de encontro/residência.
  3. `a bordo`: Paciente encontra-se fisicamente dentro do veículo em deslocamento.
  4. `foi embora`: Paciente desembarcou no destino médico (clínica/hospital) e foi liberado para atendimento.
  5. `retornou`: Paciente foi reconduzido e desembarcou no município de origem; atendimento concluído.

- **Tabela de Transições do Paciente**:

| Estado Origem | Estado Destino | Atores Permitidos | Significado Operacional |
| :--- | :--- | :--- | :--- |
| `aguardando` | `pronto` | Paciente, Motorista, Admin | Paciente pronto para embarque inicial. |
| `aguardando` | `a bordo` | Motorista, Admin | Motorista chegou e recolheu o paciente direto. |
| `pronto` | `a bordo` | Motorista, Admin | Paciente embarcou para ida. |
| `a bordo` | `foi embora` | Paciente, Motorista, Admin | Paciente desceu no hospital/destino da consulta. |
| `foi embora` | `a bordo` | Motorista, Admin | Motorista recolheu o paciente no hospital para volta. |
| `a bordo` | `retornou` | Motorista, Admin | Paciente entregue em sua residência/cidade. |

---

## 3. Decisão de Arquitetura: Lugares no Veículo e Multi-Viagem

### 3.1 O que são "Lugares" (Resolução de Ambiguidade)
- **Definição Adotada**: Cada veículo possui um número inteiro de assentos (`capacidade: int`, ex.: Spin = 4, Van = 15).
- Um "lugar" é consumido quando um paciente está fisicamente **`a bordo`** do veículo.
- Pacientes com status `aguardando`, `pronto`, `foi embora` ou `retornou` **não consomem lugares** no veículo no instante corrente.
- **Invariante de Concorrência**: O somatório de pacientes com status `a bordo` vinculados ao motorista/veículo ativo nunca pode exceder a `capacidade` do veículo selecionado. Qualquer transição para `a bordo` executa uma transação no Firestore validando essa capacidade.

### 3.2 Suporte a Multi-Viagem e Multi-Motorista
- **Carro com Múltiplas Viagens**: Um motorista com seu veículo pode atender simultaneamente pacientes da "Viagem Barretos - Manhã" e da "Viagem Barretos - Tarde", contanto que a soma a bordo caiba na capacidade do carro.
- **Viagem Compartilhada entre Motoristas**: Uma viagem não pertence a um único motorista. A lista de pacientes da viagem é ouvida via `onSnapshot` por todos os condutores designados. Quando um motorista marca o paciente X como `a bordo`, todos os outros motoristas e o administrativo veem essa alteração imediatamente em tempo real.

---

## 4. Estratégia de Autenticação (Motorista, Administrativo e Paciente)

### 4.1 Login Administrativo e Motorista (CPF + Senha)
- **Desafio Técnico**: O Firebase Authentication não possui provedor nativo baseado em CPF, exigindo e-mail ou número de telefone internacional com SMS.
- **Solução Escolhida**: **E-mail sintético determinístico derivado do CPF**:
  $$\text{email} = \text{sanitizeCPF}(\text{cpf}) + \text{"@transsaude.sp.gov.br"}$$
- **Justificativa Técnica**:
  1. *Sem dependência de backend intermediário*: Dispensou Cloud Functions pagas e custos de SMS do Firebase Phone Auth.
  2. *Compatibilidade e Confiabilidade*: Permite uso direto do SDK client do Firebase (`signInWithEmailAndPassword`) com suporte pleno a Web e Mobile.
  3. *Persistência Robusta*: A sessão persiste nativamente no `IndexedDB` do navegador (`Persistence.LOCAL`), eliminando erros ao recarregar a página (`F5`).
  4. *Segurança Aprimorada*: As senhas passam a residir com hash criptográfico bcrypt dentro do serviço isolado do Firebase Auth, eliminando a falha gravíssima de manter senhas em texto puro no Firestore.

- **Validação de CPF no Cliente e Servidor**:
  - Limpeza de caracteres não numéricos (garantindo exatamente 11 dígitos).
  - Rejeição de CPFs com dígitos repetidos conhecidos (`00000000000`, `11111111111`, etc.).
  - Cálculo e verificação dos 2 dígitos verificadores (módulo 11 oficial da Receita Federal).
  - No Firestore: Security Rules validam o formato `request.resource.data.cpf.matches('^[0-9]{11}$')`.

### 4.2 Acesso do Paciente por Código Numérico (Sem Senha)
- Cada viagem possui um `codigoAcesso` numérico de 4 ou 5 dígitos (ex.: `5821`).
- O paciente informa esse código na tela de login.
- O sistema executa `signInAnonymously()` no Firebase Auth e vincula a sessão do paciente àquela viagem.
- **Bloqueio Garantido por Security Rules**:
  - As regras do Firestore só permitem leitura dos dados da viagem e do paciente se a viagem associada ao código estiver com `status != 'encerrada'`.
  - No exato instante em que o último paciente atinge `retornou` e a viagem passa para `encerrada`, as Security Rules do Firestore **bloqueiam automaticamente qualquer leitura subsequente**, revogando o acesso do paciente na fonte, e não apenas ocultando a interface.

---

## 5. Esquema Mínimo e Normalizado do Firestore

Nenhuma informação é duplicada entre coleções:

```
/usuarios/{userId}
  ├── nome: string
  ├── cpf: string (11 dígitos numéricos limpos)
  ├── email: string (sintético derivado de CPF)
  ├── telefone: string
  ├── role: "admin" | "motorista" | "paciente"
  ├── ativo: bool (soft delete)
  ├── emViagem: bool (apenas motoristas; indica posse de veículo)
  ├── cnh: string? (apenas motoristas)
  └── endereco: string? (apenas pacientes)

/veiculos/{veiculoId}
  ├── placa: string
  ├── modelo: string
  ├── tipo: "carro" | "van" | "ambulancia"
  ├── capacidade: int (assentos)
  ├── quilometragem: int
  ├── emUso: bool
  ├── motoristaAtualId: string? (ID do motorista ocupando)
  └── ativo: bool

/viagens/{viagemId}
  ├── destino: string
  ├── data: string (YYYY-MM-DD)
  ├── horario: string (HH:mm)
  ├── status: "aberta" | "em_andamento" | "encerrada"
  ├── codigoAcesso: string (4 ou 5 dígitos numéricos)
  ├── criadoEm: timestamp
  └── atualizadoEm: timestamp

  └── /pacientes/{pacienteId}  (Subcoleção de pacientes da viagem)
        ├── pacienteId: string (referência a /usuarios/{pacienteId})
        ├── nome: string
        ├── localConsulta: string
        ├── localEmbarque: string
        ├── horarioConsulta: string
        ├── status: "aguardando" | "pronto" | "a bordo" | "foi embora" | "retornou"
        ├── motoristaResponsavelId: string? (motorista que o colocou a bordo)
        └── atualizadoEm: timestamp

/localizacoes_motoristas/{motoristaId}
  ├── motoristaId: string
  ├── motoristaNome: string
  ├── latitude: double
  ├── longitude: double
  ├── atualizadoEm: timestamp
  └── emViagem: bool
```

---

## 6. Mecanismos de Concorrência e Atomicidade

Operações críticas utilizam **Transações Atômicas do Firestore (`runTransaction`)**:
1. **Ocupar Carro**: Lê `veiculos/{id}`. Se `emUso == true`, aborta com erro. Se livre, marca `emUso = true`, vincula motorista e marca `usuarios/{motoristaId}.emViagem = true`.
2. **Liberar Carro**: Marca `usuarios/{motoristaId}.emViagem = false` e `veiculos/{id}.emUso = false`, liberando o veículo sem alterar o status da viagem.
3. **Embarcar Paciente (`a bordo`)**: Lê todos os pacientes atualmente `a bordo` com aquele motorista/veículo. Se `count >= veiculo.capacidade`, rejeita com erro de lotação. Se houver vaga, atualiza status do paciente para `a bordo` e, se a viagem estiver `aberta`, atualiza a viagem para `em_andamento`.
4. **Desembarque Final (`retornou`) e Encerramento de Viagem**: Ao atualizar o status do paciente para `retornou`, a transação consulta o status de todos os demais pacientes daquela viagem. Se nenhum paciente possuir status diferente de `retornou`, o status da viagem é atomicamente atualizado para `encerrada`.
