# Update pacman database
sudo pacman --noconfirm -Sy

# Go to home
sudo pacman -S --noconfirm --needed base-devel git rust

# TODO: Add error handing of install 
# Install Paru helper
#if [ $(which paru) != "/usr/bin/paru" ]; then
git clone https://aur.archlinux.org/paru.git
cd paru && makepkg -si && cd ..
sudo rm -R paru
#fi

sudo sed -i 's/#BottomUp/BottomUp/g' /etc/paru.conf
sudo sed -i 's/#SudoLoop/SudoLoop/g' /etc/paru.conf
sudo sed -i 's/#Color/Color/g' /etc/pacman.conf

# Install Packages
paru -S --noconfirm --needed zsh arandr meld dnsmasq rclone ntfs-3g flameshot acpid bc numlockx spotify unzip usbutils dmidecode autorandr pavucontrol variety termite feh git tree virt-manager dunst xclip xorg-xkill rofi acpilight nautilus scrot teamviewer network-manager-applet xautolock man powertop networkmanager nm-connection-editor network-manager-applet openvpn slack-desktop wget python google-chrome freecad gparted peak-linux-headers kicad i3exit polybar parsec-bin can-utils visual-studio-code-bin ttf-nerd-fonts-symbols-1000-em libreoffice-fresh gnome-keyring

# Generate ssh key
if [[ ! -f $HOME/.ssh/id_rsa ]]
then
    ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
fi

# Set theme
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

# Set Backlight permissions and monotor rules
echo 'SUBSYSTEM=="backlight",RUN+="/bin/chmod 666 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"' | sudo tee /etc/udev/rules.d/backlight-permissions.rules
sudo sh -c 'echo SUBSYSTEM=="drm", ACTION=="change", RUN+="/usr/bin/autorandr" > /etc/udev/rules.d/70-monitor.rules'

# Enable services
if ! systemctl is-active --quiet NetworkManager ; then
    systemctl enable NetworkManager.service --now
fi

if ! systemctl is-active --quiet teamviewerd  ; then
    systemctl enable teamviewerd.service --now
fi

# Check if swap is configured
if ! grep -q  "/swap/swapfile" /proc/swaps
then
  # The swap and Hibernation part goes all credit to 
  # https://forum.manjaro.org/t/howto-enable-and-configure-hibernation-with-btrfs/51253
  # Swap
  export fs_uuid=$(findmnt / -o UUID -n) && echo ${fs_uuid}
  sudo mount -m -U $fs_uuid /mnt/system-${fs_uuid}
  sudo btrfs subvolume create /mnt/system-${fs_uuid}/@swap
  sudo umount /mnt/system-${fs_uuid}
  sudo mount -m -U ${fs_uuid} -o subvol=@swap,nodatacow /swap
  sudo touch /swap/swapfile
  sudo chattr +C /swap/swapfile
  export swp_size=$(echo "$(grep "MemTotal" /proc/meminfo | tr -d "[:blank:],[:alpha:],:") * 1.6 / 1000" | bc ) && echo $swp_size
  sudo dd if=/dev/zero of=/swap/swapfile bs=1M count=$swp_size status=progress
  sudo chmod 0600 /swap/swapfile
  sudo mkswap /swap/swapfile
  sudo umount /swap
  echo -e "UUID=$fs_uuid\t/swap\tbtrfs\tsubvol=@swap,nodatacow,noatime,nospace_cache\t0\t0" | sudo tee -a /etc/fstab
  echo -e "/swap/swapfile\tnone\tswap\tdefaults\t0\t0" | sudo tee -a /etc/fstab
  sudo systemctl daemon-reload
  sudo mount /swap
  sudo swapon -a
  swapon -s

  #Hibernate
  export swp_uuid=$(findmnt -no UUID -T /swap/swapfile) && echo $swp_uuid
  curl -s "https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c" > bmp.c
  gcc -O2 -o bmp bmp.c
  swp_offset=$(echo "$(sudo ./bmp /swap/swapfile | egrep "^0\s+" | cut -f9) / $(getconf PAGESIZE)" | bc) && echo $swp_offset
  echo -e "GRUB_CMDLINE_LINUX_DEFAULT+=\" resume=UUID=$swp_uuid resume_offset=$swp_offset \"" | sudo tee -a /etc/default/grub
  echo -e "HOOKS+=( resume )" | sudo tee -a /etc/mkinitcpio.conf
  sudo mkdir -pv /etc/systemd/system/{systemd-logind.service.d,systemd-hibernate.service.d}
  echo -e "[Service]\nEnvironment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1" | sudo tee /etc/systemd/system/systemd-logind.service.d/override.conf
  echo -e "[Service]\nEnvironment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1" | sudo tee /etc/systemd/system/systemd-hibernate.service.d/override.conf
  sudo mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg 
fi

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

if [[ ! -f $HOME/.zshrc ]]
then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' ~/.zshrc

# Virt Manager
sudo usermod -G libvirt -a $USER
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service
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
    paru -S --noconfirm --needed laptop-mode-tools
    
    # Dunst settings 
    sudo sed -i 's/offset = 10x50/offset = 40x70/g' /etc/dunst/dunstrc
    sudo sed -i 's/notification_limit = 0/notification_limit = 5/g' /etc/dunst/dunstrc

    # Grub speedup
    grub_timeout="GRUB_TIMEOUT=0"
    if ! grep -Fxq $grub_timeout /etc/default/grub
    then
        sudo sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg

    # Directory
    mkdir -p $HOME/workspace &> /dev/null
    fi


elif [ $USER = screen ]; then
    # Autostart script for web kiosk
    echo Screen 
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
al_dotp="alias dotp='dotfiles commit -am update && dotfiles push'"
al_rs="alias rs='rsync --info=progress2 -au'"
al_can="alias cansetup='sudo ip link set can0 type can bitrate 125000 && sudo ip link set up can0'"
al_vpn="alias vpn='sudo openvpn --config /home/user/.config/vpn/vpn.ovpn'"

for value in "$al_dot" "$al_rs" "$al_dotp" "$al_can" "$al_vpn"
do
    if ! grep -Fxq "$value" $HOME/.zshrc
    then
        echo $value
        echo $value >> $HOME/.zshrc
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
mkdir -p $HOME/Downloads &> /dev/null
mkdir -p $HOME/Desktop &> /dev/null
mkdir -P $HOME/.config/vpn &> /dev/null

# not working
if [ "$(echo $SHELL )" != "/bin/zsh" ]; then
    chsh -s /bin/zsh
fi

# Power settings
sudo powertop --auto-tune

# Install updates and cleanup unused 
paru
paru -Qdtq | paru --noconfirm  -Rs - &> /dev/null

echo ----------------------
echo "Please reboot your PC"
echo ----------------------
