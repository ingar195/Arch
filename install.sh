# Logg messages should be in format    logging INFO MESSAGE
logging() {
    local color_error="\e[31m"
    local color_warning="\e[33m"
    local color_reset="\e[0m"
    local color_info="\e[32m"
    local log_file="log.log"
    local date="[$(date '+%Y-%m-%d %H:%M:%S')]"

    if [[ -z $DEBUG && $1 == "DEBUG" ]]; then
        echo "$1: $2" | tee -a "$log_file" &> /dev/null
    else

        case $1 in
            "ERROR")
            echo -e "${color_error}$1:${color_reset} $2" | tee -a "$log_file"
            ;;
            "WARNING")
            echo -e "${color_warning}$1:${color_reset} $2" | tee -a "$log_file"
            ;;
            "INFO")
            echo -e "${color_info}$1:${color_reset} $2" | tee -a "$log_file"
            ;;
            *)
            echo -e "$1: $2" | tee -a "$log_file"

        esac    
    fi
}


# Define commandline options
optstring=":dsc"
while getopts "$optstring" optchar; do
  case $optchar in
    d)
      DEBUG=true
      ;;
    s)
      skip_convert=true
      logging INFO "Skipping conversion from https to ssh"
      ;;
    c)
        sectools=true
        logging INFO "Adding security tools"
      ;;
    ?)
      echo "Invalid option: -$OPTARG, valid ones -s -d -c" >&2
      exit 1
      ;;
  esac
done


# Function to add source to .zshrc if not already there
add_source_to_zshrc() {
    if [[ -f $HOME/.zshrc ]]; then
        if ! grep -Fxq "source $1" $HOME/.zshrc; then
            logging INFO "Adding 'source $1 to .zshrc'"
            echo "source $1" >> $HOME/.zshrc
        fi
    fi
}


# Install Packages from file
install_packages() {
    logging INFO "Installing/checking for new packages from $1"
    local filename=$1
    while IFS= read -r package || [[ -n "$package" ]]; do
        if paru -Q "$package" &> /dev/null; then
            logging DEBUG "$package is already installed"
            continue
        else
            logging INFO "$package is not installed, installing now"
            paru -S --noconfirm --needed "$package" &>/dev/null
            if ! paru -Q "$package" &> /dev/null; then
                logging ERROR "Failed to install $package"
            fi
        fi
    done < "$filename"
}

install_code_packages() {
    logging INFO "Installing/updating code extensions"
    local filename=$1
    local installed_extensions=$(code --list-extensions)
    while IFS= read -r package || [[ -n "$package" ]]; do
        if echo "$installed_extensions" | grep -qE "^$package$" &> /dev/null; then
            logging DEBUG "$package is already installed"
            continue
        fi
        code --install-extension "$package" &>/dev/null || logging ERROR "failed to install VS Code extensions $package"
    done < "$filename"

}

replace_or_append() {
  local file="$1"  # Target file
  local target="$2" # Line to replace (target string)
  local replacement="$3" # Replacement line
  logging DEBUG "Replacing or appending $target with $replacement in $file"

  if [ -z $4 ]; then
    local sudo=""
  else
    local sudo="sudo"
  fi

  # This gives false positive on files that curen user don't not have read access to wazuh client ins on example
  # Command to be run a s sudo 
  if [ ! -f $file ]; then
    $sudo touch $file
    logging INFO "Created file: $file"
  fi

  # Use grep to check if target exists (avoids unnecessary sed invocation)
  if $sudo grep -qE "^$replacement$" "$file"; then
    logging DEBUG "Replacement already exists in file: $file"
  else
    if $sudo grep -qE "^$target$" "$file"; then
        # Perform in-place replacement with sed (consider using a temporary file for safety)
        $sudo sed -i "/^$target/s//$replacement/" "$file"
        logging INFO "Changed line in file: $file"
    else
        # Append replacement if target not found
        $sudo sh -c "$sudo echo $replacement >> $file"
        logging INFO "Added line in file: $file"
    fi
fi
}

install_i3() {
    git_url="https://github.com/ingar195/.dotfiles.git"

    install_packages $USER"_packages"

    sudo systemctl  enable --now bluetooth.service

    # Dunst settings 
    replace_or_append /etc/dunst/dunstrc "offset = 10x50" "offset = 40x70" sudo
    replace_or_append /etc/dunst/dunstrc "notification_limit = 20" "notification_limit = 5" sudo
    
    if [ ! -f "$HOME/.dotfiles/config" ];then
        rm .config/i3/config
        mkdir .config/polybar
    fi

    replace_or_append /etc/systemd/system.conf "#DefaultTimeoutStopSec=90s" "DefaultTimeoutStopSec=10s" sudo

    skip_convert=true
}

