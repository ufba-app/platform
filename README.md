# ufba-app/platform

Serviço aberto que reúne, num só lugar, os dados acadêmicos de quem estuda na UFBA: **SIGAA**, **Moodle**, **Google Classroom** e **Google Calendar**. Expõe tudo por duas interfaces equivalentes, **REST** e **MCP**, sobre os mesmos casos de uso.

> Estado: início do projeto. Ainda não há funcionalidade; o que existe é a arquitetura. Veja [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md).

## Princípios

- **A senha do SIGAA nunca é guardada.** O SIGAA não tem API, então o acesso é feito como um navegador faria. A senha vai na requisição, é usada em memória e descartada. Tokens de fontes com API oficial (Moodle, Google) podem ser guardados, cifrados.
- **Leitura e sincronização são separadas.** Ferramentas de leitura só consultam o banco. Só o comando `sincronizar` vai às fontes externas.
- **Código aberto de propósito.** Quem usa pode ler o que acontece com os próprios dados.

## Contribuindo

A `main` é protegida: toda mudança entra por branch e pull request. Antes de abrir o PR, `npm run build` e `npm test` precisam passar. A regra de dependência entre camadas é verificada por teste (`test/architecture.spec.ts`).

## Licença

[AGPL-3.0](LICENSE). Quem hospedar uma versão modificada precisa publicar o código dela.
