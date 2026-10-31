param([string]$Out)
# Fallback card art for the YouTube tab (replaced by the video thumbnail once loaded).
. (Join-Path $PSScriptRoot "card_lib.ps1")
$cards = @(
    @("sbt", "SBT", "#0033A0", "#E4002B"),
    @("sbtnews", "SBT News", "#0033A0", "#00A3E0"),
    @("tvglobo", "TV Globo", "#1E3C72", "#E6007E"),
    @("getv", "ge tv", "#0B6E2E", "#06381A"),
    @("cazetv", "CazéTV", "#111111", "#F2C200"),
    @("jogoaberto", "Jogo Aberto", "#003C82", "#00A1E4"),
    @("crunchyroll", "Crunchyroll", "#F47521", "#7A2E00"),
    @("pokemonpt", "Pokémon", "#FFCB05", "#2A75BB"),
    @("pokemontv", "Pokémon TV", "#2A75BB", "#0B2E5A"),
    @("toei", "Toei Animation", "#C8102E", "#3A0008"),
    @("sato", "Sato Company", "#5B2C83", "#1A0A2A")
)
foreach ($c in $cards) {
    New-Card (Join-Path $Out ("yt_" + $c[0] + ".png")) 400 225 $c[1] "YouTube" $c[2] $c[3]
}
Write-Output "yt cards ok"