UPSTREAM=$(git rev-parse --abbrev-ref '@{u}')
if [ -z "$UPSTREAM" ]; then
    logging ERROR "No upstream branch set. Please set the upstream branch and try again."
    exit 1
fi


git fetch &> /dev/null

# Get the upstream branch
UPSTREAM=$(git rev-parse --abbrev-ref '@{u}')
if [ -z "$UPSTREAM" ]; then
    logging ERROR "No upstream branch set. Please set the upstream branch and try again."
    exit 1
fi

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")

logging DEBUG "Local: $LOCAL"
logging DEBUG "Remote: $REMOTE"
logging DEBUG "Base: $BASE"

unstaged_changes=$(git status --porcelain)
if [ -n "$unstaged_changes" ]; then
    logging WARNING "You have unstaged changes in your working directory."
    sleep 10
fi

if [ "$LOCAL" = "$REMOTE" ]; then
    logging INFO "Install script is Up-to-date"
elif [ "$LOCAL" = "$BASE" ]; then
    logging WARNING "This is not the latest version of the install script. You should pull this repo..."
    sleep 10
elif [ "$REMOTE" = "$BASE" ]; then
    logging WARNING "You have local changes to the install script. Please push after testing..."
    sleep 10
else
    logging ERROR "The git repository for the install script has diverged. Please investigate..."
    sleep 30
fi


if [[ -n "$SUDO_USER" || -n "$SUDO_UID" ]]; then
    logging ERROR "You are not allowed to run this script as sudo"
    exit 1
fi

# Update pacman database
sudo pacman --noconfirm -Syu
sudo pacman -S --noconfirm --needed base-devel git rust &> /dev/null

if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "source $HOME/.config/zsh/.work" "$HOME/.zshrc"; then
        read -p "Do you want to add the work source to .zshrc? (y/N): " zsh_work
    fi
fi

if [ ! $(git config user.email)  ]; then
    read -p "Type your git email:  " git_email
    git config --global user.email "$git_email"
    
fi
if [ -z "$(git config user.name)" ]; then
    read -p "Type your git Full name:  " git_name
    git config --global user.name "$git_name"
fi


# Add user to uucp group to allow access to serial ports
# TODO: this should be a function now 
if ! groups $USER | grep &>/dev/null '\buucp\b'; then
    sudo gpasswd -a $USER uucp
    reboot=true
fi

# Install Paru helper
if ! command -v paru --help &> /dev/null; then
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd ..
    sudo rm -r paru-bin
fi

paru --noconfirm -Syu

# Paru settings
replace_or_append /etc/paru.conf "#BottomUp" "BottomUp" "sudo"
replace_or_append /etc/paru.conf "#SudoLoop" "SudoLoop" "sudo"
replace_or_append /etc/pacman.conf "#Color" "Color" "sudo"

install_packages "packages"

install_code_packages "code_packages"

# Install security tools if -c flag is set
if [ -n "$sectools" ]; then
    install_packages "sec_packages"
fi

# Generate ssh key
if [[ ! -f $HOME/.ssh/id_rsa ]]
then
    ssh-keygen -m PEM -N '' -f ~/.ssh/id_rsa
    logging WARNING "Did not find SSH key, and created a new one"
fi

sudo timedatectl set-timezone Europe/Oslo

# Set theme
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
# not needed?
# xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"

mkdir -p $HOME/.config/teamviewer &> /dev/null
# not setting on fresh install

# BUG: This is now wokring. It's just a just adding at the bottom of the file
if [ ! -f $HOME/.config/teamviewer/client.conf ]; then
    replace_or_append /etc/teamviewer/global.conf "[int32] EulaAccepted = 1" "[int32] EulaAccepted = 1" sudo
    replace_or_append $HOME/.config/teamviewer/client.conf "[int32] ColorScheme = 1" "[int32] ColorScheme = 2"
    echo "[int32] ColorScheme = 2" | tee $HOME/.config/teamviewer/client.conf &> /dev/null
    echo "[int32] OnboardingTaskState = 1 1 1" | sudo tee /etc/teamviewer/client.conf &> /dev/null
fi

