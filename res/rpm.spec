Name:       laladesk
Version:    1.4.1
Release:    0
Summary:    RPM package
License:    GPL-3.0
URL:        https://laladesk.com
Vendor:     laladesk <info@laladesk.com>
Requires:   gtk3 libxcb libxdo libXfixes alsa-lib libva2 pam gstreamer1-plugins-base
Recommends: libayatana-appindicator-gtk3

# https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/

%description
The best open-source remote desktop client software, written in Rust.

%prep
# we have no source, so nothing here

%build
# we have no source, so nothing here

%global __python %{__python3}

%install
mkdir -p %{buildroot}/usr/bin/
mkdir -p %{buildroot}/usr/share/laladesk/
mkdir -p %{buildroot}/usr/share/laladesk/files/
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps/
mkdir -p %{buildroot}/usr/share/icons/hicolor/scalable/apps/
install -m 755 $HBB/target/release/laladesk %{buildroot}/usr/bin/laladesk
install $HBB/libsciter-gtk.so %{buildroot}/usr/share/laladesk/libsciter-gtk.so
install $HBB/res/laladesk.service %{buildroot}/usr/share/laladesk/files/
install $HBB/res/128x128@2x.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/laladesk.png
install $HBB/res/scalable.svg %{buildroot}/usr/share/icons/hicolor/scalable/apps/laladesk.svg
install $HBB/res/laladesk.desktop %{buildroot}/usr/share/laladesk/files/
install $HBB/res/laladesk-link.desktop %{buildroot}/usr/share/laladesk/files/

%files
/usr/bin/laladesk
/usr/share/laladesk/libsciter-gtk.so
/usr/share/laladesk/files/laladesk.service
/usr/share/icons/hicolor/256x256/apps/laladesk.png
/usr/share/icons/hicolor/scalable/apps/laladesk.svg
/usr/share/laladesk/files/laladesk.desktop
/usr/share/laladesk/files/laladesk-link.desktop
/usr/share/laladesk/files/__pycache__/*

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
    rm /usr/share/applications/laladesk.desktop || true
    rm /usr/share/applications/laladesk-link.desktop || true
    update-desktop-database
  ;;
  1)
    # for upgrade
  ;;
esac
