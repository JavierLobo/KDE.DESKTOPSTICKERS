#include "kwinbridge.h"

#include <QDBusConnection>
#include <QDir>
#include <QEventLoop>
#include <QProcess>
#include <QScopeGuard>
#include <QStringList>
#include <QTemporaryFile>
#include <QTextStream>
#include <QTimer>

KWinBridge::KWinBridge(QObject *parent) : QObject(parent) {}

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
    removeRuleIdFromList(ruleGroupName(stickerId));
    reconfigureKWin();
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
