# ETAPA 0 — LEVANTAMENTO COMPLETO DE ARQUITETURA E CÓDIGO (INTERFATEC2)

**Data**: 09/11/2026  
**Engenheiro**: Engenheiro de Software Sênior  
**Repositório**: `BrunoCamiloRibeiro/InterFatec2`  
**Branch de Trabalho**: `refactor/nucleo-firebase` (derivada de `develop`)  
**Backend**: Google Firebase (Authentication, Cloud Firestore, Hosting, Local Emulator Suite)

---

## 1. Execução e Diagnóstico da Versão Web

### 1.1 Comandos Executados e Resultados
1. **Instalação de Dependências (`flutter pub get`)**:
   - Executado com sucesso.
   - Foram resolvidas todas as dependências declaradas em `pubspec.yaml` (Firebase Core 4.15.0, Firebase Auth 6.7.0, Cloud Firestore 6.10.0, Geolocator 14.0.3, PDF 3.13.1, Flutter Map 8.3.2, etc.).
   - Identificados 33 pacotes com atualizações disponíveis, porém compatíveis com as travas do projeto.

2. **Compilação Web (`flutter build web`)**:
   - Compilação concluída com sucesso (`✓ Built build/web` em 83.6s).
   - **Alertas observados**:
     - *Aviso de fontes ausentes*: "Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons)". O projeto referencia ícones de Cupertino sem declarar o pacote no `pubspec.yaml`.
     - *Tree-shaking de fontes*: Fonte `MaterialIcons-Regular.otf` reduzida em 98.7%.

3. **Execução da Suíte de Testes Existente (`flutter test`)**:
   - 272 testes executados; **todos os 272 testes passaram**.
   - **Alertas observados durante a execução**:
     - Falta de ferramentas de compilação C/C++ nativas para Linux (`clang`, `ninja`, `cmake`, `libgtk-3-dev`) informadas pelo Flutter snap, o que impede a compilação do runner desktop Linux nativo (mas não afeta a web).
     - Alertas do pacote `pdf`: "Helvetica-Bold has no Unicode support" durante os testes do gerador de PDF de viagem.

4. **Análise Estática Oficial (`dart analyze`)**:
   - `No issues found!` com base no `analysis_options.yaml` configurado.

5. **Disponibilidade do Firebase CLI**:
   - O comando binário global `firebase` não estava exportado no `$PATH` da máquina, mas o comando `npx firebase-tools` (versão 15.35.0) está plenamente funcional e responde à emulação local e deploy.

---

## 2. Histórico do Repositório (Git Log) e Branches Abertas

### 2.1 Situação das Branches Principais
- **`main`**: Em 25/09/2026, no commit `8a39784` ("chore: zerar branch main aguardando primeira release"), todos os arquivos de código (`lib/`, `pubspec.yaml`, `android/`, etc.) foram removidos para aguardar a primeira entrega formal. A árvore da branch `main` encontra-se vazia.
- **`develop`**: É a verdadeira linha-tronco ativa de desenvolvimento. Nela convergiram todos os Pull Requests das Sprints 1 a 3 (último commit: `079169d Merge pull request #75 from BrunoCamiloRibeiro/75-correcao-roteamento-sessao-e-senhas-firestore`).
- **Decisão Técnica**: Por determinação da instrução ("Não confie nesta descrição como verdade sobre o código: confirme tudo lendo o repositório e os dados reais"), a branch de trabalho para refatoração do núcleo (`refactor/nucleo-firebase`) foi criada com base no commit mais recente e íntegro do código ativo (`develop`), garantindo que nenhum trabalho anterior seja perdido.

