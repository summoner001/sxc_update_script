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
INCLUDE_PRERELEASE=true # Állítsa False-ra, ha nem szeretne pre-release-t telepíteni, csak stable/latest-et

# Verzióösszehasonlító-függvény
version_compare() {
    local v1=$(echo "$1" | sed 's/^v//;s/-.*//')
    local v2=$(echo "$2" | sed 's/^v//;s/-.*//')
    
    # Dátum kinyerése a kiadásból (ISO 8601 formátum)
    local date1=$(grep -A 10 "\"tag_name\": \"$1\"" <<< "$releases" | grep '"published_at"' | cut -d '"' -f 4)
    local date2=$(grep -A 10 "\"tag_name\": \"$2\"" <<< "$releases" | grep '"published_at"' | cut -d '"' -f 4)
    
    # Numerikus verzióösszehasonlítás
    local IFS=.
    local i ver1=($v1) ver2=($v2)
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        elif ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done
    
    # Ha a verziószámok megegyeznek, dátum alapján dönt
    [[ "$date1" > "$date2" ]]
}

# Könyvtárak létrehozása
mkdir -p "$TARGET_DIR"
mkdir -p "$(dirname "$DESKTOP_FILE")"

# Jelenlegi verzió lekérdezése
current_version=""
if [ -f "$DESKTOP_FILE" ]; then
    current_version=$(grep -oP 'Version=\Kv[0-9.]+' "$DESKTOP_FILE" || echo "")
fi

echo -e "\n${YELLOW}Új verzió keresése...${NC}\n"

# Kiadási információk letöltése
releases=$(curl -s "$API_URL")

# Legújabb verzió keresése
find_latest_release() {
    local latest_tag=""
    local latest_url=""
    local latest_date=""
    
    # Feldolgoz minden kiadást
    while read -r line; do
        if [[ $line =~ \"tag_name\":\ \"([^\"]+)\" ]]; then
            current_tag="${BASH_REMATCH[1]}"
            prerelease=false
        elif [[ $line =~ \"prerelease\":\ true ]]; then
            prerelease=true
        elif [[ $line =~ \"published_at\":\ \"([^\"]+)\" ]]; then
            current_date="${BASH_REMATCH[1]}"
        elif [[ $line =~ \"browser_download_url\":\ \"([^\"]*$APPIMAGE_NAME[^\"]*)\" ]]; then
            current_url="${BASH_REMATCH[1]}"
            
            if [[ -n "$current_tag" && -n "$current_url" ]]; then
                if [[ "$INCLUDE_PRERELEASE" == "true" || "$prerelease" == "false" ]]; then
                    if [[ -z "$latest_tag" ]] || version_compare "$current_tag" "$latest_tag"; then
                        latest_tag="$current_tag"
                        latest_url="$current_url"
                        latest_date="$current_date"
                    fi
                fi
            fi
        fi
    done <<< "$releases"
    
    if [[ -n "$latest_tag" ]]; then
        echo "${latest_tag}|${latest_url}"
    else
        echo ""
    fi
}

latest_release=$(find_latest_release)
if [ -z "$latest_release" ]; then
    echo -e "${RED}Hiba: Nem található érvényes release${NC}\n"
    exit 1
fi

latest_version=$(echo "$latest_release" | cut -d'|' -f1)
appimage_url=$(echo "$latest_release" | cut -d'|' -f2)

echo -e "Telepített verzió: ${GREEN}${current_version:-Nincs}${NC}"
echo -e "Elérhető legújabb verzió: ${GREEN}$latest_version${NC}"
if [[ "$latest_version" == *"beta"* || "$latest_version" == *"alpha"* ]]; then
    echo -e "${YELLOW}Figyelem: Ez egy pre-release verzió!${NC}"
fi
echo ""

# Verzióösszehasonlítás
if [[ "$current_version" == "$latest_version" ]]; then
    echo -e "${GREEN}Már a legfrissebb verzió van telepítve.${NC}"
    echo -ne "${YELLOW}Mégis újraletölti és felülírja?${NC} [i/N] "
    read -r force_update
    echo ""
    force_update=${force_update,,}
    if [[ ! "$force_update" =~ ^(i|igen|y|yes)$ ]]; then
        echo -e "${GREEN}Nincs szükség frissítésre.${NC}\n"
        exit 0
    fi
    echo -e "${YELLOW}Kényszerített frissítés...${NC}\n"
else
    if version_compare "$current_version" "$latest_version"; then
        echo -e "${YELLOW}Figyelem: A telepített verzió ($current_version) újabbnak tűnik, mint a legújabb kiadás ($latest_version)!${NC}"
        echo -ne "${YELLOW}Folytatja a frissítést?${NC} [i/N] "
        read -r downgrade
        echo ""
        downgrade=${downgrade,,}
        if [[ ! "$downgrade" =~ ^(i|igen|y|yes)$ ]]; then
            echo -e "${RED}Frissítés megszakítva${NC}\n"
            exit 0
        fi
    fi
    
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

# Desktop fájl frissítése
echo -e "${YELLOW}.desktop fájl frissítése...${NC}"
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

echo -e ".desktop fájl frissítve: ${GREEN}kész${NC}\n"

echo -e "${GREEN}A frissítés sikeresen befejeződött!${NC}\n"
echo -e "Új verzió: ${GREEN}$latest_version${NC}"
echo -e "AppImage helye: ${GREEN}$APPIMAGE_PATH${NC}"
echo -e ".desktop fájl helye: ${GREEN}$DESKTOP_FILE${NC}\n"

exit 0
