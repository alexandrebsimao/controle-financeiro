# Padrões de Código e Convenções do Projeto (Ruby on Rails 8)

Ao trabalhar neste repositório, siga estritamente estas diretrizes:

## 1. Arquitetura e Organização
- **Controllers:** Mantenha controllers enxutos (skinny controllers). Apenas receba parâmetros, autorize, delegue para services/queries e responda.
- **Services:** Lógica de negócio que envolva mais de um modelo ou chamadas a APIs (Groq, Gemini, Resend) deve residir em `app/services/`.
- **Query Objects:** Filtros complexos e listagens do dashboard/relatórios devem residir em `app/queries/`.
- **Rotas:** Mantenha rotas RESTful idiomáticas.

## 2. Banco de Dados e ActiveRecord
- **Prevenção de N+1:** Listagens com associações em views devem sempre utilizar `includes(...)` ou `preload(...)`.
- **Índices:** Toda migração que adiciona foreign keys ou colunas com filtros frequentes deve conter índice.
- **Validações no Banco:** Sempre adicione `null: false` e `unique: true` no banco quando a regra de negócio exigir.
- **Segurança de Acesso:** Sempre consulte registros a partir do `current_user` (ex: `current_user.transactions.find(id)`) para impedir vulnerabilidades de IDOR.

## 3. Background Jobs (Sidekiq)
- Jobs devem receber tipos primitivos (IDs) e recarregar a instância dentro do `perform`.
- Todo job deve ser projetado de forma idempotente.

## 4. Estilo e Linters
- Respeite as regras do `.rubocop.yml`.
- Execute `bundle exec brakeman --no-pager` e `bundle exec rubocop` antes de concluir alterações.
