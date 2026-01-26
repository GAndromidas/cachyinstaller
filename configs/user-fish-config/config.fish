# CachyOS Fish Configuration - User Config
# This sources the system-wide cachyos-config.fish

# Try system path first (for installed CachyOS)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
# Fallback to home cachyinstaller folder (for development/git clone)
else if test -f ~/cachyinstaller/configs/cachyos-fish-config/cachyos-config.fish
    source ~/cachyinstaller/configs/cachyos-fish-config/cachyos-config.fish
# Also check in .config if manually copied
else if test -f ~/.config/fish/cachyos-config.fish
    source ~/.config/fish/cachyos-config.fish
end

# User customizations below this line
# Uncomment to override the greeting
#function fish_greeting
#    # Custom greeting here
#end
