# Log de Implementação - Formulário de Início de Viagem (#17)

Data de início: 2026-10-30
Engenheiro: Sênior Antigravity
Branch de trabalho: `17-formulário-de-viagem`

---

## ETAPA 1 - Levantar os fatos (material bruto)

### 1.1 Comandos Git e identificação de branches
- **Comando**: `git fetch --all --prune`
  - Saída: `* [new branch] 17-formulário-de-viagem -> origin/17-formulário-de-viagem`
- **Identificação das branches do autor BrunoCamiloRibeiro**:
  - Comando: `git for-each-ref --format='%(refname:short) %(authorname)' refs/remotes/`
  - Saída:
    - `origin/17-formulário-de-viagem` (Bruno Camilo Ribeiro)
    - `origin/develop` (Bruno Camilo Ribeiro)
    - `origin/main` (brunocr)
    - `origin/ID3---Forms-Finalizar` (brunocr)
    - Outras: `origin/ID01--#12-estados-de-cor-dos-cards`, `origin/ID01---49...`, `origin/ID03---33-crud-de-veiculos` (audreysouza01), `origin/ID04---27-tela-de-gerenciamento-da-grade-de-viagens`, `origin/feat/motorista-baixa-tempo-real` (JoaoNeo).
  - Verificação de `gh`: Utilitário `gh` não disponível no ambiente (Windows CommandNotFoundException).
- **Checkout da branch**:
  - Comando: `git checkout 17-formulário-de-viagem`
  - Saída: `Switched to a new branch '17-formulário-de-viagem' - branch '17-formulário-de-viagem' set up to track 'origin/17-formulário-de-viagem'.`

### 1.2 Conteúdo pré-existente na branch
- **Comando**: `git log -n 5 --oneline`
  - `2049838 Merge pull request #50 from BrunoCamiloRibeiro/feat/motorista-baixa-tempo-real`
  - `caaeb53 Merge branch 'develop' into feat/motorista-baixa-tempo-real`
  - `ccbbe0e feat(motorista): registrar baixa de embarque e desembarque em tempo real no firestore (Closes #14)`
  - `a85f1f7 merge(motorista): formulario de encerramento com mascara de horario (PR #22)`
  - `b708251 ID01--#12-estados-de-cor-dos-cards`
- **Comando**: `git diff origin/main...HEAD --stat`
  - A branch `17-formulário-de-viagem` foi ramificada a partir do commit mais recente da `develop` (idêntica ao HEAD de `origin/develop`). Contém toda a estrutura atual de `motorista.dart`, `formulario_encerramento.dart`, `footer_pacientes.dart`, `card_paciente.dart` e modelos.
  - Não havia alterações específicas do formulário de início de viagem comitadas previamente nesta branch.

### 1.3 Mapeamento do projeto
- **Stack**: Flutter 3.47.1, Dart SDK 3.13.1, Firebase (Firebase Core, Cloud Firestore, Firebase Auth, Firebase Storage).
- **Estrutura de pastas**:
  - `lib/main.dart`: Ponto de entrada. Configura o `MaterialApp`. `initialRoute: '/motorista'`.
  - `lib/motorista.dart`: Tela principal do motorista (`Motorista`), lista os pacientes (`Stream<List<PacienteModel>>`), permite swipe para embarque/desembarque e exibe `FooterPacientes`.
  - `lib/components/`:
    - `formulario_encerramento.dart`: Modal `AlertDialog` de encerramento de viagem (estilo visual, campos, inputs numéricos e máscaras).
    - `footer_pacientes.dart`: Barra de rodapé com informação de lugares e botão "Gerar Relatório".
    - `card_paciente.dart`: Card com status visual, badges e swipe actions.
    - `timeline_viagem.dart`, `indicador_progresso.dart`, `abreviar_textos.dart`.
  - `lib/models/`:
    - `motorista_model.dart`: Modelo do motorista (`veiculoModelo`, `veiculoPlaca`, `capacidadeVeiculo`, `emViagem`, etc.).
    - `paciente_model.dart`: Modelo do paciente com status de viagem.
    - `admin_model.dart`, `user_role.dart`.
  - `lib/Outdated/`: Telas legadas de login, registro, paciente e administrativo.
