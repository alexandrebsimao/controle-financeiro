---
name: diagnosing-bugs
description: >-
  Disciplina estruturada em 6 fases para diagnosticar e isolar bugs difíceis, regressões e falhas intermitentes.
  Foco na criação prévia de um loop de feedback vermelho (red-capable), reprodução mínima e testes de regressão antes do fix.
---

# Skill: Diagnosing Bugs (Diagnóstico Rigoroso de Erros)

Esta skill aplica uma metodologia disciplinada em **6 fases** para diagnosticar e corrigir defeitos em sistemas de software, inspirada no processo do [mattpocock/skills](https://github.com/mattpocock/skills).

O princípio fundamental é: **Não altere código nem formule teorias antes de ter um loop de feedback automatizado que comprove o erro.**

---

## 🛑 Regra de Redação de Segredos
Sempre oculte senhas, tokens de API ou dados sensíveis que apareçam em logs ou saídas de terminal com `<REDACTED>`.

---

## 🎯 As 6 Fases do Diagnóstico

### 1. Construir o Loop de Feedback (Build a Feedback Loop)
Esta é a fase mais importante. Sem um sinal claro de aprovação/reprovação (pass/fail), nenhuma leitura de código terá garantia.

Crie um comando único capaz de falhar no bug atual:
- **Teste automatizado** (Minitest/RSpec em Rails) que exercita o caminho do erro.
- **Script CLI / Runner:** `bundle exec rails runner "..."`.
- **Chamada cURL:** Requisição HTTP contra o servidor local reproduzindo a falha.

**Critérios de conclusão da Fase 1:**
- [ ] **Red-capable:** O comando comprovadamente falha na branch atual exibindo o sintoma real.
- [ ] **Determinístico:** Executa sem oscilações e sem depender de estado randômico.
- [ ] **Rápido:** Executa em poucos segundos.

### 2. Reproduzir e Minimizar (Reproduce + Minimise)
- Isole o cenário cortando variáveis, payloads, colunas e parâmetros não essenciais, um por um.
- Mantenha apenas o que for estritamente necessário para manter o teste vermelho.
- O cenário minimizado será a base para o futuro teste de regressão.

### 3. Formular 3 a 5 Hipóteses Falsificáveis
Nunca se prenda à primeira teoria que vier à mente.
Gere de 3 a 5 hipóteses ranqueadas no formato:
> *"Se [X] for a causa, então ao alterar [Y], o comportamento [Z] deve acontecer."*

Apresente a lista para o usuário caso haja ambiguidades de domínio.

### 4. Instrumentação Direcionada (Instrument)
- Valide uma hipótese por vez.
- Use logs com tags exclusivas para facilitar a remoção posterior (ex: `Rails.logger.debug "[DEBUG-BUG123] valor: #{valor}"`).
- Inspecione variáveis sem suposições.

### 5. Correção e Teste de Regressão (Fix + Regression Test)
- Identifique a **costura correta (Seam)**: onde o teste de regressão deve viver (ex: teste de modelo, service ou controller).
- Converta o repro minimizado em um teste de regressão permanente na suíte oficial.
- Aplique a correção no código.
- Execute o teste: ele deve ficar **verde**!

### 6. Limpeza e Conclusão (Cleanup)
Antes de finalizar:
- [ ] O teste de regressão passa consistentemente.
- [ ] Todos os logs com prefixo `[DEBUG-...]` foram removidos.
- [ ] Nenhuma alteração especulativa foi deixada para trás.
- [ ] A causa raiz real confirmada é documentada no commit / issue.
