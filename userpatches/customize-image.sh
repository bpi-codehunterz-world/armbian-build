#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# Author:  hexzhen3x7
# Version: 2.0
# Website: https://codehunterz.world
# Github:  https://github.com/bpi-codehunterz-world/armbian-firmware-builder
# Description: This repository is made for building Armbian for Banana Pi's !"

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

BLACK='\e[0;30m'
WHITE='\e[0;37m'
RED='\e[0;31m'
BLUE='\e[0;34m'
YELLOW='\e[0;33m'
GREEN='\e[0;32m'
PURPLE='\e[0;35m'
CYAN='\e[0;36m'
NC='\033[0m'


install_docker_debian() {
	# Add Docker's official GPG key:
	sudo apt-get update
	sudo apt-get install ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
  	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  	$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
}

install_docker_ubuntu() {
	# Add Docker's official GPG key:
	sudo apt-get update
	sudo apt-get install ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
  	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  	$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

}

install_portainer() {
	docker volume create portainer_data
	docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:2.21.4
}

install() {
	local distro=$1
  	local release=$2

	if [[ -z "$distro" || -z "$release" ]]; then
    	echo "Usage: install <distro> <release>"
    	echo "Distro: debian, ubuntu"
		echo "Release-Debian: stretch, buster, bullseye, bookworm, trixie, sid"
		echo "Release-Ubuntu: xenial, bionic, focal, jammy, noble"
		echo "Release-Both: default"
    	return 1
  	fi

	case $release in
	  stretch|buster|bullseye|bookworm|trixie|sid|xenial|bionic|focal|jammy|noble)
	  	packages_file="/tmp/overlay/packages_files/$distro/$release.txt"
	  	install_packages "${packages_file}"
		;;
      default)
	    packages_file="/tmp/overlay/packages_files/$release.txt"
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

  echo -e "${RED}Console > ${NC}${CYAN} Installing APT-Packages!"

  if [[ ! -f "$package_file" ]]; then
    echo "File $package_file not found!"
    return 1
  fi
  while IFS= read -r package; do
    if [[ -n "$package" ]]; then
      echo "installing $package..."
      sudo apt-get install -y "$package"
    fi
  done < "$package_file"
}


git_repos() {
    echo -e "${RED}Console > ${NC}${CYAN} Cloning Git-Repoisotrys!"

  	git_repos="/tmp/overlay/git_repos/repos.txt"
  	if [ ! -f "$git_repos" ]; then
	    echo "$git_repos does not exist."
	    exit 1
	fi

	while IFS= read -r repo; do
	    echo "Cloning $repo..."
		mkdir -p /root/libarys
		cd /root/libarys
	    git clone "$repo"
	done < "$git_repos"
}


manage_service() {
  local scriptname=$1
  local option=$2

  if [[ -z "$scriptname" || -z "$option" ]]; then
    echo "Usage: manage_service <scriptname> <option>"
    echo "Options: defaults, remove, disable, enable"
    return 1
  fi

  case $option in
    defaults|remove|disable|enable)
      sudo update-rc.d "$scriptname" "$option"
      ;;
    *)
      echo "Invalid option: $option"
      echo "Options: defaults, remove, disable, enable"
      return 1
      ;;
  esac
}


copy_overlay() {
		echo -e "${RED}INFO > COPYING OVERLAY TO ROOTFS!${NC}"
        dirs=("/var/lib" "/usr/local/bin")
		for dir in "${dirs[@]}"; do
		  mkdir -p "$dir"
		done

	    cp -r /tmp/overlay/bananapi /var/lib/
		cp -r /tmp/overlay/scripts/set_led_trigger.sh /etc/init.d/set_led_trigger.sh

		paths=("/var/lib/bananapi" "/etc/init.d/set_led_trigger.sh")

		for path in "${paths[@]}"; do
		  chmod 777 -R "$path"
		done

		manage_service "set_led_trigger.sh" "defaults"
}



