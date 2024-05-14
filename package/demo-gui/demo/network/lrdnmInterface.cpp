#include <QtNetwork/QHostAddress>                                                                   
#include <arpa/inet.h>                                                                              
#include <QtEndian> 

#include "lrdnmInterface.h"


LrdNmInterface::LrdNmInterface()
{
    nm = new QDBusInterface(
        NM_DBUS_SERVICE,
        NM_DBUS_PATH,
        NM_DBUS_INTERFACE,
            QDBusConnection::systemBus());

    settings = new QDBusInterface (
         NM_DBUS_SERVICE,
         NM_DBUS_PATH_SETTINGS,
         NM_DBUS_INTERFACE_SETTINGS,
             QDBusConnection::systemBus());
}

void LrdNmInterface::get_all_devices(QMap<int32_t, QStringList>& mDevName, QMap<QString, QString>& mDevPath)
{
    QDBusReply<QList<QDBusObjectPath> > pathList = nm->call("GetAllDevices");

    if(!pathList.isValid()) return;

    mDevName.clear();
    mDevPath.clear();

    foreach (const QDBusObjectPath& path, pathList.value()) {

        QDBusInterface ifc(
            NM_DBUS_SERVICE,
            path.path(),
            NM_DBUS_INTERFACE_DEVICE,
                QDBusConnection::systemBus());
        if(ifc.isValid())
        {
            QString name = ifc.property("Interface").toString();
            int32_t type = ifc.property("DeviceType").toInt();
            mDevName[type].append(name);
            mDevPath.insert(name, path.path());
       }
    }
}

void LrdNmInterface::get_connection_settings_by_path(const QString& connPath, QMap<QString,
                                                               NMVariantMapMap>& mConnSettings)
{
    if(!mConnSettings[connPath].isEmpty())
        mConnSettings[connPath].clear();


    QDBusInterface ifc(
        NM_DBUS_SERVICE,
        connPath,
        NM_DBUS_INTERFACE_SETTINGS_CONNECTION,
            QDBusConnection::systemBus());
    if(ifc.isValid())
    {
         QDBusReply<NMVariantMapMap> settings = ifc.call("GetSettings");
         if(settings.isValid())
         {
             mConnSettings[connPath] = settings.value();
         }
    }
}

void  LrdNmInterface::get_accesspoint_list_by_device_path(const QString devName, const QString& devPath,
                                                                    QMap<QString, QStringList>& mSsid,
                                                                    QMap<QString, QVector<int> >& mAccessPointSecurity)
{
    int flag;

    QDBusInterface ifc(
       NM_DBUS_SERVICE,
       devPath,
       NM_DBUS_INTERFACE_DEVICE_WIRELESS,
           QDBusConnection::systemBus());
    if(ifc.isValid())
    {
        mSsid[devName].clear();

        QDBusReply<QList<QDBusObjectPath> > result = ifc.call("GetAllAccessPoints");
        foreach (const QDBusObjectPath& path, result.value())
        {

            QDBusInterface apIfc (
               NM_DBUS_SERVICE,
               path.path(),
               NM_DBUS_INTERFACE_ACCESS_POINT,
                   QDBusConnection::systemBus());

            if(!apIfc.isValid())
                continue;

            QString ssid = apIfc.property("Ssid").toString();
            if(ssid.isEmpty())
                continue;

            mSsid[devName].append(ssid);
            mAccessPointSecurity[ssid].clear();
            
            flag = apIfc.property("Flags").toInt();
            mAccessPointSecurity[ssid].append(flag);
            
            flag = apIfc.property("WpaFlags").toInt();
            if(flag == 0) 
                flag = apIfc.property("RsnFlags").toInt();
            
            mAccessPointSecurity[ssid].append(flag);
        }
    }
}

QVariant LrdNmInterface::basicTypeToVariant(const QDBusArgument &arg) 
{
    
    return arg.asVariant();
}

QVariantList LrdNmInterface::arrayTypeToVariant(const QDBusArgument &arg) 
{
    QVariantList list;
    arg.beginArray();

    while (!arg.atEnd()) 
    {
        list << dbusArgumentToVariant(arg);
    }

    arg.endArray();
    return list;
}

QVariantMap LrdNmInterface::mapTypeToVariant(const QDBusArgument &arg) 
{
    QString key;
    QVariant value;
    QVariantMap map;
    
    arg.beginMap();

    while (!arg.atEnd()) 
    {
        arg.beginMapEntry();
        key = basicTypeToVariant(arg).toString();
        value = dbusArgumentToVariant(arg);
        map[key] = QVariant::fromValue(value);
        arg.endMapEntry();
    }

    arg.endMap();
    
    ipv4.append(map);
    
    return map;
}

//IPv4 Config
QVariant LrdNmInterface::dbusArgumentToVariant(const QDBusArgument &arg) 
{
    switch (arg.currentType()) 
    {
        case QDBusArgument::BasicType:
        case QDBusArgument::VariantType:
            return basicTypeToVariant(arg);
        case QDBusArgument::ArrayType:
            return arrayTypeToVariant(arg);
        case QDBusArgument::MapType:
            return mapTypeToVariant(arg);
        default:
            qDebug() << "dbusArgumentToVariant. Type not handled.";
            return QVariant();
    }
}

