#ifndef WPAENTERPRISEINPUTDLG_H
#define WPAENTERPRISEINPUTDLG_H

#include <QWidget>
#include <QLineEdit>

#include "keyboard/keyboard.h"

namespace Ui {
class WPAEnterpriseIninputDlg;
}

class WPAEnterpriseIninputDlg : public QWidget
{
    Q_OBJECT

public:
    explicit WPAEnterpriseIninputDlg(QWidget *parent = 0);
    ~WPAEnterpriseIninputDlg();

signals:
    void sendPasswd(QString security, QString auth, QString identity, QString ca, bool noCA,
                    QString innerAuth, QString username, QString password);

private slots:
    void recv_key(QString);
    void recv_key_backspace();
    bool eventFilter(QObject *,QEvent *);
    void on_pushButton_ok_clicked();
    void on_pushButton_cancel_clicked();
    void on_comboBox_auth_currentIndexChanged(int index);
    void on_pushButton_tunneled_open_cacert_clicked();
    void on_pushButton_peap_open_cacert_clicked();
    void on_pushButton_tls_open_usercert_clicked();
    void on_pushButton_tls_open_cacert_clicked();
    void on_pushButton_tls_open_prikey_clicked();
    void on_pushButton_fast_open_pacfile_clicked();
private:
    QLineEdit* getFocusedLineEdit();
private:
    Ui::WPAEnterpriseIninputDlg *ui;
    Keyboard* kb;
    QLineEdit *focusItem;
};

#endif // WPAENTERPRISEINPUTDLG_H
