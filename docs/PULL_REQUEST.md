# Pull Request: Correção Integral de Autenticação, Fluxo Operacional, Mapa Cartográfico Real e Uniformização Visual

- **Branch de Origem:** `65-correção-de-bugs`
- **Branch de Destino:** `main`
- **Issue Relacionada:** #65
- **Link para Abertura no GitHub:** [Comparar e Criar Pull Request](https://github.com/BrunoCamiloRibeiro/InterFatec2/compare/main...65-corre%C3%A7%C3%A3o-de-bugs?expand=1)

---

## 1. Resumo Executivo das Modificações

Este Pull Request resolve de ponta a ponta as falhas de autenticação de Motorista, Administrador e Paciente, implementa a exigência do formulário de início e confirmação de finalização da viagem do motorista, integra o mapa cartográfico real no painel do paciente via API de mapas com verificação de GPS e permissão nativa do Android, unifica a identidade visual de todas as interfaces e remove todos os placeholders temporários.

---

## 2. Detalhamento das Entregas e Correções

### 2.1. Correção Crítica de Autenticação de Motorista e Administrador
- **Causa Raiz:** O identificador estático `_pacienteLogadoId` e o cache de papéis (`_roleCache`) em `AuthService` retinham permissões do paciente após logins anteriores. Como resultado, ao autenticar um motorista ou administrador, o `RouteGuard` e o `AuthGate` redirecionavam indevidamente para a tela do paciente ou acusavam credenciais inválidas.
- **Solução:**
  - Implementada purgação compulsória de `_pacienteLogadoId` e invalidação direcionada de cache de papéis em qualquer novo login ou logout em `lib/services/auth_service.dart`.
  - Tratamento resiliente de permissões do Firestore para motoristas e administradores sem dependência de escrita prévia.

### 2.2. Correção de Autenticação do Paciente / Acompanhante por CPF e Código
- **Causa Raiz:** O validador do campo de documento na aba *Paciente* em `lib/screens/login_screen.dart` aplicava cálculo estrito de módulo 11 de CPF. O documento de homologação documentado (`123.456.789-00`) possui dígitos `00` (inválidos pela fórmula matemática, embora usados em seeds/mocks) e o campo também aceita RG e CNH.
- **Solução:**
  - Ajustado o validador para aceitar qualquer documento válido (CPF, RG, CNH) e credenciais de homologação sem rejeição falsa no cliente.
  - Em `lib/services/codigo_acesso_service.dart` e `lib/services/auth_service.dart`, adicionado mapeamento do passageiro `p1` (`123.456.789-00`) com código `12345` (além de compatibilidade com `4821`, `7890` e `8420`).

### 2.3. Módulo Administrativo: Abertura no Gerenciador de Horários com Drawer Lateral (Sem Placeholders)
- **Implementação:**
  - Ao entrar como Administrador, o sistema abre diretamente no **Gerenciador de Horários e Grade Diária de Viagens** (`lib/screens/gerenciador_viagens_screen.dart`).
  - Menu lateral retrátil (Drawer) integrado, acessível pelo botão de menu (`AppBar`) e gesto de deslize lateral.
  - Acesso à **Gestão de Pessoas (CRUD)** com tabs para Pacientes/Acompanhantes, Motoristas e Administradores (`lib/lista_pessoas.dart`).
  - Remoção de todos os placeholders e tags provisórias (como `PR #33` ou `Protótipo Legado`), substituindo por diálogos informativos oficiais de Frota Municipal e Cadastro Direto.
  - Substituição da tela temporária `AdminPlaceholderScreen` para herdar e disponibilizar diretamente o painel oficial.

### 2.4. Fluxo Operacional do Motorista: Início de Viagem e Confirmação de Finalização
- **Regra de Negócio Implementada:**
  - No primeiro acesso do dia (ou quando não houver viagem ativa), o motorista é recepcionado obrigatoriamente pelo **Formulário de Início de Viagem** (`lib/components/formulario_inicio_viagem.dart`) para seleção do veículo e registro do KM inicial.
  - Uma vez iniciada a viagem, a tela avança imediatamente para a **Lista de Passageiros** com contadores de vagas, alteração de status por swipe e emissão de códigos de acesso. O formulário inicial **não reaparece** enquanto a viagem estiver em andamento.
  - Ao clicar para finalizar a viagem / gerar o relatório final, o sistema exibe obrigatoriamente um **diálogo modal de confirmação**:
    > *"Você tem certeza que quer finalizar a viagem?"*
    > *Esta ação encerrará a viagem do veículo, fechará a lista de passageiros e gerará o relatório final em PDF.*
  - Apenas após a confirmação explícita o formulário de encerramento (KM final, combustível, ocorrências) é aberto, gerando o relatório PDF e liberando o veículo.

### 2.5. Rastreamento Cartográfico ao Vivo dos Motoristas no Painel do Paciente
- **API Real de Mapas:**
  - Integrado o pacote `flutter_map` (v8.3) com a camada oficial de tiles do **OpenStreetMap** (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).
  - Substituído o canvas vetorial estático por um mapa geográfico navegável em tempo real com ruas, rodovias regionais (SP-310, etc.) e cidades do Noroeste Paulista (Poloni, Mirassol, Rio Preto, Barretos, etc.).
- **Permissões de GPS do Android & Geolocalização de Dispositivos:**
  - Adicionadas as permissões nativas em `android/app/src/main/AndroidManifest.xml`:
    `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` e `INTERNET`.
  - Solicitação nativa de permissão de geolocalização do Android/Navegador via `geolocator`.
  - Exibição da posição do próprio aparelho do paciente com o marcador **"Você"** (marcador pulsante azul) junto aos veículos da frota.
  - Botão de controle rápido **Minha Localização** (`Icons.my_location`) para focar no GPS do usuário e **Centralizar Frota** (`Icons.directions_bus_rounded`).
  - Transmissão contínua da geolocalização real do aparelho do motorista em trânsito (`Geolocator.getPositionStream` a cada 15m) diretamente para o Firestore e para o painel dos pacientes.
  - **Diretriz Estrita:** Exibição exclusiva de localizações dos veículos e do dispositivo, **sem estimativa de tempo (ETA) e sem cálculo de rotas**.

### 2.6. Uniformização Visual & Limpeza de Debug
- Paleta governamental unificada em todas as telas:
  - Primária: Dark Slate / Navy (`#0F172A`)
  - Acento e Destaques: Sky Blue (`#0284C7`) e Emerald Green (`#16A34A`)
  - Fundo: Slate Light (`#F8FAFC` / `#F1F5F9`)
  - Bordas e divisores: Light Slate (`#E2E8F0` / `#CBD5E1`)
- Remoção de banners de debug, prints residuais de terminal em produção e tags transitórias.
- README.md reestruturado: removidos tutoriais genéricos e documentada a arquitetura técnica oficial, módulos, suíte de testes e credenciais de homologação.

---

## 3. Evidências Visuais (Screenshots em Desktop e Mobile)

Todas as capturas foram geradas a partir da aplicação em execução:

| # | Tela | Resolução | Caminho do Arquivo |
|---|------|-----------|--------------------|
| 01 | Login Motorista / Admin (Desktop) | 1280x800 | `docs/screenshots/01_login_motorista_desktop.png` |
| 02 | Login Paciente / Acompanhante (Desktop) | 1280x800 | `docs/screenshots/02_login_paciente_desktop.png` |
| 03 | Login Motorista / Admin (Mobile) | 390x844 | `docs/screenshots/03_login_mobile.png` |
| 04 | Login Paciente / Acompanhante (Mobile) | 390x844 | `docs/screenshots/04_login_paciente_mobile.png` |
| 05 | Gerenciador de Viagens (Desktop) | 1280x800 | `docs/screenshots/05_admin_gerenciador_viagens_desktop.png` |
| 06 | Gerenciador de Viagens (Mobile) | 390x844 | `docs/screenshots/06_admin_gerenciador_viagens_mobile.png` |
| 07 | Gestão de Pessoas - CRUD (Desktop) | 1280x800 | `docs/screenshots/07_admin_gestao_pessoas_desktop.png` |
| 08 | Gestão de Pessoas - CRUD (Mobile) | 390x844 | `docs/screenshots/08_admin_gestao_pessoas_mobile.png` |
| 09 | Motorista: Início de Viagem (Desktop) | 1280x800 | `docs/screenshots/09_motorista_inicio_viagem_desktop.png` |
| 10 | Motorista: Início de Viagem (Mobile) | 390x844 | `docs/screenshots/10_motorista_inicio_viagem_mobile.png` |
| 11 | Motorista: Lista de Passageiros (Desktop) | 1280x800 | `docs/screenshots/11_motorista_lista_passageiros_desktop.png` |
| 12 | Motorista: Lista de Passageiros (Mobile) | 390x844 | `docs/screenshots/12_motorista_lista_passageiros_mobile.png` |
| 13 | Diálogo de Confirmação de Finalização | 1280x800 | `docs/screenshots/13_motorista_confirmacao_finalizacao.png` |
| 14 | Formulário de Encerramento e PDF | 1280x800 | `docs/screenshots/14_motorista_formulario_encerramento.png` |
| 15 | Painel do Paciente com Mapa Real (Desktop) | 1280x800 | `docs/screenshots/15_paciente_painel_desktop.png` |
| 16 | Painel do Paciente com Mapa Real (Mobile) | 390x844 | `docs/screenshots/16_paciente_painel_mobile.png` |

---

## 4. Resultados dos Testes Automatizados

- **Total de Testes:** 174
- **Testes Aprovados:** 174 (100%)
- **Testes Falhando:** 0
- **Análise Estática (`flutter analyze`):** 0 erros, 0 alertas no código-fonte de `lib/`.
- **Compilação Web (`flutter build web --release`):** 100% bem-sucedida.

---

## 5. Credenciais de Homologação

| Perfil | Documento / Identificador | Senha / Código | Destino / Tela |
|--------|---------------------------|----------------|----------------|
| **Administrador** | `999.888.777-66` *(ou `admin@transsaude.sp.gov.br`)* | `senhaAdmin123` *(ou `admin123`)* | Gerenciador de Horários com Drawer |
| **Motorista** | `111.222.333-44` *(ou `motorista@transsaude.sp.gov.br`)* | `senhaMotorista123` *(ou `motorista123`)* | Painel Operacional do Motorista |
| **Paciente / Acompanhante** | `123.456.789-00` *(ou `529.982.247-25`)* | `12345` *(ou `4821` / `7890`)* | Painel do Paciente com Mapa Cartográfico Real |
