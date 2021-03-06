module lix.skill.exiter;

import game.tribe;
import graphic.gadget.goal;
import hardware.sound;
import lix;

class Exiter : Leaver {

    // Do this much sideways motion during exiting, because the goal was
    // endered closer to the side than to the center of the trigger area
    int xOffsetFromGoal;

    mixin(CloneByCopyFrom!"Exiter");
    protected void copyFromAndBindToLix(in Exiter rhs, Lixxie lixToBindTo)
    {
        super.copyFromAndBindToLix(rhs, lixToBindTo);
        xOffsetFromGoal  = rhs.xOffsetFromGoal;
    }

    void scoreForTribe(Tribe tribe)
    {
        if (outsideWorld.state.goalsLocked)
            ++tribe.lixSavedLate;
        else {
            ++tribe.lixSaved;
            tribe.updatePreviousSave = outsideWorld.state.update;
        }
    }

    void determineSidewaysMotion(in Goal goal)
    {
        xOffsetFromGoal = env.distanceX(
            goal.x + goal.tile.triggerX + goal.tile.triggerXl / 2, lixxie.ex);
        if (xOffsetFromGoal % 2 == 0)
            // From C++ Lix: The +1 is necessary because this counts
            // pixel-wise, but the physics skip ahead 2 pixels at a time,
            // so the lixes enter the right part further to the left.
            xOffsetFromGoal += 1;
    }

    void playSound(in Goal goal)
    {
        if (goal.hasTribe(style))
            lixxie.playSound(Sound.GOAL);
        else
            playSoundIfTribeLocal(Sound.GOAL_BAD);
    }

    override void perform()
    {
        int change = (xOffsetFromGoal < 0 ? 1 : xOffsetFromGoal > 0 ? -1 : 0);
        spriteOffsetX = spriteOffsetX + change;
        xOffsetFromGoal += change;

        advanceFrameAndLeave();
    }
}
