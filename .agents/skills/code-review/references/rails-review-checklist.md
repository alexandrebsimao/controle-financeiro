# Ruby on Rails 8 - Code Review Checklist

Checklist de boas práticas e convenções para validação de diffs em aplicações Rails modernas:

---

## 1. Controllers & Rotas
- [ ] **Skinny Controllers:** Os controladores apenas coordenam a requisição (autenticam, autorizam, chamam services/queries e renderizam). Nenhuma regra de negócio pesada ou loops de processamento residem nas actions.
- [ ] **Strong Parameters:** Todos os parâmetros de escrita passam por `permit(...)` explícito. Nunca use `params.permit!` ou acesse parâmetros crus para persistência.
- [ ] **Restrição de Escopo de Usuário:** Queries de alteração/exibição partem de `current_user.recurso` (ex: `current_user.bank_accounts.find(...)`), impedindo IDOR (Insecure Direct Object References).

## 2. Models & Banco de Dados
- [ ] **Índices em Chaves Estrangeiras:** Toda migração que adiciona uma `foreign_key` ou `reference` deve garantir índice no banco (`index: true`).
- [ ] **Constraints no Banco:** Unicidade e presença crítica devem ser validadas no banco de dados (`null: false`, `unique: true`), não apenas no ActiveRecord.
- [ ] **Prevenção de N+1 Queries:** Loops em views ou serializers que acessam associações usam `includes(...)`, `preload(...)` ou `strict_loading`.
- [ ] **ActiveRecord Encryption:** Chaves secretas, tokens de API ou dados sensíveis de terceiros usam `encrypts :campo` em vez de texto puro.

## 3. Background Jobs (Sidekiq)
- [ ] **Parâmetros Primitivos:** Jobs recebem IDs (strings/inteiros) e recarregam o registro no `perform`. Nunca passe objetos ActiveRecord serializados.
- [ ] **Idempotência:** A execução do job pode ser repetida em caso de falha sem duplicar pagamentos, transações ou cobranças.

## 4. Frontend & Hotwire / Turbo
- [ ] **Turbo Frames & Streams:** Respostas parciais usam turbo-streams limpos sem poluir o DOM.
- [ ] **Stimulus Controllers:** Nomes consistentes, manipulação limpa de eventos no ciclo `connect()` / `disconnect()`, sem seletores globais descontrolados (`document.querySelector`).

## 5. Testes & Qualidade
- [ ] **Testes de Comportamento:** Testes cobrem o comportamento externo e casos de borda reais, sem mockar excessivamente o ActiveRecord interno.
- [ ] **Sem Vulnerabilidades Estáticas:** O diff não introduz avisos no `brakeman` ou no `rubocop`.
