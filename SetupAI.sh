#!/bin/bash

# 一键部署AI工具链 - 三AI协作版 (完整日志版)
# 使用方法: bash setup.sh

set -e

PROJECT_DIR="ai-toolchain"
cd "$(dirname "$0")"

echo "=== AI工具链一键部署 (三AI协作版 - 完整日志) ==="

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
    ollama serve > ollama.log 2>&1 &
    sleep 5
fi

# 下载不同角色使用的模型
echo "下载模型(首次需要时间，约10GB)..."
echo "1/3 下载组织者模型(llama3.1:8b)..."
ollama pull llama3.1:8b

echo "2/3 下载管家模型(qwen2.5:7b)..."
ollama pull qwen2.5:7b

echo "3/3 下载代码生成者模型(deepseek-coder:6.7b)..."
ollama pull deepseek-coder:6.7b

# 创建Python虚拟环境
echo "创建Python环境..."
python3 -m venv venv
source venv/bin/activate
pip install ollama

# 创建对话日志目录
mkdir -p conversations

# 创建主程序
cat > main.py << 'EOF'
import ollama
import subprocess
import os
import json
import re
import sys
import time
import datetime
from pathlib import Path
from threading import Lock

# ========== 日志系统 ==========
class ConversationLogger:
    """对话日志记录器 - 保存所有AI思考和对话"""
    
    _instance = None
    _lock = Lock()
    
    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        self.conversations_dir = Path("conversations")
        self.conversations_dir.mkdir(exist_ok=True)
        self.current_session_file = None
        self.session_start_time = None
        self.all_messages = []
        self.start_new_session()
    
    def start_new_session(self):
        """开始新的对话会话"""
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        self.session_start_time = timestamp
        self.current_session_file = self.conversations_dir / f"conversation_{timestamp}.txt"
        self.all_messages = []
        
        # 写入会话头部
        header = f"""
{'='*80}
AI工具链对话记录
开始时间: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
{'='*80}

"""
        self._write_to_file(header)
        self.add_message("系统", "对话会话已开始", "INFO")
    
    def add_message(self, role, content, msg_type="MESSAGE"):
        """添加消息到日志"""
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        
        # 确定角色标识
        role_symbols = {
            "用户": "👤",
            "组织者": "📋",
            "管家": "🔧",
            "代码生成者": "💻",
            "系统": "⚙️",
            "结果": "✅",
            "错误": "❌"
        }
        
        symbol = role_symbols.get(role, "📝")
        
        # 格式化消息
        formatted_msg = f"""
[{timestamp}] {symbol} [{role}] {msg_type}
{'─' * 60}
{content}
{'─' * 60}
"""
        
        self.all_messages.append({
            "timestamp": timestamp,
            "role": role,
            "type": msg_type,
            "content": content
        })
        
        self._write_to_file(formatted_msg)
    
    def add_ai_thinking(self, role, thought_process, final_output=""):
        """记录AI的思考过程"""
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        
        thinking_msg = f"""
[{timestamp}] 🤔 [{role}] 思考过程
{'═' * 60}
【内部思考】
{thought_process}
{'─' * 40}
【最终输出】
{final_output if final_output else thought_process}
{'═' * 60}
"""
        self._write_to_file(thinking_msg)
        
        self.all_messages.append({
            "timestamp": timestamp,
            "role": role,
            "type": "THINKING",
            "thought": thought_process,
            "output": final_output
        })
    
    def add_conversation(self, user_input, ai_response):
        """记录完整对话"""
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        
        conv_msg = f"""
[{timestamp}] 💬 对话交互
{'█' * 60}
用户输入:
{user_input}
{'─' * 40}
AI响应:
{ai_response}
{'█' * 60}
"""
        self._write_to_file(conv_msg)
        
        self.all_messages.append({
            "timestamp": timestamp,
            "type": "CONVERSATION",
            "user_input": user_input,
            "ai_response": ai_response
        })
    
    def add_task_execution(self, task_name, plan, result):
        """记录任务执行过程"""
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        
        task_msg = f"""
[{timestamp}] 📋 任务执行记录
{'█' * 60}
任务名称: {task_name}
{'─' * 40}
执行计划:
{json.dumps(plan, indent=2, ensure_ascii=False) if isinstance(plan, dict) else plan}
{'─' * 40}
执行结果:
{json.dumps(result, indent=2, ensure_ascii=False) if isinstance(result, dict) else result}
{'█' * 60}
"""
        self._write_to_file(task_msg)
    
    def _write_to_file(self, content):
        """写入文件"""
        try:
            with open(self.current_session_file, 'a', encoding='utf-8') as f:
                f.write(content)
                f.flush()
        except Exception as e:
            print(f"日志写入失败: {e}")
    
    def end_session(self):
        """结束会话"""
        footer = f"""
{'='*80}
会话结束时间: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
总消息数: {len(self.all_messages)}
日志文件: {self.current_session_file}
{'='*80}
"""
        self._write_to_file(footer)
        return str(self.current_session_file)
    
    def get_session_summary(self):
        """获取会话摘要"""
        return {
            "session_file": str(self.current_session_file),
            "start_time": self.session_start_time,
            "message_count": len(self.all_messages)
        }

