# =============================================================================
#   CachyOS Fish Configuration
# =============================================================================

# Add local bin to PATH if it exists
if test -d "$HOME/.local/bin"
    set -gx PATH "$HOME/.local/bin" $PATH
end

# =============================================================================
#   Environment Variables
# =============================================================================

set -gx EDITOR nano
set -gx VISUAL nano
set -gx STARSHIP_CONFIG "$HOME/.config/fish/starship.toml"
set -gx STARSHIP_SHELL "fish"

# =============================================================================
#   System Maintenance Aliases
# =============================================================================

alias sync='sudo pacman -Syy'                                                      # Sync package databases
alias update='paru -Syyu && sudo flatpak update'                                  # Update all packages
alias mirror='sudo rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch && sudo pacman -Syy'  # Update mirrors
alias clean='sudo pacman -Sc --noconfirm && paru -Sc --noconfirm && sudo flatpak uninstall --unused && sudo pacman -Rns --noconfirm (pacman -Qtdq 2>/dev/null)'  # Clean packages
alias cache='rm -rf ~/.cache/* && sudo paccache -r'                               # Clear cache
alias microcode='grep . /sys/devices/system/cpu/vulnerabilities/*'                # CPU vulnerabilities
alias jctl='journalctl -p 3 -xb'                                                 # Show boot errors

# =============================================================================
#   System Power Management
# =============================================================================

alias sr='sudo reboot'                                                           # Reboot
alias ss='sudo poweroff'                                                         # Shutdown
alias suspend='systemctl suspend'                                                # Suspend
alias hibernate='systemctl hibernate'                                            # Hibernate

# =============================================================================
#   File Management (eza replacing ls)
# =============================================================================

alias ls='eza -al --color=always --group-directories-first --icons'              # Detailed list
alias la='eza -a --color=always --group-directories-first --icons'               # All files
alias ll='eza -l --color=always --group-directories-first --icons'               # Long format
alias lt='eza -aT --color=always --group-directories-first --icons'              # Tree view
alias l.="eza -a | grep -e '^\.'"                                                # Dotfiles
alias lh='eza -ahl --color=always --group-directories-first --icons'             # Human sizes

# =============================================================================
#   Navigation
# =============================================================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias home='cd ~'
alias docs='cd ~/Documents'
alias down='cd ~/Downloads'

# Create a function for cd - instead of an alias
function prevd --description 'Go to previous directory'
    cd -
end

# =============================================================================
#   Networking
# =============================================================================

alias ip='ip addr'
alias ipa='ip -c -br addr'
alias myip='curl -s ifconfig.me'
alias localip='hostname -I'
alias ports='netstat -tulanp'
alias listenports='sudo lsof -i -P -n | grep LISTEN'
alias scanports='nmap -p 1-1000'
alias ping='ping -c 5'
alias fastping='ping -c 100 -s.2'
alias wget='wget -c'
alias ports-used='netstat -tulanp | grep ESTABLISHED'

# =============================================================================
#   System Monitoring
# =============================================================================

alias top='btop'
alias htop='btop'
alias hw='hwinfo --short'
alias cpu='lscpu'
alias gpu='lspci | grep -i vga'
alias mem='free -mt'
alias gove='cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
alias cpustat='cpupower frequency-info | grep -E "governor|current policy"'
alias psf='ps auxf'
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias big='expac -H M "%m\t%n" | sort -h | nl'
alias topcpu='ps auxf | sort -nr -k 3 | head -10'
alias topmem='ps auxf | sort -nr -k 4 | head -10'

# =============================================================================
#   Disk Usage
# =============================================================================

alias df='df -h'
alias du='du -h'
alias duh='du -h --max-depth=1 | sort -h'
alias duf='duf'

# =============================================================================
#   Archive Operations
# =============================================================================

alias mktar='tar -acf'
alias untar='tar -xvf'
alias mkzip='zip -r'
alias lstar='tar -tvf'
alias lszip='unzip -l'

# =============================================================================
#   File Operations
# =============================================================================

alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv --preserve-root'
alias mkdir='mkdir -pv'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# =============================================================================
#   Package Management
# =============================================================================

alias unlock='sudo rm /var/lib/pacman/db.lck'
alias rip='expac --timefmt="%d-%m-%Y %T" "%l\t%n %v" | sort | tail -200 | nl'
alias orphans='sudo pacman -Rns (pacman -Qtdq) 2>/dev/null'

# =============================================================================
#   Fun & Utilities
# =============================================================================

alias weather='curl wttr.in'
alias map='telnet mapscii.me'
alias clock='tty-clock -sct'
alias matrix='cmatrix'

# =============================================================================
#   Functions
# =============================================================================

# Extract function - handles various archive formats
function extract
    if test -f $argv[1]
        switch $argv[1]
            case '*.tar.bz2'
                tar xjf $argv[1]
            case '*.tar.gz'
                tar xzf $argv[1]
            case '*.bz2'
                bunzip2 $argv[1]
            case '*.rar'
                unrar x $argv[1]
            case '*.gz'
                gunzip $argv[1]
            case '*.tar'
                tar xf $argv[1]
            case '*.tbz2'
                tar xjf $argv[1]
            case '*.tgz'
                tar xzf $argv[1]
            case '*.zip'
                unzip $argv[1]
            case '*.Z'
                uncompress $argv[1]
            case '*.7z'
                7z x $argv[1]
            case '*'
                echo "'$argv[1]' cannot be extracted via extract"
        end
    else
        echo "'$argv[1]' is not a valid file"
    end
end

# Create directory and cd into it
function mkcd
    mkdir -p $argv[1] && cd $argv[1]
end

# Find and kill process by name
function killp
    ps aux | grep -i $argv[1] | grep -v grep | awk '{print $2}' | xargs sudo kill -9
end

# =============================================================================
#   Tool Initialization
# =============================================================================

# Initialize Starship prompt
if type -q starship
    starship init fish | source
end

# Initialize zoxide (smart cd)
if type -q zoxide
    zoxide init fish | source
end

# =============================================================================
#   Man Page Colors
# =============================================================================

set -gx LESS_TERMCAP_mb (printf "\e[1;31m")     # Begin blinking
set -gx LESS_TERMCAP_md (printf "\e[1;31m")     # Begin bold
set -gx LESS_TERMCAP_me (printf "\e[0m")        # End mode
set -gx LESS_TERMCAP_se (printf "\e[0m")        # End standout-mode
set -gx LESS_TERMCAP_so (printf "\e[1;44;33m")  # Begin standout-mode
set -gx LESS_TERMCAP_ue (printf "\e[0m")        # End underline
set -gx LESS_TERMCAP_us (printf "\e[1;32m")     # Begin underline

# =============================================================================
#   Shell Startup
# =============================================================================

# Run fastfetch on shell start if it exists
if type -q fastfetch
    fastfetch
end

# Enable Vi mode
fish_vi_key_bindings

# =============================================================================
#   End of Configuration
# =============================================================================
