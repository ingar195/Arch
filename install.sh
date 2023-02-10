# Update pacman database
sudo pacman --noconfirm -Sy
cd 
sudo pacman -S --noconfirm --needed git

if [ "$(which paru)" == "/usr/bin/paru" ]; then
  echo skipping
else
  # Install Paru helper
  git clone https://aur.archlinux.org/paru.git
  cd paru && makepkg -si && cd ..
  sudo rm -R paru
fi

sudo sed -i 's/#BottomUp/BottomUp/g' /etc/paru.conf
sudo sed -i 's/#SudoLoop/SudoLoop/g' /etc/paru.conf
sudo sed -i 's/#Color/Color/g' /etc/pacman.conf
# install Packages
paru -S --noconfirm --needed arandr meld dnsmasq onedrive flameshot acpid bc numlockx unzip usbutils dmidecode autorandr pavucontrol variety termite feh git tree virt-manager dunst xclip xorg-xkill rofi acpilight nautilus scrot teamviewer network-manager-applet xautolock zsh powertop networkmanager nm-connection-editor network-manager-applet openvpn slack-desktop wget python google-chrome freecad gparted peak-linux-headers kicad i3exit polybar parsec-bin can-utils visual-studio-code-bin


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


sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' ~/.zshrc
#sudo nano /etc/systemd/logind.conf 
#sudo sed -i 's/#Color/Color/g' /etc/systemd/logind.conf 

sudo usermod -G libvirt -a $USER
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service


if [ $USER = fw ]; then
  git_url="https://frodus@bitbucket.org/frodus/dotfiles.git"
elif [ $USER = user ]; then
  git_url="https://github.com/ingar195/.dotfiles.git"
else
  read -p "enter the https URL for you git bare repo : " git_url
fi

if [[ ! -f .dotfiles/config ]]
then
    rm .config/i3/config
    mkdir .config/polybar   
fi


al="alias dotfiles='/usr/bin/git --git-dir=/home/user/.dotfiles/ --work-tree=/home/user'"

if grep -Fxq "$al" .zshrc
then
    echo Skipping
else
    echo "alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'" >> ~/.zshrc

fi

alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME' 

echo ".dotfiles" > .gitignore 
git clone --bare $git_url  $HOME/.dotfiles 
dotfiles checkout -f

mkdir ~/Downloads 
mkdir ~/Desktop
chsh -s /bin/zsh

sudo powertop --auto-tune

# Cleanup unused
paru -Qdtq | paru --noconfirm  -Rs -
echo "Please reboot you PC"