# 全局日志实例
chat_logger = ConversationLogger()

# ========== 终端颜色 ==========
class Color:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    PURPLE = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'

class ThinkingLogger:
    """实时思考过程记录器 - 同时输出到终端和文件"""
    
    @staticmethod
    def _log(role, color, msg, msg_type="THINKING"):
        """内部日志方法"""
        prefix = f"{color}{Color.BOLD}[{role}]{Color.RESET}"
        print(f"{prefix} {msg}")
        chat_logger.add_message(role, msg, msg_type)
    
    @staticmethod
    def organizer(msg, is_thinking=True):
        prefix = f"{Color.BLUE}{Color.BOLD}[组织者]{Color.RESET}"
        if is_thinking:
            print(f"{prefix} 🤔 {msg}")
            chat_logger.add_message("组织者", msg, "THINKING")
        else:
            print(f"{prefix} 💬 {msg}")
            chat_logger.add_message("组织者", msg, "RESPONSE")
    
    @staticmethod
    def butler(msg, is_thinking=True):
        prefix = f"{Color.GREEN}{Color.BOLD}[管家]{Color.RESET}"
        if is_thinking:
            print(f"{prefix} 🤔 {msg}")
            chat_logger.add_message("管家", msg, "THINKING")
        else:
            print(f"{prefix} 💬 {msg}")
            chat_logger.add_message("管家", msg, "RESPONSE")
    
    @staticmethod
    def coder(msg, is_thinking=True):
        prefix = f"{Color.PURPLE}{Color.BOLD}[代码生成者]{Color.RESET}"
        if is_thinking:
            print(f"{prefix} 🤔 {msg}")
            chat_logger.add_message("代码生成者", msg, "THINKING")
        else:
            print(f"{prefix} 💬 {msg}")
            chat_logger.add_message("代码生成者", msg, "RESPONSE")
    
    @staticmethod
    def system(msg):
        prefix = f"{Color.CYAN}{Color.BOLD}[系统]{Color.RESET}"
        print(f"{prefix} {msg}")
        chat_logger.add_message("系统", msg, "INFO")
    
    @staticmethod
    def result(msg):
        prefix = f"{Color.YELLOW}{Color.BOLD}[结果]{Color.RESET}"
        print(f"{prefix} {msg}")
        chat_logger.add_message("结果", msg, "RESULT")
    
    @staticmethod
    def error(msg):
        prefix = f"{Color.RED}{Color.BOLD}[错误]{Color.RESET}"
        print(f"{prefix} {msg}")
        chat_logger.add_message("错误", msg, "ERROR")
    
    @staticmethod
    def user(msg):
        prefix = f"{Color.WHITE}{Color.BOLD}[用户]{Color.RESET}"
        print(f"{prefix} {msg}")
        chat_logger.add_message("用户", msg, "INPUT")
    
    @staticmethod
    def ai_thinking(role, thought, output=""):
        """记录AI的完整思考过程"""
        chat_logger.add_ai_thinking(role, thought, output)

