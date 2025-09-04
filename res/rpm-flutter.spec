Name:       laladesk
Version:    1.4.1
Release:    0
Summary:    RPM package
License:    GPL-3.0
URL:        https://laladesk.com
Vendor:     laladesk <info@laladesk.com>
Requires:   gtk3 libxcb libxdo libXfixes alsa-lib libva pam gstreamer1-plugins-base
Recommends: libayatana-appindicator-gtk3
Provides:   libdesktop_drop_plugin.so()(64bit), libdesktop_multi_window_plugin.so()(64bit), libfile_selector_linux_plugin.so()(64bit), libflutter_custom_cursor_plugin.so()(64bit), libflutter_linux_gtk.so()(64bit), libscreen_retriever_plugin.so()(64bit), libtray_manager_plugin.so()(64bit), liburl_launcher_linux_plugin.so()(64bit), libwindow_manager_plugin.so()(64bit), libwindow_size_plugin.so()(64bit), libtexture_rgba_renderer_plugin.so()(64bit)

# https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/

%description
The best open-source remote desktop client software, written in Rust.

%prep
# we have no source, so nothing here

%build
# we have no source, so nothing here

# %global __python %{__python3}

%install

mkdir -p "%{buildroot}/usr/share/laladesk" && cp -r ${HBB}/flutter/build/linux/x64/release/bundle/* -t "%{buildroot}/usr/share/laladesk"
mkdir -p "%{buildroot}/usr/bin"
install -Dm 644 $HBB/res/laladesk.service -t "%{buildroot}/usr/share/laladesk/files"
install -Dm 644 $HBB/res/laladesk.desktop -t "%{buildroot}/usr/share/laladesk/files"
install -Dm 644 $HBB/res/laladesk-link.desktop -t "%{buildroot}/usr/share/laladesk/files"
install -Dm 644 $HBB/res/128x128@2x.png "%{buildroot}/usr/share/icons/hicolor/256x256/apps/laladesk.png"
install -Dm 644 $HBB/res/scalable.svg "%{buildroot}/usr/share/icons/hicolor/scalable/apps/laladesk.svg"

%files
/usr/share/laladesk/*
/usr/share/laladesk/files/laladesk.service
/usr/share/icons/hicolor/256x256/apps/laladesk.png
/usr/share/icons/hicolor/scalable/apps/laladesk.svg
/usr/share/laladesk/files/laladesk.desktop
/usr/share/laladesk/files/laladesk-link.desktop

%changelog
# let's skip this for now

%pre
# can do something for centos7
case "$1" in
  1)
    # for install
  ;;
  2)
    # for upgrade
    systemctl stop laladesk || true
  ;;
esac

%post
cp /usr/share/laladesk/files/laladesk.service /etc/systemd/system/laladesk.service
cp /usr/share/laladesk/files/laladesk.desktop /usr/share/applications/
cp /usr/share/laladesk/files/laladesk-link.desktop /usr/share/applications/
ln -sf /usr/share/laladesk/laladesk /usr/bin/laladesk
systemctl daemon-reload
systemctl enable laladesk
systemctl start laladesk
update-desktop-database

%preun
case "$1" in
  0)
    # for uninstall
    systemctl stop laladesk || true
    systemctl disable laladesk || true
    rm /etc/systemd/system/laladesk.service || true
  ;;
  1)
    # for upgrade
  ;;
esac

%postun
case "$1" in
  0)
    # for uninstall
    rm /usr/bin/laladesk || true
    rmdir /usr/lib/laladesk || true
    rmdir /usr/local/laladesk || true
    rmdir /usr/share/laladesk || true
    rm /usr/share/applications/laladesk.desktop || true
    rm /usr/share/applications/laladesk-link.desktop || true
    update-desktop-database
  ;;
  1)
    # for upgrade
    rmdir /usr/lib/laladesk || true
    rmdir /usr/local/laladesk || true
  ;;
esac
