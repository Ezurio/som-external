#include <QtCore>
#include <QtDBus>
#include <QObject>
#include <QCoreApplication>
#include <QHostAddress>
#include <QtEndian>

#include "lrdnmdevicesifc.h"


LrdNMDevicesIfc::LrdNMDevicesIfc()
{
    QMap<QString, QString>::iterator it;
    QMap<QString, QStringList>::iterator lt;

    nmAdaptor = new LrdNetworkManagerAdaptor();

    nmAdaptor->get_all_devices(mDevName, mDevPath);

    for(it=mDevPath.begin(); it != mDevPath.end(); ++it)
        nmAdaptor->get_connections_by_device(it.key(), it.value(), mConnPath, mActiveConnPath, mIPv4ConfigPath);

    for(lt=mConnPath.begin(); lt != mConnPath.end(); ++lt)
        foreach(QString connPath, lt.value())
            nmAdaptor->get_connection_settings_by_path(connPath, mConnSettings); 
}

QStringList LrdNMDevicesIfc::get_devices_by_type(int32_t type)
{
    QStringList list = mDevName[type];
    return list;
}

QString LrdNMDevicesIfc::get_device_path_by_name(const QString& devName)
{
    return mDevPath[devName];
}

QStringList LrdNMDevicesIfc::get_all_devices()
{
    QStringList list;
    QMap<int32_t, QStringList>::iterator it;
    for(it = mDevName.begin(); it != mDevName.end(); ++it)
    {
        list.append(it.value());
    }
    return list;
}

QStringList LrdNMDevicesIfc::get_connections_by_device(const QString& devName)
{
    QStringList list;
    
    list.clear();
    
    if(devName.isEmpty())
        return list;
    
    foreach(QString path, mConnPath[devName])
    {
        QString tmp = connection_path_to_ssid(path);
        if(!tmp.isNull())
            list.append(tmp);
    }
    return list;
}

void LrdNMDevicesIfc::get_ipv4_info_by_device(const QString& devName, QString& ipaddr, QString& mask, QString& gateway)
{
    if(devName.isEmpty())
        return;
    
    nmAdaptor->get_connections_by_device(devName, mDevPath[devName], mConnPath, mActiveConnPath, mIPv4ConfigPath);
    
    if(mIPv4ConfigPath[devName].length() < 20)
        nmAdaptor->get_connections_by_device(devName, mDevPath[devName], mConnPath, mActiveConnPath, mIPv4ConfigPath);
    
    nmAdaptor->get_ipv4_config(mIPv4ConfigPath[devName], ipaddr, gateway, mask);
    return;
}

QString LrdNMDevicesIfc::get_ipv4_method(const QString& devName)
{
    if(devName.isEmpty())
        return QString();
    
    QString path = ssid_to_connection_path(devName); 
    if(path.isNull()) return "Manual";
    if(mConnSettings[path]["ipv4"]["method"] == "manual")
        return "Manual";

    return "Dhcp";
}

QString LrdNMDevicesIfc::ssid_to_device(const QString& ssid)
{
    QMap<QString, QStringList>::Iterator it;
    for(it = mSsid.begin(); it != mSsid.end(); ++it)
    {
        QStringList tmp = it.value();
        if(tmp.contains(ssid, Qt::CaseInsensitive))
            return it.key();
    }
    return NULL;
}

QString LrdNMDevicesIfc::ssid_to_connection_path(const QString &ssid)
{
    QMap<QString, NMVariantMapMap>::Iterator it;
    for(it = mConnSettings.begin(); it != mConnSettings.end(); ++it)
    {
        NMVariantMapMap tmp = it.value();
        if(tmp["connection"]["id"].isValid() && !ssid.compare(tmp["connection"]["id"].toString(), Qt::CaseInsensitive))
            return it.key();
    }
    return NULL;
}

QString LrdNMDevicesIfc::connection_path_to_ssid(const QString& connPath)
{
    QMap<QString, NMVariantMapMap>::Iterator it;
    for(it = mConnSettings.begin(); it != mConnSettings.end(); ++it)
    {
        if(it.key() == connPath) 
        {
            NMVariantMapMap tmp = it.value();
            return tmp["connection"]["id"].toString();
         }
    }
    return NULL;
}

void LrdNMDevicesIfc::do_scan_accesspoint_list(const QString& devName)
{
    //for(it=mDevPath.begin(); it != mDevPath.end(); ++it)                                            
    if(devName.isEmpty())
        return;
    
    nmAdaptor->get_accesspoint_list_by_device_path(devName, mDevPath[devName], mSsid, mAccessPointSecurity);
}

