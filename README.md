# 🚑 TransSaúde - Gestão Integrada de Transporte Sanitário

> **Projeto Interdisciplinar - FATEC**  
> Sistema multiplataforma desenvolvido em **Flutter** com arquitetura reativa integrada ao **Cloud Firestore** e **Firebase Auth**, concebido para modernizar, digitalizar e dar transparência operacional ao Tratamento Fora de Domicílio (TFD) da saúde pública municipal.

---

## 📋 Sumário
- [Visão Geral](#-visão-geral)
- [Cenário Analógico vs. TransSaúde](#-cenário-analógico-vs-transsaúde)
- [Módulos e Funcionalidades](#-módulos-e-funcionalidades)
  - [1. Módulo do Administrador e Gestão](#1-módulo-do-administrador-e-gestão)
  - [2. Módulo do Motorista](#2-módulo-do-motorista)
  - [3. Módulo do Paciente e Acompanhante](#3-módulo-do-paciente-e-acompanhante)
  - [4. Autenticação e Segurança](#4-autenticação-e-segurança)
- [Arquitetura do Código-Fonte](#-arquitetura-do-código-fonte)
- [Credenciais de Demonstração e Homologação](#-credenciais-de-demonstração-e-homologação)
- [Bateria de Testes Automatizados](#-bateria-de-testes-automatizados)
- [Tecnologias e Dependências Principais](#-tecnologias-e-dependências-principais)

---

## 🎯 Visão Geral

O **TransSaúde** informatiza a logística diária de transporte de pacientes da rede pública municipal para consultas, exames especializados e procedimentos de alta complexidade em polos hospitalares regionais (como Hospital de Base de São José do Rio Preto, Hospital de Amor de Barretos, entre outros).

O sistema substitui formulários e pranchetas físicas por uma operação digital integrada e sincronizada em tempo real entre a **Central de Regulação da Secretaria de Saúde**, os **Motoristas Municipais** e os **Munícipes / Passageiros**.

---

## ⚖️ Cenário Analógico vs. TransSaúde

| Fluxo Tradicional (Pranchetas de Papel) | Fluxo Informatizado (TransSaúde) |
| :--- | :--- |
| **Listas impressas no início da manhã**, sujeitas a rasuras, perdas e falta de atualização quando há desistências. | **Grade digital sincronizada em tempo real** via Cloud Firestore, atualizada instantaneamente para todos os envolvidos. |
| **Falta de visibilidade da frota**, pacientes esperando sem saber se os motoristas já saíram ou estão em trânsito. | **Painel do Paciente com Mapa ao Vivo**, exibindo a posição geográfica de todos os motoristas com viagens ativas na região. |
| **Conferência manual de hodômetro e veículos**, gerando divergências em prestações de contas de combustível. | **Fluxo diário de início de viagem**, exigindo declaração do veículo disponível e registro do KM inicial no primeiro acesso. |
| **Incerteza sobre o retorno do passageiro**, causando viagens com veículos vazios ou paradas desnecessárias. | **Sinalização rápida no aplicativo** ("Estou Pronto" ou "Fui embora / Carona"), otimizando as vagas dos veículos. |
| **Fechamento burocrático de adicionais de viagem**, com compilação manual e demorada de fichas físicas. | **Geração instantânea e em lote de Relatórios em PDF** com a lista oficial de transportados, KM rodado e campo para assinatura. |

---

## 👥 Módulos e Funcionalidades

### 1. Módulo do Administrador e Gestão
Painel de controle voltado à equipe de regulação e agendamento da Secretaria de Saúde:
* **Gerenciador Diário de Horários de Saída:**
  - Navegação dia a dia com atalhos de data e seletor por calendário;
  - Painel de indicadores consolidado: total de horários, viagens ativas, planejadas, concluídas e ocupação de assentos da frota;
  - Filtros dinâmicos por texto (cidade, motorista, veículo) e por status do itinerário;
  - Criação de novos horários com validação estrita contra conflitos de agenda, sobreposição de motoristas e choque de veículos;
  - Ordenação sequencial dos pontos de embarque de passageiros e acompanhantes;
  - Duplicação em lote da grade de viagens de outro dia para otimização de rotina.
* **CRUD Completo de Pessoas (Issue #34):**
  - **Listagem Unificada:** Painel polimórfico (`ListaPessoas`) que centraliza Pacientes, Motoristas e Administradores com badges visuais temáticos e ordenados.
  - **Busca em Tempo Real:** Filtragem instantânea por Nome ou CPF insensível a maiúsculas/minúsculas.
  - **Abas de Filtros com Contadores:** Seleção rápida entre `Todos`, `Pacientes`, `Motoristas` e `Administradores`, com cálculo consolidado em passada única fora do ciclo de renderização.
  - **Cadastro e Edição Completa:** Modais dedicados para criação e atualização de registros com validações estritas de CPF, contato e papéis.
  - **Exclusão Lógica e Governança:** Diálogo de confirmação para inativação de registros (`ativo: false`), respeitando as diretrizes da LGPD e preservando a rastreabilidade histórica.
  - **Sincronização com Cloud Firestore:** Atualização automática em tempo real através da coleção `usuarios`, com fallback offline e blindagem contra anomalias de tipos.
* **Emissão de Relatórios em Lote:**
  - Exportação e download em lote de documentos PDF oficiais das viagens do dia, formatados conforme as exigências da prestação de contas do SUS.

### 2. Módulo do Motorista
Interface operacional ágil desenvolvida para uso em smartphones e tablets durante o serviço:
* **Abertura Obrigatória de Turno:**
  - No primeiro acesso do dia, o motorista declara o veículo disponível selecionado na frota e registra a quilometragem inicial do hodômetro;
  - Após iniciado, o painel assume o modo operacional em trânsito, exibindo a identificação do veículo e rota no cabeçalho.
* **Controle de Embarque e Passageiros:**
  - Lista de passageiros associados ao horário com detalhes do hospital e acompanhante;
  - Gestão de status de embarque por gestos de deslize lateral (swipe/Dismissible) em tempo real.
* **Encerramento Seguro de Viagem:**
  - Diálogo de segurança modal ("Você tem certeza que quer finalizar a viagem?") antes da conclusão do trajeto;
  - Formulário de encerramento com registro do KM de retorno, cálculo automático da distância percorrida e geração do Relatório de Viagem oficial em PDF com área para assinatura física ou digital.

### 3. Módulo do Paciente e Acompanhante
Interface clara e acessível focada no munícipe que utiliza o serviço de saúde:
* **Identificação e Consulta:** Exibição clara do nome do paciente, hospital/clínica de destino, horário agendado da consulta, endereço de saída e dados do acompanhante cadastrado.
* **Ações de Prontidão:** Botões rápidos de aviso à central ("Estou Pronto" e "Fui embora / Carona").
* **Mapa de Rastreamento em Tempo Real da Frota Ativa:**
  - Exibe a todos os pacientes a localização geográfica de **todos os motoristas municipais que estiverem em viagem ativa no momento**;
  - Pins veiculares estilizados com pulso de sinal ativo, identificação do condutor, modelo/placa do veículo e município polo de atendimento;
  - Controles de zoom interativo (+ / -) e centralização de frota;
  - Chips de seleção rápida para focar em qualquer condutor em trânsito;
  - *Em estrita conformidade com a especificação, a funcionalidade limita-se a exibir as posições ativas dos motoristas no mapa, sem realizar estimativas de tempo de chegada (ETA) e sem traçar rotas.*

### 4. Autenticação e Segurança
* **Login Unificado por Perfil:**
  - Acesso de Motoristas e Administradores via CPF ou E-mail com senha;
  - Acesso de Pacientes e Acompanhantes via CPF e Código de Acesso numérico (4 a 5 dígitos gerado pelo sistema para o Horário do dia, com validação criptográfica);
* **Guarda de Rotas (RouteGuard):** Proteção reativa contra acessos indevidos ou cruzados entre perfis (redirecionamento automático e bloqueio de navegação).

---

## 📂 Arquitetura do Código-Fonte

O projeto adota uma arquitetura limpa e modular com separação de responsabilidades em camadas no diretório `lib/`:

```text
lib/
├── components/                      # Componentes reutilizáveis de interface gráfica
│   ├── card_dados_consulta.dart     # Detalhamento médico da consulta do paciente
│   ├── card_identificacao_paciente.dart # Avatar e dados civis do paciente
│   ├── card_paciente.dart           # Card do passageiro com swipe para o motorista
│   ├── card_tracking_paciente.dart  # Mapa interativo com pins de motoristas ativos
│   ├── footer_pacientes.dart        # Rodapé de capacidade e ações de encerramento
│   ├── formulario_encerramento.dart # Modal de KM final e relatório de retorno
│   ├── formulario_inicio_viagem.dart # Declaração obrigatória de veículo e KM inicial
│   ├── motorista_header.dart        # Cabeçalho da rota do condutor
│   └── timeline_viagem.dart         # Linha do tempo visual do status do itinerário
├── models/                          # Entidades imutáveis de domínio (Data Transfer Objects)
│   ├── admin_model.dart             # Perfil do gestor municipal
│   ├── localizacao_motorista_model.dart # Coordenadas GPS e metadados da frota ativa
│   ├── motorista_model.dart         # Perfil do condutor e dados de CNH
│   ├── paciente_model.dart          # Perfil do paciente, consulta e endereço
│   ├── passageiro_viagem_model.dart # Vínculo passageiro/acompanhante na escala
│   ├── sessao_veiculo_model.dart    # Sessão diária de veículo do condutor
│   ├── user_role.dart               # Enum de papéis (admin, motorista, paciente)
│   ├── veiculo_model.dart           # Frota municipal, capacidade e hodômetro
│   └── viagem_model.dart            # Rota, horário, status e lista de passageiros
├── routes/                          # Mecanismos de roteamento e segurança
│   └── route_guard.dart             # Interceptador e guarda de rotas por perfil
├── screens/                         # Telas centrais e gerenciadores de estado
│   ├── auth_gate.dart               # Despachante reativo de sessão (Firebase Auth)
│   ├── gerenciador_viagens_screen.dart # Painel administrativo de grade de horários
│   ├── login_screen.dart            # Tela oficial unificada de login e código
│   └── preview_showcase.dart        # Rotas estáticas para visualização e testes
├── services/                        # Regras de negócio e comunicação com Firebase
│   ├── auth_service.dart            # Abstração e implementação do Firebase Auth
│   ├── codigo_acesso_service.dart   # Emissão e conferência de códigos de acesso
│   ├── localizacao_motorista_service.dart # Stream de posições dos motoristas em trânsito
│   ├── relatorio_pdf_service.dart   # Geração unitária e em lote de relatórios PDF
│   ├── validacao_viagem.dart        # Validações de conflitos de horário e capacidade
│   └── viagem_service.dart          # Ciclo de vida das viagens, sessões e frotas
├── gerenciador_viagens.dart          # Ponto de entrada do módulo de horários
├── lista_pessoas.dart                # Painel CRUD de Pessoas (Motoristas, Admins, Pacientes)
├── motorista.dart                    # Painel principal do condutor em viagem ativa
├── paciente.dart                     # Painel principal de acompanhamento do paciente
└── main.dart                         # Inicialização do app, tema Material 3 e rotas
```

---

## 🔑 Credenciais de Demonstração e Homologação

Para testes funcionais e homologação das telas:

| Perfil | Identificador / E-mail | Senha / Código | Destino no Sistema |
| :--- | :--- | :--- | :--- |
| **Administrador / Gestão** | `admin@transsaude.gov.br`<br>*(ou CPF: `111.111.111-11`)* | `admin123` | Painel do Gerenciador de Horários do Dia e CRUD de Pessoas |
| **Motorista da Saúde** | `motorista@transsaude.gov.br`<br>*(ou CPF: `222.222.222-22`)* | `motorista123` | Formulário de Início (1º acesso) ou Painel em Viagem Ativa |
| **Paciente / Acompanhante** | CPF: `123.456.789-00` | Código emitido no Horário *(ex.: `12345` / `8420`)* | Painel do Paciente com Mapa de Rastreamento ao Vivo |

---

## 🧪 Bateria de Testes Automatizados

O repositório conta com uma suíte de testes automatizados com cobertura rigorosa de regras de negócio, testes de widget e validação de responsividade multiplataforma (viewport mobile de 360x640 e desktop de 1280x800):

* **173 testes automatizados** passando com 100% de sucesso;
* Cobertura completa de:
  - Máquina de estados do `AuthGate` e redirecionamentos seguros do `RouteGuard`;
  - Responsividade e ausência de overflows de layout em telas mobile e desktop;
  - Fluxo diário do motorista: abertura de veículo/KM, swipe de passageiros, confirmação antes do encerramento e emissão do PDF;
  - Gerenciador de horários: criação com validação de conflitos, duplicação e exclusão lógica;
  - Rastreamento veicular no painel do paciente: exibição dos motoristas ativos no mapa, chips interativos e ausência estrita de estimativas de rotas/tempo;
  - Geração de relatórios PDF unitários e em lote com idempotência e atomicidade;
  - Criptografia e determinismo de códigos de acesso de passageiros.

Para executar toda a suíte de testes:
```bash
flutter test
```

---

## 🛠️ Tecnologias e Dependências Principais

* **Framework:** [Flutter](https://flutter.dev/) (Material 3 habilitado com design system uniforme);
* **Linguagem:** [Dart](https://dart.dev/);
* **Serviços Backend:** [Firebase](https://firebase.google.com/):
  - **Firebase Authentication:** Sessão de usuários e controle de credenciais;
  - **Cloud Firestore:** Sincronização NoSQL em tempo real das viagens, frotas e posições;
  - **Firebase Storage:** Repositório de documentos e relatórios;
* **Geolocalização:** `geolocator` e renderização vetorial regional via `CustomPainter`;
* **Emissão de Relatórios:** `pdf` e `printing` para geração programática e impressão de fichas TFD;
* **Internacionalização:** `intl` para formatação monetária, de datas e calendários brasileiros.
