# Amaro TV - webOS (LG Smart TV)

## Pré-requisitos

1. **Ativar Developer Mode na TV LG:**
   - Na TV, abra a LG Content Store
   - Busque e instale o app "Developer Mode"
   - Abra o app Developer Mode
   - Faça login com sua conta LG Developer (crie em webostv.developer.lge.com)
   - Ative "Dev Mode Status" = ON
   - Ative "Key Server" = ON
   - Reinicie a TV quando solicitado

2. **Instalar webOS CLI (ares) no PC:**
   ```
   npm install -g @webos-tools/cli
   ```

3. **Registrar a TV no CLI:**
   ```
   ares-setup-device
   ```
   - Escolha "add"
   - Nome: LGTV
   - IP: 192.168.18.162
   - Port: 9922
   - User: prisoner
   - Auth: password
   - Password: (pegar da tela Dev Mode na TV, campo "Key Server")

## Instalar o App

### Opção 1: Script automático
```powershell
.\deploy-webos.ps1
```

### Opção 2: Manual
```bash
# Empacotar
ares-package webos-tv-livre

# Instalar
ares-install --device LGTV com.amarotv.app_1.0.0_all.ipk

# Lançar
ares-launch --device LGTV com.amarotv.app

# Ver logs (debug)
ares-inspect --device LGTV com.amarotv.app
```

## Estrutura
- `appinfo.json` - Manifesto do app webOS
- `index.html` - App completo (single-page, adaptado pra controle remoto)
- `icon.png` - Ícone 80x80
- `largeIcon.png` - Ícone 130x130
- `splash.png` - Splash screen 1920x1080

## Diferenças da versão Roku
- Roku: BrightScript nativo (`roku-tv-livre/`)
- webOS: Web app HTML/JS empacotado (esta pasta)
- Ambos usam o mesmo `catalog.json` do GitHub

## Navegação (controle remoto)
- Setas: navegar
- OK/Enter: selecionar
- Back: voltar
- Números 0-9: ir direto ao canal (ex: 15 = canal 15)
- Setas Up/Down no player: zapping (canal +/-)
