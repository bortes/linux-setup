#!/bin/bash

set -e

SCRIPT_NAME=$(basename $0)

source src/common.sh
source src/package.sh

export INSTALL_DIR="/opt"

export BURP_HOME="$INSTALL_DIR/burp"
export DBEAVER_HOME="$INSTALL_DIR/dbeaver"
export DOTNET_HOME="$INSTALL_DIR/dotnet"
export ILSPY_HOME="$INSTALL_DIR/ilspy"
export LIQUIBASE_HOME="$INSTALL_DIR/liquibase"
export MYSQL_HOME="$INSTALL_DIR/mysql"
export NGROK_HOME="$INSTALL_DIR/ngrok"
export NOMAD_HOME="$INSTALL_DIR/nomad"
export RCLONE_HOME="$INSTALL_DIR/rclone"
export TERRAFORM_HOME="$INSTALL_DIR/terraform"
export TESTSSL_HOME="$INSTALL_DIR/testssl"
export VOLTA_HOME="$INSTALL_DIR/volta"
export VSCODE_HOME="$INSTALL_DIR/vscode"

function uninstall()
{
    echo 1
}

function install()
{
    # PRE-INSTALLATION
    export PATH=$PATH:/opt/bin
    export PATH=$PATH:/home/$SUDO_USER/go/bin

    # BASE
    install_from_distro "$PACKAGE_BASE_DEVELOPMENT"
    install_from_distro "$PACKAGE_FLATPAK"
    install_from_distro "$PACKAGE_LIB_ARCHIVE"
    install_from_distro "$PACKAGE_LIB_CRYPTO"
    install_from_distro "$PACKAGE_LIB_CURL"
    install_from_distro "$PACKAGE_LIB_FFI"

    # SDK
    install_from_distro "$PACKAGE_GO"
    install_from_distro "$PACKAGE_JAVA"
    install_from_distro "$PACKAGE_PYTHON"
    install_from_distro "$PACKAGE_RUST"
    install_from_remote "https://dot.net/v1/dotnet-install.sh" "/tmp/dotnet-install.sh" "/tmp/dotnet" $DOTNET_HOME "$DOTNET_HOME/dotnet-install.sh"
    create_local_link $DOTNET_HOME/dotnet
    dotnet-install.sh --channel "3.0" --install-dir $DOTNET_HOME
    dotnet-install.sh --channel "5.0" --install-dir $DOTNET_HOME
    dotnet-install.sh --channel "6.0" --install-dir $DOTNET_HOME
    dotnet-install.sh --channel "7.0" --install-dir $DOTNET_HOME
    dotnet-install.sh --channel "8.0" --install-dir $DOTNET_HOME
    install_from_script "https://get.volta.sh" "/tmp/volta.sh" "$VOLTA_HOME/bin/volta"
    go env -w GO111MODULE=off
    volta install node@12.22
    volta install node@18.16
    volta install node@20.5

    # IDE
    install_from_go "gopls" "golang.org/x/tools/gopls@latest"
    install_from_go "dlv" "github.com/go-delve/delve/cmd/dlv@latest"
    install_from_remote "https://code.visualstudio.com/sha/download?build=stable&os=linux-x64" "/tmp/vscode.tar.gz" "/tmp/vscode/VSCode-linux-x64" $VSCODE_HOME "$VSCODE_HOME/bin/code"
    install_from_remote "https://github.com/dbeaver/dbeaver/releases/download/23.0.3/dbeaver-ce-23.0.3-linux.gtk.x86_64.tar.gz" "/tmp/dbeaver.tar.gz" "/tmp/dbeaver/dbeaver" $DBEAVER_HOME "$DBEAVER_HOME/dbeaver"
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension cschlosser.doxdocgen
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension eamodio.gitlens
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension eriklynd.json-tools
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension golang.Go
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension HashiCorp.terraform
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension KevinRose.vsc-python-indent
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension ms-azuretools.vscode-azurefunctions
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension ms-dotnettools.csharp
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension ms-dotnettools.dotnet-interactive-vscode
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension ms-python.python
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension ms-vscode.cpptools-extension-pack
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension redhat.vscode-xml
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension rust-lang.rust-analyzer
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension shd101wyy.markdown-preview-enhanced
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension VisualStudioExptTeam.intellicode-api-usage-examples
    code --extensions-dir $VSCODE_HOME/resources/app/extensions --user-data-dir /home/$SUDO_USER/.vscode --install-extension vscjava.vscode-java-pack
    change_owner /home/$SUDO_USER/.vscode

    # CLI
    install_from_distro "$PACKAGE_DOCKER"
    install_from_distro "$PACKAGE_NETWORK_BUNDLE"
    install_from_distro "$PACKAGE_NMAP"
    install_from_remote "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz" "/tmp/ngrok.tar.gz" "/tmp/ngrok" $NGROK_HOME "$NGROK_HOME/ngrok"
    install_from_remote "https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.32-linux-glibc2.12-x86_64.tar.xz" "/tmp/mysql.tar.gz" "/tmp/mysql/mysql-8.0.32-linux-glibc2.12-x86_64" $MYSQL_HOME "$MYSQL_HOME/bin/mysqldump"
    install_from_remote "https://downloads.rclone.org/v1.63.1/rclone-v1.63.1-linux-amd64.zip" "/tmp/rclone.zip" "/tmp/rclone/rclone-v1.63.1-linux-amd64" $RCLONE_HOME "$RCLONE_HOME/rclone"
    install_from_remote "https://github.com/drwetter/testssl.sh/archive/refs/heads/3.2.zip" "/tmp/testssl.zip" "/tmp/testssl/testssl.sh-3.2" $TESTSSL_HOME "$TESTSSL_HOME/testssl.sh"
    install_from_remote "https://github.com/liquibase/liquibase/releases/download/v4.21.0/liquibase-4.21.0.tar.gz" "/tmp/liquibase.tar.gz" "/tmp/liquibase" $LIQUIBASE_HOME "$LIQUIBASE_HOME/liquibase"
    install_from_remote "https://releases.hashicorp.com/nomad/1.6.1/nomad_1.6.1_linux_amd64.zip" "/tmp/nomad.zip" "/tmp/nomad" $NOMAD_HOME "$NOMAD_HOME/nomad"
    install_from_remote "https://releases.hashicorp.com/terraform/1.5.4/terraform_1.5.4_linux_amd64.zip" "/tmp/terraform.zip" "/tmp/terraform" $TERRAFORM_HOME "$TERRAFORM_HOME/terraform"
    install_from_go "sct" "github.com/gocaio/sct@latest"
    install_from_python "aws" "awscli"
    install_from_python "az" "azure-cli"
    install_from_rust "tokei" "tokei"

    # APPLICATION
    # install_from_distro "$PACKAGE_MELD"
    install_from_flatpak "flatseal" "com.github.tchx84.Flatseal"
    install_from_flatpak "insomnia" "rest.insomnia.Insomnia"
    install_from_flatpak "jmeter" "org.apache.jmeter"
    install_from_flatpak "meld" "org.gnome.meld"
    install_from_flatpak "yubioath" "com.yubico.yubioath"
    install_from_flatpak "zap" "org.zaproxy.ZAP"
    install_from_dotnet "https://github.com/icsharpcode/AvaloniaILSpy/archive/refs/heads/master.zip" "/tmp/ilspy.zip" "/tmp/ilspy/AvaloniaILSpy-master" $ILSPY_HOME "$ILSPY_HOME/ILSpy/bin/Debug/net6.0/ILSpy"
    install_from_script "https://portswigger-cdn.net/burp/releases/download?product=community&type=Linux" "/tmp/burp.sh" "$BURP_HOME/BurpSuiteCommunity" -q -overwrite -dir $BURP_HOME

    # INTERNET
    install_from_distro "$PACKAGE_REMMINA"
    install_from_distro "$PACKAGE_WIRESHARK"

    # BROWSER
    install_from_flatpak "brave" "com.brave.Browser"
    install_from_flatpak "chrome" "com.google.Chrome"
    install_from_flatpak "edge" "com.microsoft.Edge"
    install_from_flatpak "opera" "com.opera.Opera"
    install_from_flatpak "tor" "com.github.micahflee.torbrowser-launcher"

    # OFFICE
    install_from_distro "$PACKAGE_GIMP"
    install_from_distro "$PACKAGE_SIMPLE_SCREEN_RECORDER"
    install_from_flatpak "flameshot" "org.flameshot.Flameshot"
    install_from_flatpak "slack" "com.slack.Slack"
    install_from_flatpak "wps" "com.wps.Office"

    # POST-INSTALLATION

    create_local_profile "setup_profile.sh" "
        # dotnet
        export DOTNET_ROOT=$DOTNET_HOME

        # volta
        export VOLTA_HOME=$VOLTA_HOME

        # aws completion
        complete -C $(which aws_completer) aws

        # aws completion
        source $(which az.completion.sh)

        # path
        export PATH=\$PATH:\$HOME/go/bin:\$VOLTA_HOME/bin:/opt/bin
    "

    create_local_application "dbeaver.desktop" "
        [Desktop Entry]
        Type=Application
        Name=Dbeaver Community Edition
        Exec=$DBEAVER_HOME/dbeaver
        Icon=$DBEAVER_HOME/dbeaver.png
        Terminal=false
        Categories=Development;IDE;
    "

    create_local_application "ilspy.desktop" "
        [Desktop Entry]
        Type=Application
        Name=ILSpy
        Exec=$ILSPY_HOME/ILSpy/bin/Debug/net6.0/ILSpy
        Icon=$ILSPY_HOME/ILSpy.Core/Images/ILSpy.png
        Terminal=false
        Categories=Development;IDE;
    "

    create_local_application "vscode.desktop" "
        [Desktop Entry]
        Type=Application
        Name=Visual Studio Code
        Exec=$VSCODE_HOME/bin/code
        Icon=$VSCODE_HOME/resources/app/resources/linux/code.png
        Terminal=false
        Categories=Development;IDE;
    "
}

function main()
{
    local command_name="${1:-install}"

    if [ -z $SUDO_USER ]
    then
        log_error "acesso negado. execute o instalador com permissao de super usuario"
    fi

    if [[ $command_name != @(install|uninstall) ]]
    then
        log_error "comando invalido. valores suportados: install, uninstall"
    fi

    $command_name
}

main $@
