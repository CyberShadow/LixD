module hardware.mousecur;

/* This is only for the drawable mouse cursor.
 * To read mouse input, look at the module hardware.mouse.
 *
 *  public Graphic mouseCursor; -- work with this object however you wish
 */

import basics.globals;
import basics.rect;
import graphic.cutbit;
import graphic.internal;
import graphic.graphic;
import hardware.mouse;

public Graphic mouseCursor;

void initialize()
{
    assert (mouseCursor is null, "mouse cursor is already initialized");
    const(Cutbit) cb = getInternal(fileImageMouse);
    assert (cb, "mouse cursor bitmap is not loaded or missing");
    assert (cb.valid, "mouse cursor bitmap is not valid");

    mouseCursor = new Graphic(cb, null);
}

void deinitialize()
{
    if (mouseCursor) {
        destroy(mouseCursor);
        mouseCursor = null;
    }
}

void draw()
{
    assert (mouseCursor, "call hardware.mousecur.initialize() before drawing");
    mouseCursor.loc = Point(hardware.mouse.mouseX - mouseCursor.xl/2 + 1,
                            hardware.mouse.mouseY - mouseCursor.yl/2 + 1);
    mouseCursor.drawToCurrentAlbitNotTorbit();
}
