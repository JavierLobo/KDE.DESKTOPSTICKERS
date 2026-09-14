pragma Singleton
import QtQuick
import "SettingsManager.js" as Settings
import "../i18n/Dictionary_ES.js" as ES
import "../i18n/Dictionary_EN.js" as EN

// Translation lookup singleton. A real QML type (not a .pragma library
// module, like SettingsManager.js/StickerManager.js) specifically so that
// `languageCode` is a genuine QML property: a binding that calls
// `I18n.t("some.key")` establishes a dependency on `languageCode` because
// t() reads it as part of the SAME object's property system while that
// binding is being evaluated -- QML's dependency tracking follows through
// a same-engine JS function call like this. It would NOT follow through a
// C++ Q_INVOKABLE call the same way (confirmed earlier in this app: see
// SystemIntegration's installedFontFamilies(), read once at binding-
// creation time and never again) -- that's why this had to be a QML
// object, not a C++ singleton like FileStorage/SystemIntegration.
//
// Named t()/tf(), not tr()/trf(): every QObject (which this becomes under
// the hood, pragma Singleton or not) already inherits a built-in, C++
// QObject::tr(const char*, ...) translation helper. A method actually
// named `tr` risks silently colliding with it instead of overriding it --
// sidestepped rather than conclusively diagnosed, since it was fixed
// together with the real cause below and never tested in isolation.
//
// Registered as a StickersApp-module singleton via `pragma Singleton` --
// NOT auto-detected from that pragma by Qt's CMake tooling (confirmed: the
// file still built and ran without it, just as a plain non-singleton
// type); the QT_QML_SINGLETON_TYPE source file property set on this file
// in CMakeLists.txt is what actually registers it in the qmldir.
//
// Every file using `I18n.t(...)` also needs `import StickersApp` at its
// top, EVEN THOUGH it's already part of that same module and can already
// use e.g. ColorPalette/SettingsRow with no import at all -- confirmed the
// hard way: implicit same-directory visibility covers instantiable
// component TYPES, not singleton VALUE lookups, so without this import
// every `I18n.xxx` access (property or method alike) silently resolved to
// something other than the real singleton instance, throwing "Property
// 'xxx' of object I18n is not a function" / "... of undefined" at
// runtime -- not a build-time error, since the bad reference is only ever
// evaluated as a JS expression at runtime, and NOT a cyclic-import
// rejection either (that specific rejection is a `.pragma library` JS
// `.import`-statement restriction; a plain QML `import` of your own
// containing module is fine).
QtObject {
    id: root

    property string languageCode: Settings.get().language.code

    readonly property var availableLanguages: [
        { code: "es", strings: ES.strings },
        { code: "en", strings: EN.strings }
    ]

    function dictFor(code) {
        for (var i = 0; i < availableLanguages.length; i++) {
            if (availableLanguages[i].code === code) return availableLanguages[i].strings
        }
        return ES.strings
    }

    // Plain lookup. Falls back to Spanish (the complete, "source of truth"
    // dictionary every key is guaranteed to exist in) if the active
    // language's dictionary is missing this key, then to the raw key
    // itself if it's missing everywhere -- visibly broken rather than a
    // silent crash, and easy to grep for.
    function t(key) {
        var dict = dictFor(languageCode)
        if (dict[key] !== undefined) return dict[key]
        if (ES.strings[key] !== undefined) return ES.strings[key]
        return key
    }

    // Same lookup, with {0}/{1}/... replaced from `args` (a plain array)
    // -- for strings built from a template plus dynamic data (a sticker's
    // name, a count), which plain t() alone can't parameterize.
    function tf(key, args) {
        var template = t(key)
        return template.replace(/\{(\d+)\}/g, function(match, index) {
            var value = args[Number(index)]
            return value !== undefined ? value : match
        })
    }

    function setLanguage(code) {
        languageCode = code
        Settings.update("language", "code", code)
    }
}
