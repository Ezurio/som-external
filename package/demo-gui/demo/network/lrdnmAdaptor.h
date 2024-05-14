#ifndef LRDNMADAPTOR_H
#define LRDNMADAPTOR_H

#include <QtDBus/QDBusServiceWatcher>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QtDBus>
#include <QMap>

#include "lrdnmInterface.h"

class LrdNmAdaptor
{
public:
    LrdNmAdaptor();
    ~LrdNmAdaptor();

    QStringList get_devices_by_type(int32_t type);
    QString     get_device_path_by_name(const QString& devName);
    QStringList get_all_devices();
    QStringList get_connections_by_device(const QString& devName);
    void     get_ipv4_info_by_device(const QString& devName, QString& ipaddr, QString& mask, QString& gateway);
    QString get_ipv4_method(const QString& devName);
    void do_scan_accesspoint_list(const QString& devName);
    QStringList get_accesspoint_list(const QString& devName);
    QVector<int> get_accesspoint_security_type(const QString& ssid);
    bool is_added(const QString& ssid);
    
    QString add_connection(const QString& devName, const NMVariantMapMap& conn);
    QString add_connection_open(const QString& devName, const QString& ssid)  ;
    QString add_connection_wep(const QString &devName, const QString &ssid, const int key, const QString& passwd);
    QString add_connection_wpa(const QString& devName, const QString& ssid, const QString& passwd);
    
    QString add_connection_8021x(const QString &devName, const QString &ssid, const QString& eap, const QString& identity,
                        const QString& client,  const QString& ca, const QString& privateKey, const QString& passwd);
    
    bool update_connection_wired(const QString& devName, const QString& ip, const QString& netmask, const QString gateway);
    bool activate_connection(const QString& devName, const QString& ssid);
    void delete_connection(const QString& devName, const QString& ssid);
    void disconnect_connection(const QString& devName);
    
private:
    QString ssid_to_device(const QString& ssid);
    QString ssid_to_connection_path(const QString& ssid);
    QString connection_path_to_ssid(const QString& connPath);
    QString add_connection_wired(const QString& devName);
 
    
private:
     LrdNmInterface *nmIfc;
     QMap<int32_t, QStringList>mDevName;           //type <-> interface name
     QMap<QString, QString>mDevPath;                //interface name <-> interface path
     QMap<QString, QStringList>mConnPath;           //type <-> connection path
     QMap<QString, QString>mActiveConnPath;         //interface path <-> active connection path
     QMap<QString, QString>mIPv4ConfigPath;         //interface path <-> IPv4 Config path
     QMap<QString, NMVariantMapMap>mConnSettings;   //connection path <-> connection setting
     QMap<QString, QStringList> mSsid;              //interface name <-> AP ssid(s) of this interface;
     QMap<QString, QVector<int> > mAccessPointSecurity;       // ssid <-> security;
};

#endif // LRDNMADAPTOR_H
