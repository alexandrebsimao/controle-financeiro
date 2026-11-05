# Diretrizes para Agentes de IA (AGENTS.md)

Este documento instrui agentes autônomos e assistentes de IA (como Antigravity) ao operarem neste projeto.

---

## 🎯 Skills Disponíveis no Projeto

As seguintes skills estão configuradas em `.agents/skills/`:

| Skill | Descrição e Gatilho |
| :--- | :--- |
| **`specs`** | Elabora especificações técnicas e PRDs para **Features** ou **Bugs**. Executa questionamento preliminar em rodadas (*grill-me*), gera o documento padronizado, abre uma Issue no GitHub e comenta cada interação. |
| **`code-review`** | Realiza code review em dois eixos paralelos: **Standards** (boas práticas de Rails 8 + 12 smells de Fowler) e **Spec** (aderência estrita aos critérios de aceite). |
| **`grill-me`** | Entrevista implacável para questionar e estressar ideias e arquiteturas antes da implementação, mapeando a árvore de decisões. |
| **`diagnosing-bugs`** | Disciplina de 6 fases para diagnosticar defeitos: loop de feedback vermelho (*red-capable*), repro mínima, 3-5 hipóteses, instrumentação e teste de regressão. |
| **`rails-best-practices`** | Guia de arquitetura, prevenção de N+1 queries, segurança contra IDOR e boas práticas de banco de dados e Sidekiq em Rails 8. |

---

## 📌 Regras Obrigatórias para Criação de Specs

1. **Investigação Antes do Documento:** Nunca crie uma spec ou PRD sem antes fazer as rodadas de perguntas da árvore de decisão (*grilling*).
2. **Abertura de Issue no GitHub:** Sempre que uma spec for finalizada e salva em `docs/specs/`, execute `.agents/skills/specs/scripts/github-issue-sync.sh create` para abrir a issue correspondente no repositório GitHub.
3. **Comentários de Interação:** Toda rodada de feedback, mudança arquitetural, atualização de status ou decisão aprovada com o usuário DEVE ser comentada na Issue do GitHub utilizando `.agents/skills/specs/scripts/github-issue-sync.sh comment`.

---

## 💎 Padrões de Código Ruby on Rails 8

- **Controllers:** Skinny controllers apenas orquestrando fluxos;
- **Services & Queries:** Regras de negócio em `app/services/` e consultas em `app/queries/`;
- **ActiveRecord:** Sempre use `includes(...)` para evitar queries N+1 e `foreign_key: true` com índices em migrações;
- **Segurança:** Nunca consulte recursos sem partir do `current_user` e nunca commite credenciais sem criptografia.
