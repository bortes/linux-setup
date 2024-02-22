TRUE=0
FALSE=1

for folder in $(echo ${XDG_DATA_DIRS:-"/usr/local/share/:/usr/share/"} | tr ':' '\n')
do
    application_home="${folder}applications/"

    if [ -d $application_home ]
    then
        DEFAULT_APPLICATION_HOME=$application_home

        break
    fi
done


function log_info()
{
    local message="$1"
    local when=$(date +"%Y-%m-%dT%H:%M:%S.%N%z")
    
    echo "$when: $SCRIPT_NAME: $message"
}

function log_error()
{
    local message="$1"
    local return_code=${2:-"1"}
    local when=$(date +"%Y-%m-%dT%H:%M:%S.%N%z")
    
    echo "$when: $SCRIPT_NAME: $message"

    exit $return_code
}

function binary_exists()
{
    local binary_name="$1"

    if which $binary_name &> /dev/null
    then
        return $TRUE
    else
        return $FALSE
    fi	
}

function change_owner()
{
    local path="$1"

    chown $SUDO_USER:$SUDO_USER -R $path
}

function create_local_application()
{
    local application_name="$1"
    local application_settings="$(echo "$2" | sed '/^$/d; s/^[[:blank:]]*//;')"

    if [ ! -d $DEFAULT_APPLICATION_HOME ]
    then
        log_error "diretorio de aplicacoes nao encontrado. define o diretorio por meio da variavel DEFAULT_APPLICATION_HOME."
    fi

    echo "$application_settings" > "$DEFAULT_APPLICATION_HOME/$application_name"

    update-desktop-database $local_applications

    log_info "$application_name configurada"
}

function create_local_binary()
{
    local binary_name="$1"
    local binary_indent=$(echo "$2" | grep "\s" | head -n 1 | sed -E 's/( *)(.*)/\1/' | wc -m)
    local binary_data="$(echo "$2" | sed 's/^ \{,'$binary_indent'\}//')"
    local local_binaries="/opt/bin"

    echo "#!$SHELL $binary_data" > "$local_binaries/$binary_name"

    chmod +x "$local_binaries/$binary_name"

    change_owner "$local_binaries/$binary_name"
}

function create_local_link()
{
    local binary_name="$(basename $1)"
    local binary_path="$1"
    local local_binaries="/opt/bin"

    mkdir -p $local_binaries

    ln -s -f "$binary_path" "$local_binaries/$binary_name"
}

function create_local_profile()
{
    local profile_name="$1"
    local profile_indent=$(echo "$2" | grep "\s" | head -n 1 | sed -E 's/( *)(.*)/\1/' | wc -m)
    local profile_settings="$(echo "$2" | sed 's/^ \{,'$profile_indent'\}//')"
    local local_profiles="/etc/profile.d"

    mkdir -p $local_profiles

    echo "$profile_settings" > "$local_profiles/$profile_name"

    chmod +x "$local_profiles/$profile_name"

    change_owner "$local_profiles/$profile_name"

    log_info "$profile_name configurado"
}

function download_data()
{
    local remote_url="$1"
    local remote_file="$2"
    local extract_dir="$3"
    local install_dir="$4"

    mkdir -p $(dirname $remote_file)

    if [[ $remote_file == *.zip ]]
    then
        curl "$remote_url" --location --output "$remote_file"

        local extract_to=$(dirname $remote_file)/$(basename $remote_file | rev | cut -d'.' -f2- | rev)

        rm -r -f $extract_to

        mkdir -p $extract_to

        unzip -q $remote_file -d $extract_to
    elif [[ $remote_file == *.tar.* ]]
    then
        curl "$remote_url" --location --output "$remote_file"

        local extract_to=$(dirname $remote_file)/$(basename $remote_file | rev | cut -d'.' -f3- | rev)

        rm -r -f $extract_to
        
        mkdir -p $extract_to

        tar -x -f $remote_file -C $extract_to
    elif [[ $remote_file == *.sh ]]
    then
        curl "$remote_url" --location --output "$remote_file"

        chmod +x $remote_file

        mkdir -p $extract_dir

        mv -f -v $remote_file $extract_dir
    else
        log_error "compressao nao suportada. valores suportados: zip, tar"
    fi

    rm -r -f $install_dir

    mkdir -p $(dirname $install_dir)

    if [ $(basename $extract_dir) != $(basename $install_dir) ]
    then
        local extract_to=$(dirname $extract_dir)/$(basename $install_dir)

        mv -f $extract_dir $extract_to

        extract_dir=$extract_to
    fi

    mv -f $extract_dir $(dirname $install_dir)

    change_owner "$install_dir"
}

