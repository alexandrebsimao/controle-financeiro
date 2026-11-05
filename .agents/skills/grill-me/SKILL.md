---
name: grill-me
description: >-
  Entrevista implacável para questionar, estressar e validar planos, decisões de arquitetura e modelos de domínio.
  Mapeia a árvore de decisões em rodadas de perguntas, calcula a fronteira de pré-requisitos e oferece opções recomendadas.
---

# Skill: Grill-Me (Entrevista de Alinhamento e Árvore de Decisão)

Esta skill conduz uma entrevista investigativa minuciosa com o usuário para eliminar todas as dúvidas, ambiguidades e decisões tácitas antes de iniciar qualquer implementação de código.

Baseada na técnica de **Grilling** do repositório [mattpocock/skills](https://github.com/mattpocock/skills).

---

## 🌳 A Árvore de Decisão e o Conceito de Fronteira

Todo projeto ou funcionalidade é modelado como uma **árvore de decisão**: cada escolha inicial ramifica em novas decisões subsequentes.

- **A Fronteira (The Frontier):** É o conjunto de perguntas cujos pré-requisitos já foram respondidos.
- Nunca faça perguntas da próxima ramificação antes de fechar a decisão da qual ela depende.

---

## 🔁 Processo em Rodadas (Rounds)

Trabalhe em rodadas organizadas:

1. **Apresente toda a fronteira em uma única rodada:**
   Agrupe todas as perguntas desbloqueadas no momento atual.
2. **Formato Obrigatório de Cada Pergunta:**

   ```markdown
   ❓ **Q1** - **<Título da Decisão>**: <Contexto, trade-offs e opções>

   ➡️ **Recomendação:** <Sua sugestão técnica e justificativa>
   ```

   *Dica de formulação:* Estruture a pergunta para que uma resposta rápida como *"Sim"*, *"Aprovado"* ou *"Opção recomendada"* seja suficiente para o usuário avançar sem atrito.

3. **Investigação de Fatos é Função do Agente:**
   - Se uma pergunta depende de dados técnicos existentes (ex: schema de tabela, gem instalada, nome de controller, rota existente), **investigue os arquivos no repositório com suas ferramentas**.
   - Nunca pergunte ao usuário o que você mesmo pode verificar inspecionando o projeto.
4. **Recalcular a Fronteira:**
   Após a resposta do usuário, incorpore as decisões, desbloqueie os novos nós da árvore e apresente a Rodada seguinte.
5. **Critério de Conclusão:**
   A sessão termina quando a fronteira estiver vazia — isto é, quando todos os fluxos normais e de exceção tiverem sido deliberados e validados pelo usuário.