### 2.2 Branches Locais e Remotas Mapeadas
1. `16-gerar-o-pdf` / `remotes/origin/16-gerar-o-pdf`: Desenvolvimento inicial do módulo gerador de PDF de roteiro de viagem.
2. `17-formulário-de-viagem` / `remotes/origin/17-formulário-de-viagem`: Formulário inicial de abertura de viagem. Integrada em `develop`.
3. `61-documentação-código-1`: Documentação de cabeçalhos de arquivos e arquitetura.
4. `65-correção-de-bugs` / `68-correção-de-bugs-2` / `70-correção-de-bugs-3`: Ciclos sucessivos de resolução de concorrência, suporte a N viagens ativas para motoristas, Zero-Wait UI e telemetria GPS.
5. `ID01---Footer-da-lista-de-pacientes` / `ID01--#12-estados-de-cor-dos-cards` / `ID01---49-id-01---card-de-pacientes-na-tela-do-motorista`: Desenvolvimento dos cards de passageiro e seus estados visuais na tela do condutor.
6. `ID03---33-crud-de-veiculos`: CRUD de veículos e gestão de frotas (PR #63).
7. `ID04---27-tela-de-gerenciamento-da-grade-de-viagens`: Tela do administrador para alocação de viagens.
8. `feat/34-crud-de-pessoas` / `feat/gestao-pessoas`: Gestão administrativa de pessoas (PR #64).
9. `feat/19-backend-botoes-tela-paciente`: Ações do paciente na tela mobile ("Estou Pronto" e "Fui Embora").
10. `feat/auth-diferenciacao-usuario` / `feat/auth-login-motorista-admin`: Roteamento por papéis (RBAC) e telas de autenticação.
11. `chore/limpeza-debug-firebase`: Experimentos locais de desacoplamento de listeners zumbis.

---

## 3. Inventário do Código Existente

### 3.1 Telas (`lib/screens/` e telas na raiz de `lib/`)
| Arquivo | Rota Oficial | Papel / Descrição |
| :--- | :--- | :--- |
| `lib/screens/auth_gate.dart` | `/`, `/auth-gate` | Guardião reativo que escuta o estado de autenticação do Firebase Auth e o perfil no Firestore para rotear o usuário. |
| `lib/screens/login_screen.dart` | `/login`, `/login-paciente` | Tela unificada com duas abas: Motorista/Admin (CPF/Email e Senha) e Paciente (Código numérico de 4 dígitos). |
| `lib/motorista.dart` | `/motorista`, `/lista-passageiros` | Painel do motorista. Se `emViagem == false`, exibe formulário de início; se `emViagem == true`, exibe N viagens ativas com lista de passageiros e cards expansíveis. |
| `lib/paciente.dart` | `/paciente` | Painel do paciente identificado via código de acesso. Exibe dados do agendamento, botões "Estou pronto" e "Foi embora", e mapa com localização dos motoristas. |
| `lib/screens/gerenciador_viagens_screen.dart` | `/gerenciador-viagens` | Painel do administrador para criação, listagem, filtros, alocação de passageiros e exportação de PDF de viagens. |
| `lib/lista_pessoas.dart` | `/lista-pessoas`, `/crud-pessoas` | CRUD administrativo de pessoas (motoristas, administradores e pacientes) com filtros, busca e soft delete. |
| `lib/lista_veiculos.dart` | `/veiculos`, `/lista-veiculos` | CRUD administrativo de veículos com cartões de status e filtros modais. |
| `lib/detalhes_veiculo.dart` | Aberto via navegação direta | Exibição detalhada de odômetro, histórico e dados de um veículo específico. |
| `lib/screens/admin_placeholder_screen.dart` | Rotas de rascunho | Tela provisória para rotas administrativas em desenvolvimento. |

### 3.2 Serviços (`lib/services/`)
- `lib/services/auth_service.dart`: Autenticação mista. Login com Firebase Auth para motorista/admin, login de paciente via consulta direta por código na coleção `viagens` (guardando ID em memória estática), logout e cache estático de perfis.
- `lib/services/viagem_service.dart`: Monólito de mais de 2.000 linhas de código que acumula gerenciamento em memória (`_viagensAtivasMemoria`, `_todasViagensMemoria`), escritas no Firestore, geração e disparo de PDFs, lógica de encerramento e fallback offline.
- `lib/services/pessoa_service.dart`: Operações CRUD para a coleção `usuarios` com regras de soft delete (`ativo: false`).
- `lib/services/localizacao_motorista_service.dart`: Captura de GPS via `geolocator`, throttle de 200m/60s e gravação em `localizacoes_motoristas/{motoristaId}`.
- `lib/services/codigo_acesso_service.dart`: Algoritmo gerador e validador de códigos de acesso de 4 dígitos para viagens.
- `lib/services/transicao_paciente_service.dart`: Transições de status de passageiro com fila de reversão/rollback otimista.
- `lib/services/paciente_sync_service.dart`: Sincronizador de dados entre a subestrutura da viagem e o documento raiz do paciente.
- `lib/services/validacao_viagem.dart`: Métodos estáticos para validação de capacidade, veículos livres e campos obrigatórios.
- `lib/services/relatorio_pdf_service.dart`: Renderização vetorial em isolate do roteiro da viagem para PDF.

### 3.3 Regras de Segurança e Backend
- `firestore.rules`: Contém validações básicas para a coleção `usuarios`, porém as coleções `viagens`, `veiculos`, `sessoes_veiculo` e `localizacoes_motoristas` possuem regras totalmente abertas (`allow read, write: if isAuthenticated() || !isAuthenticated();`), permitindo leituras e escritas anônimas e irrestritas.
- `firebase.json`: Configura hospedagem web e os emuladores locais de Auth (porta 9099), Firestore (porta 8080) e UI (porta 4000).
- **Cloud Functions**: Inexistentes no repositório. Toda a lógica de negócios e cálculos é atualmente executada no cliente.

---

## 4. Mapa Completo do Firestore (Leitores e Escritores)

| Coleção | Campos Principais | Quem Lê | Quem Escreve | Problemas Identificados |
| :--- | :--- | :--- | :--- | :--- |
| `usuarios` | `nome`, `cpf`, `senha`, `email`, `telefone`, `role` (`admin`, `motorista`, `paciente`), `ativo`, `status`, `emViagem`, `cnh`, `veiculoModelo`, `veiculoPlaca`, `capacidadeVeiculo`, `enderecoPaciente`, `localConsulta`, `localSaida`, `horarioConsulta`, `criadoEm` | `AuthGate`, `FirebaseAuthService`, `PessoaService`, `Motorista`, `Paciente`, `GerenciadorViagensScreen`, `ListaPessoas` | `PessoaService`, `FirebaseAuthService`, `ViagemService`, `FormularioPessoa` | **Falha Grave de LGPD**: senhas gravadas em texto puro no Firestore. Atributo do veículo duplicado no cadastro do motorista. Duplicação de flags (`ativo: bool` e `status: 'ativo'`). |
| `veiculos` | `id`, `placa`, `modelo`, `marca`, `tipo`, `qtdAssentos`, `capacidade`, `quilometragemAtual`, `ultimaKmRegistrada`, `emUso`, `status` (`disponivel`, `emViagem`), `motoristaAtualId` | `VeiculoController`, `GerenciadorViagensScreen`, `Motorista`, `ViagemService` | `VeiculoController`, `ViagemService` | Duplicação de campos (`qtdAssentos` vs `capacidade`, `emUso` vs `status`, `quilometragemAtual` vs `ultimaKmRegistrada`). Falta de transação atômica ao ocupar veículo. |
| `viagens` | `id`, `motoristaId`, `motoristaNome`, `veiculoId`, `veiculoPlaca`, `veiculoModelo`, `kmInicial`, `kmFinal`, `cidadeDestino`, `nomeHorario`, `dataViagem`, `dataHoraInicio`, `dataHoraFim`, `status` (`aberta`, `ativa`, `encerrada`), `codigoAcesso`, `passageiros` (Array de maps), `passageirosIds` | `GerenciadorViagensScreen`, `Motorista`, `Paciente`, `FirebaseAuthService`, `ViagemService` | `GerenciadorViagensScreen`, `ViagemService`, `TransicaoPacienteService` | Acoplamento rígido de uma viagem a apenas um motorista e um veículo. O status do passageiro fica duplicado no array da viagem e no doc do paciente. O motorista encerra a viagem manualmente mesmo com pacientes pendentes. |
| `localizacoes_motoristas` | `motoristaId`, `latitude`, `longitude`, `timestamp` | `Paciente` (para exibir no mapa OSM) | `LocalizacaoMotoristaService` | Não possui mecanismo de expiração automática (TTL). Qualquer usuário anônimo consegue ler e sobrescrever a localização devido às regras abertas. |
| `sessoes_veiculo` | `sessaoId`, `veiculoId`, `motoristaId`, `timestampCriacao`, `status` | `ViagemService` | `ViagemService` | Abstração auxiliar criada para contornar problemas de concorrência em memória, sem validação via Security Rules. |
| `viagens_homologadas` | Dados completos de snapshot de viagem arquivada | `ViagemService` | `ViagemService` | Coleção legada de arquivamento redundante utilizada apenas por rotinas de homologação. |

---

## 5. Inconsistências Identificadas nos Dados e Regras

1. **Dessincronização Crítica de `emViagem`**:
   - O estado do motorista (`emViagem: true/false`), do veículo (`emUso: true/false`) e da viagem (`status: 'ativa'/'encerrada'`) são gravados separadamente e sem garantia de transação atômica. Se a conexão falhar ou houver exceção intermediária, o motorista fica travado como ocupado enquanto o veículo fica livre, ou vice-versa.

2. **Senhas em Texto Puro e Violação de LGPD**:
   - Documentos antigos e seeds continham o campo `senha: "12345"` diretamente legível no Firestore. Além disso, as Security Rules abertas permitiam que pacientes e anônimos realizassem `list` na coleção `/usuarios`, expondo nomes, CPFs, telefones e endereços de terceiros.

3. **Modelo Acoplado 1:1 Incompatível com o Domínio Multi-Viagem e Multi-Motorista**:
   - O documento da viagem guarda `motoristaId` e `veiculoId` de forma fixa. O novo domínio exige que:
     - Um veículo possa levar passageiros de múltiplas viagens simultaneamente.
     - Uma viagem possa ter seus pacientes atendidos/compartilhados por múltiplos condutores em tempo real.
     - A lista de pacientes da viagem seja compartilhada entre todos os motoristas dela.

4. **Ciclo de Vida de Viagem Conflitante**:
   - Na implementação atual, o botão "Finalizar Viagem" do motorista marca `viagem.status = 'encerrada'`, destruindo a sessão e impedindo que outros motoristas concluam o retorno dos pacientes. No domínio correto, o encerramento da viagem é automático e acontece **exclusivamente** quando todos os pacientes estiverem com o status `retornou`.

5. **Contaminação de Estado Estático em Logout**:
   - O `ViagemService` armazena referências estáticas em memória (`_viagensAtivasMemoria`). Se um motorista fizer logout e outro fizer login no mesmo navegador/dispositivo sem recarregar a aba, o segundo motorista visualizava dados em cache do primeiro.

---

## 6. Inventário de Código Morto e Candidatos à Remoção

Utilizando script estático de resolução de grafos de imports Dart, verificação cruzada de referências e auditoria com linters, foram confirmados os seguintes candidatos à remoção:

### 6.1 Código 100% Órfão (Sem Nenhum Import no Projeto nem nos Testes)
1. **`lib/components/timeline_viagem.dart`**:
   - Componente visual de linha do tempo vertical.
   - **Dependência atrelada**: Pacote `timeline_tile` no `pubspec.yaml` (usado unicamente neste arquivo).
   - Confirmação manual: Nenhuma ocorrência em rotas, telas ou testes.

### 6.2 Módulos e Dependências Periféricas Desnecessárias ao Núcleo
1. **Geração e Impressão de PDF**:
   - Arquivos: `lib/services/relatorio_pdf_service.dart`, referências no `gerenciador_viagens_screen.dart` e `viagem_service.dart`.
   - Dependências: `pdf: ^3.13.1`, `printing: ^5.15.1`.
   - Assets: `assets/fonts/LiberationSans-Regular.ttf`, `assets/fonts/LiberationSans-Bold.ttf`.
   - Motivo: Não faz parte do núcleo estrito de controle de transporte de pacientes em tempo real.
2. **Abstrações e Coleções Transitórias**:
   - `lib/models/janela_reversao_model.dart` e `lib/components/banner_reversao_paciente.dart`: Sistema complexo de desfaço/rollback de 5 segundos que mascara inconsistências de concorrência com o backend.
   - `lib/models/sessao_veiculo_model.dart` e coleção `sessoes_veiculo`: Criação desnecessária de coleções paralelas para gerenciar veículo.
   - `viagens_homologadas`: Coleção e métodos de arquivamento mortos.
3. **Telas e Componentes Redundantes**:
   - `lib/screens/admin_placeholder_screen.dart`: Código esqueleto sem utilidade operacional.
   - `lib/detalhes_veiculo.dart`: Tela secundária de leitura de veículo cujos dados essenciais já são exibidos na lista principal.
   - `lib/models/admin_model.dart`: Redundante com `UserRole` e modelo unificado de usuário.
   - `lib/models/estado_tela_paciente.dart`: Estado em memória redundante com o documento da viagem/paciente no Firestore.

---

## 7. Próximos Passos (Transição para a Etapa 1)
Com o levantamento concluído e documentado, o próximo passo é definir formalmente o **Modelo de Domínio** em `docs/dominio.md` (Etapa 1), cobrindo:
1. Os 3 ciclos de vida independentes (Viagem, Motorista/Veículo, Paciente na viagem).
2. As tabelas de transições de status permitidas.
3. O esquema mínimo e normalizado das coleções do Firestore (sem duplicações).
4. As decisões arquiteturais de autenticação e concorrência.
