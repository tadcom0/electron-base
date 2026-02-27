FROM arm64v8/node:25 AS build

WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.webpack.json tsconfig.json webpack.config.ts ./
COPY src src/
COPY typings typings/
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN npm run build

# Build clicklock in a separate stage so build tools don't end up in the final image
FROM balenalib/aarch64-debian-node:latest-build AS clicklock-build
RUN install_packages git autoconf libtool pkg-config libx11-dev libxss-dev
WORKDIR /usr/src/clicklock
RUN git clone https://github.com/zpfvo/clicklock.git . \
	&& git checkout 5da48f70f90883f8a966f50f75e494e8f18adc95 \
	&& autoreconf --force --install \
	&& ./configure \
	&& make

FROM balenalib/aarch64-debian-node:latest-build AS runtime
## With balenalib base images, USB works without any extra configuration

COPY --from=clicklock-build /usr/src/clicklock/clicklock /usr/bin/clicklock

# Install Node.js 24 (remove old v19 from /usr/local/bin first)
RUN rm -f /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx \
	&& curl -fsSL https://deb.nodesource.com/setup_24.x | bash \
	&& apt-get install -y nodejs

RUN \
	install_packages \
	# Electron runtime dependencies
	libasound2 \
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
	x11-xserver-utils \
	x11-utils \
	xauth \
	xinput \
	xserver-xorg-input-all \
	xserver-xorg-input-evdev \
	xserver-xorg-legacy \
	xserver-xorg-video-all \
	# GPU acceleration (used when ENABLE_GPU=1)
	libgles2-mesa \
	libegl1-mesa \
	libgl1-mesa-dri \
	libgbm1 \
	# emojis (used on the wifi config page)
	fonts-symbola \
	# mount ntfs partitions
	ntfs-3g \
	# for exposing --remote-debugging-port to other computers
	simpleproxy \
	&& rm -rf /var/lib/apt/lists/*

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

CMD sleep infinity
