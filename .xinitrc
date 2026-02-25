#!/bin/sh

if [ -n "$XRANDR_ARGS" ]; then
	xrandr $XRANDR_ARGS
fi

REMOTE_DEBUG=""
if [ -n "$BALENAELECTRONJS_REMOTE_DEBUGGING_PORT" ]; then
	LOCAL_PORT=`expr $BALENAELECTRONJS_REMOTE_DEBUGGING_PORT - 1`
	REMOTE_DEBUG="--remote-debugging-port=$LOCAL_PORT --remote-allow-origins=*"
	simpleproxy -d -L $BALENAELECTRONJS_REMOTE_DEBUGGING_PORT -R 127.0.0.1:$LOCAL_PORT
fi

rm /tmp/.X0-lock &>/dev/null || true

# Disable DPMS once X server is ready (screen blanking is handled by electron-base)
(while [ ! -e /tmp/.X11-unix/X0 ]; do sleep 0.5; done
  export DISPLAY=:0
  xset -dpms
) &

GPU_FLAGS="--disable-gpu"
if [ "$ENABLE_GPU" = "1" ]; then
	GPU_FLAGS="--disable-gpu-compositing"
fi

metacity &
dbus-daemon --fork --session --address $DBUS_SESSION_BUS_ADDRESS
/usr/src/app/node_modules/.bin/electron $REMOTE_DEBUG --no-sandbox $GPU_FLAGS --autoplay-policy=no-user-gesture-required -r /usr/lib/balena-electron-env /usr/src/app
