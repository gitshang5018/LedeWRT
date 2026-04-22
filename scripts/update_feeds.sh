# 清理旧的手动克隆包，防止与新源冲突
rm -rf package/{mosdns,v2ray-geodata,v2dat,luci-app-unblockneteasemusic,lucky}

# 防止重复添加源
sed -i '/kenzok8\/openwrt-packages/d' feeds.conf.default
sed -i '/kenzok8\/small/d' feeds.conf.default
sed -i '1i src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default

./scripts/feeds update -a
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/packages/net/{alist,adguardhome,mosdns,xray*,v2ray*,sing*,smartdns} feeds/packages/utils/v2dat feeds/packages/lang/golang
git clone https://github.com/kenzok8/golang -b 1.26 feeds/packages/lang/golang
./scripts/feeds install -a
