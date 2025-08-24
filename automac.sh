#!/bin/bash
#AUTOMAC PRO - LICENSE SYSTEM AUTOMATICO

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione Licenza
LICENSE_KEY="LICENZA_CLIENTE_001"
GITHUB_TOKEN="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"
REPO_OWNER="user0010-dev"
REPO_NAME="automac-licenses-server"

# Variabile per memorizzare se l'autenticazione è avvenuta
AUTHENTICATED=false

# Messaggi colorati
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Funzione per aggiornare il MAC automaticamente
update_license_on_github() {
    local license_key="$1"
    local mac_address="$2"
    
    # Scarica il file corrente e il suo SHA
    local file_info=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/licenses.json")
    
    local current_sha=$(echo "$file_info" | grep '"sha"' | cut -d'"' -f4)
    local current_content=$(echo "$file_info" | grep '"content"' | cut -d'"' -f4 | base64 -d)
    
    # Sostituisce il MAC address
    local new_content=$(echo "$current_content" | \
        sed "s/\"$license_key\": {[^}]*\"mac_address\": \"[^\"]*\"/\"$license_key\": {\"mac_address\": \"$mac_address\"/")
    
    # Aggiorna su GitHub
    local response=$(curl -s -X PUT -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"message\": \"Auto-update MAC for $license_key\",
            \"content\": \"$(echo -n "$new_content" | base64)\",
            \"sha\": \"$current_sha\"
        }" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/licenses.json")
    
    if echo "$response" | grep -q "commit"; then
        echo "SUCCESS"
        return 0
    else
        echo "ERROR"
        return 1
    fi
}

# Funzione verifica licenza
verify_license() {
    local license_key="$1"
    local mac_address=$(ifconfig en0 | grep ether | awk '{print $2}')
    
    # Scarica licenses.json
    local json_data=$(curl -s "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main/licenses.json")
    
    if echo "$json_data" | grep -q "\"$license_key\""; then
        local status=$(echo "$json_data" | grep -A5 "\"$license_key\"" | grep '"status"' | cut -d'"' -f4)
        local saved_mac=$(echo "$json_data" | grep -A5 "\"$license_key\"" | grep '"mac_address"' | cut -d'"' -f4)
        
        if [ "$status" = "active" ]; then
            if [ -z "$saved_mac" ] || [ "$saved_mac" = "\"\"" ]; then
                # Prima attivazione - aggiorna automaticamente
                if update_license_on_github "$license_key" "$mac_address"; then
                    echo "ACTIVATED:$mac_address"
                    return 0
                else
                    echo "ACTIVATION_FAILED"
                    return 1
                fi
            elif [ "$saved_mac" = "$mac_address" ]; then
                echo "VALID"
                return 0
            else
                echo "INVALID_MAC"
                return 1
            fi
        else
            echo "INACTIVE"
            return 1
        fi
    else
        echo "NOT_FOUND"
        return 1
    fi
}

# Funzione per autenticazione
authenticate() {
    local PASSWORD_HASH="64d38862b5b70b0605734aa56b8c3f0ef95bc43aa7da69ba837a1cfa960765b1"
    if [ -n "$1" ]; then
        input_hash=$(echo -n "$1" | shasum -a 256 | awk '{print $1}')
        if [ "$input_hash" = "$PASSWORD_HASH" ]; then
            AUTHENTICATED=true
            return 0
        else
            print_error "Password errata"
            return 1
        fi
    else
        echo -n "Inserisci password: "
        read -s input_password
        echo
        input_hash=$(echo -n "$input_password" | shasum -a 256 | awk '{print $1}')
        if [ "$input_hash" = "$PASSWORD_HASH" ]; then
            AUTHENTICATED=true
            return 0
        else
            print_error "Password errata"
            return 1
        fi
    fi
}

# Funzione per verificare se autenticato
check_authenticated() {
    if [ "$AUTHENTICATED" = false ]; then
        print_error "Operazione non autorizzata"
        return 1
    fi
    return 0
}

# Update del sistema
update_system() {
    if ! check_authenticated; then
        return 1
    fi
    
    print_status "Aggiornamento del sistema in corso..."
    
    if command -v "brew" >/dev/null 2>&1; then
        brew update
        brew upgrade
        brew cleanup
        print_success "Homebrew aggiornato"
    fi
    
    softwareupdate -i -a
    print_success "Sistema aggiornato"
}

