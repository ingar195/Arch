import subprocess
import logging
import getpass
import shutil
import os


def run_program(command, ignore_error=False):
    process = subprocess.run(command, shell=True, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return_code = process.returncode
    if return_code != 0 and not ignore_error:
        logging.error(f"Failed to run the command: {command}")

    return return_code

def install_packages(packages, pacman=False, code=False):
    if type(packages) is not list:
        packages = [packages]

    for package in packages:
        if run_program(f"pacman -Qs {package} | grep -q local/{package}", ignore_error= True) == 0:
            logging.debug(f"Skipping {package}, already installed")
            continue
        if code:
            if run_program(f"code --list-extensions | grep -qi {package}", ignore_error=True) == 0:
                logging.debug(f"Skipping {package}, already installed")
                continue
            command = f"code --install-extension {package}"
            type_name = "code"
        elif pacman:
            command = f"sudo pacman -S --noconfirm {package}"
            type_name = "pacman"
        else:
            command = (f"paru -S --noconfirm --needed {package}")
            type_name = "paru"

        return_code = run_program(command, True)

        if return_code != 0:
            logging.error(f"Failed to install the package: {package}")
            return return_code
        else:
            logging.info(f"Installed {type_name} package: {package}")

    return 0

def make_install(repo_url):
    return_code = run_program(f"git clone {repo_url}")
    if return_code != 0:
        return return_code

    repo_name = repo_url.split("/")[-1].replace(".git", "")
    return_code = run_program(f"cd {repo_name} && makepkg -si --noconfirm")
    return return_code


def file_exists(file_path):
    return os.path.exists(file_path)


def in_file(file_path, string):
    if not file_exists(file_path):
        return False

    with open(file_path, "r") as file:
        for line in file:
            if string in line:
                return True
    return False


def add_to_group(group, user):
    if type(group) is not list:
        group = [group]
    for g in group:
        if run_program(f"groups {user} | grep '{g}'") != 0:
            logging.debug(f"Adding {user} to {g}")
            run_program(f"sudo gpasswd -a {user} {g}")

    return True


def edit_file(file_path, org, new, sudo=False):
    if sudo:
        if run_program(f"sudo test -f {file_path}") == 0:
            logging.debug(f"File {file_path} does exist")
        else:
            if not file_exists(file_path):
                logging.error(f"File {file_path} does not exist")
                return False

    command = f"sed -i 's/{org}/{new}/g' {file_path}"
    if sudo:
        command = f"sudo {command}"
    if in_file(file_path, new):
        logging.debug(f"Skipping {file_path}, already like this")
        return True
    logging.debug(f"Editing {file_path} from {org} to {new}")
    run_program(command)


def add_to_file(file_path, content, sudo=False, create=False):
    if not file_exists(file_path):
        if create:
            logging.info(f"Creating file {file_path}")
            if sudo:
                run_program(f"sudo touch {file_path}")
            else:
                run_program(f"touch {file_path}")
        else:
            logging.error(f"File {file_path} does not exist")
            return False
    if in_file(file_path, content):
        logging.debug(f"Skipping {file_path}, already like this")
        return True
    if sudo:
        command = f"sudo echo '{content}' | sudo tee {file_path}"
    else:
        command = f"echo '{content}' >> {file_path}"
    logging.debug(f"Adding {content} to {file_path}")
    run_program(command)

    return True


def service(name, start=True, enable=True):
    service_status = run_program(f"sudo systemctl is-active {name}", ignore_error=True)
    if service_status != 0:
        logging.info(f"Service {name} is not active")
        if start:
            command = f"sudo systemctl start {name}"
            logging.info(f"Starting service {name}")
        elif enable:
            command = f"sudo systemctl enable {name} --now"
            logging.info(f"Enabling and starting service {name}")
        return run_program(command)
        
    elif not start:
        command = f"sudo systemctl stop {name}"
        logging.info(f"Stopping service {name}")
        return run_program(command, ignore_error=True)

    return False


def file_to_list(file_path):
    content_list = []
    if not file_exists(file_path):
        logging.error(f"File {file_path} does not exist")
        return False
    with open(file_path, "r") as file:
        for line in file:
            content_list.append(line.strip())

    return content_list


def create_dir(dir_path, sudo=False):
    if not os.path.exists(dir_path):
        if sudo:
            return_code = run_program(f"sudo mkdir -p {dir_path}")
            if return_code != 0:
                logging.error(f"Failed to create directory {dir_path}")
                return return_code
        else:
            os.makedirs(dir_path)
        logging.info(f"Creating directory {dir_path}")


def delete(file_path):
    if file_exists(file_path):
        if os.path.isdir(file_path):
            shutil.rmtree(file_path)
        else:
            os.remove(file_path)
    else:
        logging.debug(f"File {file_path} does not exist")


if __name__ == "__main__":
    TRACE = 5  # Custom log level value for TRACE
    logging.addLevelName(TRACE, "TRACE")

    logging.basicConfig(
        format='%(asctime)s %(levelname)-8s [%(filename)s:%(lineno)d] %(message)s',
        datefmt='%d-%m-%Y:%H:%M:%S',
        level="INFO", # 10 = DEBUG, 5 = TRACE
        handlers=[
            logging.FileHandler("installer.log"),
            logging.StreamHandler()
        ])

    logging.info("Starting installation")

    to_file = {}
    user = getpass.getuser()
    home_dir = os.path.expanduser("~")
    dotfiles_command =f'/usr/bin/git --git-dir={home_dir}/.dotfiles/ --work-tree={home_dir}'

    run_program("sudo pacman --noconfirm -Syu")
    install_packages(["base-devel", "git", "rust"], pacman=True)


    file_name = os.path.join(home_dir, ".zshrc")
    if not in_file(file_name, "source $HOME/.config/zsh/.work"):
        response = input("Do you want to add work to your zshrc? (y/n): ")
        if response.lower() == "y":
            to_file[file_name] = "source $HOME/.config/zsh/.work"
    
    # git user setup
        
    if run_program("paru --version") != 0:
        logging.info("Installing paru")
        run_program("git clone https://aur.archlinux.org/paru.git")
        run_program("cd paru && makepkg -si --noconfirm")
        run_program("cd .. && rm -rf paru")

        if run_program("paru --help") != 0:
            logging.error("Failed to install paru")
            exit(1)
    else:
        logging.debug("Paru is already installed")

    edit_file("/etc/paru.conf", "#BottomUp", "BottomUp", sudo=True)
    edit_file("/etc/paru.conf", "#SudoLoop", "SudoLoop", sudo=True)
    edit_file("/etc/paru.conf", "#Color", "Color", sudo=True)


    install_packages(file_to_list("packages"))
    install_packages(file_to_list("code_packages"), code=True)

    file_path = os.path.join(home_dir, ".ssh/id_rsa")
    if not file_exists(file_path):
        run_program("ssh-keygen -m PEM -N '' -f ~/.ssh/id_rsa")
    
    theme_settgins = [
        'gsettings set org.gnome.desktop.interface color-scheme prefer-dark',
        'gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"',
        'gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false',
        'xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"'
    ]
    run_program(theme_settgins)
    edit_file(os.path.join(home_dir, ".config/teamviewer/client.conf"), "ColorScheme = 1", "ColorScheme = 2")

    reboot_required = add_to_file("/etc/environment", "GTK_THEME=Adwaita-dark", sudo=True)

    add_to_file("/etc/udev/rules.d/backlight-permissions.rules",
                'SUBSYSTEM=="backlight",RUN+="/bin/chmod 666 /sys/class/backlight/%k/brightness /sys/class/backlight/%', 
                sudo=True, create=True)

    add_to_file("/etc/udev/rules.d/70-monitor.rules",
                'SUBSYSTEM=="drm", ACTION=="change", RUN+="/usr/bin/autorandr"', 
                sudo=True, create=True)
    
    service("teamviewerd", enable=True)
    service("syslog-ng@default", enable=True)

    service("systemd-networkd.service", start=False)
    service("iwd.service", start=False)
    service("NetworkManager.service", enable=True)

    add_to_file("/etc/modprobe.d/blacklist-nvidia-nouveau.conf", "blacklist nouveau", sudo=True, create=True)
    add_to_file("/etc/modprobe.d/blacklist-nvidia-nouveau.conf", "options nouveau modeset=0", sudo=True)

    service("docker.service", enable=True)
    service("acpid.service", enable=True)

    add_to_group(["docker","libvirt", "uucp"], user)

    service("wazuh-agent", enable=True)

    edit_file("/var/ossec/etc/ossec.conf", "MANAGER_IP", "213.161.247.227", sudo=True)

    if user == "fw":
        dotfiles_url = "https://github.com/frodus/dotfiles.git"

        # Add Teamviewer config to make it start
        run_program("sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/")
        add_to_file("/etc/systemd/system/getty@tty1.service.d/getty@tty1.service-drop-in.conf", 
                '[Service] \nEnvironment=XDG_SESSION_TYPE=x11', sudo=True)

        install_packages(file_to_list(f"{user}_packages"))

    elif user == "user" or user == "ingar":
        dotfiles_url = "https://github.com/ingar195/.dotfiles.git"

        # Power Save
        edit_file('/etc/systemd/logind.conf', '#HandleLidSwitch=suspend', 'HandleLidSwitch=suspend', sudo=True)
        edit_file('/etc/systemd/logind.conf', '#IdleAction=ignore', 'IdleAction=suspend', sudo=True)
        edit_file('/etc/systemd/logind.conf', '#IdleActionSec=30min', 'IdleActionSec=30min', sudo=True)
        edit_file('/etc/systemd/logind.conf', '#HoldoffTimeoutSec=30s', 'HoldoffTimeoutSec=5s', sudo=True)
        install_packages(file_to_list("user_packages"))

        # Greeter
        edit_file('/etc/lightdm/lightdm-gtk-greeter.conf', '#theme-name=', 'theme-name=Numix', sudo=True)
        edit_file('/etc/lightdm/lightdm-gtk-greeter.conf', '#icon-theme-name=', 'icon-theme-name=Papirus-Dark', sudo=True)
        edit_file('/etc/lightdm/lightdm-gtk-greeter.conf', '#background=', 'background=#2f343f', sudo=True)
        edit_file('/etc/lightdm/lightdm-gtk-greeter.conf', '#xft-dpi=', 'xft-dpi=261', sudo=True)
    
        run_program("sudo systemctl enable lightdm")
        # Dunst settings 
        edit_file('/etc/dunst/dunstrc', 'offset = 10x50', 'offset = 40x70', sudo=True)
        edit_file('/etc/dunst/dunstrc', 'notification_limit = 0', 'notification_limit = 5', sudo=True)

        install_packages("ttf-nerd-fonts-symbols", pacman=True)

        create_dir(os.path.join(home_dir, "workspace"))

        if not file_exists(os.path.join(home_dir, ".dotfiles/config")):
            delete(os.path.join(home_dir, ".config/i3"))
            delete(os.path.join(home_dir, ".config/polybar"))

    if not file_exists(os.path.join(home_dir, ".dotfiles/config")):
        # Clone dotfiles
        run_program(f"git clone --bare {dotfiles_url}")
    
    # Create folders for filemanager
    create_dir(os.path.join(home_dir, "Desktop"))
    create_dir(os.path.join(home_dir, "Pictures"))
    create_dir(os.path.join(home_dir, "Downloads")) 
    create_dir(os.path.join(home_dir, ".config/wireguard"))

    if os.environ['SHELL'] != "/bin/zsh":
        run_program(f"sudo chsh -s /bin/zsh {user}")

    if not file_exists(os.path.join(home_dir, ".zshrc")):
        run_program('sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended')
        edit_file(os.path.join(home_dir, ".zshrc"), 'ZSH_THEME="robbyrussell"', 'ZSH_THEME="agnoster"')


    zsh_config_path = os.path.join(home_dir, ".config/zsh")
    os.makedirs(zsh_config_path, exist_ok=True)

    shutil.copy('.functions', zsh_config_path)
    shutil.copy('.aliases', zsh_config_path)

    add_to_file(os.path.join(home_dir, ".zshrc"), "source $HOME/.config/zsh/.aliases")
    add_to_file(os.path.join(home_dir, ".zshrc"), "source $HOME/.config/zsh/.functions")

    for file, content in to_file.items():
        add_to_file(file, content)

    run_program("sudo updatedb")

    run_program("sudo powertop --auto-tune")

    # Install updates and cleanup unused 
    logging.info("Checking for updates and removing unused packages")
    # run_program("paru -Qdtq | paru --noconfirm -Rs")
    run_program("paru -Syu --noconfirm")

    # Converts https to ssh
    edit_file(os.path.join(home_dir, ".dotfiles/config"), "https://github.com/", "git@github.com:")

    logging.info("Done, you should reboot now")