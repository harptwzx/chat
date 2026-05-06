#!/bin/bash

# 一键部署AI工具链
# 使用方法: bash setup.sh

set -e

PROJECT_DIR="ai-toolchain"
cd "$(dirname "$0")"

echo "=== AI工具链一键部署 ==="

# 创建项目目录
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 安装Ollama
if ! command -v ollama &> /dev/null; then
    echo "安装Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

# 启动Ollama
if ! pgrep -x "ollama" > /dev/null; then
    echo "启动Ollama..."
    ollama serve > /dev/null 2>&1 &
    sleep 5
fi

# 下载模型
echo "下载模型(首次需要时间)..."
ollama pull qwen2.5:7b
ollama pull deepseek-coder:6.7b

# 创建Python虚拟环境
echo "创建Python环境..."
python3 -m venv venv
source venv/bin/activate
pip install ollama

# 创建主程序
cat > main.py << 'EOF'
import ollama
import subprocess
import os
import json
import re
from pathlib import Path

class ToolChain:
    def __init__(self):
        self.organizer = OllamaModel("qwen2.5:7b")
        self.coder = OllamaModel("deepseek-coder:6.7b")
        self.workspace = Path("workspace")
        self.workspace.mkdir(exist_ok=True)
        
    def run(self):
        print("\nAI工具链已启动")
        print("输入任务(如: 创建一个Python计算器) 或 'quit'退出\n")
        
        while True:
            user_input = input(">>> ").strip()
            if user_input.lower() == 'quit':
                break
            if not user_input:
                continue
                
            # 组织者分析任务
            print("\n[组织者] 分析任务...")
            plan = self.organizer.chat(f"""你是任务规划者。用户需求: {user_input}
如果这是一个任务(创建代码、文件操作等)，输出:
TASK:项目名
STEP1:具体步骤
STEP2:具体步骤
...
如果是普通聊天，直接回复聊天内容。
只输出内容，不要额外说明。""")
            
            if "TASK:" in plan:
                print("[管家] 开始执行...")
                self.execute_plan(plan, user_input)
            else:
                print(f"\n[AI] {plan}")
    
    def execute_plan(self, plan, requirement):
        # 解析步骤
        steps = []
        for line in plan.split('\n'):
            if line.startswith('STEP'):
                steps.append(line.split(':',1)[1].strip())
        
        # 创建项目目录
        project_name = plan.split('\n')[0].replace('TASK:', '').strip()
        project_dir = self.workspace / project_name
        project_dir.mkdir(exist_ok=True)
        
        # 执行每个步骤
        for i, step in enumerate(steps, 1):
            print(f"\n步骤{i}: {step}")
            
            # 判断是否需要生成代码
            if any(kw in step.lower() for kw in ['代码', '文件', '创建', '写']):
                self.generate_code(step, project_dir)
            else:
                # 执行系统命令
                self.execute_command(step, project_dir)
        
        print(f"\n完成! 项目位置: {project_dir}")
    
    def generate_code(self, requirement, project_dir):
        # 获取代码生成者响应
        code_response = self.coder.chat(f"""你只输出代码，不要解释。
需求: {requirement}
输出格式:
FILENAME: 文件名
CODE:
```语言
代码内容
```""")
        
        # 提取文件名和代码
        filename_match = re.search(r'FILENAME:\s*(.+)', code_response)
        code_match = re.search(r'```\w*\n(.*?)```', code_response, re.DOTALL)
        
        if filename_match and code_match:
            filename = filename_match.group(1).strip()
            code = code_match.group(1).strip()
            filepath = project_dir / filename
            filepath.write_text(code)
            print(f"  生成文件: {filename}")
            
            # 代码检查(简单语法检查)
            if filename.endswith('.py'):
                try:
                    compile(code, filename, 'exec')
                    print(f"  ✓ 语法检查通过")
                except SyntaxError as e:
                    print(f"  ✗ 语法错误，重新生成...")
                    # 重试一次
                    fix_response = self.coder.chat(f"代码有语法错误，修复它:\n{code}\n错误:{e}")
                    fix_match = re.search(r'```\w*\n(.*?)```', fix_response, re.DOTALL)
                    if fix_match:
                        fixed_code = fix_match.group(1).strip()
                        filepath.write_text(fixed_code)
                        print(f"  ✓ 已修复")
        else:
            print(f"  代码生成失败")
    
    def execute_command(self, command, cwd):
        try:
            # 解析命令
            parts = command.split()
            if not parts:
                return
            
            cmd = parts[0]
            args = parts[1:]
            
            # 安全命令白名单
            safe_cmds = ['mkdir', 'cp', 'mv', 'rm', 'ls', 'cat', 'grep', 'find', 'echo', 'wget', 'curl']
            
            if cmd in safe_cmds:
                result = subprocess.run([cmd] + args, cwd=cwd, capture_output=True, text=True)
                if result.stdout:
                    print(f"  {result.stdout[:200]}")
                if result.stderr:
                    print(f"  错误: {result.stderr[:200]}")
            else:
                print(f"  跳过不安全的命令: {cmd}")
        except Exception as e:
            print(f"  命令执行失败: {e}")

class OllamaModel:
    def __init__(self, model):
        self.model = model
        
    def chat(self, prompt):
        try:
            response = ollama.chat(model=self.model, messages=[{'role': 'user', 'content': prompt}])
            return response['message']['content']
        except Exception as e:
            return f"错误: {e}"

if __name__ == "__main__":
    toolchain = ToolChain()
    toolchain.run()
EOF

# 创建启动脚本
cat > run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python main.py
EOF

echo ""
echo "=== 安装完成 ==="
echo "启动命令: cd $PROJECT_DIR && ./run.sh"
echo ""
echo "使用示例:"
echo ">>> 创建一个Python计算器程序"
echo ">>> 下载 https://example.com/file.txt"
echo ">>> 列出当前目录文件"