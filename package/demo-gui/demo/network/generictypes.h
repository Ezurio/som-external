/*
    This file is part of the KDE project
    Copyright 2008 Will Stephenson <wstephenson@kde.org>
    Copyright 2013 Jan Grulich <jgrulich@redhat.com>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) version 3, or any
    later version accepted by the membership of KDE e.V. (or its
    successor approved by the membership of KDE e.V.), which shall
    act as a proxy defined in Section 6 of version 3 of the license.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef GENERIC_TYPES_H
#define GENERIC_TYPES_H

#include <QtCore/QVariantMap>
#include <QDBusArgument>

#include "libnm/nm-dbus-interface.h"

#define LRD_DBUS_PROPERTIES_INTERFACE "org.freedesktop.DBus.Properties"

typedef QList<QList<uint> > UIntListList;
Q_DECLARE_METATYPE(UIntListList)

typedef QList<uint> UIntList;
Q_DECLARE_METATYPE(UIntList)

typedef QMap<QString, QVariantMap> NMVariantMapMap;
Q_DECLARE_METATYPE(NMVariantMapMap)

typedef QList<QVariantMap> NMVariantMapList;
Q_DECLARE_METATYPE(NMVariantMapList)

typedef QMap<QString, QString> NMStringMap;
typedef QMapIterator<QString, QString> NMStringMapIterator;
Q_DECLARE_METATYPE(NMStringMap)

QDBusArgument &operator<<(QDBusArgument &argument, const NMStringMap &mydict);
const QDBusArgument &operator>>(const QDBusArgument &argument, NMStringMap &mydict);

#if 0
typedef struct {
    QByteArray address;
    uint prefix;
    QByteArray peer;
    QByteArray label;
} IpV4DBusAddress;

Q_DECLARE_METATYPE(IpV4DBusAddress)
typedef QList<IpV4DBusAddress> IpV4DBusAddressList;
Q_DECLARE_METATYPE(IpV4DBusAddressList)

QDBusArgument &operator<<(QDBusArgument &argument, const IpV4DBusAddress &address);
const QDBusArgument &operator>>(const QDBusArgument &argument, IpV4DBusAddress &address);

QDBusArgument &operator<<(QDBusArgument &argument, const IpV4DBusAddressList &addressList);
const QDBusArgument &operator>>(const QDBusArgument &argument, IpV4DBusAddressList &addressList);
#endif
#endif // GENERIC_TYPES_H
