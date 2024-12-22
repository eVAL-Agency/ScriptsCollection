# scriptlet: checks/os/os_like.sh

##
# Install SteamCMD
function install_steamcmd() {
	echo "Installing SteamCMD..."

	TYPE_DEBIAN="$(os_like_debian)"
	TYPE_UBUNTU="$(os_like_ubuntu)"

	# Create a "steam" user account
	# This will create the account with no password, so if you need to log in with this user,
	# run `sudo passwd steam` to set a password.
	if [ -z "$(getent passwd steam)" ]; then
		useradd -m -U steam
	fi

	# Preliminary requirements
	if [ "$TYPE_UBUNTU" == 1 ]; then
		add-apt-repository multiverse
		dpkg --add-architecture i386
		apt update
		apt install -y steamcmd
	elif [ "$TYPE_DEBIAN" == 1 ]; then
		dpkg --add-architecture i386
		apt update
		apt install -y software-properties-common apt-transport-https dirmngr ca-certificates lib32gcc-s1

		# Enable "non-free" repos for Debian (for steamcmd)
		# https://stackoverflow.com/questions/76688863/apt-add-repository-doesnt-work-on-debian-12
		add-apt-repository -y -U http://deb.debian.org/debian -c non-free-firmware -c non-free

		# Install steam repo
		curl -s http://repo.steampowered.com/steam/archive/stable/steam.gpg > /usr/share/keyrings/steam.gpg
		echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/steam.gpg] http://repo.steampowered.com/steam/ stable steam" > /etc/apt/sources.list.d/steam.list

		# Install steam binary and steamcmd
		apt update
		apt install -y steamcmd
	else
		echo 'Unsupported or unknown OS' >&2
		exit 1
	fi
}