function install_from_distro()
{
    local package_names="$1"

    if binary_exists swupd
    then
        for package_name in "$package_names"
        do
            if ! swupd bundle-list | grep -q $package_name
            then
                swupd bundle-add $package_name
            fi
        done
    elif binary_exists apt
    then
        for package_name in $package_names
        do
            if [[ $package_name == http*.deb ]]
            then
                local local_file="/tmp/$(basename $package_name)"
                local local_name=$(basename $package_name | cut -d '_' -f 1)

                if ! dpkg --list | grep -q $local_name
                then
                    wget -O $local_file $package_name

                    dpkg -i $local_file
                fi
            elif ! apt list --installed 2> /dev/null | grep -q $package_name
            then
                apt install $package_name --yes
            fi
        done
    fi

    log_info "$package_names instalado com sucesso"
}

function install_from_dotnet()
{
    local remote_url="$1"
    local remote_file="$2"
    local extract_dir="$3"
    local install_dir="$4"
    local binary_file="$5"

    local binary_name=$(basename $binary_file)

    if binary_exists $binary_file
    then
        log_info "$binary_name ja instalado -> $remote_url"
    else
        download_data $remote_url $remote_file $extract_dir $install_dir

        dotnet build $install_dir

        create_local_link $binary_file

        change_owner "$binary_file"

        log_info "$binary_name instalado com sucesso"
    fi
}

function install_from_flatpak()
{
    local binary_name="$1"
    local package_name="$2"

    if binary_exists $binary_name
    then
        log_info "$binary_name ja instalado -> $package_name"
    else
        sudo --user $SUDO_USER --set-home --shell flatpak install --assumeyes flathub $package_name

        create_local_binary $binary_name "
            set -- flatpak run $package_name \$@

            exec \$@
        "

        log_info "$binary_name instalado com sucesso"
    fi
}

function install_from_go()
{
    local binary_name="$1"
    local package_name="$2"

    if binary_exists $binary_name
    then
        log_info "$binary_name ja instalado -> $package_name"
    else
        sudo --user $SUDO_USER --set-home --shell go install "$package_name"

        log_info "$binary_name instalado com sucesso"
    fi
}

function install_from_node()
{
    local binary_name="$1"
    local package_name="$2"

    if binary_exists $binary_name
    then
        log_info "$binary_name ja instalado -> $package_name"
    else
        sudo --user $SUDO_USER --set-home --shell npm install --global "$package_name"

        log_info "$binary_name instalado com sucesso"
    fi
}

function install_from_python()
{
    local binary_name="$1"
    local package_name="$2"

    if binary_exists $binary_name
    then
        log_info "$binary_name ja instalado -> $package_name"
    else
        python -m pip install $package_name

        log_info "$package_name instalado com sucesso"
    fi
}

function install_from_rust()
{
    local binary_name="$1"
    local package_name="$2"

    if binary_exists $binary_name
    then
        log_info "$binary_name ja instalado -> $package_name"
    else
        sudo --user $SUDO_USER --set-home --shell cargo install $package_name

        log_info "$package_name instalado com sucesso"
    fi
}

function install_from_remote()
{
    local remote_url="$1"
    local remote_file="$2"
    local extract_dir="$3"
    local install_dir="$4"
    local binary_file="$5"

    local binary_name=$(basename $binary_file)

    if binary_exists $binary_name
    then
        log_info "$binary_name ja instalado -> $remote_url"
    else
        download_data $remote_url $remote_file $extract_dir $install_dir

        create_local_link $binary_file

        change_owner "$binary_file"

        log_info "$binary_name instalado com sucesso"
    fi
}

function install_from_script()
{
    local remote_file="$1"
    shift 1
    local local_file="$1"
    shift 1
    local binary_file="$1"
    shift 1
    local install_args="$@"

    local binary_name=$(basename $binary_file)

    if binary_exists $binary_name
    then
        log_info "$binary_name ja instalado -> $remote_file $install_args"
    else
        mkdir -p $(dirname $local_file)

        curl "$remote_file" --location --output "$local_file"

        chmod +x $local_file

        set -- $local_file $install_args

        $SHELL "$@"

        create_local_link $binary_file

        change_owner "$binary_file"

        log_info "$binary_name instalado com sucesso"
    fi
}

function install_theme()
{
    local theme_name="$1"
    local remote_url="$2"
    local remote_file="$3"
    local extract_dir="$4"

    local theme_dir="/home/$SUDO_USER/.themes"
    local install_dir="$theme_dir/$theme_name"

    if [ -d $install_dir ]
    then
        log_info "$theme_name ja instalado -> $remote_url"
    else
        download_data $remote_url $remote_file $extract_dir $install_dir

        change_owner "$theme_dir"

        local variables=("DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus")

        sudo --user $SUDO_USER --set-home --shell env "${variables[@]}" gsettings set org.gnome.desktop.interface gtk-theme "$theme_name"
        sudo --user $SUDO_USER --set-home --shell env "${variables[@]}" gsettings set org.gnome.desktop.wm.preferences theme "$theme_name"

        sudo --user $SUDO_USER --set-home --shell flatpak override --user --filesystem=$theme_dir
        sudo --user $SUDO_USER --set-home --shell flatpak override --user --env=GTK_THEME=$theme_name

        log_info "$theme_name instalado com sucesso"
    fi
}
