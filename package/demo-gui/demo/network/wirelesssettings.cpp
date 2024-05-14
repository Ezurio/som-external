#include <QFile>
#include <QTextStream>
#include <QtDebug>
#include <QPushButton>
#include <QObject>
#include <QCoreApplication>
#include <QTimer>

#include "wirelesssettings.h"

QString WirelessSettings::ap_security_flag_to_string(int flags, int wpaFlags)
{
    QStringList s;

    if (wpaFlags == NM_802_11_AP_SEC_NONE)
    {
        if(flags > 0)
            return "WEP";
        return "OPEN";
    }

    if(wpaFlags & (NM_802_11_AP_SEC_PAIR_CCMP | NM_802_11_AP_SEC_GROUP_CCMP))
        s.append("WPA2");

    if(wpaFlags & (NM_802_11_AP_SEC_PAIR_TKIP | NM_802_11_AP_SEC_GROUP_TKIP))
        s.append("WPA1");

    if (wpaFlags & NM_802_11_AP_SEC_KEY_MGMT_802_1X)
        s.append("802.1X");

    return s.join(" ");
}

void WirelessSettings::do_refresh_connections()
{
    QString devName = comboBox_device->currentText();
    QStringList connList = nmAdaptor->get_connections_by_device(devName);
    QString ipaddr, gateway, netmask;

    nmAdaptor->get_ipv4_info_by_device(devName, ipaddr, gateway, netmask);
    lineEdit_ipv4->setText(ipaddr);
    lineEdit_netmask->setText(netmask);
    lineEdit_gateway->setText(gateway);
}

WirelessSettings::WirelessSettings(QWidget *parent) :
    QWidget(parent)
{

    setupUi(this);

    nmAdaptor = new LrdNmAdaptor();
    QStringList devList = nmAdaptor->get_devices_by_type(NM_DEVICE_TYPE_WIFI);
    comboBox_device->clear();
    comboBox_device->addItems(devList);

    on_pushButton_ui_refresh_clicked();

}

void WirelessSettings::on_pushButton_ui_refresh_clicked()
{
    do_refresh_connections();
}

void WirelessSettings::do_wifi_connect(QString passwd)
{
    QString ssid = tableWidget_aplist->item(tableWidget_aplist->currentRow(), 0)->text();
    QString security = tableWidget_aplist->item(tableWidget_aplist->currentRow(), 1)->text();
    QString res = nmAdaptor->add_connection_wpa(comboBox_device->currentText(), ssid, passwd);
    if(res.isEmpty())
        return;
    return;
}

void WirelessSettings::do_wifi_connect_wep(QString key, QString passwd)
{
   QString ssid = tableWidget_aplist->item(tableWidget_aplist->currentRow(), 0)->text();
   QString security = tableWidget_aplist->item(tableWidget_aplist->currentRow(), 1)->text();
   QString res = nmAdaptor->add_connection_wep(comboBox_device->currentText(), ssid, key.toInt(), passwd);
   if(res.isEmpty())
       return;
   return;
}

void WirelessSettings::on_pushButton_ap_update_clicked()
{
    int row;
    QVector<int>flags;

    nmAdaptor->do_scan_accesspoint_list(comboBox_device->currentText());
    QStringList aps = nmAdaptor->get_accesspoint_list(comboBox_device->currentText());

    this->setEnabled(false);
    foreach(QString ap, aps)
    {
        if(!tableWidget_aplist->findItems(ap, Qt::MatchCaseSensitive).isEmpty())
        {
            continue;
        }
        row = tableWidget_aplist->rowCount();
        tableWidget_aplist->insertRow(row);
        tableWidget_aplist->setItem(row, 0, new QTableWidgetItem(ap));
        flags = nmAdaptor->get_accesspoint_security_type(ap);
        tableWidget_aplist->setItem(row, 1, new QTableWidgetItem(ap_security_flag_to_string(flags[0], flags[1])));
    }

    this->setEnabled(true);
    if(tableWidget_aplist->rowCount() < 1) return;
    tableWidget_aplist->sortByColumn(0, Qt::AscendingOrder);
}

void WirelessSettings::add_ap()
{
    if(tableWidget_aplist->currentRow() < 0) return;
    QString ssid = tableWidget_aplist->item(tableWidget_aplist->currentRow(), 0)->text();
    QString security = tableWidget_aplist->item(tableWidget_aplist->currentRow(), 1)->text();

    if(nmAdaptor->is_added(ssid))
        return;

    if(!security.compare("WEP", Qt::CaseInsensitive))
    {
        WEPInputDlg* wepDlg = new WEPInputDlg();
        connect(wepDlg, &WEPInputDlg::sendKeyAndPasswd, this, &WirelessSettings::do_wifi_connect_wep);
        wepDlg->show();
        return;
    }
    else if(security.contains("802.1X"))
    {
        //WPA Enterprise not supported for the time being
    }
    else if(security.contains("WPA"))
    {
        WPAInputDlg* wpaDlg = new WPAInputDlg();
        connect(wpaDlg, &WPAInputDlg::sendPasswd, this, &WirelessSettings::do_wifi_connect);
        wpaDlg->show();
        return;
    }
    else if(!security.compare("OPEN", Qt::CaseInsensitive))
    {
        nmAdaptor->add_connection_open(comboBox_device->currentText(), ssid);
    }

    return;
}

void WirelessSettings::on_pushButton_con_connect_clicked()
{
    if(tableWidget_aplist->currentRow() < 0) return;

    QString devName = comboBox_device->currentText();
    QString ssid = tableWidget_aplist->item(tableWidget_aplist->currentRow(), 0)->text();

    if(!nmAdaptor->is_added(ssid))
        add_ap();
    nmAdaptor->activate_connection(devName, ssid);
}

void WirelessSettings::on_pushButton_con_disconnect_clicked()
{
    QString devName = comboBox_device->currentText();
    nmAdaptor->disconnect_connection(devName);
}

void WirelessSettings::on_pushButton_con_delete_clicked()
{
    if(tableWidget_aplist->currentRow() < 0) return;
    QString devName = comboBox_device->currentText();
    QString ssid = tableWidget_aplist->item(tableWidget_aplist->currentRow(), 0)->text();
    nmAdaptor->delete_connection(devName, ssid);
}

WirelessSettings::~WirelessSettings()
{
    delete nmAdaptor;
}

void WirelessSettings::on_pushButton_exit_clicked()
{
    emit send_exit();
    close();
}

