import Toybox.Lang;
import Toybox.WatchUi;

// Confirmación previa al descarte. Usa Menu2 con dos items (No primero, Sí
// después) para que se vea exactamente igual que el resto de menús nativos
// de Garmin y para evitar el freeze que provocaba WatchUi.Confirmation al
// hacer pushView dentro de su onResponse.

class DiscardConfirmationDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :yes) {
            // Descartamos. Hay que sacar dos vistas del stack: la confirmación
            // y el menú de pausa que sigue debajo. Así vuelves directo a la
            // vista principal en STOPPED.
            if (!getApp().session.discard()) {
                item.setLabel(WatchUi.loadResource(Rez.Strings.RecordingFailed) as String);
                WatchUi.requestUpdate();
                return;
            }
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            // :no o cualquier otro: solo cerrar la confirmación → vuelves
            // al menú de pausa con la sesión todavía PAUSED.
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    // Construye la Menu2 de confirmación: título arriba, No primero
    // (seleccionado por defecto), Sí debajo.
    static function buildMenu() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({
            :title => WatchUi.loadResource(Rez.Strings.ConfirmDiscard) as String
        });
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.ConfirmNo) as String,
            null, :no, null));
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.ConfirmYes) as String,
            null, :yes, null));
        return menu;
    }
}
