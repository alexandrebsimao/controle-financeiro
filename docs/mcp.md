# 🔌 Servidor MCP (Model Context Protocol)

O **Controle Financeiro** inclui suporte nativo ao **Model Context Protocol (MCP)**, permitindo que agentes e LLMs externos (como Claude Desktop, Antigravity, Cursor, etc.) consultem e interajam de forma segura com suas finanças.

---

## 🚀 Modos de Operação

### 1. HTTP Remoto (na própria aplicação Rails)

O servidor Rails expõe o endpoint `/mcp`:

- **URL:** `POST http://localhost:3000/mcp` (ou na sua URL de produção)
- **Autenticação:** Header `Authorization: Bearer <MCP_AUTH_TOKEN>`

#### Teste com cURL:
```bash
curl -sS http://localhost:3000/mcp \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer seu_token_configurado' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
```

#### Exemplo de configuração de cliente (ex: Claude Desktop):
```json
{
  "mcpServers": {
    "finances": {
      "url": "http://localhost:3000/mcp",
      "headers": {
        "Authorization": "Bearer seu_token_configurado"
      }
    }
  }
}
```

---

### 2. Execução Local via Stdio

Se preferir rodar o servidor diretamente via linha de comando no ambiente Ruby local:

```bash
bundle exec ruby mcp/finances_server.rb
```
