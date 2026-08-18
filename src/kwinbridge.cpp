#include "kwinbridge.h"

#include <QDBusConnection>
#include <QDBusServiceWatcher>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QProcess>
#include <QScopeGuard>
#include <QStringList>
#include <QTemporaryFile>
#include <QTextStream>
#include <QTimer>

KWinBridge::KWinBridge(QObject *parent) : QObject(parent)
{
    startPositionWatch();

    // Recovery path for a robustness gap flagged in Task 7's review:
    // startPositionWatch() above only ever runs once, from this
    // constructor. Its script lives inside KWin's own process, so if KWin
    // ever restarts mid-session (a real possibility on a Wayland session --
    // a crash, or an explicit `kwin_wayland --replace`) the watcher script
    // dies with the old KWin process and nothing would otherwise reload it:
    // position persistence would go silently inert for the rest of this
    // app's life, with no other symptom at all (queryRealGeometry() and
    // setPinned() both load their own short-lived scripts on demand and are
    // unaffected by this). It would also cover the unlikely startup-race
    // case of this autostart daemon starting before KWin owns
    // "org.kde.KWin" on the session bus yet.
    //
    // Parented to `this` (not stored as a member) so it lives exactly as
    // long as this KWinBridge does -- Qt's parent-child ownership frees it
    // automatically; no manual lifetime management needed. Every
    // (re-)registration re-runs startPositionWatch(), which itself
    // unloads-before-loads (see its own comment), so a restart-triggered
    // reload can't collide with a script left behind by the previous KWin
    // process.
    auto *kwinWatcher = new QDBusServiceWatcher(QStringLiteral("org.kde.KWin"),
        QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForRegistration, this);
    QObject::connect(kwinWatcher, &QDBusServiceWatcher::serviceRegistered,
        this, [this](const QString &) { startPositionWatch(); });
}

QString KWinBridge::ruleGroupName(const QString &stickerId)
{
    return QStringLiteral("kdestickers-sticker-%1").arg(stickerId);
}

void KWinBridge::removeRuleIdFromList(const QString &ruleId) const
{
    QProcess readProcess;
    readProcess.start(QStringLiteral("kreadconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), QStringLiteral("General"),
         QStringLiteral("--key"), QStringLiteral("rules")});
    readProcess.waitForFinished();
    const QString existing = QString::fromUtf8(readProcess.readAllStandardOutput()).trimmed();

    QStringList ids = existing.split(QLatin1Char(','), Qt::SkipEmptyParts);
    ids.removeAll(ruleId);
    const QString updated = ids.join(QLatin1Char(','));

    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), QStringLiteral("General"),
         QStringLiteral("--key"), QStringLiteral("rules"), updated});
}

void KWinBridge::addRuleIdToList(const QString &ruleId) const
{
    QProcess readProcess;
    readProcess.start(QStringLiteral("kreadconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), QStringLiteral("General"),
         QStringLiteral("--key"), QStringLiteral("rules")});
    readProcess.waitForFinished();
    const QString existing = QString::fromUtf8(readProcess.readAllStandardOutput()).trimmed();

    QStringList ids = existing.split(QLatin1Char(','), Qt::SkipEmptyParts);
    if (!ids.contains(ruleId)) {
        ids.append(ruleId);
    }
    const QString updated = ids.join(QLatin1Char(','));

    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), QStringLiteral("General"),
         QStringLiteral("--key"), QStringLiteral("rules"), updated});
}

bool KWinBridge::reconfigureKWin() const
{
    return QProcess::execute(QStringLiteral("qdbus6"),
        {QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
         QStringLiteral("org.kde.KWin.reconfigure")}) == 0;
}

