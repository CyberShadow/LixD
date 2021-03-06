module lix.skill.basher;

import std.algorithm; // min, max

import lix;
import game.mask;
import game.physdraw;
import game.terchang;
import hardware.sound;

class Basher : Job {

    enum halfPixelsToFall = 9;
    int  halfPixelsMovedDown; // per pixel down: += 2; per frame passed: -= 1;
    bool steelWasHit;

    mixin(CloneByCopyFrom!"Basher");
    protected void copyFromAndBindToLix(in Basher rhs, Lixxie lixToBindTo)
    {
        super.copyFromAndBindToLix(rhs, lixToBindTo);
        halfPixelsMovedDown = rhs.halfPixelsMovedDown;
        steelWasHit = rhs.steelWasHit;
    }

    override UpdateOrder updateOrder() const { return UpdateOrder.remover; }

    override void onBecome()
    {
        // September 2015: start faster to make the basher slightly stronger
        frame = 2;
    }

    override void perform()
    {
        advanceFrame();
        switch (frame) {
            case  7: performSwing();   break;
            case 10: continueOrStop(); break;
            case 11: ..
            case 15: moveAhead();      break; // "..15" is inclusive! 5 cases!
            default: break;
        }
        stopIfMovedDownTooFar();
    }

private:

    bool nothingMoreToBash()
    {
        // We don't check the pixels that would be in the upcoming basher
        // swing, but so far away that they will still be ahead of the lix
        // after a full basher's walk-ahead cycle. These pixels will be
        // checked after that next basher's walk cycle.
        // Checking everything would be a rectangle of 14+2, -16, 23+2, +1
        // instead of what we do,                      14+2, -14, 21+2, -3.
        // The +2 are changes from C++ Lix to account for the longer D mask.
        immutable earth = countSolid(16, -14, 23, -3);
        if (earth < 15) {
            for (int x = 16; x <= 23; x += 2)
                if (isSolid(x, -12))
                    return false; // Thin wall found. Keep bashing.
            return true; // No thin walls, too few pixels to continue bashing.
        }
        return false;
    }

    void performSwing()
    {
        bool omitRelics()
        {
            immutable earthAfter = lixxie.countSolid(16, -16, 17, 1);
            immutable pathClear  = nothingMoreToBash();
            return earthAfter == 0 && pathClear;
        }
        TerrainDeletion tc;
        tc.update = outsideWorld.state.update;
        if (omitRelics) {
            if (dir > 0) tc.type = TerrainDeletion.Type.bashNoRelicsRight;
            else         tc.type = TerrainDeletion.Type.bashNoRelicsLeft;
        }
        else {
            if (dir > 0) tc.type = TerrainDeletion.Type.bashRight;
            else         tc.type = TerrainDeletion.Type.bashLeft;
        }
        tc.x = ex - masks[tc.type].offsetX;
        tc.y = ey - masks[tc.type].offsetY;
        outsideWorld.physicsDrawer.add(tc);
        if (wouldHitSteel(masks[tc.type])) {
            playSound(Sound.STEEL);
            steelWasHit = true;
            // do not cancel the basher yet, this will happen later
        }
    }

    void continueOrStop()
    {
        if (steelWasHit) {
            turn();
            become(Ac.walker);
        }
        else if (nothingMoreToBash)
            become(Ac.walker);
    }

    void stopIfMovedDownTooFar()
    {
        immutable stepSize = () {
            assert (halfPixelsMovedDown < halfPixelsToFall);
            for (int y; 2*y < halfPixelsToFall - halfPixelsMovedDown; ++y)
                if (lixxie.isSolid(0, 2 + y))
                    return y;
            return -1;
        }();
        if (stepSize >= 0) {
            moveDown(stepSize);
            halfPixelsMovedDown += 2 * stepSize;
            assert (halfPixelsMovedDown < halfPixelsToFall);
            if (halfPixelsMovedDown > 0)
                --halfPixelsMovedDown;
        }
        else {
            // was 3 in C++ Lix, but the walker uses 2, so we do that, too
            enum fallUpTo = 2;
            int y = 0;
            while (! isSolid(0, 2 + y) && y < fallUpTo)
                ++y;
            if (isSolid(0, 2 + y)) {
                moveDown(y);
                become(Ac.walker);
            }
            else
                Faller.becomeAndFallPixels(lixxie, y);
        }
    }

}
// end class Basher
