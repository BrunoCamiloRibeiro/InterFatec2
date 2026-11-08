# RELATÓRIO FINAL DE ENTREGA: ISSUE #65
## Gerenciador de Horários (Viagens), Correção do Login e Verificação Integrada

---

### INFORMAÇÕES GERAIS
- **Repositório:** `BrunoCamiloRibeiro/InterFatec2`
- **Branch de Trabalho:** `65-correção-de-bugs`
- **Responsável:** Equipe de Engenharia / Antigravity Agent
- **Data:** 07 de Novembro de 2026
- **Status do Projeto:** ✅ 100% Concluído e Testado (164/164 testes automatizados aprovados)

---

## 1. DECISÕES DE ARQUITETURA E MODELO DE DADOS

### 1.1 Vocabulário Institucional e Equivalência Técnica
Na interface do usuário (UI), a entidade de viagem passa a ser denominada exclusivamente como **"Horário"** (ex.: *"Gerenciador de Horários"*, *"Horários de Saída"*, *"Novo Horário"*, *"Duplicar Horários de outro dia"*).
No código-fonte, a equivalência foi mantida sobre o `ViagemModel` preexistente, complementado por campos operacionais (`nomeHorario`, `dataViagem`, `passageiros`), preservando compatibilidade retroativa com os fluxos de Declaração de Veículo pelo Motorista, Roteiro PDF em Lote e Código de Acesso do Paciente.

