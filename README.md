# 🚑 InterFatec2 (TransSaúde) - Gestão Integrada de Transporte Sanitário

> **Projeto Interdisciplinar - FATEC**  
> Sistema multiplataforma desenvolvido em **Flutter** com backend **Firebase (Cloud Firestore & Authentication)**, concebido para modernizar, digitalizar e dar transparência operacional ao Tratamento Fora de Domicílio (TFD) da saúde pública municipal.

---

## 📋 Sumário
- [1. Visão Geral e Arquitetura do Núcleo](#1-visão-geral-e-arquitetura-do-núcleo)
- [2. Modelo de Domínio e Ciclos de Vida](#2-modelo-de-domínio-e-ciclos-de-vida)
- [3. Modelo de Dados (Firestore NoSQL)](#3-modelo-de-dados-firestore-nosql)
- [4. Decisões Arquiteturais Tomadas](#4-decisões-arquiteturais-tomadas)
- [5. Como Rodar o Projeto Web](#5-como-rodar-o-projeto-web)
- [6. Como Rodar a Suíte Completa de Testes (Comando Único)](#6-como-rodar-a-suíte-completa-de-testes-comando-único)
- [7. Roteiro de Teste Manual Guiado em Tempo Real](#7-roteiro-de-teste-manual-guiado-em-tempo-real)
- [8. Segurança e Conformidade com a LGPD](#8-segurança-e-conformidade-com-a-lgpd)
- [9. Estabilização e Encerramento Cirúrgico de Viagens (PR #77)](#9-estabilização-e-encerramento-cirúrgico-de-viagens-pr-77)

---

## 1. Visão Geral e Arquitetura do Núcleo

O **InterFatec2** informatiza a logística diária de transporte de pacientes da rede pública municipal para consultas, exames especializados e procedimentos de alta complexidade em polos hospitalares regionais (Hospital de Base de São José do Rio Preto, Hospital de Amor de Barretos, etc.).

A aplicação opera sob três camadas rigorosamente desacopladas:
1. **Camada de Dados / Backend (`Firebase`):** Cloud Firestore com escutas reativas (`snapshots()`) de escopo estrito, regras de segurança granulares (`firestore.rules`) e índices compostos (`firestore.indexes.json`).
2. **Camada de Domínio / Regras de Negócio (`lib/services/`):** Transações atômicas ACID (`runTransaction`), validação oficial de CPF (módulo 11 da RFB), gestão de ciclo de vida das viagens e controle de concorrência.
3. **Camada de Interface / Apresentação (`lib/screens/`, `lib/components/`):** UI reativa em Flutter Material 3 com suporte a mobile e desktop web.

---

## 2. Modelo de Domínio e Ciclos de Vida

O sistema opera com **três ciclos de vida estritamente independentes**, garantindo que o encerramento da jornada de um motorista nunca cancele prematuramente a viagem de pacientes que ainda aguardam retorno:

```text
1. Ciclo da Viagem:
   [aberta] ──(motorista embarca passageiro)──> [em_andamento] ──(todos pacientes 'retornou')──> [encerrada]
   * Regra Invariante: O encerramento ocorre EXCLUSIVAMENTE quando todos os pacientes estão com status 'retornou'.
     Nunca por ação direta do motorista.

2. Ciclo do Veículo / Motorista:
   [livre (emViagem=false / emUso=false)] <═══> [ocupado (emViagem=true / emUso=true)]
   * "Finalizar Viagem" do motorista apenas libera o automóvel e o condutor (emViagem=false); não encerra a viagem.
   * Regra de Tela: emViagem=false exibe obrigatoriamente a escolha de veículo; emViagem=true exibe a viagem ativa.

3. Ciclo do Paciente na Viagem:
   [aguardando] ──> [pronto] ──> [a bordo] ──> [foi embora] ──> [retornou]
   * Um veículo pode transportar pacientes de múltiplas viagens simultaneamente.
   * A lista de pacientes da viagem é compartilhada entre todos os motoristas dela em tempo real.
```

---

## 3. Modelo de Dados (Firestore NoSQL)

### Coleção `/usuarios/{userId}`
Armazena motoristas, administradores e dados civis de pacientes:
* `nome`: string (obrigatório, 2..120 caracteres)
* `cpf`: string (obrigatório, 11 dígitos sanitizados, validado pelo módulo 11)
* `telefone`: string (contato do passageiro/motorista)
* `role`: string (`'admin'`, `'motorista'`, `'paciente'`)
* `ativo`: bool (soft delete; exclusão física permanentemente bloqueada)
* `emViagem`: bool (exclusivo para condutores: `false` = livre, `true` = ocupado)

### Coleção `/veiculos/{veiculoId}`
Controle de frota municipal com lock atômico:
* `placa`: string (7..10 caracteres, imutável)
* `modelo`: string (modelo comercial)
* `capacidade`: number (lotação máxima)
* `emUso`: bool (`false` = disponível para seleção, `true` = alocado)
* `motoristaAtualId`: string ou null (UID do motorista com a posse do carro)
* `quilometragem`: number (odômetro atual)
* `ativo`: bool (disponibilidade na frota)

### Coleção `/viagens/{viagemId}`
Registro mestre do itinerário:
* `cidadeDestino` / `destino`: string (polo médico, ex.: `'BARRETOS'`, `'SÃO JOSÉ DO RIO PRETO'`)
* `dataViagem`: string (data do agendamento)
* `status`: string (`'aberta'`, `'em_andamento'`, `'encerrada'`)
* `codigoAcesso`: string (código numérico de 4 a 5 dígitos para login do paciente)
* `passageiros`: array de objetos:
  - `pacienteId`: string
  - `status`: string (`'aguardando'`, `'pronto'`, `'a bordo'`, `'foi embora'`, `'retornou'`)

### Coleção `/localizacoes_motoristas/{motoristaId}`
Telemetria GPS em tempo real:
* `motoristaId`: string (igual a `request.auth.uid`)
* `latitude`: number (-90.0 .. 90.0)
* `longitude`: number (-180.0 .. 180.0)
* `emViagem`: bool (`true` para motoristas com rota em andamento)
* `motoristaNome`, `veiculoPlaca`, `veiculoModelo`: strings de exibição
* `atualizadoEm`: timestamp (TTL de atualização recente para filtrar motoristas inativos)

---

## 4. Decisões Arquiteturais Tomadas

1. **Autenticação Determinística por CPF Sintético:**
   - Como o Firebase Auth não oferece autenticação nativa por CPF, os perfis de motorista e gestor utilizam e-mails sintéticos determinísticos derivados do CPF sanitizado: `<11_digitos_cpf>@transsaude.sp.gov.br`.
   - A validação oficial de CPF (módulo 11 da Receita Federal) é executada antes da emissão do e-mail sintético.
   - Pacientes realizam login **sem senha**, utilizando CPF + Código Numérico de 4 a 5 dígitos emitido para sua viagem.
2. **Resiliência a F5 e Persistência de Sessão:**
   - O `FirebaseAuthService` detecta sessões ativas do Firebase Auth pós-F5 e restaura o perfil a partir de `usuarios/{authUid}` ou via consulta de contingência pelo e-mail sintético do token.
3. **Prevenção de Race Conditions via `runTransaction`:**
   - Toda alocação de veículos (`emUso`), preenchimento de vagas e transições de encerramento utilizam `FirebaseFirestore.instance.runTransaction()`.
   - Se dois motoristas tentarem declarar o mesmo veículo simultaneamente, o Firestore garante que apenas a primeira transação seja comitada, enquanto a segunda falha de imediato com erro de concorrência.
4. **Encerramento Automático em Ponto Único:**
   - A viagem é encerrada unicamente quando o último paciente transiciona para `'retornou'`. Essa verificação é calculada de forma centralizada e atômica.
5. **Bloqueio de Viagem Encerrada na Fonte (Security Rules):**
   - As `firestore.rules` proíbem terminantemente a leitura de viagens com status `'encerrada'` por pacientes, garantindo que o código numérico expire imediatamente após a conclusão da rota.

---

## 5. Como Rodar o Projeto Web

### Pré-requisitos
* **Flutter SDK:** Versão 3.24+ (Canal Stable)
* **Node.js:** Versão 18+ e NPM
* **Firebase CLI:** Instalado ou via `npx firebase-tools`

### Passo 1: Inicializar os Emuladores do Firebase
Na raiz do repositório ou no ambiente de homologação:
```bash
# Iniciar o Firebase Local Emulator Suite (Firestore na porta 8080 e Auth na porta 9099)
npx firebase-tools emulators:start --only auth,firestore
```

### Passo 2: Executar a Aplicação Web em Flutter
Em outro terminal:
```bash
# Obter dependências do Flutter
flutter pub get

# Rodar no Chrome com renderer CanvasKit ou HTML
flutter run -d chrome --web-port=3000
```

---

## 6. Como Rodar a Suíte Completa de Testes (Comando Único)

Todo o ecossistema de testes pode ser executado através de comandos padronizados:

### 1. Testes de Integração, Concorrência e Regras (Node.js / Emuladores)
Executa em sequência: semeadura de dados no emulador (`seed`), testes de security rules (@firebase/rules-unit-testing), teste do cenário central de ciclo de vida e concorrência multissessão com Playwright:
```bash
# Executa a verificação completa no Firebase Emulator Suite
npm test
```

Também é possível executar etapas específicas da auditoria:
* `npm run test:rules` — Validação das Security Rules para os 4 atores e LGPD (14/14 testes passando, incluindo consultas de viagens não encerradas e sessão multi-motorista)
* `npm run test:cenario` — Teste do Cenário Central (liberação de carro com viagem aberta, retorno e corte de acesso)
* `npm run test:concurrency` — Disputa concorrente por veículo, vaga e paciente com transações atômicas

### 2. Testes Unitários e de Widgets (Flutter)
```bash
flutter test -j 1
```
* **298/298 testes passando** com 100% de sucesso (incluindo testes de widget, auth, isolamento entre sessões de motoristas, visibilidade multi-motorista de viagens operacionais, responsividade em tela 320x568 e validações de CPF).

---

## 7. Roteiro de Teste Manual Guiado em Tempo Real

Para homologar a sincronização em tempo real entre diferentes atores, abra três janelas/abas distintas do navegador:

### Cenário de Teste: Operação Multi-Motorista com Viagem Compartilhada

#### Preparação
Execute o seed inicial:
```bash
npm run seed
```

#### Janela 1: Motorista 1 (Carlos - Minibus BRA-2E45)
1. Acesse `http://localhost:3000`.
2. Efetue login com o CPF do motorista: `234.567.890-92` e senha `123456`.
3. Selecione o veículo disponível `Renault Master Minibus` e inicie a rota.
4. Na lista de passageiros, localize a paciente **Maria Aparecida** e registre o embarque dela (status transiciona para **a bordo**).
5. Desembarque Maria no hospital (status transiciona para **foi embora**).
6. Clique no botão de encerramento da jornada do motorista:
   - Confirme a liberação do carro.
   - Observe que o carro `BRA-2E45` é liberado (`emUso = false`), mas a **Viagem continua em andamento**.

#### Janela 2: Paciente (Maria Aparecida - Código de Acesso da Viagem)
1. Em aba anônima, acesse `http://localhost:3000`.
2. No formulário de paciente, informe o CPF `111.222.333-96` e o Código de Acesso `7101`.
3. Observe que o mapa carrega a posição geográfica ao vivo do motorista Carlos enquanto ele estava em rota.
4. Quando Maria sai da consulta, ela clica no botão **"Estou Pronto"** para o retorno.

#### Janela 3: Motorista 2 (Maura - Spin ABC-1D23)
1. Em outra aba/navegador, acesse `http://localhost:3000`.
2. Efetue login com o CPF `180.879.890-23` e senha `123456`.
3. Escolha o veículo `Chevrolet Spin` e acerte a rota.
4. **Confirmação de Tempo Real:** A sinalização de Maria Aparecida como "pronta" aparece instantaneamente na tela da Maura, sem necessidade de recarregar a página!
5. Maura embarca Maria para volta (**a bordo**) e conclui o retorno (**retornou**).
6. Quando o último paciente da viagem é marcado como **retornou**, a viagem muda automaticamente seu status para **encerrada**.
7. Na Janela 2 (Paciente), tente atualizar ou consultar a viagem: o acesso é **bloqueado de imediato** pelas regras de segurança (`PERMISSION_DENIED`), comprovando o corte de acesso do código.

---

## 8. Segurança e Conformidade com a LGPD

* **Menor Privilégio:** Pacientes autenticados via código numérico têm permissão de leitura restrita à sua própria viagem ativa (`viagens/{viagemId}`). É expressamente proibido a um paciente ler cadastros de outros munícipes na coleção `/usuarios`.
* **Isolamento de Motoristas:** Motoristas possuem permissão para ler perfis com `role == 'paciente'`, mas não podem ler dados cadastrais privados de outros motoristas.
* **Proibição de Exclusão Física:** Todas as entidades do sistema implementam exclusão lógica (`ativo: false`). Tentativas de exclusão física (`delete`) são sumariamente rejeitadas pelas Security Rules (`allow delete: if false;`).
* **Proteção contra Recursão de Regras:** A função de autorização do administrador avalia claims do token JWT antes de executar consultas ao Firestore, garantindo tempo de resposta O(1) e eliminando riscos de estouro de pilha na avaliação de regras.

---

## 9. Estabilização e Encerramento Cirúrgico de Viagens (PR #77)

### Contexto e Objetivo
Refatoração e estabilização do núcleo operacional do TransSaúde (InterFatec2) conectado ao Firebase (Auth + Cloud Firestore), isolando o encerramento cirúrgico de viagens no relatório e garantindo persistência bidirecional em tempo real entre pacientes e motoristas, eliminando encerramentos em lote indesejados de viagens paralelas e impedindo o surgimento de telas em branco ou IDs técnicos de fallback para condutores em turno.

### Principais Alterações

#### Encerramento Cirúrgico e Isolamento de Viagens no Relatório (`lib/services/viagem_service.dart`, `lib/components/formulario_encerramento.dart`, `lib/components/footer_pacientes.dart`)
* **Isolamento de Escopo em `obterViagensParaRelatorio`:** Quando informado `viagemUnica` ou `viagensExplicitas`, o relatório restringe-se **estritamente** à viagem em foco, cessando o vazamento de viagens ativas da memória global (`_viagensAtivasMemoria`) que causava o fechamento de múltiplos horários simultâneos.
* **Transição Atômica de Ciclo de Vida:** Persistência pontual em `/viagens/{viagemId}` com `status: 'encerrada'`, `motoristaEncerramentoId`, `dataHoraFim`, `kmFinal`, `kmRodado` e consolidação automática de passageiros pendentes (`statusEmbarque < 4` -> `4`).
* **Preservação da Sessão Operacional e do Veículo:** Avaliação de `aindaRestamOutrasViagensAtivas`. Ao encerrar uma viagem isolada, caso restem outros horários ativos para a frota/sessão, o condutor e o veículo permanecem operacionais (`forcarLiberacaoSessao: false`), avançando de imediato para a próxima viagem da fila sem derrubar o segundo motorista.

#### Sincronização em Tempo Real e Persistência do Paciente (`lib/paciente.dart`, `lib/services/auth_service.dart`)
* **Remoção de Bloqueio Local:** Removido o parâmetro `persistirRemoto: false` dos botões *"Fui embora"* (`status: 5`) e *"Estou Pronto"* (`status: 2`), garantindo gravação remota direta no documento da viagem no Firestore sob `FieldValue.serverTimestamp()`.
* **Resiliência de Sessão e Escuta LGPD:** Fallback determinístico para `pacienteViagemId` quando `auth.currentUser` ainda não estiver instanciado no ciclo anônimo, notificando instantaneamente a tela do motorista via Snapshot Listener.

#### Precedência Física e Desbloqueio de Swipe (`lib/motorista.dart`)
* **Retomada de Embarque Pós-Desistência:** Habilitado o gesto de swipe (`Dismissible`) para passageiros com `status == 5` (Carona / Cancelamento) transicionando de volta para `status == 1` (Embarcado Ida), espelhando as regras de transição de `TransicaoPacienteService` quando o paciente embarca fisicamente após cancelar por equívoco.

#### UX de Fallback e Estado Vazio Amigável (`lib/motorista.dart`)
* **Eliminação de IDs Técnicos:** O `MotoristaHeader` não exibe mais a string técnica `Viagem sessao_ativa_<veiculoId>`, exibindo `'Sem Viagens Ativas'` quando não houver viagens operacionais em andamento.
* **Componente de Estado Vazio (`_construirEstadoVazioViagem`):** Substitui a tela branca vazia por um card informativo estruturado com ícone, orientando o motorista de que novas viagens cadastradas pelo setor administrativo surgirão automaticamente na tela.
* **Priorização de Viagens Reais:** A stream de escuta prioriza viagens reais do banco e só recorre ao placeholder de sessão se rigorosamente não houver nenhuma viagem operacional no sistema.

#### Regras de Segurança e Integridade (`firestore.rules`)
* Liberação controlada do atributo `motoristaEncerramentoId` na validação `isValidViagem`.
* Permissão para pacientes autenticados atualizarem atomicamente `['passageiros', 'atualizadoEm']` em viagens não encerradas.
* Permissão para motoristas registrarem snapshots imutáveis de encerramento na coleção de auditoria `/viagens_homologadas`.

### Verificação e Testes Executados
* **Análise Estática (`flutter analyze`):** 0 erros, 0 avisos.
* **Testes Automatizados Flutter (`flutter test -j 1`):** **298/298 testes aprovados (100% de sucesso)**, incluindo:
  * `test/correcoes_conclusao_homologada_test.dart` (validação de encerramento isolado, fallback automático e persistência de passageiros).
  * `test/screens/motorista_fluxo_inicio_encerramento_test.dart` (fluxo de encerramento individual via interface com relatório).
  * `test/isolamento_sessoes_motoristas_test.dart` (segregação de sessões e frotas de múltiplos motoristas).
  * `test/services/transicao_paciente_service_test.dart` (máquina de estados e precedência física de embarque).
* **Saneamento e Auditoria no Firestore (`trans-saude3`):** Reabertura remota confirmada das viagens operacionais (`Matheus`, `Audrey`, `Hank` e `Heisenberg`) com `status: 'ativa'` e `statusEmbarque: 0`, mantendo estritamente a viagem do `Heitor` com `status: 'encerrada'`.
