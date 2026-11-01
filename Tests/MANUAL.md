# Verificação manual e entrega

Os resultados automatizados estão em `PROGRESS.md`. Esta lista não é uma
declaração de aprovação manual. Registre Godot, SO, GPU, driver e resolução em
cada execução, além dos problemas observados.

1. Abrir o jogo em Windows 10/11 x64 e Linux x64 reais. Confirmar menu com mundo
   visível, textos PT/EN legíveis e créditos de felipealx.
2. Iniciar jornada; caminhar, correr, pular e colidir com terreno e árvores.
   Verificar câmera próxima de paredes e telhados e ausência de atravessamento.
3. Abrir inventário; confirmar cursor livre e controles bloqueados. Fechar e
   confirmar captura do mouse. Testar resolução, VSync, FPS, sensibilidade,
   tela cheia e os quatro níveis gráficos.
4. Derrubar árvores com três golpes próximos; confirmar crédito de madeira
   uma única vez e ausência de perda do recurso quando o inventário está cheio.
5. Fabricar fogueira com oito madeiras e abrigo com doze; verificar consumo
   exato, prévia, posições inválidas sem consumo e colisões após construir.
6. Examinar fogueira, fumaça/brasas, áudio espacial, sombra e iluminação à noite.
   Verificar diferenças reais de vegetação/sombras/partículas entre qualidades.
7. No host, ativar chuva pelo menu climático. Permanecer exposto: dano climático
   bruto zero até 40s, primeiro dano em 55s, depois 1HP em 70/85/100s. Medir os
   eventos e considerar a regeneração de 1HP/3s separadamente.
8. Entrar sob telhado antes do dano; confirmar reinício da contagem, ausência
   de chuva sob cobertura e novo período de proteção ao sair. Confirmar reset
   quando a chuva cessa. Fogueira aquece, mas não substitui cobertura.
9. Conferir transições de clima, áudio de chuva/trovão e iluminação de raios,
   visibilidade em neblina e consistência de dia/noite entre clientes.
10. Hospedar e conectar dois clientes por IP; movimentar, atacar árvores,
    fabricar e construir no mesmo mundo. Conferir inventários individuais e
    que intenções malformadas não concedem itens, teletransportam ou alteram HP.
11. Salvar e reiniciar; conferir árvores, estruturas, posição e inventário.
    Em dados de teste copiados, corromper apenas o snapshot mais recente;
    confirmar recuperação do anterior. Confirmar falha segura com dois escritores.
12. Extrair cada ZIP em uma pasta nova sem editor; executar o cliente Linux e
    Windows e o servidor. Conferir arquivos de créditos/licenças presentes.
13. No Windows, instalar `TribesOfFire-*-Windows-Setup.exe` sem administrador,
    usar atalho do menu Iniciar, atualizar e desinstalar; conferir preservação
    dos saves e ausência de remoção de arquivos alheios. Instalador sem assinatura
    digital nesta versão; publicação/assinatura comercial ainda não executadas.
14. Medir CPU/GPU, memória, frame times e tráfego de rede em hardware real,
    inclusive Ryzen 5 4600G/16GB em 1080p, antes de declarar metas de desempenho.

Não editar nem corromper saves importantes. Testes de queda abrupta devem usar
pastas isoladas, com todos os processos encerrados antes da recuperação de lock.
Multiplayer externo exige acesso UDP à porta configurada e testes de rede reais;
um teste local não comprova autorização nem conectividade pela Internet.
