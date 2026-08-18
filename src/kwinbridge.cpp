#include "kwinbridge.h"

#include <QProcess>
#include <QStringList>

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
