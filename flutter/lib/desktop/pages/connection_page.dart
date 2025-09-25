// main window right pane

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/widgets/connection_page_title.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/popup_menu.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart' show DesktopSettingPage, SettingsTabKey;

import '../../common.dart';
import '../../common/formatter/id_formatter.dart';
import '../../common/widgets/peer_tab_page.dart';
import '../../common/widgets/autocomplete.dart';
import '../../models/platform_model.dart';
import '../../models/server_model.dart' show kUsePermanentPassword;
import '../../desktop/widgets/material_mod_popup_menu.dart' as mod_menu;

class OnlineStatusWidget extends StatefulWidget {
  const OnlineStatusWidget({Key? key, this.onSvcStatusChanged})
      : super(key: key);

  final VoidCallback? onSvcStatusChanged;

  @override
  State<OnlineStatusWidget> createState() => _OnlineStatusWidgetState();
}

/// State for the connection page.
class _OnlineStatusWidgetState extends State<OnlineStatusWidget> {
  final _svcStopped = Get.find<RxBool>(tag: 'stop-service');
  final _svcIsUsingPublicServer = true.obs;
  Timer? _updateTimer;
  int _lastStatusNum = 0; // 调试用：记录最近一次状态码

  double get em => 14.0;
  double? get height => bind.isIncomingOnly() ? null : em * 3;

  void onUsePublicServerGuide() {
    const url = "https://laladesk.com/pricing";
    canLaunchUrlString(url).then((can) {
      if (can) {
        launchUrlString(url);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(Duration(seconds: 1), () async {
      updateStatus();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    startServiceWidget() => Offstage(
          offstage: !_svcStopped.value,
          child: InkWell(
                  onTap: () async {
                    await start_service(true);
                  },
                  child: Text(translate("Start service"),
                      style: TextStyle(
                          decoration: TextDecoration.underline, fontSize: em)))
              .marginOnly(left: em),
        );

    Widget setupServerWidget() => Flexible(
          child: Offstage(
            offstage: !(!_svcStopped.value &&
                stateGlobal.svcStatus.value == SvcStatus.ready &&
                _svcIsUsingPublicServer.value),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [],
            ),
          ),
        );

    basicWidget() => Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _svcStopped.value ||
                        stateGlobal.svcStatus.value == SvcStatus.connecting
                    ? kColorWarn
                    : (stateGlobal.svcStatus.value == SvcStatus.ready
                        ? Color.fromARGB(255, 50, 190, 166)
                        : Color.fromARGB(255, 224, 79, 95)),
              ),
            ).marginSymmetric(horizontal: em),
            Container(
              width: isIncomingOnly ? 226 : null,
              child: _buildConnStatusMsg(),
            ),
            if (!isIncomingOnly) startServiceWidget(),
            if (!isIncomingOnly) setupServerWidget(),
          ],
        );

    return Container(
      height: height,
      child: Obx(() => isIncomingOnly
          ? Column(
              children: [
                basicWidget(),
                Align(
                        child: startServiceWidget(),
                        alignment: Alignment.centerLeft)
                    .marginOnly(top: 2.0, left: 22.0)
              ],
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: basicWidget(),
            )),
    ).paddingOnly(right: isIncomingOnly ? 8 : 0);
  }

  _buildConnStatusMsg() {
    widget.onSvcStatusChanged?.call();
    return Text(
      _svcStopped.value
          ? translate("Service is not running")
          : stateGlobal.svcStatus.value == SvcStatus.connecting
              ? translate("connecting_status")
              : stateGlobal.svcStatus.value == SvcStatus.notReady
                  ? translate("not_ready_status")
                  : translate('Ready'),
      style: TextStyle(fontSize: em),
    );
  }

