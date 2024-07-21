#!/bin/bash

# Function to execute command and check its status
execute_command() {
    eval $1
    if [ $? -ne 0 ]; then
        echo "ִ�д���: $1"
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
    echo "���ɵ� SSH ��Կ��:"
    echo "��Կ: ${key_path}.pub"
    echo "˽Կ: ${key_path}"
}

# Main function to set up SSH certificate login
setup_ssh_certificate_login() {
    local ssh_key_path="/root/ssh.key"
    local public_key
    local choice

    echo "��ѡ��һ��ѡ��:"
    echo "1. ճ����Կ"
    echo "2. ʹ�����ϴ��Ĺ�Կ ($ssh_key_path)"
    echo "3. �Զ������µ���Կ��"
    read -p "���������ѡ�� (1, 2, �� 3): " choice

    case $choice in
        1)
            read -p "��ճ����Ĺ�Կ: " public_key
            if [ -z "$public_key" ]; then
                echo "û���ṩ��Կ��"
                exit 1
            fi
            ;;
        2)
            if [ -f $ssh_key_path ]; then
                echo "�ҵ� $ssh_key_path ���Ĺ�Կ�ļ���"
                public_key=$(read_ssh_key_from_file $ssh_key_path)
                if [ -z "$public_key" ]; then
                    echo "��ȡ��Կ�ļ�ʧ�ܡ�"
                    exit 1
                fi
            else
                echo "δ�ҵ� $ssh_key_path ���Ĺ�Կ�ļ���"
                exit 1
            fi
            ;;
        3)
            read -p "�������� SSH ��Կ������: " passphrase
            generate_ssh_key "$ssh_key_path" "$passphrase"
            public_key=$(read_ssh_key_from_file "${ssh_key_path}.pub")
            if [ -z "$public_key" ]; then
                echo "��ȡ���ɵĹ�Կʧ�ܡ�"
                exit 1
            fi
            ;;
        *)
            echo "��Чѡ��"
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
    echo "SSH �����Ѹ��¡��ѽ��������¼������֤���¼��"
    echo "�����ѡ�������µ���Կ�ԣ����˽Կλ�� ${ssh_key_path}"
}

# Run the main function
setup_ssh_certificate_login
