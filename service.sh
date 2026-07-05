#!/system/bin/sh
# AxonHub Magisk 模块 - 开机自启服务
# 在 late_start service 阶段执行，等待 boot_completed 后启动 axonhub 后台进程

MODDIR=${0%/*}
AXONHUB_BIN="$MODDIR/bin/axonhub"
DATA_DIR="/data/adb/axonhub"
PID_FILE="$DATA_DIR/axonhub.pid"
LOG_FILE="$DATA_DIR/logs/axonhub.log"

# 等待系统启动完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

# 额外等待 5 秒，确保 /data 分区稳定
sleep 5

# 创建必要的目录
mkdir -p "$DATA_DIR/logs"
mkdir -p "$DATA_DIR/config"

# 确保日志目录可写
touch "$LOG_FILE" 2>/dev/null

# 启动 axonhub 后台进程
(
    cd "$DATA_DIR"
    # 使用 nohup 启动，标准输出和错误重定向到日志文件
    nohup "$AXONHUB_BIN" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
)

# 等待 2 秒后检查进程是否存活
sleep 2
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "[AxonHub] 服务已启动, PID=$PID" >> "$LOG_FILE"
    else
        echo "[AxonHub] 警告: 进程启动后立即退出, 请检查日志" >> "$LOG_FILE"
        rm -f "$PID_FILE"
    fi
fi
