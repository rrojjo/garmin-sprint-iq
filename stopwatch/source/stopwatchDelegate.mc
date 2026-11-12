import Toybox.Attention;
import Toybox.Lang;
import Toybox.WatchUi;

class StopwatchDelegate extends WatchUi.BehaviorDelegate {

    private const VIBE_START_MS as Number = 150;   // pulsación start/pause

    private var _view as StopwatchView;
    private var _selectPressHandled as Boolean = false;
    private var _lapPressHandled as Boolean = false;

    function initialize(view as StopwatchView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        return _select(true);
    }

    // START and LAP act on key-down. Consume the completed key event so a
    // long press does not start/pause twice. Open menus only after release.
    function onKeyPressed(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() == WatchUi.KEY_ENTER) {
            _selectPressHandled = true;
            return _select(false);
        }
        if (event.getKey() == WatchUi.KEY_ESC && getApp().session.isRunning()) {
            _lapPressHandled = true;
            return onBack();
        }
        return false;
    }

    function onKey(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() == WatchUi.KEY_ENTER && _selectPressHandled) {
            _selectPressHandled = false;
            if (getApp().session.isPaused()) { _showPauseMenu(); }
            return true;
        }
        if (event.getKey() == WatchUi.KEY_ESC && _lapPressHandled) {
            _lapPressHandled = false;
            return true;
        }
        return BehaviorDelegate.onKey(event);
    }

    private function _showPauseMenu() as Void {
        WatchUi.pushView(PauseMenuDelegate.buildMenu(),
            new PauseMenuDelegate(_view), WatchUi.SLIDE_UP);
    }

    private function _select(showMenu as Boolean) as Boolean {
        var s = getApp().session;
        if (s.isStopped()) {
            s.start();
            if (s.isRunning()) {
                _view.resetScroll();
                _view.startTicker();
                _vibrate(VIBE_START_MS);
            }
            WatchUi.requestUpdate();
        } else if (s.isRunning()) {
            if (!s.pause()) { WatchUi.requestUpdate(); return true; }
            _view.stopTicker();
            _vibrate(VIBE_START_MS);
            if (showMenu) { _showPauseMenu(); }
            WatchUi.requestUpdate();
        } else if (s.isPaused()) {
            if (showMenu) { _showPauseMenu(); }
        }
        return true;
    }

    function onBack() as Boolean {
        var s = getApp().session;
        if (s.isRunning()) {
            if (!s.lap()) { WatchUi.requestUpdate(); return true; }
            _view.resetScroll();
            _view.showLapTime();
            notifyLap();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    // UP button: el visor sube en la lista → vuelve hacia las más recientes
    function onPreviousPage() as Boolean {
        _view.scrollNewer();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN button: el visor baja en la lista → revela vueltas más antiguas
    function onNextPage() as Boolean {
        _view.scrollOlder();
        WatchUi.requestUpdate();
        return true;
    }

    // Long press UP: menú de ajustes (solo en estado STOPPED para no
    // interrumpir una serie en curso). Para acceder en PAUSED, hay un item
    // "Settings" dentro del propio menú de pausa.
    function onMenu() as Boolean {
        var s = getApp().session;
        if (s.isStopped()) {
            WatchUi.pushView(SettingsMenuDelegate.buildMenu(),
                new SettingsMenuDelegate(), WatchUi.SLIDE_UP);
            return true;
        }
        return false;
    }

    private function _vibrate(durationMs as Number) as Void {
        if (!Settings.isVibrationEnabled()) { return; }
        if (Attention has :vibrate) {
            var profile = [new Attention.VibeProfile(100, durationMs)];
            Attention.vibrate(profile);
        }
    }

    // Vibración del lap: 2 segundos continuos al 100% (un solo pulso).
    // Si el ajuste de sonido está activo, también suena el tono de lap.
    static function notifyLap() as Void {
        if (Settings.isVibrationEnabled() && (Attention has :vibrate)) {
            var profile = [new Attention.VibeProfile(100, 2000)];
            Attention.vibrate(profile);
        }
        if (Settings.isSoundEnabled() && (Attention has :playTone)) {
            try {
                Attention.playTone(Attention.TONE_LOUD_BEEP);
            } catch (e) {
                // best effort
            }
        }
    }

}
