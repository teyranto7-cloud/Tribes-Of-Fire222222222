# Arquitetura — reconstrução 0.4.0-dev

Criador: **felipealx**. A base existente foi preservada. `Scenes/Main.tscn` entra
em `Main.gd`, que coordena cena, sessões, jogadores, tempo autoritativo, saves e
replicação. `Game/Runtime.gd` integra comandos e módulos. Não há troca de engine.

| Módulo | Responsabilidade atual |
|---|---|
| Settings / Graphics | Autoload Settings; configuração compartilhada, aplicação imediata dos seis perfis, preview/rollback somente do display |
| World / Terrain | Descritor seed/gerador/tamanho; relevo determinístico, chunks, árvores/IDs/rebrota, biomas, água e apresentação ambiental |
| Player / Character | Física autoritativa, câmera/colisão, esquiva/agachamento/natação, modelo original, rig e ações procedurais |
| Core / Items / Data | Inventário/transações/equipamentos/desgaste, catálogo, vida; novos valores compartilhados em Balance.json |
| Crafting / Progression | Fila com recursos reservados, cancelamento/reparo; XP por uso e pesquisa pessoal/tribal |
| Survival / Weather | Fome/sede/comida, clima, chuva/frio/cobertura/calor, eventos cronológicos de dano e regeneração |
| Building | Prefabs preservados e peças modulares físicas, portas, cama vinculável, baús de materiais/canteiros |
| Mining / Animals | Depósitos/rebrota, ações e saques, fauna com comportamentos passivos/neutros/predadores, domesticação básica e pesca |
| Combat / Tribes | Alcance/oclusão, stamina/desgaste, PvP, líder/convites e proteção bilateral de saída/expulsão |
| Game / Journal | Exploração por células, marcadores pessoais/tribais e eventos por jogador |
| Networking | ENet, whitelist/rate limit, handshake de identidade/senha/versão, snapshots por destinatário/deltas e moderação |
| Communication / Audio | Chat/grupos/salas/chamadas, voz opt-in, áudio espacial e música/buses/pooling |
| UI / Localization | Menus/inventário/mapa/opções; seis catálogos/fonte CJK, com traduções novas ainda pendentes |
| Persistence | Schema v4/migrações, limites e validação, SHA256, slots alternados, temporário verificado e lock exclusivo |
| Tools / Tests | Setup, testes, exportação com recibo de fontes/binários, fontes filtradas, ZIPs e instalador NSIS |

## Mundo e compatibilidade

O descritor `{seed, generator, size}` identifica a geração. Saves antigos migram
para gerador 0, seed 1337, tamanho 128 e mantêm o relevo original. Novas jornadas
usam gerador 1 e tamanho 320; campos de ruído e localização de recursos usam seed.
320² representa 6,25 vezes a área da malha antiga de 128²; isso não equivale a um
mundo final de 12 × 12 km.

`World/Terrain.gd` produz dados de terreno sem modificar a cena. Trabalho de malha
vai ao WorkerThreadPool; inserção de nós/colisores ocorre na thread principal.
Fila prioriza regiões próximas; uma geração obsoleta não é instalada. Chunks
saem da cena com histerese. A física do jogador e fauna aguarda terreno ativo.
IDs e registros de árvores cortadas/rebrota sobrevivem ao descarregamento.

Há representação inicial de biomas, costa, rio/lago, caverna e ruína. Ainda faltam
validação ampla de costuras, ecologia/distribuição, barcos, terreno volumétrico
editável e exploração/desempenho do continente final. Depósitos ainda reaproveitam
parte da distribuição inicial; não anunciar distribuição final por bioma.

## Comandos, recursos e apresentação

A autoridade recebe intenções e comandos, nunca concessões de itens ou posição
final. Valida identidade, schema, alcance/altura, oclusão, ferramenta, custo,
permissão e intervalo. Atividades de coleta mantêm estado de duração e revalidam
antes de concluir. Madeira e minério são materiais físicos recolhidos depois;
falha de espaço não concede itens duplicados. A fila de fabricação reserva o custo
e só entrega a saída válida; cancelamento preserva recursos se não puder devolver.

Durabilidade ainda é por tipo de item. Baús recusam depósito de equipamentos para
não perder seu desgaste; armazenamento de materiais é o MVP atual. Peças possuem
colisores/custo/rotação/estado persistido, mas resistência estrutural, reparação e
destruição de uma base complexa não estão concluídas. Cama altera o ponto de
respawn vinculado. Cultivo limita-se a bagas e domesticação ao comportamento básico.

O modelo e a vegetação são malhas originais construídas por código. Rig conecta
animações a movimento e ações reais. Arte cinematográfica final, auditoria visual
completa e benchmark físico permanecem pendentes. Compatibility é o renderer;
não há alegação de SSR, GI ou iluminação volumétrica.

## Tempo, cobertura, chuva e vida

Solo, host e dedicado usam as mesmas regras. Tempo de clima/relógio/sobrevivência
usa relógio monotônico, evitando atraso das regras por FPS baixo. Movimento mantém
passo de física. Uma pausa longa não reconstrói trajetórias que não foram simuladas.
A exposição divide o delta nos limites de 40/55/70 s e aplica eventos cronológicos,
sem repetir dano pela taxa de frames.

Sem teto/calor válidos: 40 s iniciais sem dano e primeiro dano aos 55 s; depois
1 HP a cada 15 s. Cobertura física ou fim da chuva reinicia o contador. O pedido de
reconstrução permite que calor interrompa perda por frio, mantendo a exposição
contínua; sair do calor não concede um novo período inicial. Fogueiras consomem
combustível e chuva sem cobertura pode apagá-las. Calor consulta alcance/oclusão.
Roupas com proteção térmica funcional ainda são uma pendência.

