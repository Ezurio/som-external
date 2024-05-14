QT += core gui widgets dbus network

TARGET = network-demo
TEMPLATE = app


SOURCES += main.cpp\
    keyboard/keyboard.cpp \
    generictypes.cpp \
    mainwindow.cpp \
    ethernetsettings.cpp \
    wpainputdlg.cpp \
    wpaenterpriseinputdlg.cpp \
    wepinputdlg.cpp \
    wirelesssettings.cpp \
    lrdnmAdaptor.cpp \
    lrdnmInterface.cpp \
    timesettings.cpp

HEADERS  += \
    keyboard/keyboard.h \
    generictypes.h \
    mainwindow.h \
    ethernetsettings.h \
    wpainputdlg.h \
    wpaenterpriseinputdlg.h \
    wepinputdlg.h \
    wirelesssettings.h \
    lrdnmInterface.h \
    lrdnmAdaptor.h \
    timesettings.h

FORMS    += \
    keyboard/keyboard.ui \
    mainwindow.ui \
    ethernetsettings.ui \
    wpainputdlg.ui \
    wpaenterpriseinputdlg.ui \
    wepinputdlg.ui \
    wirelesssettings.ui \
	timesettings.ui
