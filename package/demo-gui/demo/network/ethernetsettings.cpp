#include <QFile>
#include <QTextStream>
#include <QtDebug>
#include <QPushButton>
#include <QObject>
#include <QCoreApplication>
#include <QHostAddress>
#include <QNetworkInterface>
#include <QNetworkAddressEntry>

#include "ethernetsettings.h"

EthernetSettings::EthernetSettings(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::EthernetSettings)
{
    QStringList methods = {"Dhcp", "Manual"};

    ui->setupUi(this);
    
    setGeometry(100,0,600,240);
    
    focusItem = NULL;
    
    ui->lineEdit_ipv4->installEventFilter(this);
    ui->lineEdit_gateway->installEventFilter(this);
    ui->lineEdit_netmask->installEventFilter(this);
    
    nmAdaptor = new LrdNmAdaptor();
    
    QStringList devList = nmAdaptor->get_devices_by_type(NM_DEVICE_TYPE_ETHERNET);
    ui->comboBox_device->addItems(devList);
    ui->comboBox_method->addItems(methods);

    kb = new Keyboard();
    connect(kb, &Keyboard::send_key, this, &EthernetSettings::recv_key);
    connect(kb, &Keyboard::send_key_ok, this, &EthernetSettings::on_pushButton_con_connect_clicked);
    connect(kb, &Keyboard::send_key_backspace, this, &EthernetSettings::recv_key_backspace); 
}

void EthernetSettings::on_comboBox_device_currentIndexChanged(int index)
{
    
    if(nmAdaptor->get_ipv4_method(ui->comboBox_device->currentText()) == "Manual")
        ui->comboBox_method->setCurrentText("Manual");
    else
        ui->comboBox_method->setCurrentText("Dhcp");
}

void EthernetSettings::on_pushButton_con_connect_clicked()
{
    QString devName = ui->comboBox_device->currentText();
    QString ip, netmask, gateway;
    
    kb->hide();
    
    if(!ui->comboBox_method->currentText().compare("Manual"))
    {
        ip = ui->lineEdit_ipv4->text();
        netmask = ui->lineEdit_netmask->text();
        gateway = ui->lineEdit_gateway->text();
        
    }
    else
    {
        ip.clear();
        netmask.clear();
        gateway.clear();
    }
    
    nmAdaptor->update_connection_wired(devName, ip, netmask, gateway);
    nmAdaptor->activate_connection(devName, devName);
}

void EthernetSettings::on_pushButton_con_disconnect_clicked()
{
    QString devName = ui->comboBox_device->currentText();
    nmAdaptor->disconnect_connection(devName);
}

EthernetSettings::~EthernetSettings()
{
    delete kb;
    delete nmAdaptor;
}

void EthernetSettings::recv_key(QString key)
{
    if(focusItem)
    {
        QLineEdit *tmp = static_cast<QLineEdit *>(focusItem);
        tmp->insert(key);
    }
}

void EthernetSettings::recv_key_backspace()
{
    if(focusItem)
    {
        QLineEdit *tmp = static_cast<QLineEdit *>(focusItem);
        tmp->backspace();
    }
}

bool EthernetSettings::eventFilter(QObject* watched,QEvent* event)
{ 
    if(watched == ui->lineEdit_ipv4 || watched == ui->lineEdit_netmask || watched == ui->lineEdit_gateway)
    {
        if (event->type() == QEvent::MouseButtonPress)
        {
            if(watched == ui->lineEdit_ipv4)
                focusItem = ui->lineEdit_ipv4;
            else if (watched == ui->lineEdit_netmask)
                focusItem = ui->lineEdit_netmask;
            else if (watched == ui->lineEdit_gateway)
                focusItem = ui->lineEdit_gateway;
            
            kb->show();
        }
    }

    return QWidget::eventFilter(watched,event);
}

void EthernetSettings::on_pushButton_refresh_clicked()
{
    QString devName = ui->comboBox_device->currentText();
    QString ipaddr, gateway, netmask;
    
    nmAdaptor->get_ipv4_info_by_device(devName, ipaddr, gateway, netmask);
    
    ui->lineEdit_ipv4->setText(ipaddr);
    ui->lineEdit_netmask->setText(netmask);
    ui->lineEdit_gateway->setText(gateway);
    
    on_comboBox_device_currentIndexChanged(0);
}

void EthernetSettings::on_pushButton_exit_clicked()
{
    emit send_exit();
    close();
}
