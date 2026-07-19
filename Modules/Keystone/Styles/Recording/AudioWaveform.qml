import QtQuick
import qs.Common

Item {
    id: root

    property bool active: false
    property bool acceptSamples: false
    property bool sourceAvailable: false
    property double amplitude: 0
    property double sampleTimestampMs: 0
    property int activeBars: 22
    property int waitingBars: 5
    property real barWidth: 3
    property real barGap: 3
    property real minimumHeight: 2
    property real maximumHeight: 36
    property color activeColor: Appearance.colors.colError
    property color waitingColor: Appearance.applyAlpha(
        Appearance.colors.colOnSurfaceVariant, 0.32)

    property var _levels: []
    property var _bornAt: []
    property int _head: 0
    property double _lastSourceTimestamp: 0
    property double _lastPushAt: 0
    readonly property int _sampleInterval: 160

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
        _lastSourceTimestamp = 0;
        _lastPushAt = Date.now();
        waveformCanvas.requestPaint();
    }

    function pushSample(value, timestamp) {
        if (_levels.length !== activeBars)
            initialize();

        const now = Date.now();
        const replacement = _head;
        _levels[replacement] = sourceAvailable ? clamp01(value) : 0;
        _bornAt[replacement] = now + Math.max(0, _sampleInterval - 90);
        _head = (_head + 1) % activeBars;
        _lastSourceTimestamp = timestamp;
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
                + (targetHeight * 1.08 - minimumHeight) * eased;
        }
        if (age < 220) {
            const progress = (age - 90) / 130;
            const eased = 1 - Math.pow(1 - progress, 3);
            return targetHeight * (1.08 - 0.08 * eased);
        }
        return targetHeight;
    }

    onSampleTimestampMsChanged: {
        if (active && acceptSamples
                && sampleTimestampMs > _lastSourceTimestamp) {
            pushSample(amplitude, sampleTimestampMs);
        }
    }
    onAcceptSamplesChanged: {
        if (acceptSamples)
            initialize();
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
