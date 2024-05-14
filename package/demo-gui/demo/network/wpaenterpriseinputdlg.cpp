#include <QFileDialog>

#include "wpaenterpriseinputdlg.h"
#include "ui_wpaenterpriseinputdlg.h"

WPAEnterpriseIninputDlg::WPAEnterpriseIninputDlg(QWidget *parent) :
    QWidget(parent),
    ui(new Ui::WPAEnterpriseIninputDlg)
{
    const QStringList fastInnerAuthMethods= {"GTC", "MSCHAPv2"};
    const QStringList fastPacProvisioning = {"Anonymous", "Authenticated", "Both"};
    const QStringList peapInnerAuthMethods= {"MSCHAPv2","MD5", "GTC"};
    const QStringList peapVersions = {"Automatic", "Version 0","Version 1"};
    const QStringList authMethods = {"TLS", "LEAP", "PWD", "FAST", "Tunneled TLS", "PEAP"};
    const QStringList tunneledInnerAuthMethods = {"PAP", "MSCHAP", "MSCHAPv2", "CHAP", "MD5", "GTC"};   
    
    setWindowFlags(Qt::FramelessWindowHint);
    
    ui->setupUi(this);
    setGeometry(0,0,800,240);

    focusItem = NULL;
    
    ui->lineEdit_tunneled_identity->installEventFilter(this);
    ui->lineEdit_fast_identity->installEventFilter(this);
    ui->lineEdit_username->installEventFilter(this);
    ui->lineEdit_password->installEventFilter(this);
    ui->lineEdit_tls_identity->installEventFilter(this);
    ui->lineEdit_tls_passwd->installEventFilter(this);
    ui->lineEdit_peap_dentity->installEventFilter(this);

    //ui->comboBox_security->addItem("WPA & WPA2 Enterprise");
    ui->comboBox_auth->addItems(authMethods);
    ui->comboBox_fast_inner_auth->addItems(fastInnerAuthMethods);
    ui->comboBox_tunneled_inner_auth->addItems(tunneledInnerAuthMethods);
    ui->comboBox_peap_inner_auth->addItems(peapInnerAuthMethods);
    ui->comboBox_fast_PAC->addItems(fastPacProvisioning);
    ui->comboBox_peap_version->addItems(peapVersions);
    
    kb = new Keyboard();
    connect(kb, &Keyboard::send_key, this, &WPAEnterpriseIninputDlg::recv_key);
    connect(kb, &Keyboard::send_key_ok, this, &WPAEnterpriseIninputDlg::on_pushButton_ok_clicked);
    connect(kb, &Keyboard::send_key_backspace, this, &WPAEnterpriseIninputDlg::recv_key_backspace);
}



WPAEnterpriseIninputDlg::~WPAEnterpriseIninputDlg()
{
    delete kb;
    delete ui;
}

void WPAEnterpriseIninputDlg::on_comboBox_auth_currentIndexChanged(int index)
{
    if(index == 0)      //tls
    {
        ui->widget_tunneled_tls->hide();
        ui->widget_userinfo->hide();
        ui->widget_peap->hide();
        ui->widget_fast->hide();
        
        ui->widget_tls->show();

        ui->widget_top->setGeometry(0, 0, 500, 40);
        ui->widget_tls->setGeometry(0, 40, 500, 150);     
        ui->widget_bottom->setGeometry(0, 190, 500, 25);
        
        ui->widget_wifi_auth->setGeometry(150,0,500, 220);
    }
    else if (index == 1)    //leap
    {
        ui->widget_tunneled_tls->hide();
        ui->widget_tls->hide();
        ui->widget_peap->hide();
        ui->widget_fast->hide();
        
        ui->widget_userinfo->show();
        
        ui->widget_top->setGeometry(0, 0, 500, 40);
        ui->widget_userinfo->setGeometry(0, 40, 500, 60);
        ui->widget_bottom->setGeometry(0, 100, 500, 25);
        ui->widget_wifi_auth->setGeometry(150,0,500, 130);
    }
    else if (index == 2)        //pwd
    {
        ui->widget_tunneled_tls->hide();
        ui->widget_tls->hide();
        ui->widget_peap->hide();
        ui->widget_fast->hide();
        
        ui->widget_userinfo->show();
        
        ui->widget_top->setGeometry(0, 0, 500, 30);
        ui->widget_userinfo->setGeometry(0, 30, 500, 60);
        ui->widget_bottom->setGeometry(0, 90, 500, 25);
        ui->widget_wifi_auth->setGeometry(150,0,500, 120);
    }
    else if (index == 3)        //fast
    {

        ui->widget_tunneled_tls->hide();

        ui->widget_peap->hide();
        ui->widget_tls->hide();
        
        ui->widget_fast->show();
        ui->widget_userinfo->show();       


        ui->widget_top->setGeometry(0, 0, 500, 30);
        ui->widget_fast->setGeometry(0, 30, 500, 120);
        ui->widget_userinfo->setGeometry(0, 150, 500, 60);
        ui->widget_bottom->setGeometry(0, 210, 500, 25);
        ui->widget_wifi_auth->setGeometry(150,0,500, 240);
    }
    else if (index == 4)        //tunneled
    {
        
        ui->widget_fast->hide();
        ui->widget_userinfo->hide();
        ui->widget_peap->hide();
        
        ui->widget_tunneled_tls->show();
        ui->widget_userinfo->show(); 
        

        ui->widget_top->setGeometry(0, 0, 500, 30);
        ui->widget_tunneled_tls->setGeometry(0, 30, 500, 90);
        ui->widget_userinfo->setGeometry(0, 120, 500, 60);
        ui->widget_bottom->setGeometry(0, 180, 500, 25);
        ui->widget_wifi_auth->setGeometry(150,0,500, 210);
    }
    else if (index == 5)            //peap
    {
        ui->widget_tunneled_tls->hide();
        ui->widget_userinfo->hide();     
        ui->widget_tls->hide();
        
        ui->widget_peap->show();  
        ui->widget_userinfo->show(); 
               
        ui->widget_top->setGeometry(0, 0, 500, 30);
        ui->widget_peap->setGeometry(0, 30, 500, 120);
        ui->widget_userinfo->setGeometry(0, 150, 500, 60);
        ui->widget_bottom->setGeometry(0, 210, 500, 25);
        ui->widget_wifi_auth->setGeometry(150,0,500, 240);
    }
}