class AIModel:
    """AI模型封装 - 记录所有输入输出"""
    
    def __init__(self, model_name, role_name):
        self.model_name = model_name
        self.role_name = role_name
        self.conversation_history = []
        self.all_responses = []
        
    def chat(self, prompt, system_prompt="", show_thinking=True):
        """与模型对话 - 记录完整交互"""
        
        if show_thinking:
            ThinkingLogger.system(f"调用{self.role_name}模型({self.model_name})...")
            ThinkingLogger.ai_thinking(self.role_name, f"准备调用模型\n模型: {self.model_name}\n系统提示: {system_prompt[:200] if system_prompt else '无'}\n用户提示: {prompt[:500]}")
        
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        
        messages.extend(self.conversation_history[-10:])
        messages.append({"role": "user", "content": prompt})
        
        # 记录请求
        request_log = {
            "timestamp": datetime.datetime.now().isoformat(),
            "model": self.model_name,
            "role": self.role_name,
            "system_prompt": system_prompt,
            "user_prompt": prompt,
            "history_length": len(self.conversation_history)
        }
        
        try:
            start_time = time.time()
            response = ollama.chat(
                model=self.model_name,
                messages=messages,
                options={"temperature": 0.7}
            )
            elapsed_time = time.time() - start_time
            
            result = response['message']['content']
            
            # 记录响应
            response_log = {
                "timestamp": datetime.datetime.now().isoformat(),
                "response": result,
                "elapsed_time": elapsed_time,
                "response_length": len(result)
            }
            
            # 保存到历史
            self.conversation_history.append({"role": "user", "content": prompt})
            self.conversation_history.append({"role": "assistant", "content": result})
            self.all_responses.append({"request": request_log, "response": response_log})
            
            if show_thinking:
                print(f"{Color.DIM}[{self.role_name}响应时间: {elapsed_time:.2f}秒]{Color.RESET}")
                ThinkingLogger.ai_thinking(self.role_name, 
                    f"收到响应\n响应时间: {elapsed_time:.2f}秒\n响应长度: {len(result)}字符\n响应内容预览:\n{result[:300]}{'...' if len(result) > 300 else ''}",
                    result[:500])
                
                # 输出到终端
                print(f"{Color.CYAN}┌{'─' * 60}┐{Color.RESET}")
                print(f"{Color.CYAN}│{Color.BOLD}{self.role_name}完整响应{Color.RESET}{Color.CYAN}{' ' * (46 - len(self.role_name))}│{Color.RESET}")
                print(f"{Color.CYAN}├{'─' * 60}┤{Color.RESET}")
                
                # 分行输出响应
                lines = result.split('\n')
                for line in lines[:30]:  # 限制输出行数
                    if len(line) > 70:
                        line = line[:67] + "..."
                    print(f"{Color.CYAN}│{Color.RESET} {line:<68} {Color.CYAN}│{Color.RESET}")
                if len(lines) > 30:
                    print(f"{Color.CYAN}│{Color.RESET} ... 还有 {len(lines)-30} 行{Color.RESET}{' ' * (55 - len(str(len(lines)-30)))} {Color.CYAN}│{Color.RESET}")
                print(f"{Color.CYAN}└{'─' * 60}┘{Color.RESET}")
                print()
            
            return result
            
        except Exception as e:
            error_msg = f"模型调用失败: {e}"
            ThinkingLogger.error(error_msg)
            chat_logger.add_message(self.role_name, error_msg, "ERROR")
            return f"ERROR: {e}"
    
    def clear_context(self):
        """清空上下文"""
        self.conversation_history = []
        ThinkingLogger.system(f"{self.role_name}上下文已清空")

