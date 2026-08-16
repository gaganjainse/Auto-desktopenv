# This script is meant to be sourced.
# It's not for directly running.

install-yay(){
  x sudo pacman -S --needed --noconfirm base-devel
  x git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay
  x cd /tmp/buildyay
  x makepkg -o
  x makepkg -se
  x makepkg -i --noconfirm
  x cd ${REPO_ROOT}
  rm -rf /tmp/buildyay
}

remove_deprecated_dependencies(){
  printf "${STY_CYAN}[$0]: Removing deprecated dependencies (dependency-safe):${STY_RST}\n"
  local list=()
  list+=(illogical-impulse-{microtex,pymyc-aur,oneui4-icons-git})
  list+=(hyprland-qtutils)
  list+=({quickshell,hyprutils,hyprpicker,hyprlang,hypridle,hyprland-qt-support,hyprland-qtutils,hyprlock,xdg-desktop-portal-hyprland,hyprcursor,hyprwayland-scanner,hyprland}-git)
  list+=(matugen-bin)
  local pkg
  for pkg in "${list[@]}"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      if sudo pacman -Rns --noconfirm "$pkg"; then
        printf "${STY_GREEN}[$0]: Removed deprecated package: %s${STY_RST}\n" "$pkg"
      else
        printf "${STY_YELLOW}[$0]: Could not remove %s safely because installed dependencies still require it; leaving it in place.${STY_RST}\n" "$pkg"
      fi
    fi
  done
}

implicitize_old_dependencies(){
  remove_bashcomments_emptylines ./sdata/dist-arch/previous_dependencies.conf ./cache/old_deps_stripped.conf
  readarray -t old_deps_list < ./cache/old_deps_stripped.conf
  pacman -Qeq > ./cache/pacman_explicit_packages
  readarray -t explicitly_installed < ./cache/pacman_explicit_packages

  echo "Attempting to set previously explicitly installed deps as implicit..."
  for i in "${explicitly_installed[@]}"; do
    for j in "${old_deps_list[@]}"; do
      if [[ "$i" == "$j" ]]; then
        if ! yay -D --asdeps "$i"; then
          log_warning "Could not mark $i as a dependency; leaving package metadata unchanged."
        fi
      fi
    done
  done
}

if ! command -v pacman >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: pacman not found; this installer requires Arch/pacman. Aborting...${STY_RST}\n"
  exit 1
fi

if [[ -z "${PACMAN_AUTH:-}" ]]; then
  export PACMAN_AUTH="sudo"
fi

showfun remove_deprecated_dependencies
v remove_deprecated_dependencies

case $SKIP_SYSUPDATE in
  true) true;;
  *) v sudo pacman -Syu;;
esac

if ! command -v yay >/dev/null 2>&1; then
  echo -e "${STY_YELLOW}[$0]: yay not found.${STY_RST}"
  showfun install-yay
  v install-yay
fi

showfun implicitize_old_dependencies
v implicitize_old_dependencies

install-local-pkgbuild() {
  local location=$1
  local installflags=$2

  x pushd "$location"
  source ./PKGBUILD
  x yay -S --sudoloop $installflags --asdeps "${depends[@]}"
  x makepkg -Afsi --noconfirm
  x popd
}

metapkgs=(./sdata/dist-arch/illogical-impulse-{audio,backlight,basic,fonts-themes,kde,portal,python,screencapture,toolkit,widgets})
metapkgs+=(./sdata/dist-arch/illogical-impulse-hyprland)
metapkgs+=(./sdata/dist-arch/illogical-impulse-microtex-git)
metapkgs+=(./sdata/dist-arch/illogical-impulse-quickshell-git)
metapkgs+=(./sdata/dist-arch/illogical-impulse-bibata-modern-classic-bin)

for i in "${metapkgs[@]}"; do
  metainstallflags="--needed"
  $ask && showfun install-local-pkgbuild || metainstallflags="$metainstallflags --noconfirm"
  v install-local-pkgbuild "$i" "$metainstallflags"
done

v sudo pacman -S --needed --noconfirm sddm
if pacman -Qs ^plasma-browser-integration$ ; then
  SKIP_PLASMAINTG=true
fi
case $SKIP_PLASMAINTG in
  true) true;;
  *)
    if $ask; then
      echo -e "${STY_YELLOW}[$0]: plasma-browser-integration is optional and can add KDE dependencies.${STY_RST}"
      echo -e "${STY_YELLOW}Install it? [y/N]${STY_RST}"
      read -r -p "====> " p
    else
      p=y
    fi
    case $p in
      y) x sudo pacman -S --needed --noconfirm plasma-browser-integration ;;
      *) echo "Ok, won't install" ;;
    esac
    ;;
esac
