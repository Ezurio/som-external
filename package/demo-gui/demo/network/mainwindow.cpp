#include "mainwindow.h"
#include "ui_mainwindow.h"

MainWindow::MainWindow(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    ui->pushButton_ts_cali->hide();
    //ui->pushButton_exit->hide();
    
    connect(&process, SIGNAL(finished(int,QProcess::ExitStatus)), this, SLOT(onProcessFinished(int, QProcess::ExitStatus))); 
    
    qApp->setQuitOnLastWindowClosed (true);
}

MainWindow::~MainWindow()
{
    delete ui;
}

void MainWindow::ethernet_setting_exit()
{
    es->deleteLater();
}

void MainWindow::on_pushButton_ethernet_setting_clicked()
{
    es = new EthernetSettings();
    connect(es, &EthernetSettings::send_exit, this, &MainWindow::ethernet_setting_exit);
    es->show();
}

void MainWindow::wireless_setting_exit()
{
    ws->deleteLater();
}

void MainWindow::on_pushButton_wireless_setting_clicked()
{
    ws = new WirelessSettings();
    connect(ws, &WirelessSettings::send_exit, this, &MainWindow::wireless_setting_exit);
    ws->show();
}

void MainWindow::time_setting_exit()
{
    ts->deleteLater();
}

void MainWindow::on_pushButton_time_setting_clicked()
{
    ts = new Timesettings();
    connect(ts, &Timesettings::send_exit, this, &MainWindow::time_setting_exit);
    ts->show();
}

void MainWindow::on_pushButton_display_time_clicked()
{
    if(ui->pushButton_display_time->text().contains("Stop"))
    {
        QString stopCmd = QString("killall systime");
        system(qPrintable(stopCmd));
        ui->pushButton_display_time->setText("Display Time");
    }
    else
    {
        QString displayCmd = QString("/opt/systime &");
        system(qPrintable(displayCmd));
        ui->pushButton_display_time->setText("Stop Display Time");
    }
}

void MainWindow::EnableWidges(bool flag)
{
    ui->pushButton_display_time->setEnabled(flag);
    ui->pushButton_ethernet_setting->setEnabled(flag);
    ui->pushButton_exit->setEnabled(flag);
    ui->pushButton_mine_hunt->setEnabled(flag);
    ui->pushButton_time_setting->setEnabled(flag);
    ui->pushButton_wireless_setting->setEnabled(flag);
}

void MainWindow::onProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    process.kill();
    
    EnableWidges(true);
    repaint();
}

void MainWindow::on_pushButton_mine_hunt_clicked()
{   
    process.setWorkingDirectory("/opt/minehunt/");
    process.setProgram("./minehunt");
    process.start();

    if (!process.waitForStarted())
        return;
    
    EnableWidges(false);
}

void MainWindow::on_pushButton_ts_cali_clicked()
{
    process.setProgram("/usr/bin/ts_calibrate");
    process.start();

    if (!process.waitForStarted())
    {
        qDebug() << process.exitStatus();
        return;
    }

    EnableWidges(false);
}

void MainWindow::on_pushButton_exit_clicked()
{
    if (ui->pushButton_display_time->text().contains("Stop"))
    {
        QString stopCmd = QString("killall systime");
        system(qPrintable(stopCmd));
    }
    
    close();
    
    QMetaObject::invokeMethod(qApp, "quit", Qt::QueuedConnection);
}


