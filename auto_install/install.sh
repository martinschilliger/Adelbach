#!/usr/bin/env bash

# Adelbach: Use your GoPro with a RaspberryPi for RTMP streaming – reliable
# Install script is heavily inspired by pi-hole.net and PiVPN. Thanks for the amazing work!
# Please see LICENSE file for your rights under this license.
#
#
# Install with this command (from your Pi):
#
# curl -L https://github.com/martinschilliger/Adelbach/raw/master/auto_install/install.sh | bash
# Make sure you have `curl` installed

# -e option instructs bash to immediately exit if any command [1] has a non-zero exit status
# We do not want users to end up with a partially working install, so we exit the script
# instead of continuing the installation with something broken
set -e
######## VARIABLES #########


######## TODO #########
# * Add keepalive and ffmpeg-streaming as a services => Done automatically??
# * reconnect on loss of connection

tmpLog="/tmp/adelbach-install.log"
instalLogLoc="/etc/adelbach/install.log"
setupVars=/etc/adelbach/setupVars.conf
useUpdateVars=false

### PKG Vars ###
PKG_MANAGER="apt-get"
PKG_CACHE="/var/lib/apt/lists/"
UPDATE_PKG_CACHE="${PKG_MANAGER} update"
PKG_INSTALL="${PKG_MANAGER} --yes --no-install-recommends install"
PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"
ADELBACH_DEPS=(git tar wget grep ffmpeg)
CONFIG_FILE_PATH="/etc/adelbach/streamer.conf"


adelbachGitUrl="https://github.com/martinschilliger/Adelbach.git"
adelbachFilesDir="/etc/.adelbach"

# Raspbian's unattended-upgrades package downloads Debian's config, so this is the link for the proper config
UNATTUPG_CONFIG="https://github.com/mvo5/unattended-upgrades/archive/1.4.tar.gz"

# Find the rows and columns. Will default to 80x24 if it can not be detected.
screen_size=$(stty size 2>/dev/null || echo 24 80)
rows=$(echo $screen_size | awk '{print $1}')
columns=$(echo $screen_size | awk '{print $2}')

# Divide by two so the dialogs take up half of the screen, which looks nice.
r=$(( rows / 2 ))
c=$(( columns / 2 ))
# Unless the screen is tiny
r=$(( r < 20 ? 20 : r ))
c=$(( c < 70 ? 70 : c ))

######## Undocumented Flags. Shhh ########
skipSpaceCheck=false
reconfigure=false
runUnattended=false

# Next see if we are on a tested and supported OS
function noOS_Support() {
    whiptail --msgbox --backtitle "INVALID OS DETECTED" --title "Invalid OS" "We have not been able to detect a supported OS.
Currently this installer should support Raspbian and Debian (Jessie and Stretch), Devuan (Jessie) and Ubuntu from 14.04 (trusty) to 17.04 (zesty).
If you think you received this message in error, you can post an issue on the GitHub at https://github.com/martinschilliger/Adelbach/issues." ${r} ${c}
    exit 1
}

function maybeOS_Support() {
    if (whiptail --backtitle "Not Supported OS" --title "Not Supported OS" --yesno "You are on an OS that we have not tested but MAY work.
Currently this installer should support Raspbian and Debian (Jessie and Stretch), Devuan (Jessie) and Ubuntu from 14.04 (trusty) to 17.04 (zesty).
Would you like to continue anyway?" ${r} ${c}) then
        echo "::: Did not detect perfectly supported OS but,"
        echo "::: Continuing installation at user's own risk..."
    else
        echo "::: Exiting due to unsupported OS"
        exit 1
    fi
}

# Compatibility
distro_check() {
    # if lsb_release command is on their system
    if hash lsb_release 2>/dev/null; then

        PLAT=$(lsb_release -si)
        OSCN=$(lsb_release -sc) # We want this to be trusty xenial or jessie

    else # else get info from os-release

        source /etc/os-release
        PLAT=$(awk '{print $1}' <<< "$NAME")
        VER="$VERSION_ID"
        declare -A VER_MAP=(["9"]="stretch" ["8"]="jessie" ["18.04"]="bionic" ["16.04"]="xenial" ["14.04"]="trusty")
        OSCN=${VER_MAP["${VER}"]}
    fi

    if [[ ${OSCN} != "bionic" ]]; then
        ADELBACH_DEPS+=(dhcpcd5)
    fi

    case ${PLAT} in
        Ubuntu|Raspbian|Debian|Devuan)
        case ${OSCN} in
            trusty|xenial|jessie|stretch)
            ;;
            *)
            maybeOS_Support
            ;;
        esac
        ;;
        *)
        noOS_Support
        ;;
    esac

    echo "${PLAT}" > /tmp/DET_PLATFORM
}