QStringList LrdNMDevicesIfc::get_accesspoint_list(const QString& devName)
{
    return mSsid[devName];
}

QVector<int> LrdNMDevicesIfc::get_accesspoint_security_type(const QString& ssid)
{
    return mAccessPointSecurity[ssid];
}

bool LrdNMDevicesIfc::is_added(const QString& ssid)
{
    QString tmp = ssid_to_connection_path(ssid);
    if(tmp.isNull())
        return false;
    return true;
}

QString LrdNMDevicesIfc::add_connection(const QString& devName, const NMVariantMapMap& conn)
{
    QString result;
    
    if(devName.isEmpty())
        return QString();
    
    result = nmAdaptor->add_connection(conn);
    if(result.isNull())
        return QString();
    
    mConnPath[devName].append(result);
    mConnSettings[result] = conn;  
    return result;
}

QString LrdNMDevicesIfc::add_connection_wired(const QString& devName)
{
    QString result;
    NMVariantMapMap connection;                                                                                                                            
    
    if(devName.isEmpty())
        return QString();
    // Set method to "Manual" and put addresses to the connection map                           
    connection["ipv4"]["method"] = "auto";  
    
    // Build up the 'connection' Setting                                                            
    connection["connection"]["uuid"] = QUuid::createUuid().toString().remove('{').remove('}');         
    connection["connection"]["id"] = devName;                                                
    connection["connection"]["type"] = "802-3-ethernet";                                            
                                                                                                    
    // Build up the '802-3-ethernet' Setting                                                        
    connection["802-3-ethernet"];                                                                   
    
    return add_connection(devName, connection);
}

QString LrdNMDevicesIfc::add_connection_open(const QString& devName, const QString& ssid)              
{                                                                                                   
    NMVariantMapMap connection;                                                                     
    
    if(devName.isEmpty())
        return QString();
    // Build up the 'connection' Setting                                                            
    connection["connection"]["uuid"] = QUuid::createUuid().toString().remove('{').remove('}');      
    connection["connection"]["id"] = ssid;                                                          
    connection["connection"]["type"] = "802-11-wireless";                                           
                                                                                                    
    // Build up the '802-11-wireless' Setting                                                       
    connection["802-11-wireless"]["ssid"] = ssid.toUtf8();                                          
    connection["802-11-wireless"]["mode"] = "infrastructure";                                       
                                                                                                    
    // Build up the 'ipv4' Setting                                                                  
    connection["ipv4"]["method"] = "auto";                                                          
    connection["ipv6"]["method"] = "auto";                                                          
                                                                                                    
    return add_connection(devName, connection);                                                     
} 

QString LrdNMDevicesIfc::add_connection_wep(const QString &devName, const QString &ssid, const int key, const QString& passwd)
{                                                                                                   
    NMVariantMapMap connection;    
    
    if(devName.isEmpty())
        return QString();                                                                                                 
    // Build up the 'connection' Setting                                                            
    connection["connection"]["uuid"] = QUuid::createUuid().toString().remove('{').remove('}');      
    connection["connection"]["id"] = ssid;                                                          
    connection["connection"]["type"] = "802-11-wireless";                                           
                                                                                                    
    // Build up the '802-11-wireless' Setting                                                       
    connection["802-11-wireless"]["ssid"] = ssid.toUtf8();                                          
    connection["802-11-wireless"]["mode"] = "infrastructure";                                       
                                                                                                    
    // Build up the '802-11-wireless-security' Setting                                              
    connection["802-11-wireless-security"]["key-mgmt"] = "none";                                    
    connection["802-11-wireless-security"]["auth-alg"] = "open";                                    
    connection["802-11-wireless-security"]["wep-key1"] = passwd;                                    
    connection["802-11-wireless-security"]["wep-key-type"] = key;                                   
    connection["802-11-wireless-security"]["wep-tx-keyidx"] = key; 

    // Build up the 'ipv4' Setting                                                                  
    connection["ipv4"]["method"] = "auto";                                                          
    connection["ipv6"]["method"] = "auto";                                                          
                                                                                                    
    return add_connection(devName, connection);                                                     
}

QString LrdNMDevicesIfc::add_connection_8021x(const QString &devName, const QString &ssid, const QString& eap, const QString& identity,
                    const QString& client,  const QString& ca, const QString& privateKey, const QString& passwd)
{   
    if(devName.isEmpty())
        return QString(); 
    
    return QString();                                                                                   
}