if [ ! "$(grep "GTK_THEME=Adwaita-dark" /etc/environment)" ]; then
    replace_or_append /etc/environment "GTK_THEME=Adwaita-dark" "GTK_THEME=Adwaita-dark" sudo
    # echo "GTK_THEME=Adwaita-dark" | sudo tee -a /etc/environment
fi

# Set Backlight permissions and monotor rules
# Replace does not work, something wrong with "'" in the string
echo 'SUBSYSTEM=="backlight",RUN+="/bin/chmod 666 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"' | sudo tee /etc/udev/rules.d/backlight-permissions.rules &> /dev/null
sudo sh -c 'echo SUBSYSTEM=="drm", ACTION=="change", RUN+="/usr/bin/autorandr" > /etc/udev/rules.d/70-monitor.rules' &> /dev/null

# Enable services
sudo systemctl enable teamviewerd.service --now

# Setup syslog-ng
sudo systemctl enable syslog-ng@default.service --now

# Disable iwd if archinstaller has copied ios settings
sudo systemctl disable systemd-networkd.service &> /dev/null
sudo systemctl disable iwd.service &> /dev/null
# Setup Network manager
sudo systemctl enable NetworkManager.service --now

replace_or_append /etc/modprobe.d/blacklist-nvidia-nouveau.conf "" "blacklist nouveau" sudo

# BUG: Failed to add to file 
replace_or_append /etc/modprobe.d/blacklist-nvidia-nouveau.conf "" "options nouveau modeset=0" sudo
# sudo sh -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"

#Docker
sudo systemctl enable docker.service acpid.service --now

# Wazuh-agent
sudo sed -i 's/MANAGER_IP/213.161.247.227/g' /var/ossec/etc/ossec.conf
#replace_or_append /var/ossec/etc/ossec.conf "MANAGER_IP" "213.161.247.227" sudo

# Start wazuh-agent
sudo systemctl enable --now wazuh-agent

# Power Save
replace_or_append /etc/systemd/logind.conf "#HandleLidSwitch=suspend" "HandleLidSwitch=suspend" sudo
replace_or_append /etc/systemd/logind.conf "#IdleAction=ignore" "IdleAction=suspend" sudo
replace_or_append /etc/systemd/logind.conf "#IdleActionSec=30min" "IdleActionSec=10min" sudo
replace_or_append /etc/systemd/logind.conf "#HoldoffTimeoutSec=30s" "HoldoffTimeoutSec=5s" sudo

# Lockscreen after suspend
sudo cp suspend-lock.service /etc/systemd/system/suspend-lock.service
sudo sed -i "s/User=USER/User=$USER/g" /etc/systemd/system/suspend-lock.service
sudo systemctl enable suspend-lock.service
    
# OSC Printer
sudo systemctl enable --now cups

if ! lpstat -p OSC_Printer &> /dev/null; then
    lpadmin -p OSC_Printer -E -v "ipp://192.168.6.11/ipp/print" -m everywhere
fi

# Greeter
replace_or_append /etc/lightdm/lightdm-gtk-greeter.conf "#theme-name=" "theme-name=Numix" sudo
replace_or_append /etc/lightdm/lightdm-gtk-greeter.conf "#icon-theme-name=" "icon-theme-name=Papirus-Dark" sudo
replace_or_append /etc/lightdm/lightdm-gtk-greeter.conf "#background=" "background=#2f343f" sudo
replace_or_append /etc/lightdm/lightdm-gtk-greeter.conf "#xft-dpi=" "xft-dpi=261" sudo

# Lightdm
sudo systemctl enable lightdm

# TLP
sudo systemctl enable tlp.service --now 
replace_or_append /etc/tlp.conf "#TLP_ENABLE=1" "TLP_ENABLE=1" sudo
replace_or_append /etc/tlp.conf "#CPU_SCALING_GOVERNOR_ON_BAT=powersave" "CPU_SCALING_GOVERNOR_ON_BAT=powersave" sudo
replace_or_append /etc/tlp.conf "#CPU_SCALING_GOVERNOR_ON_AC=powersave" "CPU_SCALING_GOVERNOR_ON_AC=performance" sudo

# Setting TERM to xterm
replace_or_append $HOME/.zshrc "export TERM=xterm" "export TERM=xterm"

