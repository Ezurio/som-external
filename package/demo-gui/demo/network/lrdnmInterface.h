#ifndef LRDNMINTERFACE_H
#define LRDNMINTERFACE_H

#include <QtDBus/QDBusServiceWatcher>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QtDBus>
#include <QMap>


#include "generictypes.h"

class LrdNmInterface
{
public:
    LrdNmInterface();
    ~LrdNmInterface();

public:
    void  get_all_devices(QMap<int32_t, QStringList>& mDevName, QMap<QString, QString>& mDevPath);
    
    void  get_connections_by_device(const QString& devName, const QString& devPath,
                                                             QMap<QString, QStringList>& mConn,
                                                             QMap<QString, QString>& mActiveConn,
                                                             QMap<QString, QString>& mIPv4ConfigPath);
    
    void  get_connection_settings_by_path(const QString& connPath, QMap<QString,
                                                             NMVariantMapMap>& mConnSettings);
    
    void  get_accesspoint_list_by_device_path(const QString devName, const QString& devPath, 
                                                             QMap<QString, QStringList>& mSsid,
                                                             QMap<QString, QVector<int> >& mAccessPointSecurity);
    
    void  get_ipv4_config(const QString& ipConnPath, QString& ipaddr, QString& mask, QString& gateway);
    
    QString  add_connection(const NMVariantMapMap& connsettings);
    
    QString  activate_connection(const QString& connPath);
    
    void  update_connection(const QString& connPath, const NMVariantMapMap& connsettings);
    
    void  disconnect_connection(const QString& connPath);
    
    void  delete_connection(const QString& connPath);


private:
     QDBusInterface *nm;
     QDBusInterface *settings;
     
     NMVariantMapList ipv4;
     
     QVariantMap mapTypeToVariant(const QDBusArgument &arg);
     QVariant basicTypeToVariant(const QDBusArgument &arg);
     QVariantList arrayTypeToVariant(const QDBusArgument &arg);
     QVariant dbusArgumentToVariant(const QDBusArgument &arg);
};

#endif // LRDNMINTERFACE_H