Regeneração segura mantém 1 HP/3 s após espera configurável padrão de 6 s desde
o dano. Fome/sede esgotadas, combate ou exposição nociva impedem regeneração.
O servidor aplica dano e respawn; perda na morte é configurável. A restauração
deve conservar o próximo intervalo de chuva e a durabilidade dos itens.

## Rede e estado privado

`Networking/Session.gd` valida protocolo/versão, identidade e prova HMAC por nonce
para senha opcional. Identidade local persistida vincula o perfil; não é uma conta
comercial. O transporte ENet continua sem criptografia. Não anunciar segurança de
servidor público ou capacidade comprovada para 100 jogadores.

Main cria snapshot por destinatário: inventário/espaços/desgaste, necessidades,
progressão/fila e journal são privados do dono. Equipamento aparente, movimento e
vida ficam disponíveis para representação dos outros jogadores. Conteúdo de baús
é filtrado por autorização; eventos de armazenamento são dirigidos. SnapshotCodec
envia diferenças e full snapshots periódicos. Ainda falta relevância espacial,
predição, compensação de latência e medição de banda/carga com 8–16 clientes.

Configuração JSON define nome, porta, senha, limite, seed, PvP, perda na morte,
dia/noite, recursos, dificuldade e identidades administrativas/banidas. Moderação
usa identidades autorizadas; bandeira de UI enviada ao cliente não concede poder
no servidor. Configuração pública omite senha e listas privadas. A aplicação de balanceamento
ainda é parcial: resource_rate afeta madeira; normal/difícil não têm diferenciação
completa. Não anunciar escalabilidade de todos os recursos ou níveis completos.

Tribos preservam proteção bidirecional por 300 s após saída/expulsão, inclusive
reconexão. Expiração usa UTC do servidor; não existe defesa contra alteração do
relógio do SO. Diplomacia/alianças/guerras e bloqueio de hostilidade por 1 h ainda
não foram implementados. Grupos, bloqueios e chamadas da comunicação continuam
em eventos dirigidos; chamadas exigem aceite novo após desconexão/reinício.

Voz: captura Godot → mono 16 kHz → pacotes IMA ADPCM de 40 ms → canal ENet dedicado
→ validação/roteamento → decodificação → fila limitada → reprodução espacial ou
remota autorizada. Não é Opus. Eco, ruído, dispositivos físicos e comportamento
sob carga não foram certificados nesta revisão.

## Preferências e persistência

Autoload `/root/Settings` fornece Graphics e acesso a `user://settings.cfg`.
ConfigStore mescla seções antes de gravar temporário e renomear; gráficos, entrada,
áudio, idioma e bindings compartilham esse arquivo. Preferências antigas possuem
migrações parciais; tipos/limites são validados. Recuperação faz backup `.bak` de
arquivo ilegível/malformado ou versão incompatível; a cobertura de todos os casos
inválidos e permissões ainda exige teste. `identity.cfg` permanece separado.

Saves v4 incluem descritor, jogador, itens, estruturas, módulos integrados e suas
filas/progressão/plantio/pesca. Migração v1/v2/v3 preserva gerador legado. Limites de
posições dependem do descritor; IDs, quantidades e dados de módulos são validados.
Envelope até 16 MiB/payload 8 MiB, até 1.024 perfis históricos. Lock é obtido antes
de carregar; dois slots inválidos causam recusa sem mundo novo silencioso.

Dois snapshots alternados protegem contra corrupção de um slot; não equivalem a
transações WAL/fsync. Crash pode perder ações desde o último save e deixar lock
para recuperação explícita, depois de parar processos e copiar os dados. Logs
não gravam conversas, voz ou tokens. Configuração e dados pessoais não pertencem
a pacotes de código ou instalação.

## Build e liberação

`project.godot` é a fonte da versão; `Tools/version.py` deriva nomes de pacotes e
versão numérica de exportação/NSIS. `Tools/build.py` importa, testa e congela a
assinatura das fontes durante exportação. Alteração invalida o recibo.
`package.py` exige esse recibo, verifica executáveis/ZIPs e grava manifesto/SHA256.
Fontes usam allowlist e excluem segredos, saves e saídas; não seguem symlinks.

NSIS instala por usuário, seis idiomas, atalhos e uninstall preservando dados.
O idioma instalado pode inicializar o jogo no Windows; esse caminho novo ainda
precisa de validação nativa. A aprovação Windows 0.3.1 é histórica e não valida
os binários novos. As três exportações 0.4.0-dev foram geradas após 458 verificações
aprovadas; os executáveis Linux passaram em seis verificações de execução/save/
reinício. O executável Windows ainda não foi testado em Windows. O cliente Linux também
abriu graficamente em display virtual por 5 s, sem erro/vazamento observado, além
do aviso de VSync no llvmpipe. QA Windows/workflow foram adaptados estaticamente
para schema4, mundo320 e versão derivada, mas ainda exigem execução nativa.

Cinquenta aberturas headless sequenciais passaram, e os cenários locais de rede,
reconexão/migração e comunicação foram repetidos. Capturas OpenGL foram inspecionadas
no llvmpipe. Esses testes não substituem carga, sessão real de 30 min, microfones
físicos, benchmark alvo ou validação nativa do instalador.

A API GitHub está bloqueada pelo proxy neste ambiente; a publicação foi suspensa
conforme o pedido. Alterar transporte para contornar a restrição não faz parte
da entrega. Resultados atuais estão em Docs/RECONSTRUCTION_TEST_REPORT.md.
