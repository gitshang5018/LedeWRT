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
#   Lean LEDE 的 luci-app-mtwifi 包自带 /sbin/mtkwifi (Lua 脚本)，它是闭源驱动的官方
#   WiFi 管理入口。mtkwifi up 会遍历 /sys/class/net 找到所有 ra*/rai* 接口，执行
#   ifconfig up 并 brctl addif br-lan 将它们桥接到 LAN。
#
#   但闭源驱动存在已知的启动时序竞争问题：内核模块加载完成后，接口可能还未就绪，
#   导致 WiFi 无法跟随 network 服务自动启动。社区通行方案是在 rc.local 或独立 init.d
#   脚本中延迟调用 /sbin/mtkwifi reload。
#
#   这里使用 init.d 脚本方案（START=99 保证最后执行），延迟后直接调用 mtkwifi reload
#   完成驱动加载、接口 UP、桥接三合一操作，比手动 modprobe + ip link + uci 更可靠。

if [ "$DEVICE_MODEL" = "歌华链 MT7621" ]; then
  INIT_F=./package/lean/default-settings/files/etc/init.d/mtwifi-init
  mkdir -p "$(dirname "$INIT_F")"
  cat > "$INIT_F" <<'INITSCRIPT'
#!/bin/sh /etc/rc.common
START=99

start() {
    # 后台延迟执行，避免阻塞系统启动流程
    (
        # 等待内核模块和网络子系统完全初始化
        sleep 15
        # 使用 mtkwifi 官方接口重载驱动（加载模块 + 接口 UP + 桥接 br-lan）
        /sbin/mtkwifi reload
        logger -t mtwifi-init "闭源 WiFi 驱动重载完成"
    ) &
}

stop() {
    /sbin/mtkwifi down 2>/dev/null
}
INITSCRIPT
  chmod +x "$INIT_F"
  # 在 zzz-default-settings 中注册自启
  if [ -f ./package/lean/default-settings/files/zzz-default-settings ]; then
    sed -i '/exit 0/i /etc/init.d/mtwifi-init enable' ./package/lean/default-settings/files/zzz-default-settings
  fi
fi
