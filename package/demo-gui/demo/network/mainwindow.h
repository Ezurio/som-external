#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QWidget>

#include "ethernetsettings.h"
#include "wirelesssettings.h"
#include "timesettings.h"

namespace Ui {
class MainWindow;
}

class MainWindow : public QWidget
{
    Q_OBJECT
    
public:
    explicit MainWindow(QWidget *parent = 0);
    ~MainWindow();
    
private slots:
    void on_pushButton_ethernet_setting_clicked();
    void on_pushButton_wireless_setting_clicked();
    void on_pushButton_time_setting_clicked();
    
    void ethernet_setting_exit();
    void wireless_setting_exit();
    void time_setting_exit();
    
    void on_pushButton_exit_clicked();
    void on_pushButton_display_time_clicked();
    void on_pushButton_mine_hunt_clicked();
    
    void onProcessFinished(int, QProcess::ExitStatus);
    
    void on_pushButton_ts_cali_clicked();
    
private:
    void EnableWidges(bool flag);
    
private:
    Ui::MainWindow* ui;
    EthernetSettings* es;
    WirelessSettings* ws;
    Timesettings* ts;
    QProcess process;
};

#endif // MAINWINDOW_H
