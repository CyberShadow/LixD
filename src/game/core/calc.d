module game.core.calc;

import std.algorithm; // all

import basics.user;
import basics.cmdargs;
import game.core.game;
import game.window.single;
import game.window.multi;
import game.core.active;
import game.core.passive;
import game.core.speed;
import gui;
import hardware.keyset;

package void
implGameCalc(Game game)
{
    assert (game.runmode == Runmode.INTERACTIVE);
    if (game.modalWindow) {
        game.calcModalWindow;
    }
    else if (keyGameExit.keyTapped) {
        game.createModalWindow;
    }
    else {
        game.calcPassive();
        game.calcActive();
        game.updatePhysicsAccordingToSpeedButtons();
        if (game.isFinished)
            game.createModalWindow;
    }
}

private bool
isFinished(const(Game) game) { with (game)
{
    assert (nurse);
    if (runmode == Runmode.VERIFY)
        return ! nurse.stillPlaying();
    else
        return ! nurse.stillPlaying() && effect.nothingGoingOn;
}}

private void
createModalWindow(Game game) { with (game)
{
    assert (! modalWindow);
    if (game.isFinished)
        // Refactoring idea: I didn't want to pass mutable tribes across the
        // program, but here I do nonetheless. I don't know who should spawn
        // the window: The nurse shouldn't spawn it, but we shouldn't have
        // to refine the data from the nurse.
        modalWindow = multiplayer ? new WindowEndMulti(
                                    nurse.stateOnlyPrivatelyForGame.tribes,
                                    _localStyle, nurse.replay, level)
            : new WindowEndSingle(localTribe, nurse.replay, level);
    else
        modalWindow = new WindowDuringOffline(nurse.replay, level);
    addFocus(game.modalWindow);
}}

private void
calcModalWindow(Game game) { with (game)
{
    void killWindow()
    {
        rmFocus(modalWindow);
        modalWindow = null;
        game.setLastUpdateToNow();
    }
    assert (modalWindow);
    if (modalWindow.resume) {
        killWindow();
    }
    else if (modalWindow.framestepBack) {
        game.framestepBackBy(3 * Game.updatesBackMany);
        killWindow();
    }
    else if (modalWindow.restart) {
        game.restartLevel();
        killWindow();
    }
    else if (modalWindow.exitGame) {
        _gotoMainMenu = true;
        killWindow();
    }
}}
