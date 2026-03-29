#!/system/bin/sh
SCRIPT_DIR="/data/adb/agh/scripts"
AGH_DIR="/data/adb/agh"
BIN_DIR="$AGH_DIR/bin"
MAIN_LOG="$AGH_DIR/agh.log"
MODULES_DIR="/data/adb/modules"
AGH_MODULE_PROP="/data/adb/modules/AdGuardHome/module.prop"
export TZ='Asia/Shanghai'

# 1. 环境清理：确保日志文件存在并可写
touch "$MAIN_LOG"
chmod 666 "$MAIN_LOG"

# 2. 检查hosts模块冲突
found_hosts=false
for module in "$MODULES_DIR"/*; do 
    [ -d "$module" ] && [ -f "$module/system/etc/hosts" ] && {
        found_hosts=true
        touch "$module/remove" 2>/dev/null
    }
done

if [ "$found_hosts" = true ]; then
    DESC="⚠️ AdGuardHome已禁用 - 检测到hosts模块冲突"
    [ -f "$AGH_MODULE_PROP" ] && sed -i "s/description=.*/description=$DESC/" "$AGH_MODULE_PROP"
    echo "$(date '+%F %T') [ERROR] 检测到hosts模块，启动中止。" >> "$MAIN_LOG"
    exit 1
fi

# 3. 启动 AdGuardHome
# 增加 SSL 证书路径支持，禁用自动更新以提高启动速度
export SSL_CERT_DIR="/system/etc/security/cacerts/"
"$BIN_DIR/AdGuardHome" --no-check-update --work-dir "$BIN_DIR" --config "$BIN_DIR/AdGuardHome.yaml" > /dev/null 2>&1 &

# 4. 验证启动结果 (最多等待 5 秒)
success=false
for i in 1 2 3 4 5; do
    sleep 1
    if pgrep "AdGuardHome" > /dev/null; then
        success=true
        break
    fi
done

if [ "$success" = true ]; then
    echo "$(date '+%F %T') [INFO] AdGuardHome 进程已在后台运行。" >> "$MAIN_LOG"
else
    echo "$(date '+%F %T') [ERROR] AdGuardHome 启动失败，请检查端口冲突或配置文件。" >> "$MAIN_LOG"
    # 不再执行 exec "$0"，防止死循环烧 CPU
    exit 1
fi

# 5. 启动附属脚本 (只保留有效存在的脚本)
[ -f "$SCRIPT_DIR/ModuleMOD.sh" ] && "$SCRIPT_DIR/ModuleMOD.sh" &
[ -f "$SCRIPT_DIR/NoAdsService.sh" ] && "$SCRIPT_DIR/NoAdsService.sh" &

# 6. 日志维护：超过 100KB 自动清空
if [ -f "$MAIN_LOG" ]; then
    [ $(stat -c %s "$MAIN_LOG") -ge 102400 ] && : > "$MAIN_LOG"
fi