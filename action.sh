#!/system/bin/sh
# AxonHub Magisk 模块 - Action 按钮脚本
# 点击 Magisk Manager 中模块的 Action 按钮时触发
# 功能：停止当前运行的 axonhub 进程并重新启动

MODDIR=${0%/*}
AXONHUB_BIN="$MODDIR/bin/axonhub"
DATA_DIR="/data/adb/axonhub"
PID_FILE="$DATA_DIR/axonhub.pid"
LOG_FILE="$DATA_DIR/logs/axonhub.log"

# 创建必要的目录
mkdir -p "$DATA_DIR/logs"

# 停止现有进程
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null
        # 等待进程退出，最多 5 秒
        for i in 1 2 3 4 5; do
            if ! kill -0 "$OLD_PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        # 如果还在运行，强制终止
        if kill -0 "$OLD_PID" 2>/dev/null; then
            kill -9 "$OLD_PID" 2>/dev/null
            sleep 1
        fi
        echo "[AxonHub] 已停止旧进程 PID=$OLD_PID" >> "$LOG_FILE"
    fi
    rm -f "$PID_FILE"
fi

# 通过 pkill 兜底清理（防止 PID 文件丢失但有残留进程）
pkill -f "$AXONHUB_BIN" 2>/dev/null
sleep 1

# 重新启动 axonhub 后台进程
(
    cd "$DATA_DIR"
    nohup "$AXONHUB_BIN" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
)

# 等待 2 秒后检查进程是否存活
sleep 2
if [ -f "$PID_FILE" ]; then
    NEW_PID=$(cat "$PID_FILE")
    if kill -0 "$NEW_PID" 2>/dev/null; then
        echo "[AxonHub] 服务已重启, PID=$NEW_PID" >> "$LOG_FILE"
    else
        echo "[AxonHub] 警告: 重启后进程立即退出, 请检查日志" >> "$LOG_FILE"
        rm -f "$PID_FILE"
    fi
fi