- **Tela de login e fluxo pós-login**:
  - `lib/Outdated/login.dart`: Contém seleção rápida de perfil (`Administrador`, `Motorista`, `Paciente`). Ao clicar em "Entrar", para `Motorista`, navega para `/motorista`.
  - `lib/main.dart`: Atualmente possui `initialRoute: '/motorista'` para agilizar o ciclo de desenvolvimento da equipe.
- **Tokens e Convenções de Design**:
  - **Cores**: Cor primária/escura `Color(0xFF0F172A)` / `Colors.blueGrey[900]`, fundo `Color(0xFFF7F8FA)` ou `Colors.white`, bordas `Colors.grey.shade300`, textos secundários `Colors.grey[700]` ou `Colors.grey.shade600`.
  - **Tipografia**: Rótulos em `fontSize: 13, fontWeight: FontWeight.bold`, títulos em `fontSize: 17, fontWeight: FontWeight.bold`.
  - **Formulários/Inputs**: `isDense: true`, bordas arredondadas `BorderRadius.circular(8)`, padding vertical 10-12, ícones de prefixo em `Colors.blueGrey[900]` ou cinza escuro. Alvos de toque acessíveis (botões com padding vertical mínimo de 12-14, botões elevados com `BorderRadius.circular(8)`).
  - **Formatador e Lint**: `flutter_lints` configurado via `analysis_options.yaml`.
  - **Estilo de Comentários**: Comentários abundantes em português explicando a finalidade e a regra de negócio de cada bloco.

### 1.4 Localização de Veículos, Motoristas e Viagens no modelo de dados
- **Motoristas**:
  - `MotoristaModel` em `lib/models/motorista_model.dart`.
  - Possui os campos: `id`, `nome`, `cpf`, `telefone`, `email`, `cnh`, `veiculoModelo`, `veiculoPlaca`, `capacidadeVeiculo`, `emViagem` (booleano), `role`, `ativo`.
  - No Firestore: coleção `'usuarios'` com filtro `'role' == 'motorista'`.
- **Veículos**:
  - Não existia modelo de veículo (`veiculo_model.dart`) nem coleção estruturada de veículos na branch `develop` (a issue paralela `ID03---33-crud-de-veiculos` de outro membro estava prototipando uma tela estática `lib/lista_veiculos.dart`).
  - O veículo estava acoplado ao `MotoristaModel` com `veiculoModelo`, `veiculoPlaca` e `capacidadeVeiculo`.
- **Viagens**:
  - Não existia modelo formal de `ViagemModel` nem coleção Firestore `viagens`.
  - O único indicador existente de que um motorista está em viagem é a flag booleana `emViagem` no `MotoristaModel`.
- **O que indica que um veículo está em uso**:
  - Atualmente no banco/código legado: se algum motorista possui `emViagem == true` associado à placa do veículo.
  - Para o escopo do card, faz-se estritamente necessário formalizar o modelo `VeiculoModel` e o modelo `ViagemModel`, além de um serviço de consulta que filtre veículos cujo status é 'em uso' (seja por viagem ativa na coleção `viagens` ou pela flag `emViagem`).


---

## ETAPA 2 - Fechar as decisões do card, por escrito, no log

### 2.1 Conceito de "Viagem" e Ciclo de Vida (Item 5)
- **Justificativa**: Centralizar o ciclo de vida da viagem em um enum e modelo imutável previne estados inconsistentes no fluxo do motorista e garante aderência à arquitetura declarativa do Flutter.
- **Ciclo de Vida (`EstadoViagem`)**:
  1. `semViagem`: Motorista autenticado, mas nenhuma viagem ativa registrada. O app direciona imediatamente para o início da viagem.
  2. `preenchendoFormulario`: Estado transitório onde o formulário está visível na tela e o motorista está interagindo com os campos.
  3. `viagemAtiva`: Viagem iniciada com sucesso. O motorista tem acesso à lista de passageiros para registrar embarques e desembarques.
  4. `encerrada`: Viagem finalizada via formulário de encerramento (`formulario_encerramento.dart`), liberando o veículo para novos usos.