####### FUNCTIONS ##########
spinner()
{
    local pid=$1
    local delay=0.50
    local spinstr='/-\|'
    while [ "$(ps a | awk '{print $1}' | grep "${pid}")" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "${spinstr}"
        local spinstr=${temp}${spinstr%"$temp"}
        sleep ${delay}
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

welcomeDialogs() {
    # Display the welcome dialog
    whiptail --msgbox --backtitle "Welcome" --title "Adelbach Automated Installer" "This installer will transform your Raspberry Pi into an GoPro-to-RTMP-Stream proxy!" ${r} ${c}
}

chooseUser() {
    # Explain the local user
    whiptail --msgbox --backtitle "Parsing User List" --title "Local Users" "Choose a local user that will hold your adelbach configurations." ${r} ${c}
    # First, let's check if there is a user available.
    numUsers=$(awk -F':' 'BEGIN {count=0} $3>=1000 && $3<=60000 { count++ } END{ print count }' /etc/passwd)
    if [ "$numUsers" -eq 0 ]
    then
        # We don't have a user, let's ask to add one.
        if userToAdd=$(whiptail --title "Choose A User" --inputbox "No non-root user account was found. Please type a new username." ${r} ${c} 3>&1 1>&2 2>&3)
        then
            # See http://askubuntu.com/a/667842/459815
            PASSWORD=$(whiptail  --title "password dialog" --passwordbox "Please enter the new user password" ${r} ${c} 3>&1 1>&2 2>&3)
            CRYPT=$(perl -e 'printf("%s\n", crypt($ARGV[0], "password"))' "${PASSWORD}")
            $SUDO useradd -m -p "${CRYPT}" -s /bin/bash "${userToAdd}"
            if [[ $? = 0 ]]; then
                echo "Succeeded"
                ((numUsers+=1))
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
    availableUsers=$(awk -F':' '$3>=1000 && $3<=60000 {print $1}' /etc/passwd)
    local userArray=()
    local firstloop=1

    while read -r line
    do
        mode="OFF"
        if [[ $firstloop -eq 1 ]]; then
            firstloop=0
            mode="ON"
        fi
        userArray+=("${line}" "" "${mode}")
    done <<< "${availableUsers}"
    chooseUserCmd=(whiptail --title "Choose A User" --separate-output --radiolist "Choose (press space to select):" ${r} ${c} ${numUsers})
    chooseUserOptions=$("${chooseUserCmd[@]}" "${userArray[@]}" 2>&1 >/dev/tty)
    if [[ $? = 0 ]]; then
        for desiredUser in ${chooseUserOptions}; do
            adelbachUser=${desiredUser}
            echo "::: Using User: $adelbachUser"
            echo "${adelbachUser}" > /tmp/adelbachUSR
        done
    else
        echo "::: Cancel selected, exiting...."
        exit 1
    fi
}

verifyFreeDiskSpace() {
    # If user installs unattended-upgrades we'd need about 60MB so will check for 75MB free
    echo "::: Verifying free disk space..."
    local required_free_kilobytes=76800
    local existing_free_kilobytes=$(df -Pk | grep -m1 '\/$' | awk '{print $4}')

    # - Unknown free disk space , not a integer
    if ! [[ "${existing_free_kilobytes}" =~ ^([0-9])+$ ]]; then
        echo "::: Unknown free disk space!"
        echo "::: We were unable to determine available free disk space on this system."
        echo "::: You may continue with the installation, however, it is not recommended."
        read -r -p "::: If you are sure you want to continue, type YES and press enter :: " response
        case $response in
            [Y][E][S])
                ;;
            *)
                echo "::: Confirmation not received, exiting..."
                exit 1
                ;;
        esac
    # - Insufficient free disk space
    elif [[ ${existing_free_kilobytes} -lt ${required_free_kilobytes} ]]; then
        echo "::: Insufficient Disk Space!"
        echo "::: Your system appears to be low on disk space. Adelbach recommends a minimum of $required_free_kilobytes KiloBytes."
        echo "::: You only have ${existing_free_kilobytes} KiloBytes free."
        echo "::: If this is a new install on a Raspberry Pi you may need to expand your disk."
        echo "::: Try running 'sudo raspi-config', and choose the 'expand file system option'"
        echo "::: After rebooting, run this installation again."

        echo "Insufficient free space, exiting..."
        exit 1
    fi
}


