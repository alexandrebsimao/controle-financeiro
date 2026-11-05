# 🛠️ Guia de Instalação e Execução

Este guia detalha como executar o **Controle Financeiro** em seu ambiente, seja usando **Docker Compose** (recomendado para inicialização rápida) ou rodando os serviços diretamente na sua máquina local.

---

## 📋 Pré-requisitos

### Opção 1: Via Docker (Mais Simples)
- [Docker](https://docs.docker.com/get-docker/) e [Docker Compose](https://docs.docker.com/compose/) instalados.

### Opção 2: Instalação Nativa
- **Ruby:** `3.4.1` (gerenciado via rbenv, asdf, mise ou chruby)
- **Node.js:** `v20+` e **npm** `10+`
- **PostgreSQL:** `14+`
- **Redis:** `7+`

---

## 🐳 Executando com Docker Compose

Esta é a forma mais rápida de iniciar o ecossistema completo (Rails + PostgreSQL + Redis + Sidekiq):

1. **Clone o repositório:**
   ```bash
   git clone <URL_DO_REPOSITORIO> controle-financeiro
   cd controle-financeiro
   ```

2. **Crie o arquivo de ambiente `.env`:**
   ```bash
   cp .env.example .env
   ```

3. **Inicie os serviços:**
   ```bash
   docker compose up -d --build
   ```

4. **Prepare o banco de dados (na primeira execução):**
   ```bash
   docker compose exec web bundle exec rails db:prepare
   docker compose exec web bundle exec rails db:seed # opcional: carrega categorias padrão
   ```

5. **Acesse no navegador:**
   - **Aplicação:** [http://localhost:3000](http://localhost:3000)
   - **Painel Sidekiq:** [http://localhost:3000/sidekiq](http://localhost:3000/sidekiq)

---

## 💻 Executando Localmente (Sem Docker)

### 1. Clonar e Configurar Variáveis
```bash
git clone <URL_DO_REPOSITORIO> controle-financeiro
cd controle-financeiro
cp .env.example .env
```
Edite o arquivo `.env` com suas credenciais do PostgreSQL local e chaves de API desejadas.

### 2. Instalar Dependências Ruby e JavaScript
```bash
# Dependências de Gems
bundle install

# Dependências JavaScript
npm install
```

### 3. Configurar Banco de Dados
Certifique-se de que o serviço do PostgreSQL e do Redis estão rodando:
```bash
# Cria o banco, roda as migrações e insere dados iniciais
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed
```

### 4. Inicializar a Aplicação
O projeto utiliza o script `./bin/dev` para subir simultaneamente o servidor Rails, o compilador do TailwindCSS e o Sidekiq:

```bash
./bin/dev
```

Acesse: **http://localhost:3000**

---

## 🧪 Executando os Testes

Para garantir a integridade do código e das regras de negócio:

```bash
# Roda toda a suíte de testes
bundle exec rails test

# Análise estática de segurança e código
bundle exec brakeman --no-pager
bundle exec rubocop
```
