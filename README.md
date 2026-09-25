# 🚑 TransSaúde - Gestão Integrada de Transporte Sanitário

> **Projeto Interdisciplinar - FATEC**  
> Aplicativo Android multiplataforma desenvolvido em **Flutter** integrado com **Firebase**, focado em otimizar a logística do transporte sanitário municipal, eliminando listas de papel e conectando motoristas, pacientes e administração em tempo real.

---

## 📋 Sumário
- [Sobre o Projeto](#-sobre-o-projeto)
- [Problema vs Solução](#-problema-vs-solução)
- [Frentes de Atuação (Módulos)](#-frentes-de-atuação-módulos)
  - [1. Motoristas da Saúde](#1-módulo-motoristas-da-saúde)
  - [2. Pacientes](#2-módulo-pacientes)
  - [3. Administrativo](#3-módulo-administrativo)
- [Tecnologias Utilizadas](#-tecnologias-utilizadas)
- [Arquitetura de Pastas Recomendada](#-arquitetura-de-pastas-recomendada)
- [Pré-requisitos e Instalação](#-pré-requisitos-e-instalação)
- [Configuração do Firebase](#-configuração-do-firebase)
- [Padrão de Commits e Fluxo Git](#-padrão-de-commits-e-fluxo-git)
- [Membros da Equipe](#-membros-da-equipe)

---

## 🎯 Sobre o Projeto

O **TransSaúde** nasceu para modernizar a gestão do transporte de pacientes da rede pública de saúde para consultas, exames e procedimentos em hospitais e clínicas da região. O sistema unifica as operações em tempo real através de 3 frentes de acesso (perfis de usuário), trazendo previsibilidade, transparência e agilidade tanto para quem transporta quanto para quem é transportado.

---

## ⚖️ Problema vs Solução

| Cenário Atual (Analógico / Papel) | Cenário com o TransSaúde (Digital / Tempo Real) |
| :--- | :--- |
| **Listas em pranchetas de papel** impressas no início do dia, sujeitas a rasuras, perdas e desatualização. | **Lista digital sincronizada** em tempo real via Cloud Firestore entre todos os motoristas e a central. |
| Motoristas esperam horas em pontos de encontro sem saber se o paciente já foi embora com outro veículo ou familiar. | **Status de Ida e Volta atualizado instantaneamente**; se um motorista dá a baixa, todos os demais são notificados. |
| Pacientes aguardam nas calçadas sem saber onde está a condução e que horas ela passará. | **Mapa com rastreamento ao vivo** do veículo e estimativa de tempo de chegada (ETA). |
| Pacientes que conseguem carona não têm como avisar, gerando viagens perdidas e ligações telefônicas. | **Botão "Não preciso de retorno"** no app do paciente, liberando a vaga imediatamente para outro munícipe. |
| Fechamento mensal manual e burocrático de adicionais de transporte para pagamento dos motoristas. | **Geração automática de relatório em PDF** com a lista oficial de transportados e campo de assinatura física/digital. |

---

## 👥 Frentes de Atuação (Módulos)

### 1. Módulo Motoristas da Saúde
Desenvolvido para uso dinâmico durante a condução e paradas:
* **Lista Digital de Passageiros:** Exibição detalhada de cada paciente, destino (hospital/clínica), horário da consulta e necessidades especiais de locomoção.
* **Baixa em Tempo Real (Ida e Volta):** Ao embarcar ou desembarcar o paciente, o motorista registra a baixa. Toda a frota tem ciência instantânea de quem já foi transportado, evitando ligações e esperas desnecessárias.
* **Geração de Relatório em PDF com Assinatura:** Ao término do turno/jornada, o aplicativo gera automaticamente um documento PDF consolidado contendo a relação de todos os pacientes transportados, com área para assinatura (digital na tela ou física após impressão). Este relatório é a comprovação oficial para o cálculo do **adicional por número de pacientes transportados**.

### 2. Módulo Pacientes
Interface simplificada e acessível, focada em três ações essenciais:
* **Mapa com Localização da Condução:** Rastreamento em tempo real do veículo em trânsito para saber a proximidade e o tempo estimado até o ponto de embarque.
* **Botão "Já consegui carona / Não preciso de volta":** Informa à central e aos motoristas que o paciente foi embora por meios próprios, evitando buscas e ligações desnecessárias.
* **Botão "Consulta Realizada / Disponível para Retorno":** Notifica a equipe de motoristas que o atendimento médico foi concluído e que o paciente já está aguardando no ponto para o próximo horário/veículo disponível.

### 3. Módulo Administrativo
Painel de controle para a equipe da Secretaria de Saúde:
* **Gestão Diária de Viagens:** Visualização da grade de pacientes do dia, locais de atendimento, horários agendados e alocação nas rotas.
* **Escala de Motoristas:** Controle dos motoristas ativos por turno, vinculando-os aos veículos disponíveis.
* **Cadastros (CRUD):** Inserção, edição e importação de dados de pacientes (endereço, telefone, local habitual de consulta) e motoristas (CNH, contato, veículo).

---

## 🛠️ Tecnologias Utilizadas

- **Linguagem & Framework:** [Dart](https://dart.dev/) / [Flutter](https://flutter.dev/) (Alvo principal: Android)
- **Backend as a Service (BaaS):** [Firebase](https://firebase.google.com/)
  - **Firebase Authentication:** Controle de acesso seguro e papéis de usuário (Motorista, Paciente, Admin).
  - **Cloud Firestore:** Banco NoSQL com sincronização em tempo real das listas e status.
  - **Firebase Storage:** Armazenamento seguro dos relatórios PDF gerados.
  - **Firebase Cloud Messaging (FCM):** Notificações push para avisos de chegada e alertas de carona.
- **Geolocalização & Mapas:** `geolocator` e `google_maps_flutter` (ou `flutter_map` / OpenStreetMap).
- **Relatórios & PDF:** Pacotes `pdf` e `printing` para geração e compartilhamento de relatórios assináveis.
- **Gerenciamento de Estado:** Provider / Riverpod / Bloc (a definir pela equipe).

---

## 📂 Arquitetura de Pastas Recomendada

Organização baseada em recursos (*Feature-First*), ideal para equipes de 4 pessoas trabalharem em paralelo sem gerar conflitos de merge:

```text
lib/
├── core/                       # Componentes globais e compartilhados
│   ├── constants/              # Cores, estilos, constantes de API
│   ├── theme/                  # Configuração de temas claro e escuro
│   ├── utils/                  # Formatadores (datas, CPF, telefone)
│   └── widgets/                # Botões, inputs e cards reutilizáveis
├── features/                   # Módulos organizados por frente de trabalho
│   ├── auth/                   # Telas de login, cadastro e controle de perfis
│   ├── motorista/              # Lista de passageiros, baixas de ida/volta e PDF
│   │   ├── models/
│   │   ├── controllers/
│   │   ├── views/
│   │   └── services/           # Serviço de exportação de PDF com assinatura
│   ├── paciente/               # Mapa ao vivo, botão de carona e retorno
│   │   ├── controllers/
│   │   ├── views/
│   │   └── services/
│   └── admin/                  # Gestão de viagens do dia, turnos e cadastros
│       ├── controllers/
│       ├── views/
│       └── services/
├── services/                   # Serviços de infraestrutura (Firebase, GPS)
│   ├── firebase_auth_service.dart
│   ├── firestore_service.dart
│   └── location_service.dart
└── main.dart                   # Ponto de entrada da aplicação
```

---

## 💻 Pré-requisitos e Instalação

### Requisitos da Máquina:
- **Flutter SDK:** >= 3.x ([Guia oficial de instalação](https://docs.flutter.dev/get-started/install))
- **Java JDK:** OpenJDK 17
- **Android Studio / Android SDK:** com ferramentas de linha de comando e emulador configurado (ou smartphone Android físico com depuração USB ativada)
- **VS Code:** com extensões oficiais do Dart e Flutter instaladas
- **Git:** instalado e configurado

### Executando o Projeto:

1. **Clone o repositório:**
   ```bash
   git clone <URL_DO_REPOSITORIO_GITHUB>
   cd Interdisciplinar
   ```

2. **Instale as dependências do Flutter:**
   ```bash
   flutter pub get
   ```

3. **Conecte um dispositivo Android ou inicie um emulador:**
   ```bash
   flutter devices
   ```

4. **Inicie o aplicativo em modo de depuração:**
   ```bash
   flutter run
   ```

---

## 🔥 Configuração do Firebase

Para que o aplicativo se conecte ao Firebase:
1. Um integrante da equipe cria o projeto no [Console do Firebase](https://console.firebase.google.com/).
2. Ativação dos serviços:
   - **Authentication:** Ativar provedor de Email/Senha.
   - **Firestore Database:** Criar base no modo de teste ou configurar regras de segurança por perfil.
   - **Storage:** Ativar bucket de armazenamento para os PDFs.
3. Obtenção do arquivo `google-services.json` no console do Firebase (Configurações do Projeto > Seus aplicativos Android).
4. Posicione o arquivo em: `android/app/google-services.json` *(observar as diretrizes de segurança no `.gitignore`)*.
5. Alternativamente, utilize o comando oficial:
   ```bash
   flutterfire configure
   ```

---

## 🤝 Padrão de Commits e Fluxo Git

Este projeto segue o padrão internacional de **Conventional Commits** e fluxo de trabalho em equipe com branches protegidas.  
Antes de enviar qualquer código, consulte o nosso guia detalhado:

👉 **[Leia o Guia de Contribuição e Padrões de Commit (CONTRIBUTING.md)](CONTRIBUTING.md)**

Resumo rápido dos tipos de commit:
- `feat(modulo):` nova funcionalidade
- `fix(modulo):` correção de erro
- `docs:` melhorias na documentação
- `style:` ajustes de formatação e lint
- `refactor:` melhoria de código sem alterar regra de negócio

### ⚠️ Regras de Integração e Pull Request:
- **NUNCA dê push direto na `develop` ou `main`:** É proibido push direto. Todo código entra exclusivamente via PR a partir da sua branch.
- **Só abra a PR se tiver certeza absoluta do que fez:** Teste a tela/funcionalidade localmente e rode `flutter analyze`. Não abra PR com código não testado ou incompleto.
- **Sempre abra uma Pull Request (PR) direcionada para `develop`:** Após commitar na sua branch e dar `git push`, abra a PR para `develop` para revisão em equipe.
- **Informe se a branch deve ser deletada ou mantida:** Na descrição do PR, deixe explícito se a branch pode ser excluída após o merge ou se você ainda continuará trabalhando nela.
- **Padrão para commit de merge da PR:**
  ```text
  merge(<escopo>): <descrição sucinta da entrega> (PR #<número>)
  ```
- **Como vai para a `main` (Produção)?** No fechamento da versão estável/sprint, abre-se uma PR de Release: `develop` $\rightarrow$ `main` com commit `release(sprint-X): ...`.

---

## 👨‍💻 Membros da Equipe

Projeto desenvolvido para o Trabalho Interdisciplinar do curso de Tecnologia em Análise e Desenvolvimento de Sistemas / Gestão de TI da **FATEC**:

1. **Integrante 1** - *Responsável pelo Módulo do Motorista & Relatórios PDF*
2. **Integrante 2** - *Responsável pelo Módulo do Paciente & Geolocalização/Mapas*
3. **Integrante 3** - *Responsável pelo Módulo Administrativo & Regras de Negócio*
4. **Integrante 4** - *Responsável pelo Backend (Firebase), Autenticação & Infraestrutura*
