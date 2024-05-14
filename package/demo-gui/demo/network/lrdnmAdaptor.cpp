#include <QtCore>
#include <QtDBus>
#include <QObject>
#include <QCoreApplication>
#include <QHostAddress>
#include <QtEndian>

#include "lrdnmAdaptor.h"


LrdNmAdaptor::LrdNmAdaptor()
{
    QMap<QString, QString>::iterator it;
    QMap<QString, QStringList>::iterator lt;

    nmIfc = new LrdNmInterface();

    nmIfc->get_all_devices(mDevName, mDevPath);

    for(it=mDevPath.begin(); it != mDevPath.end(); ++it)
        nmIfc->get_connections_by_device(it.key(), it.value(), mConnPath, mActiveConnPath, mIPv4ConfigPath);

    for(lt=mConnPath.begin(); lt != mConnPath.end(); ++lt)
        foreach(QString connPath, lt.value())
            nmIfc->get_connection_settings_by_path(connPath, mConnSettings); 
}

QStringList LrdNmAdaptor::get_devices_by_type(int32_t type)
{
    QStringList list = mDevName[type];
    return list;
}

QString LrdNmAdaptor::get_device_path_by_name(const QString& devName)
{
    return mDevPath[devName];
}

QStringList LrdNmAdaptor::get_all_devices()
{
    QStringList list;
    QMap<int32_t, QStringList>::iterator it;
    for(it = mDevName.begin(); it != mDevName.end(); ++it)
    {
        list.append(it.value());
    }
    return list;
}

QStringList LrdNmAdaptor::get_connections_by_device(const QString& devName)
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

void LrdNmAdaptor::get_ipv4_info_by_device(const QString& devName, QString& ipaddr, QString& mask, QString& gateway)
{
    if(devName.isEmpty())
        return;
    
    nmIfc->get_connections_by_device(devName, mDevPath[devName], mConnPath, mActiveConnPath, mIPv4ConfigPath);
    
    if(mIPv4ConfigPath[devName].length() < 20)
        nmIfc->get_connections_by_device(devName, mDevPath[devName], mConnPath, mActiveConnPath, mIPv4ConfigPath);
    
    nmIfc->get_ipv4_config(mIPv4ConfigPath[devName], ipaddr, gateway, mask);
    return;
}

QString LrdNmAdaptor::get_ipv4_method(const QString& devName)
{
    if(devName.isEmpty())
        return QString();
    
    QString path = ssid_to_connection_path(devName); 
    if(path.isNull()) return "Manual";
    if(mConnSettings[path]["ipv4"]["method"] == "manual")
        return "Manual";

    return "Dhcp";
}

QString LrdNmAdaptor::ssid_to_device(const QString& ssid)
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

QString LrdNmAdaptor::ssid_to_connection_path(const QString &ssid)
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

QString LrdNmAdaptor::connection_path_to_ssid(const QString& connPath)
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

void LrdNmAdaptor::do_scan_accesspoint_list(const QString& devName)
{
    //for(it=mDevPath.begin(); it != mDevPath.end(); ++it)                                            
    if(devName.isEmpty())
        return;
    
    nmIfc->get_accesspoint_list_by_device_path(devName, mDevPath[devName], mSsid, mAccessPointSecurity);
}

QStringList LrdNmAdaptor::get_accesspoint_list(const QString& devName)
{
    return mSsid[devName];
}

QVector<int> LrdNmAdaptor::get_accesspoint_security_type(const QString& ssid)
{
    return mAccessPointSecurity[ssid];
}

bool LrdNmAdaptor::is_added(const QString& ssid)
{
    QString tmp = ssid_to_connection_path(ssid);
    if(tmp.isNull())
        return false;
    return true;
}

QString LrdNmAdaptor::add_connection(const QString& devName, const NMVariantMapMap& conn)
{
    QString result;
    
    if(devName.isEmpty())
        return QString();
    
    result = nmIfc->add_connection(conn);
    if(result.isNull())
        return QString();
    
    mConnPath[devName].append(result);
    mConnSettings[result] = conn;  
    return result;
}

QString LrdNmAdaptor::add_connection_wired(const QString& devName)
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

QString LrdNmAdaptor::add_connection_open(const QString& devName, const QString& ssid)              
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

QString LrdNmAdaptor::add_connection_wep(const QString &devName, const QString &ssid, const int key, const QString& passwd)
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

QString LrdNmAdaptor::add_connection_8021x(const QString &devName, const QString &ssid, const QString& eap, const QString& identity,
                    const QString& client,  const QString& ca, const QString& privateKey, const QString& passwd)
{   
    if(devName.isEmpty())
        return QString(); 
    
    return QString();                                                                                   
}

QString LrdNmAdaptor::add_connection_wpa(const QString& devName, const QString& ssid, const QString& passwd)
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

bool LrdNmAdaptor::update_connection_wired(const QString& devName, const QString& ip, const QString& netmask, const QString gateway)
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
    
    if(ip.isEmpty())
    {                                                                      
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
                                                                    
        addr1 << qToBigEndian(QHostAddress(ip).toIPv4Address()) << prefix 
              << qToBigEndian(QHostAddress(gateway).toIPv4Address());
        addresses << addr1;
                               
        mConnSettings[path]["ipv4"]["method"] = "manual";
        mConnSettings[path]["ipv4"]["addresses"] = QVariant::fromValue(addresses);      
    }

    nmIfc->update_connection(path, mConnSettings[path]);
    return true;
}

bool LrdNmAdaptor::activate_connection(const QString& devName, const QString& ssid)
{
    if(devName.isEmpty())
        return false;
    
    QString path = ssid_to_connection_path(ssid);
    if(path.isNull())
        return false;

    QString result = nmIfc->activate_connection(path);
    if(result.isNull())
        return false;

    return true;
}

void LrdNmAdaptor::delete_connection(const QString& devName, const QString& ssid)
{
    if(devName.isEmpty())
        return;
    
    QString path = ssid_to_connection_path(ssid);
    if(path.isNull())
        return;

    nmIfc->delete_connection(path);
    mConnPath[devName].removeOne(ssid);
    mConnSettings.remove(path);
    nmIfc->get_connections_by_device(devName, mDevPath[devName], mConnPath, mActiveConnPath, mIPv4ConfigPath);

    return;
}

void LrdNmAdaptor::disconnect_connection(const QString& devName)
{
    if(devName.isEmpty())
        return;
    
    QString path = mActiveConnPath[devName];
    if(path.isNull())
        return;

    nmIfc->disconnect_connection(path);
    nmIfc->get_connections_by_device(devName, mDevPath[devName], mConnPath, mActiveConnPath, mIPv4ConfigPath);
}


LrdNmAdaptor::~LrdNmAdaptor()
{
    delete nmIfc;
}
