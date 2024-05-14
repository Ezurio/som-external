#ifndef WEPINPUTDLG_H
#define WEPINPUTDLG_H

#include <QWidget>
#include "keyboard/keyboard.h"


namespace Ui {
class WEPInputDlg;
}

class WEPInputDlg : public QWidget
{
    Q_OBJECT
    
public:
    explicit WEPInputDlg(QWidget *parent = 0);
    ~WEPInputDlg();

signals:
    void sendKeyAndPasswd(QString key, QString passwd);

private slots:
    void recv_key(QString);
    void recv_key_backspace();
    bool eventFilter(QObject *,QEvent *);
    void on_pushButton_ok_clicked();
    void on_pushButton_cancel_clicked();

private:
    Ui::WEPInputDlg *ui;
    Keyboard* kb;
    
};

#endif // WEPINPUTDLG_H
