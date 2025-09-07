#!/bin/bash
# ============= 自定义要预装的第三方/仓库内插件 =============
# 说明：
# 1) 本脚本通过拼接 CUSTOM_PACKAGES 变量来控制要编译进固件的包。
# 2) 使用 add_pkg 函数可避免重复追加（如果上游脚本已包含同名包则不会重复）。
# 3) 硬路由闪存空间有限时请酌情删减。

# 初始化变量（若外部未定义）
: "${CUSTOM_PACKAGES:=}"

# 简易去重追加函数
add_pkg() {
  for p in "$@"; do
    case " $CUSTOM_PACKAGES " in
      *" $p "*) : ;;            # 已存在，跳过
      *) CUSTOM_PACKAGES="$CUSTOM_PACKAGES $p" ;;
    esac
  done
}

# ============= 你需要预装的 6 个插件 =============
# 1) 首页和网络向导
add_pkg luci-i18n-quickstart-zh-cn

# 2) 去广告 AdGuardHome
add_pkg luci-app-adguardhome

# 3) OpenClash（上游可能已集成；用 add_pkg 避免重复）
add_pkg luci-app-openclash

# 4) Tailscale（含中文界面包）
add_pkg luci-app-tailscale luci-i18n-tailscale-zh-cn

# 5) 网络测速（含中文界面包）
add_pkg luci-app-netspeedtest luci-i18n-netspeedtest-zh-cn

# 6) Turbo ACC 网络加速
add_pkg luci-app-turboacc

# =================================================
# 如需额外插件，可继续按上面 add_pkg 的写法追加。
# 例如：
# add_pkg luci-app-mosdns luci-i18n-mosdns-zh-cn
# add_pkg luci-app-advancedplus luci-i18n-advancedplus-zh-cn

# 输出日志（可选）
echo "[custom-packages] FINAL CUSTOM_PACKAGES = ${CUSTOM_PACKAGES}"
export CUSTOM_PACKAGES
