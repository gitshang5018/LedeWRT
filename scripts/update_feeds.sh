# 1. 清理环境：删除旧的手动克隆包，防止与新源冲突
rm -rf package/{mosdns,v2ray-geodata,v2dat,luci-app-unblockneteasemusic,lucky,golang}

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
rm -rf feeds/packages/lang/golang

# 5. 将自定义 Golang 放入 package 目录（优先级最高且不破坏 feeds 索引）
git clone https://github.com/kenzok8/golang -b 1.26 package/golang

# 6. 安装插件
./scripts/feeds install -a

# 7. 自动清理配置缓存，防止旧架构/旧版本的依赖干扰
rm -rf tmp