class Organizer:
    """组织者 - 拆解任务、协调全局"""
    
    def __init__(self, model):
        self.model = model
        self.current_task = None
        self.current_plan = None
        self.decision_history = []
    
    def analyze_task(self, user_input):
        """分析用户输入，决定是聊天还是任务"""
        ThinkingLogger.organizer("正在分析用户需求...", is_thinking=True)
        
        prompt = f"""分析用户输入，判断是普通对话还是需要执行的任务。

用户输入: {user_input}

请严格按照以下格式输出:

TYPE: [CHAT 或 TASK]
REASON: [判断理由]

如果是TASK，额外输出:
TASK_NAME: [任务名称]
DESCRIPTION: [任务描述]

如果是CHAT，直接输出回复内容。"""
        
        response = self.model.chat(prompt, show_thinking=True)
        
        # 记录决策
        self.decision_history.append({
            "input": user_input,
            "response": response,
            "timestamp": datetime.datetime.now().isoformat()
        })
        
        if "TYPE: TASK" in response:
            # 提取任务信息
            task_name = ""
            description = ""
            for line in response.split('\n'):
                if line.startswith("TASK_NAME:"):
                    task_name = line.replace("TASK_NAME:", "").strip()
                elif line.startswith("DESCRIPTION:"):
                    description = line.replace("DESCRIPTION:", "").strip()
            
            ThinkingLogger.organizer(f"识别为任务: {task_name}", is_thinking=False)
            ThinkingLogger.organizer(f"任务描述: {description}", is_thinking=False)
            
            return {
                "type": "task",
                "name": task_name,
                "description": description,
                "raw_response": response
            }
        else:
            # 普通聊天，提取回复
            ThinkingLogger.organizer("识别为普通对话", is_thinking=False)
            return {
                "type": "chat",
                "response": response
            }
    
    def create_plan(self, task_name, task_description):
        """创建任务执行计划"""
        ThinkingLogger.organizer(f"正在为任务'{task_name}'创建执行计划...", is_thinking=True)
        
        prompt = f"""你需要拆解以下任务，给出详细的执行计划。

任务名称: {task_name}
任务描述: {task_description}

请严格按照以下格式输出计划:

PROJECT_NAME: [项目名称]
PROJECT_PATH: workspace/projects/[项目名称]

STEPS:
STEP_1: [步骤1描述，要具体可执行]
STEP_1_TYPE: [CODE 或 COMMAND] (CODE表示需要写代码，COMMAND表示执行系统命令)
STEP_1_OUTPUT: [预期输出文件名或结果]

STEP_2: [步骤2描述]
STEP_2_TYPE: [CODE 或 COMMAND]
STEP_2_OUTPUT: [预期输出]

... (根据任务复杂度输出3-10个步骤)

DEPENDENCIES: [步骤间的依赖关系描述]"""
        
        plan = self.model.chat(prompt, show_thinking=True)
        self.current_plan = plan
        self.current_task = task_name
        
        # 解析计划
        parsed_plan = self.parse_plan(plan)
        
        ThinkingLogger.organizer(f"计划创建完成，共{len(parsed_plan['steps'])}个步骤", is_thinking=False)
        
        return parsed_plan
    
    def parse_plan(self, plan_text):
        """解析计划文本"""
        steps = []
        current_step = {}
        
        lines = plan_text.split('\n')
        project_name = ""
        project_path = "workspace/projects/default"
        
        for line in lines:
            if line.startswith("PROJECT_NAME:"):
                project_name = line.replace("PROJECT_NAME:", "").strip()
                project_path = f"workspace/projects/{project_name}"
            elif line.startswith("PROJECT_PATH:"):
                project_path = line.replace("PROJECT_PATH:", "").strip()
            elif line.startswith("STEP_"):
                parts = line.split(':', 1)
                if len(parts) == 2:
                    step_info = parts[0].split('_')
                    if len(step_info) >= 2:
                        step_num = step_info[1]
                        if "TYPE" not in line and "OUTPUT" not in line:
                            current_step = {"number": step_num, "description": parts[1].strip()}
                        elif "TYPE" in line and "STEP" in line and step_info[1].isdigit():
                            step_type = parts[1].strip()
                            current_step["type"] = step_type
                            steps.append(current_step.copy())
                        elif "OUTPUT" in line:
                            current_step["output"] = parts[1].strip()
        
        return {
            "project_name": project_name,
            "project_path": project_path,
            "steps": steps,
            "raw_plan": plan_text
        }
    
    def review_result(self, project_path, task_description):
        """审查最终结果"""
        ThinkingLogger.organizer("正在审查最终结果...", is_thinking=True)
        
        # 收集项目文件列表
        files_info = []
        path = Path(project_path)
        if path.exists():
            for file in path.rglob("*"):
                if file.is_file():
                    files_info.append(f"{file.relative_to(path.parent)}")
        
        files_text = "\n".join(files_info[:20])
        
        prompt = f"""审查以下项目是否完成了任务。

任务: {task_description}
项目路径: {project_path}
生成的文件:
{files_text}

请判断:
1. 项目是否完整
2. 是否满足任务要求
3. 如果有问题，具体是什么问题

输出格式:
STATUS: [PASS 或 FAIL]
REASON: [通过或失败的原因]
FEEDBACK: [给用户的反馈信息]
IMPROVEMENTS: [如果不通过，需要的改进建议]"""
        
        review = self.model.chat(prompt, show_thinking=True)
        
        if "STATUS: PASS" in review:
            ThinkingLogger.organizer("审查通过", is_thinking=False)
            return {"passed": True, "feedback": review}
        else:
            ThinkingLogger.organizer("审查不通过，需要改进", is_thinking=False)
            return {"passed": False, "feedback": review}

