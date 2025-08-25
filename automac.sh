#!/bin/bash
#AUTOMAC PRO - VERSIONE DEFINITIVA

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
CONFIG_DIR="$HOME/.automac"
LICENSE_FILE="$CONFIG_DIR/license.key"

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

# Setup licenza automatico
setup_license() {
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    
    if [ ! -f "$LICENSE_FILE" ]; then
        echo "=== BENVENUTO IN AUTOMAC PRO ==="
        echo "Inserisci la licenza che hai acquistato"
        echo -n "Licenza: "
        read user_license
        echo "$user_license" > "$LICENSE_FILE"
        chmod 600 "$LICENSE_FILE"
        echo "Licenza memorizzata con successo!"
        echo ""
    fi
    
    LICENSE_KEY=$(cat "$LICENSE_FILE" 2>/dev/null | tr -d '[:space:]')
    
    if [ -z "$LICENSE_KEY" ]; then
        print_error "Licenza non valida. Reinserisci la licenza."
        rm -f "$LICENSE_FILE"
        exit 1
    fi
}


verify_license() {
    local license_key="$1"
    
    # URL del file licenses.json
    local json_url="https://raw.githubusercontent.com/user0010-dev/automac-licenses-server/main/licenses.json"
    
    # Scarica il file JSON
    local json_data=$(curl -s "$json_url")
    
    # Verifica se il file JSON è valido
    if [ -z "$json_data" ]; then
        echo "ERROR: Impossibile scaricare il file delle licenze"
        return 1
    fi
    
    # Cerco la licenza nel JSON
    if echo "$json_data" | grep -q "\"$license_key\""; then
        # Estrae lo status della licenza
        local status=$(echo "$json_data" | grep -A5 "\"$license_key\"" | grep '"status"' | cut -d'"' -f4)
        
        if [ "$status" = "active" ]; then
            echo "VALID"
            return 0
        else
            echo "INACTIVE"
            return 1
        fi
    else
        echo "NOT_FOUND"
        return 1
    fi
}

# Update del sistema
update_system() {
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
    # Setup licenza automatico
    setup_license
    
    # Verifica licenza
    print_status "Verifica licenza in corso..."
    result=$(verify_license "$LICENSE_KEY")
    
    case "$result" in
        "VALID")
            print_success "Licenza verificata con successo!"
            ;;
        "INACTIVE")
            print_error "Licenza disattivata. Contatta il supporto."
            exit 1
            ;;
        "NOT_FOUND")
            print_error "Licenza non trovata. Verifica il codice."
            rm -f "$LICENSE_FILE"
            exit 1
            ;;
        *)
            print_error "Errore di connessione. Riprova più tardi."
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
