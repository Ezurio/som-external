#ifndef TIMESETTINGS_H
#define TIMESETTINGS_H

#include <QWidget>

namespace Ui {
class Timesettings;
}

class Timesettings : public QWidget
{
    Q_OBJECT
    
public:
    explicit Timesettings(QWidget *parent = 0);
    ~Timesettings();
    
signals:
    void send_exit();
    
private slots:
    
    void on_pushButton_ok_clicked();
    
    void on_pushButton_exit_clicked();
    
private:
    Ui::Timesettings *ui;
};

#endif // TIMESETTINGS_H
