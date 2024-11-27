# Arch Installer

## Description
This is the installer we use to prepare our Arch install after the initial Arch installation.

## Installation
Here is the basic installation guide:
1. Install Arch on your PC
    * Set your preferences for all except:
        - Profile: minimal
        - Audio: Pulse
        - Additional packages: git (vim/nano is also recommended)
2. Install, then reboot without chroot
3. Navigate to where you want to store the script
4. Clone the repository: `git clone https://github.com/ingar195/arch.git`
5. cd to the arch folder
6. Run the script: `sh install.sh`
7. Reboot the PC

## Dotfiles
Dotfiles is what we have named the git bare repo we use for backing up OS settings and non-sensitive files.  
These are stored in a GitHub repo like [this](https://github.com/ingar195/arch.git).

## Usage
When installing, you have a selection of arguments. They can be used all together or one at a time.
Arguments:
* `sh install.sh [-s -d -c -n]`
* `-s` skips converting the dotfiles repo to SSH (mostly used for testing)
* `-d` enables debug to console log
* `-c` includes installation of the sec tools
* `-n` skips blacklisting of Nvidia drivers


## Features
Here are some of the features:  
* Updates the PC
* Sets up git username and email
* Installs paru-bin and all packages from the packages file
* Configures:
    * Dark theme
    * Paru
    * Time to Oslo
    * Rules for backlight
    * Enables services for installed programs
    * Blacklists Nvidia drivers
    * Lid actions
    * Optimizes power usage with TLP
    * Dotfiles setup

* Aliases and commands:
    - `dotfiles`    Is an alias for using the dotfiles repo that gets initialized or downloaded during installation.
    - `dotp`        Alias for quickly committing and pushing all changes in files already committed 
    - `rs`          Alias for using the rsync command with our preferred options
    - `cansetup`    Alias for setting up can-bus to be used with can-utils
    - `wg`          Alias for connecting with WireGuard to the file `/home/$USER/.config/wireguard/wg0.conf`
    - `wgd`         Alias for disconnecting WireGuard
    - `wgh`         Alias for connecting with WireGuard to the file `/home/$USER/.config/wireguard/wg1.conf`
    - `wgd`         Alias for disconnecting WireGuard
    - `lll`         Alias for tree view
    - `py`          Runs Python3 commands
    - `python`      Runs Python3 commands
    - `cpu`         Used for checking current core clock per thread
    - `install`     Uses paru and searches for a program to install
    - `uninstall`   Removes installed programs
    - `update`      Updates the script and the PC