# Cancellazione cache
clean_system() {
    if ! check_authenticated; then
        return 1
    fi
    
    print_status "Pulizia del sistema in corso..."
    
    find ~/Library/Caches -type f -name "*.cache" -delete 2>/dev/null
    find ~/Library/Caches -type f -name "tmp.*" -delete 2>/dev/null
    sudo find /Library/Caches -type f -name "*.cache" -delete 2>/dev/null
    sudo find /var/log -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
    find /tmp -type f -mtime +7 -delete 2>/dev/null
    sudo purge
    
    print_success "Pulizia completata"
}

# Gestione spazio disco
disk_management() {
    print_status "Analisi spazio disco..."
    df -h
    print_status "Cercando file grandi..."
    find ~ -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -10
    print_status "Top 10 cartelle piu grandi:"
    du -h ~ 2>/dev/null | sort -rh | head -11
}

# Backup
backup_home() {
    if ! check_authenticated; then
        return 1
    fi
    
    local backup_dir="/Volumes/Backup/$(date +%Y%m%d_%H%M%S)"
    print_status "Backup della home directory in: $backup_dir"
    mkdir -p "$backup_dir"
    rsync -av --progress ~/ "$backup_dir/" --exclude='.Trash' --exclude='.npm' --exclude='.cache'
    print_success "Backup completato"
}

# Monitoraggio sistema
system_monitor() {
    print_status "Monitoraggio sistema:"
    echo -e "\n${YELLOW}=== USO CPU ===${NC}"
    top -l 1 -s 0 | head -10
    echo -e "\n${YELLOW}=== USO MEMORIA ===${NC}"
    vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free: (\d+)/ and printf("Memoria libera: %.2f MB\n", $1 * $size / 1048576)'
    echo -e "\n${YELLOW}=== PROCESSI ATTIVI ===${NC}"
    ps aux | head -10
}

# Controllo sicurezza
security_check() {
    print_status "Controllo sicurezza..."
    print_status "Stato firewall:"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
    print_status "Aggiornamenti automatici:"
    defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled
    print_status "Applicazioni in esecuzione:"
    osascript -e 'tell application "System Events" to get name of every process where background only is false' 2>/dev/null || echo "Non è possibile ottenere la lista"
}

# Funzione per gestione rete
network_info() {
    print_status "Informazioni di rete:"
    echo -e "\n${YELLOW}=== IP ADDRESS ===${NC}"
    ifconfig | grep "inet " | grep -v 127.0.0.1 | head -5
    echo -e "\n${YELLOW}=== CONNESSIONI ATTIVE ===${NC}"
    lsof -i -P | grep LISTEN | head -5
}

# Menu principale
show_menu() {
    echo -e "\n${GREEN}=== AutoMac PRO ===${NC}"
    echo "1. Aggiorna sistema"
    echo "2. Pulizia sistema"
    echo "3. Gestione spazio disco"
    echo "4. Backup home directory"
    echo "5. Monitoraggio sistema"
    echo "6. Controllo sicurezza"
    echo "7. Informazioni rete"
    echo "0. Esci"
    echo -n "Scegli un'opzione: "
}

# Main execution
main() {
    # Verifica licenza all'inizio
    print_status "Verifica licenza in corso..."
    result=$(verify_license "$LICENSE_KEY")
    
    case "$result" in
        "VALID")
            print_success "Licenza verificata con successo!"
            ;;
        "ACTIVATED:"*)
            print_success "Licenza attivata per questo Mac!"
            ;;
        *)
            print_error "Licenza non valida: $result"
            print_error "Acquista su: https://tuosito.com"
            exit 1
            ;;
    esac
    
    # Menu principale
    while true; do
        show_menu
        read choice
        case $choice in
            1) update_system ;;
            2) clean_system ;;
            3) disk_management ;;
            4) backup_home ;;
            5) system_monitor ;;
            6) security_check ;;
            7) network_info ;;
            0)
                print_status "Arrivederci!"
                exit 0
                ;;
            *)
                print_error "Opzione non valida"
                ;;
        esac
        echo -e "\nPremi Invio per continuare..."
        read
    done
}

# Esegui il main
main "$@"
