#!/bin/bash
sed -i '$a src-git helloworld https://github.com/fw876/helloworld' feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a

# ========== 核心修复：替换为稳定的第三方组件 ==========
# 1. 删除刚拉取下来的、自带的残缺组件
rm -rf feeds/packages/net/mosdns
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/utils/v2dat   # <--- 新增：删除坏掉的 v2dat

# 2. 拉取 sbwml 修复版组件，放入 package 目录
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata
git clone https://github.com/sbwml/v2dat package/v2dat   # <--- 新增：拉取稳定的 v2dat
# ============================================================
