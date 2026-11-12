import Toybox.Lang;
import Toybox.System;
import Toybox.ActivityRecording;
import Toybox.Activity;
import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Sensor;

class StopwatchSession {

    enum {
        STATE_STOPPED,
        STATE_RUNNING,
        STATE_PAUSED
    }

    // Claves de persistencia en Application.Storage. La existencia de
    // KEY_TOTAL_AT_SAVE es lo que dispara la recuperación al arrancar.
    private const KEY_LAP_TIMES as String = "ss.lapTimes";
    private const KEY_TOTAL_AT_SAVE as String = "ss.totalAtSaveMs";
    private const KEY_LAP_AT_SAVE as String = "ss.lapAtSaveMs";

    private var _state as Number;
    private var _sessionStartMs as Number;
    private var _lapStartMs as Number;
    private var _pauseStartMs as Number;
    private var _pausedAccumMs as Number;
    private var _lapPausedAccumMs as Number;
    private var _lapTimes as Array<Number>;
    private var _recordingSession as ActivityRecording.Session?;
    private var _hasError as Boolean;

    function initialize() {
        _state = STATE_STOPPED;
        _sessionStartMs = 0;
        _lapStartMs = 0;
        _pauseStartMs = 0;
        _pausedAccumMs = 0;
        _lapPausedAccumMs = 0;
        _lapTimes = [];
        _recordingSession = null;
        _hasError = false;
    }

    // Monotonic clock; overridable by deterministic simulator tests.
    function nowMs() as Number { return System.getTimer(); }

    function getState() as Number { return _state; }
    function isRunning() as Boolean { return _state == STATE_RUNNING; }
    function isPaused() as Boolean { return _state == STATE_PAUSED; }
    function isStopped() as Boolean { return _state == STATE_STOPPED; }
    function hasError() as Boolean { return _hasError; }
    function getLapTimes() as Array<Number> { return _lapTimes; }
    function getLapCount() as Number { return _lapTimes.size(); }

    function getTotalElapsedMs() as Number {
        if (_state == STATE_STOPPED) { return 0; }
        var endMs = (_state == STATE_PAUSED) ? _pauseStartMs : nowMs();
        return endMs - _sessionStartMs - _pausedAccumMs;
    }

    function getCurrentLapElapsedMs() as Number {
        if (_state == STATE_STOPPED) { return 0; }
        var endMs = (_state == STATE_PAUSED) ? _pauseStartMs : nowMs();
        return endMs - _lapStartMs - _lapPausedAccumMs;
    }

    function start() as Boolean {
        if (_state != STATE_STOPPED) { return false; }
        // Timestamp the input before native recording/sensor setup or storage.
        var now = nowMs();
        try {
            _recordingSession = ActivityRecording.createSession({
                :sport => Activity.SPORT_RUNNING,
                :subSport => Activity.SUB_SPORT_TRACK,
                :name  => "Series"
            });
        } catch (e) {
            _recordingSession = null;
        }
        if (_recordingSession == null) {
            _hasError = true;
            return false;
        }
        try {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        } catch (e) {
            // best effort; manifest still grants Sensor permission
        }
        if (!_setRecordingRunning(true)) { return false; }
        _sessionStartMs = now;
        _lapStartMs = now;
        _pauseStartMs = 0;
        _pausedAccumMs = 0;
        _lapPausedAccumMs = 0;
        _lapTimes = [];
        _hasError = false;
        _state = STATE_RUNNING;
        _persist();
        return true;
    }

    function pause() as Boolean {
        if (_state != STATE_RUNNING) { return false; }
        var now = nowMs();
        if (!_setRecordingRunning(false)) { return false; }
        _pauseStartMs = now;
        _state = STATE_PAUSED;
        _persist();
        return true;
    }

    function resume() as Boolean {
        if (_state != STATE_PAUSED) { return false; }
        var now = nowMs();
        if (!_setRecordingRunning(true)) { return false; }
        var delta = now - _pauseStartMs;
        _pausedAccumMs += delta;
        _lapPausedAccumMs += delta;
        _pauseStartMs = 0;
        _state = STATE_RUNNING;
        _persist();
        return true;
    }

