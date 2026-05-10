#!/bin/bash

set -e

PROJECT_DIR="ai-toolchain"
cd "$(dirname "$0")"

echo "=== AI工具链一键部署 ==="

mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

if ! command -v ollama &> /dev/null; then
    echo "安装Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

if ! pgrep -x "ollama" > /dev/null; then
    echo "启动Ollama..."
    ollama serve > ollama.log 2>&1 &
    sleep 5
fi

echo "下载模型..."
ollama pull llama3.1:8b
ollama pull qwen2.5:7b
ollama pull deepseek-coder:6.7b
ollama pull codellama:7b

echo "创建Python环境..."
python3 -m venv venv
source venv/bin/activate
pip install ollama

mkdir -p conversations workspace memory

cat > main.py << 'EOF'
import ollama
import subprocess
import os
import json
import re
import sys
import time
import datetime
import shutil
import sqlite3
from pathlib import Path
from typing import Dict, List, Tuple, Any, Optional

class MemorySystem:
    def __init__(self, memory_dir: str = "memory"):
        self.memory_dir = Path(memory_dir)
        self.memory_dir.mkdir(exist_ok=True)
        self.db_path = self.memory_dir / "memory.db"
        self._init_database()
        self.short_term_memory = {
            "organizer": [],
            "butler": [],
            "conversations": [],
            "tasks": [],
            "context": {}
        }
        self._load_long_term_memory()
    
    def _init_database(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS conversations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                role TEXT,
                content TEXT,
                session_id TEXT
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                task_name TEXT,
                task_description TEXT,
                status TEXT,
                result TEXT,
                session_id TEXT
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS contexts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key TEXT UNIQUE,
                value TEXT,
                updated_at TEXT
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS projects (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_name TEXT,
                project_path TEXT,
                created_at TEXT,
                last_accessed TEXT,
                status TEXT,
                metadata TEXT
            )
        ''')
        conn.commit()
        conn.close()
    
    def _load_long_term_memory(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('SELECT key, value FROM contexts')
        self.long_term_contexts = dict(cursor.fetchall())
        conn.close()
    
    def remember_conversation(self, role: str, content: str, session_id: str = None):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        timestamp = datetime.datetime.now().isoformat()
        cursor.execute('''
            INSERT INTO conversations (timestamp, role, content, session_id)
            VALUES (?, ?, ?, ?)
        ''', (timestamp, role, content, session_id))
        conn.commit()
        conn.close()
        self.short_term_memory["conversations"].append({
            "role": role, "content": content, "timestamp": timestamp
        })
        if len(self.short_term_memory["conversations"]) > 100:
            self.short_term_memory["conversations"] = self.short_term_memory["conversations"][-100:]
    
    def remember_task(self, task_name: str, description: str, status: str, result: str, session_id: str = None):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        timestamp = datetime.datetime.now().isoformat()
        cursor.execute('''
            INSERT INTO tasks (timestamp, task_name, task_description, status, result, session_id)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (timestamp, task_name, description, status, result, session_id))
        conn.commit()
        conn.close()
        self.short_term_memory["tasks"].append({
            "task_name": task_name, "description": description,
            "status": status, "result": result, "timestamp": timestamp
        })
    
    def remember_context(self, key: str, value: str):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        timestamp = datetime.datetime.now().isoformat()
        cursor.execute('''
            INSERT OR REPLACE INTO contexts (key, value, updated_at)
            VALUES (?, ?, ?)
        ''', (key, value, timestamp))
        conn.commit()
        conn.close()
        self.short_term_memory["context"][key] = value
    
    def recall_context(self, key: str) -> Optional[str]:
        if key in self.short_term_memory["context"]:
            return self.short_term_memory["context"][key]
        return self.long_term_contexts.get(key)
    
    def recall_recent_conversations(self, limit: int = 10) -> List[Dict]:
        return self.short_term_memory["conversations"][-limit:]
    
    def recall_recent_tasks(self, limit: int = 5) -> List[Dict]:
        return self.short_term_memory["tasks"][-limit:]
    
    def update_organizer_memory(self, user_input: str, response: str):
        self.short_term_memory["organizer"].append({
            "user": user_input, "response": response,
            "timestamp": datetime.datetime.now().isoformat()
        })
        if len(self.short_term_memory["organizer"]) > 50:
            self.short_term_memory["organizer"] = self.short_term_memory["organizer"][-50:]
        self.remember_conversation("user", user_input)
        self.remember_conversation("organizer", response)
    
    def update_butler_memory(self, command: str, result: Dict):
        self.short_term_memory["butler"].append({
            "command": command, "result": result,
            "timestamp": datetime.datetime.now().isoformat()
        })
        if len(self.short_term_memory["butler"]) > 100:
            self.short_term_memory["butler"] = self.short_term_memory["butler"][-100:]
    
    def get_context_for_organizer(self, current_input: str) -> str:
        context_parts = []
        recent_conv = self.recall_recent_conversations(5)
        if recent_conv:
            context_parts.append("最近对话:")
            for conv in recent_conv:
                context_parts.append(f"  {conv['role']}: {conv['content'][:200]}")
        recent_tasks = self.recall_recent_tasks(3)
        if recent_tasks:
            context_parts.append("\n最近任务:")
            for task in recent_tasks:
                context_parts.append(f"  - {task['task_name']}: {task['status']}")
        current_project = self.recall_context("current_project")
        if current_project:
            context_parts.append(f"\n当前项目: {current_project}")
        return "\n".join(context_parts)
    
    def get_context_for_butler(self, task_description: str) -> str:
        context_parts = []
        recent_butler = self.short_term_memory["butler"][-5:]
        if recent_butler:
            context_parts.append("最近命令:")
            for cmd in recent_butler:
                status = "✓" if cmd["result"].get("success") else "✗"
                context_parts.append(f"  {status} {cmd['command'][:100]}")
        current_project = self.recall_context("current_project")
        if current_project:
            context_parts.append(f"\n当前目录: {current_project}")
        return "\n".join(context_parts)
    
    def save_project_memory(self, project_name: str, project_path: str, status: str = "active"):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        timestamp = datetime.datetime.now().isoformat()
        cursor.execute('''
            INSERT OR REPLACE INTO projects (project_name, project_path, created_at, last_accessed, status, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (project_name, project_path, timestamp, timestamp, status, "{}"))
        conn.commit()
        conn.close()
        self.remember_context("current_project", project_path)

class Logger:
    def __init__(self):
        self.conversations_dir = Path("conversations")
        self.conversations_dir.mkdir(exist_ok=True)
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = self.conversations_dir / f"session_{timestamp}.log"
    
    def log(self, level, role, message):
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}][{level}][{role}] {message}"
        print(log_entry)
        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(log_entry + '\n')
            f.flush()
    
    def info(self, role, msg): self.log("INFO", role, msg)
    def debug(self, role, msg): self.log("DEBUG", role, msg)
    def error(self, role, msg): self.log("ERROR", role, msg)
    def result(self, role, msg): self.log("RESULT", role, msg)

logger = Logger()

class ToolExecutor:
    def __init__(self):
        self.working_dir = Path.cwd()
        self.allowed_commands = {
            'ls': self._ls, 'mkdir': self._mkdir, 'cp': self._cp, 'mv': self._mv,
            'rm': self._rm, 'cat': self._cat, 'pwd': self._pwd, 'touch': self._touch,
            'wget': self._wget, 'curl': self._curl, 'python': self._python, 'cd': self._cd,
            'echo': self._echo, 'find': self._find, 'grep': self._grep
        }
    
    def execute(self, command: str, cwd: Optional[str] = None) -> Dict:
        parts = command.strip().split()
        if not parts:
            return {"success": False, "error": "空命令"}
        cmd = parts[0]
        args = parts[1:]
        if cmd not in self.allowed_commands:
            return {"success": False, "error": f"不允许的命令: {cmd}"}
        original_cwd = os.getcwd()
        if cwd:
            os.chdir(cwd)
        try:
            result = self.allowed_commands[cmd](args)
            return result
        except Exception as e:
            return {"success": False, "error": str(e)}
        finally:
            os.chdir(original_cwd)
    
    def _ls(self, args):
        path = args[0] if args else "."
        p = Path(path)
        if not p.exists():
            return {"success": False, "error": f"路径不存在: {path}"}
        items = list(p.iterdir())
        output = "\n".join([f"  {i.name}{'/' if i.is_dir() else ''}" for i in items])
        return {"success": True, "output": output}
    
    def _mkdir(self, args):
        if not args:
            return {"success": False, "error": "需要目录名"}
        path = Path(args[0])
        path.mkdir(parents=True, exist_ok=True)
        return {"success": True, "output": f"目录已创建: {path}"}
    
    def _cp(self, args):
        if len(args) < 2:
            return {"success": False, "error": "需要源文件和目标"}
        src = Path(args[0])
        dst = Path(args[1])
        if src.is_file():
            shutil.copy2(src, dst)
        else:
            shutil.copytree(src, dst, dirs_exist_ok=True)
        return {"success": True, "output": f"已复制: {src} -> {dst}"}
    
    def _mv(self, args):
        if len(args) < 2:
            return {"success": False, "error": "需要源文件和目标"}
        src = Path(args[0])
        dst = Path(args[1])
        shutil.move(str(src), str(dst))
        return {"success": True, "output": f"已移动: {src} -> {dst}"}
    
    def _rm(self, args):
        if not args:
            return {"success": False, "error": "需要文件或目录"}
        path = Path(args[0])
        recursive = '-r' in args or '-rf' in args
        if path.is_file():
            path.unlink()
        elif path.is_dir() and recursive:
            shutil.rmtree(path)
        else:
            return {"success": False, "error": "删除目录需要 -r 参数"}
        return {"success": True, "output": f"已删除: {path}"}
    
    def _cat(self, args):
        if not args:
            return {"success": False, "error": "需要文件名"}
        path = Path(args[0])
        if not path.exists():
            return {"success": False, "error": f"文件不存在: {path}"}
        content = path.read_text(encoding='utf-8')
        return {"success": True, "output": content}
    
    def _pwd(self, args):
        return {"success": True, "output": os.getcwd()}
    
    def _touch(self, args):
        if not args:
            return {"success": False, "error": "需要文件名"}
        path = Path(args[0])
        path.touch()
        return {"success": True, "output": f"文件已创建: {path}"}
    
    def _wget(self, args):
        if not args:
            return {"success": False, "error": "需要URL"}
        url = args[0]
        output = None
        if '-O' in args:
            idx = args.index('-O')
            if idx + 1 < len(args):
                output = args[idx + 1]
        try:
            import requests
            response = requests.get(url, timeout=30)
            if response.status_code == 200:
                if output:
                    Path(output).write_bytes(response.content)
                else:
                    filename = url.split('/')[-1] or 'downloaded_file'
                    Path(filename).write_bytes(response.content)
                return {"success": True, "output": f"下载成功: {output or filename}"}
            else:
                return {"success": False, "error": f"HTTP {response.status_code}"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _curl(self, args):
        if not args:
            return {"success": False, "error": "需要URL"}
        url = args[0]
        try:
            import requests
            response = requests.get(url, timeout=30)
            return {"success": True, "output": response.text[:1000]}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _python(self, args):
        if not args:
            return {"success": False, "error": "需要脚本文件"}
        script = args[0]
        if not Path(script).exists():
            return {"success": False, "error": f"脚本不存在: {script}"}
        try:
            result = subprocess.run(['python3', script], capture_output=True, text=True, timeout=30)
            return {"success": True, "output": result.stdout, "error": result.stderr}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _cd(self, args):
        if not args:
            return {"success": False, "error": "需要目录"}
        try:
            os.chdir(args[0])
            return {"success": True, "output": f"切换目录到: {os.getcwd()}"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _echo(self, args):
        return {"success": True, "output": " ".join(args)}
    
    def _find(self, args):
        search_path = args[0] if args else "."
        name_pattern = None
        if '-name' in args:
            idx = args.index('-name')
            if idx + 1 < len(args):
                name_pattern = args[idx + 1]
        results = []
        for root, dirs, files in os.walk(search_path):
            for file in files:
                if name_pattern:
                    import fnmatch
                    if fnmatch.fnmatch(file, name_pattern):
                        results.append(os.path.join(root, file))
                else:
                    results.append(os.path.join(root, file))
        return {"success": True, "output": "\n".join(results[:50])}
    
    def _grep(self, args):
        if len(args) < 2:
            return {"success": False, "error": "需要模式和文件"}
        pattern = args[0]
        files = args[1:]
        matches = []
        for file in files:
            path = Path(file)
            if path.exists() and path.is_file():
                content = path.read_text(encoding='utf-8', errors='ignore')
                for i, line in enumerate(content.split('\n'), 1):
                    if re.search(pattern, line):
                        matches.append(f"{file}:{i}: {line[:100]}")
        return {"success": True, "output": "\n".join(matches[:50])}

class AIModel:
    def __init__(self, model_name: str, role: str, memory: MemorySystem = None):
        self.model_name = model_name
        self.role = role
        self.memory = memory
        self.conversation_history = []
        self.max_history = 20
    
    def chat(self, prompt: str, system_prompt: str = "", context: str = "") -> str:
        logger.debug(self.role, f"调用模型: {self.model_name}")
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        if context:
            messages.append({"role": "system", "content": f"上下文:\n{context}"})
        for msg in self.conversation_history[-self.max_history:]:
            messages.append(msg)
        messages.append({"role": "user", "content": prompt})
        try:
            start = time.time()
            response = ollama.chat(
                model=self.model_name,
                messages=messages,
                options={"temperature": 0.3}
            )
            elapsed = time.time() - start
            result = response['message']['content']
            logger.debug(self.role, f"响应时间: {elapsed:.2f}s, 长度: {len(result)}")
            self.conversation_history.append({"role": "user", "content": prompt})
            self.conversation_history.append({"role": "assistant", "content": result})
            if len(self.conversation_history) > self.max_history * 2:
                self.conversation_history = self.conversation_history[-self.max_history * 2:]
            return result
        except Exception as e:
            logger.error(self.role, f"调用失败: {e}")
            return f"ERROR: {e}"
    
    def clear(self):
        self.conversation_history = []

class CodeChecker:
    def __init__(self, model: AIModel):
        self.model = model
    
    def check(self, code: str, filename: str, requirements: str) -> Dict:
        logger.info("代码检查者", f"检查文件: {filename}")
        prompt = f"""检查代码。
文件名: {filename}
需求: {requirements}
代码:
```{filename.split('.')[-1] if '.' in filename else 'python'}
{code}
```

输出格式:
STATUS: [PASS 或 FAIL]
ERRORS: [具体错误]
WARNINGS: [警告]
SUGGESTIONS: [建议]"""
response = self.model.chat(prompt)
status = "FAIL"
errors = ""
for line in response.split('\n'):
if line.startswith("STATUS:"):
status = line.replace("STATUS:", "").strip()
elif line.startswith("ERRORS:"):
errors = line.replace("ERRORS:", "").strip()
if filename.endswith('.py'):
try:
compile(code, filename, 'exec')
logger.info("代码检查者", "语法检查通过")
except SyntaxError as e:
status = "FAIL"
errors = f"语法错误: {e}"
passed = status == "PASS" and (errors.lower() in ["无", "none", ""])
return {"passed": passed, "status": status, "errors": errors}

class Organizer:
def init(self, model: AIModel, memory: MemorySystem):
self.model = model
self.memory = memory
self.session_id = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

用户输入: {user_input}
{context}
输出格式:
TYPE: [CHAT 或 TASK]
如果是CHAT:
RESPONSE: [回复]
如果是TASK:
TASK_NAME: [任务名]
TASK_DESCRIPTION: [描述]"""
response = self.model.chat(prompt, context=context)
self.memory.update_organizer_memory(user_input, response)
self.memory.remember_conversation("user", user_input, self.session_id)
self.memory.remember_conversation("organizer", response, self.session_id)
result = {"raw": response}
if "TYPE: CHAT" in response:
resp_match = re.search(r'RESPONSE:\s(.+?)(?=\n\w+:|$)', response, re.DOTALL)
result["type"] = "chat"
result["response"] = resp_match.group(1).strip() if resp_match else response
else:
result["type"] = "task"
name_match = re.search(r'TASK_NAME:\s*(.+?)(?=\n|$)', response)
desc_match = re.search(r'TASK_DESCRIPTION:\s(.+?)(?=\n|$)', response, re.DOTALL)
result["task_name"] = name_match.group(1).strip() if name_match else "未命名任务"
result["description"] = desc_match.group(1).strip() if desc_match else user_input
return result

任务名: {task_name}
描述: {description}
{task_context}
输出格式:
PROJECT_NAME: [项目名]
PROJECT_PATH: workspace/projects/[项目名]
步骤1: [描述]
步骤1类型: [COMMAND 或 CODE]
步骤1命令: [具体命令]
步骤2: [描述]
步骤2类型: [COMMAND 或 CODE]
步骤2命令: [具体命令]"""
plan_text = self.model.chat(prompt)
steps = []
lines = plan_text.split('\n')
project_name = task_name
project_path = f"workspace/projects/{task_name}"
current_step = {}
for line in lines:
if line.startswith('PROJECT_NAME:'):
project_name = line.replace('PROJECT_NAME:', '').strip()
project_path = f"workspace/projects/{project_name}"
elif line.startswith('PROJECT_PATH:'):
project_path = line.replace('PROJECT_PATH:', '').strip()
elif line.startswith('步骤') and '类型' not in line and '命令' not in line:
if current_step:
steps.append(current_step)
current_step = {"number": len(steps) + 1, "description": line.split(':', 1)[1].strip()}
elif '步骤类型:' in line:
current_step["type"] = line.split(':', 1)[1].strip()
elif '步骤命令:' in line:
current_step["command"] = line.split(':', 1)[1].strip()
if current_step:
steps.append(current_step)
self.memory.save_project_memory(project_name, project_path)
return {"project_name": project_name, "project_path": project_path, "steps": steps}

需求: {original_requirement}
路径: {project_path}
文件: {', '.join(files) if files else '无'}
结果: {json.dumps(results, indent=2, ensure_ascii=False)[:500]}
输出格式:
STATUS: [PASS 或 FAIL]
REASON: [原因]
FEEDBACK: [反馈]"""
review = self.model.chat(prompt)
passed = "STATUS: PASS" in review
self.memory.remember_task(Path(project_path).name, original_requirement,
"completed" if passed else "failed", review, self.session_id)
return {"passed": passed, "review": review, "files": files}

class Butler:
def init(self, model: AIModel, executor: ToolExecutor, memory: MemorySystem):
self.model = model
self.executor = executor
self.memory = memory

class Coder:
def init(self, model: AIModel):
self.model = model

需求: {requirement}
{context}
输出格式:
FILENAME: [文件名]
CODE:

```语言
[完整代码]
```"""
        response = self.model.chat(prompt)
        filename_match = re.search(r'FILENAME:\s*([^\n]+)', response)
        filename = filename_match.group(1).strip() if filename_match else "generated.py"
        code_match = re.search(r'CODE:\s*```\w*\n(.*?)```', response, re.DOTALL)
        if not code_match:
            code_match = re.search(r'```\w*\n(.*?)```', response, re.DOTALL)
        if code_match:
            return {"success": True, "filename": filename, "code": code_match.group(1).strip()}
        return {"success": False, "error": "无法提取代码"}
    
    def fix(self, code: str, errors: str, requirement: str) -> Dict:
        logger.info("代码生成者", "修复代码...")
        prompt = f"""修复代码。
需求: {requirement}
错误: {errors}
原代码:
```python
{code}
```

输出修复后的完整代码:
FILENAME: [文件名]
CODE:

```语言
[修复后的代码]
```"""
        response = self.model.chat(prompt)
        code_match = re.search(r'CODE:\s*```\w*\n(.*?)```', response, re.DOTALL)
        if not code_match:
            code_match = re.search(r'```\w*\n(.*?)```', response, re.DOTALL)
        if code_match:
            return {"success": True, "filename": "fixed.py", "code": code_match.group(1).strip()}
        return {"success": False, "error": "无法提取修复后的代码"}

class AIToolChain:
    def __init__(self):
        logger.info("系统", "初始化AI工具链...")
        self.memory = MemorySystem()
        self.organizer_model = AIModel("llama3.1:8b", "组织者", self.memory)
        self.butler_model = AIModel("qwen2.5:7b", "管家", self.memory)
        self.coder_model = AIModel("deepseek-coder:6.7b", "代码生成者", self.memory)
        self.checker_model = AIModel("codellama:7b", "代码检查者", self.memory)
        self.executor = ToolExecutor()
        self.organizer = Organizer(self.organizer_model, self.memory)
        self.butler = Butler(self.butler_model, self.executor, self.memory)
        self.coder = Coder(self.coder_model)
        self.checker = CodeChecker(self.checker_model)
        logger.info("系统", "初始化完成")
    
    def run(self):
        print("\n" + "="*70)
        print("AI工具链系统 - 多轮记忆版")
        print("="*70)
        print("组织者: llama3.1:8b | 管家: qwen2.5:7b")
        print("代码生成: deepseek-coder:6.7b | 检查: codellama:7b")
        print("="*70)
        print("命令: quit退出, clear清空记忆, log查看日志\n")
        while True:
            try:
                user_input = input("\n>>> ").strip()
                if not user_input:
                    continue
                logger.info("用户", user_input)
                if user_input.lower() == 'quit':
                    logger.info("系统", "再见!")
                    break
                if user_input.lower() == 'clear':
                    self.organizer_model.clear()
                    self.butler_model.clear()
                    self.coder_model.clear()
                    self.checker_model.clear()
                    logger.info("系统", "已清空上下文")
                    continue
                if user_input.lower() == 'log':
                    logger.info("系统", f"日志: {logger.log_file}")
                    continue
                understanding = self.organizer.understand(user_input)
                if understanding["type"] == "chat":
                    print(f"\n[组织者] {understanding['response']}")
                    continue
                print("\n[组织者] 创建计划...")
                plan = self.organizer.create_plan(understanding["task_name"], understanding["description"])
                print(f"\n项目: {plan['project_name']}")
                print(f"路径: {plan['project_path']}")
                print("步骤:")
                for step in plan["steps"]:
                    print(f"  {step['number']}. {step.get('description', '')} [{step.get('type', '')}]")
                print("\n[管家] 执行中...")
                success, results = self.butler.execute_plan(plan)
                if not success:
                    print("\n执行失败")
                    continue
                code_results = []
                for result in results:
                    if result.get("pending"):
                        print(f"\n生成代码: {result['requirement'][:100]}...")
                        code_result = self.butler.generate_code(
                            result["requirement"], plan["project_path"], self.coder, self.checker
                        )
                        code_results.append(code_result)
                        result["success"] = code_result["success"]
                        if code_result["success"]:
                            print(f"  ✓ 生成成功: {code_result['filename']}")
                        else:
                            print(f"  ✗ 生成失败: {code_result.get('error', '')}")
                print("\n[组织者] 审查中...")
                review = self.organizer.review(plan["project_path"], user_input, results + code_results)
                if review["passed"]:
                    print(f"\n✅ 任务完成!")
                    print(f"项目位置: {plan['project_path']}")
                    print(f"生成文件: {', '.join(review['files'])}")
                else:
                    print(f"\n⚠️ 需要改进")
                    print(review['review'][:300])
            except KeyboardInterrupt:
                print("\n")
                logger.info("系统", "中断")
                break
            except Exception as e:
                logger.error("系统", str(e))

if __name__ == "__main__":
    toolchain = AIToolChain()
    toolchain.run()
EOF

cat > run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python main.py
EOF

chmod +x run.sh

echo ""
echo "部署完成!"
echo ""
echo "启动: cd $PROJECT_DIR && ./run.sh"
echo ""
echo "支持命令:"
echo "  >>> 创建一个Python计算器"
echo "  >>> mv file.txt backup/"
echo "  >>> clear - 清空记忆"
echo "  >>> log - 查看日志"
echo "========================================="