class Butler:
    """管家 - 执行计划和协调"""
    
    def __init__(self, model, coder_model):
        self.model = model
        self.coder = coder_model
        self.current_project_dir = None
        self.execution_log = []
    
    def execute_plan(self, plan):
        """执行计划"""
        ThinkingLogger.butler("开始执行计划...", is_thinking=True)
        
        project_path = Path(plan["project_path"])
        project_path.mkdir(parents=True, exist_ok=True)
        self.current_project_dir = project_path
        
        ThinkingLogger.butler(f"项目目录: {project_path}", is_thinking=False)
        
        # 记录执行计划
        self.execution_log.append({
            "plan": plan,
            "start_time": datetime.datetime.now().isoformat(),
            "steps_results": []
        })
        
        results = []
        for i, step in enumerate(plan["steps"], 1):
            ThinkingLogger.butler(f"执行步骤 {i}: {step.get('description', '未知步骤')}", is_thinking=False)
            
            result = self.execute_step(step, project_path)
            results.append(result)
            
            self.execution_log[-1]["steps_results"].append({
                "step_number": i,
                "step": step,
                "result": result,
                "timestamp": datetime.datetime.now().isoformat()
            })
            
            if not result["success"]:
                ThinkingLogger.error(f"步骤{i}执行失败: {result.get('error', '未知错误')}")
                return {"success": False, "results": results}
        
        ThinkingLogger.butler("所有步骤执行完成", is_thinking=False)
        return {"success": True, "results": results}
    
    def execute_step(self, step, project_path):
        """执行单个步骤"""
        step_type = step.get("type", "COMMAND")
        
        ThinkingLogger.butler(f"步骤类型: {step_type}", is_thinking=True)
        
        if step_type == "CODE":
            return self.generate_code(step.get("description", ""), project_path)
        else:
            return self.execute_command(step.get("description", ""), project_path)
    
    def generate_code(self, requirement, project_path, max_retries=3):
        """生成代码，带检查和重试"""
        ThinkingLogger.coder(f"收到代码生成请求", is_thinking=True)
        ThinkingLogger.coder(f"需求: {requirement}", is_thinking=False)
        
        for attempt in range(max_retries):
            ThinkingLogger.coder(f"生成代码 (尝试 {attempt + 1}/{max_retries})", is_thinking=True)
            
            prompt = f"""根据以下需求生成完整代码。只输出代码，不要输出解释。

需求: {requirement}

输出格式:
FILENAME: [文件名，包含扩展名]
LANGUAGE: [编程语言]
CODE:
```语言
[完整代码]
```"""
            
            response = self.coder.chat(prompt, show_thinking=True)
            
            # 提取文件名和代码
            filename_match = re.search(r'FILENAME:\s*([^\n]+)', response)
            code_match = re.search(r'```\w*\n(.*?)```', response, re.DOTALL)
            
            if filename_match and code_match:
                filename = filename_match.group(1).strip()
                code = code_match.group(1).strip()
                filepath = project_path / filename
                
                ThinkingLogger.coder(f"准备保存文件: {filename}", is_thinking=False)
                ThinkingLogger.coder(f"代码长度: {len(code)} 字符", is_thinking=True)
                
                # 输出代码预览
                code_preview = code[:300] + ("..." if len(code) > 300 else "")
                ThinkingLogger.coder(f"代码预览:\n{code_preview}", is_thinking=True)
                
                # 代码质量检查
                check_result = self.check_code(code, filename)
                
                if check_result["passed"]:
                    filepath.write_text(code)
                    ThinkingLogger.coder(f"✓ 代码已保存: {filename}", is_thinking=False)
                    ThinkingLogger.coder(f"检查结果: {check_result['message']}", is_thinking=False)
                    
                    # 记录生成的代码
                    chat_logger.add_message("代码生成者", f"生成文件: {filename}\n代码:\n{code}", "CODE_OUTPUT")
                    
                    return {
                        "success": True,
                        "step": requirement,
                        "file": filename,
                        "code_length": len(code),
                        "check_result": check_result
                    }
                else:
                    ThinkingLogger.coder(f"✗ 代码检查未通过: {check_result['message']}", is_thinking=False)
                    
                    if attempt < max_retries - 1:
                        ThinkingLogger.coder("尝试修复代码...", is_thinking=True)
                        
                        # 要求模型修复
                        fix_prompt = f"""代码有以下问题，请修复:
问题: {check_result['message']}

原代码:
{code}

请输出修复后的完整代码(使用相同的输出格式)。"""
                        
                        # 记录修复尝试
                        chat_logger.add_message("代码生成者", f"代码检查失败，尝试修复\n问题: {check_result['message']}", "FIX_ATTEMPT")
                        continue
                    else:
                        return {
                            "success": False,
                            "error": check_result['message']
                        }
            else:
                ThinkingLogger.error("无法解析代码生成响应")
                if not filename_match:
                    ThinkingLogger.error("未找到文件名")
                if not code_match:
                    ThinkingLogger.error("未找到代码块")
        
        return {"success": False, "error": "代码生成失败"}
    
    def check_code(self, code, filename):
        """检查代码质量"""
        checks = []
        
        # Python语法检查
        if filename.endswith('.py'):
            try:
                compile(code, filename, 'exec')
                checks.append(("Python语法", True, "语法正确"))
                ThinkingLogger.coder(f"Python语法检查通过", is_thinking=True)
            except SyntaxError as e:
                checks.append(("Python语法", False, f"语法错误: {e}"))
                ThinkingLogger.coder(f"Python语法错误: {e}", is_thinking=True)
        
        # 代码长度检查
        if len(code.strip()) < 10:
            checks.append(("代码完整性", False, "代码太短"))
        else:
            checks.append(("代码完整性", True, f"代码长度 {len(code)} 字符"))
        
        # 检查是否有明显的错误标记
        todo_patterns = ['TODO', 'FIXME', 'XXX', 'HACK']
        found_todos = [p for p in todo_patterns if p in code.upper()]
        if found_todos:
            checks.append(("待办标记", False, f"包含待办: {', '.join(found_todos)}"))
        else:
            checks.append(("待办标记", True, "无待办标记"))
        
        # 检查主要函数/类定义
        if filename.endswith('.py'):
            has_main = 'def main' in code or 'if __name__' in code
            if not has_main and len(code.split('\n')) > 5:
                checks.append(("入口函数", False, "缺少main函数或if __name__块"))
            else:
                checks.append(("入口函数", True, "有入口定义"))
        
        passed = all(c[1] for c in checks)
        message = "\n".join([f"  {c[0]}: {'✓' if c[1] else '✗'} {c[2]}" for c in checks])
        
        return {"passed": passed, "message": message}
    
    def execute_command(self, command, cwd):
        """执行系统命令"""
        ThinkingLogger.butler(f"执行命令: {command}", is_thinking=False)
        
        # 解析命令
        parts = command.split()
        if not parts:
            return {"success": False, "error": "空命令"}
        
        cmd = parts[0]
        args = parts[1:]
        
        # 安全命令白名单
        safe_commands = {
            'mkdir': '创建目录',
            'ls': '列出文件',
            'cd': '切换目录',
            'pwd': '显示路径',
            'echo': '输出文本',
            'cat': '查看文件',
            'grep': '搜索文本',
            'find': '查找文件',
            'cp': '复制文件',
            'mv': '移动文件',
            'rm': '删除文件',
            'wget': '下载文件',
            'curl': 'HTTP请求',
            'python3': '运行Python',
            'pip3': '安装包',
            'touch': '创建文件'
        }
        
        if cmd not in safe_commands:
            ThinkingLogger.butler(f"跳过不安全的命令: {cmd}", is_thinking=True)
            return {"success": False, "error": f"不安全的命令: {cmd}"}
        
        try:
            ThinkingLogger.butler(f"执行: {cmd} {' '.join(args)}", is_thinking=True)
            
            result = subprocess.run(
                [cmd] + args,
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                output = result.stdout.strip()
                if output:
                    ThinkingLogger.butler(f"命令输出:\n{output[:500]}", is_thinking=False)
                else:
                    ThinkingLogger.butler("命令执行成功(无输出)", is_thinking=False)
                
                # 记录命令执行
                chat_logger.add_message("管家", f"执行命令: {command}\n输出: {output[:1000]}", "COMMAND_OUTPUT")
                
                return {
                    "success": True,
                    "command": command,
                    "output": output[:500]
                }
            else:
                error = result.stderr.strip()
                ThinkingLogger.error(f"命令执行失败: {error[:200]}")
                return {
                    "success": False,
                    "command": command,
                    "error": error[:200]
                }
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "命令执行超时"}
        except Exception as e:
            return {"success": False, "error": str(e)}

