# 💰 Controle Financeiro

> Sistema moderno e completo de **Gestão Financeira Pessoal e Familiar** construído com **Ruby on Rails 8**, **Tailwind CSS**, **PostgreSQL**, **Sidekiq** e **Inteligência Artificial (Groq / Google Gemini)**.

---

## 🌟 Funcionalidades Principais

- 📊 **Dashboard Interativo:** Saldo consolidado, receitas vs despesas, gráficos mensais e visão rápida de movimentações pendentes.
- 🏦 **Múltiplas Contas Bancárias:** Gestão de diferentes bancos, carteiras e contas de investimento com saldos em tempo real.
- 💳 **Gestão Completa de Cartões de Crédito:** Controle de limites, faturas abertas/fechadas, parcelamentos automáticos e projeções futuras.
- 🔁 **Movimentações Recorrentes:** Agendamento flexível de despesas e receitas periódicas (mensal, anual, semanal) com geração automática de parcelas.
- 🏷️ **Categorias Hierárquicas & Auto-categorização:** Organização com categorias pai e subcategorias, além de palavras-chave para classificação automática.
- 🤖 **Consultoria Financeira com IA:** Análise inteligente de fluxo de caixa, sugestões de cortes e projeções de endividamento usando **Groq (Llama 3)** ou **Google Gemini**.
- 📥 **Importação Inteligente de Extratos:** Importação de extratos bancários em formatos **CSV** e **PDF** com tela de validação e de/para antes da confirmação.
- 📧 **Alertas de Vencimento por E-mail:** Job automatizado com envio de resumos diários de contas a vencer via **Resend**.
- 🔌 **Servidor MCP Integrado:** Conecte facilmente assistentes de IA (Claude Desktop, Cursor, etc.) diretamente aos seus dados via **Model Context Protocol**.

---

## 🛠️ Stack Tecnológica

| Camada | Tecnologia |
| :--- | :--- |
| **Backend** | Ruby 3.4.1, Rails 8.1, Puma |
| **Frontend** | Tailwind CSS, Stimulus.js, Turbo / Hotwire |
| **Banco de Dados** | PostgreSQL 14+ |
| **Filas & Cache** | Redis 7+, Sidekiq |
| **Inteligência Artificial** | Groq API, Google Gemini API |
| **Disparo de E-mails** | Resend API |
| **Containerização** | Docker & Docker Compose |

---

## 🚀 Como Executar

### Opção 1: Via Docker Compose (Recomendado)

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/seu-usuario/controle-financeiro.git
   cd controle-financeiro
   ```

2. **Copie o arquivo de variáveis de ambiente:**
   ```bash
   cp .env.example .env
   ```

3. **Inicie os containers:**
   ```bash
   docker compose up -d --build
   ```

4. **Prepare o banco de dados:**
   ```bash
   docker compose exec web bundle exec rails db:prepare
   docker compose exec web bundle exec rails db:seed
   ```

5. **Acesse no navegador:**
   - Aplicação: [http://localhost:3000](http://localhost:3000)
   - Painel Sidekiq: [http://localhost:3000/sidekiq](http://localhost:3000/sidekiq)

---

### Opção 2: Instalação Local (Sem Docker)

Consulte o [Guia Completo de Instalação Local](docs/instalacao.md) para detalhes sobre configuração passo a passo com Ruby, PostgreSQL e Redis instalados na máquina.

---

## ⚙️ Variáveis de Ambiente Principais

Copie `.env.example` para `.env` e configure conforme necessário:

| Variável | Descrição | Padrão |
| :--- | :--- | :--- |
| `DATABASE_HOST` | Host do banco de dados | `localhost` / `db` |
| `DATABASE_USER` | Usuário do PostgreSQL | `postgres` |
| `DATABASE_PASSWORD` | Senha do PostgreSQL | `postgres` |
| `REDIS_URL` | URL de conexão com o Redis | `redis://localhost:6379/0` |
| `RESEND_API_KEY` | Chave de envio de e-mails (Resend) | Opcional em desenvolvimento |
| `AI_PROVIDER` | Motor de IA padrão (`groq` ou `gemini`) | `groq` |
| `GROQ_API_KEY` | Chave de API da plataforma Groq | Opcional |
| `GEMINI_API_KEY` | Chave de API do Google Gemini | Opcional |
| `MCP_AUTH_TOKEN` | Token de segurança para o endpoint MCP | Opcional |

---

## 📚 Documentação Adicional

- [Guia de Instalação e Execução](docs/instalacao.md)
- [Arquitetura e Entidades do Sistema](docs/funcionalidades.md)
- [Como Funcionam as Recorrências](docs/recorrencias.md)
- [Configuração de Notificações por E-mail](docs/notificacoes-email.md)
- [Servidor Model Context Protocol (MCP)](docs/mcp.md)

---

## 📄 Licença

Este projeto está sob a licença [MIT](LICENSE).
