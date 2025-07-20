#!/bin/bash

# Színek
YELLOW='\033[0;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

REPO="simplex-chat/simplex-chat"
API_URL="https://api.github.com/repos/$REPO/releases"
TARGET_DIR="$HOME/Applications"

mkdir -p "$TARGET_DIR"

echo -e "\n${YELLOW}Release információk lekérése...${RESET}\n"

release_info=$(curl -s "$API_URL")

appimage_url=$(echo "$release_info" | grep -i 'browser_download_url.*AppImage' | head -n 1 | cut -d '"' -f 4)
version=$(echo "$release_info" | grep -m 1 '"tag_name":' | cut -d '"' -f 4)

if [ -z "$appimage_url" ] || [ -z "$version" ]; then
    echo -e "${RED}\nHiba: Nem található AppImage vagy verziószám\n${RESET}"
    exit 1
fi

filename="simplex-desktop-${version//./_}.AppImage"
filepath="$TARGET_DIR/$filename"

echo -e "Legutóbbi elérhető verzió: ${GREEN}$version${RESET}\n"

echo -ne "${YELLOW}Letölti?${RESET} [Y/n] "
read -r response
echo ""
response=${response,,}
if [[ "$response" =~ ^(n|no)$ ]]; then
    echo -e "${RED}Letöltés megszakítva${RESET}\n"
    exit 0
fi

if [ -f "$filepath" ]; then
    echo -ne "${RED}A fájl már létezik:${RESET} $filename. ${RED}Felülírja?${RESET} [y/N] "
    read -r overwrite
    echo ""
    overwrite=${overwrite,,}
    if [[ ! "$overwrite" =~ ^(y|yes)$ ]]; then
        echo -e "${RED}Letöltés megszakítva${RESET}\n"
        exit 0
    fi
fi

echo -e "${YELLOW}Letöltés:${RESET} $appimage_url\n"
wget -q --show-progress "$appimage_url" -O "$filepath"
echo -e "\nLetöltés: ${GREEN}kész${RESET}\n"

chmod +x "$filepath"
echo -e "Fájl futtathatóvá tétele: ${GREEN}kész${RESET}\n"

echo -e "${GREEN}Sikeresen letöltve: $filepath${RESET}\n"
