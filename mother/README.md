# ScreenCast pre-authorization (xdg-desktop-portal-kde 6.7.5)

KDE already lets an admin pre-authorize the RemoteDesktop portal through the
permission store table `kde-authorized`, id `remote-desktop`. This fork adds
the same mechanism for **org.freedesktop.portal.ScreenCast** using permission
id `screencast`.

When the calling `app_id` is stored as `yes`, `Start()` skips
`ScreenChooserDialog`, shares monitor sources automatically (all outputs if the
session requested multiple sources, otherwise the primary output), continues
through the same path as a user clicking Share with restore allowed, and shows
a notification that sharing started.

Apps that are not authorized keep the chooser dialog.

## Authorize an app

```sh
flatpak permission-set kde-authorized screencast "<app_id>" yes
```

For host apps with no `app_id` (typical of a root systemd service such as
RustDesk), authorize the empty id:

```sh
flatpak permission-set kde-authorized screencast "" yes
```

## Finding the app_id

The portal logs the `app_id` on both the pre-authorized path and when the
chooser dialog is shown. Enable the category and retry a capture:

```sh
QT_LOGGING_RULES="xdp-kde-screencast=true" journalctl --user -u plasma-xdg-desktop-portal-kde.service -f
```

Look for `Using pre-authorized ScreenCast path for app_id` or
`Showing ScreenChooserDialog for app_id`.

## Security

Host applications can claim any `app_id`. Pre-authorization is an admin
override, not a sandbox. Only authorize ids you trust; the empty `app_id` rule
does not cover apps that send a non-empty id.

## Arch package

`PKGBUILD` is Arch's `6.7.5-1` packaging with `pkgrel=1.1` and a local source
tarball. Reproduce the container build from a clean checkout:

```sh
./mother/build-arch.sh
```

The package is `mother/dist/xdg-desktop-portal-kde-6.7.5-1.1-x86_64.pkg.tar.zst`.
On the target machine:

```sh
sudo pacman -U xdg-desktop-portal-kde-6.7.5-1.1-x86_64.pkg.tar.zst
```
