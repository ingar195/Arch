# Define commandline options
optstring="d:s"
while getopts "$optstring" optchar; do
  case $optchar in
    d)
      DEBUG=true
      ;;
    s)
        skip_convert=true
        ;;
    ?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done


# Logg messages should be in format    logging INFO MESSAGE
logging(){
  if [[ -z $DEBUG && $1 == "DEBUG" ]]; then
    echo "$1: $2" | tee -a log.log &> /dev/null
  else
    echo "$1: $2" | tee -a log.log
  fi
}


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
    echo "Installing" $1
    local filename=$1
    while IFS= read -r package || [[ -n "$package" ]]; do
        if [ -n "$(paru -Qs "$package")" ]; then
            echo "INFO: $package is already installed" >> log.log
            continue
        fi
        logging INFO "--------------------------------Installing $package"
        paru -S --noconfirm --needed "$package" &>/dev/null || echo "ERROR: $package" >> error.log
    done < "$filename"
}


install_code_packages() {
    logging INFO "Installing code extensions"
    local filename=$1
    local installed_extensions=$(code --list-extensions)
    while IFS= read -r package || [[ -n "$package" ]]; do
        if echo "$installed_extensions" | grep -i "$package" &> /dev/null; then
            logger INFO "$package is already installed"
            continue
        fi
        code --install-extension "$package" &>/dev/null || logger ERROR "failed to install $package"
    done < "$filename"
}


replace_or_append() {
  local file="$1"  # Target file
  local target="$2" # Line to replace (target string)
  local replacement="$3" # Replacement line
  
  if [ -z $4 ]; then
    local sudo=""
  else
    local sudo="sudo"
  fi

  if [ ! -f $file ]; then
    $sudo touch $file
    logger INFO "Created file: $file"
  fi

  # Use grep to check if target exists (avoids unnecessary sed invocation)
  if $sudo grep -q "^$target\$" "$file"; then
    # Perform in-place replacement with sed (consider using a temporary file for safety)
    $sudo sed -i "/^$target$/s//$replacement/" "$file"
    logger INFO "Changed line in file: $file"
  else
    # Append replacement if target not found
    $sudo sh -c "echo $replacement >> $file"
    logger INFO "Added line in file: $file"
  fi
}


if [[ -n "$SUDO_USER" || -n "$SUDO_UID" ]]; then
    logger ERROR "You are not allowed to run this script as sudo"
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
if ! groups $USER | grep &>/dev/null '\buucp\b'; then
    sudo gpasswd -a $USER uucp
fi

# Install Paru helper
if ! command -v paru --help &> /dev/null; then
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd ..
    sudo rm -r paru-bin
fi

# Paru settings
sudo sed -i 's/#BottomUp/BottomUp/g' /etc/paru.conf
sudo sed -i 's/#SudoLoop/SudoLoop/g' /etc/paru.conf
sudo sed -i 's/#Color/Color/g' /etc/pacman.conf

install_packages "packages"

install_code_packages "code_packages"

# Generate ssh key
if [[ ! -f $HOME/.ssh/id_rsa ]]
then
    ssh-keygen -m PEM -N '' -f ~/.ssh/id_rsa
    logger WARNING "Did not find SSH key, and created a new one"
fi

sudo timedatectl set-timezone Europe/Oslo

# Set theme
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"
replace_or_append $HOME/.config/teamviewer/client.conf "[int32] ColorScheme = 1" "[int32] ColorScheme = 2"

if [ ! "$(grep "GTK_THEME=Adwaita-dark" /etc/environment)" ]; then
    echo "GTK_THEME=Adwaita-dark" | sudo tee -a /etc/environment
fi

# Set Backlight permissions and monotor rules
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

sudo sh -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo sh -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"

#Docker
sudo systemctl enable docker.service acpid.service --now

# Wazuh-agent
sudo sed -i 's/MANAGER_IP/213.161.247.227/g' /var/ossec/etc/ossec.conf

# Start wazuh-agent
sudo systemctl enable --now wazuh-agent | logger ERROR "Wazuh did not start..."

# Power Save
sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=suspend/g' /etc/systemd/logind.conf
sudo sed -i 's/#IdleAction=ignore/IdleAction=suspend/g' /etc/systemd/logind.conf
sudo sed -i 's/#IdleActionSec=30min/IdleActionSec=30min/g' /etc/systemd/logind.conf
sudo sed -i 's/#HoldoffTimeoutSec=30s/HoldoffTimeoutSec=5s/g' /etc/systemd/logind.conf

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

