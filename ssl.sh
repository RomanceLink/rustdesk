./vcpkg install libvpx libyuv opus aom

export VCPKG_ROOT=~/repos/vcpkg

fvm global 3.35.1

export PATH=$HOME/fvm/default/bin:$PATH

flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h

python3 ./build.py --flutter



codesign --deep --force --options=runtime \--sign "Developer ID Application: Shenzhen Huolala Technology Company Limited (F75K3ZYHQP)" \
--timestamp ./LaLaDesk.app

xcrun notarytool store-credentials 'LaLaDesk' --apple-id 'fangqiao.luo@huolala.cn' --team-id F75K3ZYHQP --password 'ozxt-xnzp-tvhe-ffje'   

ditto -c -k --keepParent LaLaDesk.app LaLaDesk.zip

xcrun notarytool submit LaLaDesk.zip --keychain-profile "LaLaDesk"  --wait              