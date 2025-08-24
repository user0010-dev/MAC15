#!/bin/bash
#AUTOMAC 0.0.5 - Versione Ottimizzata

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

# Funzione per installare i pacchetti necessari (SOLO se veramente necessari)
install_required_packages() {
    if ! check_authenticated; then
        return 1
    fi
    
    print_status "Controllo pacchetti necessari..."
    
    # SOLO pacchetti LEGGERI e veramente utili
    local required_packages=(
        "htop"   # Per monitoraggio sistema (opzionale ma utile)
    )
    
    local missing_packages=()
    
    # Controlla quali pacchetti mancano
    for pkg in "${required_packages[@]}"; do
        if ! command_exists "$pkg"; then
            missing_packages+=("$pkg")
            print_warning "$pkg non è installato"
        else
            print_status "$pkg è già installato"
        fi
    done
    
    # Se non mancano pacchetti, esci
    if [ ${#missing_packages[@]} -eq 0 ]; then
        print_success "Tutti i pacchetti necessari sono già installati"
        return 0
    fi
    
    print_status "Pacchetti da installare: ${missing_packages[*]}"
    
    # Installa Homebrew se non presente
    if ! command_exists "brew"; then
        print_status "Installazione di Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Configura PATH per Homebrew
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
    
    # Installa i pacchetti mancanti
    for pkg in "${missing_packages[@]}"; do
        print_status "Installazione di $pkg..."
        brew install "$pkg"
        if [ $? -eq 0 ]; then
            print_success "$pkg installato con successo"
        else
            print_error "Errore durante l'installazione di $pkg"
            print_warning "Il pacchetto $pkg è opzionale, lo script funzionerà comunque"
        fi
    done
    
    # Segna che i pacchetti sono stati installati
    touch "$INSTALLED_PACKAGES_FILE"
    print_success "Installazione pacchetti completata"
}

# Update del sistema macos
update_system() {
    if ! check_authenticated; then
        return 1
    fi
    
    print_status "Aggiornamento del sistema in corso..."
    
    if command_exists "brew"; then
        brew update
        brew upgrade
        brew cleanup
        print_success "Homebrew aggiornato"
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
    
    # Mostra le 10 cartelle più grandi
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

# Monitoraggio sistema
system_monitor() {
    print_status "Monitoraggio sistema:"
    
    echo -e "\n${YELLOW}=== USO CPU ===${NC}"
    top -l 1 -s 0 | head -10
    
    echo -e "\n${YELLOW}=== USO MEMORIA ===${NC}"
    vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free: (\d+)/ and printf("Memoria libera: %.2f MB\n", $1 * $size / 1048576)'
    
    echo -e "\n${YELLOW}=== PROCESSI ATTIVI ===${NC}"
    ps aux | head -10
    
    # htop è opzionale, usiamo top che è preinstallato
    if command_exists "htop"; then
        echo -e "\n${YELLOW}=== HTOP (VISUALIZZAZIONE AVANZATA) ===${NC}"
        htop --version | head -1
    else
        print_status "Installa htop con l'opzione 8 per monitoraggio avanzato"
    fi
}

# Controllo sicurezza
security_check() {
    print_status "Controllo sicurezza..."
    
    # Verifica firewall
    print_status "Stato firewall:"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
    
    # Verifica software updates
    print_status "Aggiornamenti automatici:"
    defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled
    
    # Lista applicazioni aperte
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

# Funzione per installare applicazioni aggiuntive (OPZIONALI)
install_essentials() {
    if ! check_authenticated; then
        return 1
    fi
    
    print_status "Installazione applicazioni opzionali..."
    
    # App OPZIONALI (non necessarie per lo script base)
    local apps=(
        "htop"     # Monitoraggio avanzato
        "tree"     # Visualizzazione alberi directory
    )
    
    for app in "${apps[@]}"; do
        if ! command_exists "$app"; then
            print_status "Installazione di $app..."
            brew install "$app"
        else
            print_status "$app è già installato"
        fi
    done
    
    print_success "Applicazioni opzionali installate"
}

# Funzione aiuto
show_help() {
    echo -e "${GREEN}=== AutoMac - Guida all'uso ===${NC}"
    echo "Utilizzo:"
    echo "  ./automac.sh [opzione] [password]"
    echo ""
    echo "Opzioni:"
    echo "  install  Installa pacchetti opzionali (richiede password)"
    echo "  1        Aggiorna sistema (richiede password)"
    echo "  2        Pulizia sistema (richiede password)"
    echo "  3        Gestione spazio disco"
    echo "  4        Backup (richiede password)"
    echo "  5        Monitoraggio sistema"
    echo "  6        Controllo sicurezza"
    echo "  7        Informazioni rete"
    echo "  8        Installa applicazioni opzionali (richiede password)"
    echo "  9        Tutte le operazioni (richiede password)"
    echo "  0        Esci"
    echo "  -h       Mostra questo aiuto"
    echo ""
    echo "Password predefinita: macos123"
    echo ""
    echo "NOTA: Lo script funziona SENZA installare pacchetti aggiuntivi!"
}

# Menu principale
show_menu() {
    echo -e "\n${GREEN}=== AutoMac - Automazione macOS ===${NC}"
    echo "install   Installa pacchetti opzionali (password)"
    echo "1.        Aggiorna sistema (password)"
    echo "2.        Pulizia sistema (password)"
    echo "3.        Gestione spazio disco"
    echo "4.        Backup home directory (password)"
    echo "5.        Monitoraggio sistema"
    echo "6.        Controllo sicurezza"
    echo "7.        Informazioni rete"
    echo "8.        Installa applicazioni opzionali (password)"
    echo "9.        Tutte le operazioni (password)"
    echo "0.        Esci"
    echo "-h        Aiuto"
    echo -n "Scegli un'opzione: "
}

# Main execution
main() {
    # Prima di tutto: AUTENTICAZIONE
    case "${1:-}" in
        "install"|"1"|"2"|"4"|"8"|"9")
            if ! authenticate_at_start "$2"; then
                exit 1
            fi
            print_success "Autenticazione riuscita"
            ;;
        *)
            # Per modalità interattiva
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

    # Poi: INSTALLAZIONE PACCHETTI OPZIONALI (se richiesto)
    case "${1:-}" in
        "install")
            install_required_packages
            exit 0
            ;;
    esac

    # Infine: ESECUZIONE OPERAZIONI
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
                    "install")
                        if [ "$AUTHENTICATED" = true ]; then
                            install_required_packages
                        else
                            print_error "Autenticazione richiesta"
                        fi
                        ;;
                    "1")
                        if [ "$AUTHENTICATED" = true ]; then
                            update_system
                        else
                            print_error "Autenticazione richiesta"
                        fi
                        ;;
                    "2")
                        if [ "$AUTHENTICATED" = true ]; then
                            clean_system
                        else
                            print_error "Autenticazione richiesta"
                        fi
                        ;;
                    "3") disk_management ;;
                    "4")
                        if [ "$AUTHENTICATED" = true ]; then
                            backup_home
                        else
                            print_error "Autenticazione richiesta"
                        fi
                        ;;
                    "5") system_monitor ;;
                    "6") security_check ;;
                    "7") network_info ;;
                    "8")
                        if [ "$AUTHENTICATED" = true ]; then
                            install_essentials
                        else
                            print_error "Autenticazione richiesta"
                        fi
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
                    "0")
                        print_status "Arrivederci!"
                        exit 0
                        ;;
                    "-h") show_help ;;
                    *)
                        print_error "Opzione non valida"
                        ;;
                esac
                echo -e "\nPremi Invio per continuare..."
                read
            done
            ;;
    esac
}

# Esegui il main
main "$@"
