# Estado de reconstrução e pendências verificáveis

Base publicada preservada:0.3.1-dev. Nova revisão em desenvolvimento:0.4.0-dev.
Diagnóstico antes de alterações:RECONSTRUCTION_DIAGNOSIS.md, commit5992efc.
Solicitações integrais:REQUEST_RECONSTRUCTION.md, REQUEST_RECONSTRUCTION_PART2.md,
REQUEST_CONTENT.md e REQUEST_CONTINUITY_MASTER.md. O resumo histórico do último
pedido menciona0.3.0; a auditoria local constatou0.3.1 e preservou suas evidências.

## Já observado nesta reconstrução

- Baseline gráfico300,05s, saída0, sem erro/vazamento, screenshot e métricas.
- Falhas de presets, corte/água/cozinha através de parede, machado sem desgaste e
  animais neutros agressivos reproduzidas antes de corrigir.
- Fonte única das opções gráficas em settings.cfg, autoload Settings, aplicação
  imediata e rollback só do display. Seis presets esperaram120s reais cada um,
  passaram por mundo/menu e reiniciaram em seis processos; todos passaram.
- Suíte nova da cena real:53verificações passaram antes da última expansão de
  asserções de animação. Repetição final pendente.
- Regras61/0, mundo25/0, player11/0 e input8/0 preservados nas primeiras repetições.
- Empacotamento/recibo/segredos:12testes Python passaram.
- Encerramento após menu vazava playbacksWAV; reprodução verbose confirmou áudio
  pendente, liberação explícita de streams corrigiu o caso e o teste120s passou.

## Implementado em código, validação final ainda necessária

- Mundo320×320 porseed e descriptorversionado; legado mantém gerador antigo.
- Chunks em tarefa/ativação na main thread, árvores porID com rebrota, biomas,
  litoral, rio/lago e geometrias de caverna/ruína. Verificação de exploração,
  costuras e desempenho gráficos ainda precisa execução mais ampla.
- Peças físicas de casa, porta, teto, cama, baú/canteiro; custo/permissão e saves.
- Ações de coleta com animação e materiais físicos; fila/cancelamento/reparo,
  pesquisa/XP poruso, cultivo de bagas, domesticação básica e pesca inicial.
- Snapshots privados por dono e deltas, senha/challenge/version, configservidor,
  moderação autenticada. Exigem cenários de rede completos e carga8–16clientes.
- Malhas novas de árvores/personagem/animais e grama. Não declarar qualidade
  visual final sem capturas e inspeção. Água melhorada ainda requer testeGL.
- Mapa real com exploração/marcadores, ajuda e HUD sem lista fixa de teclas,
  opções de acessibilidade. Traduções novas e interação gráfica pendentes.

## Bloqueios de validação antes de exportar/publicar

1. Atualizar testes de gameplay que esperavam concessão instantânea de madeira e
   craft instantâneo:agora devem verificar escrow, animação e objeto físico.
2. Atualizar assert de versão3 para migração4; preservar casos/regressões anteriores.
3. Repetir importação, suíte toda, cenáriosmultiplayer/reconexão/privacidade/senha,
   configurações inválidas, fifty-starts e encerramento.
4. Executar gráficos/dia/noite/tempestade/modosjanela e sessão30min, registrando
   memória/FPS/geração sem equiparar llvmpipe a GPUreal.
5. Gerar novos binários/pacotes apósfreeze, verificar recursos/CRC/SHA e instalar
   no Windowslimpo, incluindo upgrade. Windows10/11 gráficos reais não disponíveis
   no ambienteLinux; não declarar esse teste como executado.
6. Só publicar quando testesreais executados passarem. Criar release exige API
   GitHub/autorização de rede; se bloqueada, interromper publicação e informar,
   conforme pedido. Nenhum download antigo será substituído silenciosamente.

## Extensões de produto ainda ausentes ou parciais

A seção22.6 permite MVPs funcionais e registro do restante. Não há 1.0 nesta etapa.
Continuam pendentes:catálogo completo proposto, ícones/modelos individuais de todo
item, peso/mochilas/pilhas/desgaste por instância, validade/conservação, cerâmica/
curtimento/medicina completa, NPCs/trocas, armas balísticas recuperáveis/ferimentos,
estações/eventos completos, diplomacia/guerras/alianças e1hproteção, transporte/
barcos, fauna extra/ecologia/carga/necessidades de pets, navegação por trilhas,
servidor público/descoberta/criptografia/autenticação comercial/relevância,
WAL/fsyncdurabilidade contraquedaenergia, Opus/eco/microfones físicos,
acessibilidade integral/controle físico/multimonitorDPI, benchmarkhardwarealvo,
assinaturacertificado/Steam/material de divulgaçãofinal.

Valores novos estão em Data/Balance.json; cobertura de todos os valores legados
precisa revisão, sem afirmar que cada literal técnico é um parâmetro de balance.
Uma tabela de conteúdo distinguirá proposta, parcial, comprovado e ausente.
