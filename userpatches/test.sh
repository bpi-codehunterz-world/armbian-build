#!/bin/bash
# test.sh


install() {
	local distro=$1
  	local release=$2

	if [[ -z "$distro" || -z "$release" ]]; then
    	echo "Usage: install <distro> <release>"
    	echo "Distro: debian, ubuntu"
		echo "Release-Debian: stretch, buster, bullseye, bookworm, trixie, sid"
		echo "Release-Ubuntu: xenial, bionic, focal, jammy, noble"
    	return 1
  	fi

	case $release in
	  stretch|buster|bullseye|bookworm|trixie|sid)
	  	packages_file="./packages_files/$distro/$release.txt"
	  	install_packages "${packages_file}"
		;;
		*)
		echo "Invalid Release!"
		return 1
		;;

	esac
}

install_packages() {
  local package_file=$1

  # Überprüfen, ob die Datei existiert
  if [[ ! -f "$package_file" ]]; then
    echo "Datei $package_file nicht gefunden!"
    return 1
  fi

  # Pakete aus der Datei einlesen und installieren
  while IFS= read -r package; do
    if [[ -n "$package" ]]; then
      echo "Installiere $package..."
      sudo apt-get install -y "$package"
    fi
  done < "$package_file"
}


install "debian" "bullseye"