    function lap() as Boolean {
        if (_state != STATE_RUNNING) { return false; }
        // One timestamp closes the old lap and opens the next: no lost time.
        var now = nowMs();
        try {
            if (_recordingSession == null || !_recordingSession.addLap()) {
                _hasError = true;
                return false;
            }
        } catch (e) {
            _hasError = true;
            return false;
        }
        _lapTimes.add(now - _lapStartMs - _lapPausedAccumMs);
        _lapStartMs = now;
        _lapPausedAccumMs = 0;
        _hasError = false;
        _persist();
        return true;
    }

    // Reinterpret the last START press as LAP. The next stopwatch lap includes
    // time spent in the menu. Garmin cannot backdate FIT laps or timer events;
    // its native recording resumes/marks the lap when the correction is chosen.
    function lapAndContinue() as Boolean {
        if (_state != STATE_PAUSED) { return false; }
        if (!_setRecordingRunning(true)) { return false; }
        try {
            if (_recordingSession == null || !_recordingSession.addLap()) {
                _setRecordingRunning(false);
                _hasError = true;
                return false;
            }
        } catch (e) {
            _setRecordingRunning(false);
            _hasError = true;
            return false;
        }
        _lapTimes.add(_pauseStartMs - _lapStartMs - _lapPausedAccumMs);
        _lapStartMs = _pauseStartMs;
        _lapPausedAccumMs = 0;
        // Do not add this accidental pause to the excluded pause accumulator.
        _pauseStartMs = 0;
        _state = STATE_RUNNING;
        _hasError = false;
        _persist();
        return true;
    }

    function save() as Boolean {
        if (_state != STATE_PAUSED) { return false; }
        // save() closes the final FIT lap. Never add another manual lap here.
        if (!_finishRecording(true)) { return false; }
        var pending = _pauseStartMs - _lapStartMs - _lapPausedAccumMs;
        if (pending > 0) {
            _lapTimes.add(pending);
        }
        _state = STATE_STOPPED;
        _clearPersisted();
        return true;
    }

    function discard() as Boolean {
        if (_state != STATE_PAUSED) { return false; }
        if (!_finishRecording(false)) { return false; }
        _state = STATE_STOPPED;
        _clearPersisted();
        return true;
    }

    function forceSaveIfActive() as Void {
        if (_state == STATE_STOPPED) { return; }
        // Preserve the recovery snapshot when the system cannot save the FIT.
        if (_state == STATE_RUNNING && !pause()) { _persist(); return; }
        save();
    }

    private function _setRecordingRunning(running as Boolean) as Boolean {
        try {
            if (_recordingSession != null) {
                if (_recordingSession.isRecording() == running ||
                    (running ? _recordingSession.start() : _recordingSession.stop())) {
                    _hasError = false;
                    return true;
                }
            }
        } catch (e) {
            // The caller keeps its current state so the operation can be retried.
        }
        _hasError = true;
        return false;
    }

    private function _finishRecording(keep as Boolean) as Boolean {
        if (!_setRecordingRunning(false)) { return false; }
        try {
            if (_recordingSession != null &&
                (keep ? _recordingSession.save() : _recordingSession.discard())) {
                _recordingSession = null;
                _hasError = false;
                return true;
            }
        } catch (e) {
            // Retain the handle and snapshot on failure; never claim success.
        }
        _hasError = true;
        return false;
    }

    // ===== Persistencia =====

    // Guarda en Storage los datos suficientes para reconstruir la sesión.
    // Llamado tras cada transición de estado (start/pause/resume/lap).
    private function _persist() as Void {
        if (_state == STATE_STOPPED) {
            _clearPersisted();
            return;
        }
        var storedLaps = [] as Array<Storage.ValueType>;
        for (var i = 0; i < _lapTimes.size(); i += 1) {
            storedLaps.add(_lapTimes[i]);
        }
        Storage.setValue(KEY_LAP_TIMES, storedLaps);
        Storage.setValue(KEY_TOTAL_AT_SAVE, getTotalElapsedMs());
        Storage.setValue(KEY_LAP_AT_SAVE, getCurrentLapElapsedMs());
    }

