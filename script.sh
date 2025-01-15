#!/bin/bash

# 定义 JSON 文件路径
ACCOUNTS_FILE="accounts.json"

# 检查 jq 是否安装
if ! command -v jq &>/dev/null; then
  echo "jq 未安装，请安装后再运行此脚本。"
  exit 1
fi

# 检查 accounts.json 文件是否存在
if [[ ! -f "$ACCOUNTS_FILE" ]]; then
  echo "文件 $ACCOUNTS_FILE 不存在，请确保文件路径正确。"
  exit 1
fi

# 遍历 JSON 中的账户信息，逐个执行
jq -c '.accounts[]' "$ACCOUNTS_FILE" | while read -r account; do
  # 提取账户信息
  username=$(echo "$account" | jq -r '.username')
  password=$(echo "$account" | jq -r '.password')
  panel=$(echo "$account" | jq -r '.panel')

  # 输出当前处理的用户信息
  echo "开始处理用户: $username@$panel"

  # 遍历用户的任务
  echo "$account" | jq -r '.tasks[]' | while read -r task; do
    echo "处理任务: $task"

    # 使用 sshpass 登录远程服务器并处理 Crontab
    sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -tt "$username@$panel" <<EOF
      # 获取当前 Crontab
      current_cron=\$(crontab -l 2>/dev/null || echo "")
      
      # 定义新任务
      new_cron="*/13 * * * * $task"

      # 检查是否已存在相同任务
      if [[ "\$current_cron" == *"\$new_cron"* ]]; then
        echo "任务已存在: $task，跳过添加。"
      else
        (echo "\$current_cron"; echo "\$new_cron") | crontab -
        echo "任务已成功添加到 Crontab: $task。"
      fi

      exit
EOF

    # 检查 SSH 连接是否成功
    if [[ $? -eq 0 ]]; then
      echo "任务 $task 已处理完成。"
    else
      echo "任务 $task 处理失败，请检查连接或任务信息。"
    fi
  done

  echo "用户 $username@$panel 的所有任务处理完成并退出 SSH。"
  echo "--------------------------------------------"
done

echo "所有用户已处理完成。"