class AIToolChain:
    """主程序"""
    
    def __init__(self):
        ThinkingLogger.system("初始化AI工具链...")
        
        # 初始化三个不同的AI模型
        self.organizer_model = AIModel("llama3.1:8b", "组织者")
        self.butler_model = AIModel("qwen2.5:7b", "管家")
        self.coder_model = AIModel("deepseek-coder:6.7b", "代码生成者")
        
        # 初始化角色
        self.organizer = Organizer(self.organizer_model)
        self.butler = Butler(self.butler_model, self.coder_model)
        
        # 会话统计
        self.session_stats = {
            "start_time": datetime.datetime.now(),
            "task_count": 0,
            "chat_count": 0,
            "total_tokens": 0
        }
        
        ThinkingLogger.system("初始化完成!")
    
    def run(self):
        """运行主循环"""
        print("\n" + "="*80)
        print(f"{Color.BOLD}{Color.CYAN}AI工具链 - 三AI协作系统{Color.RESET}")
        print(f"{Color.BOLD}{Color.YELLOW}日志文件将保存在 conversations/ 目录{Color.RESET}")
        print("="*80)
        print(f"{Color.BOLD}组织者: llama3.1:8b{Color.RESET}")
        print(f"{Color.BOLD}管家: qwen2.5:7b{Color.RESET}")
        print(f"{Color.BOLD}代码生成者: deepseek-coder:6.7b{Color.RESET}")
        print("="*80)
        print("\n输入任务或问题，输入 'quit' 退出")
        print("输入 'clear' 清空对话历史")
        print("输入 'log' 查看当前日志文件位置")
        print("输入 'summary' 查看会话统计\n")
        
        while True:
            try:
                user_input = input(f"{Color.BOLD}{Color.WHITE}┌─[{Color.CYAN}用户{Color.WHITE}]─{Color.RESET}\n{Color.BOLD}{Color.WHITE}└─>>> {Color.RESET}").strip()
                
                if not user_input:
                    continue
                
                # 记录用户输入
                ThinkingLogger.user(user_input)
                chat_logger.add_conversation(user_input, "")
                
                if user_input.lower() == 'quit':
                    self._shutdown()
                    break
                
                if user_input.lower() == 'clear':
                    self.organizer_model.clear_context()
                    self.butler_model.clear_context()
                    self.coder_model.clear_context()
                    ThinkingLogger.system("对话历史已清空")
                    continue
                
                if user_input.lower() == 'log':
                    summary = chat_logger.get_session_summary()
                    ThinkingLogger.system(f"当前日志文件: {summary['session_file']}")
                    continue
                
                if user_input.lower() == 'summary':
                    self._show_summary()
                    continue
                
                print(f"{Color.BOLD}{Color.YELLOW}┌{'─' * 78}┐{Color.RESET}")
                print(f"{Color.BOLD}{Color.YELLOW}│{Color.RESET}{Color.BOLD} 开始处理用户请求{Color.RESET}{' ' * 60}{Color.BOLD}{Color.YELLOW}│{Color.RESET}")
                print(f"{Color.BOLD}{Color.YELLOW}└{'─' * 78}┘{Color.RESET}")
                
                # 组织者分析
                analysis = self.organizer.analyze_task(user_input)
                
                if analysis["type"] == "task":
                    ThinkingLogger.system("检测到任务请求，开始协作处理...")
                    self.session_stats["task_count"] += 1
                    
                    print(f"{Color.BOLD}{Color.GREEN}{'█' * 80}{Color.RESET}")
                    
                    # 创建执行计划
                    plan = self.organizer.create_plan(
                        analysis.get("name", "未命名任务"),
                        analysis.get("description", user_input)
                    )
                    
                    print(f"{Color.BOLD}{Color.YELLOW}{'═' * 80}{Color.RESET}")
                    ThinkingLogger.system("计划详情:")
                    print(f"  📁 项目名称: {plan['project_name']}")
                    print(f"  📂 项目路径: {plan['project_path']}")
                    print(f"  📝 任务步骤: {len(plan['steps'])}")
                    
                    # 显示步骤详情
                    for i, step in enumerate(plan['steps'], 1):
                        print(f"     步骤{i}: {step.get('description', '未知')} [{step.get('type', 'UNKNOWN')}]")
                    
                    print(f"{Color.BOLD}{Color.YELLOW}{'═' * 80}{Color.RESET}")
                    
                    # 记录任务执行
                    chat_logger.add_task_execution(analysis.get("name", ""), plan, {})
                    
                    # 管家执行
                    result = self.butler.execute_plan(plan)
                    
                    if result["success"]:
                        ThinkingLogger.system("任务执行完成!")
                        
                        # 组织者审查
                        review = self.organizer.review_result(plan["project_path"], user_input)
                        
                        if review["passed"]:
                            ThinkingLogger.result("✓ 任务成功完成!")
                            print(f"\n📁 项目位置: {plan['project_path']}")
                            print(f"📊 执行结果: {len(result.get('results', []))} 个步骤成功")
                        else:
                            ThinkingLogger.result("⚠ 任务完成但需要改进")
                            print(f"\n📋 审查反馈:\n{review['feedback'][:500]}")
                    else:
                        ThinkingLogger.error("任务执行失败")
                        print(f"\n❌ 失败步骤: {result.get('results', [])}")
                    
                    # 记录最终结果
                    chat_logger.add_message("系统", f"任务完成\n结果: {result}", "TASK_COMPLETE")
                
                else:
                    # 普通聊天
                    self.session_stats["chat_count"] += 1
                    print(f"\n{Color.BLUE}{'█' * 80}{Color.RESET}")
                    print(f"{Color.BLUE}{Color.BOLD}[组织者回复]{Color.RESET}")
                    print(f"{Color.BLUE}{'─' * 80}{Color.RESET}")
                    print(analysis.get("response", "无响应"))
                    print(f"{Color.BLUE}{'█' * 80}{Color.RESET}")
                    
                    # 记录聊天响应
                    chat_logger.add_conversation(user_input, analysis.get("response", ""))
                
                print(f"{Color.BOLD}{Color.YELLOW}{'─' * 80}{Color.RESET}\n")
                
            except KeyboardInterrupt:
                print("\n")
                ThinkingLogger.system("中断执行")
                self._shutdown()
                break
            except Exception as e:
                ThinkingLogger.error(f"执行错误: {e}")
                import traceback
                traceback.print_exc()
                continue
    
    def _shutdown(self):
        """关闭系统"""
        ThinkingLogger.system("正在关闭系统...")
        log_file = chat_logger.end_session()
        ThinkingLogger.system(f"对话已保存到: {log_file}")
        self._show_summary()
        ThinkingLogger.system("再见!")
    
    def _show_summary(self):
        """显示会话统计"""
        elapsed = datetime.datetime.now() - self.session_stats["start_time"]
        print(f"\n{Color.BOLD}{'='*60}{Color.RESET}")
        print(f"{Color.BOLD}会话统计{Color.RESET}")
        print(f"{Color.BOLD}{'='*60}{Color.RESET}")
        print(f"运行时间: {elapsed.seconds // 60}分 {elapsed.seconds % 60}秒")
        print(f"任务数量: {self.session_stats['task_count']}")
        print(f"对话数量: {self.session_stats['chat_count']}")
        
        summary = chat_logger.get_session_summary()
        print(f"日志文件: {summary['session_file']}")
        print(f"消息总数: {summary['message_count']}")
        print(f"{Color.BOLD}{'='*60}{Color.RESET}\n")