installScripts() {
    # Install the scripts from /etc/.adelbach to their various locations
    $SUDO echo ":::"
    $SUDO echo -n "::: Installing scripts to /opt/adelbach..."
    if [ ! -d /opt/adelbach ]; then
        $SUDO mkdir /opt/adelbach
        $SUDO chown "$adelbachUser":root /opt/adelbach
        $SUDO chmod u+srwx /opt/adelbach
    fi
    $SUDO cp /etc/.adelbach/scripts/streamer.sh /opt/adelbach/streamer.sh
    $SUDO chmod 0755 /opt/adelbach/streamer.sh
    $SUDO cp /etc/.adelbach/scripts/keepalive.sh /opt/adelbach/keepalive.sh
    $SUDO chmod 0755 /opt/adelbach/keepalive.sh
    $SUDO cp /etc/.adelbach/scripts/wifi_watchdog.sh /opt/adelbach/wifi_watchdog.sh
    $SUDO chmod 0755 /opt/adelbach/wifi_watchdog.sh
    $SUDO cp /etc/.adelbach/scripts/uninstall.sh /opt/adelbach/uninstall.sh
    $SUDO chmod 0755 /opt/adelbach/uninstall.sh

    $SUDO cp /etc/.adelbach/adelbach.sh /usr/local/bin/adelbach
    $SUDO chmod 0755 /usr/local/bin/adelbach

    $SUDO echo " done."
}

package_check_install() {
    dpkg-query -W -f='${Status}' "${1}" 2>/dev/null | grep -c "ok installed" || ${PKG_INSTALL} "${1}"
}

update_package_cache() {
  #Running apt-get update/upgrade with minimal output can cause some issues with
  #requiring user input

  #Check to see if apt-get update has already been run today
  #it needs to have been run at least once on new installs!
  timestamp=$(stat -c %Y ${PKG_CACHE})
  timestampAsDate=$(date -d @"${timestamp}" "+%b %e")
  today=$(date "+%b %e")


  if [ ! "${today}" == "${timestampAsDate}" ]; then
    #update package lists
    echo ":::"
    echo -n "::: ${PKG_MANAGER} update has not been run today. Running now..."
    $SUDO ${UPDATE_PKG_CACHE} &> /dev/null
    echo " done!"
  fi
}

notify_package_updates_available() {
  # Let user know if they have outdated packages on their system and
  # advise them to run a package update at soonest possible.
  echo ":::"
  echo -n "::: Checking ${PKG_MANAGER} for upgraded packages...."
  updatesToInstall=$(eval "${PKG_COUNT}")
  echo " done!"
  echo ":::"
  if [[ ${updatesToInstall} -eq "0" ]]; then
    echo "::: Your system is up to date! Continuing with Adelbach installation..."
  else
    echo "::: There are ${updatesToInstall} updates available for your system!"
    echo "::: We recommend you update your OS after installing Adelbach! "
    echo ":::"
  fi
}


