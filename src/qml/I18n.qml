pragma Singleton
import QtQuick
import "SettingsManager.js" as Settings
import Stickers.Storage as App

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
//
// Dictionaries are plain .json files (src/i18n/<code>.json), not .pragma
// library modules like the first version of this file used -- a
// .pragma library needs a static, compile-time `.import "Dictionary_XX.js"`
// per language, so adding one meant touching this file (and CMakeLists.txt)
// every time. JSON files are just *data*, readable at runtime through the
// same FileStorage.readFile() already used for settings.json/stickers.json,
// so availableLanguages can enumerate whatever's actually in that directory
// (FileStorage.listFileBaseNames(), new alongside this rewrite) and load
// each one by its own file name -- adding a language becomes "drop a new
// <code>.json file in src/i18n/, list it in CMakeLists.txt's RESOURCES so
// it's actually bundled in", no other file needs to change.
QtObject {
    id: root

    readonly property string i18nDir: ":/qt/qml/StickersApp/src/i18n"

    function loadDictionary(code) {
        const raw = App.FileStorage.readFile(i18nDir + "/" + code + ".json")
        try {
            return JSON.parse(raw)
        } catch (e) {
            console.error("I18n: failed to parse dictionary for \"" + code + "\":", e)
            return {}
        }
    }

    // Evaluated once (Q_INVOKABLE calls establish no ongoing binding
    // dependency, same reasoning as the header comment above) -- correct,
    // since the set of bundled dictionaries is fixed for the process's
    // whole lifetime, only ever changing between builds.
    readonly property var availableLanguages: {
        const codes = App.FileStorage.listFileBaseNames(i18nDir, "*.json").sort()
        const langs = []
        for (let i = 0; i < codes.length; i++) {
            langs.push({ code: codes[i], strings: loadDictionary(codes[i]) })
        }
        return langs
    }

    property string languageCode: Settings.get().language.code

    function dictFor(code) {
        for (let i = 0; i < availableLanguages.length; i++) {
            if (availableLanguages[i].code === code) return availableLanguages[i].strings
        }
        return availableLanguages.length > 0 ? availableLanguages[0].strings : {}
    }

    // Plain lookup. Falls back to Spanish -- the app's original, most
    // complete dictionary -- if the active language's is missing this key,
    // then to the raw key itself if it's missing everywhere too: visibly
    // broken rather than a silent crash, and easy to grep for.
    function t(key) {
        const dict = dictFor(languageCode)
        if (dict[key] !== undefined) return dict[key]
        const esDict = dictFor("es")
        if (esDict[key] !== undefined) return esDict[key]
        return key
    }

    // Same lookup, with {0}/{1}/... replaced from `args` (a plain array)
    // -- for strings built from a template plus dynamic data (a sticker's
    // name, a count), which plain t() alone can't parameterize.
    function tf(key, args) {
        const template = t(key)
        return template.replace(/\{(\d+)\}/g, function(match, index) {
            const value = args[Number(index)]
            return value !== undefined ? value : match
        })
    }

    function setLanguage(code) {
        languageCode = code
        Settings.update("language", "code", code)
    }
}
