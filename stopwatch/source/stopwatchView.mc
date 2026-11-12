import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Timer;

class StopwatchView extends WatchUi.View {

    private const TICK_RUNNING_MS as Number = 50;
    private const TICK_IDLE_MS as Number = 1000;
    private const VISIBLE_LAPS as Number = 3;
    private const LAP_PREVIEW_MS as Number = 4000;

    // Posiciones verticales (208x208, FR55)
    private const Y_CLOCK as Number = 18;
    private const Y_INFO as Number = 40;        // total + heart + HR
    private const Y_BIG as Number = 92;         // vcenter del lap actual
    private const Y_TOP_DOTS as Number = 128;   // indicador superior (si scrolled)
    private const Y_LAP_N as Number = 148;
    private const Y_LAP_N1 as Number = 168;
    private const Y_LAP_N2 as Number = 184;
    private const Y_BOT_DOTS as Number = 193;   // indicador inferior
    private const Y_BATTERY as Number = 160;    // batería en STOPPED sin laps

    // Anclas horizontales para total / heart / HR
    private const X_TOTAL_RIGHT_OFFSET as Number = 18;   // total acaba en cx - 18
    private const X_HEART_OFFSET as Number = 22;         // centro del corazón en cx + 22
    private const X_HR_LEFT_OFFSET as Number = 30;       // texto HR empieza en cx + 30

    private var _ticker as Timer.Timer;
    private var _currentTickPeriod as Number;
    private var _scrollOffset as Number;
    private var _lastFullUpdate as Number = -1000;
    private var _lastState as Number = -1;
    private var _lastLapCount as Number = -1;
    private var _lastScrollOffset as Number = -1;
    private var _lastDark as Boolean = false;
    private var _themeDark as Boolean = false;
    private var _lastError as Boolean = false;
    private var _fastestLapMs as Number = 0;
    private var _fastestLapCount as Number = -1;
    private var _frame as Graphics.BufferedBitmap?;
    private var _lapPreviewUntilMs as Number = 0;
    private var _lapPreviewMs as Number = 0;

    // Caches del big lap: el string formateado solo cambia cuando avanza la
    // décima visible, y la fuente solo cambia si el ancho cambia. Evitan
    // re-formatear y re-medir en cada refresco de 50 ms.
    private var _cachedBigText as String?;
    private var _cachedBigDecimas as Number;
    private var _cachedBigFont as Graphics.FontDefinition?;
    private var _cachedFontTextLen as Number;

    function initialize() {
        View.initialize();
        _ticker = new Timer.Timer();
        _currentTickPeriod = 0;
        _scrollOffset = 0;
        _cachedBigText = null;
        _cachedBigDecimas = -1;
        _cachedBigFont = null;
        _cachedFontTextLen = -1;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        _lastFullUpdate = System.getTimer() - TICK_IDLE_MS;
        _themeDark = Settings.isThemeDark();
        try {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        } catch (e) {
            // best effort
        }
        _ensureTicker();
    }

    function onHide() as Void {
        _ticker.stop();
        _currentTickPeriod = 0;
    }

    function startTicker() as Void {
        _ensureTicker();
    }

    function stopTicker() as Void {
        _ensureTicker();
    }

    function resetScroll() as Void {
        _scrollOffset = 0;
    }

    function showLapTime() as Void {
        var s = getApp().session;
        var laps = s.getLapTimes();
        if (laps.size() == 0) { return; }
        _lapPreviewMs = laps[laps.size() - 1];
        _lapPreviewUntilMs = s.nowMs() + LAP_PREVIEW_MS;
    }

    function getDisplayedLapMs() as Number {
        var s = getApp().session;
        if (!s.isRunning()) { _lapPreviewUntilMs = 0; }
        if (s.isRunning() && s.nowMs() < _lapPreviewUntilMs) {
            return _lapPreviewMs;
        }
        return s.getCurrentLapElapsedMs();
    }

    function scrollOlder() as Void {
        var laps = getApp().session.getLapCount();
        var maxOffset = (laps > VISIBLE_LAPS) ? laps - VISIBLE_LAPS : 0;
        if (_scrollOffset < maxOffset) {
            _scrollOffset += 1;
        }
    }