void KWinBridge::removeRules(const QString &stickerId) const
{
    const QString ruleId = ruleGroupName(stickerId);

    removeRuleIdFromList(ruleId);
    reconfigureKWin();

    // Unlike setPinned(false) (see its .cpp comment), a real deletion is
    // supposed to fully delist this group -- there is no position/pin state
    // left to preserve for a sticker that no longer exists. Ordering still
    // matters for the defensive writes below, though, and for the same
    // measured reason: KWin's reconfigure handler deletes an unlisted rule
    // group from kwinrulesrc entirely as part of reconfigure (confirmed
    // directly, see setPinned()'s comment for the repro), so writing these
    // keys BEFORE the delisting reconfigureKWin() above would just get
    // thrown away by the very call that follows it. Writing them AFTER
    // recreates a fresh, empty group containing only these defensive
    // values, sitting inertly outside rules= until some later drag/pin
    // action re-lists this exact id.
    //
    // Flagged during Task 7's review as a second path to the same bug:
    // sticker ids are reused (newStickerId() is max+1), so deleting a
    // pinned sticker and later creating a new one that happens to land on
    // the same freed id could otherwise leave the OLD sticker's
    // desktopsrule=2 (Force) sitting in this group, ready to silently
    // re-pin the brand new sticker the first time it gets dragged (which
    // re-lists the group via updatePositionRule()'s addRuleIdToList()).
    // Neutralising desktopsrule here means a resurrected group is inert on
    // the pin axis regardless of what a previous occupant of this id left
    // behind.
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("desktopsrule"), QStringLiteral("1")});

    // Same defensive argument, applied to the position axis: flagged during
    // the final whole-branch review as the same id-reuse hazard, one field
    // over. If a resurrected group (same id-reuse path as above) still
    // carries position/positionrule from a deleted, previously-*dragged*
    // sticker -- the prune above has already been observed to not be
    // perfectly deterministic here, see Task 7's fix-round report,
    // "asymmetric desktopsrule persistence" -- a brand new sticker that
    // gets pinned before its first drag would re-list the group via
    // setPinned(true)'s addRuleIdToList() and could silently inherit a
    // stale position it never actually had. Neutralising positionrule here
    // (1 = Unused, KWin's "rule doesn't apply" value) keeps a resurrected
    // group inert on the position axis too, regardless of what a previous
    // occupant of this id left behind.
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("positionrule"), QStringLiteral("1")});
}

void KWinBridge::receiveGeometry(const QString &windowTitle, const QString &geometry)
{
    const QStringList parts = geometry.split(QLatin1Char(','));
    if (parts.size() != 2) {
        return;
    }
    bool xOk = false;
    bool yOk = false;
    const double x = parts.at(0).toDouble(&xOk);
    const double y = parts.at(1).toDouble(&yOk);
    if (!xOk || !yOk) {
        return;
    }
    emit geometryReported(windowTitle, x, y);
}

void KWinBridge::receiveMoveFinished(const QString &windowTitle)
{
    emit moveFinished(windowTitle);
}

// Escapes a string for safe embedding inside a double-quoted JS string
// literal in the generated KWin script. Sticker titles come from user data
// (the sticker id), so they must not be able to break out of the literal.
static QString jsQuote(const QString &value)
{
    QString escaped = value;
    escaped.replace(QLatin1Char('\\'), QStringLiteral("\\\\"));
    escaped.replace(QLatin1Char('"'), QStringLiteral("\\\""));
    escaped.replace(QLatin1Char('\n'), QStringLiteral("\\n"));
    escaped.replace(QLatin1Char('\r'), QStringLiteral("\\r"));
    return escaped;
}

