# Arquitetura — 0.2.0-dev

`Main.gd` coordena menus, ciclo local, autoridade, persistência e replicação.
O projeto anterior foi preservado em módulos, com evolução dos visuais e regras.

| Módulo | Responsabilidade |
|---|---|
| World | Terreno triangulado com colisão, 160 árvores determinísticas, grama MultiMesh, água visual, relógio e luz |
| Player | Física CharacterBody3D na autoridade, intenções limitadas, timeout, câmera SpringArm e modelo articulado original |
| Core | Inventário, crafting atômico, limites e vida/regeneração |
| Weather | Modelo determinístico, transições, estados sincronizados, exposição e integração cronológica de dano/regeneração |
| Building | Fogueira com som espacial, calor, brasas/fumaça e abrigo com painéis inclinados de colisão no teto |
| Networking | ENet, RPC de intenções/ações, validação de remetente e limites de frequência, snapshots da autoridade |
| Persistence | Schema v2, migração v1, SHA256, snapshots alternados e lock exclusivo por processo |
| UI | PT-BR/EN, menus, inventário, servidor, clima administrativo e configurações |
| Tools | Setup, importação, testes, exportação, ZIP e instalador NSIS |

## Autoridade e apresentação

Solo, anfitrião e servidor dedicado usam as mesmas regras. O cliente manda eixo
de movimento, orientação e ações. O servidor executa física e valida alcance,
cooldown, recursos e espaço para construir. IDs vêm da conexão, não do payload.
Clientes interpolam os estados de jogadores recebidos; predição avançada e
compensação de latência ainda não foram implementadas. Snapshots são enviados
a 10 Hz, com transporte confiável para estados maiores que o MTU.

Um handshake vincula o peer temporário ao hash de uma identidade aleatória local.
Inventário e posição sobrevivem a uma nova conexão; uma identidade já conectada
é rejeitada. A identidade trafega por ENet sem criptografia; o protocolo é para
desenvolvimento em redes confiáveis e ainda precisa de autenticação comercial.

O servidor é a única origem de dano climático. Exposure integra os eventos de
regeneração e dano em ordem temporal, inclusive quando um tick cruza vários
intervalos. O cliente apenas mostra esses contadores. A cobertura é consultada
por raycast no teto físico. Colunas visuais de chuva terminam na primeira
superfície e são invalidadas quando um abrigo é construído.

## Renderização e mundo

O terreno mede 128 × 128 m, seed fixa 1337. A geração distribui trabalho entre
frames; não é streaming de mundo nem geração assíncrona em threads. A grama usa
instancing e shader de vento; árvores têm troncos, galhos e copas próprias.
Árvores alternam entre malhas detalhadas e simplificadas por distância.
Personagem usa peças anatômicas arredondadas e animação procedural articulada.
Áudio de chuva, trovão e fogo é sintetizado no projeto.

Compatibility funciona com OpenGL. Densidade/alcance da grama, sombras e chuva
variam por qualidade. Não existem recursos silenciosamente apresentados como
implementados: SSR, GI, volumetria, oceanos navegáveis e terreno editável ainda
faltam. A água atual é visual, sem natação.
Seu shader tem ondas e usa reflexão de ambiente estática em Alto/Ultra;
isso não é reflexão planar do cenário em tempo real.

## Persistência e entrega

Schema v2 armazena jogadores, inventários, HP, intervalo de regeneração,
exposição, cortes, construções, relógio e estado/RNG climático. O slot mais novo
válido é carregado; corrupção de um slot permite recuperar o anterior.
O lock é conservador e não é roubado automaticamente após crash. Não se deve
confundir checksum com autenticidade contra um administrador que edita o save.

As exportações usam presets Windows/Linux x64 e Linux dedicado. O empacotador
valida cabeçalhos PE/ELF, integridade ZIP e gera SHA256. NSIS instala por usuário
e mantém os dados pessoais fora da pasta de instalação. A presença de um build
Windows não comprova sua execução no Windows.

## Fronteiras seguintes

Persistência transacional com journal e recuperação automática segura; perfis de
rede autenticados para Internet; protocolo incremental por relevância; testes
de carga e latência. Depois, sobrevivência alimentar, caça/IA, mineração,
combate/armaduras, construção modular, tribos/diplomacia e streaming por biomas.
Não há módulos vazios contabilizados como funcionalidades.
