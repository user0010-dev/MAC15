#!/bin/bash
#AUTOMAC 0.0.3

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Password hash (password predefinita: macos123)
PASSWORD_HASH="64d38862b5b70b0605734aa56b8c3f0ef95bc43aa7da69ba837a1cfa960765b1"

# Variabile per memorizzare se l'autenticazione è avvenuta
AUTHENTICATED=false

# File per tracciare i pacchetti già installati
INSTALLED_PACKAGES_FILE="$HOME/.automac_installed"

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

# Funzione per installare i pacchetti necessari al primo utilizzo
install_required_packages() {
    if [ -f "$INSTALLED_PACKAGES_FILE" ]; then
        return 0
    fi
    
    print_status "Primo utilizzo: installazione pacchetti necessari..."
    
    # Installa Homebrew se non presente
    if ! command_exists "brew"; then
        print_status "Installazione di Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Configura PATH per Homebrew su Apple Silicon
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    # Pacchetti necessari
    local required_packages=(
        "wget"
        "git"
        "htop"
        "tree"
        "istats"
    )
    
    for pkg in "${required_packages[@]}"; do
        if ! command_exists "$pkg"; then
            print_status "Installazione di $pkg..."
            brew install "$pkg"
        fi
    done
    
    # Segna che i pacchetti sono stati installati
    touch "$INSTALLED_PACKAGES_FILE"
    print_success "Pacchetti necessari installati"
}

# Funzione per autenticazione all'inizio
authenticate_at_start() {
    if [ -n "$1" ]; then
        # Modalità non interattiva (da riga di comando)
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
        print_error "Operazione non autorizzata. Autenticarsi prima."
        return 1
    fi
    return 0
}

# Update del sistema macos 2.5.2
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

# Cancellazione cache/cose inutili
clean_system() {
    if ! check_authenticated; then
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
    if ! check_authenticated; then
        return 1
    fi
    
    local backup_dir="/Volumes/Backup/$(date +%Y%m%d_%H%M%S)"
    print_status "Backup della home directory in: $backup_dir"
    
    mkdir -p "$backup_dir"
    rsync -av --progress ~/ "$backup_dir/" --exclude='.Trash' --exclude='.npm' --exclude='.cache'
    
    print_success "Backup completato"
}

# Monitoraggio e anti virus
system_monitor() {
    print_status "Monitoraggio sistema:"
    
    echo -e "\n${YELLOW}=== USO CPU ===${NC}"
    top -l 1 -s 0 | head -10
    
    echo -e "\n${YELLOW}=== USO MEMORIA ===${NC}"
    vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free: (\d+)/ and printf("Memoria libera: %.2f MB\n", $1 * $size / 1048576)'
    
    echo -e "\n${YELLOW}=== PROCESSI ATTIVI ===${NC}"
    ps aux | head -10
    
    echo -e "\n${YELLOW}=== TEMPERATURE ===${NC}"
    if command_exists "istats"; then
        istats
    else
        print_warning "istats non installato. Esegui l'opzione 8 per installare i pacchetti necessari."
    fi
}

# Scirezza carabinieri
security_check() {
    print_status "Controllo sicurezza..."
    
    # Verifica firewall
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
    
    # Verifica software updates
    defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled
    
    # Lista applicazioni aperte
    print_status "Applicazioni in esecuzione:"
    osascript -e 'tell application "System Events" to get name of every process where background only is false'
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
    if ! check_authenticated; then
        return 1
    fi
    
    if ! command_exists "brew"; then
        print_status "Installazione Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Configura PATH per Homebrew su Apple Silicon
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
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
        "istats"
    )
    
    for app in "${apps[@]}"; do
        if ! command_exists "$app"; then
            brew install "$app"
        else
            print_status "$app è già installato"
        fi
    done
    
    # Aggiorna il file dei pacchetti installati
    touch "$INSTALLED_PACKAGES_FILE"
    print_success "Applicazioni essenziali installate"
}

