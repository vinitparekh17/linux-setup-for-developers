# Check if /etc/os-release file exists
if [ -e /etc/os-release ]; then
    # Source the os-release file to get the necessary variables
    . /etc/os-release

    # Determine the distribution
    case $ID in
        ubuntu)
            echo "Detected Ubuntu"
            package_manager="apt-get"
            ;;
        fedora)
            echo "Detected Fedora"
            package_manager="dnf"
            ;;
        arch)
            echo "Detected Arch"
            package_manager="pacman"
            ;;
        centos)
            echo "Detected CentOS"
            # As of CentOS 8 and later, dnf is used
            package_manager="dnf"
            ;;
        *)
            echo "Unsupported or unknown distribution"
            exit 1
            ;;
    esac
    cp ~/.bashrc ~/.bashrc_backup
    sleep 2
    echo "Starting installation setup..."

# A linux command script for pre configuring laptop for development

    sudo $package_manager update -y
    sudo $package_manager upgrade -y

# Some development essentials

    sudo $package_manager install -y git
    sudo $package_manager install -y curl
    sudo $package_manager install -y wget
    sudo $package_manager install -y code

    # Installing brave browser
    if [ $package_manager == "apt-get" ]; then
        sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
        sudo $package_manager update -y
        sudo $package_manager install brave-browser -y
    elif [ $package_manager == "dnf" ]; then
        sudo dnf install dnf-plugins-core -y
        sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo -y
        sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
        sudo dnf install brave-browser -y
    elif [ $package_manager == "pacman" ]; then
        echo "Enter your username of arch linux in which you want to install brave browser:"
        read username
        if [ -z "$username" ]; then
            sleep 5
            echo "Installing for root user!"
            sudo git clone https://aur.archlinux.org/yay.git
            cd yay
            makepkg -si
            yay -S brave-bin
            else
            sudo git clone https://aur.archlinux.org/yay.git
            sudo chown -R  $username:users yay
            cd yay
            makepkg -si
            yay -S brave-bin
            fi
    fi
    # Docker installation

    # Add Docker's official GPG key:
    sudo $package_manager update -y
    sudo $package_manager install -y ca-certificates gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo $package_manager update -y

    sudo $package_manager install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

    # Golang install
    wget https://go.dev/dl/go1.21.4.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf ~/go1.21.4.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin

    # Installing dotnet

    wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
    chmod +x dotnet-install.sh
    ./dotnet-install.sh --version latest
    ./dotnet-install.sh --version latest --runtime aspnetcore
    ./dotnet-install.sh --channel 8.0

        # Path configuration for dotnet
    DOTNET_FILE=dotnet-sdk-8.0.100-linux-x64.tar.gz
    export DOTNET_ROOT=$(pwd)/.dotnet
    mkdir -p "$DOTNET_ROOT" && tar zxf "$DOTNET_FILE" -C "$DOTNET_ROOT"
    export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

    # Installing nodejs lts version
    nvm install --lts

    # Customizing the terminal

    sudo $package_manager install -y zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    curl -o ~/.bashrc https://raw.githubusercontent.com/vinitparekh17/backup/main/.bashrc
    curl -o ~/.zshrc https://raw.githubusercontent.com/vinitparekh17/backup/main/.zshrc

    # load the terminal with new configurations
    source ~/.bashrc
    source ~/.zshrc
else
    echo "Unsupported or unknown distribution"
    exit 1
fi

echo "Installation completed successfully!"
echo -e "\e[1;33mOrignal bashrc file is backed up in ~/.bashrc_backup in case you want to revert back to it.\e[0m"