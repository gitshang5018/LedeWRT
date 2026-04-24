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

# 5. 安装插件
./scripts/feeds install -a

# 6. 安装后清理：从 package/feeds 中移除有缺陷依赖或语法错误的包
#    （feeds install 通过索引文件创建符号链接，仅删 feeds/ 不够，必须也删 package/feeds/）
rm -rf package/feeds/kenzo/luci-app-dockerman
rm -rf package/feeds/kenzo/luci-theme-alpha

# 7. 自动清理配置缓存，防止旧架构/旧版本的依赖干扰
rm -rf tmp