# Funzione aiuto
show_help() {
    echo -e "${GREEN}=== AutoMac - Guida all'uso ===${NC}"
    echo "Utilizzo:"
    echo "  ./automac.sh [opzione] [password]"
    echo ""
    echo "Opzioni:"
    echo "  1       Aggiorna sistema (richiede autenticazione)"
    echo "  2       Pulizia sistema (richiede autenticazione)"
    echo "  3       Gestione spazio disco"
    echo "  4       Backup (richiede autenticazione)"
    echo "  5       Monitoraggio sistema"
    echo "  6       Controllo sicurezza"
    echo "  7       Informazioni rete"
    echo "  8       Installa applicazioni (richiede autenticazione)"
    echo "  9       Tutte le operazioni (richiede autenticazione)"
    echo "  0       Esci"
    echo ""
    echo "Password predefinita: macos123"
    echo "Modifica PASSWORD_HASH nello script per cambiarla"
}

# Menu principale
show_menu() {
    echo -e "\n${GREEN}=== AutoMac - Automazione macOS ===${NC}"
    echo "1. Aggiorna sistema (richiede autenticazione)"
    echo "2. Pulizia sistema (richiede autenticazione)"
    echo "3. Gestione spazio disco"
    echo "4. Backup home directory (richiede autenticazione)"
    echo "5. Monitoraggio sistema"
    echo "6. Controllo sicurezza"
    echo "7. Informazioni rete"
    echo "8. Installa applicazioni (richiede autenticazione)"
    echo "9. Tutte le operazioni (richiede autenticazione)"
    echo "0. Esci"
    echo -n "Scegli un'opzione: "
}

# Main execution
main() {
    # Installa pacchetti necessari al primo utilizzo
    install_required_packages
    
    # Autenticazione all'inizio se sono richieste operazioni protette
    case "${1:-}" in
        "1"|"2"|"4"|"8"|"9")
            if ! authenticate_at_start "$2"; then
                exit 1
            fi
            ;;
        *)
            # Per modalità interattiva, autenticare all'inizio se necessario
            if [ $# -eq 0 ]; then
                echo "Autenticazione richiesta per alcune funzioni"
                if authenticate_at_start; then
                    print_success "Autenticazione riuscita"
                else
                    print_warning "Modalità limitata: alcune funzioni non saranno disponibili"
                fi
            fi
            ;;
    esac

    # Esecuzione in base all'opzione
    case "${1:-}" in
        "1")
            update_system
            ;;
        "2")
            clean_system
            ;;
        "3")
            disk_management
            ;;
        "4")
            backup_home
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
            install_essentials
            ;;
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
        "-h"|"--help")
            show_help
            exit 0
            ;;
        *)
            while true; do
                show_menu
                read choice
                case $choice in
                    1) 
                        if [ "$AUTHENTICATED" = true ]; then
                            update_system
                        else
                            print_error "Autenticazione richiesta - Riavviare lo script"
                        fi
                        ;;
                    2) 
                        if [ "$AUTHENTICATED" = true ]; then
                            clean_system
                        else
                            print_error "Autenticazione richiesta - Riavviare lo script"
                        fi
                        ;;
                    3) disk_management ;;
                    4) 
                        if [ "$AUTHENTICATED" = true ]; then
                            backup_home
                        else
                            print_error "Autenticazione richiesta - Riavviare lo script"
                        fi
                        ;;
                    5) system_monitor ;;
                    6) security_check ;;
                    7) network_info ;;
                    8) 
                        if [ "$AUTHENTICATED" = true ]; then
                            install_essentials
                        else
                            print_error "Autenticazione richiesta - Riavviare lo script"
                        fi
                        ;;
                    9) 
                        if [ "$AUTHENTICATED" = true ]; then
                            update_system
                            clean_system
                            disk_management
                            security_check
                            system_monitor
                        else
                            print_error "Autenticazione richiesta - Riavviare lo script"
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
