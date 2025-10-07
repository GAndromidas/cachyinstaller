# Initialize Starship for Fish shell
set -gx STARSHIP_CONFIG "$HOME/.config/fish/starship.toml"

# Set Starship specific environment variables
set -gx STARSHIP_SHELL "fish"

# Enable command duration reporting
set -gx STARSHIP_CMD_DURATION true
set -gx STARSHIP_CMD_DURATION_MIN_TIME 500  # Show duration for commands that take more than 500ms

# Set cache location
set -gx STARSHIP_CACHE_DIR "$HOME/.cache/starship"

# Initialize Starship
if type -q starship
    starship init fish | source
end

# Set Starship specific colors (optional - remove if using default theme)
set -gx STARSHIP_COLOR_BLUE "blue"
set -gx STARSHIP_COLOR_GREEN "green"
set -gx STARSHIP_COLOR_RED "red"
set -gx STARSHIP_COLOR_YELLOW "yellow"
set -gx STARSHIP_COLOR_GRAY "brblack"
