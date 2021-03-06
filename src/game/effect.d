module game.effect;

/* Convention: Effects are passed from the working lix by specifying the
 * lix's own ex/ey. The effect manager is responsible for drawing the effects
 * at the correct position/offset. The effect managager does this by passing
 * the lix's own ex/ey straight on to the debris, which therefore becomes
 * reponsible for being drawn at the correct position.
 *
 * Because the effect manager accepts the lix's ex/ey directly, and doesn't
 * ask the lix to pass it already modified, the effect manager's calling
 * convention differs from game.physdraw.PhysicsDrawer: PhysicsDrawer expects
 * the lix to pass the top-left coordinate of the shape to be drawn.
 */

import std.algorithm;
import std.container;

import basics.help;
import net.repdata;
import game.debris;
import graphic.torbit;
import hardware.sound;

private struct Effect {
    Update   update;
    Style    tribe;
    int      lix;   // if not necessary, set to 0
    Sound    sound; // if not necessary, set to 0 == Sound::NOTHING
    Loudness loudness;

    int opCmp(ref in Effect rhs) const
    {
        return update   != rhs.update   ? update   - rhs.update
            :  tribe    != rhs.tribe    ? tribe    - rhs.tribe
            :  lix      != rhs.lix      ? lix      - rhs.lix
            :  sound    != rhs.sound    ? sound    - rhs.sound
            :  loudness != rhs.loudness ? loudness - rhs.loudness
            :  0;
    }
}

class EffectManager {

    private RedBlackTree!Effect _tree;
    private Debris[] _debris;
    public  Style localTribe;

    this()
    {
        _tree = new RedBlackTree!Effect;
    }

    bool nothingGoingOn() const
    {
        // _tree is irrelevant for checking whether anything is still flying,
        // because _tree remembers whether the same effect was added before.
        return _debris.length == 0;
    }

    void deleteAfter(in Update upd)
    out {
        foreach (e; _tree)
            assert (e.update <= upd);
    }
    body {
        // Throw away what has update (upd + 1) or more.
        // Since I can't specify (upd+1, Style.min - 1), I'll cut here:
        _tree.remove(_tree.upperBound(Effect(upd, Style.max, 0)));
    }

    void addSoundGeneral(in Update upd,
        in Sound sound, in Loudness loudness = Loudness.loud
    ) {
        addSound(upd, localTribe, 0, sound, loudness);
    }

    void addSound(
        in Update upd, in Style tribe, in int lix,
        in Sound sound, in Loudness loudness = Loudness.loud
    ) {
        Effect e = Effect(upd, tribe, lix, sound, loudness);
        if (e !in _tree) {
            _tree.insert(e);
            hardware.sound.play(sound, loudness);
        }
    }

    void addSoundIfTribeLocal(
        in Update upd, in Style tribe, in int lix,
        in Sound sound, in Loudness loudness = Loudness.loud
    ) {
        if (tribe == localTribe)
            addSound(upd, tribe, lix, sound, loudness);
    }

    void addArrow(in Update upd, in Style tribe, in int lix,
        in int ex, in int ey, in Ac ac
    ) {
        Effect e = Effect(upd, tribe, lix);
        if (e !in _tree) {
            _tree.insert(e);
            _debris ~= Debris.newArrow(ex, ey, tribe, ac);
        }
    }

    // Only remember the effect, don't draw any debris now.
    // This is used for assignments by the local tribe master.
    void addArrowDontShow(in Update upd, in Style tribe, in int lix)
    {
        Effect e = Effect(upd, tribe, lix);
        if (e !in _tree)
            _tree.insert(e);
    }

    public alias addDigHammer = addDigHammerOrPickaxe!false;
    public alias addPickaxe = addDigHammerOrPickaxe!true;

    private void addDigHammerOrPickaxe(bool axe)(
        Update upd, Style tribe, int lix, int ex, int ey, int dir
    ) {
        Effect e = Effect(upd, tribe, lix,
            tribe == localTribe ? Sound.STEEL : Sound.NOTHING, Loudness.loud);
        if (e !in _tree) {
            _tree.insert(e);
            hardware.sound.play(e.sound, e.loudness);
            static if (axe) {
                // frame 0 (4th argument) is the pickaxe
                _debris ~= Debris.newFlyingTool(ex, ey, dir, 0);
            }
            else {
                // DTODOEFFECT: animate the dig hammer at(x, y - 10)
            }
        }
    }

    void addImplosion(in Update upd, in Style tribe, int lix, int ex, int ey)
    {
        Effect e = Effect(upd, tribe, lix, Sound.POP,
            tribe == localTribe ? Loudness.loud : Loudness.quiet);
        if (e !in _tree) {
            _tree.insert(e);
            hardware.sound.play(e.sound, e.loudness);
            _debris ~= Debris.newImplosion(ex, ey);
        }
    }

    void addExplosion(in Update upd, in Style tribe, int lix, int ex, int ey)
    {
        Effect e = Effect(upd, tribe, lix, Sound.POP,
            tribe == localTribe ? Loudness.loud : Loudness.quiet);
        if (e !in _tree) {
            _tree.insert(e);
            hardware.sound.play(e.sound, e.loudness);
            _debris ~= Debris.newExplosion(ex, ey);
        }
    }

    void calc()
    {
        int i = 0;
        while (i < _debris.len) {
            if (_debris[i].timeToLive > 0)
                _debris[i++].calc();
            else
                _debris = _debris[0 .. i] ~ _debris[i+1 .. $];
        }
    }

    void draw()
    {
        _debris.each!(a => a.draw());
    }
}
