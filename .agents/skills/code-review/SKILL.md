---
name: code-review
description: >-
  Revisa o código a partir de um ponto fixo (commit, branch, PR ou merge-base) sob dois eixos independentes:
  Eixo 1: Standards (boas práticas de Rails 8 e baseline de Code Smells de Fowler).
  Eixo 2: Spec (aderência estrita aos requisitos e critérios de aceite da PRD / Issue original).
  Executa análises em paralelo e registra os apontamentos na Issue ou Pull Request correspondente.
---

# Skill: Code Review em Dois Eixos

Esta skill avalia as alterações do `HEAD` contra um ponto fixo (commit, branch `main` ou tag) em dois eixos deliberadamente separados:

1. **Standards:** O código segue os padrões do repositório, boas práticas de **Ruby on Rails 8** e o catálogo de **Code Smells de Fowler**?
2. **Spec:** O código implementa fielmente o que foi acordado na **Spec / PRD / Issue** de origem sem omissões e sem *scope creep*?

Ambos os eixos rodam em **sub-agentes paralelos** para garantir que a avaliação técnica não contamine a verificação funcional.

---

## 🎯 Por que Dois Eixos?

- Código que segue todos os padrões mas implementa a regra de negócio errada → **Standards Pass, Spec Fail**.
- Código que cumpre exatamente o que a Issue pediu mas quebra convenções, cria N+1 ou adiciona smells graves → **Spec Pass, Standards Fail**.

A separação impede que um eixo mascare as deficiências do outro.

---

## 📋 Processo de Execução

### 1. Definir o Ponto Fixo (Diff Baseline)
- Identifique a referência base fornecida pelo usuário (`main`, `HEAD~1`, commit SHA ou tag). Se omitido, use `origin/main` ou pergunte.
- Valide o ponto fixo: `git rev-parse <ponto-fixo>`.
- Capture o diff com `git diff <ponto-fixo>...HEAD` (três pontos) e a lista de commits com `git log <ponto-fixo>..HEAD --oneline`.

### 2. Identificar a Fonte da Spec
Procure a especificação ou issue de origem nesta ordem:
1. Menções nos commits (ex: `Closes #15`, `refs #22`).
2. Arquivos em `docs/specs/*.md` correspondentes à branch ou feature.
3. Se não encontrar, solicite ao usuário o link/arquivo da spec.

### 3. Identificar os Padrões de Código
Consulte:
- [references/rails-review-checklist.md](./references/rails-review-checklist.md) (Checklist de Rails 8).
- [references/code-smells.md](./references/code-smells.md) (Catálogo de Smells de Martin Fowler).
- Regras locais do projeto em `.agents/rules/` ou `.rubocop.yml`.

### 4. Executar os Dois Eixos em Paralelo (Sub-Agentes)

Invoque dois sub-agentes com contextos independentes:

#### Sub-Agente A: Standards & Rails Best Practices
Analisa o diff contra as regras de Rails 8 e os 12 code smells de Fowler:
- Aponta violações de padrões de Rails (N+1 queries, falta de índices em FKs, ausência de Strong Params, etc.).
- Identifica cheiros de código com heurística (ex: *Feature Envy*, *Primitive Obsession*, *Shotgun Surgery*).
- Formato: Citar arquivo, linha/hunk, o cheiro/regra violada e sugestão clara de refatoração.

#### Sub-Agente B: Spec & Acceptance Criteria
Analisa o diff contra a Issue / PRD de origem:
- **(a) Requisitos Faltantes ou Parciais:** O que a spec exigia que não foi entregue?
- **(b) Scope Creep (Comportamento Não Solicitado):** O diff adicionou lógica ou endpoints fora de escopo?
- **(c) Implementações Incorretas:** Onde a regra de negócio foi codificada de forma divergente da spec?
- Formato: Citar cada critério de aceite da spec confrontando com o trecho do diff.

### 5. Consolidar o Relatório e Comentar na Issue / PR
Gere o relatório final consolidado estruturado:

```markdown
## 🔍 Relatório de Code Review

### 📐 1. Eixo: Standards & Boas Práticas Rails
- **Violações de Padrão:** [Resumo ou "Nenhuma"]
- **Code Smells Identificados:** [Apontamentos por arquivo]

### 🎯 2. Eixo: Aderência à Especificação (Spec)
- **Requisitos Atendidos:** [Lista de critérios OK]
- **Pendências / Divergências:** [Itens que precisam de ajuste]
- **Scope Creep:** [Nenhum ou itens identificados]

### 🏁 Veredito Final
- **Standards:** [Aprovado / Requer Ajustes]
- **Spec:** [Aprovado / Requer Ajustes]
```

Se houver uma Issue do GitHub vinculada, registre o relatório como comentário:
```bash
.agents/skills/specs/scripts/github-issue-sync.sh comment "<numero-da-issue>" "<conteudo-do-review>"
```