void LrdNmInterface::get_ipv4_config(const QString& ipConnPath, QString& ipaddr, QString& mask, QString& gateway)
{
    QDBusInterface ifc (
        NM_DBUS_SERVICE,
        ipConnPath,
        //NM_DBUS_INTERFACE_IP4_CONFIG,
        LRD_DBUS_PROPERTIES_INTERFACE,
        QDBusConnection::systemBus());
    
    QDBusMessage msg = ifc.call("Get", NM_DBUS_INTERFACE_IP4_CONFIG, "AddressData");
    if (msg.type() != QDBusMessage::ReplyMessage)
        return;
    
    uint32_t prefix, shift;    
    QDBusVariant first = msg.arguments().at(0).value<QDBusVariant>();
    QDBusArgument dbusArgs = first.variant().value<QDBusArgument>();
    
    ipv4.clear();
    
    dbusArgumentToVariant(dbusArgs);
    
    if(ipv4.size() < 1) return;
    
    //The first one is to be used
    QVariantMap vm = ipv4.at(0);
    first = qdbus_cast<QDBusVariant>(vm["address"]);  
    ipaddr = first.variant().toString();
    
    first =  qdbus_cast<QDBusVariant>(vm["prefix"]);
    shift = first.variant().toUInt();
    prefix = 0xFFFFFFFF >> (32-shift);
    prefix = prefix << (32-shift);
    mask = QHostAddress(prefix).toString();

    QDBusInterface ifc2 (
        NM_DBUS_SERVICE,
        ipConnPath,
        NM_DBUS_INTERFACE_IP4_CONFIG,
        QDBusConnection::systemBus());
    
    gateway = ifc2.property("Gateway").toString();
}

void LrdNmInterface::get_connections_by_device(const QString& devName, const QString& devPath,
                                                         QMap<QString, QStringList>& mConn,
                                                         QMap<QString, QString>& mActiveConn,
                                                         QMap<QString, QString>& mIPv4ConfigPath)
{
    QVariant qvar;

    mConn[devName].clear();
    mActiveConn[devName].clear();
    mIPv4ConfigPath[devName].clear();
    
    QDBusInterface ifc (
        NM_DBUS_SERVICE,
        devPath,
        NM_DBUS_INTERFACE_DEVICE,
            QDBusConnection::systemBus());
    if(ifc.isValid())
    {
        qvar = ifc.property("AvailableConnections");
        if(qvar.isValid())
        {
            QList<QDBusObjectPath> paths = qvariant_cast<QList<QDBusObjectPath> >(qvar);
            foreach (const QDBusObjectPath& tmp, paths)
                mConn[devName].append(tmp.path());
         }
        
        qvar = ifc.property("ActiveConnection");
        if(qvar.isValid())
        {
            QDBusObjectPath path = qvariant_cast<QDBusObjectPath>(qvar);
            mActiveConn[devName] = path.path();
        }
        
        qvar = ifc.property("Ip4Config");
        if(qvar.isValid())
        {
            QDBusObjectPath path = qvariant_cast<QDBusObjectPath>(qvar);
            mIPv4ConfigPath[devName] = path.path();
        }
    }
}

QString LrdNmInterface::add_connection(const NMVariantMapMap& connsettings)
{
    QDBusReply<QDBusObjectPath> result = settings->call("AddConnection", QVariant::fromValue(connsettings));

    return result.isValid() ? result.value().path() : NULL;

}

QString LrdNmInterface::activate_connection(const QString& connPath)
{
    QDBusObjectPath o1(connPath), o2("/"), o3("/");
    QDBusReply<QDBusObjectPath> result = nm->call("ActivateConnection", QVariant::fromValue(o1),
                                                         QVariant::fromValue(o2), QVariant::fromValue(o3));
    return result.isValid() ? result.value().path() : NULL;
}

 void LrdNmInterface::update_connection(const QString& connPath, const NMVariantMapMap& connsettings)
 {
     QDBusInterface ifc (
         NM_DBUS_SERVICE,
         connPath,
         NM_DBUS_INTERFACE_SETTINGS_CONNECTION,
             QDBusConnection::systemBus());
     if(ifc.isValid())
     {
         QVariant tmp = QVariant::fromValue(connsettings);
         if(tmp.isNull())
             return;
         ifc.call("Update", tmp);
     }
 }

void  LrdNmInterface::disconnect_connection(const QString& connPath)
{
    QDBusObjectPath o1(connPath);
    nm->call("DeactivateConnection", QVariant::fromValue(o1));
}

void  LrdNmInterface::delete_connection(const QString& connPath)
{
    QDBusInterface ifc (
        NM_DBUS_SERVICE,
        connPath,
        NM_DBUS_INTERFACE_SETTINGS_CONNECTION,
            QDBusConnection::systemBus());
    if(ifc.isValid())
    {
        ifc.call("Delete");
    }
}

LrdNmInterface::~LrdNmInterface()
{
    
    delete settings;
    delete nm;
}


