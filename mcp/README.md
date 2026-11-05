# Finances MCP

Servidor MCP local para apoiar importacao, analise, de/para e sincronizacao de extratos bancarios deste projeto Rails.

## HTTP remoto na app Rails

O endpoint remoto fica em:

```text
POST /mcp
```

Configure um token longo no seu arquivo `.env`:

```bash
MCP_AUTH_TOKEN="gere-um-token-longo-aqui"
```

Depois reinicie o container/app Rails. O cliente MCP deve enviar:

```text
Authorization: Bearer gere-um-token-longo-aqui
```

Teste basico:

```bash
curl -sS https://seu-dominio.com/mcp \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer gere-um-token-longo-aqui' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
```

Exemplo de configuracao para cliente que aceita MCP remoto:

```json
{
  "server_url": "https://seu-dominio.com/mcp",
  "headers": {
    "Authorization": "Bearer gere-um-token-longo-aqui"
  }
}
```

Se o cliente so oferecer OAuth ou "sem autenticacao", escolha "sem autenticacao" e coloque o token na URL:

```text
https://seu-dominio.com/mcp?token=gere-um-token-longo-aqui
```

Esse modo ainda valida `MCP_AUTH_TOKEN` no Rails. A diferenca e que o segredo vai na URL em vez do header.

## Comando stdio local

Em um ambiente Ruby compatível com o projeto:

```bash
bundle exec ruby mcp/finances_server.rb
```

Se voce usa Docker Compose para rodar a app:

```bash
docker compose exec -T web bundle exec ruby mcp/finances_server.rb
```

O servidor usa stdio, entao o comando acima deve ser cadastrado no cliente MCP que voce usa.

## Ferramentas

- `finances_context`: lista usuario, contas bancarias, categorias, palavras-chave e metodos de pagamento.
- `analyze_statement_csv`: le um CSV dentro do diretorio do projeto, normaliza as linhas, sugere categorias e calcula totais sem gravar nada.
- `suggest_de_para`: agrupa descricoes do CSV e sugere palavras-chave para regras de categoria.
- `upsert_de_para_keyword`: cria ou atualiza uma palavra-chave de categoria para o de/para.
- `import_statement_csv`: cria `Transaction` com `idempotency_key` para evitar duplicidade. Rode primeiro com `dry_run: true`.

## Exemplo de argumentos

```json
{
  "user_email": "voce@example.com",
  "bank_account_id": 1,
  "file_path": "imports/nubank.csv",
  "col_sep": ";",
  "mapping": {
    "date": "Data",
    "title": "Descricao",
    "amount": "Valor"
  },
  "dry_run": true
}
```

Quando o banco exportar debito e credito em colunas separadas, use:

```json
{
  "mapping": {
    "date": "Data",
    "title": "Historico",
    "debit": "Debito",
    "credit": "Credito"
  }
}
```

Exemplo para gravar uma regra de de/para:

```json
{
  "user_email": "voce@example.com",
  "category_id": 12,
  "keyword": "mercado pago",
  "match_type": "contains",
  "priority": 10
}
```

## Regras atuais

- Apenas arquivos dentro do diretorio do projeto sao lidos.
- Valores negativos viram `expense`; valores positivos viram `income`.
- Transacoes importadas entram como pagas (`paid: true`) na data do extrato.
- A categoria e sugerida/reaproveitada pelo `AutoCategorizationService` existente.
- A importacao usa `Transaction.idempotency_key`, entao reprocessar o mesmo CSV nao duplica linhas ja criadas.
