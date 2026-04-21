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
git clone https://github.com/UnblockNeteaseMusic/luci-app-unblockneteasemusic.git package/luci-app-unblockneteasemusic
git clone https://github.com/gdy666/luci-app-lucky.git package/lucky
# ============================================================

# 3. 重新注册上述手动 clone 的包到构建系统
#    不执行此步，make defconfig 无法识别 package/ 下的新包，
#    导致 .config 里对应的 =y 被自动重置为 =n（即不编译）
./scripts/feeds install -a
