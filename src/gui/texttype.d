module gui.texttype;

/* A GUI element to enter numbers or text by typing on the keyboard.
 * Can be set to accept only digits. There is potential to improve this,
 * by choosing more carefully where pruneText() and pruneDigits() are called.
 * Maybe it should be abstract, with subclasses for different allowed chars.
 */

import std.conv; // filter result to string
import std.algorithm; // filter
import std.string; // stringz

import basics.alleg5;
import basics.globals; // ticksForDoubleClick
import basics.help;
import gui;
import hardware.keyboard;
import hardware.mouse;

class Texttype : Button {

    enum AllowedChars { unicode, filename, digits }
    enum caretChar = '|';

private:

    Label _label;

    string _text;
    string _textBackupForCancelling;

    bool _invisibleBG;
    bool _allowScrolling;

    void delegate() _onEnter;
    void delegate() _onEsc;

public:

    this(Geom g)
    {
        super(g);
        _label = new Label(TextButton.newGeomForLeftAlignedLabelInside(g));
        addChild(_label);
    }

    AllowedChars allowedChars;

    mixin (GetSetWithReqDraw!"invisibleBG");
    mixin (GetSetWithReqDraw!"allowScrolling");

    @property onEnter(void delegate() f) { _onEnter = f; }
    @property onEsc  (void delegate() f) { _onEsc   = f; }
    @property string text() const { return _text; }
    @property string text(in string s)
    {
        if (s == _text)
            return s;
        _text = s;
        pruneText();
        reqDraw();
        return s;
    }

    @property nothrow int number() const
    {
        try               return _text.to!int;
        catch (Exception) return 0;
    }

    override @property bool on() const { return super.on; }
    override @property bool on(in bool b)
    {
        if (b == on)
            return b;
        super.on(b);
        if (b) {
            addFocus(this);
            _textBackupForCancelling = _text;
            _label.color = super.colorText;
        }
        else {
            rmFocus(this);
            _label.color = super.colorText;
        }
        return b;
    }

protected:

    override void calcSelf()
    {
        super.calcSelf();
        if (!on)
            on = super.execute;
        else {
            reqDraw(); // for the blinking cursor
            handleOnAndTyping();
        }
    }

    override void drawOntoButton()
    {
        _label.text = ! on || timerTicks % ticksForDoubleClick
                              < ticksForDoubleClick/2
            ? _text : _text ~ caretChar;
    }

private:

    void handleOnAndTyping()
    {
        if (mouseClickLeft || mouseClickRight || ALLEGRO_KEY_ENTER.keyTapped) {
            on = false;
            pruneDigits();
            if (_onEnter !is null)
                _onEnter();
        }
        else if (ALLEGRO_KEY_ESCAPE.keyTapped) {
            on = false;
            text = _textBackupForCancelling;
            if (_onEsc !is null)
                _onEsc();
        }
        else
            handleTyping();
    }

    void handleTyping()
    {
        if (backspace) {
            _text = backspace(_text);
            pruneText();
        }
        if (utf8Input != "") {
            _text ~= utf8Input();
            pruneText();
        }
    }

    void pruneText()
    {
        reqDraw();
        if (allowedChars == AllowedChars.filename)
            _text = escapeStringForFilename(_text);
        else if (allowedChars == AllowedChars.digits) {
            bool pred(dchar c) { return c >= '0' && c <= '9'; }
            _text = _text.filter!pred.to!string;
        }

        while (textTooLong)
            _text = backspace(_text);

        assert (! _allowScrolling, "DTODO: implement _allowScrolling");
    }

    bool textTooLong()
    {
        return ! _allowScrolling && _label.tooLong(_text ~ caretChar);
    }

    void pruneDigits()
    {
        if (allowedChars != AllowedChars.digits)
            return;
        while (_text.length > 0 && _text[0] == '0')
            _text = _text[1 .. $];
        if (_text.length == 0)
            _text = "0";
        pruneText();
    }

}
// end class Texttype