QPointF KWinBridge::queryRealGeometry(const QString &windowTitle)
{
    if (m_geometryQueryInFlight) {
        return QPointF(-1, -1);
    }
    m_geometryQueryInFlight = true;
    const QScopeGuard releaseGuard([this] { m_geometryQueryInFlight = false; });

    QPointF result(-1, -1);
    bool received = false;

    QEventLoop loop;
    QTimer timeoutTimer;
    timeoutTimer.setSingleShot(true);
    QObject::connect(&timeoutTimer, &QTimer::timeout, &loop, &QEventLoop::quit);

    QMetaObject::Connection conn = QObject::connect(this, &KWinBridge::geometryReported,
        this, [&](const QString &title, double x, double y) {
            if (title == windowTitle) {
                result = QPointF(x, y);
                received = true;
                loop.quit();
            }
        });

    // KWin only accepts a script as a file path, so the query has to be
    // materialised on disk for the duration of the call. Default autoRemove
    // deletes it when this object goes out of scope, which is after KWin has
    // both read and unloaded the script, and covers every early return too.
    QTemporaryFile scriptFile(QDir::tempPath() + QStringLiteral("/kde-stickers-geom-XXXXXX.js"));
    if (scriptFile.open()) {
        const QString scriptPath = scriptFile.fileName();
        const QString quotedTitle = jsQuote(windowTitle);
        QTextStream stream(&scriptFile);
        // Geometry is concatenated into a single "x,y" string rather than
        // passed as two numbers -- see receiveGeometry()'s declaration for
        // the measured reason (KWin marshals integral JS numbers as int32,
        // which silently fails to match a double-typed D-Bus method).
        stream << QStringLiteral(
            "var wins = workspace.windowList();\n"
            "for (var i = 0; i < wins.length; i++) {\n"
            "    if (wins[i].caption === \"%1\") {\n"
            "        var g = wins[i].frameGeometry;\n"
            "        callDBus(\"org.kde.stickers\", \"/KWinBridge\","
            " \"org.kde.stickers.KWinBridge\", \"receiveGeometry\","
            " \"%1\", \"\" + g.x + \",\" + g.y);\n"
            "        break;\n"
            "    }\n"
            "}\n"
        ).arg(quotedTitle);
        stream.flush();
        scriptFile.close();

        // loadScript() returns an integer script id (NOT a D-Bus path, as
        // one might assume); the script's own object lives at
        // /Scripting/Script<id>. Verified against
        // `qdbus6 org.kde.KWin /Scripting`, which declares
        // "method int org.kde.kwin.Scripting.loadScript(QString, QString)".
        const QString pluginName = QStringLiteral("kde-stickers-geom-query");

        // Unload first, before loading. KWin refuses a loadScript() whose
        // plugin name is already registered -- it returns -1 rather than
        // replacing or reusing the existing script -- and the name stays
        // registered for the rest of the KWin session if this process dies
        // between load and unload (e.g. killed mid-query, which is easy
        // since the call blocks for up to 2s). Without this pre-unload, a
        // single unclean exit would make every later query in that session
        // fail with (-1, -1) until KWin itself restarts. Verified by
        // loading two different files under one name: the second returned
        // -1, and only succeeded after an explicit unloadScript.
        QProcess::execute(QStringLiteral("qdbus6"),
            {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
             QStringLiteral("org.kde.kwin.Scripting.unloadScript"), pluginName});

        QProcess loadProcess;
        loadProcess.start(QStringLiteral("qdbus6"),
            {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
             QStringLiteral("org.kde.kwin.Scripting.loadScript"),
             scriptPath, pluginName});
        loadProcess.waitForFinished();
        const QString scriptId = QString::fromUtf8(loadProcess.readAllStandardOutput()).trimmed();

        bool idOk = false;
        const int id = scriptId.toInt(&idOk);
        if (idOk && id >= 0) {
            // Started detached rather than waited on: the script calls back
            // into this very process over D-Bus, and this process cannot
            // answer that call while blocked inside waitForFinished().
            QProcess::startDetached(QStringLiteral("qdbus6"),
                {QStringLiteral("org.kde.KWin"),
                 QStringLiteral("/Scripting/Script%1").arg(id),
                 QStringLiteral("org.kde.kwin.Script.run")});

            timeoutTimer.start(2000);
            loop.exec();

            // Release the name again so KWin is not left holding a script
            // registration for a file this method is about to delete.
            QProcess::execute(QStringLiteral("qdbus6"),
                {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
                 QStringLiteral("org.kde.kwin.Scripting.unloadScript"), pluginName});
        }
    }

    QObject::disconnect(conn);

    return received ? result : QPointF(-1, -1);
}