elif [ $USER = user ] || [ $USER = ingar ]; then
    git_url="https://github.com/ingar195/.dotfiles.git"

    install_packages "user_packages"

    # TLP
    sudo systemctl enable tlp.service --now 
    replace_or_append /etc/tlp.conf "#TLP_ENABLE=1" "TLP_ENABLE=1" sudo
    replace_or_append /etc/tlp.conf "#CPU_SCALING_GOVERNOR_ON_BAT=powersave" "CPU_SCALING_GOVERNOR_ON_BAT=powersave" sudo
    replace_or_append /etc/tlp.conf "#CPU_SCALING_GOVERNOR_ON_AC=performance" "CPU_SCALING_GOVERNOR_ON_AC=performance" sudo

    # Greeter
    replace_or_append /etc/lightdm/lightdm-gtk-greeter.conf "#theme-name=" "theme-name=Numix" sudo
    replace_or_append /etc/lightdm/lightdm-gtk-greeter.conf "#icon-theme-name=" "icon-theme-name=Papirus-Dark" sudo
    replace_or_append /etc/lightdm/lightdm-gtk-greeter.conf "#background=" "background=#2f343f" sudo
    replace_or_append /etc/lightdm/lightdm-gtk-greeter.conf "#xft-dpi=" "xft-dpi=261" sudo

    # Lightdm
    sudo systemctl enable lightdm

    # Dunst settings 
    replace_or_append /etc/dunst/dunstrc "offset = 10x50" "offset = 40x70" sudo
    replace_or_append /etc/dunst/dunstrc "notification_limit = 0" "notification_limit = 5" sudo

    # Directory
    mkdir -p $HOME/workspace &> /dev/null
    
    if [ ! -f "$HOME/.dotfiles/config" ];then
        rm .config/i3/config
        mkdir .config/polybar
    fi

else
    read -p "enter the https URL for you git bare repo : " git_url
fi


# Tmp alias for installation only 
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=/home/$USER'

if [[ ! -d $HOME/.dotfiles/ ]]
then
    logging INFO "Did not find .dotfiles, so will check them out again"
    git clone --bare $git_url $HOME/.dotfiles 
    dotfiles checkout -f || echo "Dotfiles checkout failed."
    if [ $? -ne 0 ]; then
        logger WARNING "Dotfiles pull failed. retrying..."
        sudo rm -rf $HOME/.dotfiles
        git clone --bare $git_url $HOME/.dotfiles
    else
        logger INFO "Dotfiles Successfully checked out."
    fi
else
    
    logger INFO "Updating dotfiles"
    
    dotfiles pull || logger ERROR "Dotfiles pull failed."    
fi

# Create folders for filemanager
mkdir -p $HOME/Downloads &> /dev/null
mkdir -p $HOME/Desktop &> /dev/null
mkdir -p $HOME/Pictures &> /dev/null
mkdir -p $HOME/.config/wireguard &> /dev/null

if [ "$(echo $SHELL )" != "/bin/zsh" ]; then
    sudo chsh -s /bin/zsh $USER
fi

## FIX ME! The check is not good....
if [ ! -f $HOME/.zshrc ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' ~/.zshrc
fi

# Aliases and functions
# Copy .aliases and .functions files to .config
zsh_config_path=$HOME/.config/zsh
mkdir -p $zsh_config_path

cp .aliases $zsh_config_path/
cp .functions $zsh_config_path/

# Add sources to .zshrc if not already there
add_source_to_zshrc "$zsh_config_path/.aliases"
add_source_to_zshrc "$zsh_config_path/.functions"

if [[ $zsh_work == "y" ]]; then
    add_source_to_zshrc "$zsh_config_path/.work"
fi

# Update locate database
sudo updatedb

# Power settings
sudo powertop --auto-tune &> /dev/null

# Cleanup unused packages 
paru -Qdtq | paru --noconfirm -Rs - &> /dev/null

# Converts https to ssh
if [ -z $skip_convert ]; then
    replace_or_append $HOME/.dotfiles/config "https://github.com/" "git@github.com:" sudo
else
    logging WARNING "Skipping conversion from https to ssh"
fi

echo ----------------------
echo "Please reboot your PC"
echo ----------------------
