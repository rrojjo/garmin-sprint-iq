import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (!(item instanceof WatchUi.ToggleMenuItem)) { return; }
        var toggle = item as WatchUi.ToggleMenuItem;
        var id = item.getId();
        if (id == :set_vibrate) {
            Settings.setVibrationEnabled(toggle.isEnabled());
        } else if (id == :set_sound) {
            Settings.setSoundEnabled(toggle.isEnabled());
        } else if (id == :set_theme) {
            Settings.setThemeDark(toggle.isEnabled());
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    // Construye el Menu2 de ajustes con sus 3 toggles. Accesible desde el
    // delegate principal (STOPPED) y desde el menú de pausa (PAUSED).
    static function buildMenu() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({
            :title => WatchUi.loadResource(Rez.Strings.SettingsTitle) as String
        });
        menu.addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsVibration) as String,
            null, :set_vibrate, Settings.isVibrationEnabled(), null));
        menu.addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsSound) as String,
            null, :set_sound, Settings.isSoundEnabled(), null));
        menu.addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SettingsTheme) as String,
            null, :set_theme, Settings.isThemeDark(), null));
        return menu;
    }
}
