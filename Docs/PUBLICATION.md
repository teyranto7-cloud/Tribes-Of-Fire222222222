# Envio ao GitHub — 0.4.0-dev

Destino: https://github.com/teyranto7-cloud/Tribes-Of-Fire.

O bloqueio anterior de conexão à API (403) foi resolvido na configuração atual:
`https://api.github.com` respondeu HTTP200, `gh` autenticou a conta autorizada e
confirmou acesso de escrita. Foram reutilizadas as credenciais do ambiente; nenhum
valor foi copiado ou solicitado no chat.

Antes do envio, `git fetch origin main` encontrou o remoto no commit `bf0faa7`,
com apenas README inicial e sem ancestral comum com o trabalho local. Os dois
históricos foram integrados, preservando o commit remoto e a implementação local
`ac64a34`. O README inicial foi substituído pelas instruções completas do jogo.
O envio deve ser um avanço normal de main, sem force push.

Os cinco pacotes 0.4.0-dev e seus hashes estão em `Downloads/0.4.0-dev`. O runtime
continua com a impressão digital do recibo validado. Registros anteriores de
bloqueio em `verification/0.4.0-dev/publication-status.txt` descrevem a tentativa
anterior, não o estado desta nova tentativa.

A publicação é de desenvolvimento. A confirmação remota, a execução do workflow
Windows e eventual prerelease serão registradas após observar seus resultados.
Não equivale a 1.0 ou validação de gráficos Windows, microfone/hardware físico,
100 jogadores ou conclusão do conteúdo completo solicitado.
