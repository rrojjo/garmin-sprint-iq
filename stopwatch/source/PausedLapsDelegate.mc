import Toybox.Lang;
import Toybox.WatchUi;

// Inspection only: closing this view returns to the pause menu unchanged.
class PausedLapsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {}

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }

    static function buildMenu() as WatchUi.Menu2 {
        var s = getApp().session;
        var menu = new WatchUi.Menu2({
            :title => WatchUi.loadResource(Rez.Strings.MenuViewLaps) as String
        });
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.CurrentLapPaused) as String,
            StopwatchSession.formatLapSmall(s.getCurrentLapElapsedMs()), :current, null));
        var laps = s.getLapTimes();
        for (var i = laps.size() - 1; i >= 0; i -= 1) {
            menu.addItem(new WatchUi.MenuItem("v" + (i + 1).toString(),
                StopwatchSession.formatLapSmall(laps[i]), i, null));
        }
        return menu;
    }
}
