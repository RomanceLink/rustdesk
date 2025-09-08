codesign --deep --force --options=runtime \--sign "Developer ID Application: Shenzhen Huolala Technology Company Limited (F75K3ZYHQP)" \
--timestamp ./LaLaDesk.app

xcrun notarytool store-credentials 'LaLaDesk' --apple-id 'fangqiao.luo@huolala.cn' --team-id F75K3ZYHQP --password 'ozxt-xnzp-tvhe-ffje'   

ditto -c -k --keepParent LaLaDesk.app LaLaDesk.zip

xcrun notarytool submit LaLaDesk.zip --keychain-profile "LaLaDesk"  --wait              