# TV Livre — canal Roku (Roku OS 11.5+)

Central de conteúdo gratuito e legal para TVs Roku antigas.

| Seção | Fonte |
|---|---|
| Ao Vivo | TV Câmara (camara.gov.br), NASA TV — links oficiais |
| Filmes / Séries / Desenhos | Internet Archive, só itens em domínio público ou Creative Commons |
| Animações Abertas | Filmes da Blender Foundation (Creative Commons) |
| Animes | Calendário de episódios da API pública AniList (informação, sem vídeo) |
| Minha Lista | Favoritos e "continuar assistindo", salvos na própria TV |
| Buscar | Busca no acervo do Internet Archive |

## Tela inicial (launcher)

O app abre numa tela com papel de parede e carrossel no rodapé: engrenagem (vai para a tela inicial da Roku, onde ficam as Configurações), TV ao vivo, TV Livre, Conexões (HDMI/AV), apps instalados e Central de Apps.
Os apps abrem pela ECP da própria TV (porta 8060). **Segure OK** (ou `*`) num card para **Mover** ou **Ocultar** (só apps instalados); a ordem fica salva na TV.
Papel de parede e ícones: `python -I tools/launcher_assets.py tools/assets/wallpaper_fiorde.webp roku-tv-livre/images`.
Teste pela rede: `powershell -File tools/roku_test.ps1 -Steps "launch/dev,keypress/Right,keypress/Select"`.

O app procura episódios novos de anime ao abrir e a cada 6 horas (badge "N novos" na home; `*` força a busca).
As fileiras "Adicionados recentemente" mostram o que entrou de novo no acervo.

## Instalar na TV

1. No controle da Roku: **Home 3x, Cima 2x, Direita, Esquerda, Direita, Esquerda, Direita**.
2. Ative o *Developer Mode*, anote o IP mostrado e defina uma senha. A TV reinicia.
3. Opção A: abra `http://IP-DA-TV` no navegador do PC (usuário `rokudev`), envie `tv-livre.zip` e clique **Install**.
   Opção B: no PowerShell desta pasta:

```
powershell -ExecutionPolicy Bypass -File deploy.ps1 -RokuIp 192.168.0.50 -Password suaSenha
```

## Configurar

Tudo em `roku-tv-livre/config/catalog.json`: seções, fileiras (consultas do Internet Archive), canais ao vivo.
`versionUrl` (opcional): URL de um JSON `{"version":"1.0.2","message":"..."}`; se a versão for maior que a do `manifest`, o app avisa.
Depois de editar, rode o `deploy.ps1` de novo.

### Catálogo online (sem deploy)

`catalogUrl` (opcional): endereço de uma cópia do `catalog.json` na internet (ex.: link "Raw" de um GitHub Gist, sem o código da revisão no meio, para sempre pegar a última versão).
Com ele preenchido, a TV baixa o catálogo toda vez que o app abre e passa a usar a cópia online — basta editar o arquivo online e reabrir o app.
Se o download falhar ou o JSON estiver inválido, a TV continua com a última cópia boa (ou com o catálogo do pacote).
Para voltar a usar só o catálogo do pacote, deixe `catalogUrl` vazio e faça o deploy.

### Continuar assistindo

Filmes e séries guardam onde parou. Filmes mostram "Continuar de 12:34" e "Do início"; a aba Filmes ganha a fileira "Continuar assistindo" e a Minha Lista mostra filmes, séries e itens do Internet Archive.
Ao terminar um episódio em tela cheia, o próximo começa sozinho em 10 s (OK começa já, Voltar cancela).
