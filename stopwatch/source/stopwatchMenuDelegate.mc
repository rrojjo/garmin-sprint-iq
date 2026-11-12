import Toybox.Attention;
import Toybox.Lang;
import Toybox.WatchUi;

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {

    private const VIBE_RESUME_MS as Number = 150;

    private var _view as StopwatchView;

    function initialize(view as StopwatchView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var s = getApp().session;
        var id = item.getId();
        if (id == :laps) {
            WatchUi.pushView(PausedLapsDelegate.buildMenu(),
                new PausedLapsDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        if (id == :settings) {
            WatchUi.pushView(SettingsMenuDelegate.buildMenu(),
                new SettingsMenuDelegate(), WatchUi.SLIDE_UP);
            return;
        }
        if (id == :discard) {
            // Lanzamos la confirmación encima del pause menu. Si el usuario
            // dice "No" vuelve al pause menu sin perder estado. Si dice "Sí",
            // el ConfirmDelegate cierra ambas vistas. Mantener ambas vistas
            // en pila evita el problema de timing que provocaba el freeze.
            WatchUi.pushView(DiscardConfirmationDelegate.buildMenu(),
                new DiscardConfirmationDelegate(),
                WatchUi.SLIDE_LEFT);
            return;
        }
        if (id == :lapContinue) {
            if (!_lapAndContinue()) {
                item.setLabel(WatchUi.loadResource(Rez.Strings.RecordingFailed) as String);
                WatchUi.requestUpdate();
                return;
            }
        } else if (id == :resume) {
            if (!s.resume()) {
                item.setLabel(WatchUi.loadResource(Rez.Strings.RecordingFailed) as String);
                WatchUi.requestUpdate();
                return;
            }
            _view.startTicker();
            _vibrate(VIBE_RESUME_MS);
        } else if (id == :save) {
            if (!s.save()) {
                item.setLabel(WatchUi.loadResource(Rez.Strings.SaveFailed) as String);
                WatchUi.requestUpdate();
                return;
            }
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        // Correct an accidental START with the physical BACK/LAP button.
        if (!_lapAndContinue()) { WatchUi.requestUpdate(); return; }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    private function _lapAndContinue() as Boolean {
        if (!getApp().session.lapAndContinue()) { return false; }
        _view.resetScroll();
        _view.showLapTime();
        _view.startTicker();
        StopwatchDelegate.notifyLap();
        return true;
    }

    private function _vibrate(durationMs as Number) as Void {
        if (!Settings.isVibrationEnabled()) { return; }
        if (Attention has :vibrate) {
            var profile = [new Attention.VibeProfile(100, durationMs)];
            Attention.vibrate(profile);
        }
    }

    // Resume, correct a mistaken START, inspect laps, then other actions.
    // Statico para que pueda reconstruirse desde el confirm delegate cuando
    // el usuario dice "No" al descartar.
    static function buildMenu() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({
            :title => WatchUi.loadResource(Rez.Strings.MenuPaused) as String
        });
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.MenuResume) as String,
            null, :resume, null));
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.MenuLapContinue) as String,
            null, :lapContinue, null));
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.MenuViewLaps) as String,
            null, :laps, null));
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsTitle) as String,
            null, :settings, null));
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.MenuSave) as String,
            null, :save, null));
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.MenuDiscard) as String,
            null, :discard, null));
        return menu;
    }
}