QString LrdNMDevicesIfc::add_connection_wpa(const QString& devName, const QString& ssid, const QString& passwd)
{                                                                                                   
    NMVariantMapMap connection;                                                                     
    if(devName.isEmpty())
        return QString();                                                                                                
    // Build up the 'connection' Setting                                                            
    connection["connection"]["uuid"] = QUuid::createUuid().toString().remove('{').remove('}');      
    connection["connection"]["id"] = ssid;                                                          
    connection["connection"]["type"] = "802-11-wireless";                                           
                                                                                                    
    // Build up the '802-11-wireless' Setting                                                       
    connection["802-11-wireless"]["ssid"] = ssid.toUtf8();                                          
    connection["802-11-wireless"]["mode"] = "infrastructure";                                       
                                                                                                    
    // Build up the '802-11-wireless-security' Setting                                              
    connection["802-11-wireless-security"]["key-mgmt"] = "wpa-psk";                                 
    connection["802-11-wireless-security"]["auth-alg"] = "open";                                    
    connection["802-11-wireless-security"]["psk"] = passwd;                                         
                                                                                                    
    // Build up the 'ipv4' Setting                                                                  
    connection["ipv4"]["method"] = "auto";                                                          
    connection["ipv6"]["method"] = "auto";                                                          
                                                                                                    
    return add_connection(devName, connection);                                                     
}

bool LrdNMDevicesIfc::update_connection_wired(const QString& devName, const QString& ip, const QString& netmask, const QString gateway)
{
    if(devName.isEmpty())
        return false;
    
    QList<QList<uint> > addresses;                                                              
    QList<uint> addr1;     
    QString path = ssid_to_connection_path(devName);
    if(path.isNull())
    {
        path = add_connection_wired(devName);
        if(path.isEmpty())
            return false;
    }
    
    qDebug() << "Added! connection is " << path;
    
    if(ip.isEmpty())
    {
        // Add some addresses                                                                       
        addr1 << qToBigEndian(QHostAddress("0.0.0.0").toIPv4Address()) << 0 
              << qToBigEndian(QHostAddress("0.0.0.0").toIPv4Address());
        addresses << addr1;
        
        mConnSettings[path]["ipv4"]["addresses"] = QVariant::fromValue(addresses);  
        mConnSettings[path]["ipv4"]["method"] = "auto";
    }
    else 
    {
                                                              
        uint32_t mask = QHostAddress(netmask).toIPv4Address();
        uint32_t prefix = 32;
        
        while(!(mask & 1)){
            mask = mask >> 1;
            --prefix;
        }

        // Add some addresses                                                                       
        addr1 << qToBigEndian(QHostAddress(ip).toIPv4Address()) << prefix 
              << qToBigEndian(QHostAddress(gateway).toIPv4Address());
        addresses << addr1;
        
        // Set method to "Manual" and put addresses to the connection map                           
        mConnSettings[path]["ipv4"]["method"] = "manual";
        mConnSettings[path]["ipv4"]["addresses"] = QVariant::fromValue(addresses);      
    }
    qDebug() << "To update\r\n";
    nmAdaptor->update_connection(path, mConnSettings[path]);
    qDebug() << "Update\r\n";
    return true;
}

bool LrdNMDevicesIfc::activate_connection(const QString& devName, const QString& ssid)
{
    if(devName.isEmpty())
        return false;
    
    QString path = ssid_to_connection_path(ssid);
    if(path.isNull())
        return false;

    QString result = nmAdaptor->activate_connection(path);
    if(result.isNull())
        return false;

    return true;
}

void LrdNMDevicesIfc::delete_connection(const QString& devName, const QString& ssid)
{
    if(devName.isEmpty())
        return;
    
    QString path = ssid_to_connection_path(ssid);
    if(path.isNull())
        return;

    nmAdaptor->delete_connection(path);
    mConnPath[devName].removeOne(ssid);
    mConnSettings.remove(path);
    nmAdaptor->get_connections_by_device(devName, mDevPath[devName], mConnPath, mActiveConnPath, mIPv4ConfigPath);

    return;
}

void LrdNMDevicesIfc::disconnect_connection(const QString& devName)
{
    if(devName.isEmpty())
        return;
    
    QString path = mActiveConnPath[devName];
    if(path.isNull())
        return;

    nmAdaptor->disconnect_connection(path);
    nmAdaptor->get_connections_by_device(devName, mDevPath[devName], mConnPath, mActiveConnPath, mIPv4ConfigPath);
}


LrdNMDevicesIfc::~LrdNMDevicesIfc()
{
    delete nmAdaptor;
}
