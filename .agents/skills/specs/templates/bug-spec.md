# Bug Spec: [Título do Bug / Erro]

**Metadata:**
- **Status:** [Triaged | In Investigation | Root Cause Found | Fixed | Verified]
- **Tipo:** Bug
- **Severidade:** [Crítica / Alta / Média / Baixa]
- **Data:** [YYYY-MM-DD]
- **GitHub Issue:** [URL ou #Issue]
- **Autor(es):** [Nome / Agente]

---

## 1. Descrição do Problema
### 1.1 Sintoma Observado pelo Usuário
O que acontece exatamente? Inclua mensagem de erro, traceback, status HTTP inesperado ou discrepância de valores.

### 1.2 Comportamento Esperado
O que deveria ter ocorrido de acordo com as regras de negócio?

### 1.3 Ambiente e Contexto
- Ambiente afetado: [Desenvolvimento / Produção / Testes]
- Parâmetros envolvidos: [Dados da requisição, usuário, headers, etc.]

---

## 2. Reprodução Mínima (Minimal Repro)
Passo a passo mínimo para disparar a falha com 100% de consistência:
1. ...
2. ...
3. ...

---

## 3. Loop de Feedback Automatizado (Tight Red-Capable Loop)
> Comando único, rápido e determinístico que reproduz o erro (falha antes da correção, passa após a correção):

```bash
# Exemplo: teste automatizado ou comando curl
bundle exec rails test test/models/transaction_test.rb:45
```

- [ ] **Red-capable comprovado:** O comando falhou ao ser executado na branch atual.
- [ ] **Determinístico:** Executa em segundos sem depender de estado volátil.

---

## 4. Hipóteses Ranqueadas de Causa Raiz
Liste de 3 a 5 hipóteses falsificáveis antes de alterar código:

1. **Hipótese 1:** Se a causa for [X], então ao alterar [Y] o bug deve sumir porque [Z].
2. **Hipótese 2:** ...
3. **Hipótese 3:** ...

---

## 5. Causa Raiz Confirmada (Root Cause Analysis)
Qual hipótese foi confirmada através de instrumentação ou testes e por que a falha aconteceu?

---

## 6. Plano de Correção e Teste de Regressão
- **Costura / Seam Correto:** Em qual camada o teste de regressão foi adicionado (Model, Service ou Controller Test)?
- **Correção Proposta:** Resumo da alteração no código para eliminar o defeito sem causar efeitos colaterais.

---

## 7. Critérios de Conclusão e Limpeza
- [ ] O comando de feedback do Passo 3 agora roda verde (passou).
- [ ] Teste de regressão permanente adicionado e integrado à suíte de testes.
- [ ] Logs temporários `[DEBUG-...]` removidos.
- [ ] Nenhuma nova vulnerabilidade apontada pelo Brakeman ou RuboCop.