unattendedUpgrades() {
    whiptail --msgbox --backtitle "Security Updates" --title "Unattended Upgrades" "Since this server will have at least one port open to the internet, it is recommended you enable unattended-upgrades.\nThis feature will check daily for security package updates only and apply them when necessary.\nIt will NOT automatically reboot the server so to fully apply some updates you should periodically reboot." ${r} ${c}

    if (whiptail --backtitle "Security Updates" --title "Unattended Upgrades" --yesno "Do you want to enable unattended upgrades of security patches to this server?" ${r} ${c}) then
        UNATTUPG="unattended-upgrades"
    else
        UNATTUPG=""
    fi
}

stopServices() {
    # Stop openvpn
    $SUDO echo ":::"
    $SUDO echo -n "::: Stopping Adelbach service..."
    case ${PLAT} in
        Ubuntu|Debian|*vuan)
            $SUDO service adelbach stop || true
            ;;
        *)
            $SUDO systemctl stop adelbach.service || true
            ;;
    esac
    $SUDO echo " done."
}

getGitFiles() {
    # Setup git repos for base files
    echo ":::"
    echo "::: Checking for existing base files..."
    if is_repo "${1}"; then
        update_repo "${1}"
    else
        make_repo "${1}" "${2}"
    fi
}

is_repo() {
    # If the directory does not have a .git folder it is not a repo
    echo -n ":::    Checking $1 is a repo..."
    cd "${1}" &> /dev/null || return 1
    $SUDO git status &> /dev/null && echo " OK!"; return 0 || echo " not found!"; return 1
}

make_repo() {
    # Remove the non-repos interface and clone the interface
    echo -n ":::    Cloning $2 into $1..."
    $SUDO rm -rf "${1}"
    $SUDO git clone -q "${2}" "${1}" > /dev/null & spinner $!
    if [ -z "${TESTING+x}" ]; then
        :
    else
        $SUDO git -C "${1}" checkout test
    fi
    echo " done!"
}

update_repo() {
    if [[ "${reconfigure}" == true ]]; then
          echo "::: --reconfigure passed to install script. Not downloading/updating local repos"
    else
        # Pull the latest commits
        echo -n ":::     Updating repo in $1..."
        cd "${1}" || exit 1
        $SUDO git stash -q > /dev/null & spinner $!
        $SUDO git pull -q > /dev/null & spinner $!
        if [ -z "${TESTING+x}" ]; then
            :
        else
            ${SUDOE} git checkout test
        fi
        echo " done!"
    fi
}

writeConfig(){
  # writeConfig TARGET_KEY REPLACEMENT_VALUE
    $SUDO sed -i "" "s/\(${1} *= *\).*/\1${2}/" $CONFIG_FILE_PATH
}

confAdelbach(){
  # Load settings
  source $CONFIG_FILE_PATH

  # Streaming URL and KEY
  if NEW_SERVER_URL=$(whiptail --title "Enter the server URL" --inputbox "Enter the URL of the server, starting with \"rtmp://\"." ${r} ${c} $SERVER_URL 3>&1 1>&2 2>&3)
  then
    writeConfig "SERVER_URL" $NEW_SERVER_URL
  else
    exit 1
  fi

  if NEW_SERVER_KEY=$(whiptail --title "Enter the server key" --inputbox "Enter the key for the server." ${r} ${c} $SERVER_KEY 3>&1 1>&2 2>&3)
  then
    writeConfig "SERVER_KEY" $NEW_SERVER_KEY
  else
    exit 1
  fi

  # Connect to the GoPro WiFi
  # TODO: Do we also have to set the country code? For Raspberry Pi 3 B+?
  if CAMERA_NAME=$(whiptail --title "Find camera name" --inputbox "Now we want to connect to the GoPro WiFi. Please open Settings > Connections > Camera Info. There you will find the name of the camera that is also used as WiFi SSID." ${r} ${c} "GP42001337" 3>&1 1>&2 2>&3)
  then
    writeConfig "GOPRO_SSID" $CAMERA_NAME
    if CAMERA_PW=$(whiptail --title "Find camera password" --inputbox "Now we also need the password. You can find it also in Settings > Connections > Camera Info. It normally contains a word and a four numbers." ${r} ${c} "wheel2260" 3>&1 1>&2 2>&3)
    then
      # now write this down to the network configuration
      $sudo echo "

network={
    ssid=\"${CAMERA_NAME}\"
    psk=\"${CAMERA_PW}\"
    priority=1
}" >> /etc/wpa_supplicant/wpa_supplicant.conf
    else
      exit 1
    fi
  else
    exit 1
  fi
}