  updateStatus() async {
    final status =
        jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
    final statusNum = status['status_num'] as int;
    _lastStatusNum = statusNum; // 记录调试状态码
    if (statusNum == 0) {
      stateGlobal.svcStatus.value = SvcStatus.connecting;
    } else if (statusNum == -1) {
      stateGlobal.svcStatus.value = SvcStatus.notReady;
    } else if (statusNum == 1) {
      stateGlobal.svcStatus.value = SvcStatus.ready;
    } else {
      stateGlobal.svcStatus.value = SvcStatus.notReady;
    }
    _svcIsUsingPublicServer.value = await bind.mainIsUsingPublicServer();
    try {
      stateGlobal.videoConnCount.value = status['video_conn_count'] as int;
    } catch (_) {}
  }
}

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({Key? key}) : super(key: key);

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage>
    with SingleTickerProviderStateMixin, WindowListener {
  /// Controller for the id input bar.
  final _idController = IDTextEditingController();

  final RxBool _idInputFocused = false.obs;
  final FocusNode _idFocusNode = FocusNode();
  final TextEditingController _idEditingController = TextEditingController();

  String selectedConnectionType = 'Connect';

  bool isWindowMinimized = false;

  final AllPeersLoader _allPeersLoader = AllPeersLoader();

  // https://github.com/flutter/flutter/issues/157244
  Iterable<Peer> _autocompleteOpts = [];

  final _menuOpen = false.obs;

  @override
  void initState() {
    super.initState();
    _allPeersLoader.init(setState);
    _idFocusNode.addListener(onFocusChanged);
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<TextEditingController>(_idEditingController);
    Get.put<IDTextEditingController>(_idController);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    _idController.dispose();
    windowManager.removeListener(this);
    _allPeersLoader.clear();
    _idFocusNode.removeListener(onFocusChanged);
    _idFocusNode.dispose();
    _idEditingController.dispose();
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }

  @override
  void onWindowEvent(String eventName) {
    super.onWindowEvent(eventName);
    if (eventName == 'minimize') {
      isWindowMinimized = true;
    } else if (eventName == 'maximize' || eventName == 'restore') {
      if (isWindowMinimized && isWindows) {
        // windows can't update when minimized.
        Get.forceAppUpdate();
      }
      isWindowMinimized = false;
    }
  }

  @override
  void onWindowEnterFullScreen() {
    // Remove edge border by setting the value to zero.
    stateGlobal.resizeEdgeSize.value = 0;
  }

  @override
  void onWindowLeaveFullScreen() {
    // Restore edge border to default edge size.
    stateGlobal.resizeEdgeSize.value = stateGlobal.isMaximized.isTrue
        ? kMaximizeEdgeSize
        : windowResizeEdgeSize;
  }

  @override
  void onWindowClose() {
    super.onWindowClose();
    bind.mainOnMainWindowClose();
  }

  void onFocusChanged() {
    _idInputFocused.value = _idFocusNode.hasFocus;
    if (_idFocusNode.hasFocus) {
      if (_allPeersLoader.needLoad) {
        _allPeersLoader.getAllPeers();
      }

      final textLength = _idEditingController.value.text.length;
      // Select all to facilitate removing text, just following the behavior of address input of chrome.
      _idEditingController.selection =
          TextSelection(baseOffset: 0, extentOffset: textLength);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    return Column(
      children: [
        Expanded(
            child: Column(
          children: [
            Row(
              children: [
                if (!isOutgoingOnly) ...[
                  Expanded(child: _buildLocalInfoBox(context)),
                  SizedBox(width: 12),
                ],
                Expanded(child: _buildRemoteIDTextField(context)),
              ],
            ).marginOnly(top: 22),
            SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Theme.of(context).colorScheme.background),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '温馨提示',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.titleLarge?.color),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1.本软件仅供公司内部使用，请勿随意对外传播。',
                      style: TextStyle(fontSize: 14, height: 1.6, color: Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.85)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '2.建议在公司内网或连接安心连后使用，以确保最佳体验和信息安全。',
                      style: TextStyle(fontSize: 14, height: 1.6, color: Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ).paddingSymmetric(horizontal: 12.0)),
        if (!isOutgoingOnly) const Divider(height: 1),
        if (!isOutgoingOnly) OnlineStatusWidget()
      ],
    );
  }

  Widget _buildLocalInfoBox(BuildContext context) {
    final model = gFFI.serverModel;
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(13)),
          border: Border.all(color: Theme.of(context).colorScheme.background)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ID
          Container(
            height: 25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本设备识别码',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.color
                          ?.withOpacity(0.5)),
                ).marginOnly(top: 5),
                InkWell(
                  onTap: () async {
                    final userName = gFFI.userModel.userName.value;
                    final name = (userName.isNotEmpty) ? userName : await bind.mainGetMyId();
                    final code = model.serverId.text;
                    final otp = model.serverPasswd.text;
                    final msg = '${name}邀请您进行远程控制\nLalaDesk设备代码:${code}\n临时密码:${otp}';
                    await Clipboard.setData(ClipboardData(text: msg));
                    showToast(translate('Copied'));
                  },
                  child: Icon(Icons.ios_share, size: 18, color: Theme.of(context).textTheme.titleLarge?.color?.withOpacity(0.6)),
                ).marginOnly(top: 2),
              ],
            ),
          ),
          GestureDetector(
            onDoubleTap: () {
              Clipboard.setData(ClipboardData(text: model.serverId.text));
              showToast(translate("Copied"));
            },
            child: TextFormField(
              controller: model.serverId,
              readOnly: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 10, bottom: 10),
                filled: false,
              ),
              style: const TextStyle(fontSize: 22),
            ).workaroundFreezeLinuxMint(),
          ),
          const SizedBox(height: 8),
          // 一次性密码已移动到右侧盒子
        ],
      ),
    );
  }

  void onConnect({bool isFileTransfer = false, bool isViewCamera = false, bool isTerminal = false}) {
    var id = _idController.id;
    connect(context, id,
        isFileTransfer: isFileTransfer,
        isViewCamera: isViewCamera,
        isTerminal: isTerminal);
  }

  Widget _buildRemoteIDTextField(BuildContext context) {
    final model = gFFI.serverModel;
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;

    var w = Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(13)),
          border: Border.all(color: Theme.of(context).colorScheme.background)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 一次性密码（从左侧移动过来）
          Text(
            translate("One-time Password"),
            style: TextStyle(fontSize: 14, color: textColor?.withOpacity(0.5)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onDoubleTap: () {
              if (showOneTime) {
                Clipboard.setData(ClipboardData(text: model.serverPasswd.text));
                showToast(translate("Copied"));
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onDoubleTap: () {
                      if (showOneTime) {
                        Clipboard.setData(ClipboardData(text: model.serverPasswd.text));
                        showToast(translate("Copied"));
                      }
                    },
                    child: TextFormField(
                      controller: model.serverPasswd,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(top: 8, bottom: 8),
                        filled: false,
                      ),
                      style: const TextStyle(fontSize: 15),
                    ).workaroundFreezeLinuxMint(),
                  ),
                ),
                if (showOneTime)
                  InkWell(
                    child: Icon(Icons.refresh, color: const Color(0xFFDDDDDD), size: 18).marginOnly(right: 0, top: 2),
                    onTap: () => bind.mainUpdateTemporaryPassword(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 已移除右侧横线，温馨提示在下方功能区盒子中显示
         ],
       ),
     );
     return Container(constraints: const BoxConstraints(maxWidth: 600), child: w);
   }
 }
