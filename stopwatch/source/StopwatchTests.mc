import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:test)
class TestClockSession extends StopwatchSession {
    var timeMs as Number = 1000;

    function initialize() {
        StopwatchSession.initialize();
    }

    function nowMs() as Number { return timeMs; }
}

(:test)
function pausesAndLapsMatchRecording(logger as Test.Logger) as Boolean {
    var s = new TestClockSession();
    try {
        Test.assert(s.start());
        Test.assert((Activity.getActivityInfo() as Activity.Info).timerState == Activity.TIMER_STATE_ON);
        s.timeMs = 3000;
        Test.assert(s.lap());
        Test.assert(s.getLapTimes()[0] == 2000);
        s.timeMs = 4000;
        Test.assert(s.pause());
        Test.assert((Activity.getActivityInfo() as Activity.Info).timerState != Activity.TIMER_STATE_ON);
        s.timeMs = 14000;
        Test.assert(s.getTotalElapsedMs() == 3000);
        Test.assert(s.getCurrentLapElapsedMs() == 1000);
        Test.assert(!s.lap());
        Test.assert(s.resume());
        Test.assert((Activity.getActivityInfo() as Activity.Info).timerState == Activity.TIMER_STATE_ON);
        s.timeMs = 16000;
        Test.assert(s.getCurrentLapElapsedMs() == 3000);
        s.timeMs = 17000;
        Test.assert(s.pause());
        Test.assert(s.getTotalElapsedMs() == 6000);
        Test.assert(s.save());
        Test.assert(s.getLapCount() == 2);
        Test.assert(s.getLapTimes()[1] == 4000);
        Test.assert(s.isStopped());
        Test.assert(Storage.getValue("ss.totalAtSaveMs") == null);
        return true;
    } finally {
        if (s.isRunning()) { s.pause(); }
        if (s.isPaused()) { s.discard(); }
    }
}

(:test)
function restoreRemainsPaused(logger as Test.Logger) as Boolean {
    var original = new TestClockSession();
    Test.assert(original.start());
    original.timeMs = 2500;
    Test.assert(original.lap());
    original.timeMs = 4000;
    Test.assert(original.pause());
    var restored = new TestClockSession();
    try {
        Test.assert(restored.tryRestore());
        Test.assert(restored.isPaused());
        Test.assert((Activity.getActivityInfo() as Activity.Info).timerState != Activity.TIMER_STATE_ON);
        Test.assert(restored.getTotalElapsedMs() == 3000);
        Test.assert(restored.getCurrentLapElapsedMs() == 1500);
        restored.timeMs = 11000;
        Test.assert(restored.getTotalElapsedMs() == 3000);
        Test.assert(restored.resume());
        restored.timeMs = 12000;
        Test.assert(restored.getTotalElapsedMs() == 4000);
        Test.assert(restored.pause());
        Test.assert(restored.discard());
        Test.assert(Storage.getValue("ss.totalAtSaveMs") == null);
        return true;
    } finally {
        if (restored.isRunning()) { restored.pause(); }
        if (restored.isPaused()) { restored.discard(); }
    }
}

(:test)
function formatBoundaries(logger as Test.Logger) as Boolean {
    Test.assert(StopwatchSession.formatLapBig(0).equals("00.0"));
    Test.assert(StopwatchSession.formatLapBig(59999).equals("59.9"));
    Test.assert(StopwatchSession.formatLapBig(60000).equals("1:00.0"));
    Test.assert(StopwatchSession.formatLapSmall(59999).equals("0:59.99"));
    Test.assert(StopwatchSession.formatTotal(3599999).equals("59:59"));
    Test.assert(StopwatchSession.formatTotal(3600000).equals("1:00:00"));
    return true;
}

(:test)
function appExitStopsAndSavesRecording(logger as Test.Logger) as Boolean {
    var s = new TestClockSession();
    Test.assert(s.start());
    s.timeMs = 3000;
    try {
        s.forceSaveIfActive();
        Test.assert(s.isStopped());
        Test.assert(!s.hasError());
        Test.assert((Activity.getActivityInfo() as Activity.Info).timerState != Activity.TIMER_STATE_ON);
        Test.assert(s.getLapCount() == 1);
        Test.assert(s.getLapTimes()[0] == 2000);
        Test.assert(Storage.getValue("ss.totalAtSaveMs") == null);
        return true;
    } finally {
        if (s.isRunning()) { s.pause(); }
        if (s.isPaused()) { s.discard(); }
    }
}

(:test)
function lapPreviewExpiresWithoutPausingSession(logger as Test.Logger) as Boolean {
    var previousSession = getApp().session;
    var s = new TestClockSession();
    getApp().session = s;
    try {
        Test.assert(s.start());
        s.timeMs = 3000;
        Test.assert(s.lap());
        var view = new StopwatchView();
        view.showLapTime();
        s.timeMs = 6999;
        Test.assert(view.getDisplayedLapMs() == 2000);
        Test.assert(s.getCurrentLapElapsedMs() == 3999);
        Test.assert(s.isRunning());
        s.timeMs = 7000;
        Test.assert(view.getDisplayedLapMs() == 4000);
        Test.assert(s.getTotalElapsedMs() == 6000);
        Test.assert(s.pause());
        Test.assert(view.getDisplayedLapMs() == 4000);
        Test.assert(s.discard());
        return true;
    } finally {
        if (s.isRunning()) { s.pause(); }
        if (s.isPaused()) { s.discard(); }
        getApp().session = previousSession;
    }
}
