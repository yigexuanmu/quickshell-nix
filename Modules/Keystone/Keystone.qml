import QtQuick
import Quickshell.Io
import qs.Services
import qs.Modules.Keystone.Styles.Bangs
import qs.Modules.Keystone.Styles.Pill

Item {
    id: root

    function invoke(methodName): string {
        if (!styleLoader.item || typeof styleLoader.item[methodName] !== "function")
            return "KEYSTONE_UNAVAILABLE";
        return styleLoader.item[methodName]();
    }

    Loader {
        id: styleLoader

        sourceComponent: PersonalizationConfig.keystoneStyle === "pill"
            ? pillStyle
            : bangsStyle
    }

    IpcHandler {
        target: "keystone"

        function cancelRecord(): string { return root.invoke("cancelRecord"); }
        function closeAllOthers(): string { return root.invoke("closeAllOthers"); }
        function currentStyle(): string { return PersonalizationConfig.keystoneStyle; }
        function hub(): string { return root.invoke("hub"); }
        function tools(): string { return root.invoke("tools"); }
    }

    IpcHandler {
        target: "island"

        function cancelRecord(): string { return root.invoke("cancelRecord"); }
        function closeAllOthers(): string { return root.invoke("closeAllOthers"); }
        function currentStyle(): string { return PersonalizationConfig.keystoneStyle; }
        function hub(): string { return root.invoke("hub"); }
        function tools(): string { return root.invoke("tools"); }
    }

    Component {
        id: bangsStyle

        Bangs {}
    }

    Component {
        id: pillStyle

        Pill {}
    }
}
