module graphic.torbit.torbit;

import std.math; // fmod, abs
import std.algorithm; // minPos

import basics.alleg5;
import basics.help; // positiveMod
import basics.topology;
import graphic.color; // drawing dark, to analyze transparency
import file.filename;
import hardware.display;

public import basics.rect;

/* Torbit is a bitmap with possible torus wrapping. When you instruct it to
 * draw things on itself, it warps the things around accordingly.
 *
 * See also TargetTorbit in graphic.targtorb.
 */

class Torbit : Topology {
private:
    Albit bitmap;

public:
    @property inout(Albit) albit() inout { return bitmap; }

    this(in int _xl, in int _yl, in bool _tx = false, in bool _ty = false)
    {
        super(_xl, _yl, _tx, _ty);
        bitmap = albitCreate(_xl, _yl);
    }

    this(const(Topology) topol)
    {
        super(topol);
        bitmap = albitCreate(topol.xl, topol.yl);
    }

    this(const Torbit rhs)
    {
        assert (rhs, "Don't copy-construct from a null Torbit.");
        assert (rhs.bitmap, "shouldn't ever happen, bug in Torbit");
        super(rhs);
        bitmap = al_clone_bitmap(cast (Albit) rhs.bitmap);
    }

    void copyFrom(in Torbit rhs)
    {
        assert (rhs, "can't copyFrom a null Torbit");
        assert (bitmap, "null bitmap shouldn't ever happen, bug in Torbit");
        assert (rhs.bitmap, "null rhs.bitmap shouldn't ever happen");
        assert (rhs.Topology.opEquals(this),
            "copyFrom only implemented between same size, for speedup");
        auto targetBitmap = TargetBitmap(bitmap);
        al_draw_bitmap(cast (Albit) rhs.bitmap, 0, 0, 0);
    }

    ~this() { dispose(); }
    void dispose()
    {
        if (bitmap) {
            al_destroy_bitmap(bitmap);
            bitmap = null;
        }
    }

    Albit loseOwnershipOfAlbit()
    {
        assert (bitmap);
        auto ret = bitmap;
        bitmap = null;
        return ret;
    }

    void copyToScreen()
    {
        auto targetBitmap = TargetBitmap(al_get_backbuffer(display));
        al_draw_bitmap(bitmap, 0, 0, 0);
    }

    void clearToBlack()  { this.clearToColor(color.black);  }
    void clearToTransp() { this.clearToColor(color.transp); }
    void clearToColor(Alcol col)
    {
        auto targetBitmap = TargetBitmap(bitmap);
        al_clear_to_color(col);
    }

    void drawRectangle(in Rect rect, in Alcol col)
    {
        useDrawingDelegate(delegate void(int x, int y) {
            al_draw_rectangle(x + 0.5f,           y + 0.5f,
                              x + rect.xl - 0.5f, y + rect.yl - 0.5f, col, 1);
        }, wrap(rect.topLeft));
    }

    void drawFilledRectangle(Rect rect, Alcol col)
    {
        useDrawingDelegate(delegate void(int x, int y) {
            al_draw_filled_rectangle(x, y, x + rect.xl, y + rect.yl, col);
        }, wrap(rect.topLeft));
    }

    void saveToFile(in Filename fn)
    {
        al_save_bitmap(fn.stringzForWriting, bitmap);
    }