void WPAEnterpriseIninputDlg::recv_key(QString key)
{
    if(focusItem)
    {
        focusItem->insert(key);
    }    
}

void WPAEnterpriseIninputDlg::recv_key_backspace()
{
    if(focusItem)
    {
        focusItem->backspace();
    }  
}

bool WPAEnterpriseIninputDlg::eventFilter(QObject* watched,QEvent* event)
{
    if (event->type() == QEvent::MouseButtonPress)
    {   
        if( watched == ui->lineEdit_fast_identity)
            focusItem = ui->lineEdit_fast_identity;
        else if (watched == ui->lineEdit_password)
            focusItem = ui->lineEdit_password;
        else if (watched == ui->lineEdit_peap_dentity)
            focusItem = ui->lineEdit_peap_dentity;
        else if (watched == ui->lineEdit_tls_identity)
            focusItem = ui->lineEdit_tls_identity; 
        else if (watched == ui->lineEdit_tls_passwd)
            focusItem = ui->lineEdit_tls_passwd;
        else if (watched == ui->lineEdit_tunneled_identity)
            focusItem = ui->lineEdit_tunneled_identity;
        else if (watched == ui->lineEdit_username)
            focusItem = ui->lineEdit_username;
        else
            focusItem = NULL;
        
        if(focusItem)
            kb->show();
    }
    
    return QWidget::eventFilter(watched,event);
}

void WPAEnterpriseIninputDlg::on_pushButton_ok_clicked()
{
    kb->close();
    close();
}

void WPAEnterpriseIninputDlg::on_pushButton_cancel_clicked()
{
    kb->close();
    close();
}

void WPAEnterpriseIninputDlg::on_pushButton_tunneled_open_cacert_clicked()
{
    QString fileName = QFileDialog::getOpenFileName(this,
         tr("Open CA certificate"), "/home/", tr("CA Certificate Files (*.ca)"));
    ui->pushButton_tunneled_open_cacert->setText(fileName);
}

void WPAEnterpriseIninputDlg::on_pushButton_peap_open_cacert_clicked()
{
    QString fileName = QFileDialog::getOpenFileName(this,
         tr("Open CA certificate"), "/home/", tr("CA Certificate Files (*.ca)"));
    ui->pushButton_peap_open_cacert->setText(fileName);
}

void WPAEnterpriseIninputDlg::on_pushButton_tls_open_usercert_clicked()
{
    QString fileName = QFileDialog::getOpenFileName(this,
         tr("Open user certificate"), "/home/", tr("CA Certificate Files (*.user)"));
    ui->pushButton_tls_open_usercert->setText(fileName);
}

void WPAEnterpriseIninputDlg::on_pushButton_tls_open_cacert_clicked()
{
    QString fileName = QFileDialog::getOpenFileName(this,
         tr("Open CA certificate"), "/home/", tr("CA Certificate Files (*.ca)"));
    ui->pushButton_tls_open_cacert->setText(fileName);
}

void WPAEnterpriseIninputDlg::on_pushButton_tls_open_prikey_clicked()
{
    QString fileName = QFileDialog::getOpenFileName(this,
         tr("Open private key"), "/home/", tr("Key Files (*.key)"));
    ui->pushButton_tls_open_prikey->setText(fileName);
}

void WPAEnterpriseIninputDlg::on_pushButton_fast_open_pacfile_clicked()
{
    QString fileName = QFileDialog::getOpenFileName(this,
         tr("Open PAC key"), "/home/", tr("PAC Files (*.pac)"));
    ui->pushButton_fast_open_pacfile->setText(fileName);
}