    function scrollNewer() as Void {
        if (_scrollOffset > 0) {
            _scrollOffset -= 1;
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    private function _ensureTicker() as Void {
        var desired = getApp().session.isRunning() ? TICK_RUNNING_MS : TICK_IDLE_MS;
        if (_currentTickPeriod != desired) {
            _ticker.stop();
            _ticker.start(method(:onTick), desired, true);
            _currentTickPeriod = desired;
        }
    }

    function onUpdate(screen as Dc) as Void {
        // A device update must receive a complete frame. The physical display
        // buffer is not a reliable cache between calls (black bands on FR55).
        // This app-owned bitmap retains the header/history for fast updates.
        if (_frame == null) {
            _frame = new Graphics.BufferedBitmap({
                :width => screen.getWidth(), :height => screen.getHeight(),
                :palette => [Graphics.COLOR_BLACK, Graphics.COLOR_WHITE,
                    Graphics.COLOR_RED, Graphics.COLOR_GREEN, 0x005500,
                    Graphics.COLOR_YELLOW, Graphics.COLOR_DK_GRAY, Graphics.COLOR_LT_GRAY]
            });
            _lastFullUpdate = System.getTimer() - TICK_IDLE_MS;
        }
        var frame = _frame as Graphics.BufferedBitmap;
        _renderFrame(frame.getDc());
        screen.drawBitmap(0, 0, frame);
    }

    private function _renderFrame(dc as Dc) as Void {
        _ensureTicker();

        var s = getApp().session;
        var w = dc.getWidth();
        var cx = w / 2;

        // Settings change in a menu; onShow reloads them when returning here.
        var isDark = _themeDark;
        var fg = isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var bg = isDark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        // En tema claro el verde brillante destiñe contra el blanco; usamos
        // un verde muy oscuro para contraste cómodo.
        var fastestColor = isDark ? Graphics.COLOR_GREEN : 0x005500;

        var now = System.getTimer();
        var countNow = s.getLapCount();
        var errorNow = s.hasError();
        var fullUpdate = now - _lastFullUpdate >= TICK_IDLE_MS ||
            _lastState != s.getState() || _lastLapCount != countNow ||
            _lastScrollOffset != _scrollOffset || _lastDark != isDark ||
            _lastError != errorNow;
        if (!fullUpdate) {
            // Retain pixels in our own bitmap, never in the system's buffer.
            var text = _getBigText(getDisplayedLapMs());
            if (text != _lastDrawnBigText) {
                dc.setColor(bg, bg);
                dc.fillRectangle(0, Y_INFO + 14, w, Y_TOP_DOTS - Y_INFO - 20);
                dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
                _drawBigTime(dc, cx, text);
            }
            return;
        }
        _lastFullUpdate = now;
        _lastState = s.getState();
        _lastLapCount = countNow;
        _lastScrollOffset = _scrollOffset;
        _lastDark = isDark;
        _lastError = errorNow;

        dc.setColor(fg, bg);
        dc.clear();
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        // ===== Reloj arriba =====
        var clock = System.getClockTime();
        var clockText = clock.hour.format("%02d") + ":" + clock.min.format("%02d");
        if (errorNow) {
            clockText = WatchUi.loadResource(Rez.Strings.RecordingFailed) as String;
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, Y_CLOCK, Graphics.FONT_TINY, clockText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        // ===== Total (izq.) + corazón + HR (dcha.) =====
        var totalText = StopwatchSession.formatTotal(s.getTotalElapsedMs());
        dc.drawText(cx - X_TOTAL_RIGHT_OFFSET, Y_INFO, Graphics.FONT_XTINY, totalText,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        _drawHeart(dc, cx + X_HEART_OFFSET, Y_INFO);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        var hrText = _getHrText();
        dc.drawText(cx + X_HR_LEFT_OFFSET, Y_INFO, Graphics.FONT_XTINY, hrText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // ===== Lap actual (grande) =====
        var bigText;
        if (s.isStopped() && s.getLapCount() == 0) {
            bigText = "00.0";
        } else {
            bigText = _getBigText(getDisplayedLapMs());
        }
        _drawBigTime(dc, cx, bigText);

        // ===== Historial de vueltas =====
        var laps = s.getLapTimes();
        var count = laps.size();
        if (count > 0) {
            var maxOffset = (count > VISIBLE_LAPS) ? count - VISIBLE_LAPS : 0;
            if (_scrollOffset > maxOffset) { _scrollOffset = maxOffset; }
            if (_scrollOffset < 0) { _scrollOffset = 0; }

            // The history only changes when a lap is added or a session resets.
            if (_fastestLapCount != count) {
                _fastestLapMs = laps[0];
                for (var k = 1; k < count; k += 1) {
                    if (laps[k] < _fastestLapMs) {
                        _fastestLapMs = laps[k];
                    }
                }
                _fastestLapCount = count;
            }

            // Indicador superior: solo cuando hay vueltas más nuevas fuera de la
            // ventana (es decir, cuando hemos scrolleado hacia atrás).
            if (count > VISIBLE_LAPS && _scrollOffset > 0) {
                dc.drawText(cx, Y_TOP_DOTS, Graphics.FONT_TINY, "...",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }

            var ys = [Y_LAP_N, Y_LAP_N1, Y_LAP_N2];
            var fonts = [Graphics.FONT_TINY, Graphics.FONT_XTINY, Graphics.FONT_XTINY];
            for (var slot = 0; slot < VISIBLE_LAPS; slot += 1) {
                var i = count - 1 - _scrollOffset - slot;
                if (i < 0) { break; }
                var prefix = "v" + (i + 1).toString();
                var time = StopwatchSession.formatLapSmall(laps[i]);
                var isFastest = (laps[i] == _fastestLapMs);
                _drawLapRow(dc, cx, ys[slot], fonts[slot], prefix, time,
                    isFastest, fg, fastestColor);
            }

            // Indicador inferior: restablecer fg porque _drawLapRow puede
            // haberlo dejado en verde (vuelta más rápida).
            if (count > VISIBLE_LAPS && _scrollOffset < maxOffset) {
                dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, Y_BOT_DOTS, Graphics.FONT_XTINY, "...",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        } else if (s.isStopped()) {
            _fastestLapCount = -1;
            // Sin vueltas y en reposo: aprovecha el hueco para mostrar la
            // batería con su icono coloreado y el porcentaje.
            _drawBattery(dc, cx, Y_BATTERY, fg);
        }
    }

    // Devuelve el string del big lap, reutilizando el cache mientras estemos
    // dentro de la misma décima.
    private function _getBigText(elapsedMs as Number) as String {
        var decimas = elapsedMs / 100;
        if (decimas == _cachedBigDecimas && _cachedBigText != null) {
            return _cachedBigText as String;
        }
        _cachedBigText = StopwatchSession.formatLapBig(elapsedMs);
        _cachedBigDecimas = decimas;
        return _cachedBigText as String;
    }

    private var _lastDrawnBigText as String = "";

    private function _drawBigTime(dc as Dc, cx as Number, text as String) as Void {
        dc.drawText(cx, Y_BIG, _pickBigFont(dc, text), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        _lastDrawnBigText = text;
    }

    // Pinta una fila del historial: prefijo "vN " en rojo + tiempo en el color
    // de tema (o el verde de la vuelta más rápida). Centrado horizontal.
    private function _drawLapRow(
        dc as Dc, cx as Number, y as Number, font as Graphics.FontDefinition,
        prefix as String, time as String, isFastest as Boolean,
        fgColor as Number, fastestColor as Number
    ) as Void {
        var sep = " ";
        var prefixW = dc.getTextWidthInPixels(prefix + sep, font);
        var timeW = dc.getTextWidthInPixels(time, font);
        var totalW = prefixW + timeW;
        var startX = cx - totalW / 2;

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, y, font, prefix + sep,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var timeColor = isFastest ? fastestColor : fgColor;
        dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + prefixW, y, font, time,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Corazón 8x7 dibujado con dos círculos y un triángulo. Cero recursos.
    private function _drawHeart(dc as Dc, cx as Number, cy as Number) as Void {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 2, cy - 1, 2);
        dc.fillCircle(cx + 2, cy - 1, 2);
        var pts = [[cx - 4, cy + 1], [cx + 4, cy + 1], [cx, cy + 4]];
        dc.fillPolygon(pts);
    }

    private function _getHrText() as String {
        var info = Activity.getActivityInfo();
        if (info != null) {
            var hr = info.currentHeartRate;
            if (hr != null) { return hr.toString(); }
        }
        return "--";
    }

    // Batería: icono rectangular + tip a la derecha, relleno proporcional al
    // porcentaje y coloreado según nivel (verde > 50, amarillo 20-50, rojo
    // < 20). Texto del porcentaje a la derecha del icono. Todo centrado en cx.
    private function _drawBattery(dc as Dc, cx as Number, cy as Number,
            fg as Number) as Void {
        var stats = System.getSystemStats();
        if (stats == null || stats.battery == null) { return; }
        var pctInt = stats.battery.toNumber();
        if (pctInt < 0) { pctInt = 0; }
        if (pctInt > 100) { pctInt = 100; }

        var bodyW = 36;
        var bodyH = 16;
        var tipW = 3;
        var tipH = 8;
        var gap = 6;

        var pctText = pctInt.toString() + "%";
        var font = Graphics.FONT_TINY;
        var textW = dc.getTextWidthInPixels(pctText, font);

        var iconW = bodyW + tipW;
        var totalW = iconW + gap + textW;
        var startX = cx - totalW / 2;

        var bodyX = startX;
        var bodyY = cy - bodyH / 2;

        // Color del nivel
        var lvlColor;
        if (pctInt > 50) {
            lvlColor = Graphics.COLOR_GREEN;
        } else if (pctInt > 20) {
            lvlColor = Graphics.COLOR_YELLOW;
        } else {
            lvlColor = Graphics.COLOR_RED;
        }

        // Outline de la batería en color del nivel (con esquinas suavemente
        // redondeadas, radio 2; doble línea para que el grosor se note).
        dc.setColor(lvlColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bodyX, bodyY, bodyW, bodyH, 2);
        dc.drawRoundedRectangle(bodyX + 1, bodyY + 1, bodyW - 2, bodyH - 2, 2);
        // Tip
        dc.fillRectangle(bodyX + bodyW, cy - tipH / 2, tipW, tipH);

        // Relleno interior proporcional, también con esquinas redondeadas.
        var pad = 3;
        var maxFillW = bodyW - 2 * pad;
        var fillW = (maxFillW * pctInt) / 100;
        if (fillW > 0) {
            dc.fillRoundedRectangle(bodyX + pad, bodyY + pad,
                fillW, bodyH - 2 * pad, 1);
        }

        // Porcentaje a la derecha en color de tema
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + iconW + gap, cy, font, pctText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // El lap actual nunca usa NUMBER_THAI_HOT: aunque cabría en ancho para
    // textos cortos, su altura invade la fila de total/HR. NUMBER_HOT es el
    // tope; MEDIUM solo como fallback si el ancho excede el screen + 8 px.
    // Cache por longitud del texto: el ancho cambia con la longitud (4 chars
    // "SS.d", 6 "M:SS.d", 7 "MM:SS.d") así que basta con esa clave.
    private function _pickBigFont(dc as Dc, text as String) as Graphics.FontDefinition {
        var len = text.length();
        if (len == _cachedFontTextLen && _cachedBigFont != null) {
            return _cachedBigFont as Graphics.FontDefinition;
        }
        var w = dc.getWidth();
        if (dc.getTextWidthInPixels(text, Graphics.FONT_NUMBER_HOT) <= w + 8) {
            _cachedBigFont = Graphics.FONT_NUMBER_HOT;
        } else {
            _cachedBigFont = Graphics.FONT_NUMBER_MEDIUM;
        }
        _cachedFontTextLen = len;
        return _cachedBigFont as Graphics.FontDefinition;
    }
}
