# Relatório verificável — 0.3.0-dev

Data UTC: 2026-11-02. Godot 4.6.3.stable.official.7d41c59c4, Linux x64.
Execução real com saídas/artefatos, sem inferir Windows a partir de exportação.

## Regras e integração

`python3 Tools/build.py` importou, executou seis suítes GDScript e o teste de
processos, e exportou Windows/Linux/dedicado. Saída final:

```
RULES CHECKS=61 FAILED=0
WORLD CHECKS=25 FAILED=0
PLAYER_CHECKS=11 FAILED=0
INPUT CHECKS=8 FAILED=0
GAMEPLAY CHECKS=17 FAILED=0
V3 CHECKS=109 FAILED=0
PERSISTENCE_PROCESS CHECKS=4 FAILED=0
```

Total: 235 verificações. Teste de chuva usa 15/30/60/144 FPS simulados, limites
40/55/70/85/100/300 s, reinício por teto/fim da chuva e segurança da regeneração.
Integração verifica slots/transações, alcance de estações, grupos/bloqueios,
limites de aparência, fonte japonesa, captura sintética, caça/loot/cozimento,
limite de dano animal, arco/munição e persistência real v3.

## Rede em processos separados

- `python3 Tools/test_network.py`: 1 servidor/2 clientes, snapshots autoritativos,
  intenções válidas, comandos inválidos/administrativos recusados: NETWORK_PASS.
- `python3 Tools/test_multiplayer.py --keep-logs builds/logs`: cena real do jogo,
  dedicado/2 clientes, ambos moveram, viram corte compartilhado e 8 madeiras;
  perfis salvos, saída sem erros: MULTIPLAYER_PASS.
- `python3 Tools/test_reconnect.py`: novo peer, mesma identidade/inventário, parada
  e reinício real do servidor, inventário 12 restaurado: RECONNECT_PASS.
- `python3 Tools/test_communication.py --keep-logs builds/logs`: dedicado/3 clientes,
  seis canais de texto, privacidade, bloqueio e áudio ADPCM por canal autorizado:
  COMMUNICATION_PASS. B recebeu 6 pacotes de proximidade e 4 em cada canal
  privado/grupo/tribo (11.520 amostras reproduzidas); C recebeu 4 diplomáticos
  remotos (2.560 amostras), sem áudio privado indevido. Microfones físicos nunca
  iniciados. Dano aliado e pós-saída bloqueado pelo Runtime real da autoridade.

Identidades e diretórios XDG isolados por processo. Limites de frequência, codec
malformado e exclusão de terceiros são testados. Isso não constitui teste de
100 jogadores, Internet hostil, perda/latência extensa ou usuários em máquinas distintas.

## Binários e empacotamento

`python3 Tools/test_exports.py --keep-logs builds/logs` executou cliente Linux,
dedicado e reinício sem editor: EXPORT CHECKS=6 FAILED=0. Conferiu avanço do
relógio, saves, checksums, estado de jogadores e liberação do lock.
O executável Linux também abriu com OpenGL no Xorg virtual, salvou e saiu com 0.
VSync indisponível no display virtual foi registrado como aviso.

