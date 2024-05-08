#!/bin/bash

# 显示所有磁盘及其分区信息
echo "当前系统的所有磁盘及分区信息:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
echo ""

# 提供选择磁盘的选项
DISKS=$(lsblk -nd -o NAME,SIZE | grep -v "sr0")
echo "可用的硬盘列表:"
echo "$DISKS"
echo ""

read -p "请输入您要操作的硬盘编号（例如 sda, sdb）: " DISK_CHOICE
SECOND_DISK="/dev/$DISK_CHOICE"

# 检查硬盘是否存在
if ! lsblk | grep -q "$DISK_CHOICE"; then
    echo "输入的硬盘编号不存在，请重新运行脚本并输入正确的硬盘编号。"
    exit 1
fi

# 警告信息
echo "选中的硬盘: $SECOND_DISK"
echo -e "\e[33m警告: 格式化硬盘将会删除所有数据！\e[0m"

# 检查当前的文件系统类型并提供更通俗的解释
FS_TYPE=$(lsblk -f $SECOND_DISK | grep -v "NAME" | awk '{print $2}' | head -n 1)
FS_LABEL=""
case $FS_TYPE in
    ntfs)
        FS_LABEL="Windows NTFS"
        ;;
    ext4)
        FS_LABEL="Linux ext4"
        ;;
    xfs)
        FS_LABEL="Linux XFS"
        ;;
    btrfs)
        FS_LABEL="Linux Btrfs"
        ;;
    vfat)
        FS_LABEL="FAT32"
        ;;
    iso9660)
        FS_LABEL="ISO 9660 CD-ROM"
        ;;
    *)
        FS_LABEL="$FS_TYPE"
        ;;
esac

if [ -n "$FS_TYPE" ]; then
    echo "当前硬盘文件系统为: $FS_LABEL"
    read -p "是否需要重新格式化该硬盘？(y/n): " FORMAT_DECISION
    if [ "$FORMAT_DECISION" != "y" ]; then
        echo "用户选择不重新格式化，脚本退出。"
        exit 1
    fi
else
    echo "硬盘未被格式化。"
fi

# 格式化硬盘
echo "支持的文件系统类型: ext4, xfs, btrfs"
read -p "请选择您要格式化的文件系统类型: " FS_CHOICE
case $FS_CHOICE in
    ext4|xfs|btrfs)
        # 如果已存在分区，重新分区
        echo -e "d\nn\np\n1\n\n\nw" | fdisk $SECOND_DISK
        mkfs.$FS_CHOICE ${SECOND_DISK}1
        ;;
    *)
        echo "不支持的文件系统类型，脚本退出。"
        exit 1
        ;;
esac

# 挂载硬盘
read -p "请输入挂载目录（默认为 /www）: " MOUNT_DIR
MOUNT_DIR=${MOUNT_DIR:-/www}
mkdir -p $MOUNT_DIR
mount ${SECOND_DISK}1 $MOUNT_DIR
echo "硬盘已挂载到 $MOUNT_DIR"

# 将挂载信息写入 fstab
echo "${SECOND_DISK}1 $MOUNT_DIR $FS_CHOICE defaults 0 2" >> /etc/fstab
echo "挂载信息已写入 /etc/fstab，完成设置。"
