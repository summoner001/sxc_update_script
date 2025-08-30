#!/bin/bash

# Színek
YELLOW='\033[0;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Beállítások
REPO="simplex-chat/simplex-chat"
API_URL="https://api.github.com/repos/$REPO/releases"
TARGET_DIR="$HOME/SimpleX"
DESKTOP_FILE="$HOME/.local/share/applications/SimpleX_Chat.desktop"
APPIMAGE_NAME="simplex-desktop-x86_64.AppImage"
APPIMAGE_PATH="$TARGET_DIR/$APPIMAGE_NAME"

# Könyvtárak létrehozása, ha nem léteznek
mkdir -p "$TARGET_DIR"
mkdir -p "$(dirname "$DESKTOP_FILE")"

# Jelenlegi verzió lekérdezése a desktop fájlból
current_version=""
if [ -f "$DESKTOP_FILE" ]; then
    current_version=$(grep -oP 'Version=\Kv[0-9.]+' "$DESKTOP_FILE" || echo "")
fi

echo -e "\n${YELLOW}Új verzió keresése...${NC}\n"

# Legújabb verzió információk lekérése
release_info=$(curl -s "$API_URL")
latest_version=$(echo "$release_info" | grep -m 1 '"tag_name":' | cut -d '"' -f 4)
appimage_url=$(echo "$release_info" | grep -i "browser_download_url.*$APPIMAGE_NAME" | head -n 1 | cut -d '"' -f 4)

if [ -z "$appimage_url" ] || [ -z "$latest_version" ]; then
    echo -e "${RED}Hiba: Nem található AppImage vagy verziószám${NC}\n"
    exit 1
fi

echo -e "Telepített verzió: ${GREEN}${current_version:-Nincs}${NC}"
echo -e "Elérhető legújabb verzió: ${GREEN}$latest_version${NC}\n"

# Verziók összehasonlítása
if [ "$current_version" = "$latest_version" ]; then
    echo -e "${GREEN}Már a legfrissebb verzió van telepítve.${NC}"
    echo -ne "${YELLOW}Mégis letölti újra és felülírja?${NC} [i/N] "
    read -r force_update
    echo ""
    force_update=${force_update,,}
    if [[ ! "$force_update" =~ ^(i|igen|y|yes)$ ]]; then
        echo -e "${GREEN}Nincs szükség frissítésre.${NC}\n"
        exit 0
    fi
    echo -e "${YELLOW}Kényszerített frissítés...${NC}\n"
else
    echo -ne "${YELLOW}Új verzió érhető el. Letöltés és frissítés?${NC} [I/n] "
    read -r answer
    echo ""
    answer=${answer,,}
    if [[ "$answer" =~ ^(n|no|nem)$ ]]; then
        echo -e "${RED}Frissítés megszakítva${NC}\n"
        exit 0
    fi
fi

# AppImage letöltése
echo -e "${YELLOW}Letöltés:${NC} $appimage_url\n"
wget -q --show-progress "$appimage_url" -O "$APPIMAGE_PATH"
if [ $? -ne 0 ]; then
    echo -e "${RED}Hiba történt az AppImage letöltése közben${NC}\n"
    exit 1
fi
echo -e "\nLetöltés: ${GREEN}kész${NC}\n"

# Futtathatóvá tétel
chmod +x "$APPIMAGE_PATH"
echo -e "Fájl futtathatóvá tétele: ${GREEN}kész${NC}\n"

# Desktop fájl létrehozása/frissítése
echo -e "${YELLOW}Desktop fájl létrehozása/frissítése...${NC}"
cat > "$DESKTOP_FILE" <<EOL
[Desktop Entry]
Version=$latest_version
Name=SimpleX Chat $latest_version
Comment=Private and secure open-source messenger - no user IDs
Exec=$APPIMAGE_PATH
Icon=$TARGET_DIR/SimpleX.png
StartupWMClass=chat-simplex-desktop-MainKt
Type=Application
Terminal=false
Categories=Network;Chat;
EOL

echo -e "Desktop fájl létrehozva/frissítve: ${GREEN}kész${NC}\n"

echo -e "${GREEN}A frissítés sikeresen befejeződött!${NC}\n"
echo -e "Új verzió: ${GREEN}$latest_version${NC}"
echo -e "AppImage helye: ${GREEN}$APPIMAGE_PATH${NC}"
echo -e "Desktop fájl helye: ${GREEN}$DESKTOP_FILE${NC}\n"

exit 0
