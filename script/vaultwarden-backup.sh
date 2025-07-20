#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")" || exit 1

# ============ 配置区域 ============
DB_USER="vaultwarden"
DB_NAME="vaultwarden"
VW_VOLUME_NAME="vaultwarden_data"
VW_SERVICE_NAME="vaultwarden-server.service"
PG_CONTAINER_NAME="vaultwarden-postgres"
BACKUP_DIR_BASE="./vaultwarden"
KEEP_DAYS=99
VW_VOLUME_PATH=$(podman volume inspect "$VW_VOLUME_NAME" --format '{{ .Mountpoint }}')
# =================================

TODAY="${TODAY:-$(date +"%Y-%m-%d")}"

backup() {
    echo "[$TODAY] 开始备份..."
    
    local tmp_backup_dir
    tmp_backup_dir=$(mktemp -d "${BACKUP_DIR_BASE}/${TODAY}.tmp.XXXXXX")
    # 设置陷阱，确保即使脚本中途失败，临时目录也会被自动清理。
    trap 'rm -rf "$tmp_backup_dir"' EXIT

    echo "  -> 正在备份数据库..."
    podman exec -i "$PG_CONTAINER_NAME" pg_dump -U "$DB_USER" -Fc "$DB_NAME" \
        > "$tmp_backup_dir/db.dump"

    echo "  -> 正在备份数据卷..."
    tar --exclude="tmp" --exclude="sends" -czf "$tmp_backup_dir/data.tar.gz" -C "$VW_VOLUME_PATH" .

    local backup_dir_today="${BACKUP_DIR_BASE}/${TODAY}"
    [ -d "$backup_dir_today" ] && rm -rf "$backup_dir_today"
    mv "$tmp_backup_dir" "$backup_dir_today"
    # 备份成功，解除陷阱，防止最终的备份目录被意外删除。
    trap - EXIT

    # --- 开始上传到云存储 ---
    # 注意: 请确保 .cos.conf 和 .rclone.conf 文件与此脚本位于同一目录。
    echo "  -> 正在上传备份到云存储..."
    local backup_target_dir_name="${TODAY}"

    # 上传到腾讯云 COS
    echo "    -> 上传到腾讯云 COS..."
    if podman run --rm \
        -v ./.cos.conf:/root/.cos.conf:Z \
        -v "${BACKUP_DIR_BASE}":/data:z \
        ghcr.io/22p/coscmd:master \
        upload -rs "/data/${backup_target_dir_name}" "/vaultwarden/$(date +"%Y%m")/"; then
        echo "      COS 上传成功。"
    else
        echo "      警告: 上传到 COS 失败 (错误码: $?)"
    fi

    # 上传到 Cloudflare R2
    echo "    -> 上传到 Cloudflare R2..."
    if podman run --rm \
        -v ./.rclone.conf:/config/rclone/rclone.conf:Z \
        -v "${BACKUP_DIR_BASE}":/data:z \
        docker.io/rclone/rclone:latest copy "/data/${backup_target_dir_name}" "r2:/$(date +"%Y%m")/${backup_target_dir_name}" -q --no-check-dest; then
        echo "      R2 上传成功。"
    else
        echo "      警告: 上传到 R2 失败 (错误码: $?)"
    fi
    # --- 云存储上传结束 ---

    echo "  -> 正在清理旧备份 (保留${KEEP_DAYS}天)..."
    find "$BACKUP_DIR_BASE" -maxdepth 1 -type d -name "20*" -mtime +$KEEP_DAYS -exec rm -rf {} \;

    echo "[$TODAY] 备份完成。"
}

restore() {
    # 如果未提供日期，则自动查找并使用最新的备份。
    local restore_date=${1:-$(find "$BACKUP_DIR_BASE" -maxdepth 1 -type d -name "20*" | sort -r | head -n 1 | xargs basename)}

    if [ -z "$restore_date" ]; then
        echo "错误: 找不到任何备份。"
        exit 1
    fi
    
    local restore_path="${BACKUP_DIR_BASE}/${restore_date}"
    if [ ! -f "$restore_path/db.dump" ] || [ ! -f "$restore_path/data.tar.gz" ]; then
        echo "错误：找不到 '$restore_date' 的完整备份文件。"
        exit 1
    fi

    echo "即将从 '$restore_date' 的备份恢复数据，当前数据将被完全覆盖。"
    read -rp "输入 'yes' 继续: " confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        echo "已取消恢复。"
        exit 0
    fi

    echo "停止 Vaultwarden 服务..."
    systemctl --user stop "$VW_SERVICE_NAME"

    echo "清空数据卷..."
    rm -rf "${VW_VOLUME_PATH:?}/"*

    echo "恢复数据库..."
    podman exec -i "$PG_CONTAINER_NAME" pg_restore -U "$DB_USER" -d "$DB_NAME" --clean --if-exists \
        < "$restore_path/db.dump"

    echo "恢复数据卷..."
    tar -xzf "$restore_path/data.tar.gz" -C "$VW_VOLUME_PATH"

    echo "启动 Vaultwarden 服务..."
    systemctl --user start "$VW_SERVICE_NAME"

    echo "[$restore_date] 恢复完成。"
}

usage() {
    echo "用法: $0 --backup | --restore [日期]"
}

# --- 主逻辑 ---
mkdir -p "$BACKUP_DIR_BASE"

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

case "$1" in
    --backup)
        backup
        ;;
    --restore)
        restore "${2:-}"
        ;;
    *)
        usage
        exit 1
        ;;
esac
