# Update pacman database
sudo pacman --noconfirm -Sy
sudo pacman -S --noconfirm --needed base-devel git rust &> /dev/null


# Install Paru helper
if ! command -v paru --help &> /dev/null; then
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd ..
    sudo rm -r paru-bin
fi


# Install Packages from file
install_packages() {
    echo "Installing" $1
    local filename=$1
    while IFS= read -r package; do
        # start_time=$(date +%s)
        # Check is package is already installed
        if [ -n "$(paru -Qs "$package")" ]; then
            echo "INFO: $package is already installed" >> log.log
            continue
        fi
        echo "--------------------------------Installing $package"
        paru -S --noconfirm --needed "$package" || echo "ERROR: $package" >> error.log
        # end_time=$(date +%s)
        # duration=$((end_time - start_time))
        # echo "INFO: Installation of $package took $duration sec" >> paru.log
    done < "$filename"
}

install_packages "packages"