# Fowler Code Smells Baseline (Refactoring, Ch. 3)

Este catálogo define a base de cheiro de código (*code smells*) aplicada durante o eixo de **Standards** do Code Review. Cada item é uma heurística qualitativa (julgamento técnico), e não uma regra cega. Padrões explicitamente documentados no repositório sempre têm precedência sobre esta lista.

---

### 1. Mysterious Name (Nome Misterioso)
- **O que é:** Função, método, variável ou tipo cujo nome não revela com clareza o que faz ou o que armazena.
- **Como corrigir:** Renomeie com honestidade; se nenhum nome claro surgir, o design subjacente está confuso.

### 2. Duplicated Code (Código Duplicado)
- **O que é:** O mesmo formato ou fluxo de lógica aparece em mais de um hunk ou arquivo na alteração.
- **Como corrigir:** Extraia o formato compartilhado para um método ou classe utilitária e chame-o em ambos os locais.

### 3. Feature Envy (Inveja de Recursos)
- **O que é:** Um método que acessa e manipula os dados de outro objeto mais do que os seus próprios.
- **Como corrigir:** Mova o método (ou parte dele) para a classe dona dos dados manipulados.

### 4. Data Clumps (Aglomerados de Dados)
- **O que é:** O mesmo conjunto de 3 ou mais parâmetros viajam juntos em assinaturas de métodos ou hashes.
- **Como corrigir:** Agrupe esses campos em um Value Object ou objeto de domínio dedicado.

### 5. Primitive Obsession (Obsessão por Primitivos)
- **O que é:** Uso indiscriminado de tipos primitivos (strings, inteiros, hashes soltos) para representar conceitos do domínio (ex: dinheiro, moeda, chave pix, cnpj, range de datas).
- **Como corrigir:** Crie uma pequena classe ou Value Object para encapsular a lógica e validações desse conceito.

### 6. Repeated Switches (Switches / Condicionais Repetidos)
- **O que é:** As mesmas verificações `case/when` ou cascatas de `if/else` sobre o mesmo tipo ou enum se repetem em vários lugares.
- **Como corrigir:** Substitua por polimorfismo, classes de estratégia ou uma tabela de mapeamento única.

### 7. Shotgun Surgery (Cirurgia por Espingarda)
- **O que é:** Uma única alteração lógica obriga a fazer pequenas edições espalhadas por inúmeros arquivos diferentes no diff.
- **Como corrigir:** Reúna os elementos que mudam juntos dentro de um único módulo ou serviço coeso.

### 8. Divergent Change (Modificação Divergente)
- **O que é:** O mesmo arquivo ou classe é alterado por múltiplos motivos não relacionados.
- **Como corrigir:** Aplique o Princípio da Responsabilidade Única (SRP); divida a classe para que cada uma mude por um único motivo.

### 9. Speculative Generality (Generalidade Especulativa)
- **O que é:** Criação de abstrações, parâmetros opcionais, interfaces ou hooks prevendo necessidades futuras que a spec atual não exige.
- **Como corrigir:** Remova o código especulativo; mantenha o código simples (YAGNI) até que a necessidade real se manifeste.

### 10. Message Chains (Cadeias de Mensagens)
- **O que é:** Navegação longa no estilo `a.b.c.d.valor`, violando a Lei de Demeter.
- **Como corrigir:** Oculte o caminho criando métodos de delegação (ex: `delegate` do Rails) ou solicite o resultado diretamente ao primeiro objeto.

### 11. Middle Man (Homem do Meio)
- **O que é:** Uma classe ou serviço que apenas repassa chamadas adiante sem agregar nenhuma regra ou inteligência.
- **Como corrigir:** Elimine o intermediário e chame o destino diretamente.

### 12. Refused Bequest (Herança Rejeitada)
- **O que é:** Uma subclasse que ignora, lança erro ou sobrescreve a maior parte dos métodos que herda da classe pai.
- **Como corrigir:** Remova a herança e use composição ou módulos de concern compartilhados.
