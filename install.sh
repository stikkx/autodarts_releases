#!/bin/bash

if [[ $1 == "--uninstall" ]]; then
    echo "Trying to remove autodarts"
    sudo systemctl stop autodarts
    sudo systemctl disable autodarts
    sudo rm /etc/systemd/system/autodarts.service
    sudo rm /etc/systemd/system/autodartsupdater.service
    rm ~/.local/bin/autodarts
    rm ~/.local/bin/update.sh
    exit
fi

AUTOSTART="true"
AUTOUPDATE="true"
while getopts "nu" OPTION; do
  case "${OPTION}" in
    n)
      AUTOSTART="false"
      ;;
    u)
      AUTOUPDATE="false"
      ;;
    *)
      AUTOSTART="true"
      AUTOUPDATE="true"
      ;;
  esac
done

shift "$(($OPTIND -1))"

PLATFORM=$(uname)
if [[ "$PLATFORM" = "Linux" ]]; then 
    PLATFORM="linux"
elif [[ "$PLATFORM" = "Darwin" ]]; then
    PLATFORM="darwin"
else
    echo "Platform is not 'linux', and hence is not supported by this script." && exit 1
fi

ARCH=$(uname -m)
case "${ARCH}" in
    "x86_64"|"amd64") ARCH="amd64";;
    "aarch64"|"arm64") ARCH="arm64";;
    "armv7l") ARCH="armv7l";;
    *) echo "Kernel architecture '${ARCH}' is not supported." && exit 1;;
esac

REQ_VERSION=$1
REQ_VERSION="${REQ_VERSION#v}"
if [[ "$REQ_VERSION" = "" ]]; then
    VERSION=$(curl -sL https://api.github.com/repos/autodarts/releases/releases/latest | grep tag_name | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    echo "Installing latest version v${VERSION}."
else
    VERSION=$(curl -sL https://api.github.com/repos/autodarts/releases/releases | grep tag_name | grep ${REQ_VERSION} | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\(-\(beta\|rc\)[0-9]\+\)\?' | head -1)
    if [[ "$VERSION" = "" ]]; then
        echo "Requested version v${REQ_VERSION} not found." && exit 1
    fi
    echo "Installing requested version v${VERSION}."
fi

# Download autodarts binary and unpack to ~/.local/bin
mkdir -p ~/.local/bin
echo "Downloading and extracting 'autodarts${VERSION}.${PLATFORM}-${ARCH}.tar.gz' into '~/.local/bin'."
curl -sL https://github.com/autodarts/releases/releases/download/v${VERSION}/autodarts${VERSION}.${PLATFORM}-${ARCH}.tar.gz | tar -xz -C /usr/local/bin
echo "Making /usr/local/bin/autodarts executable."
chmod +x /usr/local/bin/autodarts
curl -sL https://raw.githubusercontent.com/autodarts/releases/main/updater.sh > /usr/local/bin/updater.sh
chmod +x /usr/local/bin/updater.sh

if [[ ${AUTOUPDATE} = "true" && "$PLATFORM" = "linux" ]]; then
    # Create systemd service
    echo "Creating systemd service for autodarts auto updater to run on system startup."
    echo "We will need sudo access to do that."

    if [[ ${USER} = "root" ]]; then
      cat <<EOF | sudo tee /etc/systemd/system/autodartsupdater.service >/dev/null
# autodartsupdater.service
[Unit]
Description=Autodarts automatic updater.
Wants=network.target
After=network.target

[Service]
Type=simple
User=${USER}
ExecStart=/usr/local/bin/updater.sh

[Install]
WantedBy=multi-user.target
EOF
    else
      cat <<EOF | sudo tee /etc/systemd/system/autodartsupdater.service >/dev/null
# autodartsupdater.service
[Unit]
Description=Autodarts automatic updater.
Wants=network.target
After=network.target

[Service]
Type=simple
User=${USER}
ExecStart=/usr/local/bin/updater.sh

[Install]
WantedBy=multi-user.target
EOF
    fi

    echo "Enabling systemd service for automatic updates."
    sudo systemctl enable autodartsupdater
fi

if [[ ${AUTOSTART} = "true" && "$PLATFORM" = "linux" ]]; then
    # Create systemd service
    echo "Creating systemd service for autodarts to start on system startup."
    echo "We will need sudo access to do that."

    if [[ ${USER} = "root" ]]; then
      cat <<EOF | sudo tee /etc/systemd/system/autodarts.service >/dev/null
# autodarts.service

[Unit]
Description=Start/Stop Autodarts board service
Wants=network.target
After=network.target

[Service]
User=${USER}
ExecStart=/usr/local/bin/autodarts
Restart=on-failure
KillSignal=SIGINT
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    else
      cat <<EOF | sudo tee /etc/systemd/system/autodarts.service >/dev/null
# autodarts.service

[Unit]
Description=Start/Stop Autodarts board service
Wants=network.target
After=network.target

[Service]
User=${USER}
ExecStart=/usr/local/bin/autodarts
Restart=on-failure
KillSignal=SIGINT
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    fi

    echo "Adding the current user to the group video"
    sudo usermod -aG ${USER} video

    echo "Enabling systemd service."
    sudo systemctl enable autodarts

    echo "Starting autodarts."
    sudo systemctl stop autodarts
    sudo systemctl start autodarts
fi

echo "Done."