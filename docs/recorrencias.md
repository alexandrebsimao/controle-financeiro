# 🔄 Sistema de Movimentações Recorrentes

O sistema de recorrências permite automatizar despesas e receitas que se repetem ao longo do tempo (como aluguel, salários, assinaturas e mensalidades).

---

## 🎯 Estratégias de Edição

Ao editar uma recorrência existente no sistema, você pode optar por duas abordagens:

### 1. Atualizar Tudo a Partir de Agora (`update_type: 'all'`)
- **Quando usar:** Ao renegociar um contrato, alterar o valor geral ou mudar a conta padrão para todos os lançamentos futuros.
- **Comportamento:**
  - Descrição, valor e categoria são propagados para todas as transações futuras ainda não pagas.
  - Altera a data base e recalcula as próximas datas de vencimento.
  - Remove transações não pagas distantes e regenera as ocorrências com a nova configuração.

### 2. Atualizar a Partir de uma Ocorrência Específica (`update_type: 'from_occurrence'`)
- **Quando usar:** Quando o valor aumentou a partir de um mês específico (ex.: reajuste anual a partir de maio).
- **Comportamento:**
  - Preserva os lançamentos gerados anteriores ao índice ou data selecionada.
  - Aplica as novas regras apenas daquela ocorrência em diante.

---

## ⚙️ Processamento em Segundo Plano

O agendador do **Sidekiq** executa periodicamente o job `GenerateRecurrencesJob` (configurado em `config/sidekiq.yml`).

Ele garante que a janela de meses futuros esteja sempre populada no banco de dados para permitir previsibilidade do fluxo de caixa e cálculo correto nas projeções financeiras da IA.
