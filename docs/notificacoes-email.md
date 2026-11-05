# 📧 Notificações de Vencimento por E-mail

O sistema conta com um serviço automatizado para alertar os usuários sobre contas a vencer nos próximos dias ou já em atraso.

---

## 🛠️ Como Funciona

1. **Job Diário:** O Sidekiq roda o `DueTransactionsNotificationJob` diariamente às 09:00 (ou horário configurado em `config/sidekiq.yml`).
2. **Serviço de Varredura:** O `DueTransactionsService` analisa as contas não pagas de cada usuário em 4 janelas:
   - Contas que vencem em **5 dias**
   - Contas que vencem em **3 dias**
   - Contas que vencem **hoje**
   - Contas já **vencidas e não pagas**
3. **Disparo do E-mail:** Se houver pendências, um e-mail estruturado é disparado através da API do **Resend**.

---

## ⚙️ Configuração

Adicione as variáveis ao seu arquivo `.env`:

```env
# Chave de API da Resend (https://resend.com)
RESEND_API_KEY=re_sua_chave_aqui

# Endereço remetente verificado no seu domínio
MAILER_DEFAULT_FROM=financeiro@seu-dominio.com

# Host da aplicação para gerar os links dentro do e-mail
APP_HOST=app.seu-dominio.com
```

---

## 🧪 Testando o Envio Manualmente

Você pode forçar a execução do job via console do Rails:

```ruby
# No console: rails c
DueTransactionsNotificationJob.perform_now
```

Ou executar a tarefa Rake dedicada:

```bash
bundle exec rails due_transactions:notify
```
