# Envio ao GitHub

Destino existente: https://github.com/teyranto7-cloud/Tribes-Of-Fire.
O código novo está em desenvolvimento na branch local `work`; a última base
pública confirmada nesta auditoria é `18bb0cc` (0.3.1-dev).

A tentativa de consultar `https://api.github.com` foi recusada pelo proxy com
403 na abertura da conexão. `gh auth status` não conseguiu validar a autenticação.
O pedido de continuidade determina suspender publicação quando a API estiver
bloqueada. Nenhum push ou release desta reconstrução foi confirmado.

Para permitir o envio, o responsável pelo ambiente precisa liberar
`api.github.com` no controle de acesso suportado e disponibilizar/revalidar a
autenticação de escrita do GitHub. Se usar `GH_TOKEN`, configure-o como segredo
do ambiente com acesso a este repositório. Não cole o valor no chat, código,
comandos registrados ou arquivos versionados. Não é necessário tornar o
repositório privado nem criar outro repositório.

Depois de o acesso funcionar, conferir o remoto com `git fetch origin` e comparar
`origin/main` com a branch local antes de enviar. Preservar qualquer alteração
remota nova e usar apenas avanço normal, sem force push. Os resultados e limites
da revisão estão em `RECONSTRUCTION_TEST_REPORT.md` e `PENDENCIAS.md`.

O envio de código em desenvolvimento não constitui lançamento 1.0. Uma release
de executáveis exige conferir os testes e hashes dos próprios artefatos, executar
o QA Windows e resolver os critérios de distribuição ainda pendentes. Os
downloads publicados da 0.3.1 permanecem preservados.
