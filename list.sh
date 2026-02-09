#!/bin/bash

#
# 描述:
#   该脚本用于列出用户的 GitHub 仓库及其最后更新时间。
#   输出结果按时间逆序排列（最新的在最后）。
#   当天更新的仓库会以天蓝色高亮显示。
#
# 使用方法:
#   ./get_repos.sh <your_github_api_token>
#
# 依赖:
#   - curl
#   - jq
#   - tac
#

# --- 检查参数 ---
# 检查是否提供了 API 令牌作为第一个参数。
if [[ -z "$1" ]]; then
  echo "错误：缺少 GitHub API 令牌。" >&2
  echo "用法: $0 <your_github_api_token>" >&2
  exit 1
fi

# --- 配置 ---
# 从第一个参数中存储 API 令牌。
API_TOKEN="$1"

# 获取今天的日期，格式为 YYYY-MM-DD，用于后续比较。
TODAY=$(date +%Y-%m-%d)

# 定义终端输出的 ANSI 颜色代码。
# CYAN 用于高亮显示，NC (No Color) 用于重置颜色。
CYAN='\033[0;36m'
NC='\033[0m'

# --- 主逻辑 ---
echo "正在从 GitHub API 获取仓库列表..."
echo "------------------------------------------------------------"

# 将整个处理流程放入一个子 shell 中，并将其输出通过管道传递给 `tac` 命令。
# `tac` 会将输入的行逆序输出，从而实现将最新的记录显示在最底部的效果。
(curl -s -H "Accept: application/vnd.github+json" \
     -H "Authorization: Bearer $API_TOKEN" \
     "https://api.github.com/user/repos?per_page=100&sort=updated&direction=desc" | \
jq -r '.[] | "\(.name)\t\(.updated_at)"' | \
while IFS=$'\t' read -r name updated_at; do
  # 如果读取失败（例如到了输入末尾），则跳过。
  [[ -z "$name" ]] && continue

  # 从完整的 ISO 8601 时间戳中提取日期部分（例如从 '2024-05-20T10:30:00Z' 提取 '2024-05-20'）。
  repo_date=$(echo "$updated_at" | cut -d'T' -f1)

  # 使用 'date' 命令将 ISO 8601 时间戳格式化为 'YYYYMMDD-HHMM' 格式。
  # GNU date 可以直接处理这种格式。
  formatted_ts=$(date -d "$updated_at" "+%Y%m%d-%H%M")

  # 使用 printf 来格式化输出，实现列对齐。
  # '%-45s' 表示一个左对齐、宽度为45个字符的字符串，不足部分用空格填充。
  line=$(printf "%-45s %s" "$name" "$formatted_ts")

  # 比较仓库的更新日期和今天的日期。
  if [[ "$repo_date" == "$TODAY" ]]; then
    # 如果是今天更新的，则以天蓝色打印。
    echo -e "${CYAN}${line}${NC}"
  else
    # 否则，以默认颜色打印。
    echo "$line"
  fi
done) | tac

echo "------------------------------------------------------------"
echo "完成。"
