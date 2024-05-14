#include "wepinputdlg.h"
#include "ui_wepinputdlg.h"

WEPInputDlg::WEPInputDlg(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::WEPInputDlg)
{
    QStringList keySel = {"0","1","2","3"};
    setWindowFlags(Qt::FramelessWindowHint);
    //setAttribute( Qt::WA_DeleteOnClose, true );

    ui->setupUi(this);
    setGeometry(200,60,400,110);
    ui->comboBox_key_sel->addItems(keySel);
    
    ui->lineEdit_passwd->installEventFilter(this);

    kb = new Keyboard();
    connect(kb, &Keyboard::send_key, this, &WEPInputDlg::recv_key);
    connect(kb, &Keyboard::send_key_ok, this, &WEPInputDlg::on_pushButton_ok_clicked);
    connect(kb, &Keyboard::send_key_backspace, this, &WEPInputDlg::recv_key_backspace);
    kb->show();
}

WEPInputDlg::~WEPInputDlg()
{
    delete ui;
}

void WEPInputDlg::on_pushButton_ok_clicked()
{

    QString passwd = ui->lineEdit_passwd->text();
    QString key = ui->comboBox_key_sel->currentText();
    emit sendKeyAndPasswd(key, passwd);

    kb->close();
    close();

}

void WEPInputDlg::on_pushButton_cancel_clicked()
{

    kb->close();
    close();
}

void WEPInputDlg::recv_key(QString key)
{
    if(ui->lineEdit_passwd->hasFocus())
    {
        ui->lineEdit_passwd->insert(key);
    }

}

void WEPInputDlg::recv_key_backspace()
{
    if(ui->lineEdit_passwd->hasFocus())
    {
        ui->lineEdit_passwd->backspace();
    }
}

bool WEPInputDlg::eventFilter(QObject* watched,QEvent* event)
{

    if (watched == ui->lineEdit_passwd)
    {
        if (event->type() == QEvent::MouseButtonPress)
        {
            kb->show();
            return true;
        }
    }


   return QWidget::eventFilter(watched,event);
}
