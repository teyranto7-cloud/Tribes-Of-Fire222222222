# Progresso — 0.3.0-dev

Criado por **felipealx**. Validação em 2 de novembro de 2026 (UTC), Linux x64,
Godot **4.6.3.stable.official.7d41c59c4**. Incremento real sobre 0.2.0-dev;
os critérios obrigatórios de 1.0 continuam incompletos.

## Implementado e integrado

- Funcionalidades anteriores preservadas: mundo/colisões, câmera, árvores/coleta,
  inventário, crafting, fogueiras, telhados, dia/noite, clima, host/dedicado e saves.
- Criação de personagem com preview real, nome, 18 parâmetros, variação de cabelos,
  barbas/olhos/roupa, altura cosmética 1,35–1,65 m e Skeleton3D de nove ossos.
  Aparência validada pela autoridade e restaurada do save. Arte ainda inicial.
- Agachamento com mudança real de cápsula e teste de espaço para levantar,
  esquiva com stamina/cooldown, defesa, câmera suave/zoom e controles remapeáveis.
- Catálogo de recursos, ferramentas, armas e armaduras; 36 espaços, arrastar/dividir,
  equipar, consumir, descartar e recuperar bolsas, transações de custo/recompensa.
- Fome, sede, alimentos, fonte potável, cozinhar carne junto ao fogo, morte e
  renascimento inicial; sem camas ou seleção de ponto de respawn.
- Mineração/coleta em 22 depósitos, picaretas, bancada/fornalha com colisão/custo,
  fundição cobre/bronze/ferro/aço e receitas que verificam estação próxima.
- Seis espécies/12 animais com navegação em grade e física, fuga/perseguição,
  retorno, ataque com aviso, limite 20 HP, cadáver e saque concedido uma vez.
- Combate autoritativo com armas/munição, alcance e oclusão, stamina/cooldown,
  durabilidade, armadura, bloqueio/esquiva. Arco usa acerto por raio nesta fase.
- Tribos, líder, convites, entrada/saída/expulsão/transferência; dano aliado recusado.
  Proteção bilateral de 300 s após saída/expulsão, persistida por identidade/UTC.
- Chat global/local/privado/grupo/tribo/diplomacia, histórico limitado, comandos,
  grupos por convite, bloqueio, salas privadas por aceite e roteamento server-side.
- Voz real opt-in: captura/mixer, resampling, IMA ADPCM, canal ENet separado,
  validação, decodificação, fila limitada, reprodução espacial ou remota autorizada.
  Volumes/mudos individuais persistidos; microfone desativado a cada abertura.
- Seis idiomas e fonte japonesa, 233 entradas em cada catálogo; primeira escolha,
  troca em execução e persistência. Algumas mensagens técnicas antigas precisam
  de migração; revisão linguística nativa integral ainda pendente.
- Seis perfis gráficos, Médio padrão, escalabilidade real e configuração pendente;
  confirmação de resolução em 15 s sem persistir preview, fallback `--safe`.
- Áudio original em 20 WAV, música por estado com crossfade, sons posicionais,
  passos, pooling e buses/volumes independentes persistidos.
- Persistência v3 de aparência/espaços/equipamentos/necessidades/tribos/grupos/
  bloqueios/fauna/recursos/estações/bolsas, migrações anteriores, schema/checksum/lock.
  Chamadas e convites de comunicação exigem novo aceite após reinício do processo.
- Logs técnicos de inicialização/salvamento sem conversas, voz ou tokens.
- Consolidação das malhas estáticas de árvores/depósitos por material, preservando
  triângulos, colisões, animação de queda e LOD; IA/animação reduzidas à distância.
- Exportação real Windows/Linux/dedicado; recibo de hashes impede empacotar fontes
  ou binários diferentes dos exportados. Setup mantém TLS/SHA512/APT verificados.
- NSIS Unicode com seis idiomas, opção de atalho marcada por padrão, menu Iniciar,
  lançamento final, ícone, instalação por usuário e desinstalação preservando dados.
  Script PowerShell de QA para conta Windows limpa e modo seguro no pacote Windows.

## Evidências reproduzíveis

