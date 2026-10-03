/*
 * SPDX-FileCopyrightText: 2018-2019 Red Hat Inc
 * SPDX-FileCopyrightText: 2022 Aleix Pol Gonzalez <aleixpol@kde.org>
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 *
 * SPDX-FileCopyrightText: 2018-2019 Jan Grulich <jgrulich@redhat.com>
 */

#include "dbushelpers.h"
#include "debug.h"
#include "permission_store.h"

#include <QDBusConnection>
#include <QDBusMetaType>
#include <QDBusReply>

using namespace Qt::StringLiterals;

bool isAppMegaAuthorized(const QString &app_id, const QString &permissionId)
{
    qDBusRegisterMetaType<AppIdPermissionsMap>();
    OrgFreedesktopImplPortalPermissionStoreInterface permissionStore(u"org.freedesktop.impl.portal.PermissionStore"_s,
                                                                     u"/org/freedesktop/impl/portal/PermissionStore"_s,
                                                                     QDBusConnection::sessionBus());
    // Bring the timeout way down. Permission store queries are fast, if they aren't then something is wrong and there is no point waiting a long time.
    permissionStore.setTimeout(1000);
    QDBusVariant data;
    auto reply = permissionStore.Lookup(u"kde-authorized"_s, permissionId, data);
    if (reply.isValid()) {
        auto appIdPermissions = reply.value();
        if (!appIdPermissions.contains(app_id)) {
            qCDebug(XdgDesktopPortalKde) << "MegaAuth:" << permissionId << "permission not granted for" << app_id;
            return false;
        }

        auto permissions = appIdPermissions.value(app_id);
        if (permissions.contains("yes"_L1)) {
            qCDebug(XdgDesktopPortalKde) << "MegaAuth:" << permissionId << "permission granted for" << app_id;
            return true;
        }
    } else {
        qCWarning(XdgDesktopPortalKde) << "MegaAuth: Failed to lookup" << permissionId << "permissions:" << reply.error().message();
    }

    return false;
}

QDBusArgument &operator<<(QDBusArgument &arg, const Choice &choice)
{
    arg.beginStructure();
    arg << choice.id << choice.value;
    arg.endStructure();
    return arg;
}

const QDBusArgument &operator>>(const QDBusArgument &arg, Choice &choice)
{
    QString id;
    QString value;
    arg.beginStructure();
    arg >> id >> value;
    choice.id = id;
    choice.value = value;
    arg.endStructure();
    return arg;
}

QDBusArgument &operator<<(QDBusArgument &arg, const Option &option)
{
    arg.beginStructure();
    arg << option.id << option.label << option.choices << option.initialChoiceId;
    arg.endStructure();
    return arg;
}

const QDBusArgument &operator>>(const QDBusArgument &arg, Option &option)
{
    QString id;
    QString label;
    Choices choices;
    QString initialChoiceId;
    arg.beginStructure();
    arg >> id >> label >> choices >> initialChoiceId;
    option.id = id;
    option.label = label;
    option.choices = choices;
    option.initialChoiceId = initialChoiceId;
    arg.endStructure();
    return arg;
}

#include "moc_dbushelpers.cpp"
