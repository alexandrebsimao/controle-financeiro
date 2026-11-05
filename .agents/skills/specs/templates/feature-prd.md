# PRD: [Título da Funcionalidade]

**Metadata:**
- **Status:** [Draft | Under Review | Approved | In Progress | Completed]
- **Tipo:** Feature
- **Data:** [YYYY-MM-DD]
- **GitHub Issue:** [URL ou #Issue]
- **Autor(es):** [Nome / Agente]

---

## 1. Problema e Oportunidade
### 1.1 Declaração do Problema (Problem Statement)
Qual problema o usuário está enfrentando, a partir da perspectiva dele? Descreva a dor, o impacto no fluxo financeiro ou de navegação e as limitações da solução atual.

### 1.2 Proposta de Solução (Solution)
Como esta solução resolve o problema acima? Qual é a nova experiência ou capacidade fornecida ao usuário?

---

## 2. Personas e Cenários de Uso
- **Persona Primária:** [ex: Usuário individual gerenciando faturas e cartões]
- **Contexto:** [ex: Acessando via mobile ou desktop ao final do mês para conferir extratos]

---

## 3. Histórias de Usuário (User Stories)
> Lista detalhada e numerada de histórias no formato:
> `Como um <ator>, eu quero <funcionalidade>, para que <benefício esperado>`.

1. **Como um** usuário autenticado, **eu quero** ..., **para que** ...
2. **Como um** usuário com múltiplas contas, **eu quero** ..., **para que** ...
3. **Como um** ...

---

## 4. Critérios de Aceite (Gherkin Scenarios)

### Cenário 1: [Fluxo Principal de Sucesso]
- **Dado que** o usuário está na tela `X` com as condições `Y`
- **Quando** ele preenche `Z` e clica em salvar
- **Então** o sistema deve persistir os dados com status `A`
- **E** exibir a notificação de confirmação `B`

### Cenário 2: [Validações e Casos de Borda]
- **Dado que** ...
- **Quando** ...
- **Então** ...

---

## 5. Decisões Técnicas e Arquitetura (Implementation Decisions)
- **Modelos e Migrações:** Quais tabelas, colunas, índices e chaves estrangeiras serão criados/modificados? (Garantir constraints e índices adequados).
- **Controladores e Rotas:** Quais rotas RESTful serão adicionadas? Há novos parâmetros fortes permitidos?
- **Serviços e Domínio:** Quais Services, Query Objects ou Jobs assíncronos isolarão a lógica de negócio?
- **Ponto de Integração / Seam:** Em qual camada a funcionalidade será exposta e interceptada para testes? (Prefira o seam mais alto existente).
- **Frontend / Turbo / Stimulus:** Como a interface reagirá sem recarregar a página? Quais controllers Stimulus serão criados/alterados?

---

## 6. Estratégia de Testes (Testing Decisions)
- **Testes de Integração / Request:** Validação do fluxo ponta a ponta (status HTTP, redirecionamento, persistência real).
- **Testes Unitários de Modelo e Serviço:** Validação de regras de negócio, cálculos matemáticos, scopes e validações de dados.
- **Jobs / Assíncronos:** Teste de enfileiramento e execução isolada com Sidekiq::Testing.
- **Arte Anterior (Prior Art):** Referência a testes similares existentes no repositório.

---

## 7. Fora de Escopo (Out of Scope)
O que explicitamente **NÃO** faz parte desta entrega inicial (para evitar escopo inflado).

---

## 8. Riscos, Segurança e Desempenho
- **Segurança:** Autenticação necessária? Acesso de dados restrito ao `current_user`? Prevenção de Mass Assignment?
- **Desempenho:** Há risco de queries N+1? (Utilizar `includes` / `strict_loading`).
- **Idempotência:** O que acontece se o usuário submeter duas vezes a mesma ação?