### 1.2 Modelo de Dados: Horário por Dia com Duplicação
- **Decisão:** Optou-se pela criação direta de Horários por dia da escala (`ViagemModel` com `dataViagem`), acompanhada de funcionalidade ágil de **"Duplicar Horários de outro dia"**, em vez de um modelo abstrato complexo de "grade fixa recorrente".
- **Justificativa Técnica:** O modelo direto atende com simplicidade e precisão ao fluxo da saúde pública de Poloni (onde destinos, veículos e pacientes variam semanalmente conforme demandas da DRS e do Hospital de Amor), sem criar tabelas adicionais no Firestore e permitindo que o motorista declare o veículo e encontre imediatamente suas viagens agendadas para a data do dia.
- **Relação com Pessoas e Veículos:** Os passageiros são modelados via `PassageiroViagemModel`, referenciando por chave estrangeira (ID) os registros já cadastrados na base de Pessoas (Feita pelo João - PR #64) e Veículos (Feita pela Audrey - PR #63). **Não há recadastramento ou duplicação de entidades**.

---

## 2. CAUSA RAIZ E CORREÇÃO DO LOGIN DE MOTORISTA E ADMINISTRADOR

### 2.1 Diagnóstico Comprovado
A classe `FirebaseAuthService` mantinha a variável estática `_pacienteLogadoId`, preenchida durante a autenticação de pacientes ou acompanhantes por CPF e código de 4 a 5 dígitos.
Quando um motorista ou administrador tentava subsequentemente realizar login por e-mail/senha ou CPF/senha:
1. A variável estática `_pacienteLogadoId` não era redefinida como nula no início do método `login(...)` nem no método `logout()`.
2. O getter `currentUserId` priorizava `_pacienteLogadoId ?? _auth.currentUser?.uid`.
3. Ao navegar para as rotas protegidas `/motorista` ou `/administrativo`, o `RouteGuard` resolvia o papel do usuário utilizando `currentUserId` (que apontava para o paciente anterior).
4. O usuário era identificado como tendo o papel `UserRole.paciente`, resultando no bloqueio da rota operacional e no redirecionamento forçado para a tela do paciente.

### 2.2 Correções Implementadas
1. **Purga Incondicional de Sessão:** `_pacienteLogadoId = null;` foi adicionado como primeira instrução no método `login(...)` e dentro do método `logout()` de `FirebaseAuthService`.
2. **Rate Limiting Operacional:** Implementado mecanismo de contenção de ataques de força bruta no login com senha (5 tentativas incorretas bloqueiam o usuário temporariamente por 15 minutos com o código `rate-limit-exceeded`).
3. **Respostas Seguras:** Mensagens genéricas de erro (`Credenciais inválidas. Verifique os dados digitados e tente novamente.`) para impedir enumeração de usuários.
4. **Isolamento de Log e LGPD:** Nenhuma credencial ou dado civil sensível é registrado em texto plano no console.

---

## 3. REGRAS DE NEGÓCIO E CASOS DE BORDA IMPLEMENTADOS

| Caso de Borda | Regra Implementada | Comportamento e Teste |
| :--- | :--- | :--- |
| **1. Conflito de Motorista** | Motorista não pode ter 2 horários simultâneos no mesmo dia | `validarConflitoMotorista` detecta sobreposição de horário no mesmo dia e rejeita a criação/edição. |
| **2. Conflito de Veículo** | Veículo não pode ter 2 horários simultâneos no mesmo dia | `validarConflitoVeiculo` detecta se a mesma placa foi alocada em horários coincidentes e bloqueia. |
| **3. Lotação e Acompanhante** | Capacidade máxima do veículo respeitada | Cada acompanhante ocupa 1 assento adicional (`totalAssentos = pacientes + acompanhantes`). Rejeita criação com mensagem clara se exceder. |
| **4. Conflito de Paciente** | Paciente não pode estar em dois horários no mesmo dia | `validarConflitoPaciente` impede agendamento simultâneo do mesmo paciente em múltiplas rotas conflitantes. |
| **5. Horário de Consulta** | Consulta deve ser posterior ao horário de saída do veículo | `validarCompatibilidadeHorarioConsulta` compara o horário previsto do atendimento com a saída da van/ambulância. |
| **6. Cancelamento Lógico** | Exclusão suave (soft delete) com invalidação de código | Ao cancelar um horário, `status = 'cancelada'` é atribuído. Códigos de acesso são limpos para impedir logins em viagens canceladas. |
| **7. Paciente sem CPF** | Respeito à decisão de ignorar no app e alertar admin | Paciente sem CPF consta na lista física e no itinerário do motorista, mas exibe alerta âmbar no card alertando a impossibilidade de login no app. |
| **8. Fuso e Virada de Dia** | Fuso de referência America/Sao_Paulo | Normalização de datas via `dataOperacional` (ano, mês, dia) sem ruídos de timezone UTC na separação de escalas. |

---

## 4. O QUE FICOU FORA / LIMITAÇÕES DEFINIDAS

1. **Cadastro Inline de Novas Pessoas no Modal de Horário:** Por determinação da arquitetura, manteve-se estritamente o reuso de pessoas e veículos cadastrados previamente pelos CRUDs de Pessoas e Veículos. Se um paciente não constar na lista, o admin deve cadastrá-lo no módulo de Pessoas.
2. **Exclusão Física (Hard Delete) de Viagens com Passageiros:** Viagens com histórico ou passageiros vinculados apenas podem ser canceladas logicamente, garantindo auditoria e integridade de dados.

---

## 5. EVIDÊNCIAS DE TESTES AUTOMATIZADOS

A suíte completa do projeto conta com **164 testes**, todos executados com sucesso (`All tests passed!`).

```text
00:14 +159: test/caracterizacao_fase0_novos_test.dart: 1. Geração de código de acesso é determinística em hash e idempotente
00:14 +160: test/caracterizacao_fase0_novos_test.dart: 2. Login de paciente/acompanhante por CPF e código funciona com viagem ativa
00:14 +161: test/caracterizacao_fase0_novos_test.dart: 3. Geração em lote de PDFs compila atomica e idempotentemente
00:14 +162: test/caracterizacao_fase0_novos_test.dart: 4. Reprodução: Efeito colateral de _pacienteLogadoId contamina sessão do motorista
00:14 +163: test/caracterizacao_fase0_novos_test.dart: 5. Reprodução: Efeito colateral de _pacienteLogadoId contamina sessão do administrador
00:14 +164: test/fluxo_integracao_completo_test.dart: Ciclo integral da operação: Admin -> Motorista -> Declaração -> Embarque -> Código -> Paciente/Acomp -> PDF em Lote
00:14 +164: All tests passed!
```

- **Caracterização Fase 0:** 5 testes passando
- **Gerenciador de Horários & Casos de Borda:** 11 testes passando
- **Autenticação, Rate Limit & RBAC:** 7 testes passando
- **Responsividade Web Mobile (360x640) & Desktop:** 3 testes passando (zero RenderFlex overflow)
- **Fluxo Integrado E2E:** 2 testes passando
- **Suíte Legada e Componentes Preexistentes:** 136 testes mantidos 100% íntegros

---

## 6. ROTEIRO DE HOMOLOGAÇÃO MANUAL (GUIA RÁPIDO PARA ADMIN E MOTORISTA)

### 6.1 Teste do Administrador
1. **Login:** Acesse a aplicação na tela de login, selecione a aba **Administrador**, informe o CPF e a senha.
2. **Acesso ao Gerenciador:** No painel administrativo, clique no botão **"Gerenciar Horários de Viagens"**.
3. **Criação de Horário:**
   - Clique no botão flutuante **"+"** (*Novo Horário*).
   - Preencha o nome do horário (ex.: `06:00 - Barretos`), selecione a Spin e o Motorista.
   - Clique em **"Adicionar Passageiro"**, escolha um paciente da lista e informe o horário de consulta (ex.: `09:00`).
   - Salve o horário.
4. **Verificação do Card:** Observe o card do horário com badge azul `PLANEJADA`, contadores de assento e lista de passageiros.
5. **Ação de Duplicação:** Clique em **"Duplicar de outro dia"**, escolha a data de origem e confirme a replicação para hoje.

### 6.2 Teste do Motorista
1. **Login:** Na tela de login, selecione a aba **Motorista**, informe o CPF e a senha.
2. **Verificação de Horários Atribuídos:** Na tela inicial do motorista, confira os horários planejados para o seu perfil no dia de hoje.
3. **Declaração de Veículo:**
   - Selecione a Spin e informe o odômetro inicial (ex.: `50000 km`).
   - Confirme a declaração; a viagem passa para o status `ativa`.
4. **Embarque e Código:**
   - Na lista de passageiros, realize a baixa de embarque.
   - O código numérico de 4 a 5 dígitos é gerado e exibido para entrega ao paciente.
5. **Geração de PDF:** Ao finalizar o dia, gere o lote de relatórios PDF com todas as viagens realizadas.

### 6.3 Teste do Paciente / Acompanhante
1. **Login com Código:** Na tela de login, selecione a aba **Paciente**, digite o CPF e o código numérico de 4 ou 5 dígitos fornecido pelo motorista.
2. **Painel do Paciente:** Confirme o acesso à tela com os detalhes da consulta, motorista responsável e itinerário.
