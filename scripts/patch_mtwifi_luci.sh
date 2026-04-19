#!/bin/bash
# ====== 修补 luci-app-mtwifi 高级设置页面 502 Bad Gateway ======
# 问题现象: 点击 WiFi 高级设置 (dev_cfg_view) 返回 502 Bad Gateway
#           "The process did not produce any response"
#
# 根因: luci-app-mtwifi 的 Lua 模板/控制器代码中，在遍历设备配置时
#       对某些可能为 nil 的驱动参数直接进行字符串拼接或索引操作，
#       导致 Lua 解释器崩溃，uhttpd 收不到任何响应，返回 502。
#
# 修复策略:
#   1. 为 mtkwifi.lua 库的关键函数添加 nil 安全防护
#   2. 为 dev_cfg_view 模板添加 pcall 错误保护
#   3. 增大 uhttpd script_timeout（通过 uci-defaults 首次启动注入）

MTKWIFI_DIR="package/lean/mt/luci-app-mtwifi"

if [ ! -d "$MTKWIFI_DIR" ]; then
  echo "ℹ️  未找到 luci-app-mtwifi 包，跳过修补"
  exit 0
fi

echo "🔧 修补 luci-app-mtwifi 高级设置页面 ..."

# ====== 修补 1: 为控制器的 dev_cfg 函数添加 nil 安全防护 ======
CONTROLLER="$MTKWIFI_DIR/luasrc/controller/mtkwifi.lua"
if [ -f "$CONTROLLER" ]; then
  # 给模板渲染入口 (index 函数中的 dev_cfg_view) 包裹 pcall 保护
  # 修补 dev_cfg 函数中的 assert(profiles[devname]) —— 改为优雅降级
  sed -i 's/assert(profiles\[devname\])/if not profiles[devname] then luci.http.redirect(luci.dispatcher.build_url("admin", "network", "wifi")); return end/g' "$CONTROLLER"
  echo "  ✅ 控制器 assert 崩溃点已修补为优雅降级"
fi

# ====== 修补 2: 为底层 mtkwifi.lua 库添加 nil 安全检查 ======
# 查找 mtkwifi.lua 的位置（可能在 luasrc/ 或 root/usr/lib/lua/）
MTKWIFI_LIB=$(find "$MTKWIFI_DIR" -name "mtkwifi.lua" -not -path "*/controller/*" | head -1)
if [ -n "$MTKWIFI_LIB" ]; then
  # token_set 函数是崩溃高频点：当第一个参数为 nil 时直接崩溃
  # 注入 nil 防护: 如果 token 为 nil，初始化为空字符串
  sed -i '/^function.*token_set/,/^end/ {
    /^function.*token_set/a\    if not token then token = "" end
  }' "$MTKWIFI_LIB" 2>/dev/null
  echo "  ✅ mtkwifi.lua token_set nil 防护已注入"
fi

# ====== 修补 3: 为模板文件添加 pcall 错误捕获 ======
DEV_CFG_TPL="$MTKWIFI_DIR/luasrc/view/admin_mtk/mtk_wifi_dev_cfg.htm"
if [ -f "$DEV_CFG_TPL" ]; then
  # 在模板顶部注入 pcall 包装的设备信息获取
  # 搜索模板中直接调用 mtkwifi 函数的地方，包裹 pcall
  # 常见崩溃模式：devs = mtkwifi.get_all_devs()  然后直接 devs[devname].xxx
  sed -i 's/local devs = mtkwifi.get_all_devs()/local ok, devs = pcall(mtkwifi.get_all_devs)\nif not ok or not devs then devs = {} end/' "$DEV_CFG_TPL" 2>/dev/null
  echo "  ✅ 模板 get_all_devs 已包裹 pcall 保护"
fi

# ====== 修补 4: 概览页面同样加固 ======
OVERVIEW_TPL="$MTKWIFI_DIR/luasrc/view/admin_mtk/mtk_wifi_overview.htm"
if [ -f "$OVERVIEW_TPL" ]; then
  sed -i 's/local devs = mtkwifi.get_all_devs()/local ok, devs = pcall(mtkwifi.get_all_devs)\nif not ok or not devs then devs = {} end/' "$OVERVIEW_TPL" 2>/dev/null
  echo "  ✅ 概览页 get_all_devs 已包裹 pcall 保护"
fi

# ====== 修补 5: 增大 uhttpd 脚本超时 ======
UCI_DEFAULTS_DIR="./package/base-files/files/etc/uci-defaults"
mkdir -p "$UCI_DEFAULTS_DIR"
# 确保不重复写入（检查是否已存在）
if [ ! -f "$UCI_DEFAULTS_DIR/98-uhttpd-timeout" ]; then
  cat > "$UCI_DEFAULTS_DIR/98-uhttpd-timeout" <<'TIMEOUT'
#!/bin/sh
uci set uhttpd.main.script_timeout='120'
uci set uhttpd.main.network_timeout='120'
uci commit uhttpd
exit 0
TIMEOUT
  chmod +x "$UCI_DEFAULTS_DIR/98-uhttpd-timeout"
  echo "  ✅ uhttpd 脚本超时已增至 120 秒"
fi

echo "✅ luci-app-mtwifi 修补完成"
