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

# Verzióösszehasonlító-függvény (sort -V használatával)
# Ez a függvény helyesen kezeli a "v6.4.4" és "v6.4.4-beta.0" formátumokat
version_compare() {
    # Összehasonlítja, hogy $1 újabb vagy egyenlő-e $2-vel
    # A `sort -V` rendezi a verziószámokat, a `tail -n1` visszaadja a legnagyobbat.
    # Ha a legnagyobb verzió megegyezik az elsővel ($1), akkor az $1 >= $2.
    [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]
}

# Könyvtárak létrehozása
mkdir -p "$TARGET_DIR"
mkdir -p "$(dirname "$DESKTOP_FILE")"

# Jelenlegi verzió lekérdezése (a teljes verziószámot olvassa ki)
current_version=""
if [ -f "$DESKTOP_FILE" ]; then
    # A regex-et javítottuk, hogy a teljes verziószámot kinyerje (pl. v5.5.0-beta.2)
    current_version=$(grep -oP 'Version=\K.*' "$DESKTOP_FILE" || echo "")
fi

echo -e "\n${YELLOW}Új verzió keresése...${NC}\n"

# Kiadási információk letöltése
# A jq használata sokkal stabilabb és egyszerűbb, mint a manuális feldolgozás
# Ha nincs telepítve a jq, a szkript a régi, grep alapú módszert használja
if command -v jq &> /dev/null; then
    releases_json=$(curl -s "$API_URL")
    if [[ "$INCLUDE_PRERELEASE" != "true" ]]; then
        releases_json=$(jq 'map(select(.prerelease == false))' <<< "$releases_json")
    fi
    # A kiadásokat a verziószám alapján rendezi a jq és a sort -V segítségével
    latest_release_info=$(jq -r '.[].tag_name' <<< "$releases_json" | sort -V | tail -n1)
    
    if [ -n "$latest_release_info" ]; then
        latest_version="$latest_release_info"
        appimage_url=$(jq -r --arg tag "$latest_version" '.[] | select(.tag_name == $tag) | .assets[] | select(.name | endswith("x86_64.AppImage")) | .browser_download_url' <<< "$releases_json")
        latest_release="${latest_version}|${appimage_url}"
    else
        latest_release=""
    fi
else
    # Régi módszer, ha a jq nem elérhető
    releases=$(curl -s "$API_URL")
    find_latest_release() {
        local latest_tag=""
        local latest_url=""
        
        # A kiadások feldolgozása a jq helyett grep/sed párossal
        local tags_and_urls=$(echo "$releases" | grep -oP '(?<="tag_name": ")[^"]*|(?<="prerelease": )(true|false)|(?<="browser_download_url": ")[^"]*' | grep -E "($APPIMAGE_NAME|v[0-9]|\btrue\b|\bfalse\b)")
        
        local current_tag=""
        local prerelease_status=""
        
        while read -r line; do
            if [[ "$line" =~ ^v[0-9] ]]; then
                current_tag=$line
            elif [[ "$line" == "true" || "$line" == "false" ]]; then
                prerelease_status=$line
            elif [[ "$line" == *"$APPIMAGE_NAME" ]]; then
                if [[ "$INCLUDE_PRERELEASE" == "true" || "$prerelease_status" == "false" ]]; then
                    if [[ -z "$latest_tag" ]] || ! version_compare "$latest_tag" "$current_tag"; then
                        latest_tag="$current_tag"
                        latest_url="$line"
                    fi
                fi
            fi
        done <<< "$tags_and_urls"
        
        if [[ -n "$latest_tag" ]]; then
            echo "${latest_tag}|${latest_url}"
        else
            echo ""
        fi
    }
    latest_release=$(find_latest_release)
fi


if [ -z "$latest_release" ] || [ -z "$(echo "$latest_release" | cut -d'|' -f2)" ]; then
    echo -e "${RED}Hiba: Nem található érvényes release vagy letöltési URL.${NC}\n"
    exit 1
fi

latest_version=$(echo "$latest_release" | cut -d'|' -f1)
appimage_url=$(echo "$latest_release" | cut -d'|' -f2)

echo -e "Telepített verzió: ${GREEN}${current_version:-Nincs}${NC}"
echo -e "Elérhető legújabb verzió: ${GREEN}$latest_version${NC}"
if [[ "$latest_version" == *"beta"* || "$latest_version" == *"alpha"* || "$latest_version" == *"rc"* ]]; then
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
    if [[ -n "$current_version" ]] && version_compare "$current_version" "$latest_version"; then
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
# Az Icon útvonalát javítottam, feltételezve, hogy az ikon a TARGET_DIR-ben van
cat > "$DESKTOP_FILE" <<EOL
[Desktop Entry]
Version=$latest_version
Name=SimpleX Chat
Comment=Private and secure open-source messenger - no user IDs
Exec=$APPIMAGE_PATH %U
Icon=$TARGET_DIR/simplex.png
StartupWMClass=chat-simplex-desktop-MainKt
Type=Application
Terminal=false
Categories=Network;Chat;
EOL

# Ikon letöltése, ha még nem létezik (opcionális, de ajánlott)
if [ ! -f "$TARGET_DIR/simplex.png" ]; then
    echo -e "${YELLOW}Ikon letöltése...${NC}"
    wget -q "https://raw.githubusercontent.com/simplex-chat/simplex-chat/stable/apps/desktop/assets/icon.png" -O "$TARGET_DIR/simplex.png"
    echo -e "Ikon letöltve: ${GREEN}kész${NC}\n"
fi


echo -e ".desktop fájl frissítve: ${GREEN}kész${NC}\n"
# Asztali adatbázis frissítése, hogy a változások azonnal megjelenjenek
update-desktop-database -q "$HOME/.local/share/applications"

echo -e "${GREEN}A frissítés sikeresen befejeződött!${NC}\n"
echo -e "Új verzió: ${GREEN}$latest_version${NC}"
echo -e "AppImage helye: ${GREEN}$APPIMAGE_PATH${NC}"
echo -e ".desktop fájl helye: ${GREEN}$DESKTOP_FILE${NC}\n"

exit 0
