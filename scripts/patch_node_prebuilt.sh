#!/bin/bash
# ==============================================================================
# patch_node_prebuilt.sh
# 对 x86_64 目标使用预编译 node 二进制，跳过耗时 ~6 小时的源码编译
# 通过替换 node 包的 Makefile 编译逻辑，改为下载预编译二进制
# 其他架构（ARM/aarch64）因无 musl 预编译版本，保留源码编译
# ==============================================================================
set -euo pipefail

NODE_VER="v20.18.2"
NODE_PKG_VER="20.18.2"

# 检测当前编译目标架构
TARGET_ARCH=""
if grep -q '^CONFIG_TARGET_x86_64=y' .config 2>/dev/null; then
    TARGET_ARCH="x86_64"
elif grep -q '^CONFIG_TARGET_x86=y' .config 2>/dev/null; then
    TARGET_ARCH="x86_64"
fi

# 检查是否启用了 node
if ! grep -q '^CONFIG_PACKAGE_node=y' .config 2>/dev/null; then
    echo "[node-prebuilt] node 未启用，跳过"
    exit 0
fi

# 仅 x86_64 使用预编译，其他架构无 musl 预编译版本
if [ "$TARGET_ARCH" != "x86_64" ]; then
    echo "[node-prebuilt] 当前架构非 x86_64，保留源码编译"
    exit 0
fi

echo "[node-prebuilt] 检测到 x86_64 目标，使用预编译 node ${NODE_VER}"

# 定位 node 包的 Makefile
NODE_MK=""
for candidate in feeds/packages/lang/node/Makefile package/feeds/packages/node/Makefile; do
    if [ -f "$candidate" ]; then
        NODE_MK="$candidate"
        break
    fi
done

if [ -z "$NODE_MK" ]; then
    echo "[node-prebuilt] 警告：找不到 node Makefile，跳过"
    exit 0
fi

NODE_DIR=$(dirname "$NODE_MK")
echo "[node-prebuilt] 替换 ${NODE_MK} 的编译逻辑为预编译下载..."

# 备份原始 Makefile
cp "$NODE_MK" "${NODE_MK}.bak"

# 生成新的精简 Makefile
cat > "$NODE_MK" << 'MAKEFILE_EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=node
PKG_VERSION:=20.18.2
PKG_RELEASE:=1

PKG_SOURCE:=node-v$(PKG_VERSION)-linux-x64-musl.tar.xz
PKG_SOURCE_URL:=https://unofficial-builds.nodejs.org/download/release/v$(PKG_VERSION)/
PKG_HASH:=skip

PKG_MAINTAINER:=prebuilt
PKG_LICENSE:=MIT

PKG_BUILD_DIR:=$(BUILD_DIR)/node-v$(PKG_VERSION)-linux-x64-musl

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk

define Package/node
  SECTION:=lang
  CATEGORY:=Languages
  TITLE:=Node.js is a platform built on Chrome's JavaScript runtime
  URL:=https://nodejs.org/
  DEPENDS:=+libc +libstdcpp +libopenssl +zlib +libatomic
endef

define Package/node/extra_provides
	libc.musl-x86_64.so.1
endef

define Package/node/description
  Node.js® is a JavaScript runtime built on Chrome's V8 JavaScript engine.
  (Using prebuilt binary for x86_64 musl to skip ~6h source compilation)
endef

# Host 预编译逻辑：直接从官方下载 x64 二进制供编译机使用
define Host/Prepare
	mkdir -p $(HOST_BUILD_DIR)
	[ -f $(DL_DIR)/node-v$(PKG_VERSION)-linux-x64.tar.xz ] || \
	wget -q -O $(DL_DIR)/node-v$(PKG_VERSION)-linux-x64.tar.xz https://nodejs.org/dist/v$(PKG_VERSION)/node-v$(PKG_VERSION)-linux-x64.tar.xz
	tar -xJ -C $(HOST_BUILD_DIR) --strip-components=1 -f $(DL_DIR)/node-v$(PKG_VERSION)-linux-x64.tar.xz
endef

define Host/Compile
	@echo "[node-prebuilt] Skipping host compilation, using official binary"
endef

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOST)/bin
	$(INSTALL_BIN) $(HOST_BUILD_DIR)/bin/node $(STAGING_DIR_HOST)/bin/node
	$(LN) node $(STAGING_DIR_HOST)/bin/nodejs
endef

define Build/Compile
	@echo "[node-prebuilt] Skipping source compilation, using prebuilt binary"
endef

define Package/node/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/node $(1)/usr/bin/node
endef

$(eval $(call HostBuild))
$(eval $(call BuildPackage,node))
MAKEFILE_EOF

# 清理该目录下可能干扰新 Makefile 的补丁和其他文件
rm -rf "${NODE_DIR}/patches"

echo "[node-prebuilt] Makefile 替换完成！"
echo "[node-prebuilt] 运行 make defconfig 同步配置状态..."
make defconfig
echo "[node-prebuilt] 预编译 node 将在 'make download' 阶段下载"
echo "[node-prebuilt] 编译阶段直接安装二进制，节省 ~6 小时"
