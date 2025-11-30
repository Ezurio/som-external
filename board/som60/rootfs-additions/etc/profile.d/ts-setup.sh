#Neither the edt-ft5x06 driver nor QT will do the calibration
export QT_QPA_FB_TSLIB=1
export TSLIB_TSDEVICE=/dev/input/event0
export TSLIB_CALIBFILE=/etc/pointercal
export TSLIB_CONFFILE=/etc/ts.conf
export TSLIB_FBDEVICE=/dev/fb0
export TSLIB_PLUGINDIR=/usr/lib/ts
export QT_QPA_GENERIC_PLUGINS=tslib:/dev/input/event0
export QT_QPA_PLATFORM=linuxfb:/dev/fb0
export QT_QPA_FB_NO_LIBINPUT=1
export QT_QPA_FB_DISABLE_INPUT=0
#export QT_QPA_EVDEV_DEBUG=1
