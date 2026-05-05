#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 设置工作目录为脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 设置模型存储路径为当前目录下的 models 文件夹
export OLLAMA_MODELS="$SCRIPT_DIR/models"

# 创建必要目录
mkdir -p models outputs

echo -e "${GREEN}🚀 启动 Qwen2.5-7B 本地模型${NC}"
echo -e "${BLUE}📁 模型存储: $OLLAMA_MODELS${NC}"
echo -e "${BLUE}📁 日志目录: $SCRIPT_DIR/outputs${NC}"
echo ""

# 生成日志文件名
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$SCRIPT_DIR/outputs/conversation_${TIMESTAMP}.txt"

# 1. 检查并安装 Ollama
if ! command -v ollama &> /dev/null; then
    echo -e "${BLUE}📦 安装 Ollama...${NC}"
    curl -fsSL https://ollama.com/install.sh | sh
fi

# 2. 启动 Ollama 服务（如果未运行）
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "${BLUE}🔧 启动 Ollama 服务...${NC}"
    ollama serve > "$SCRIPT_DIR/ollama.log" 2>&1 &
    sleep 5
fi

# 3. 检查并下载模型到本地目录
echo -e "${BLUE}📥 检查模型 Qwen2.5-7B-Instruct...${NC}"
if ! ollama list | grep -q "qwen2.5:7b-instruct"; then
    echo -e "${YELLOW}模型不存在，正在下载到 $OLLAMA_MODELS ...${NC}"
    echo -e "${YELLOW}文件大小约 4.5GB，需要 10-20 分钟${NC}"
    ollama pull qwen2.5:7b-instruct
    echo -e "${GREEN}✅ 模型下载完成！${NC}"
else
    echo -e "${GREEN}✅ 模型已存在${NC}"
fi

# 4. 显示模型位置
echo -e "${BLUE}📂 模型文件位置:${NC}"
ls -lh "$OLLAMA_MODELS/blobs/" 2>/dev/null | head -5

echo ""
echo -e "${GREEN}✅ 准备就绪！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "这是 Qwen2.5-7B-Instruct 通用模型"
echo -e "可以回答各种问题（编程、知识、生活、翻译等）"
echo -e ""
echo -e "命令说明："
echo -e "  ${GREEN}/bye${NC}          - 退出对话"
echo -e "  ${GREEN}/save${NC}         - 保存对话到日志"
echo -e "  ${GREEN}/tokens${NC}       - 显示本次会话 token 统计"
echo -e "  ${GREEN}/reset${NC}        - 重置会话统计"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 记录开始时间
START_TIME=$(date +%s)
SESSION_LOG="$SCRIPT_DIR/outputs/session_${TIMESTAMP}.raw"

# 运行模型并记录输出
ollama run qwen2.5:7b-instruct 2>&1 | tee "$SESSION_LOG" | while IFS= read -r line; do
    echo "$line"
    
    # 检测退出命令
    if [[ "$line" == "/bye" ]]; then
        # 计算会话统计
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        # 估算 token 数（平均每字符 0.3 token）
        if [ -f "$SESSION_LOG" ]; then
            CHAR_COUNT=$(wc -c < "$SESSION_LOG")
            TOKEN_EST=$((CHAR_COUNT / 3))
            
            echo ""
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}📊 会话统计${NC}"
            echo -e "  会话时长: ${DURATION} 秒"
            echo -e "  估算 Token: 约 ${TOKEN_EST} tokens"
            echo -e "  日志保存: $SESSION_LOG"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            
            # 复制到正式日志
            cp "$SESSION_LOG" "$LOG_FILE"
            echo -e "${GREEN}✅ 对话已保存到: $LOG_FILE${NC}"
        fi
        break
    fi
    
    # 处理 /save 命令
    if [[ "$line" == "/save" ]]; then
        cp "$SESSION_LOG" "$LOG_FILE"
        echo -e "${GREEN}✅ 对话已保存到: $LOG_FILE${NC}"
    fi
    
    # 处理 /tokens 命令
    if [[ "$line" == "/tokens" ]]; then
        if [ -f "$SESSION_LOG" ]; then
            CURRENT_CHAR=$(wc -c < "$SESSION_LOG")
            CURRENT_TOKEN=$((CURRENT_CHAR / 3))
            echo -e "${GREEN}📊 当前会话 Token: 约 ${CURRENT_TOKEN}${NC}"
        fi
    fi
done

echo -e "\n${GREEN}👋 再见！${NC}"
