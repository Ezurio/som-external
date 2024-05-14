#include <QDateTime>
#include <QtDebug>


#include "timesettings.h"
#include "ui_timesettings.h"

Timesettings::Timesettings(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::Timesettings)
{
    setWindowFlags(Qt::FramelessWindowHint);
    ui->setupUi(this);
    setGeometry(100, 40, 600, 400);
    QDateTime dt = QDateTime::currentDateTime();
    ui->dateEdit->setDate(dt.date());
    ui->timeEdit->setTime(dt.time());
}

Timesettings::~Timesettings()
{
    delete ui;
}

void Timesettings::on_pushButton_ok_clicked()
{
    QDate dt = ui->dateEdit->date();
    QTime time = ui->timeEdit->time();
    
    QString dateCmd = QString("date -s %1-%2-%3").arg(QString::number(dt.year()), QString::number(dt.month()), QString::number(dt.day())); 
    QString timeCmd = QString("date -s %1:%2:%3").arg(QString::number(time.hour()), QString::number(time.minute()), QString::number(time.minute()));  
    
    system(qPrintable(dateCmd));
    system(qPrintable(timeCmd));
}

void Timesettings::on_pushButton_exit_clicked()
{
    send_exit();
    close();
}
