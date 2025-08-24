#!/bin/bash
#AUTOMAC 0.0.1

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#la password sarà fornita nel prossimo aggiornamento 
PASSWORD_HASH="03ad7fccecf32af81f39d966d55bb09477f6a2f5ce71bd9f4d9cf1e939c7c2f0"

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

# verifica comandi
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# auth
authenticate() {
    if [ -n "$1" ]; then
        # interazzione off
        input_hash=$(echo -n "$1" | shasum -a 256 | cut -d' ' -f1)
        if [ "$input_hash" == "$PASSWORD_HASH" ]; then
            return 0
        else
            print_error "Password errata"
            return 1
        fi
    else
        # interazzione on
        echo -n "Inserisci password: "
        read -s input_password
        echo
        input_hash=$(echo -n "$input_password" | shasum -a 256 | cut -d' ' 
-f1)
        if [ "$input_hash" == "$PASSWORD_HASH" ]; then
            return 0
        else
            print_error "Password errata"
            return 1
        fi
    fi
}

# Update del sistema macos 2.5.2
update_system() {
    if ! authenticate "$1"; then
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

# Cancellazione cache/cose inutili
clean_system() {
    if ! authenticate "$1"; then
        return 1
    fi
    
    print_status "Pulizia del sistema in corso..."
    
    # Pulizia cache utente
    find ~/Library/Caches -type f -name "*.cache" -delete 2>/dev/null
    find ~/Library/Caches -type f -name "tmp.*" -delete 2>/dev/null
    
    # Pulizia cache di sistema
    sudo find /Library/Caches -type f -name "*.cache" -delete 2>/dev/null
    
    # Pulizia log
    sudo find /var/log -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
    
    # Pulizia temporanei di 7 giorni
    find /tmp -type f -mtime +7 -delete 2>/dev/null
    
    # Pulizia memoria
    sudo purge
    
    print_success "Pulizia completata"
}

# Gestione spazio disco
disk_management() {
    print_status "Analisi spazio disco..."
    
    # Mostra uso disco
    df -h
    
    # Trova file grandi (>100MB)
    print_status "Cercando file grandi (>100MB)..."
    find ~ -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -10
    
    # Mostra le 10 cartelle più grandi di leo
    print_status "Top 10 cartelle più grandi:"
    du -h ~ 2>/dev/null | sort -rh | head -11
}

# Backup e funzioni
backup_home() {
    if ! authenticate "$1"; then
        return 1
    fi
    
    local backup_dir="/Volumes/Backup/$(date +%Y%m%d_%H%M%S)"
    print_status "Backup della home directory in: $backup_dir"
    
    mkdir -p "$backup_dir"
    rsync -av --progress ~/ "$backup_dir/" --exclude='.Trash' 
--exclude='.npm' --exclude='.cache'
    
    print_success "Backup completato"
}

# Monitoraggio e anti virus
system_monitor() {
    print_status "Monitoraggio sistema:"
    
    echo -e "\n${YELLOW}=== USO CPU ===${NC}"
    top -l 1 -s 0 | head -10
    
    echo -e "\n${YELLOW}=== USO MEMORIA ===${NC}"
    vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free: 
(\d+)/ and printf("Memoria libera: %.2f MB\n", $1 * $size / 1048576)'
    
    echo -e "\n${YELLOW}=== PROCESSI ATTIVI ===${NC}"
    ps aux | head -10
    
    echo -e "\n${YELLOW}=== TEMPERATURE ===${NC}"
    if command_exists "istats"; then
        istats
    else
        print_warning "Installa istats: brew install istats"
    fi
}

# Scirezza carabinieri
security_check() {
    print_status "Controllo sicurezza..."
    
    # Verifica firewall
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
    
    # Verifica software updates
    defaults read /Library/Preferences/com.apple.SoftwareUpdate 
AutomaticCheckEnabled
    
    # Lista applicazioni aperte
    print_status "Applicazioni in esecuzione:"
    osascript -e 'tell application "System Events" to get name of every 
process where background only is false'
}

# Funzione per gestione rete
network_info() {
    print_status "Informazioni di rete:"
    
    echo -e "\n${YELLOW}=== IP ADDRESS ===${NC}"
    ifconfig | grep "inet " | grep -v 127.0.0.1
    
    echo -e "\n${YELLOW}=== DNS ===${NC}"
    scutil --dns
    
    echo -e "\n${YELLOW}=== CONNESSIONI ATTIVE ===${NC}"
    lsof -i -P | grep LISTEN
}

# Funzione per installare Homebrew e app utili
install_essentials() {
    if ! authenticate "$1"; then
        return 1
    fi
    
    if ! command_exists "brew"; then
        print_status "Installazione Homebrew..."
        /bin/bash -c "$(curl -fsSL 
https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    print_status "Installazione applicazioni essenziali..."
    
    # App da installare
    local apps=(
        "wget"
        "git"
        "python"
        "node"
        "htop"
        "tree"
        "mas"
        "ffmpeg"
    )
    
    for app in "${apps[@]}"; do
        brew install "$app"
    done
    
    print_success "Applicazioni essenziali installate"
}

# Funzione aiuto
show_help() {
    echo -e "${GREEN}=== AutoMac - Guida all'uso ===${NC}"
    echo "Utilizzo:"
    echo "  ./automac.sh [opzione] [password]"
    echo ""
    echo "Opzioni:"
    echo "  1       Aggiorna sistema (richiede password)"
    echo "  2       Pulizia sistema (richiede password)"
    echo "  3       Gestione spazio disco"
    echo "  4       Backup (richiede password)"
    echo "  5       Monitoraggio sistema"
    echo "  6       Controllo sicurezza"
    echo "  7       Informazioni rete"
    echo "  8       Installa applicazioni (richiede password)"
    echo "  9       Tutte le operazioni (richiede password)"
    echo "  0       Esci"
    echo ""
    echo "Password predefinita: macos123"
    echo "Modifica PASSWORD_HASH nello script per cambiarla"
}

# Menu principale
show_menu() {
    echo -e "\n${GREEN}=== AutoMac - Automazione macOS ===${NC}"
    echo "1. Aggiorna sistema (password)"
    echo "2. Pulizia sistema (password)"
    echo "3. Gestione spazio disco"
    echo "4. Backup home directory (password)"
    echo "5. Monitoraggio sistema"
    echo "6. Controllo sicurezza"
    echo "7. Informazioni rete"
    echo "8. Installa applicazioni (password)"
    echo "9. Tutte le operazioni (password)"
    echo "0. Esci"
    echo -n "Scegli un'opzione: "
}

# Esecuzione in base all'opzione
case "${1:-}" in
    "1")
        update_system "$2"
        ;;
    "2")
        clean_system "$2"
        ;;
    "3")
        disk_management
        ;;
    "4")
        backup_home "$2"
        ;;
    "5")
        system_monitor
        ;;
    "6")
        security_check
        ;;
    "7")
        network_info
        ;;
    "8")
        install_essentials "$2"
        ;;
    "9")
        if authenticate "$2"; then
            update_system "$2"
            clean_system "$2"
            disk_management
            security_check
            system_monitor
        fi
        ;;
    "-h"|"--help")
        show_help
        exit 0
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
                    if authenticate; then
                        update_system
                        clean_system
                        disk_management
                        security_check
                        system_monitor
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

