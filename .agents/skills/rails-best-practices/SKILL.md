---
name: rails-best-practices
description: >-
  Diretrizes de arquitetura, padrões de projeto, segurança e performance para aplicações Ruby on Rails 8.
  Orienta a criação de Controllers magros, Services, Query Objects, prevenção de N+1 e boas práticas de banco de dados.
---

# Skill: Ruby on Rails 8 Best Practices

Esta skill guia o desenvolvimento de funcionalidades, refatorações e revisões dentro de aplicações Rails 8, assegurando código limpo, sustentável e de alto desempenho.

---

## 🏛️ 1. Arquitetura em Camadas

### Controllers (Skinny Controllers)
- **Função:** Apenas rotear, autenticar/autorizar, chamar camadas de domínio e renderizar views/JSON/turbo-streams.
- **Regras:**
  - Máximo de 7 actions RESTful padrão (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`). Se precisar de actions extras, crie um novo controller aninhado.
  - Parâmetros obrigatórios e seguros via Strong Parameters (`params.require(...).permit(...)`).
  - Nunca execute consultas SQL complexas ou cálculos financeiros diretamente no controller.

### Models & ActiveRecord
- Validações de presença, unicidade e regras de dados intrínsecas ao modelo.
- Relacionamentos claros com `dependent: :destroy` ou `dependent: :restrict_with_error`.
- Índices de banco de dados (`index: true`) em todas as chaves estrangeiras.
- Validação de unicidade no banco de dados através de `add_index :tabela, :campo, unique: true`.

### Services & Use Cases (`app/services`)
- Encapsule fluxos de negócio que envolvem múltiplos modelos, integrações externas (APIs de IA, gateways de pagamento) ou orquestrações complexas.
- Convenção de chamada uniforme: `Resultado = MeuService.call(params)` ou `MeuService.new(params).call`.

### Query Objects (`app/queries`)
- Isole consultas complexas, filtros dinâmicos de dashboards e relatórios fora dos models e controllers (ex: `TransactionsIndexQuery`).

---

## ⚡ 2. Performance e Banco de Dados

### Prevenção de N+1 Queries
- Sempre pré-carregue associações em listagens:
  ```ruby
  @transactions = current_user.transactions.includes(:category, :bank_account)
  ```
- No Rails 8, ative `strict_loading` em pontos críticos para capturar N+1 em tempo de desenvolvimento.

### Migrações Seguras
- Evite `default: nil` em colunas booleanas; use `default: false, null: false`.
- Sempre adicione chaves estrangeiras (`foreign_key: true`) para manter integridade referencial.

---

## 🔒 3. Segurança e Proteção de Dados

- **Escopo do Usuário:** Sempre encadeie consultas a partir do usuário autenticado:
  ```ruby
  # Correto:
  @account = current_user.bank_accounts.find(params[:id])

  # Incorreto (Vulnerabilidade IDOR):
  @account = BankAccount.find(params[:id])
  ```
- **ActiveRecord Encryption:** Para chaves de API, senhas ou tokens sensíveis no banco de dados:
  ```ruby
  class User < ApplicationRecord
    encrypts :custom_groq_api_key, :custom_gemini_api_key
  end
  ```
- **Credenciais em Produção:** Nunca insira senhas puras em arquivos versionados; utilize variáveis de ambiente (`ENV["..."]`).

---

## 🔄 4. Processamento Assíncrono (Sidekiq)

- **Parâmetros Primitivos:** Passe apenas identificadores (IDs) para os jobs, nunca instâncias completas de modelos ActiveRecord.
- **Idempotência:** Todo job deve ser seguro para ser reexecutado múltiplas vezes sem efeitos colaterais duplicados.
