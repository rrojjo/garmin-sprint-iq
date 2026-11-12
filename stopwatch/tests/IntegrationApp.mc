import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Real-time integration run, built separately from the installable application.
// The production view runs throughout; FIT timestamps use the real device clock.
class IntegrationApp extends StopwatchApp {
    private var _steps as Timer.Timer;
    private var _step as Number = 0;
    private var _pausedTotal as Number = 0;
    private var _view as IntegrationView?;

    function initialize() {
        StopwatchApp.initialize();
        _steps = new Timer.Timer();
    }

    function onStart(state as Dictionary?) as Void {
        _steps.start(method(:advance), 1000, true);
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new IntegrationView();
        _view = view;
        return [view, new StopwatchDelegate(view)];
    }

    private function check(condition as Boolean, message as String) as Void {
        if (!condition) {
            _steps.stop();
            System.println("INTEGRATION FAILED: " + message);
            System.exit();
        }
    }

    function advance() as Void {
        _step += 1;
        if (_step == 1) {
            check(session.start(), "start");
        } else if (_step == 3 || _step == 13) {
            check(session.lap(), "lap " + _step);
            (_view as IntegrationView).showLapTime();
        } else if (_step >= 4 && _step <= 6) {
            check((_view as IntegrationView).getDisplayedLapMs() == session.getLapTimes()[0],
                "lap preview did not remain visible for four seconds");
        } else if (_step == 8 || _step == 14) {
            check(session.pause(), "pause");
            check((Activity.getActivityInfo() as Activity.Info).timerState != Activity.TIMER_STATE_ON,
                "native recording still running while paused");
            _pausedTotal = session.getTotalElapsedMs();
        } else if (_step == 11) {
            check(session.getTotalElapsedMs() == _pausedTotal, "pause changed elapsed time");
            check(session.resume(), "resume");
        } else if (_step == 15) {
            var total = session.getTotalElapsedMs();
            check(total >= 9800 && total <= 10200, "active time should be 10 seconds");
            check(session.save(), "save");
            check(session.getLapCount() == 3, "final lap missing or duplicated");
            var laps = session.getLapTimes();
            check(laps[0] + laps[1] + laps[2] == total, "lap time was lost");
            check((_view as IntegrationView).report(), "a visible tenth was skipped");
            System.println("INTEGRATION PASSED: active_ms=" + total + ", laps_ms=" + laps.toString());
            _steps.stop();
            System.exit();
        }
        WatchUi.requestUpdate();
    }
}

class IntegrationView extends StopwatchView {
    private var _lastFrameMs as Number = 0;
    private var _previousRunning as Boolean = false;
    private var _frames as Number = 0;
    private var _maxGapMs as Number = 0;
    private var _maxRenderMs as Number = 0;
    private var _fontHeight as Number = 0;
    private var _lastLapCount as Number = -1;
    private var _lastTenth as Number = 0;
    private var _missedTenths as Number = 0;

    function initialize() { StopwatchView.initialize(); }

    function onUpdate(dc as Graphics.Dc) as Void {
        var start = System.getTimer();
        var session = getApp().session;
        var running = session.isRunning();
        var tenth = session.getCurrentLapElapsedMs() / 100;
        if (running && _previousRunning && session.getLapCount() == _lastLapCount &&
            tenth > _lastTenth + 1) {
            _missedTenths += tenth - _lastTenth - 1;
        }
        _lastTenth = tenth;
        _lastLapCount = session.getLapCount();
        if (running && _previousRunning) {
            var gap = start - _lastFrameMs;
            if (gap > _maxGapMs) { _maxGapMs = gap; }
        }
        if (running) { _frames += 1; }
        _lastFrameMs = start;
        _previousRunning = running;
        // Reproduce a device providing a fresh black surface on every update.
        // The full frame must restore the header and history as well as digits.
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        StopwatchView.onUpdate(dc);
        var renderMs = System.getTimer() - start;
        if (renderMs > _maxRenderMs) { _maxRenderMs = renderMs; }
        _fontHeight = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
    }

    function report() as Boolean {
        System.println("RENDER: running_frames=" + _frames + ", max_gap_ms=" + _maxGapMs +
            ", max_render_ms=" + _maxRenderMs + ", font_height=" + _fontHeight +
            ", skipped_tenths=" + _missedTenths);
        return _missedTenths == 0;
    }
}
