# Análise do NuvioTV x Amaro TV

Repositório analisado: https://github.com/NuvioMedia/NuvioTV (commit `a102f6b`, 03/11/2026, licença GPL-3.0).

## Resumo

- **NuvioTV** é um app Android TV (Kotlin + Jetpack Compose + ExoPlayer/mpv). Não roda em Roku, então código não pode ser copiado; só ideias e APIs.
- **Ele não traz nenhuma fonte de vídeo embutida.** O modelo é "traga suas fontes": o usuário instala add-ons no padrão Stremio, conecta Jellyfin/Emby/Plex ou contas debrid. Por isso **não existe lista de canais, filmes ou séries para reaproveitar**.
- O que dá para reaproveitar são **APIs públicas de metadados, legendas e "pular abertura"**, listadas abaixo. Todas foram testadas em 03/11/2026.

## URLs confiáveis para reaproveitar (testadas)

| Serviço | Endpoint | Para quê | Chave? | Status |
|---|---|---|---|---|
| **Cinemeta** (Stremio) | `https://v3-cinemeta.strem.io/meta/{movie\|series}/{imdbId}.json` | Pôster, fundo, sinopse, elenco, **lista completa de temporadas/episódios com thumbnails** | Não | 200 OK |
| Cinemeta catálogos | `https://v3-cinemeta.strem.io/catalog/movie/top.json` (redireciona para `cinemeta-catalogs.strem.io`) | Listas "Populares" de filmes/séries | Não | 200 OK |
| **OpenSubtitles v3** (Stremio) | `https://opensubtitles-v3.strem.io/subtitles/movie/{imdbId}.json` e `.../series/{imdbId}:{temp}:{ep}.json` | **Legendas SRT**; tem `pob` (PT-BR) e `por` (PT-PT) | Não | 200 OK — Big Bang S01E01 tem 6 legendas PT-BR |
| **AniSkip** | `https://api.aniskip.com/v2/skip-times/{malId}/{ep}?types[]=op&types[]=ed&episodeLength=0` | **Botão "Pular abertura/encerramento"** em animes | Não | 200 OK |
| Anime-Skip | `https://api.anime-skip.com/graphql` | Alternativa ao AniSkip | Client ID grátis | não testado |
| Tiffara (Parents Guide) | `https://api.tiffara.com/titles/{imdbId}/parentsGuide` | Classificação/conteúdo sensível (sexo, violência…) | Não | 200 OK |
| TMDB | `https://api.themoviedb.org/3/...` | Metadados, trailers (`/videos`), elenco, logos | Sim (grátis) | já usamos as imagens |
| YouTube thumbs | `https://img.youtube.com/vi/{id}/hqdefault.jpg` | Thumbnail de trailers/vídeos | Não | 200 OK |
| wsrv.nl | `https://wsrv.nl/?url={img}&w=300&output=jpg` | Proxy que **redimensiona/converte imagens** (bom para Roku: menos memória, webp→jpg) | Não | 200 OK |
| Trakt / Simkl / MDBList | `api.trakt.tv`, `api.simkl.com`, `api.mdblist.com` | Sincronizar "assistidos", notas IMDb/RT/Metacritic | Sim (OAuth/conta) | não testado |
| IntroDB | URL privada (vem do `local.properties`) | Pular intro em séries | — | **não é pública**, não dá para usar |

Não reaproveitar: endereços de debrid (Real-Debrid, Premiumize, TorBox) e trackers de torrent — dependem de conta paga ou de torrent, e não fazem sentido no Roku.

## Funcionalidades que o NuvioTV tem e nós não

Ordenado por ganho para o Amaro TV x esforço no Roku.

### Alto valor, viável no Roku
1. **Legendas** — o player do Roku aceita SRT externo (`subtitleTracks` no nó `Video`). Com o OpenSubtitles v3 basta ter o IMDb ID de cada série/filme no `catalog.json`. Nuvio também tem: atraso de legenda, estilo (cor/tamanho), filtro de SDH.
2. **Pular abertura/encerramento** — AniSkip para animes (usa o MAL ID, que a AniList já devolve no campo `idMal`). Para séries, alternativa: marcar `introStart/introEnd` manualmente no `catalog.json`.
3. **Próximo episódio automático** — overlay "Próximo episódio em 10s" no fim do vídeo (`NextEpisodeEndPromptOverlay`). Já temos `gridResume`, falta o prompt.
4. **"Continuar assistindo" na Home** — fileira com o que está pela metade (filmes e séries), com barra de progresso no pôster.
5. **Metadados automáticos via Cinemeta** — hoje escrevemos sinopse/ano/nota à mão no `catalog.json`. Com o IMDb ID, dá para buscar tudo (inclusive nomes e thumbnails dos episódios) e montar a página de detalhes.
6. **Página de detalhes mais rica** — elenco, trailer (YouTube), "Mais como este", notas por episódio, logo do título no lugar do texto.
7. **Marcar episódio como assistido** e **episódio aleatório** (shuffle — bom para sitcoms).
8. **Modo ambiente / protetor de tela** — slideshow de fundos dos títulos quando a TV fica parada.
9. **Velocidade de reprodução** e **seleção de faixa de áudio** (dublado/legendado) no player.
10. **"Ainda está assistindo?"** — pausa após N episódios seguidos sem interação.

### Médio valor
11. **Perfis** (vários usuários, cada um com sua lista e progresso).
12. **Temas/cores personalizáveis** e escolha de layout da Home (clássico/moderno/grade).
13. **Teste de velocidade da internet** nas configurações (usa a API do fast.com).
14. **Busca unificada** com tela "Descobrir" por gênero/ano.
15. **Aviso de conteúdo** (Parents Guide) antes de tocar.
16. **Relatório de problema de reprodução** — enviar para o nosso Worker quando um link falha (já temos `StreamCheckTask`, falta reportar).

### Grande / pouco viável no Roku
17. Sincronização com Trakt/Simkl (OAuth por código na TV — possível, mas trabalhoso).
18. Watch Party (assistir junto, sincronizado) — precisa de backend próprio.
19. Integração com Jellyfin/Emby (servidor de mídia caseiro).
20. Sistema de add-ons/plugins no padrão Stremio.
21. Login por QR code e sincronização na nuvem (Supabase).
22. Recursos de vídeo avançados (Dolby Vision, mpv, troca automática de taxa de quadros) — o Roku cuida disso sozinho.

## O que nós temos e o NuvioTV não

- TV ao vivo com 400+ canais e **guia de programação (EPG)**.
- Canais 24h, canais do YouTube ao vivo e calendário de animes da AniList.
- Conteúdo já incluso no app, sem o usuário configurar nada.

## Atenção sobre "links confiáveis" no nosso catálogo

Os filmes e séries do `catalog.json` apontam para `dbonline.tech-cdn.top` (via nosso Worker). Esse tipo de servidor costuma cair ou mudar sem aviso e normalmente não tem direitos de distribuição do conteúdo — é o ponto mais frágil do app. O NuvioTV evita isso justamente por não embutir fontes. Fontes estáveis e legais que já usamos: archive.org, Pluto TV, canais públicos (Câmara, TV Cultura etc.).

## Sugestão de ordem de implementação

1. Adicionar `imdb` em cada série/filme do `catalog.json`.
2. Legendas PT-BR via OpenSubtitles v3.
3. Próximo episódio automático + "Continuar assistindo" na Home.
4. Pular abertura em animes (AniSkip).
5. Metadados automáticos via Cinemeta (nomes/thumbnails de episódios).