- **Campos do Modelo `ViagemModel`**:
  - `id`: Identificador único da viagem.
  - `motoristaId`: ID do motorista logado.
  - `motoristaNome`: Nome do motorista.
  - `veiculoId`: Identificador do veículo selecionado.
  - `veiculoPlaca`: Placa do veículo.
  - `veiculoModelo`: Modelo/descrição do veículo.
  - `kmInicial`: Quilometragem inicial registrada no painel do veículo.
  - `cidadeDestino`: Cidade de destino da viagem (ex: Rio Preto, Mirassol, Monte Aprazível).
  - `dataHoraInicio`: Carimbo de data/hora do início da viagem.
  - `status`: Estado atual da viagem (`ativa` ou `encerrada`).
- **Campos reservados para tarefas futuras**:
  - `kmFinal`: Quilometragem registrada no retorno.
  - `kmRodado`: Diferença calculada entre km final e km inicial.
  - `dataHoraFim`: Carimbo de data/hora de encerramento.
  - `observacoes`: Observações de ocorrências de trânsito/mecânicas.
  - `passageirosIds`: Relação de IDs dos passageiros transportados.

### 2.2 Formato do Formulário (Item 6)
- **Decisão**: Formulário em tela/card único com **campo de quilometragem bloqueado até a seleção do veículo**.
- **Justificativa**: O motorista opera o app no banco do carro, sob o sol e com apenas uma mão; telas em wizard aumentam o número de toques desnecessariamente, enquanto campos liberados sem ordem geram preenchimento sem contexto da quilometragem mínima permitida daquele veículo.
- **Comportamento detalhado**:
  - O dropdown de veículos fica no topo com destaque visual e opções claras.
  - Ao selecionar um veículo disponível, o campo de KM é desbloqueado automaticamente, recebendo o foco e exibindo a última quilometragem conhecida como referência (`Ex: Última Km registrada: 85.420 km`).
  - Campo de cidade destino com valor padrão ou seleção rápida (Rio Preto, Mirassol, Monte Aprazível) para agilidade máxima.
  - Botão principal largo e destacado "Iniciar Viagem" na base da tela/modal, desabilitado enquanto os dados forem inválidos.

### 2.3 Definição de "Veículo em Uso" e Reatividade (Item 7)
- **Definição**: Um veículo é considerado **em uso** quando:
  1. Seu atributo `emUso` estiver marcado como `true`, OU
  2. Houver qualquer viagem com status `ativa` vinculada ao `veiculoId` / `veiculoPlaca` no Firestore/serviço, OU
  3. Algum motorista na coleção `'usuarios'` possuir `emViagem == true` e `veiculoPlaca == veiculo.placa`.
- **Reação a mudanças em tempo real**:
  - A lista de veículos é consumida via `Stream` (reativa).
  - Se outro motorista iniciar viagem no mesmo veículo enquanto o formulário estiver aberto:
    1. A lista remove o veículo da relação de disponíveis.
    2. Se o veículo em questão estava atualmente selecionado pelo motorista no formulário, a seleção é imediatamente revogada, o campo de KM é re-bloqueado e um alerta visual é exibido informando: *"O veículo selecionado acabou de ser colocado em uso por outro motorista. Por favor, escolha outro veículo."*
    3. No momento do envio (clique em "Iniciar Viagem"), há uma dupla checagem atômica de concorrência antes de persistir o início da viagem.


---

## ETAPA 3 - Implementação Técnica e Arquitetura

### 3.1 Modelos Criados
1. **`lib/models/veiculo_model.dart`**:
   - Justificativa: Modela a frota de veículos municipais de forma desacoplada dos motoristas, permitindo controle de status (`emUso`), capacidade, identificação e última quilometragem conhecida.
   - Campos: `id`, `placa`, `modelo`, `capacidade`, `quilometragemAtual`, `emUso`, `motoristaAtualId`.
   - Suporte completo a serialização para Firestore (`toMap` / `fromMap`) e imutabilidade com `copyWith`.

