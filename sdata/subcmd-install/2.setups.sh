# This script is meant to be sourced.
# It's not for directly running.

function prepare_systemd_user_service(){
  if [[ ! -e "/usr/lib/systemd/user/ydotool.service" ]]; then
    x sudo ln -s /usr/lib/systemd/{system,user}/ydotool.service
  fi
}

function setup_user_group(){
  if [[ -z $(getent group i2c) ]] && [[ "$OS_GROUP_ID" != "fedora" ]]; then
    # On Fedora this is not needed. Tested with desktop computer with NVIDIA video card.
    x sudo groupadd i2c
  fi

  if [[ "$OS_GROUP_ID" == "fedora" ]]; then
    x sudo usermod -aG video,input "$(whoami)"
  else
    x sudo usermod -aG video,i2c,input "$(whoami)"
  fi
}
#####################################################################################
# These python packages are installed using uv into the venv (virtual environment). Once the folder of the venv gets deleted, they are all gone cleanly. So it's considered as setups, not dependencies.
showfun install-python-packages
v install-python-packages

showfun setup_user_group
v setup_user_group

if [[ ! -z $(systemctl --version) ]]; then
  # For Fedora, uinput is required for the virtual keyboard to function, and udev rules enable input group users to utilize it.
  if [[ "$OS_GROUP_ID" == "fedora" ]]; then
    v bash -c "echo uinput | sudo tee /etc/modules-load.d/uinput.conf"
    v bash -c 'echo SUBSYSTEM==\"misc\", KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"input\" | sudo tee /etc/udev/rules.d/99-uinput.rules'
  else
    v bash -c "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf"
  fi
  # TODO: find a proper way for enable Nix installed ydotool. When running `systemctl --user enable ydotool, it errors "Failed to enable unit: Unit ydotool.service does not exist".
  if [[ ! "${INSTALL_VIA_NIX}" == true ]]; then
    if [[ "$OS_GROUP_ID" == "fedora" ]]; then
      v prepare_systemd_user_service
    fi
    # When $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR are empty, it commonly means that the current user has been logged in with `su - user` or `ssh user@hostname`. In such case `systemctl --user enable <service>` is not usable. It should be `sudo systemctl --machine=$(whoami)@.host --user enable <service>` instead.
    if [[ ! -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
      v systemctl --user enable ydotool --now
    else
      v sudo systemctl --machine=$(whoami)@.host --user enable ydotool --now
    fi
  fi
  v sudo systemctl enable bluetooth --now
elif [[ ! -z $(openrc --version) ]]; then
  v bash -c "echo 'modules=i2c-dev' | sudo tee -a /etc/conf.d/modules"
  v sudo rc-update add modules boot
  v sudo rc-update add ydotool default
  v sudo rc-update add bluetooth default

  x sudo rc-service ydotool start
  x sudo rc-service bluetooth start
else
  printf "${STY_RED}"
  printf "====================INIT SYSTEM NOT FOUND====================\n"
  printf "${STY_RST}"
  pause
fi

if [[ "$OS_GROUP_ID" == "gentoo" ]]; then
  v sudo chown -R $(whoami):$(whoami) ~/.local/
fi

v gsettings set org.gnome.desktop.interface font-name 'Google Sans Flex Medium 11 @opsz=11,wght=500'
v gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
v kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly

#####################################################################################
# MSI MUX Switcher
showfun setup_mux_switcher
v setup_mux_switcher

function setup_mux_switcher(){
  local mux_dir="${REPO_ROOT}/tools/mux-switcher"
  local mux_bin="${XDG_BIN_HOME}/mux-switcher"

  if [[ ! -d "$mux_dir" ]]; then
    printf "${STY_YELLOW}[$0]: mux-switcher not found at $mux_dir${STY_RST}\n"
    return 0
  fi

  if [[ -f /sys/class/dmi/id/product_name ]] && \
     grep -qi "MSI" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
    printf "${STY_CYAN}[$0]: MSI laptop detected, setting up MUX switcher${STY_RST}\n"
    v mkdir -p "$XDG_BIN_HOME"
    v ln -sf "${mux_dir}/mux-switcher.sh" "$mux_bin"
    v chmod +x "$mux_bin"
    printf "${STY_GREEN}[$0]: MUX switcher installed at $mux_bin${STY_RST}\n"
    printf "  Run: sudo mux-switcher status\n"
  else
    printf "${STY_YELLOW}[$0]: Not an MSI laptop, skipping MUX switcher${STY_RST}\n"
  fi
}

#####################################################################################
# Smart Organizer
if [[ ! "${SKIP_SMART_ORGANIZER:-}" == true ]]; then
  showfun setup_smart_organizer
  v setup_smart_organizer
fi

function setup_smart_organizer(){
  local organizer_dir="${REPO_ROOT}/tools/smart-organizer"
  local organizer_bin="${XDG_BIN_HOME}/smart-organizer"

  if [[ ! -d "$organizer_dir" ]]; then
    printf "${STY_YELLOW}[$0]: smart-organizer not found at $organizer_dir${STY_RST}\n"
    return 0
  fi

  printf "${STY_CYAN}[$0]: Setting up Smart Organizer${STY_RST}\n"
  v mkdir -p "$XDG_BIN_HOME"
  v ln -sf "${organizer_dir}/smart-organizer.sh" "$organizer_bin"
  v chmod +x "$organizer_bin"

  # Install systemd user service for watch mode
  v mkdir -p "${XDG_CONFIG_HOME}/systemd/user"
  v bash -c "cat > '${XDG_CONFIG_HOME}/systemd/user/smart-organizer.service' << EOFSERVICE
[Unit]
Description=Smart Organizer Watch Service
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/smart-organizer --watch
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOFSERVICE"

  v systemctl --user daemon-reload
  v systemctl --user enable --now smart-organizer.service || true

  printf "${STY_GREEN}[$0]: Smart Organizer installed successfully!${STY_RST}\n"
  printf "  Run: smart-organizer --dry-run\n"
  printf "  Run: smart-organizer --clean system\n"
  printf "  Service: systemctl --user status smart-organizer\n"
}