    private function _clearPersisted() as Void {
        Storage.deleteValue(KEY_LAP_TIMES);
        Storage.deleteValue(KEY_TOTAL_AT_SAVE);
        Storage.deleteValue(KEY_LAP_AT_SAVE);
    }

    // Restaura sesión desde Storage si existe. Devuelve true si recuperó algo.
    // Política: restauramos siempre en estado PAUSED para que tú decidas
    // explícitamente Reanudar / Guardar / Descartar.
    // Se recupera el último checkpoint, no el tiempo posterior al mismo.
    // createSession recupera el handle existente si Garmin aún lo conserva.
    function tryRestore() as Boolean {
        var savedTotal = Storage.getValue(KEY_TOTAL_AT_SAVE);
        if (savedTotal == null) { return false; }

        var savedLap = Storage.getValue(KEY_LAP_AT_SAVE);
        var savedLaps = Storage.getValue(KEY_LAP_TIMES);

        _lapTimes = (savedLaps != null) ? savedLaps as Array<Number> : [];
        if (savedLap == null) { savedLap = 0; }

        var now = nowMs();
        // Reconstruimos las referencias en términos de nowMs() actual,
        // de modo que getTotalElapsedMs y getCurrentLapElapsedMs devuelvan los
        // valores guardados al consultarlos ahora mismo (estado PAUSED).
        _sessionStartMs = now - (savedTotal as Number);
        _lapStartMs = now - (savedLap as Number);
        _pausedAccumMs = 0;
        _lapPausedAccumMs = 0;
        _pauseStartMs = now;
        _state = STATE_PAUSED;
        _hasError = false;

        // Do not start recording while the restored stopwatch is paused.
        // If Garmin lost the FIT, historical samples cannot be reconstructed.
        _recordingSession = null;
        try {
            _recordingSession = ActivityRecording.createSession({
                :sport => Activity.SPORT_RUNNING,
                :subSport => Activity.SUB_SPORT_TRACK,
                :name  => "Series"
            });
            if (_recordingSession != null) {
                try {
                    Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
                } catch (es) {
                }
                _setRecordingRunning(false);
            } else {
                _hasError = true;
            }
        } catch (e) {
            _recordingSession = null;
            _hasError = true;
        }

        return true;
    }

    // ===== Formato =====

    // Vuelta actual (grande): omitir minutos cuando todavía no se ha llegado al
    // primer minuto. SS.d hasta 59.9, luego M:SS.d, luego MM:SS.d.
    static function formatLapBig(ms as Number) as String {
        var totalDs = ms / 100;
        var d = totalDs % 10;
        var s = (totalDs / 10) % 60;
        var m = totalDs / 600;
        if (m == 0) {
            return Lang.format("$1$.$2$", [s.format("%02d"), d.format("%d")]);
        }
        return Lang.format("$1$:$2$.$3$", [
            m.format("%d"),
            s.format("%02d"),
            d.format("%d")
        ]);
    }

    // Historial: minutos de un solo dígito mientras m < 10.
    static function formatLapSmall(ms as Number) as String {
        var totalCs = ms / 10;
        var c = totalCs % 100;
        var s = (totalCs / 100) % 60;
        var m = totalCs / 6000;
        return Lang.format("$1$:$2$.$3$", [
            m.format("%d"),
            s.format("%02d"),
            c.format("%02d")
        ]);
    }

    static function formatTotal(ms as Number) as String {
        var s = ms / 1000;
        if (s >= 3600) {
            var h = s / 3600;
            var mm = (s / 60) % 60;
            var ss = s % 60;
            return Lang.format("$1$:$2$:$3$", [
                h.format("%d"),
                mm.format("%02d"),
                ss.format("%02d")
            ]);
        }
        var m = s / 60;
        var sec = s % 60;
        return Lang.format("$1$:$2$", [
            m.format("%02d"),
            sec.format("%02d")
        ]);
    }
}
