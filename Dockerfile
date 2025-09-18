FROM arm64v8/node:latest as build

WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.webpack.json tsconfig.json webpack.config.ts ./
COPY src src/
COPY typings typings/
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN npm run build

CMD sleep infinity

FROM balenalib/aarch64-ubuntu:noble-build AS runtime
## With balenalib base images, USB works without any extra configuration

RUN apt update && apt install -y npm git autoconf libtool pkg-config libx11-dev libxss-dev libxss1 curl

# Build clicklock
WORKDIR /usr/src/clicklock
RUN git clone https://github.com/zpfvo/clicklock.git .
RUN git checkout 5da48f70f90883f8a966f50f75e494e8f18adc95
RUN autoreconf --force --install
RUN ./configure
RUN make

RUN cp /usr/src/clicklock/clicklock /usr/bin/clicklock

RUN \
	apt install -y \
	# Electron runtime dependencies
	libasound2t64 \
	libgdk-pixbuf-xlib-2.0-0 \
	libglib2.0-0 \
	libgtk-3-0 \
	libnss3 \
	libx11-xcb1 \
	libxss1 \
	libxtst6 \
	# Onscreen keyboard
	onboard \
	dconf-cli \
	metacity \
	# x11
	xserver-xorg \
	xinit \
	# includes e
	x11-xserver-utils \
	x11-utils \
	xauth \
	xinput \
	xserver-xorg-input-all \
	xserver-xorg-input-evdev \
	xserver-xorg-legacy \
	xserver-xorg-video-all \
	# emojis (used on the wifi config page)
	fonts-symbola \
	# mount ntfs partitions
	ntfs-3g \
	# for exposing --remote-debugging-port to other computers
	linux-firmware-raspi \
	simpleproxy \
	&& rm -rf /var/lib/apt/lists/*

RUN apt autoremove -y

COPY --from=build /usr/src/app/build /usr/lib/balena-electron-env
COPY .xserverrc /root/.xserverrc
COPY .xinitrc /root/.xinitrc

ENV DISPLAY=:0
ENV X_ADDITIONAL_PARAMETERS='-nocursor'
ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/dbus-session-bus"
# Required for communicating with host's NetworkManager
ENV DBUS_SYSTEM_BUS_ADDRESS="unix:path=/host/run/dbus/system_bus_socket"

COPY onboard/Balena-*.svg /usr/share/onboard/layouts/
COPY onboard/Balena.onboard /usr/share/onboard/layouts/
COPY onboard/Balena.colors /usr/share/onboard/themes/
COPY onboard/Balena.theme /usr/share/onboard/themes/
COPY onboard/SourceSansPro-Regular.ttf /usr/local/share/fonts/
COPY onboard/onboard-defaults.conf /etc/onboard/

WORKDIR /usr/src/app

# COPY --from=build /usr/src/app/package-lock.json ./

CMD sleep infinity