if __name__ == "__main__":
    toolchain = AIToolChain()
    toolchain.run()
EOF

# 创建启动脚本
cat > run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python main.py
EOF

chmod +x run.sh

echo ""
echo "========================================="
echo "部署完成!"
echo "========================================="
echo ""
echo "启动命令: cd $PROJECT_DIR && ./run.sh"
echo ""
echo "使用的模型:"
echo "  - 组织者: llama3.1:8b (负责理解需求、拆解任务、审查结果)"
echo "  - 管家: qwen2.5:7b (负责执行计划、协调调度)"
echo "  - 代码生成者: deepseek-coder:6.7b (负责生成代码)"
echo ""
echo "新增功能:"
echo "  ✓ 所有AI的思考过程实时显示"
echo "  ✓ 所有对话自动保存到 conversations/ 目录"
echo "  ✓ 支持命令: log - 查看日志文件, summary - 查看统计, clear - 清空上下文"
echo ""
echo "测试示例:"
echo "  >>> 请计算出圆周率π的前10位数字"
echo "  >>> 创建一个Python程序计算斐波那契数列"
echo "  >>> 下载 https://example.com 网页"
echo "  >>> log (查看日志文件位置)"
echo ""
echo "日志位置: conversations/conversation_YYYYMMDD_HHMMSS.txt"
echo "========================================="