| Verificação | Resultado nesta versão |
|---|---|
| Importação e parser da aplicação | Sem erros |
| Regras de inventário, vida, relógio, clima, chuva e persistência | 61 verificações, 0 falhas |
| Mundo/colisões/teto/qualidade/LOD/consolidação | 25 verificações, 0 falhas |
| Player/física/intenção/ataque/snapshots | 11 verificações, 0 falhas |
| Input → Main → Session → player/câmera/inventário | 8 verificações, 0 falhas |
| Gameplay integrado anterior | 17 verificações, 0 falhas |
| Novos módulos/UI/tribos/voz/aparência/fauna/arco/save | 109 verificações, 0 falhas |
| Escritor concorrente/SIGKILL/recusa/recuperação/liberação do lock | 4 verificações, 0 falhas |
| ENet isolado: 1 servidor/2 clientes, payload e admin indevidos | Passou |
| Jogo real: dedicado/2 clientes, movimento e coleta compartilhada | Passou; ambos confirmaram estado, 8 madeiras observadas |
| Reconexão com novo peer e reinício real do servidor | Passou; inventário e identidade restaurados |
| Comunicação: dedicado/3 clientes, seis canais e áudio codificado | Passou; áudio entregue/reproduzido apenas nos participantes permitidos |
| PvP na cena real da comunicação | Dano aliado e pós-saída recusados, sem dano aplicado |
| Captura sintética pelo mixer → codec → reprodução | Passou; nenhum microfone físico iniciado |
| Windows x64 / Linux x64 / dedicado Linux | Três executáveis exportados sem erros |
| Linux exportado fora do editor: solo/dedicado/reinício | 6 verificações, 0 falhas; snapshots/checksums/locks conferidos |
| Linux exportado com OpenGL | Renderizou, iniciou jornada, salvou e saiu com código 0; aviso de VSync do display virtual |
| ZIPs / instalador NSIS | Gerados; NSIS Unicode com seis tabelas de idioma, ZIPs verificados e hashes em dist/ |
| Execução/instalação Windows 10/11 | **Não executada** neste ambiente Linux |
| Voz com microfones/fones físicos | **Não executada**; testes usaram sinal sintético |
| 60 FPS no 4600G / 100 jogadores | **Não comprovados** |

As seis suítes GDScript somam **231 verificações**; processos acrescentam quatro
(total **235**). Os testes de executáveis acrescentam seis (total **241**), além
dos cenários multiprocesso com marcadores próprios. Não contar cada pacote como
um teste separado. Logs finais ficam em builds/logs/ e evidências em Docs/TEST_REPORT.md.

## Falhas encontradas e corrigidas

Durante integração: inferência GDScript em testes, validação NUL de texto que
rejeitava mensagens válidas, layout de pilhas após crafting, preview de resolução
salvo antes da confirmação, ataque principal do arco que não selecionava modo
ranged e envio público das preferências privadas de comunicação e durabilidade de ferramenta substituta. A tradução de nomes compostos de
itens/controles também foi ajustada às chaves dos catálogos. Foram corrigidos
e os testes correspondentes passaram.

Uma execução do smoke multiplayer falhou porque o primeiro cliente encerrava
assim que comprovava o estado compartilhado, antes de o segundo poder verificá-lo.
O fixture mantém os clientes conectados durante a janela de validação; a repetição
passou. Não foi tratado como prova de falha de transporte nem ocultado.

Uma importação sem liberação de sockets/configuração de cache falhou no sandbox;
a execução com permissões locais e diretórios adequados passou. O display virtual
não suporta VSync; o aviso é registrado. Nenhum resultado Windows foi inferido.

## Medição e limites

Nove amostras curtas de renderização, câmera fixa, 1280 × 720, OpenGL/Mesa llvmpipe,
CPU reportada EPYC 9V74, cinco processadores visíveis. Aquecimento de 1 s e amostra
de 4 s para dia/noite/tempestade em Muito Baixo/Médio/Ultra. JSON antes/depois em
builds/reports/. A execução posterior coincidiu parcialmente com trabalho de build,
portanto tempos/FPS não constituem comparação controlada de ganho.

Chamadas de desenho diurnas: Muito Baixo ~548 → ~416, Médio 1.934 → 1.302,
Ultra ~4.339 → 2.238. Memória estática reportada pelo Godot caiu aproximadamente de
114–118 MiB para 101–102 MiB nessas amostras. Esse contador não é RSS total.
FPS posterior: ~14,5–18,7 em Muito Baixo e ~1,8–2,8 em Médio/Ultra. O renderizador
é software; desempenho permanece insuficiente nesse ambiente e não é o resultado
da GPU de referência. Tempo de GPU não disponível; não foi inventado.

Sete telas reais inspecionadas em builds/screenshots/v3/ mostram idiomas, menu,
criador, aparência, japonês, gráficos e inventário. A inspeção ampliou o personagem
no preview e confirmou glyphs japoneses; não certifica arte final ou revisão nativa.

## Pendências que impedem 1.0

Construção modular completa/baús/camas, agricultura/ecologia e regeneração dos
recursos, mundo amplo/seed selecionável/streaming/biomas/cavernas/barcos/terreno
editável, arte/animações cinematográficas finais, territórios/alianças/guerras,
proteção diplomática de 1 h, autenticação/senha/segurança comercial, relevância de
rede/predição/testes de carga, journal/WAL/energia, Opus/eco/voz física, revisão
linguística integral, Windows reais, benchmark no hardware alvo e Steamworks.

Depósitos e fauna são finitos nesta versão; alguns minérios não têm progressão
completa. Durabilidade é por tipo de item. Snapshots ainda compartilham inventários
de outros jogadores. A matriz detalhada e critérios de liberação estão em
Docs/AUDIT.md. Não publicar esta entrega como 1.0 nem prometer desempenho validado.