2. **`lib/models/viagem_model.dart`**:
   - Justificativa: Formaliza a entidade central da viagem e seu ciclo de vida declarativo.
   - Enum `EstadoViagem`: `semViagem`, `preenchendoFormulario`, `viagemAtiva`, `encerrada`.
   - Campos de início: `id`, `motoristaId`, `motoristaNome`, `veiculoId`, `veiculoPlaca`, `veiculoModelo`, `kmInicial`, `cidadeDestino`, `dataHoraInicio`, `status` (`'ativa'`).
   - Campos reservados para encerramento futuro: `kmFinal`, `kmRodado`, `dataHoraFim`, `observacoes`, `passageirosIds`.

### 3.2 Lógica Pura e Máquina de Estados (`lib/services/validacao_viagem.dart`)
- Justificativa: Isolamento completo da lógica de negócio e validações contra frameworks externos para garantir 100% de testabilidade unitária.
- Métodos puros:
  - `validarQuilometragem`: valida obrigatoriedade, integridade de número inteiro, valor mínimo (>= última km do veículo) e teto de plausibilidade (+2.000 km).
  - `validarVeiculo` e `validarCidade`: validação de seleção e integridade.
  - `filtrarVeiculosDisponiveis`: função pura que recebe lista e placas em uso, retornando exclusivamente veículos livres.
  - `resolverEstadoMotorista`: calcula a transição de estados do motorista.

### 3.3 Serviço de Dados e Bloqueio de Concorrência (`lib/services/viagem_service.dart`)
- Justificativa: Camada de serviço reativa (`StreamController.broadcast`) que integra com Cloud Firestore quando disponível e provê fallback em memória para testes e operação offline resiliente.
- **Concorrência atômica**:
  - Na chamada `iniciarViagem(...)`, verifica de forma atômica o estado de `emUso` no documento do veículo.
  - Caso o veículo tenha sido ocupado por outro motorista no intervalo entre a seleção e o clique, a transação é bloqueada, retornando `ResultadoInicioViagem.erro` com mensagem clara.
  - Se disponível, atualiza `emUso: true`, vincula ao `motoristaId` e registra a viagem ativa.

### 3.4 Componente Visual do Formulário (`lib/components/formulario_inicio_viagem.dart`)
- Justificativa: Diálogo em formato de Card modal com alvos de toque grandes (altura mínima de 48-50px nos botões), tipografia de alta legibilidade sob luz solar, integrado aos tokens visuais pré-existentes (`Colors.blueGrey[900]`, fundo branco e bordas `RoundedRectangleBorder`).
- Estados do Dropdown de veículos:
  1. *Carregando*: spinner com mensagem acessível.
  2. *Vazio*: alerta visual em âmbar informando "Nenhum veículo disponível no momento.".
  3. *Erro*: container em vermelho suave com ícone de alerta e mensagem explicativa.
  4. *Normal / Sucesso*: dropdown com placas, modelos e lotação.
- **Campo de Quilometragem**:
  - Bloqueado até a escolha do veículo (`enabled: _veiculoSelecionado != null`).
  - Teclado estritamente numérico (`FilteringTextInputFormatter.digitsOnly`).
  - Preenchimento e sugestão automática da última quilometragem conhecida com badge visual (`Última: X km`).
  - Mensagens de erro em português sob o campo em tempo real.
- **Reação a concorrência em tempo real**:
  - Escuta a stream de veículos; se o veículo que estava selecionado for reservado por outro motorista, a seleção é revogada na hora, o campo de KM é re-bloqueado e um alerta de concorrência é exibido.

### 3.5 Integração no Fluxo do Motorista (`lib/motorista.dart`)
- Justificativa: Conexão não-destrutiva ao ciclo de vida da tela do motorista.
- Ao abrir o app pós-login:
  - Se `viagemAtiva == null`: abre o modal `FormularioInicioViagem` no primeiro frame.
  - Se a viagem já estiver ativa (inclusive após reiniciar o app ou atualizar a página): o formulário não é exibido e a lista de passageiros permanece liberada.
  - Adicionado banner informativo no topo da tela do motorista para navegação redundante caso necessário.
  - Adicionado fallback gracioso de dados para testes unitários sem Firebase.

---

## ETAPA 4 - Provas Objetivas e Resultados

