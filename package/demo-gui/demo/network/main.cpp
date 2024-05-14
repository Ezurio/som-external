#include <QtWidgets/QApplication>
#include <QtWidgets/QMainWindow>


#include "mainwindow.h"

int main(int argc, char *argv[])
{
    qRegisterMetaType<UIntList>();
    qRegisterMetaType<UIntListList>();   
    qRegisterMetaType<NMStringMap>();
    qRegisterMetaType<NMVariantMapList>();
    qRegisterMetaType<NMVariantMapMap>();
    
    qDBusRegisterMetaType<UIntList>();
    qDBusRegisterMetaType<UIntListList>();   
    qDBusRegisterMetaType<NMStringMap>();
    qDBusRegisterMetaType<NMVariantMapList>();
    qDBusRegisterMetaType<NMVariantMapMap>();
    
    QApplication a(argc, argv);
    QMainWindow w;
    MainWindow mw;
    
    w.setCentralWidget(&mw);
    w.showMaximized();
    
    return a.exec();
}
