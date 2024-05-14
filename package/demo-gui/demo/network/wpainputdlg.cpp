#include "wpainputdlg.h"

WPAInputDlg::WPAInputDlg(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::WPAInputDlg)
{
    setWindowFlags(Qt::FramelessWindowHint);
    //setAttribute( Qt::WA_DeleteOnClose, true );

    ui->setupUi(this);
    setGeometry(200,60,400,90);
    ui->lineEdit_passwd->installEventFilter(this);

    kb = new Keyboard();
    connect(kb, &Keyboard::send_key, this, &WPAInputDlg::recv_key);
    connect(kb, &Keyboard::send_key_ok, this, &WPAInputDlg::on_pushButton_ok_clicked);
    connect(kb, &Keyboard::send_key_backspace, this, &WPAInputDlg::recv_key_backspace);
    kb->show();
}

WPAInputDlg::~WPAInputDlg()
{
    delete kb;
    delete ui;
}

void WPAInputDlg::on_pushButton_ok_clicked()
{

    QString passwd = ui->lineEdit_passwd->text();
    emit sendPasswd(passwd);

    kb->close();
    close();

}

void WPAInputDlg::on_pushButton_cancel_clicked()
{

    kb->close();
    close();
}

void WPAInputDlg::recv_key(QString key)
{
    if(ui->lineEdit_passwd->hasFocus())
    {
        ui->lineEdit_passwd->insert(key);
    }

}

void WPAInputDlg::recv_key_backspace()
{
    if(ui->lineEdit_passwd->hasFocus())
    {
        ui->lineEdit_passwd->backspace();
    }
}

bool WPAInputDlg::eventFilter(QObject* watched,QEvent* event)
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