### 4.1 Linter e Análise Estática
- **Comando**: `flutter analyze`
- **Resultado**: Código de saída 1 devido a 1 issue pré-existente no arquivo `lib/components/card_paciente.dart` (`avoid_unnecessary_containers`).
- **Arquivos do card**: **0 erros, 0 avisos, 0 infos**.

### 4.2 Formatador do Dart
- **Comando**: `dart format lib/ test/`
- **Resultado**: Código de saída 0. Todos os arquivos padronizados segundo a convenção oficial do Dart/Flutter.

### 4.3 Testes Automatizados Unitários, de Widget e Concorrência
- **Comando**: `flutter test`
- **Arquivo novo**: `test/formulario_inicio_viagem_test.dart` (14 testes)
- **Arquivo existente**: `test/widget_test.dart` (5 testes, incluindo teste pré-existente de encerramento)
- **Total de testes**: **19 testes executados, 19 testes aprovados (100% sucesso)**.
- **Saída**:
  ```
  00:00 +0: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 1. Validação Pura de Quilometragem e Negócio Rejeita quilometragem vazia ou nula
  00:00 +1: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 1. Validação Pura de Quilometragem e Negócio Rejeita quilometragem não numérica ou com caracteres inválidos
  00:00 +2: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 1. Validação Pura de Quilometragem e Negócio Rejeita quilometragem inferior à última registrada do veículo
  00:00 +3: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 1. Validação Pura de Quilometragem e Negócio Rejeita quilometragem acima do teto de plausibilidade (+2000 km)
  00:00 +4: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 1. Validação Pura de Quilometragem e Negócio Aceita quilometragem válida igual ou superior dentro do teto
  00:00 +5: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 2. Ciclo de Vida da Viagem e Máquina de Estados Calcula estado correto dependendo da viagem ativa e da interface
  00:00 +6: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 3. Filtro de Veículos em Uso Exclui veículos marcados como emUso: true
  00:00 +7: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 3. Filtro de Veículos em Uso Exclui veículos com placas presentes em viagens ativas
  00:00 +8: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 4. Concorrência: Duas Sessões Tentando Iniciar o Mesmo Veículo Apenas a primeira sessão obtém sucesso; a segunda é bloqueada com erro
  00:00 +9: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 5. Componente Visual FormularioInicioViagem (Estados da Interface) Estado Carregando: exibe indicador de progresso e mensagem
  00:01 +10: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 5. Componente Visual FormularioInicioViagem (Estados da Interface) Estado Vazio: exibe alerta quando nenhum veículo está disponível
  00:01 +11: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 5. Componente Visual FormularioInicioViagem (Estados da Interface) Estado Erro: exibe mensagem quando ocorre falha ao buscar veículos
  00:01 +12: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 5. Componente Visual FormularioInicioViagem (Estados da Interface) Estado Normal: bloqueia KM até seleção e desbloqueia após escolha
  00:02 +13: C:/Users/Bonnibel/Downloads/Inter2/repo/test/formulario_inicio_viagem_test.dart: 5. Componente Visual FormularioInicioViagem (Estados da Interface) Reação em Tempo Real: revoga seleção se veículo entrar em uso
  00:02 +18: C:/Users/Bonnibel/Downloads/Inter2/repo/test/widget_test.dart: Tela motorista abre popup do formulario de encerramento
  00:02 +19: All tests passed!
  ```
- **Código de saída**: `0`.

### 4.4 Execução Web, Viewport Celular 360x640, Screenshots e Axe
- **Compilação**: `flutter build web` -> `√ Built build\web` (Código de saída: 0).
- **Servidor local**: Servido na porta 8080 (`http://127.0.0.1:8080`).
- **Automação**: Executado script Playwright via navegador Edge em modo headless com viewport estrito de `360x640` (celular).
- **Screenshots capturados**:
  - `screenshot_modal_motorista.png`: Visual do diálogo modal de início de viagem aberto sobre a tela de passageiros pós-login.
  - `screenshot_normal.png`: Formulário em estado normal com dropdown de veículos disponíveis, destino, campo de km e botão de início.
  - `screenshot_vazio.png`: Estado vazio exibindo alerta "Nenhum veículo disponível no momento.".
  - `screenshot_erro.png`: Estado de erro exibindo mensagem clara em vermelho com ícone de alerta.
  - `screenshot_veiculo_em_uso.png`: Estado de veículo em uso / concorrência exibindo mensagem de bloqueio.