    void drawFromPreservingAspectRatio(in Torbit from)
    {
        auto targetBitmap = TargetBitmap(bitmap);
        immutable float scaleX = 1.0f * xl / from.xl;
        immutable float scaleY = 1.0f * yl / from.yl;
        // draw (from) as large as possible onto (this), which requires that
        // the strongest restriction is followed, i.e.,
        // we scale by the smallest scaling factor.
        int destXl = xl, destYl = yl;
        if (scaleX < scaleY)
            destYl = (yl * scaleX/scaleY).roundInt;
        else
            destXl = (xl * scaleY/scaleX).roundInt;
        assert (destXl <= xl && destYl == yl
            ||  destYl <= yl && destXl == xl);
        al_draw_scaled_bitmap(cast (Albit) from.bitmap,
            0, 0, from.xl, from.yl,
            (xl-destXl)/2, (yl-destYl)/2, destXl, destYl, 0);
    }

protected:
    final override void onResize()
    out {
        assert (bitmap);
        assert (xl == al_get_bitmap_width (bitmap));
        assert (yl == al_get_bitmap_height(bitmap));
    }
    body {
        if (bitmap)
            al_destroy_bitmap(bitmap);
        bitmap = albitCreate(xl, yl);
    }

package:
    // To call this, use TargetTorbit on the torbit, then call the free
    // function drawToTargetTorbit(...), that draws onto the TargetTorbit.
    // Allegro 5 drawing works like this, with thread-local targets.
    // Draw the entire Albit onto (Torbit this). Can take non-integer quarter
    // turns as (double rot).
    final void drawFrom(
        const(Albit) source,
        in Point targetCorner = Point(0, 0),
        bool mirrY = false, // vertically mirrored -- happens before rotation
        double rotCw = 0,   // clockwise rotation -- after any mirroring
        double scal = 0
    )
    in {
        assert (bitmap);
        assert (this.bitmap == al_get_target_bitmap(),
            "I ask callers to set the bitmap before this comes in a loop.");
        assert (source, "can't blit the null bitmap onto Torbit");
        assert (rotCw >= 0 && rotCw < 4);
    }
    body {
        Albit bit = cast (Albit) source; // A5 is not typesafe
        void delegate(int, int) drawFrom_at;
        // Select the appropriate Allegro function and its arguments.
        // This function will be called up to 4 times for drawing (Albit bit)
        // onto (Torbit this). Only the positions vary based on torus property.
        if (rotCw == 0 && ! scal) {
            drawFrom_at = delegate void(int x_at, int y_at)
            {
                al_draw_bitmap(bit, x_at, y_at, ALLEGRO_FLIP_VERTICAL * mirrY);
            };
        }
        else if (rotCw == 2 && ! scal) {
            drawFrom_at = delegate void(int x_at, int y_at)
            {
                al_draw_bitmap(bit, x_at, y_at,
                 (ALLEGRO_FLIP_VERTICAL * ! mirrY) | ALLEGRO_FLIP_HORIZONTAL);
            };
        }
        else {
            // Comment (C1)
            // We don't expect non-square things to be rotated by non-integer
            // amounts of quarter turns. Squares will have xdr = ydr = 0 in
            // this scope, see the variable definitions below.
            // The non-square terrain will only be rotated in steps of quarter
            // turns, and its top-left corner after rotation shall remain at
            // the specified level coordinates, no matter how it's rotated.
            // Terrain rotated by 0 or 2 quarter turns has already been managed
            // by the (if)s above. Now, we'll be doing a noncontinuous jump at
            // exactly 1 and 3 quarter turns, which will manage the terrain
            // well, and doesn't affect continuous rotations of squares anyway.
            immutable bool b = (rotCw == 1 || rotCw == 3);

            // x/y-length of the source bitmap
            immutable int xsl = al_get_bitmap_width (bit);
            immutable int ysl = al_get_bitmap_height(bit);

            // Comment (C2)
            // We don't want to rotate around the center point of the source
            // bitmap. That would only be the case if the source is a square.
            // We wish to have the top-left corner of the rotated shape at x/y
            // whenever we perform a multiple of a quarter turn.
            // DTODO: Test this on Linux and Windows, whether it generates the
            // same terrain.
            float xdr = b ? ysl/2f : xsl/2f;
            float ydr = b ? xsl/2f : ysl/2f;

            if (! scal) drawFrom_at = delegate void(int x_at, int y_at)
            {
                al_draw_rotated_bitmap(bit, xsl/2f, ysl/2f,
                    xdr + x_at, ydr + y_at,
                    rotCw * ALLEGRO_PI / 2,
                    mirrY ? ALLEGRO_FLIP_VERTICAL : 0
                );
            };
            else drawFrom_at = delegate void(int x_at, int y_at)
            {
                // Let's recap for rot == 0:
                // (xsl, ysl) are the x- and y-length of the unscaled source.
                // (xdr, ydr) are half of that.
                // I multiply xdr, ydr in line (L3) below with scal, because
                // according to comment (C2), the drawn shape's top-left corner
                // for rot == 0 should end up at drawFrom's arguments x and y.
                al_draw_scaled_rotated_bitmap(bit,
                    xsl/2f, // (A): this point of the unscaled source bitmap
                    ysl/2f, //      is drawn to...
                    xdr * scal + x_at, // (L3) ...to this target pos...
                    ydr * scal + y_at,
                    scal, scal, // ...and then it's scaled relative to there
                    rotCw * ALLEGRO_PI / 2,
                    mirrY ? ALLEGRO_FLIP_VERTICAL : 0
                );
            };
        }
        useDrawingDelegate(drawFrom_at, wrap(targetCorner));
    }

    // We need this for nontrivial physics drawing that can't blit everything
    final void drawFromPixel(in Albit from, in Point fromPoint, Point toPoint)
    {
        assert (this.bitmap == al_get_target_bitmap(),
            "drawFromSinglePixel() is designed for high-speed drawing. "
            ~ "Set the target bitmap manually to the target torbit's bitmap.");
        assert (from);
        assert (fromPoint.x >= 0);
        assert (fromPoint.y >= 0);
        assert (fromPoint.x < al_get_bitmap_width (cast (Albit) from));
        assert (fromPoint.y < al_get_bitmap_height(cast (Albit) from));
        toPoint = wrap(toPoint);
        al_draw_bitmap_region(cast (Albit) from,
            fromPoint.x, fromPoint.y, 1, 1, toPoint.x, toPoint.y, 0);
    }

private:
    final void useDrawingDelegate(
        void delegate(int, int) drawing_delegate,
        Point targetCorner
    ) {
        assert (bitmap);
        assert (bitmap.isTargetBitmap);
        assert (drawing_delegate != null);
        assert (targetCorner == wrap(targetCorner));

        // We don't lock the bitmap; drawing with high-level primitives
        // and blitting other VRAM bitmaps is best without locking
        with (targetCorner) {
                                  drawing_delegate(x,      y     );
            if (torusX          ) drawing_delegate(x - xl, y     );
            if (          torusY) drawing_delegate(x,      y - yl);
            if (torusX && torusY) drawing_delegate(x - xl, y - yl);
        }
    }
}
// end class Torbit
