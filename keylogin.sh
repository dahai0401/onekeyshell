#!/bin/bash

# Function to execute command and check its status
execute_command() {
    eval $1
    if [ $? -ne 0 ]; then
        echo "执行错误: $1"
        exit 1
    fi
}

# Function to read SSH key from file
read_ssh_key_from_file() {
    local file_path=$1
    if [ -f $file_path ]; then
        cat $file_path
    else
        echo ""
    fi
}

# Function to generate SSH key
generate_ssh_key() {
    local key_path=$1
    local passphrase=$2
    execute_command "ssh-keygen -t rsa -b 2048 -f $key_path -N \"$passphrase\""
    echo "生成的 SSH 密钥对:"
    echo "公钥: ${key_path}.pub"
    echo "私钥: ${key_path}"
}

# Main function to set up SSH certificate login
setup_ssh_certificate_login() {
    local ssh_key_path="/root/ssh.key"
    local public_key
    local choice

    echo "请选择一个选项:"
    echo "1. 粘贴公钥"
    echo "2. 使用已上传的公钥 ($ssh_key_path)"
    echo "3. 自动生成新的密钥对"
    read -p "请输入你的选择 (1, 2, 或 3): " choice

    case $choice in
        1)
            read -p "请粘贴你的公钥: " public_key
            if [ -z "$public_key" ]; then
                echo "没有提供公钥。"
                exit 1
            fi
            ;;
        2)
            if [ -f $ssh_key_path ]; then
                echo "找到 $ssh_key_path 处的公钥文件。"
                public_key=$(read_ssh_key_from_file $ssh_key_path)
                if [ -z "$public_key" ]; then
                    echo "读取公钥文件失败。"
                    exit 1
                fi
            else
                echo "未找到 $ssh_key_path 处的公钥文件。"
                exit 1
            fi
            ;;
        3)
            read -p "请输入新 SSH 密钥的密码: " passphrase
            generate_ssh_key "$ssh_key_path" "$passphrase"
            public_key=$(read_ssh_key_from_file "${ssh_key_path}.pub")
            if [ -z "$public_key" ]; then
                echo "读取生成的公钥失败。"
                exit 1
            fi
            ;;
        *)
            echo "无效选择。"
            exit 1
            ;;
    esac

    # Ensure .ssh directory exists
    execute_command "mkdir -p ~/.ssh"
    
    # Add public key to authorized_keys
    echo $public_key >> ~/.ssh/authorized_keys

    # Set correct permissions
    execute_command "chmod 600 ~/.ssh/authorized_keys"
    execute_command "chmod 700 ~/.ssh"

    # Configure SSH to disable password authentication
    local sshd_config_path="/etc/ssh/sshd_config"
    if grep -q "^PasswordAuthentication" $sshd_config_path; then
        sed -i "s/^PasswordAuthentication.*/PasswordAuthentication no/" $sshd_config_path
    else
        echo "PasswordAuthentication no" >> $sshd_config_path
    fi

    if grep -q "^ChallengeResponseAuthentication" $sshd_config_path; then
        sed -i "s/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/" $sshd_config_path
    else
        echo "ChallengeResponseAuthentication no" >> $sshd_config_path
    fi

    if ! grep -q "^PubkeyAuthentication" $sshd_config_path; then
        echo "PubkeyAuthentication yes" >> $sshd_config_path
    fi

    if ! grep -q "^UsePAM" $sshd_config_path; then
        echo "UsePAM yes" >> $sshd_config_path
    fi

    # Double check the changes made to sshd_config
    echo "Updated /etc/ssh/sshd_config:"
    grep -E "PasswordAuthentication|ChallengeResponseAuthentication|PubkeyAuthentication|UsePAM" $sshd_config_path

    # Restart SSH service
    execute_command "systemctl restart sshd"
    echo "SSH 配置已更新。已禁用密码登录，启用证书登录。"
    echo "如果你选择生成新的密钥对，你的私钥位于 ${ssh_key_path}"
}

# Run the main function
setup_ssh_certificate_login
