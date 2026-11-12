import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class StopwatchApp extends Application.AppBase {

    var session as StopwatchSession;

    function initialize() {
        AppBase.initialize();
        session = new StopwatchSession();
    }

    function onStart(state as Dictionary?) as Void {
        // Si la app se cerró inesperadamente con una sesión activa, recupera
        // los lap times y el elapsed desde Storage. Quedará en PAUSED para que
        // el usuario decida Resume / Save / Discard explícitamente.
        session.tryRestore();
    }

    function onStop(state as Dictionary?) as Void {
        // Defensive: if the app is killed while a recording is active,
        // save the FIT instead of losing it.
        session.forceSaveIfActive();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new StopwatchView();
        var delegate = new StopwatchDelegate(view);
        return [view, delegate];
    }
}

function getApp() as StopwatchApp {
    return Application.getApp() as StopwatchApp;
}
