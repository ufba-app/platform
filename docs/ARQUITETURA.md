# Arquitetura em camadas (inspirada em DDD)

Registro das decisões de arquitetura do serviço. Explica o que foi decidido e **por quê**, o que de DDD foi adotado (e o que não foi), e o que ficou para depois.

- Decisão: 2026-10-31, em conversa com o autor do projeto.
- Estado: existem o esqueleto (camadas, teste de arquitetura, detecção de mudança, `GET /health`) e o schema do banco com a migração inicial. Nenhuma fonte está integrada ainda.

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

## 3. Modelo de dados

O schema está em `prisma/`, dividido por grupo em `prisma/models/<grupo>/` (Prisma 7, `schema: 'prisma'`). Os identificadores são em inglês; os termos do SIGAA ficam na fronteira (no parser) e neste glossário.

```
identity/    users · api_keys · source_accounts · student_profiles
catalog/     programs · curricula · curriculum_components          (global, público)
academic/    sections · enrollments · transcripts (+ entries, pending) · plan_items
coursework/  course_spaces · items · attachments · grade_entries · calendar_events
sync/        sync_runs · change_events
```

| SIGAA (português) | Modelo |
|---|---|
| curso | `Program` |
| estrutura curricular | `Curriculum` |
| componente curricular | `CurriculumComponent` |
| turma | `Section` |
| matrícula (na turma) | `Enrollment` |
| histórico | `Transcript` (`TranscriptEntry`, `TranscriptPending`) |
| plano de curso do aluno | `PlanItem` |

### 3.1 Decisões de modelagem

- **Tudo que vem das fontes pertence a uma `SourceAccount`**, nunca direto ao usuário: um aluno nunca vê o que é de outro. Só o catálogo (`programs`, `curricula`, `curriculum_components`) e as turmas (`sections`) são globais, porque são públicos e iguais para todos.
- **`SourceAccount` do SIGAA nunca tem segredo.** As colunas `secret_*` ficam nulas; só Moodle e Google guardam token, cifrado. O Prisma não expressa essa restrição, então ela terá de ser garantida pelo código que grava contas, com teste, quando esse caso de uso existir (ver §2.3). Hoje nada grava nesta tabela.
- **Um `Item` único**, com `kind` (aviso, tarefa, prova, material, fórum) e um JSON `extra` para o que é específico da fonte. É o que permite "o que vence esta semana?" sem juntar quatro estruturas.
- **Uma disciplina real vira até três `CourseSpace`** (SIGAA, Moodle, Classroom). `sectionId` liga ao `Section`; o vínculo é sugerido pelo sistema e confirmado pela pessoa (`linkConfirmedAt`), porque casar por nome é frágil.
- **Remoção lógica** (`deletedAt`) em tudo que a sincronização pode ver sumir, para preservar o histórico de mudanças. `firstSeenAt` e `lastSeenAt` registram quando apareceu e quando foi visto pela última vez.
- **Anexos: só metadados.** O conteúdo é buscado na fonte sob demanda, com cache curto fora do banco.
- **`Transcript` guarda só dado acadêmico**: sem CPF, nascimento nem nome do aluno. `status` e `nature` das linhas são texto de propósito, porque o documento usa muitas siglas e a extração não deve falhar por uma sigla nova. A matriz de carga horária fica como o documento a declara, para a validação recalcular e comparar.
- **O histórico é extraído por IA** (provedor configurável por variável de ambiente), seguido de validação contra o próprio documento (carga horária e CR recalculados). Só o histórico usa IA.
- **`PlanItem` é dado autoral**, não vem de fonte nenhuma, e por isso não é chave estrangeira do histórico: sobrevive à reimportação.
- **Sem TTL de atualização.** Nenhuma tabela tem `staleAfter`: o serviço não atualiza sozinho (§2.2), e quem lê decide pela idade do dado (`fetchedAt`, `lastSeenAt`).

### 3.2 O que ficou de fora (de propósito)

Não foram portados do app antigo: perfil de docentes (`Instructor` e a busca por nome), pontos de atenção e votos, faltas, caches de notas e horário, vínculo cifrado com a senha do SIGAA, push e versões do app. Docentes volta quando houver caso de uso; o resto não pertence ao núcleo.

### 3.3 Banco compartilhado

O serviço pode dividir um Postgres com outro projeto usando um schema próprio (`?schema=platform` em `DATABASE_URL`, criado antes com `CREATE SCHEMA platform;`). As migrações não citam o nome do schema, então valem em qualquer um, inclusive `public`.

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
