import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;

// Ajustes persistentes accesibles desde cualquier parte de la app.
// Defaults: vibración ON, sonido ON, tema claro.
class Settings {

    static const KEY_VIBRATE as String = "set.vibrate";
    static const KEY_SOUND as String = "set.sound";
    static const KEY_THEME_DARK as String = "set.themeDark";

    static function isVibrationEnabled() as Boolean {
        var v = Storage.getValue(KEY_VIBRATE);
        return (v instanceof Boolean) ? v : true;
    }

    static function setVibrationEnabled(v as Boolean) as Void {
        Storage.setValue(KEY_VIBRATE, v);
    }

    static function isSoundEnabled() as Boolean {
        var v = Storage.getValue(KEY_SOUND);
        return (v instanceof Boolean) ? v : true;
    }

    static function setSoundEnabled(v as Boolean) as Void {
        Storage.setValue(KEY_SOUND, v);
    }

    static function isThemeDark() as Boolean {
        var v = Storage.getValue(KEY_THEME_DARK);
        return (v instanceof Boolean) ? v : false;
    }

    static function setThemeDark(v as Boolean) as Void {
        Storage.setValue(KEY_THEME_DARK, v);
    }
}