confUnattendedUpgrades() {
    cd /etc/apt/apt.conf.d

    if [[ $UNATTUPG == "unattended-upgrades" ]]; then
        $SUDO apt-get --yes --quiet --no-install-recommends install "$UNATTUPG" > /dev/null & spinner $!
        if [[ $PLAT == "Ubuntu" ]]; then
            # Ubuntu 50unattended-upgrades should already just have security enabled
            # so we just need to configure the 10periodic file
            cat << EOT | $SUDO tee 10periodic >/dev/null
    APT::Periodic::Update-Package-Lists "1";
    APT::Periodic::Download-Upgradeable-Packages "1";
    APT::Periodic::AutocleanInterval "5";
    APT::Periodic::Unattended-Upgrade "1";
EOT
        else
            # Fix Raspbian config
            if [[ $PLAT == "Raspbian" ]]; then
                wget -q -O - "$UNATTUPG_CONFIG" | $SUDO tar xz
                $SUDO cp unattended-upgrades-1.4/data/50unattended-upgrades.Raspbian 50unattended-upgrades
                $SUDO rm -rf unattended-upgrades-1.4
            fi

            # Add the remaining settings for all other distributions
            cat << EOT | $SUDO tee 02periodic >/dev/null
    APT::Periodic::Enable "1";
    APT::Periodic::Update-Package-Lists "1";
    APT::Periodic::Download-Upgradeable-Packages "1";
    APT::Periodic::Unattended-Upgrade "1";
    APT::Periodic::AutocleanInterval "7";
    APT::Periodic::Verbose "0";
EOT
        fi
    fi

}

confLogging() {
  echo "if \$programname == 'adelbach-server' then /var/log/adelbach.log
if \$programname == 'adelbach-server' then stop" | $SUDO tee /etc/rsyslog.d/30-adelbach.conf > /dev/null

  echo "/var/log/adelbach.log
{
    rotate 4
    weekly
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        invoke-rc.d rsyslog rotate >/dev/null 2>&1 || true
    endscript
}" | $SUDO tee /etc/logrotate.d/adelbach > /dev/null

  # Restart the logging service
  case ${PLAT} in
    Ubuntu|Debian|*vuan)
      $SUDO service rsyslog restart || true
      ;;
    *)
      $SUDO systemctl restart rsyslog.service || true
      ;;
  esac
}

installAdelbach() {
    stopServices
    $SUDO mkdir -p /etc/adelbach/
    $SUDO cp /tmp/adelbachUSR /etc/adelbach/INSTALL_USER
    $SUDO cp /tmp/DET_PLATFORM /etc/adelbach/DET_PLATFORM
    # Write config file for server using the example-config.txt file
    $SUDO cp /etc/.adelbach/example-config.txt $CONFIG_FILE_PATH
    confUnattendedUpgrades
    installScripts
    confLogging
    confAdelbach
}

updateAdelbach() {
    stopServices
    confUnattendedUpgrades
    installScripts
}


displayFinalMessage() {
    # Final completion message to user
    whiptail --msgbox --backtitle "Make it so." --title "Installation Complete!" "The install log is in /etc/adelbach. Consider running sudo raspi-config for additional configurations (please don't touch WiFi!)." ${r} ${c}
    if (whiptail --title "Reboot" --yesno --defaultno "It is strongly recommended you reboot after installation.  Would you like to reboot now?" ${r} ${c}); then
        whiptail --title "Rebooting" --msgbox "The system will now reboot." ${r} ${c}
        printf "\nRebooting system...\n"
        $SUDO sleep 3
        $SUDO shutdown -r now
    fi
}

