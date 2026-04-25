#!/bin/bash
set -e

# 1. 清理环境：删除旧的手动克隆包，防止与新源冲突
rm -rf package/{mosdns,v2ray-geodata,v2dat,luci-app-unblockneteasemusic,lucky}

# 2. 注入新源并防止重复
sed -i '/kenzok8\/openwrt-packages/d' feeds.conf.default
sed -i '/kenzok8\/small/d' feeds.conf.default
sed -i '1i src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default

# 3. 更新 feeds 索引
./scripts/feeds update -a

# 4. 清理 feeds 中已知的冲突项
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/packages/net/{alist,adguardhome,mosdns,xray*,v2ray*,sing*,smartdns}
rm -rf feeds/packages/utils/v2dat
# 注意：不再替换 golang，LEDE 自带 Go 1.26.2 已满足所有包的编译需求
rm -rf feeds/kenzo/luci-app-dockerman
rm -rf feeds/kenzo/luci-theme-alpha
rm -rf feeds/small/tcping
rm -rf feeds/kenzo/luci-theme-design

# ====== 修复 libwebsockets-mbedtls 编译失败 ======
# libwebsockets 4.3.2 的 mbedtls 变体调用了已被移除的 mbedtls_version_get_string() API
# 导致所有设备编译必定失败。在 feeds 层面直接删除 mbedtls 变体，
# 这样 make defconfig 永远不会自动选中它，只保留 openssl 变体。
rm -rf feeds/packages/libs/libwebsockets/files/mbedtls 2>/dev/null || true
# 从 Makefile 中删除 mbedtls 变体的所有定义
if [ -f feeds/packages/libs/libwebsockets/Makefile ]; then
  # 删除 Package/libwebsockets-mbedtls 相关定义块和 BuildPackage 调用
  sed -i '/define Package\/libwebsockets-mbedtls/,/endef/d' feeds/packages/libs/libwebsockets/Makefile
  sed -i '/ifeq (\$(BUILD_VARIANT),mbedtls)/,/endif/d' feeds/packages/libs/libwebsockets/Makefile
  sed -i '/Package\/libwebsockets-mbedtls\/install/d' feeds/packages/libs/libwebsockets/Makefile
  sed -i '/BuildPackage,libwebsockets-mbedtls/d' feeds/packages/libs/libwebsockets/Makefile
  echo "[feeds] 已从 libwebsockets Makefile 中移除 mbedtls 变体"
fi

# ====== 修复 shadowsocksr-libev 在 MT7621/MIPS 下的编译崩溃 ======
# MIPS 架构下开启 -flto 经常会导致 gcc 内存不足或内部错误(ICE)导致编译失败。
# 这里强制移除 shadowsocksr-libev 的 -flto 编译选项。
if [ -f feeds/small/shadowsocksr-libev/Makefile ]; then
  sed -i 's/TARGET_CFLAGS += -flto//g' feeds/small/shadowsocksr-libev/Makefile
  echo "[feeds] 已移除 shadowsocksr-libev 的 -flto 选项以修复 MT7621 编译问题"
fi

# 5. 安装插件
./scripts/feeds install -a

# 6. 安装后清理：从 package/feeds 中移除有缺陷依赖或语法错误的包
#    （feeds install 通过索引文件创建符号链接，仅删 feeds/ 不够，必须也删 package/feeds/）
rm -rf package/feeds/kenzo/luci-app-dockerman
rm -rf package/feeds/kenzo/luci-theme-alpha
rm -rf package/feeds/small/tcping
rm -rf package/feeds/small/luci-theme-design
# 确保 libwebsockets-mbedtls 的符号链接也被清除
rm -rf package/feeds/packages/libwebsockets-mbedtls 2>/dev/null || true

# 7. 自动清理配置缓存，防止旧架构/旧版本的依赖干扰
rm -rf tmp
