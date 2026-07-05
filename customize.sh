#!/system/bin/sh
SKIPUNZIP=0
ui_print "==============================="
ui_print " AxonHub LLM Gateway"
ui_print " Magisk Module"
ui_print "==============================="
ui_print ""
DATA_DIR=/data/adb/axonhub
ui_print "- 创建数据目录: $DATA_DIR"
mkdir -p "$DATA_DIR/logs"
mkdir -p "$DATA_DIR/config"
if [ ! -f "$DATA_DIR/config.yml" ]; then
    ui_print "- 复制默认配置文件"
    cp -f "$MODPATH/config/config.yml" "$DATA_DIR/config.yml"
else
    ui_print "- 检测到已有配置，保留不覆盖"
fi
ui_print "- 设置二进制权限"
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm "$MODPATH/bin/axonhub" 0 0 0755
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/bin/axonhub" 0 0 0755
ui_print ""
ui_print "- 安装完成"
ui_print ""
ui_print " 访问地址: http://127.0.0.1:8090"
ui_print " 数据目录: $DATA_DIR"
ui_print " 日志文件: $DATA_DIR/logs/axonhub.log"
ui_print ""
ui_print " 重启设备后服务自动启动"
ui_print " 也可点击模块的 Action 按钮手动启动/重启"
ui_print "==============================="
