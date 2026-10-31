# Arquitetura em camadas (inspirada em DDD)

Registro das decisões de arquitetura do serviço. Explica o que foi decidido e **por quê**, o que de DDD foi adotado (e o que não foi), e o que ficou para depois.

- Decisão: 2026-10-31, em conversa com o autor do projeto.
- Estado: só o esqueleto existe (camadas, teste de arquitetura, detecção de mudança e `GET /health`). Nenhuma fonte está integrada ainda.

## 1. Contexto

O serviço junta dados acadêmicos de quatro fontes: **SIGAA**, **Moodle**, **Google Classroom** e **Google Calendar**. O consumo é por duas interfaces equivalentes, **REST** e **MCP**. Uma interface web virá depois, como cliente do REST; ela não faz parte deste serviço.

As fontes são muito diferentes. Calendar e Classroom têm API oficial. O Moodle tem API, mas o token vem de um login institucional interativo. O SIGAA **não tem API**: o acesso é feito como um navegador faria, com usuário e senha.

## 2. Decisão

```
src/
├── domain/           regras puras: sem banco, rede, framework nem relógio
│   ├── kernel/         base sem regra de negócio (hash de conteúdo, erros)
│   └── sync/           detecção de mudança (novo, alterado, removido)
├── application/      casos de uso (um por operação)
├── interface/        adaptadores de entrada
│   ├── rest/           controllers e DTOs
│   └── mcp/            ferramentas e schemas
└── infrastructure/   adaptadores de saída
    ├── persistence/    Prisma
    └── sources/        gateways: sigaa/, moodle/, classroom/, calendar/
```

Só `domain`, `interface/rest` e `app.module.ts`/`main.ts` existem hoje; as demais pastas entram quando houver o que colocar nelas.

| Camada | Responsabilidade | Pode depender de |
|---|---|---|
| `domain` | Regras e conceitos. Não conhece JSON, banco, fila nem HTTP | só dele mesmo |
| `application` | Casos de uso: orquestram o domínio | `domain` |
| `interface` | Traduz o mundo de fora (REST, MCP) para casos de uso | `application`, `domain` |
| `infrastructure` | Fala com Postgres e com as fontes | `application`, `domain` |

A regra é uma só: **a dependência aponta para dentro**. O `domain/kernel` é a base e não importa o resto do domínio.

`test/architecture.spec.ts` lê os imports e **falha o build** se a regra for quebrada, ou se o `domain` importar framework, banco ou fila.

### 2.1 REST e MCP são equivalentes

`interface/rest` e `interface/mcp` são adaptadores finos e irmãos: validam a entrada e chamam os **mesmos casos de uso**. Nenhuma lógica mora no controller nem na ferramenta. O que existe numa interface existe na outra.

### 2.2 Leituras e comandos são separados

- **Leituras** (`listar_itens`, `agenda`, `mudancas`…) só consultam o banco. **Nunca** vão a uma fonte externa e sempre devolvem `atualizadoEm`.
- **Comando** `sincronizar` é o único que vai às fontes. Recebe `fonte` e `alcance` (`tudo`, `curso` ou `item`) e grava o que trouxe.
- Nada atualiza sozinho dentro de uma leitura. Quem decide se o dado serve ou se precisa sincronizar é quem chama (o agente, ou a interface), que tem o contexto. A descrição de cada ferramenta orienta essa escolha.

Esta regra vale para REST e MCP. Será protegida por teste quando houver os primeiros casos de uso de leitura.

### 2.3 Credenciais

- **A senha do SIGAA nunca é guardada.** Ela vem na requisição de `sincronizar`, é usada em memória e descartada. Nenhuma tabela tem coluna para ela.
- Tokens de fontes com API oficial (Moodle, Google) podem ser guardados, **cifrados**.
- Cada fonte declarará como autentica (`token-guardado` ou `segredo-por-requisição`). Assim a regra do SIGAA fica na estrutura do código, e qualquer agendador futuro nunca toca em fonte do segundo tipo.

### 2.4 Modelo pull, sem agendador por enquanto

A sincronização acontece quando alguém pede. Agendador, fila (BullMQ), webhooks, long polling e notificações ativas ficam fora do primeiro marco. Quando vierem, serão mais um adaptador de entrada (`interface/scheduler`) chamando o mesmo caso de uso `sincronizar`, sem refazer nada.

### 2.5 Mudanças detectadas por hash

Cada `sincronizar` compara o que veio da fonte com o que está no banco pelo **hash do conteúdo** (`domain/sync`) e registra o que é novo, alterado ou removido. Esse registro responde "o que mudou desde a última vez que olhei?" e alimenta notificações no futuro.

## 3. Modelo de dados (direção)

Este PR não traz schema. A direção, a detalhar no PR do schema:

```
IDENTIDADE      user · api_key (só hash) · source_account (token cifrado, estado)
CATÁLOGO        curso · estrutura_curricular · componente · docente
VIDA ACADÊMICA  turma · matrícula · histórico · plano
TRABALHO        course_space · item · attachment · grade_entry · calendar_event
CONTROLE        sync_run · change_event
```

- Um `item` único, com `tipo` (aviso, tarefa, prova, material, nota…) e um JSON para o que é específico da fonte.
- Itens pertencem a uma `source_account`: um aluno nunca vê o que é de outro.
- Anexos: só metadados no banco. O conteúdo é buscado na fonte sob demanda, com cache curto.
- O histórico escolar é extraído por **IA** (provedor configurável por variável de ambiente), seguido de validação contra o próprio documento (carga horária e CR recalculados). Só o histórico usa IA.

## 4. O que de DDD foi adotado, e o que não foi

| Conceito | Situação |
|---|---|
| Camadas e regra de dependência | **Adotado**, com teste |
| Domínio puro, testável sem infraestrutura | **Adotado** |
| Casos de uso nomeados | **Adotado** (`application/`) |
| Portas e adaptadores para as fontes | **Previsto**: quatro fontes implementam o mesmo conceito, então a abstração se justifica |
| Entidades com ciclo de vida, eventos de domínio | **Não adotado**: sem necessidade hoje |

## 5. Fora do escopo agora

Agendador e fila, webhooks (Calendar, Classroom), long polling/SSE, notificações, interface web. Cada um é adição, não reescrita.
