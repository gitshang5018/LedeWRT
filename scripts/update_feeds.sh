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

# 处理本地已有的 x86_64 玩机版压缩包
cat << 'EOF' > patch_lucky.py
import os
path = "package/lucky/lucky/Makefile"
if os.path.exists(path):
    with open(path, "r") as f:
        content = f.read()
    inject = "\t[ -f $(TOPDIR)/local_repo/lucky_2.27.2_Linux_x86_64_wanji.tar.gz ] && [ \"$(ARCH)\" = \"x86_64\" ] && cp $(TOPDIR)/local_repo/lucky_2.27.2_Linux_x86_64_wanji.tar.gz $(PKG_BUILD_DIR)/lucky_2.27.2_Linux_x86_64.tar.gz || true\n"
    content = content.replace("define Build/Prepare\n", "define Build/Prepare\n" + inject)
    with open(path, "w") as f:
        f.write(content)
EOF
python3 patch_lucky.py
rm patch_lucky.py
# ============================================================

# 3. 重新注册上述手动 clone 的包到构建系统
#    不执行此步，make defconfig 无法识别 package/ 下的新包，
#    导致 .config 里对应的 =y 被自动重置为 =n（即不编译）
./scripts/feeds install -a