void KWinBridge::unpinLiveWindow(const QString &windowTitle) const
{
    // Fire-and-forget: unlike queryRealGeometry, this script doesn't call
    // back into the app (no callDBus, no return value needed), so there's
    // no risk of the callback deadlocking against a blocked event loop --
    // a plain blocking QProcess::execute for both run() and the unload
    // afterward is safe here.
    QTemporaryFile scriptFile(QDir::tempPath() + QStringLiteral("/kde-stickers-unpin-XXXXXX.js"));
    if (!scriptFile.open()) {
        return;
    }
    QTextStream stream(&scriptFile);
    stream << QStringLiteral(
        "var wins = workspace.windowList();\n"
        "for (var i = 0; i < wins.length; i++) {\n"
        "    if (wins[i].caption === \"%1\") {\n"
        "        wins[i].onAllDesktops = false;\n"
        "        break;\n"
        "    }\n"
        "}\n"
    ).arg(jsQuote(windowTitle));
    stream.flush();
    scriptFile.close();

    const QString pluginName = QStringLiteral("kde-stickers-unpin");

    // Same unload-before-load pattern as queryRealGeometry, same reason:
    // KWin refuses loadScript() under an already-registered plugin name.
    QProcess::execute(QStringLiteral("qdbus6"),
        {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
         QStringLiteral("org.kde.kwin.Scripting.unloadScript"), pluginName});

    QProcess loadProcess;
    loadProcess.start(QStringLiteral("qdbus6"),
        {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
         QStringLiteral("org.kde.kwin.Scripting.loadScript"),
         scriptFile.fileName(), pluginName});
    loadProcess.waitForFinished();
    const QString scriptId = QString::fromUtf8(loadProcess.readAllStandardOutput()).trimmed();

    bool idOk = false;
    const int id = scriptId.toInt(&idOk);
    if (idOk && id >= 0) {
        QProcess::execute(QStringLiteral("qdbus6"),
            {QStringLiteral("org.kde.KWin"),
             QStringLiteral("/Scripting/Script%1").arg(id),
             QStringLiteral("org.kde.kwin.Script.run")});
        QProcess::execute(QStringLiteral("qdbus6"),
            {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
             QStringLiteral("org.kde.kwin.Scripting.unloadScript"), pluginName});
    }
}

