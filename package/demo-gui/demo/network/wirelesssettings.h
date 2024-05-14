#ifndef WIRELESSSETTINGS_H
#define WIRELESSSETTINGS_H


#include "lrdnmAdaptor.h"
#include "ui_wirelesssettings.h"

#include "wepinputdlg.h"
#include "wpainputdlg.h"
#include "wpaenterpriseinputdlg.h"


namespace Ui {
class WirelessSettings;
}

class WirelessSettings : public QWidget, public Ui_WirelessSettings
{
    Q_OBJECT

public:
    explicit WirelessSettings(QWidget *parent = 0);
    ~WirelessSettings();

private:
    Ui::WirelessSettings *ui;
    LrdNmAdaptor* nmAdaptor;
    QMutex mutex;
    
signals:
    void send_exit();

private slots:

    void on_pushButton_con_connect_clicked();
    void on_pushButton_con_disconnect_clicked();
    void on_pushButton_con_delete_clicked();
    void do_wifi_connect(QString passwd);
    void do_wifi_connect_wep(QString key, QString passwd);
    void on_pushButton_ui_refresh_clicked();
    void on_pushButton_exit_clicked();
    void on_pushButton_ap_update_clicked();
    
private:
    void add_ap();
    void do_refresh_connections();
    void do_refresh_accesspoints();
    QString ap_security_flag_to_string(int flags, int wpaFlags);
    int ap_security_string_to_flag(QString type);



};

#endif // WIRELESSSETTINGS_H
