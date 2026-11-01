# Tribes of Fire

Criado por **felipealx** · Godot 4.6.3 · **0.2.0-dev** · Windows/Linux x64

Versão de desenvolvimento jogável, materializada a partir da implementação
0.1.0 fornecida na conversa. Ainda não é o jogo completo da especificação.

## Jogar

Extraia o ZIP do seu sistema e execute `TribesOfFire.exe` ou
`./TribesOfFire.x86_64`. No Windows também há um instalador por usuário
`TribesOfFire-0.2.0-dev-Windows-Setup.exe`, com atalhos e desinstalador.
O instalador não exige privilégios de administrador. Binários Windows foram
gerados no Linux; execução e instalação em Windows ainda precisam ser validadas.

Escolha **Nova jornada**. Use WASD para andar, mouse para câmera, Shift para
correr e Espaço para pular. Mire em uma árvore próxima e dê três golpes com o
botão esquerdo: recebe quatro madeiras. Tab abre o inventário. Duas árvores
fornecem as oito madeiras para uma fogueira; três fornecem as doze para um abrigo.
Use 1 para machado, 2 para fogueira e 3 para abrigo. A prévia verde indica
posicionamento permitido; clique para construir. Esc abre o menu.
F5 salva e F9 carrega no modo solo.

O abrigo tem teto e colisões reais. Entre por uma lateral aberta para se proteger.
Fogueiras aquecem em um raio limitado, sem anular o dano por chuva quando exposto.
O painel **Clima** do anfitrião permite testar condições; as mudanças são graduais.

## Multiplayer e servidor

No menu, escolha hospedar ou conectar por IP. A porta padrão é **24567/UDP**.
Dois clientes reais foram testados com um servidor dedicado local. A capacidade
de 100 jogadores é uma meta futura, sem benchmark que a comprove.

    ./TribesOfFireServer.x86_64 --headless -- --server --port=24567 --save-dir=/caminho/mundo --max-players=16

Ou use `start-server.sh` no ZIP do servidor. A porta UDP precisa ser acessível
aos clientes; não há descoberta pública, abertura automática de NAT ou Steamworks.
O relógio e o clima avançam sem jogadores enquanto o processo do servidor roda.
No anfitrião local, o processo do jogo também é o servidor.

Clientes enviam intenções, nunca HP, itens, posições finais ou resultados de
coleta. Movimento, alcance, ferramentas, recursos, crafting, construções e chuva
são calculados pelo servidor. Conexão direta é experimental: use em redes de
confiança. Não há senha, criptografia do transporte ou autenticação Steam.

Cada cliente guarda uma identidade aleatória em `user://identity.cfg`; o servidor
guarda seu hash para restaurar o jogador na reconexão. Preserve esse arquivo e
não o compartilhe: ele não substitui autenticação para servidores públicos.
Para dois jogadores no mesmo computador Linux, use diretórios XDG_DATA_HOME
distintos. Uma identidade não pode ocupar duas conexões simultâneas.

## Chuva e vida

A vida máxima é 100. Cada dano reinicia o intervalo de regeneração: 1 HP a cada
3 segundos completos sem dano. Exposição contínua à chuva tem 40 segundos
iniciais de proteção; o primeiro dano de 1 HP ocorre aos **55 segundos**, seguido
de 1 HP a cada 15 segundos. O dano bruto aos 300 segundos é 17 HP; a regeneração
continua ativa. Entrar sob teto válido ou cessar a chuva reinicia a exposição.
Somente a autoridade avança esses contadores.

## Desenvolver e testar

Abra `project.godot` no Godot **4.6.3 padrão**, sem .NET, e pressione F5.
GDScript usa recursos disponíveis em Godot 4.3+, mas esta entrega foi validada
com 4.6.3. Não há dependências pagas nem recursos gráficos de terceiros no jogo.

    bash Tools/setup.sh
    python3 Tools/build.py --test-only
    python3 Tools/test_network.py
    python3 Tools/test_multiplayer.py --keep-logs builds/logs
    python3 Tools/test_reconnect.py
    python3 Tools/build.py
    python3 Tools/test_exports.py --keep-logs builds/logs
    python3 Tools/package.py

O setup instala templates oficiais com SHA512 verificado e prepara NSIS local
para o instalador. Exportações precisam de templates da versão exata do editor.
As ferramentas preservam verificações TLS e de assinatura dos pacotes.
Em ambientes com rede restrita, os testes ENet exigem permissão para sockets
UDP locais. O editor pode também precisar de sockets locais durante importação.

Os builds ficam em `builds/` e os ZIPs/instalador/checksums em `dist/`.
Scripts de empacotamento incluem atribuições do Godot e verificam os ZIPs.
O renderer Compatibility favorece compatibilidade; não oferece nesta versão
iluminação volumétrica, GI ou reflexos SSR. Qualidade altera instâncias de
grama, alcance, sombras e partículas. Resolução, tela cheia, VSync, FPS,
sensibilidade, som e idioma têm opções funcionais.

## Dados e recuperação

O Godot guarda dados em `user://`; no Linux, normalmente
`~/.local/share/godot/app_userdata/Tribes of Fire/`; no Windows,
`%APPDATA%/Godot/app_userdata/Tribes of Fire/`.
O mundo padrão fica na subpasta `world`. `--save-dir=...` seleciona outra pasta.
Opções pessoais ficam em `settings.cfg`.

Dois snapshots alternados com checksum, schema e arquivo temporário preservam
o último estado válido. Há save manual, automático a cada 45 segundos e ao sair
normalmente. Saves versão 1 migram para versão 2. Um lock exclusivo impede dois
escritores na mesma pasta. Após encerramento abrupto, pare **todos** os processos
que usam esse mundo, faça backup e só então remova a pasta `.writer-lock` para
recuperar. Não apague o lock de um servidor ativo.

Não há journal transacional nem garantia contra queda de energia; ações desde o
último snapshot podem se perder. Veja limitações e resultados em
[PROGRESS.md](PROGRESS.md), arquitetura em [ARCHITECTURE.md](ARCHITECTURE.md)
e verificações manuais em [Tests/MANUAL.md](Tests/MANUAL.md).