void KWinBridge::setPinned(const QString &stickerId, const QString &windowTitle, bool pinned) const
{
    const QString ruleId = ruleGroupName(stickerId);

    if (!pinned) {
        // Pin and position deliberately share ONE KWin rule group per
        // sticker (kdestickers-sticker-<id>) -- a sticker that is both
        // pinned and has a known dragged-to position needs desktops/
        // desktopsrule and position/positionrule to coexist in the same
        // group (see updatePositionRule()'s .cpp comment). That sharing is
        // exactly why unpinning must NEVER delist the group from [General]
        // rules= in kwinrulesrc.
        //
        // Final-review finding: an earlier version of this branch called
        // removeRuleIdFromList(ruleId) followed by reconfigureKWin(). That
        // looked safe in isolation but silently destroyed any saved
        // position: KWin's own reconfigure handler deletes an unlisted rule
        // group from kwinrulesrc *entirely* as part of reconfigure, not
        // just its listing (confirmed directly: wrote a throwaway group,
        // listed it, reconfigured -- group intact; delisted it, reconfigured
        // again -- the whole group vanished from the file). Since
        // updatePositionRule() writes position/positionrule into this exact
        // group from an earlier drag, delisting-then-reconfiguring wiped
        // those keys too, and the subsequent recreate-with-desktopsrule=1
        // only ever produced a *fresh*, position-less group. Net effect:
        // pin -> drag -> unpin -> restart silently lost the sticker's saved
        // position, reopening it at KWin's default cascade placement
        // instead. Task 7's own fix-round verification always dragged
        // *after* unpinning (which re-writes position and re-lists the
        // group), so this exact order was never exercised until this
        // review.
        //
        // Fix: never delist on unpin. Instead, overwrite desktopsrule to 1
        // (DontAffect) *in place* while the group stays listed the entire
        // time. This write is still required -- the pinned branch below
        // never clears desktops=/desktopsrule=2 from this group, it only
        // ever ADDS keys to it, so without an explicit overwrite here a
        // since-unpinned sticker that gets dragged again (which re-lists
        // the group via updatePositionRule()'s addRuleIdToList()) would
        // silently carry the old Force rule forward. Because the group
        // stays listed while reconfigureKWin() runs below, KWin updates the
        // live rule from Force to DontAffect instead of pruning the group,
        // so position/positionrule/wmclass/title and every other key
        // already present survive untouched.
        QProcess::execute(QStringLiteral("kwriteconfig6"),
            {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
             QStringLiteral("--group"), ruleId,
             QStringLiteral("--key"), QStringLiteral("desktopsrule"), QStringLiteral("1")});

        // Order matters: write the key and let reconfigure fully land
        // BEFORE touching the live window, or the still-active Force rule
        // silently re-pins it out from under the script (Task 5 finding).
        //
        // "Fully land" needs an explicit wait, not just a blocking D-Bus
        // round-trip: reconfigureKWin()'s QProcess::execute only waits for
        // org.kde.KWin.reconfigure's D-Bus *reply*, which KWin sends before
        // it has actually finished rebuilding its internal rule cache from
        // the updated kwinrulesrc. Measured directly while implementing
        // Task 7: calling unpinLiveWindow() immediately after
        // reconfigureKWin() returns reproduced the still-pinned bug on
        // every single trial (window stayed onAllDesktops=true), while
        // adding a settle wait first fixed it reliably. This is exactly the
        // "looks like a flaky KWin bug" trap Task 5's spike warned about --
        // it is a race, not a KWin defect. The 300ms below is a generous
        // margin over the ~50-100ms observed to be sufficient, and is
        // unrelated to this round's delist-vs-overwrite fix above.
        reconfigureKWin();

        QEventLoop settleLoop;
        QTimer::singleShot(300, &settleLoop, &QEventLoop::quit);
        settleLoop.exec();
        unpinLiveWindow(windowTitle);
        return;
    }

    addRuleIdToList(ruleId);
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclass"), QStringLiteral("org.kde.stickers")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclassmatch"), QStringLiteral("2")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclasscomplete"), QStringLiteral("false")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("title"), windowTitle});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("titlematch"), QStringLiteral("1")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("types"), QStringLiteral("1")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("desktops"), QStringLiteral("")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("desktopsrule"), QStringLiteral("2")});

    reconfigureKWin();
}

// Writes to the *same* rule group id (kdestickers-sticker-<id>) that
// setPinned() may also write to -- a sticker that is both pinned and has a
// known position ends up with one rule group carrying both
// desktops/desktopsrule and position/positionrule keys, which is valid KWin
// rule syntax (a single rule group can force multiple properties at once).
// kwriteconfig6 only touches the specific key given each call, so writing
// position keys here doesn't clobber setPinned()'s desktop keys already in
// the same group, or vice versa.
void KWinBridge::updatePositionRule(const QString &stickerId, const QString &windowTitle, int x, int y) const
{
    const QString ruleId = ruleGroupName(stickerId);

    addRuleIdToList(ruleId);
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclass"), QStringLiteral("org.kde.stickers")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclassmatch"), QStringLiteral("2")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("wmclasscomplete"), QStringLiteral("false")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("title"), windowTitle});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("titlematch"), QStringLiteral("1")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("types"), QStringLiteral("1")});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("position"),
         QStringLiteral("%1,%2").arg(x).arg(y)});
    QProcess::execute(QStringLiteral("kwriteconfig6"),
        {QStringLiteral("--file"), QStringLiteral("kwinrulesrc"),
         QStringLiteral("--group"), ruleId,
         QStringLiteral("--key"), QStringLiteral("positionrule"), QStringLiteral("3")});

    reconfigureKWin();
}

