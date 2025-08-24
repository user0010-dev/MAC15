#!/bin/bash
#AUTOMAC PRO - LICENSE REQUIRED

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Licenza cliente - MODIFICARE CON LICENZA REALE
LICENSE_KEY="CLIENTE_ABC123"

# Variabile per memorizzare se l'autenticazione è avvenuta
AUTHENTICATED=false

# messaggi colorati
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

# Funzione per verificare la licenza
verify_license() {
    local license_key="$1"
    local mac_address=$(ifconfig en0 | grep ether | awk '{print $2}')
    
    print_status "Connessione al server licenze..."
    local json_data=$(curl -s "https://raw.githubusercontent.com/user0010-dev/automac-licenses-server/main/licenses.json")
    
    if [ -z "$json_data" ]; then
        print_error "Impossibile connettersi al server licenze"
        return 1
    fi
    
    # Cerca la licenza nel JSON
    if echo "$json_data" | grep -q "\"$license_key\""; then
        local status=$(echo "$json_data" | grep -A5 "\"$license_key\"" | grep '"status"' | cut -d'"' -f4)
        local saved_mac=$(echo "$json_data" | grep -A5 "\"$license_key\"" | grep '"mac_address"' | cut -d'"' -f4)
        
        if [ "$status" = "active" ]; then
            if [ -z "$saved_mac" ]; then
                echo "ACTIVATED:$mac_address"
                return 0
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
    if [ -n "$1" ]; then
        # Modalità non interattiva
        input_hash=$(echo -n "$1" | shasum -a 256 | awk '{print $1}')
        if [ "$input_hash" == "$PASSWORD_HASH" ]; then
            AUTHENTICATED=true
            return 0
        else
            print_error "Password errata"
            return 1
        fi
    else
        # Modalità interattiva
        echo -n "Inserisci password: "
        read -s input_password
        echo
        input_hash=$(echo -n "$input_password" | shasum -a 256 | awk '{print $1}')
        if [ "$input_hash" == "$PASSWORD_HASH" ]; then
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
    
    if command_exists "brew"; then
        brew update
        brew upgrade
        brew cleanup
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
    print_status "Cercando file grandi (>100MB)..."
    find ~ -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -10
    print_status "Top 10 cartelle più grandi:"
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
    osascript -e 'tell application "System Events" to get name of every process where background only is false' 2>/dev/null || echo "Non è possibile ottenere la lista delle applicazioni"
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
    echo -e "\n${GREEN}=== AutoMac PRO - Licenza: ATTIVA ===${NC}"
    echo "1. Aggiorna sistema"
    echo "2. Pulizia sistema"
    echo "3. Gestione spazio disco"
    echo "4. Backup home directory"
    echo "5. Monitoraggio sistema"
    echo "6. Controllo sicurezza"
    echo "7. Informazioni rete"
    echo "8. Installa applicazioni"
    echo "9. Tutte le operazioni"
    echo "0. Esci"
    echo -n "Scegli un'opzione: "
}

# Main execution
main() {
    # Verifica licenza all'inizio
    print_status "Verifica licenza in corso..."
    if ! verify_license "$LICENSE_KEY"; then
        print_error "Licenza non valida. Acquista su: https://tuosito.com"
        exit 1
    fi
    print_success "Licenza verificata con successo!"
    
    # Autenticazione per operazioni protette
    case "${1:-}" in
        "1"|"2"|"4"|"8"|"9")
            if ! authenticate "$2"; then
                exit 1
            fi
            ;;
        *)
            if [ $# -eq 0 ]; then
                if authenticate; then
                    print_success "Autenticazione riuscita"
                else
                    print_warning "Modalità limitata: alcune funzioni non disponibili"
                fi
            fi
            ;;
    esac

    # Esecuzione in base all'opzione
    case "${1:-}" in
        "1") update_system ;;
        "2") clean_system ;;
        "3") disk_management ;;
        "4") backup_home ;;
        "5") system_monitor ;;
        "6") security_check ;;
        "7") network_info ;;
        "8") install_essentials ;;
        "9")
            if [ "$AUTHENTICATED" = true ]; then
                update_system
                clean_system
                disk_management
                security_check
                system_monitor
            else
                print_error "Autenticazione richiesta"
            fi
            ;;
        *)
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
                    8) install_essentials ;;
                    9)
                        if [ "$AUTHENTICATED" = true ]; then
                            update_system
                            clean_system
                            disk_management
                            security_check
                            system_monitor
                        else
                            print_error "Autenticazione richiesta"
                        fi
                        ;;
                    0)
                        print_status "Arrivederci!"
                        exit 0
                        ;;
                    *) print_error "Opzione non valida" ;;
                esac
                echo -e "\nPremi Invio per continuare..."
                read
            done
            ;;
    esac
}

# Esegui il main
main "$@"