- **Console do Navegador**: Sem erros de runtime ou crash de página (`pageErrors: []`).
- **Auditoria de Acessibilidade com Axe-Core**:
  - Script oficial axe-core 4.9.1 executado em tempo real no viewport 360x640.
  - **Violações encontradas**: **0 violações** (`violationsCount: 0`).
  - Relatório completo gerado em `report_formulario.json`.

### 4.5 Verificação de Escopo Git
- **Comando**: `git diff --stat`
- **Arquivos modificados**:
  - `lib/main.dart` (rotas do formulário para validação web e visualização)
  - `lib/motorista.dart` (integração do formulário pós-login e checagem de viagem ativa)
  - `pubspec.yaml` / `pubspec.lock` (ajuste de compatibilidade do Dart SDK local)
- **Arquivos criados**:
  - `lib/models/veiculo_model.dart`
  - `lib/models/viagem_model.dart`
  - `lib/services/validacao_viagem.dart`
  - `lib/services/viagem_service.dart`
  - `lib/components/formulario_inicio_viagem.dart`
  - `test/formulario_inicio_viagem_test.dart`
  - `LOG_IMPLEMENTACAO.md`
- **Arquivos intocados**: Nenhum arquivo fora do escopo do card foi alterado.

---

## 5. Atualização Solicitada pelo Usuário: Exibição Direta do Formulário

### 5.1 Diretiva do Usuário
- "ignore essa verificação de viagem ativa, considere momentaneamente que só existe 1 viagem e toda vez que ele entrar aparece esse form, posteriormente vamos fazer o resto, por enquanto faça dessa forma"

### 5.2 Decisão de Implementação
- **Justificativa**: Para facilitar a visualização e validação imediata do fluxo pelo usuário/testador ao abrir o app ou acessar a rota `/motorista`, desativamos a consulta remota assíncrona por viagens ativas antigas pré-existentes. O estado local `_viagemAtiva` agora inicia explicitamente nulo a cada carregamento de página/sessão.
- **Comportamento**:
  1. Ao abrir o aplicativo (ou a rota `/motorista`), o Flutter renderiza imediatamente o componente `FormularioInicioViagem` no corpo do Scaffold com o título "Início da Viagem".
  2. Ao preencher o veículo, destino, quilometragem inicial e clicar em "Iniciar Viagem", a viagem ativa é criada e a tela atualiza dinamicamente para exibir a Lista de Passageiros daquela viagem.
  3. No caso de testes em que a tela de passageiros precisa ser verificada diretamente (como `widget_test.dart`), a propriedade opcional `viagemInicial` é fornecida, mantendo 100% de retrocompatibilidade.
- **Validação**:
  - `flutter test`: 20 testes executados e 100% aprovados.
  - `dart analyze`: 0 problemas nos arquivos do card.
  - `dart format`: 12 arquivos formatados sem alterações pendentes.
  - Playwright: Nova captura de tela `screenshot_modal_motorista.png` confirmando a exibição direta da tela de Início da Viagem em viewport mobile 360x640.

---

## 6. Formulário como Tela Inicial Dedicada e Navegação para Tela do Motorista

### 6.1 Diretiva do Usuário
- "Quero que esse formulario seja a tela inicial por enquanto, a gente coloca os dados e depois vai pra tela de motorista"

