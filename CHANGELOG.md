# Mudanças — Tribes of Fire

Criado por **felipealx**.

## 0.4.0-dev — reconstrução em validação

A reconstrução parte da0.3.1 preservada em Downloads. O relatório de execução
identifica quais mudanças foram integradas e testadas; a existência desta seção
não declara aprovação de todos os requisitos.

- Empacotamento de fontes passa a respeitar arquivos ignorados e excluir perfis,
  credenciais e chaves, inclusive se adicionados ao Git por engano.
- Documentação de privacidade, componentes de terceiros e estado de lançamento
  acompanha os pacotes. Relatórios/imagens de auditoria são excluídos do PCK.
- Infraestrutura Windows preparada para verificar atualização da0.3.1, migração
  de saves e preferências, além de instalação limpa e desinstalação.

Consulte PROGRESS.md para as alterações de jogabilidade, gráficos, mundo,
segurança e resultados observados nesta revisão.

## 0.3.1-dev

Correções de movimento após morte, durabilidade de itens descartados, oclusão de
coleta, cozimento com inventário cheio, configurações malformadas, LOD e fechamento
no carregamento. Fortalecimento de saves/identidades, relógio monotônico e fila de
voz. Suíte de372 verificações e seis checks dos binários Linux; execução Windows
headless aprovada. Voz sob carga, gráficos Windows e hardware alvo não certificados.

## 0.3.0-dev

Primeira entrega integrada de personagens personalizáveis, seis idiomas, inventário
com espaços, equipamentos, sobrevivência, animais, mineração, combate, tribos,
texto/voz opt-in, perfis gráficos e instalador multilíngue. Mundo128×128m com seed
fixa; versão de desenvolvimento, requisitos1.0 incompletos.
