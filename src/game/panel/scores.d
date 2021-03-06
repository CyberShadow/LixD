module game.panel.scores;

/* ScoreGraph: The UI element in multiplayer games that displays lovely
 * bar graphs of the current score and the potential score.
 * Sorted by current score.
 *
 * ScoreGraph.Score: The necessary data for one team.
 */

import std.algorithm;
import std.conv;

import basics.alleg5;
import game.score;
import graphic.color;
import graphic.internal;
import gui;

class ScoreGraph : Element {
private:
    Score[] scores; // not an associative array because we want to sort it
    Style ourStyle; // tiebreak in favor of this for sorting

public:
    this(Geom g) { super(g); }

    void update(Score updatedScore)
    {
        auto found = scores.find!(e => e.style == updatedScore.style);
        if (found == [])
            scores ~= updatedScore;
        else if (found[0] != updatedScore) {
            found[0] = updatedScore;
            reqDraw();
        }
        scores.sort!((a, b) =>
              a.current > b.current ? true
            : a.current < b.current ? false
            : a.potential > b.potential ? true
            : a.potential < b.potential ? false
            : a.style == ourStyle);
    }

protected:
    override void drawSelf()
    {
        drawFrame();
        foreach (int i, score; scores)
            drawScore(i, score);
    }

private:
    void drawFrame()
    {
        alias th = Geom.thicks;
        assert (xls >= 4*th);
        assert (yls >= 4*th);
        draw3DFrame(xs, ys, xls, yls, color.guiL, color.guiM, color.guiD);
        draw3DFrame(xs + th, ys + th, xls - 2*th, yls - 2*th,
            color.guiD, color.guiM, color.guiL);
        al_draw_filled_rectangle(xs + 2*th, ys + 2*th,
            xs + xls - 2*th, ys + yls - 2*th, color.black);
    }

    void drawScore(in int idFromTop, in Score score)
    {
        assert (scores.length > 0);
        float maxPotential = scores.map!(sc => sc.potential).fold!max;
        assert (maxPotential >= score.current, "current score too large");
        assert (maxPotential >= score.potential, "potential score too large");
        if (maxPotential <= 0)
            return;

        // See argument comments in this.drawRatio for cryptic variable names
        alias th = Geom.thicks;
        immutable div = scores.length.to!float;
        immutable rycs = ys + 2*th + (yls - 4*th) * (idFromTop + 0.5f) / div;
        immutable ryls = (yls - 4*th) / div;
        drawRatio(rycs, ryls/3, score.potential / maxPotential, score.style);
        drawRatio(rycs, ryls, score.current / maxPotential, score.style);
    }

    // This draws a single colorful rectangle. We assume that there's a
    // black background inside (this) with 2 * Geom.thickness distance
    // to all 4 sides of (this). We draw inside that black rectangle.
    void drawRatio(
        in float rycs, // rectangle y center (!) position on the screen
        in float ryls, // rectangle y length on the screen
        in float ratio, // x length: 0.0 = nothing, 1.0f = entire width
        in Style style
    ) {
        assert (ratio >= 0f);
        assert (ratio <= 1f);
        if (ratio <= 0f)
            return;
        Alcol3D cols = getAlcol3DforStyle(style);
        draw3DButton(xs + 2*Geom.thicks, rycs - ryls/2f,
            (xls - 4*Geom.thicks) * ratio, ryls, cols.l, cols.m, cols.d);
    }
}
