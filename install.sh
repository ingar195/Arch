# Update pacman database
sudo pacman --noconfirm -Sy

# Go to home
cd $HOME
sudo pacman -S --noconfirm --needed base-devel git


# TODO: Add error handing of install 
# Install Paru helper
git clone https://aur.archlinux.org/paru.git
cd paru && makepkg -si && cd ..
sudo rm -R paru
# if [ "$(which paru)" == "/usr/bin/paru" ]; then
# fi
git clone https://aur.archlinux.org/paru.git
cd paru && makepkg -si && cd ..
sudo rm -R paru
sudo sed -i 's/#BottomUp/BottomUp/g' /etc/paru.conf
sudo sed -i 's/#SudoLoop/SudoLoop/g' /etc/paru.conf
sudo sed -i 's/#Color/Color/g' /etc/pacman.conf

# Install Packages
paru -S --noconfirm --needed arandr meld dnsmasq onedrive flameshot acpid bc numlockx spotify unzip usbutils dmidecode autorandr pavucontrol variety termite feh git tree virt-manager dunst xclip xorg-xkill rofi acpilight nautilus scrot teamviewer network-manager-applet xautolock zsh man powertop networkmanager nm-connection-editor network-manager-applet openvpn slack-desktop wget python google-chrome freecad gparted peak-linux-headers kicad i3exit polybar parsec-bin can-utils visual-studio-code-bin tf-nerd-fonts-symbols-1000-em libreoffice-fresh


if [[ ! -f .ssh/id_rsa ]]
then
    ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
fi

gsettings set org.gnome.desktop.interface color-scheme prefer-dark

echo 'SUBSYSTEM=="backlight",RUN+="/bin/chmod 666 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"' | sudo tee -a /etc/udev/rules.d/backlight-permissions.rules
sudo sh -c 'echo SUBSYSTEM=="drm", ACTION=="change", RUN+="/usr/bin/autorandr" > /etc/udev/rules.d/70-monitor.rules'


if systemctl is-active --quiet NetworkManager ; then
    echo Skipping NetworkManager service
else
    systemctl enable NetworkManager.service --now
fi


if systemctl is-active --quiet teamviewerd  ; then
    echo Skipping teamviewerd service
else
    systemctl enable teamviewerd.service --now
fi


sudo sh -c 'echo "sudo ip link set can0 type can bitrate 125000" > /usr/bin/cansetup'
sudo sh -c 'echo "sudo ip link set up can0" >> /usr/bin/cansetup'

sudo chmod +x /usr/bin/cansetup

#swap:
#https://forum.manjaro.org/t/howto-enable-and-configure-hibernation-with-btrfs/51253

sudo sh -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo sh -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"

if [ ! $(git config user.email)  ]; then
    read -p "Type your git email:  " git_email
    git config --global user.email $git_email
    
fi
if [ ! $(git config user.name)  ]; then
    read -p "Type your git Full name:  " git_name
    git config --global user.name $git_name
fi

if [[ ! -f .zshrc ]]
then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' ~/.zshrc

# VirtManager
sudo usermod -G libvirt -a $USER
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service

# Network dows not work, run this to  make it work 
# sudo virsh net-start default

# This is not tested, wil hopefully fix virt networks
sudo virsh net-autostart default


# user defaults
if [ $USER = fw ]; then
    git_url="https://frodus@bitbucket.org/frodus/dotfiles.git"

    elif [ $USER = user ]; then
    git_url="https://github.com/ingar195/.dotfiles.git"
    
    # Power Save
    sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=suspend/g' /etc/systemd/logind.conf
    sudo sed -i 's/#IdleAction=ignore/IdleAction=suspend/g' /etc/systemd/logind.conf
    sudo sed -i 's/#IdleActionSec=30min/IdleActionSec=30min/g' /etc/systemd/logind.conf
    sudo sed -i 's/#HoldoffTimeoutSec=30s/HoldoffTimeoutSec=5s/g' /etc/systemd/logind.conf
    
    # Dunst settings 
    sudo sed -i 's/offset = 10x50/offset = 40x70/g' /etc/dunst/dunstrc
    sudo sed -i 's/notification_limit = 0/notification_limit = 5/g' /etc/dunst/dunstrc

    # Grub speedup
    sudo sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub

    elif [ $USER = screen ]; then
    # Autostart script for web kiosk
else
    read -p "enter the https URL for you git bare repo : " git_url
fi

if [[ ! -f .dotfiles/config ]]
then
    rm .config/i3/config
    mkdir .config/polybar
fi

# Aliases
al_dot="alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=/home/user'"
al_rs="alias rs=rsync --info=progress2 -au"

for value in "$al_dot" "$al_rs"
do
    if grep -Fxq "$value" .zshrc
    then
        echo Skipping
    else
        echo $value
        echo $value >> .zshrc
        
        
    fi
done

# Tmp alias for installation only 
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=/home/user'

# Create gitingore
if [[ ! -f .gitignore ]]
then
    echo ".dotfiles" > .gitignore
    git clone --bare $git_url $HOME/.dotfiles
    dotfiles checkout -f
else
    dotfiles pull
fi




# Create folders for filemanager
mkdir ~/Downloads &> /dev/null
mkdir ~/Desktop &> /dev/null

if [ "$(echo $SHELL )" != "/bin/zsh" ]; then
    chsh -s /bin/zsh
fi

# Power settings
sudo powertop --auto-tune

# Cleanup unused
paru -Qdtq | paru --noconfirm  -Rs - &> /dev/null

echo ----------------------
echo "Please reboot your PC"
echo ----------------------
