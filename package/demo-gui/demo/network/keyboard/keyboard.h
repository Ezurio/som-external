#ifndef KEYBOARD_H
#define KEYBOARD_H

#include "ui_keyboard.h"

namespace Ui {
class Keyboard;
}

class Keyboard : public QWidget, public Ui_Keyboard
{
    Q_OBJECT
    
public:
    explicit Keyboard(QWidget *parent = 0);
    ~Keyboard();

signals:
    void send_key(QString);
    void send_key_ok();
    void send_key_backspace();
    
private slots:
    void keyboardHandler();
    void on_shiftButton_clicked();
    void on_escButton_clicked();
    void on_enterButton_clicked();
    void on_backButton_clicked();
    void on_altButton_clicked();

private:
    Ui::Keyboard *ui;
    //QString outputText;
    bool shift;
    bool alt;

public:
    void show();
    void hide();

};

#endif // KEYBOARD_H
