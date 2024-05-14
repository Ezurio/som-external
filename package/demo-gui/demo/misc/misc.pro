TEMPLATE = app
CONFIG += console
CONFIG -= app_bundle
CONFIG -= qt

TARGET = systime
SOURCES += systime.c

LIBS += -ldrm -lplanes -lcairo -lcjson -llua

QMAKE_CFLAGS += `pkg-config --cflags --libs libdrm`
QMAKE_CFLAGS += `pkg-config --cflags --libs libplanes`
QMAKE_CFLAGS += `pkg-config --cflags --libs cairo`
QMAKE_CFLAGS += `pkg-config --cflags --libs cjson`
QMAKE_CFLAGS += `pkg-config --cflags --libs lua`