update_dialogs() {
    # reconfigure
    if [ "${reconfigure}" = true ]; then
        opt1a="Repair"
        opt1b="This will retain existing settings"
        strAdd="You will remain on the same version"
    else
        opt1a="Update"
        opt1b="This will retain existing settings."
        strAdd="You will be updated to the latest version."
    fi
    opt2a="Reconfigure"
    opt2b="This will allow you to enter new settings"

    UpdateCmd=$(whiptail --title "Existing Install Detected!" --menu "\n\nWe have detected an existing install.\n\nPlease choose from the following options: \n($strAdd)" ${r} ${c} 2 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
    { echo "::: Cancel selected. Exiting"; exit 1; }

    case ${UpdateCmd} in
        ${opt1a})
            echo "::: ${opt1a} option selected."
            useUpdateVars=true
            ;;
        ${opt2a})
            echo "::: ${opt2a} option selected"
            useUpdateVars=false
            ;;
    esac
}

clone_or_update_repos() {
    if [[ "${reconfigure}" == true ]]; then
        echo "::: --reconfigure passed to install script. Not downloading/updating local repos"
    else
        # Get Git files
        getGitFiles ${adelbachFilesDir} ${adelbachGitUrl} || \
        { echo "!!! Unable to clone ${adelbachGitUrl} into ${adelbachFilesDir}, unable to continue."; \
            exit 1; \
        }
    fi
}

######## SCRIPT ############

main() {

    ######## FIRST CHECK ########
    # Must be root to install
    echo ":::"
    if [[ $EUID -eq 0 ]];then
        echo "::: You are root."
    else
        echo "::: sudo will be used for the install."
        # Check if it is actually installed
        # If it isn't, exit because the install cannot complete
        if [[ $(dpkg-query -s sudo) ]];then
            export SUDO="sudo"
            export SUDOE="sudo -E"
        else
            echo "::: Please install sudo or run this as root."
            exit 1
        fi
    fi

    # Check for supported distribution
    distro_check

    # Check arguments for the undocumented flags
    for var in "$@"; do
        case "$var" in
            "--reconfigure"  ) reconfigure=true;;
            "--i_do_not_follow_recommendations"   ) skipSpaceCheck=false;;
            "--unattended"     ) runUnattended=true;;
        esac
    done

    if [[ -f ${setupVars} ]]; then
        if [[ "${runUnattended}" == true ]]; then
            echo "::: --unattended passed to install script, no whiptail dialogs will be displayed"
            useUpdateVars=true
        else
            update_dialogs
        fi
    fi

    # Start the installer
    # Verify there is enough disk space for the install
    if [[ "${skipSpaceCheck}" == true ]]; then
        echo "::: --i_do_not_follow_recommendations passed to script, skipping free disk space verification!"
    else
        verifyFreeDiskSpace
    fi

    # Install the packages (we do this first because we need whiptail)
    addSoftwareRepo

    update_package_cache

    # Notify user of package availability
    notify_package_updates_available

    # Install packages used by this installation script
    install_dependent_packages ADELBACH_DEPS[@]

    # Display welcome dialogs
    welcomeDialogs

    # Choose the user for the ovpns
    chooseUser

    # Ask if unattended-upgrades will be enabled
    unattendedUpgrades

    # Clone/Update the repos
    clone_or_update_repos

    # Install and log everything to a file
    installAdelbach | tee ${tmpLog}

    echo "::: Install Complete..."


    #Move the install log into /etc/adelbach for storage
    $SUDO mv ${tmpLog} ${instalLogLoc}

    echo "::: Restarting services..."
    # Start services
    case ${PLAT} in
        Ubuntu|Debian|*vuan)
            $SUDO service adelbach start
            ;;
        *)
            $SUDO systemctl enable adelbach.service
            $SUDO systemctl start adelbach.service
            ;;
    esac

    echo "::: done."

    if [[ "${useUpdateVars}" == false ]]; then
        displayFinalMessage
    fi

    echo ":::"
    if [[ "${useUpdateVars}" == false ]]; then
        echo "::: Installation Complete!"
        echo "::: It is strongly recommended you reboot after installation."
    else
        echo "::: Update complete!"
    fi

    echo ":::"
    echo "::: The install log is located at: ${instalLogLoc}"
}

# start the script
main "$@"
