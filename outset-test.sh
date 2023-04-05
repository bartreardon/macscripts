#!/bin/bash
folder_root="/usr/local/outset"
folders=(
    login-every
    login-privileged-once
    on-demand
    boot-every
    login-once
    login-window
    boot-once
    login-privileged-every
) 

for folder in "${folders[@]}"
do
    if [[ ! -e "${folder_root}/${folder}" ]]; then
        mkdir -p "${folder_root}/${folder}"
    fi
    cat <<EOF > "${folder_root}/${folder}/${folder}-test.sh"
#!/bin/sh

echo "running \$0"
EOF
    chmod 755 "${folder_root}/${folder}/${folder}-test.sh"
    chown root "${folder_root}/${folder}/${folder}-test.sh"
done

# enable verbose debugging
defaults write /Library/Preferences/io.macadmins.Outset.plist verbose_logging -bool true