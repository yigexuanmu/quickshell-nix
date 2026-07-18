import QtQuick
import qs.Common

Item {
    id: root

    property bool active: false
    property bool acceptSamples: false
    property bool sourceAvailable: false
    property double amplitude: 0
    property double sampleTimestampMs: 0
    property int activeBars: 32
    property int waitingBars: 9
    property real barWidth: 3
    property real barGap: 2
    property real minimumHeight: 2
    property real maximumHeight: 30
    property color activeColor: Appearance.colors.colError
    property color waitingColor: Appearance.applyAlpha(
        Appearance.colors.colOnSurfaceVariant, 0.32)

    property var _levels: []
    property var _bornAt: []
    property int _head: 0
    property double _lastSampleTimestamp: 0
    property double _lastPushAt: 0
    property real _sampleInterval: 33

    function clamp01(value) {
        return Math.max(0, Math.min(1, Number(value) || 0));
    }

    function logicalLevel(index) {
        if (_levels.length !== activeBars)
            return 0;
        return _levels[(_head + index) % activeBars] || 0;
    }

    function initialize() {
        const levels = [];
        const born = [];
        for (let index = 0; index < activeBars; ++index) {
            levels.push(0);
            born.push(0);
        }
        _levels = levels;
        _bornAt = born;
        _head = 0;
        _lastSampleTimestamp = 0;
        _lastPushAt = Date.now();
        waveformCanvas.requestPaint();
    }

    function pushSample(value, timestamp) {
        if (_levels.length !== activeBars)
            initialize();

        const now = Date.now();
        const previous = logicalLevel(activeBars - 1);
        const previous2 = logicalLevel(activeBars - 2);
        const raw = sourceAvailable ? clamp01(value) : 0;
        const smoothed = 0.70 * raw + 0.20 * previous + 0.10 * previous2;
        const target = Math.max(smoothed, raw * 0.85);

        const replacement = _head;
        _levels[replacement] = target;
        _bornAt[replacement] = now;
        _head = (_head + 1) % activeBars;

        if (_lastSampleTimestamp > 0) {
            _sampleInterval = Math.max(
                24,
                Math.min(50, timestamp - _lastSampleTimestamp)
            );
        }
        _lastSampleTimestamp = timestamp;
        _lastPushAt = now;
        waveformCanvas.requestPaint();
    }

    function animatedHeight(slot, now) {
        const targetHeight = minimumHeight
            + logicalLevel(slot) * (maximumHeight - minimumHeight);
        const physicalIndex = (_head + slot) % activeBars;
        const age = Math.max(0, now - (_bornAt[physicalIndex] || 0));
        if (_bornAt[physicalIndex] <= 0)
            return minimumHeight;

        if (age < 90) {
            const progress = age / 90;
            const eased = 1 - Math.pow(1 - progress, 3);
            return minimumHeight
                + (targetHeight * 1.06 - minimumHeight) * eased;
        }
        if (age < 250) {
            const progress = (age - 90) / 160;
            const eased = 1 - Math.pow(1 - progress, 3);
            return targetHeight * (1.06 - 0.06 * eased);
        }
        return targetHeight;
    }

    onSampleTimestampMsChanged: {
        if (active && acceptSamples && sampleTimestampMs > _lastSampleTimestamp)
            pushSample(amplitude, sampleTimestampMs);
    }
    onActiveBarsChanged: initialize()
    Component.onCompleted: initialize()

    Timer {
        interval: 16
        repeat: true
        running: root.active
        onTriggered: waveformCanvas.requestPaint()
    }

    Canvas {
        id: waveformCanvas

        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const context = getContext("2d");
            context.reset();
            const now = Date.now();
            const pitch = root.barWidth + root.barGap;
            const activeWidth = root.activeBars * pitch - root.barGap;
            const centerY = height / 2;
            const phase = Math.max(
                0,
                Math.min(1, (now - root._lastPushAt) / root._sampleInterval)
            );

            context.save();
            context.beginPath();
            context.rect(0, 0, activeWidth, height);
            context.clip();
            context.fillStyle = root.activeColor;
            for (let slot = 0; slot < root.activeBars; ++slot) {
                const barHeight = root.animatedHeight(slot, now);
                const x = (slot + 1 - phase) * pitch;
                const y = centerY - barHeight / 2;
                const radius = Math.min(root.barWidth / 2, barHeight / 2);
                context.beginPath();
                context.roundedRect(x, y, root.barWidth, barHeight, radius, radius);
                context.fill();
            }
            context.restore();

            context.fillStyle = root.waitingColor;
            for (let slot = 0; slot < root.waitingBars; ++slot) {
                const x = activeWidth + root.barGap + slot * pitch;
                const y = centerY - root.minimumHeight / 2;
                const radius = root.minimumHeight / 2;
                context.beginPath();
                context.roundedRect(
                    x, y, root.barWidth, root.minimumHeight, radius, radius);
                context.fill();
            }
        }
    }
}
