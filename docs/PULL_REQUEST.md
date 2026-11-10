# Pull Request: Estabilização do Encerramento Cirúrgico de Viagens, Sincronização em Tempo Real do Paciente e Eliminação de Fallback Fantasma

- **Branch de Origem:** `77-correcao-encerramento-viagem-e-sync-paciente`
- **Branch de Destino:** `develop`
- **Link para Abertura no GitHub:** [Criar Pull Request](https://github.com/BrunoCamiloRibeiro/InterFatec2/pull/new/77-correcao-encerramento-viagem-e-sync-paciente)

---

### Contexto e Objetivo
Refatoração e estabilização do núcleo operacional do TransSaúde (InterFatec2) conectado ao Firebase (Auth + Cloud Firestore), isolando o encerramento cirúrgico de viagens no relatório e garantindo persistência bidirecional em tempo real entre pacientes e motoristas, eliminando encerramentos em lote indesejados de viagens paralelas e impedindo o surgimento de telas em branco ou IDs técnicos de fallback para condutores em turno.

---

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

---

### Verificação e Testes Executados
* **Análise Estática (`flutter analyze`):** 0 erros, 0 avisos.
* **Testes Automatizados Flutter (`flutter test -j 1`):** **299/299 testes aprovados (100% de sucesso)**, incluindo:
  * `test/correcoes_conclusao_homologada_test.dart` (validação de encerramento isolado, fallback automático e persistência de passageiros).
  * `test/screens/motorista_fluxo_inicio_encerramento_test.dart` (fluxo de encerramento individual via interface com relatório).
  * `test/isolamento_sessoes_motoristas_test.dart` (segregação de sessões e frotas de múltiplos motoristas).
  * `test/services/transicao_paciente_service_test.dart` (máquina de estados e precedência física de embarque).
* **Saneamento e Auditoria no Firestore (`trans-saude3`):** Reabertura remota confirmada das viagens operacionais (`Matheus`, `Audrey`, `Hank` e `Heisenberg`) com `status: 'ativa'` e `statusEmbarque: 0`, mantendo estritamente a viagem do `Heitor` com `status: 'encerrada'`.
