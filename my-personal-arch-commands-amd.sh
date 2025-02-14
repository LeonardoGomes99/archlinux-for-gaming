#!/bin/bash

# Exit on error and enable debugging
set -e
set -x

# Helper function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

enable_multilib() {
    echo "Verificando se o repositório multilib está ativado..."
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo "Habilitando multilib..."
        sudo sed -i '/#\[multilib\]/s/^#//' /etc/pacman.conf
        sudo sed -i '/#Include = \/etc\/pacman.d\/mirrorlist/s/^#//' /etc/pacman.conf
        sudo pacman -Syu --noconfirm
    else
        echo "O repositório multilib já está ativado."
    fi
}

# Disable IPv6 for all interfaces and specifically for the wireless interface
disable_ipv6() {
    echo "Disabling IPv6..."
    if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.d/99-sysctl.conf; then
        echo -e "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
        WLAN_INTERFACE=$(iw dev | awk '$1=="Interface"{print $2}')
        if [[ -n "$WLAN_INTERFACE" ]]; then
            echo "net.ipv6.conf.$WLAN_INTERFACE.disable_ipv6=1" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
        fi
        sudo sysctl --system
    else
        echo "IPv6 is already disabled."
    fi
}

update_and_install_packages() {
    echo "Updating system and installing packages..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm git vim base-devel iwd dhcpcd
}

install_yay() {
    if ! command_exists yay; then
        echo "yay is not installed. Installing yay..."
        git clone https://aur.archlinux.org/yay.git
        cd yay && makepkg -si --noconfirm
        cd .. && rm -rf yay
    else
        echo "yay is already installed."
    fi
}

install_amd_drivers() {
    echo "Installing AMD drivers..."
    sudo pacman -S --noconfirm vulkan-radeon lib32-vulkan-radeon
    git clone https://github.com/Frogging-Family/mesa-git.git ~/mesa-git
    cd ~/mesa-git
    makepkg -si --noconfirm
    cd .. && rm -rf ~/mesa-git
}

install_additional_packages() {
    echo "Installing additional packages..."
    sudo pacman -S --noconfirm chromium git steam gamemode mangohud wine-staging
    yay -S --noconfirm goverlay brave-bin
}

disable_baloo() {
    if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]] || pgrep -x "plasmashell" > /dev/null; then
        if command_exists balooctl; then
            echo "KDE Plasma is running. Disabling and purging Baloo..."
            balooctl stop
            balooctl disable
            balooctl purge
        else
            echo "Baloo is not installed. Skipping..."
        fi
    fi
}

install_zsh_and_ohmyzsh() {
    if ! command_exists zsh; then
        sudo pacman -S --noconfirm zsh
    fi
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        chsh -s $(which zsh)
    else
        echo "Oh My Zsh is already installed."
    fi
}

install_docker() {
    if ! command_exists docker; then
        echo "Installing Docker..."
        sudo pacman -S --noconfirm docker
        sudo groupadd -f docker
        sudo usermod -aG docker $USER
        sudo systemctl enable docker
        sudo systemctl start docker
        echo "Docker installed. Please log out and back in to apply group changes."
    else
        echo "Docker is already installed."
    fi
    if ! command_exists docker-compose; then
        echo "Installing Docker Compose..."
        sudo pacman -S --noconfirm docker-compose
    else
        echo "Docker Compose is already installed."
    fi
}

install_nodejs() {
    if ! command_exists node; then
        echo "Installing Node.js, npm, and Yarn..."
        sudo pacman -S --noconfirm nodejs npm
    else
        echo "Node.js is already installed."
    fi
    if [ ! -d "$HOME/.nvm" ]; then
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \ . "$NVM_DIR/nvm.sh"
        echo "nvm installed. Please restart your shell to use it."
    else
        echo "nvm is already installed."
    fi
}

install_kde_and_ly() {
    echo "Installing KDE Plasma and ly..."
    sudo pacman -S --noconfirm plasma
    yay -S --noconfirm ly
    sudo systemctl enable ly
    sudo systemctl start ly
}

main() {
    disable_ipv6
    enable_multilib
    update_and_install_packages
    install_yay
    install_amd_drivers
    install_additional_packages
    disable_baloo
    install_zsh_and_ohmyzsh
    install_docker
    install_nodejs
    install_kde_and_ly
    echo "All tools installed and configured!"
}

main
