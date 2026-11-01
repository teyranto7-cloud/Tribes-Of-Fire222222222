# Progresso — 0.2.0-dev

Criado por **felipealx**. Esta é uma entrega de desenvolvimento, não a conclusão
das quinze fases da especificação. Data de validação: 1 de novembro de 2026.

## Implementado

- Materialização da versão anterior em arquivos reais Godot, preservando coleta,
  personagem, inventário, crafting, fogueiras, relógio, opções e saves.
- Correção da coleta com inventário cheio: recompensa reservada antes do corte.
- Câmera de cenário já no menu inicial.
- Personagem próprio com rosto, cabelo, roupas, mãos/pés e animações articuladas.
- Árvores com galhos e copas, grama instanciada com vento, materiais e paleta.
- LOD de árvores por distância, ondas na água e reflexão estática de ambiente
  em Alto/Ultra, sem alegar reflexos planares ou SSR.
- Sol/lua e amanhecer/entardecer; sombras e luzes quentes de fogo configuráveis.
- Fogueiras com som espacial, fumaça/brasas, colisão e zona limitada de conforto.
- Estados de céu limpo/nublado, chuva leve/forte, tempestade e neblina, com
  transições, vento visual, áudio procedural, relâmpagos e trovão atrasado.
- Chuva sincronizada; regra exata de 40 s iniciais + 15 s até cada dano, com
  regeneração independente, sem taxa vinculada à intensidade.
- Abrigo fabricável com teto físico inclinado, colisão e bloqueio da chuva.
- Solo, hospedagem por jogador e ENet dedicado; movimento, coleta, fabricação,
  construções, inventários e clima controlados pela autoridade.
- Identidade local aleatória com handshake e hash persistido para reconexão.
- Interface PT/EN e ajustes reais de gráficos, resolução, FPS e sensibilidade.
- Persistência v2 com migração, corrupção/fallback, lock e contadores climáticos.
- Exportação Windows/Linux/dedicado, ZIPs e instalador NSIS por usuário.

## Evidências

Godot **4.6.3.stable.official.7d41c59c4**, Linux x64. Validação real:

| Verificação | Resultado |
|---|---|
| Importação e parser | Passaram, sem erros de script |
| Regras: inventário, vida, relógio, clima, chuva, schema e corrupção | 60 verificações, 0 falhas |
| Mundo: colisão, cobertura, chuva, qualidade, LOD, restauração | 24 verificações, 0 falhas |
| Player: física, intenção, timeout, ataque e snapshots | 11 verificações, 0 falhas |
| Input → Main → Session → movimento, câmera e inventário | 8 verificações, 0 falhas |
| Gameplay integrado: coleta atômica, crafting, construção, save/load e chuva | 17 verificações, 0 falhas |
| Processos: escritor concorrente, SIGKILL, recusa e recuperação do lock | 4 verificações, 0 falhas |
| ENet isolado: servidor + 2 clientes, intenções e ações | Passou; 4 comandos maliciosos rejeitados |
| Gameplay multiplayer: servidor + 2 clientes reais | Passou; ambos moveram, receberam 30 snapshots e viram coleta compartilhada; 8 madeiras e 2 perfis persistidos |
| Reconexão com novo ID e reinício real do servidor | Passou; identidade e inventário restaurados |
| Exportação Windows x64 / Linux x64 / dedicado Linux | Três executáveis gerados sem erros |
| Executáveis Linux fora do editor: cliente, dedicado e reinício | 6 verificações, 0 falhas; saves/checksums/locks verificados |
| Cliente Linux exportado com renderização OpenGL | Abriu jornada, renderizou, salvou e saiu com código 0; VSync indisponível no display virtual |

As cinco suítes GDScript somam **120 verificações**; o teste entre processos
acrescenta quatro. Logs da execução ficam em `builds/logs/`.

Seis capturas de renderização real estão em `builds/screenshots/`. Elas mostram
menu, dia, personagem, noite, tempestade e abrigo. Renderer OpenGL/Mesa llvmpipe
com Xorg dummy, 1280 × 720. A inspeção levou à correção de cores sRGB e exposição
do terreno; não é benchmark da GPU de referência.

Foram corrigidos também dois problemas revelados pelos testes de rede:
fragmentação de snapshots acima do MTU e envio durante desconexão simultânea.
Snapshots usam fragmentação confiável e o relay entre clientes foi desativado;
replicação passa sempre pela autoridade. Logs finais de gameplay multiplayer e
reconexão encerraram sem erros ou avisos de recursos. Playbacks de áudio são
parados e drenados antes da saída; o teste World também aguarda essa liberação.

O empacotador gera ZIP Windows/Linux/servidor e instalador NSIS Windows, verifica
integridade dos ZIPs e inclui licenças oficiais do Godot. Checksums ficam em
`dist/SHA256SUMS.txt`. **A instalação e execução em Windows continuam não testadas.**
Nenhuma meta de FPS, GPU integrada ou 100 jogadores foi comprovada.

## Limitações e fases pendentes

- Fome, sede, alimentos/cozimento, caça, animais/IA, camas e respawn selecionável.
- Mineração/fundição, equipamentos, armaduras e combate PvP.
- Construção modular completa, encaixe/rotação/reparos/resistência/destruição.
- Tribos, permissões, territórios, alianças, guerras e proteções diplomáticas.
- Continente 12 km, biomas, rios/cavernas/ilhas/barcos, terreno editável e streaming.
- Persistência transacional/journal e durabilidade contra queda de energia.
- Senha, autenticação comercial, descoberta pública, Steamworks e distribuição Steam.
- Occlusion culling elaborado e relevância de rede.
- GI, volumetria, água com reflexos avançados e benchmarks em hardware real.
- Validação do instalador e dos executáveis em Windows 10/11.

Qualidade visual e animações são procedurais iniciais, não arte final.
Não apresentar estes itens como concluídos em uma versão publicada.
