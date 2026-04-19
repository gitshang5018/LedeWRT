#!/bin/bash
DEVICE_MODEL=$1

# ====== 后置修补：强制覆盖 defconfig 自动启用的开源 WiFi 驱动 ======
if [ "$DEVICE_MODEL" = "歌华链 MT7621" ]; then
  sed -i '/CONFIG_PACKAGE_kmod-mt76/d' .config
  sed -i '/CONFIG_PACKAGE_kmod-mt7603=/d' .config
  sed -i '/CONFIG_PACKAGE_kmod-mt76x2=/d' .config
  sed -i '/CONFIG_PACKAGE_kmod-mt76-core/d' .config
  sed -i '/CONFIG_PACKAGE_kmod-mt76-connac/d' .config
  sed -i '/CONFIG_PACKAGE_wpad-basic/d' .config
  cat >> .config <<'WIFI_FIX'
# CONFIG_PACKAGE_kmod-mt76 is not set
# CONFIG_PACKAGE_kmod-mt76-core is not set
# CONFIG_PACKAGE_kmod-mt76-connac is not set
# CONFIG_PACKAGE_kmod-mt7603 is not set
# CONFIG_PACKAGE_kmod-mt76x2 is not set
# CONFIG_PACKAGE_wpad-basic-mbedtls is not set
# CONFIG_PACKAGE_wpad-basic-wolfssl is not set
CONFIG_PACKAGE_kmod-mt7603e=y
CONFIG_PACKAGE_kmod-mt76x2e=y
CONFIG_PACKAGE_luci-app-mtwifi=y
WIFI_FIX
fi

# 网络配置修改 (仅修改默认 IP，其余保持系统默认)
if [ -f ./package/lean/default-settings/files/zzz-default-settings ]; then
  sed -i "2i # network config" ./package/lean/default-settings/files/zzz-default-settings
  sed -i "3i uci set network.lan.ipaddr='10.10.10.1'" ./package/lean/default-settings/files/zzz-default-settings
  sed -i "4i uci commit network\n" ./package/lean/default-settings/files/zzz-default-settings
fi

# ====== MT7621 闭源 WiFi 开机自启动 ======
# 原理说明:
#   闭源驱动存在启动时序竞争问题：内核模块加载完成后，ra*/rai* 接口可能还未就绪，
#   导致 WiFi 无法跟随 network 服务自动启动。
#
# 历史方案（已废弃）:
#   将 init.d 脚本文件放在 default-settings/files/etc/init.d/ 目录下，但 Lean 的
#   default-settings 包的 Makefile 只安装 zzz-default-settings 到 /etc/uci-defaults/，
#   不会递归安装 files/etc/init.d/ 子目录，导致脚本根本没被打包进固件。
#
# 当前方案（双保险）:
#   1. 利用 base-files 包的 /etc/uci-defaults/ 机制：在该目录放置脚本，系统首次启动时
#      自动执行，执行成功后自动删除。base-files 包一定会安装该目录下的所有文件。
#      脚本在首次启动时动态创建 /etc/init.d/mtwifi-init 并 enable。
#   2. 同时修改 /etc/rc.local 写入兜底的延迟 mtkwifi reload。

if [ "$DEVICE_MODEL" = "歌华链 MT7621" ]; then
  # --- 方案 1: uci-defaults 首次启动脚本（在首次启动时动态创建 init.d 服务） ---
  UCI_DEFAULTS_DIR=./package/base-files/files/etc/uci-defaults
  mkdir -p "$UCI_DEFAULTS_DIR"
  cat > "$UCI_DEFAULTS_DIR/99-mtwifi-init" <<'UCIDEFAULT'
#!/bin/sh
# 动态创建 init.d 服务脚本
cat > /etc/init.d/mtwifi-init <<'INITEOF'
#!/bin/sh /etc/rc.common
START=99

start() {
    # 后台延迟执行，避免阻塞系统启动流程
    (
        sleep 15
        /sbin/mtkwifi reload
        logger -t mtwifi-init "闭源 WiFi 驱动重载完成"
    ) &
}

stop() {
    /sbin/mtkwifi down 2>/dev/null
}
INITEOF
chmod +x /etc/init.d/mtwifi-init
/etc/init.d/mtwifi-init enable

# 兜底：在 rc.local 的 exit 0 前插入延迟重载命令
if [ -f /etc/rc.local ] && ! grep -q 'mtkwifi reload' /etc/rc.local; then
    sed -i '/^exit 0/i (sleep 20 && /sbin/mtkwifi reload && logger -t rc.local "WiFi 兜底重载完成") &' /etc/rc.local
fi

exit 0
UCIDEFAULT
  chmod +x "$UCI_DEFAULTS_DIR/99-mtwifi-init"
fi