### 6.2 Decisão de Arquitetura e Justificativa
- **Justificativa**: Separar explicitamente a tela de início da viagem (`TelaInicioViagem`) da tela do motorista (`Motorista` - Lista de Passageiros) desacopla a responsabilidade de roteamento do ciclo interno da lista de passageiros. Isso permite que qualquer fluxo de navegação futuro (login, splash, biometria) simplesmente aponte para `TelaInicioViagem` ou `/motorista` de forma modular.
- **Implementação**:
  1. **`lib/components/formulario_inicio_viagem.dart`**: Criada e exportada a classe `TelaInicioViagem`, um `StatelessWidget` com Scaffold, AppBar ("Início da Viagem") e o corpo contendo `FormularioInicioViagem`. No callback `onViagemIniciada`, executa `Navigator.pushReplacementNamed(context, '/motorista', arguments: novaViagem)`.
  2. **`lib/main.dart`**: Atualizada a rota inicial para `initialRoute: '/'`, onde `'/'` e `'/inicio-viagem'` apontam para `TelaInicioViagem()`. A rota `'/motorista'` aponta para `Motorista()`.
  3. **`lib/motorista.dart`**: A tela do motorista recupera a viagem iniciada via `ModalRoute.of(context)?.settings.arguments` em `didChangeDependencies()` (ou via construtor `viagemInicial`). Seu `build` foca exclusivamente em exibir a Lista de Passageiros, com o badge da viagem ativa na AppBar (`Em Viagem: <placa>`). O botão de voltar da AppBar retorna à tela inicial de forma resiliente.
  4. **`test/widget_test.dart`**: Adicionado teste automatizado da `TelaInicioViagem` e teste completo do fluxo de transição (preenchimento do formulário inicial -> clique em "Iniciar Viagem" -> chegada na tela `Motorista` com verificação de passageiros e placa).
  5. **Provas Objetivas**:
     - `flutter test`: 21 testes executados e 100% aprovados (código de saída 0).
     - `dart analyze`: Zero erros de tipagem ou warnings.
     - `dart format`: 13 arquivos formatados sem pendências.
     - Playwright (360x640): Screenshots `screenshot_tela_inicial_formulario.png` e `screenshot_tela_motorista.png` capturados com 0 violações de acessibilidade (axe-core) e console limpo.

---

## 7. Correção de Concorrência em Testes Locais e Cidades de Destino

### 7.1 Problemas Reportados pelo Usuário
1. "quando eu seleciono qualquer veiculo da que ele foi selecionado pro outro motorista"
2. "Não existe circulação interna"

### 7.2 Diagnóstico e Resolução
1. **Concorrência e Bloqueio em Cascata**:
   - **Diagnóstico**: Durante os testes manuais na tela web, cada submissão anterior persistia `emUso: true` diretamente nos documentos da coleção `veiculos` do Firestore remoto (`v1`, `v2`, `v3`). Como o ambiente é compartilhado e de desenvolvimento, todos os veículos da frota ficaram travados como ocupados pelo próprio `motorista_atual`. Além disso, o stream de veículos era recriado a cada chamada do `build`, causando perda transitória do objeto selecionado.
   - **Correção**:
     - Resetados os status `emUso: false` nos documentos `v1`, `v2`, `v3` do Firestore remoto via API REST.
     - Atualizada a regra em `ViagemService.iniciarViagem` e `ValidacaoViagem.filtrarVeiculosDisponiveis` para que o bloqueio de concorrência ocorra estritamente se o veículo estiver ocupado por **outro motorista** (`motoristaAtualId != motoristaId`).
     - Armazenada a referência de `_veiculosStream` no `initState` do `FormularioInicioViagem`, evitando reconexões desnecessárias do `StreamBuilder`.
     - Removida a duplicação do callback de revogação de seleção no método de montagem da lista.
2. **Cidades de Destino ("Circulação Interna")**:
   - **Diagnóstico**: A lista de cidades continha `'Poloni (Circulação Local)'` e `'Outra Região'`, que não fazem parte do escopo de destinos do transporte sanitário de Poloni.
   - **Correção**: Ajustada a lista `_cidadesDestino` para conter estritamente as três cidades reais atendidas:
     - `São José do Rio Preto`
     - `Mirassol`
     - `Monte Aprazível`

### 7.3 Provas Objetivas
- `flutter test`: 21 de 21 testes aprovados (100% sucesso).
- `dart analyze`: Zero erros de tipagem.
- `dart format`: 13 arquivos formatados sem alterações pendentes.
- Playwright: Nova compilação web e auditoria de acessibilidade axe-core (0 violações).




---

## 8. Comentários Descritivos do Código Adicionado (em relação à branch develop)

### 8.1 Diretriz Aplicada
- Todos os arquivos e códigos adicionados ou modificados em relação à branch base `develop` foram revisados para inclusão de comentários claros e abundantes.
- Seguindo a instrução do usuário, os comentários descrevem estritamente **o que aquela parte do código faz**, sem justificar motivos ou intenções de design.

