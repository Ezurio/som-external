#ifndef ETHERNETSETTINGS_H
#define ETHERNETSETTINGS_H


#include "lrdnmAdaptor.h"
#include "ui_ethernetsettings.h"
#include "keyboard/keyboard.h"



namespace Ui {
class EthernetSettings;
}

class EthernetSettings : public QWidget, public Ui_EthernetSettings
{
    Q_OBJECT

public:
    EthernetSettings(QWidget *parent = 0);
    ~EthernetSettings();

private:
    Ui::EthernetSettings *ui;
    LrdNmAdaptor* nmAdaptor;
    Keyboard *kb;

signals:
    void send_exit();
    
private slots:
    void on_comboBox_device_currentIndexChanged(int index);
    void on_pushButton_con_connect_clicked();
    void on_pushButton_con_disconnect_clicked();
    void recv_key_backspace();
    void recv_key(QString key);
    bool eventFilter(QObject* watched,QEvent* event);
    
    void on_pushButton_refresh_clicked();
    
    void on_pushButton_exit_clicked();
    
private:
    QObject* focusItem;
};

#endif // ETHERNETSETTINGS_H