clone_repositorys() {
	mkdir -p /usr/share/libarys
	cd /usr/share/libarys

	git clone https://github.com/bpi-codehunterz-world/RPi.GPIO
	sleep 2
	git clone https://github.com/bpi-codehunterz-world/BPI-WiringPi2
	sleep 2
	git clone https://github.com/bpi-codehunterz-world/BPI-WiringPi2-Python
	sleep 2

	chmod 777 -R ../**

	echo -e "INFO: Installing BPI-WiringPi2!"
	cd BPI-WiringPi2
	./build
	echo -e "/usr/local/lib" >> /etc/ld.so.conf
	ldconfig
	cd wiringPi
  	make static
  	make install-static

	sleep 2

	cd ..
	cd ..
	echo -e "INFO: Installing RPi.GPIO!"
    cd RPi.GPIO
	python3 setup.py install
	pip3 install .

	sleep 2

	cd ..
	echo -e "INFO: Installing BPI-WiringPi2-Python!"
	cd BPI-WiringPi2-Python
	swig -python wiringpi.i
	python3 setup.py build install
	cd ..

	git_repos;
 }





build() {
    apt-get update;
    install "default";
	copy_overlay;
	clone_repositorys;
	install_docker_ubuntu
	install_portainer

}

build_xenial() {
    apt-get update;

    install "ubuntu" "xenial";
	copy_overlay;
	clone_repositorys;

	install_docker_ubuntu
	install_portainer
}

build_bionic() {
	apt-get update;

    install "ubuntu" "bionic";
	copy_overlay;
	clone_repositorys;

	install_docker_ubuntu
	install_portainer
}

build_focal() {
	apt-get update;

    install "ubuntu" "focal";
	copy_overlay;
	clone_repositorys;

	install_docker_ubuntu
	install_portainer
}

build_jammy() {
	apt-get update;

    install "ubuntu" "jammy";
	copy_overlay;
	clone_repositorys;

	install_docker_ubuntu
	install_portainer
}

build_noble() {
	apt-get update;

    install "ubuntu" "noble";
	copy_overlay;
	clone_repositorys;

	install_docker_ubuntu
	install_portainer
}

build_stretch() {
	apt-get update;

    install "debian" "stretch";
	copy_overlay;
	clone_repositorys;

	install_docker_debian
	install_portainer
}

build_buster() {
	apt-get update;

    install "debian" "buster";
	copy_overlay;
	clone_repositorys;

	install_docker_debian
	install_portainer
}

build_bullseye() {
	apt-get update;
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93D6889F9F0E78D5
    wget -qO - https://armbian.github.io/configng/KEY.gpg | sudo apt-key add -
	gpg --export 93D6889F9F0E78D5 | sudo tee /etc/apt/trusted.gpg.d/armbian.gpg
	apt-key net-update
	apt-key update
	apt-get update;

    install "debian" "bullseye";
	copy_overlay;
	clone_repositorys;

	install_docker_debian
	install_portainer

}

build_bookworm() {
    apt-get update;

    install "debian" "bookworm";
	copy_overlay;
	clone_repositorys;

	install_docker_debian
	install_portainer
}

build_trixie() {
    apt-get update;

    install "debian" "trixie";
	copy_overlay;
	clone_repositorys;

	install_docker_debian
	install_portainer

}

build_sid() {
    apt-get update;

    install "debian" "sid";
	copy_overlay;
	clone_repositorys;

	install_docker_debian
	install_portainer

}





Main() {
	case $RELEASE in
		stretch)
			build_stretch;
			;;
		buster)
			build_buster;
			;;
		jammy)
			build_jammy;
			;;
		xenial)
			build_xenial;
			;;
		bookworm)
			build_bookworm;
			;;
		bullseye)
			build_bullseye;
			;;
		bionic)
			build_bionic;
			;;
		focal)
			build_focal;
			;;
		noble)
			build_noble;
			;;
	esac
}

InstallOpenMediaVault() {
	echo root:openmediavault | chpasswd
	rm /root/.not_logged_in_yet
	. /etc/default/cpufrequtils
	export LANG=C LC_ALL="en_US.UTF-8"
	export DEBIAN_FRONTEND=noninteractive
	export APT_LISTCHANGES_FRONTEND=none
	case ${RELEASE} in
		jessie)
			OMV_Name="erasmus"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all3.deb"
			;;
		stretch)
			OMV_Name="arrakis"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all4.deb"
			;;
	esac
	cat > /etc/apt/sources.list.d/openmediavault.list <<- EOF
	deb https://openmediavault.github.io/packages/ ${OMV_Name} main
	## Uncomment the following line to add software from the proposed repository.
	deb https://openmediavault.github.io/packages/ ${OMV_Name}-proposed main

	## This software is not part of OpenMediaVault, but is offered by third-party
	## developers as a service to OpenMediaVault users.
	# deb https://openmediavault.github.io/packages/ ${OMV_Name} partner
	EOF

	if [ "${BOARD}" = "odroidxu4" ]; then
		add-apt-repository -y ppa:kyle1117/ppa
		sed -i 's/jessie/xenial/' /etc/apt/sources.list.d/kyle1117-ppa-jessie.list
	fi
	mount --bind /dev/null /proc/mdstat
	apt-get update
	apt-get --yes --force-yes --allow-unauthenticated install openmediavault-keyring
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7AA630A1EDEE7D73
	apt-get update
	HOSTNAME="${BOARD}"
	debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME}"
	debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No configuration'"
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		debconf-utils postfix
	cp -p /usr/bin/newaliases /usr/bin/newaliases.bak && ln -sf /bin/true /usr/bin/newaliases
	sed -i -e "s/^::1         localhost.*/::1         ${HOSTNAME} localhost ip6-localhost ip6-loopback/" \
		-e "s/^127.0.0.1   localhost.*/127.0.0.1   ${HOSTNAME} localhost/" /etc/hosts
	sed -i -e "s/^mydestination =.*/mydestination = ${HOSTNAME}, localhost.localdomain, localhost/" \
		-e "s/^myhostname =.*/myhostname = ${HOSTNAME}/" /etc/postfix/main.cf
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		openmediavault
	FILE=$(mktemp)
	wget "$OMV_EXTRAS_URL" -qO $FILE && dpkg -i $FILE

	/usr/sbin/omv-update
	. /usr/share/openmediavault/scripts/helper-functions
	apt-get -y -q install openmediavault-netatalk openmediavault-flashmemory
	AFP_Options="mimic model = Macmini"
	SMB_Options="min receivefile size = 16384\nwrite cache size = 524288\ngetwd cache = yes\nsocket options = TCP_NODELAY IPTOS_LOWDELAY"
	xmlstarlet ed -L -u "/config/services/afp/extraoptions" -v "$(echo -e "${AFP_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/smb/extraoptions" -v "$(echo -e "${SMB_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/flashmemory/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/permitrootlogin" -v "0" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/ntp/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "UTC" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/network/dns/hostname" -v "${HOSTNAME}" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/monitoring/perfstats/enable" -v "0" /etc/openmediavault/config.xml
	echo -e "OMV_CPUFREQUTILS_GOVERNOR=${GOVERNOR}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MINSPEED=${MIN_SPEED}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MAXSPEED=${MAX_SPEED}" >>/etc/default/openmediavault
	for i in netatalk samba flashmemory ssh ntp timezone interfaces cpufrequtils monit collectd rrdcached ; do
		/usr/sbin/omv-mkconf $i
	done
	/sbin/folder2ram -enablesystemd || true
	sed -i 's|-j /var/lib/rrdcached/journal/ ||' /etc/init.d/rrdcached
	sed -i '/stretch-backports/d' /etc/apt/sources.list
	echo 15500000s >/root/.rootfs_resize
	sed -i '/systemctl\ disable\ armbian-firstrun/i \
	mv /usr/bin/newaliases.bak /usr/bin/newaliases \
	export DEBIAN_FRONTEND=noninteractive \
	sleep 3 \
	apt-get install -f -qq python-pip python-setuptools || exit 0 \
	pip install -U tzupdate \
	tzupdate \
	read TZ </etc/timezone \
	/usr/sbin/omv-initsystem \
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "${TZ}" /etc/openmediavault/config.xml \
	/usr/sbin/omv-mkconf timezone \
	lsusb | egrep -q "0b95:1790|0b95:178a|0df6:0072" || sed -i "/ax88179_178a/d" /etc/modules' /usr/lib/armbian/armbian-firstrun
	sed -i '/systemctl\ disable\ armbian-firstrun/a \
	sleep 30 && sync && reboot' /usr/lib/armbian/armbian-firstrun
	echo -e "r8152\nax88179_178a" >>/etc/modules
	case ${BOARD} in
		odroidxu4)
			HMP_Fix='; taskset -c -p 4-7 $i '
			echo "H4sIAKdXHVkCA7WQXWuDMBiFr+eveOe6FcbSrEIH3WihWx0rtVbUFQqCqAkYGhJn
			tF1x/vep+7oebDfh5DmHwJOzUxwzgeNIpRp9zWRegDPznya4VDlWTXXbpS58XJtD
			i7ICmFBFxDmgI6AXSLgsiUop54gnBC40rkoVA9rDG0SHHaBHPQx16GN3Zs/XqxBD
			leVMFNAz6n6zSWlEAIlhEw8p4xTyFtwBkdoJTVIJ+sz3Xa9iZEMFkXk9mQT6cGSQ
			QL+Cr8rJJSmTouuuRzfDtluarm1aLVHksgWmvanm5sbfOmY3JEztWu5tV9bCXn4S
			HB8RIzjoUbGvFvPw/tmr0UMr6bWSBupVrulY2xp9T1bruWnVga7DdAqYFgkuCd3j
			vORUDQgej9HPJxmDDv+3WxblBSuYFH8oiNpHz8XvPIkU9B3JVCJ/awIAAA==" \
			| tr -d '[:blank:]' | base64 --decode | gunzip -c >/usr/local/sbin/cloudshell2-support.sh
			chmod 755 /usr/local/sbin/cloudshell2-support.sh
			apt install -y i2c-tools odroid-cloudshell cloudshell2-fan
			sed -i '/systemctl\ disable\ armbian-firstrun/i \
			lsusb | grep -q -i "05e3:0735" && sed -i "/exit\ 0/i echo 20 > /sys/class/block/sda/queue/max_sectors_kb" /etc/rc.local \
			/usr/sbin/i2cdetect -y 1 | grep -q "60: 60" && /usr/local/sbin/cloudshell2-support.sh' /usr/lib/armbian/armbian-firstrun
			;;
		bananapim3)
			HMP_Fix='; taskset -c -p 4-7 $i '
			;;
		edge*|ficus|firefly-rk3399|nanopct4|nanopim4|nanopineo4|renegade-elite|roc-rk3399-pc|rockpro64|station-p1)
			HMP_Fix='; taskset -c -p 4-5 $i '
			;;
	esac
	echo "* * * * * root for i in \`pgrep \"ftpd|nfsiod|smbd|afpd|cnid\"\` ; do ionice -c1 -p \$i ${HMP_Fix}; done >/dev/null 2>&1" \
		>/etc/cron.d/make_nas_processes_faster
	chmod 600 /etc/cron.d/make_nas_processes_faster
	[ "${LINUXFAMILY}" = "sunxi" ] && \
		echo -e "#\n# If you want to use a SATA PM add \"ahci_sunxi.enable_pmp=1\" to bootargs above" \
		>>/boot/boot.cmd
	echo ':msg, contains, "do ionice -c1" ~' >/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "action " ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "netsnmp_assert" ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "Failed to initiate sched scan" ~' >>/etc/rsyslog.d/omv-armbian.conf

	if [ -f /usr/lib/python3.5/weakref.py ]; then
		wget -O /usr/lib/python3.5/weakref.py \
		https://raw.githubusercontent.com/python/cpython/9cd7e17640a49635d1c1f8c2989578a8fc2c1de6/Lib/weakref.py
	fi
	umount /proc/mdstat
	chage -d 0 root
}

UnattendedStorageBenchmark() {
	rm /root/.not_logged_in_yet
	apt-get -qq install time
	wget -qO /usr/local/bin/sd-card-bench.sh https://raw.githubusercontent.com/ThomasKaiser/sbc-bench/master/sd-card-bench.sh
	chmod 755 /usr/local/bin/sd-card-bench.sh
	sed -i '/^exit\ 0$/i \
	/usr/local/bin/sd-card-bench.sh &' /etc/rc.local
}

InstallAdvancedDesktop()
{
	apt-get install -yy transmission libreoffice libreoffice-style-tango meld remmina thunderbird kazam avahi-daemon
	[[ -f /usr/share/doc/avahi-daemon/examples/sftp-ssh.service ]] && cp /usr/share/doc/avahi-daemon/examples/sftp-ssh.service /etc/avahi/services/
	[[ -f /usr/share/doc/avahi-daemon/examples/ssh.service ]] && cp /usr/share/doc/avahi-daemon/examples/ssh.service /etc/avahi/services/
	apt clean
}

Main "$@"
