# Atualização de arquitetura — 0.5.0-dev

Mesma cena Main e módulos da 0.4, sem troca de engine. Esta revisão acrescenta:

- Terrain: gerador 2 tamanho 1536, preservando 0/1. Edits de altura em malha 4 m são
  copiados para novo sampler imutável. Chunks e colisão são reconstruídos após
  alteração. Horizonte/floresta distante são visuais e não substituem física.
- Mining:158 IDs estáveis,22 originais preservados, recursos/ervas/flores adicionais,
  visibilidade por terreno carregado, rebrota e ações de servidor.
- Factory: estado input/output/progress validado, receitas fixas, produção em
  servidor ativo, transferências atômicas e filtro de inventário por proprietário.
- Building/Piece: jangada, tocha e lamparina. Jangada movimentada por intenções
  validadas no Player, com limites de água/obstáculos. Replicas atualizam posição
  sem recriar geometria. Não há simulação hidrodinâmica avançada.
- Tribes: relações por par, pedido/aceite, guerra/paz, trégua UTC 3600 s, proteção
  aliada. Proteção de saída/expulsão 300 s permanece. Dados são autoritativos.
- UI: abas Mochila/Fabricação/Construir, busca, custos, motivos e fila; painéis
  de máquina e diplomacia. Novos textos PT/EN; revisão dos seis idiomas pendente.
- Persistence: schema 4 mantido com descritor 0/1/2 e campos novos opcionais
  validados. Saves 0.4 não mudam de mapa. Crescimento de catálogo não altera IDs
  históricos. Escavação/máquinas/jangada/alianças são salvos em snapshots existentes.

Não há WAL/fsync nem garantia contra queda de energia. Rede ainda ENet experimental,
sem capacidade 100 jogadores comprovada ou autenticação comercial. Limites completos
em PROGRESS.md e Docs/PENDENCIAS.md. A arquitetura anterior está no histórico Git.
