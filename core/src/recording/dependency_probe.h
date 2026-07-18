#pragma once

#include "recording_types.h"

#include <QJsonObject>
#include <QList>

namespace Clavis::Recording {

struct DependencyCheck {
    QString name;
    bool ok = false;
    QString path;
    QString message;

    QJsonObject toJson() const;
};

class DependencyProbe {
public:
    QList<DependencyCheck> run(const QString &outputDirectory = {}) const;
    static bool allPassed(const QList<DependencyCheck> &checks);
    static QString defaultOutputDirectory(RecordingType type = RecordingType::Video);

private:
    static DependencyCheck executable(const QString &name);
    static DependencyCheck directory(const QString &name, const QString &path,
                                     bool createIfMissing);
    static DependencyCheck niriSocket();
};

} // namespace Clavis::Recording