NSIS 3.11 compilou instalador Unicode com seis tabelas de idioma. ZIPs têm teste
CRC, headers dos binários são conferidos e SHA256 acompanha os artefatos.
O workflow Windows foi publicado e a [execução aprovada](https://github.com/teyranto7-cloud/Tribes-Of-Fire/actions/runs/41380465249)
foi observada com status público passing. Tools/Test-Windows.ps1 executa em modo
headless em windows-latest: instalação, atalhos, startup, SHA256/schema dos saves,
reinício dedicado, preservação de jogadores/relógio/lock, reinstalação da mesma
versão e desinstalação. Os relatórios detalhados estão no artefato da execução.
Essa validação ocorreu depois da geração dos pacotes e não equivale a jogar em
um Windows desktop com GPU e dispositivos físicos.
**Windows 10/11 gráficos/interativos e microfones físicos: não executados.**
A matriz manual completa está em Tests/MANUAL.md.

Hash SHA256 das fontes runtime no recibo da exportação:

`4321bc9b4436d3c93dec46b06e8ecdc17ac9b5e71e9a94735713e77768a50434`

O empacotador compara esse hash e os três hashes de executáveis antes de criar
pacotes. Alterar código exige nova exportação. Recibo completo em
builds/build-receipt.json; manifesto final e SHA256 em dist/.

## Medição gráfica curta

AMD EPYC 9V74 80-Core Processor, llvmpipe (LLVM 19.1.7, 256 bits), 5 processadores visíveis, 1280 × 720, Compatibility.
Nove cenários, 1 s de aquecimento e 4 s de amostragem, câmera fixa, sem limite FPS.
Antes/depois da consolidação de árvores/depósitos por material:

| Perfil / cena | Draw calls antes → depois | FPS antes → depois | p95 depois (ms) | Frames depois |
|---|---:|---:|---:|---:|
| Very Low / day | 548 → 416 | 14.48 → 14.55 | 113.5 | 59 |
| Very Low / night | 550 → 418 | 16.06 → 18.69 | 63.6 | 75 |
| Very Low / storm | 529 → 397 | 16.26 → 18.23 | 67.3 | 73 |
| Medium / day | 1934 → 1302 | 2.40 → 2.21 | 493.6 | 9 |
| Medium / night | 1810 → 1224 | 2.68 → 2.43 | 462.6 | 10 |
| Medium / storm | 1935 → 1303 | 2.46 → 2.76 | 380.7 | 12 |
| Ultra / day | 4339 → 2238 | 1.95 → 1.82 | 598.1 | 8 |
| Ultra / night | 3805 → 2052 | 2.04 → 2.04 | 528.0 | 9 |
| Ultra / storm | 4441 → 2334 | 1.97 → 1.96 | 573.4 | 8 |

São amostras curtas, com poucos frames nos perfis pesados e interferência parcial
de build na segunda rodada. Demonstram redução de submissões de geometria, sem
provar ganho controlado de FPS. O renderizador é software llvmpipe; os valores
não representam GPU integrada ou dedicada. A meta de 60 FPS no 4600G não foi
atingida/comprovada. Tempo de GPU indisponível; campo null nos JSONs.
Memória estática Godot não é RSS total nem certificação de ausência de vazamento.

Reproduza com display gráfico: `godot --path . --script res://Tools/benchmark.gd`.
Headless é recusado para evitar tratar FPS sem renderização como benchmark.
Dados brutos em builds/reports/benchmark-before-batching.json e benchmark.json.

## Evidências e falhas corrigidas

Logs desta versão: builds/logs/test_*.gd.log, persistence-process.log,
v3-network.log, v3-multiplayer.log, v3-reconnect.log, communication-*.log,
export-*.log e *-export.log. Telas em builds/screenshots/v3/.

Uma execução de integração falhou por inferência de tipo no teste; corrigida.
Um smoke de rede falhou por término precoce de cliente no fixture; corrigido para
manter os dois durante a verificação. A importação inicial sem sockets/cache
adequados falhou no sandbox; repetição autorizada e configurada passou. Falhas
não foram convertidas em sucesso por código de saída 0 sem examinar logs.

Preview gráfico deixou de gravar antes do aceite; NUL em mensagens foi corrigido;
slots após crafting e durabilidade de ferramenta substituta foram corrigidos;
preferências privadas não entram nos snapshots públicos; seleção de modo ranged
foi validada por consumo de flecha e dano em alvo real.

Esta entrega permanece **0.3.0-dev**. Docs/AUDIT.md lista os requisitos ausentes
que bloqueiam 1.0. Não houve publicação Steam ou teste comercial certificado.
