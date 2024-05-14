#ifndef WPAINPUTDLG_H
#define WPAINPUTDLG_H

#include "keyboard/keyboard.h"
#include "ui_wpainputdlg.h"

namespace Ui {
class WPAInputDlg;
}

class WPAInputDlg : public QWidget,public Ui_WPAInputDlg
{
    Q_OBJECT

public:
    explicit WPAInputDlg(QWidget *parent = 0);
    ~WPAInputDlg();

signals:
    void sendPasswd(QString passwd);

private slots:
    void recv_key(QString);
    void recv_key_backspace();
    bool eventFilter(QObject *,QEvent *);
    void on_pushButton_ok_clicked();
    void on_pushButton_cancel_clicked();


private:
    Ui::WPAInputDlg *ui;
    Keyboard* kb;
};

#endif // WPAINPUTDLG_H