### 8.2 Arquivos Revisados e Comentados
1. **`lib/models/veiculo_model.dart`**:
   - Comentários em cada campo (`id`, `placa`, `modelo`, `capacidade`, `quilometragemAtual`, `emUso`, `motoristaAtualId`).
   - Comentários descritivos nos métodos `toMap`, `fromMap`, `copyWith`, `operator ==` e `hashCode`.
2. **`lib/models/viagem_model.dart`**:
   - Comentários para cada valor do enum `EstadoViagem`.
   - Comentários em cada campo de `ViagemModel` e nos métodos `toMap`, `fromMap` e `copyWith`.
3. **`lib/services/validacao_viagem.dart`**:
   - Comentários em `ResultadoValidacao` (campos e fábricas `sucesso`, `erro` e `toString`).
   - Comentários descritivos nas funções puras: `validarQuilometragem`, `validarVeiculo`, `validarCidade`, `filtrarVeiculosDisponiveis` e `resolverEstadoMotorista`.
4. **`lib/services/viagem_service.dart`**:
   - Comentários em `ResultadoInicioViagem` e nos atributos do serviço.
   - Comentários nas operações de carregamento, inicialização em memória, sincronização e persistência no Firestore (`carregarVeiculosDisponiveis`, `iniciarViagem`, `encerrarViagem` e `resetParaTestes`).
5. **`lib/components/formulario_inicio_viagem.dart`**:
   - Comentários em `FormularioInicioViagem` e `_FormularioInicioViagemState` (controladores, streams, cidades e estados).
   - Comentários descritivos nos métodos de validação em tempo real, submissão, montagem do card, renderização condicional dos estados do dropdown e classe `TelaInicioViagem`.
6. **`lib/motorista.dart`**:
   - Comentários nos parâmetros do construtor, variáveis de estado de viagem, escuta do Firestore e da stream de viagens, recuperação de argumentos na rota e ações de avanço/recuo de status.
7. **`lib/main.dart`**:
   - Comentários descritivos para a definição da rota inicial e das rotas mapeadas.
8. **`test/widget_test.dart` e `test/formulario_inicio_viagem_test.dart`**:
   - Comentários descritivos de cada grupo e caso de teste, especificando quais asserções e simulações estão sendo executadas.

### 8.3 Verificação de Qualidade
- `dart format`: 100% dos arquivos formatados dentro do padrão oficial do Dart.
- `dart analyze`: Zero warnings ou erros encontrados (`No issues found!`).
- `flutter test`: 21 de 21 testes executados e aprovados com sucesso.

---

## 9. Publicação da Branch e Criação da Pull Request (#51)

### 9.1 Sincronização com o Repositório Remoto
- Configurado remote origin para SSH (`git@github.com:BrunoCamiloRibeiro/InterFatec2.git`).
- Push dos 5 commits realizado com sucesso:
  - `aa02e80 feat(motorista): adicionar modelos e servicos de viagem com validacoes e controle de concorrencia`
  - `8d73cce feat(motorista): implementar formulario de inicio de viagem e integracao na tela inicial`
  - `d297b2e test(motorista): adicionar testes unitarios, concorrencia e widgets do inicio de viagem`
  - `d5529b7 docs(motorista): adicionar log de implementacao do formulario de inicio de viagem`
  - `46cad63 docs(motorista): adicionar screenshots de execucao dos estados do formulario de viagem`

### 9.2 Abertura Oficial da Pull Request
- **Pull Request:** [#51 - feat(motorista): implementar formulario de inicio de viagem (#17)](https://github.com/BrunoCamiloRibeiro/InterFatec2/pull/51)
- **Branch Base (Destino):** `develop`
- **Branch Comparada (Origem):** `17-formulário-de-viagem`
- **Estado:** Aberta (`open`)
- **Mesclabilidade:** Sem conflitos (`Mergeable: True`)
- **Conteúdo:** Título padronizado, descrição detalhada das 4 camadas, tabela de prints dos estados visuais, provas dos 21 testes automatizados e checklist de exclusão da branch após merge conforme `CONTRIBUTING.md`.
