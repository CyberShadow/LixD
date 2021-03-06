module net.ac;

/* Activity enum for the lixes.
 * This is in net/, not in lix/, because it has to travel over the network.
 */

import std.algorithm;
import std.array;
import std.conv;
import std.uni;

enum int skillInfinity  = -1;
enum int skillNumberMax = 999;

enum int builderBrickXl  = 12;
enum int platformLongXl  = 8; // first brick
enum int platformShortXl = 6; // all bricks laid down while kneeling
enum int brickYl         = 2;

enum UpdateOrder {
    peaceful, // Least priority -- cannot affect other lix. Updated last.
    adder,    // Worker that adds terrain. Adders may add in fresh holes.
    remover,  // Worker that removes terrain.
    blocker,  // Affects lixes directly other than by flinging -- blocker.
    flinger,  // Affects lixes directly by flinging. Updated first.
}

nothrow bool isPloder(in Ac ac) pure
{
    return ac == Ac.imploder || ac == Ac.exploder;
}

nothrow @property int acToSkillIconXf(in Ac ac)
{
    // I plan to remove black frames from skillico.I.png, to save time.
    // I will then replace this by a nontrivial computation.
    return ac;
}

nothrow Ac stringToAc(in string str)
{
    try {
        string lower = str.toLower;
        return lower == "exploder"  ? Ac.imploder
            :  lower == "exploder2" ? Ac.exploder : lower.to!Ac;
    }
    catch (Exception)
        return Ac.max;
}

string acToString(in Ac ac)
{
    return ac == Ac.exploder ? "EXPLODER2"
        :  ac == Ac.imploder ? "EXPLODER" : ac.to!string.toUpper;
}

auto acToNiceCase(in Ac ac)
{
    string s = ac.to!string;
    if (s[$-1] == '2') // shrugger2
        s = s[0 .. $-1];
    return s.asCapitalized;
}

unittest {
    assert (acToString(Ac.faller) == "FALLER");
    assert (stringToAc("builDER") == Ac.builder);
    assert (stringToAc("expLoder") == Ac.imploder);
    assert (stringToAc("eXploDer2") == Ac.exploder);
    assert (acToString(Ac.imploder) == "EXPLODER");
    assert (acToString(Ac.exploder) == "EXPLODER2");
    assert (acToNiceCase(Ac.faller).equal("Faller"));
    assert (acToNiceCase(Ac.shrugger2).equal("Shrugger"));
    assert (acToNiceCase(Ac.imploder).equal("Imploder"));
}

enum Ac : ubyte {
    nothing,
    faller,
    tumbler,
    stunner,
    lander,
    splatter,
    burner,
    drowner,
    exiter,
    walker,
    runner,

    climber,
    ascender,
    floater,
    imploder,
    exploder,
    blocker,
    builder,
    shrugger,
    platformer,
    shrugger2,
    basher,
    miner,
    digger,

    jumper,
    batter,
    cuber,

    max
}
