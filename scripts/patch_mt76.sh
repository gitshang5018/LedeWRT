#!/bin/bash
# 仅当 .config 中选了开源 mt76 驱动时才需要执行修补
if ! grep -q 'CONFIG_PACKAGE_kmod-mt76=y\|CONFIG_PACKAGE_kmod-mt7603=y\|CONFIG_PACKAGE_kmod-mt76-core=y' .config 2>/dev/null; then
  echo "ℹ️ 未启用开源 mt76 驱动，跳过修补"
  exit 0
fi
MT76_MK="package/kernel/mt76/Makefile"
if [ ! -f "$MT76_MK" ]; then
  echo "⚠️ 未找到 $MT76_MK，跳过"
  exit 0
fi
echo "🔧 修改 mt76 包 Makefile，注入兼容性修补..."
sed -i '/^define Build\/Compile/a\\tfind $(PKG_BUILD_DIR) -name "*.c" -exec sed -i "s/\\.remove_new/.remove/g" {} +' "$MT76_MK"
grep -q 'Wno-error=incompatible-pointer-types' "$MT76_MK" || \
  sed -i '/^include.*kernel.mk/a NOSTDINC_FLAGS += -Wno-error=incompatible-pointer-types' "$MT76_MK"
echo "✅ mt76 包 Makefile 修补完成"