# user defaults
if [ $USER = fw ]; then


    # Remember where we where..
    cwd=$(pwd)
    
    # Define the dotfiles repo
    git_url="https://github.com/frodus/dotfiles.git"

    # Add Teamviewer config to make it start without a loginmanager
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
    echo -e '[Service] \nEnvironment=XDG_SESSION_TYPE=x11' | sudo tee /etc/systemd/system/getty@tty1.service.d/getty@tty1.service-drop-in.conf

    # Install my packages
    install_packages $USER"_packages"

    # Build my dispay manager
    git clone git@github.com:frodus/dwm.git $HOME/repo/dwm
    cd $HOME/repo/dwm
    git checkout fw-modification
    sudo rm config.h
    make &>/dev/null && sudo make install &>/dev/null

    # Get back to where we started from
    cd $cwd
    
    systemctl --user enable --now ssh-agent

elif [ $USER = user ] || [ $USER = ingar ]; then

    # Create directory's
    mkdir -p $HOME/workspace/work &> /dev/null
    
    install_i3
    skip_convert=false
else
    read -p "enter the https URL for you git bare repo: " git_url
fi

# Tmp alias for installation only 
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=/home/$USER'

if [[ ! -d $HOME/.dotfiles/ ]]
then
    logging INFO "Did not find .dotfiles, so will check them out again"
    git clone --bare $git_url $HOME/.dotfiles 
    dotfiles checkout -f || logging ERROR "Dotfiles checkout failed."
    if [ $? -ne 0 ]; then
        logging WARNING "Dotfiles pull failed. retrying..."
        sudo rm -rf $HOME/.dotfiles
        git clone --bare $git_url $HOME/.dotfiles
    else
        logging INFO "Dotfiles Successfully checked out."
    fi
else
    logging INFO "Updating dotfiles"
    dotfiles pull &> /dev/null || logging ERROR "Dotfiles pull failed."    
fi

# Create folders for filemanager
mkdir -p $HOME/Downloads &> /dev/null
mkdir -p $HOME/Desktop &> /dev/null
mkdir -p $HOME/Pictures &> /dev/null
mkdir -p $HOME/.config/wireguard &> /dev/null


if [ "$(echo $SHELL )" != "/bin/zsh" ]; then
    sudo chsh -s /bin/zsh $USER
fi

if [ ! -f $HOME/.oh-my-zsh/README.md ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    # replace_or_append $HOME/.zshrc "ZSH_THEME=\"robbyrussell\"" "ZSH_THEME=\"agnoster\""
fi
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' $HOME/.zshrc

# Aliases and functions
# Copy .aliases and .functions files to .config
zsh_config_path=$HOME/.config/zsh
mkdir -p $zsh_config_path

cp .aliases $zsh_config_path/
cp .functions $zsh_config_path/

sudo sed -i "s|script_path|$PWD|g" $HOME/.config/zsh/.functions

# Add sources to .zshrc if not already there
add_source_to_zshrc "$zsh_config_path/.aliases"
add_source_to_zshrc "$zsh_config_path/.functions"

file_to_source="$zsh_config_path/.work"

if [[ $zsh_work == "y" && ! $(grep -q "$file_to_source" ~/.zshrc) ]]; then
    add_source_to_zshrc "$file_to_source"
fi

# Update locate database
sudo updatedb

# Cleanup unused packages 
paru -Qdtq | paru --noconfirm -Rs - &> /dev/null

# Converts https to ssh
if [ -z $skip_convert ]; then
    if [ $skip_convert = false ]; then
        sed -i 's/https:\/\/github.com\//git@github.com:/g' /home/$USER/.dotfiles/config
        logging INFO "Converted from https to ssh"
    fi
else
    logging DEBUG "Skipping conversion from https to ssh"
fi

# List all packages installed on system that is not installed by this script
declare -a package_lists

# Find files named "packages" or ending with "packages"
package_files=( 
  "packages" 
  *"_packages" 
)
for file in "${package_files[@]}"; do
  # Read packages from the file and store them in the array
  while IFS= read -r package  || [[ -n "$package" ]]; do
    package_lists+=("$package")
  done < "$file"
done

installed_packages=$(pacman -Qtq)

unlisted_packages=()
for package in $installed_packages; do
  # Check if package exists in the array (any list file)
  if [[ ! "${package_lists[@]}" =~ "$package" ]]; then
    unlisted_packages+=("$package")
  fi
done

logging WARNING "The following packages are not from the installer: $(echo ${unlisted_packages[@]})"
# Reboot if any changes were made
# Make this actually work
reboot=true
if [ "$reboot" = true ]; then
    echo ----------------------
    echo "Please reboot your PC"
    echo ----------------------
fi