void KWinBridge::startPositionWatch() const
{
    // Not a QTemporaryFile: this script must go on being readable/valid for
    // KWin's whole session (see the .h comment -- it is loaded once and
    // deliberately never unloaded), so an auto-deleted-on-scope-exit temp
    // file would be the wrong tool here, unlike queryRealGeometry's and
    // unpinLiveWindow's short-lived scripts. A fixed path is overwritten
    // fresh on every app startup, which is fine: KWin only reads the file
    // at loadScript() time, not afterward.
    const QString scriptPath = QDir::tempPath() + QStringLiteral("/kde-stickers-position-watch.js");
    QFile scriptFile(scriptPath);
    if (!scriptFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return;
    }
    QTextStream stream(&scriptFile);
    // attach() connects interactiveMoveResizeFinished (fired by KWin itself
    // when an interactive move/resize grab ends -- see receiveMoveFinished's
    // .h comment for why this, and not any Qt/QML-side signal, is the only
    // reliable "the drag just ended" trigger on this stack) on every sticker
    // window, matched by caption prefix rather than exact title since this
    // one script has to cover every sticker, present and future, not one
    // specific window the way queryRealGeometry's per-call script does.
    // windowAdded covers stickers created later via the "+" button;
    // existing ones are attached up front from the initial windowList().
    stream << QStringLiteral(
        "function kdeStickersAttach(win) {\n"
        "    if (win.caption.indexOf(\"Sticker \") !== 0) return;\n"
        "    win.interactiveMoveResizeFinished.connect(function() {\n"
        "        callDBus(\"org.kde.stickers\", \"/KWinBridge\","
        " \"org.kde.stickers.KWinBridge\", \"receiveMoveFinished\", win.caption);\n"
        "    });\n"
        "}\n"
        "var kdeStickersWins = workspace.windowList();\n"
        "for (var i = 0; i < kdeStickersWins.length; i++) {\n"
        "    kdeStickersAttach(kdeStickersWins[i]);\n"
        "}\n"
        "workspace.windowAdded.connect(kdeStickersAttach);\n"
    );
    stream.flush();
    scriptFile.close();

    const QString pluginName = QStringLiteral("kde-stickers-position-watch");

    // Unload-before-load, same reasoning as queryRealGeometry/
    // unpinLiveWindow: KWin refuses loadScript() under an already-registered
    // plugin name, and a previous unclean exit of this app would otherwise
    // leave this name registered (pointing at a now-dead D-Bus service)
    // forever, permanently blocking every future position watch.
    QProcess::execute(QStringLiteral("qdbus6"),
        {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
         QStringLiteral("org.kde.kwin.Scripting.unloadScript"), pluginName});

    QProcess loadProcess;
    loadProcess.start(QStringLiteral("qdbus6"),
        {QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"),
         QStringLiteral("org.kde.kwin.Scripting.loadScript"),
         scriptPath, pluginName});
    loadProcess.waitForFinished();
    const QString scriptId = QString::fromUtf8(loadProcess.readAllStandardOutput()).trimmed();

    bool idOk = false;
    const int id = scriptId.toInt(&idOk);
    if (idOk && id >= 0) {
        // Deliberately no matching unloadScript call anywhere -- this script
        // is meant to keep running (and its signal connections keep living)
        // for the rest of the KWin session, unlike every other script in
        // this class.
        QProcess::execute(QStringLiteral("qdbus6"),
            {QStringLiteral("org.kde.KWin"),
             QStringLiteral("/Scripting/Script%1").arg(id),
             QStringLiteral("org.kde.kwin.Script.run")});
    }
}
