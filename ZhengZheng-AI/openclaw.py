#!/usr/bin/env python3
"""
OpenClaw Core - 基于 transformers 的代码执行引擎
支持模型选择：DeepSeek-R1-Distill-Qwen-14B / 7B
"""

import os
import re
import json
import shutil
import subprocess
import tempfile
from typing import Optional, Dict, List, Tuple, Any, Generator
from dataclasses import dataclass, field
from pathlib import Path
from datetime import datetime
from threading import Thread

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, TextIteratorStreamer


# ========== 模型配置 ==========
MODEL_CONFIGS = {
    "deepseek-r1-14b": {
        "name": "DeepSeek-R1-Distill-Qwen-14B",
        "repo": "deepseek-ai/DeepSeek-R1-Distill-Qwen-14B",
        "description": "14B 参数，推理能力强，推荐 RTX 3090/4090 或更高",
        "min_vram_gb": 16,
        "size_gb": 28,
    },
    "deepseek-r1-7b": {
        "name": "DeepSeek-R1-Distill-Qwen-7B",
        "repo": "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B",
        "description": "7B 参数，速度快，推荐 RTX 3060 12GB 或更高",
        "min_vram_gb": 8,
        "size_gb": 15,
    },
}


@dataclass
class CodeBlock:
    filename: Optional[str]
    language: str
    code: str


@dataclass
class ExecutionResult:
    filename: Optional[str]
    language: str
    stdout: str
    stderr: str
    returncode: int
    success: bool


@dataclass
class Message:
    role: str
    content: str
    executions: List[ExecutionResult] = field(default_factory=list)
    timestamp: str = field(default_factory=lambda: datetime.now().strftime("%H:%M:%S"))


class ProjectManager:
    """项目管理器"""

    def __init__(self, base_dir: str = "projects"):
        self.base_dir = Path(base_dir)
        self.base_dir.mkdir(exist_ok=True)
        self.current_project: Optional[str] = None
        self.current_project_path: Optional[Path] = None

    def create_project(self, name: str) -> Path:
        project_path = self.base_dir / name
        project_path.mkdir(exist_ok=True)
        self.current_project = name
        self.current_project_path = project_path
        return project_path

    def load_project(self, name: str) -> Path:
        project_path = self.base_dir / name
        if not project_path.exists():
            raise ValueError(f"项目 {name} 不存在")
        self.current_project = name
        self.current_project_path = project_path
        return project_path

    def list_projects(self) -> List[str]:
        return [d.name for d in self.base_dir.iterdir() if d.is_dir()]

    def save_file(self, filename: str, content: str) -> Path:
        if not self.current_project_path:
            self.create_project("default")
        filepath = self.current_project_path / filename
        filepath.parent.mkdir(parents=True, exist_ok=True)
        filepath.write_text(content, encoding="utf-8")
        return filepath

    def read_file(self, filename: str) -> str:
        if not self.current_project_path:
            raise ValueError("未选择项目")
        filepath = self.current_project_path / filename
        if not filepath.exists():
            raise FileNotFoundError(f"文件 {filename} 不存在")
        return filepath.read_text(encoding="utf-8")

    def list_files(self) -> List[str]:
        if not self.current_project_path:
            return []
        files = []
        for f in self.current_project_path.rglob("*"):
            if f.is_file():
                files.append(str(f.relative_to(self.current_project_path)))
        return files

    def delete_file(self, filename: str) -> None:
        if not self.current_project_path:
            raise ValueError("未选择项目")
        filepath = self.current_project_path / filename
        if filepath.exists():
            filepath.unlink()

    def get_project_path(self) -> Optional[Path]:
        return self.current_project_path


class CodeExecutor:
    """代码执行器"""

    def __init__(self, project_manager: ProjectManager, timeout: int = 30):
        self.timeout = timeout
        self.pm = project_manager
        self.temp_dir = Path(tempfile.mkdtemp(prefix="openclaw_exec_"))

    def _get_work_dir(self) -> Path:
        if self.pm.current_project_path:
            return self.pm.current_project_path
        return self.temp_dir

    def execute_python(self, code: str, filename: Optional[str] = None) -> Tuple[str, str, int]:
        work_dir = self._get_work_dir()
        if filename:
            script_path = work_dir / filename
        else:
            script_path = work_dir / "script.py"
        script_path.write_text(code, encoding="utf-8")

        try:
            env = os.environ.copy()
            env["PYTHONPATH"] = str(work_dir) + os.pathsep + env.get("PYTHONPATH", "")
            result = subprocess.run(
                ["python3", str(script_path)],
                capture_output=True, text=True, timeout=self.timeout,
                cwd=str(work_dir), env=env
            )
            return result.stdout, result.stderr, result.returncode
        except subprocess.TimeoutExpired:
            return "", "执行超时", -1
        except Exception as e:
            return "", str(e), -1

    def execute_cpp(self, code: str, filename: Optional[str] = None) -> Tuple[str, str, int]:
        work_dir = self._get_work_dir()
        if filename:
            source_path = work_dir / filename
            binary_name = source_path.stem
        else:
            source_path = work_dir / "main.cpp"
            binary_name = "main"
        binary_path = work_dir / binary_name
        source_path.write_text(code, encoding="utf-8")

        compile_result = subprocess.run(
            ["g++", "-std=c++17", "-O2", str(source_path), "-o", str(binary_path)],
            capture_output=True, text=True, timeout=self.timeout, cwd=str(work_dir)
        )
        if compile_result.returncode != 0:
            return "", f"编译错误:\n{compile_result.stderr}", compile_result.returncode

        try:
            result = subprocess.run(
                [str(binary_path)], capture_output=True, text=True,
                timeout=self.timeout, cwd=str(work_dir)
            )
            return result.stdout, result.stderr, result.returncode
        except subprocess.TimeoutExpired:
            return "", "执行超时", -1

    def execute_javascript(self, code: str, filename: Optional[str] = None) -> Tuple[str, str, int]:
        work_dir = self._get_work_dir()
        if filename:
            script_path = work_dir / filename
        else:
            script_path = work_dir / "script.js"
        script_path.write_text(code, encoding="utf-8")
        try:
            result = subprocess.run(
                ["node", str(script_path)], capture_output=True, text=True,
                timeout=self.timeout, cwd=str(work_dir)
            )
            return result.stdout, result.stderr, result.returncode
        except Exception as e:
            return "", str(e), -1

    def execute_bash(self, code: str) -> Tuple[str, str, int]:
        work_dir = self._get_work_dir()
        try:
            result = subprocess.run(
                code, shell=True, capture_output=True, text=True,
                timeout=self.timeout, cwd=str(work_dir)
            )
            return result.stdout, result.stderr, result.returncode
        except subprocess.TimeoutExpired:
            return "", "执行超时", -1

    def execute(self, block: CodeBlock) -> ExecutionResult:
        executors = {
            "python": self.execute_python, "py": self.execute_python,
            "cpp": self.execute_cpp, "c++": self.execute_cpp, "cxx": self.execute_cpp, "cc": self.execute_cpp,
            "javascript": self.execute_javascript, "js": self.execute_javascript,
            "bash": self.execute_bash, "sh": self.execute_bash, "shell": self.execute_bash,
        }
        lang = block.language.lower()
        executor = executors.get(lang, self.execute_python)

        if lang in ("bash", "sh", "shell"):
            stdout, stderr, returncode = executor(block.code)
        else:
            stdout, stderr, returncode = executor(block.code, block.filename)

        return ExecutionResult(
            filename=block.filename, language=block.language,
            stdout=stdout, stderr=stderr, returncode=returncode, success=returncode == 0
        )

    def cleanup(self):
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)


class DeepSeekEngine:
    """DeepSeek 模型引擎"""

    SYSTEM_PROMPT = """你是 OpenClaw，一个专业的编程助手。

## 核心能力
1. **代码生成**：根据需求生成完整、可运行的代码
2. **多文件项目**：可以生成多个相互关联的文件
3. **文件操作**：可以读写项目中的文件

## 输出格式规范

### 单文件代码
```python
# 代码内容
```

### 多文件项目
```python:main.py
# 主程序
```

```python:utils.py
# 工具模块
```

```cpp:main.cpp
// C++ 主程序
```

### 文件操作
- 读取文件：`[READ:filename.py]`
- 修改文件：`[EDIT:filename.py]` 后接完整新内容

## 规则
1. 代码必须完整、可运行
2. 多文件项目时确保引用正确
3. 优先使用相对路径
4. 输出简洁，重点在代码本身
"""

    def __init__(self, model_key: str = "deepseek-r1-14b"):
        config = MODEL_CONFIGS.get(model_key, MODEL_CONFIGS["deepseek-r1-14b"])
        self.model_name = config["repo"]
        self.model_key = model_key
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        print(f"🖥️  使用设备: {self.device}")
        print(f"📥 正在加载模型: {config['name']}")
        print(f"   首次下载约 {config['size_gb']}GB，请耐心等待...")

        self.tokenizer = AutoTokenizer.from_pretrained(
            self.model_name, trust_remote_code=True, padding_side="left"
        )

        load_kwargs = {
            "torch_dtype": torch.float16 if self.device == "cuda" else torch.float32,
            "device_map": "auto" if self.device == "cuda" else None,
            "trust_remote_code": True,
            "low_cpu_mem_usage": True,
        }

        if self.device == "cuda":
            try:
                self.model = AutoModelForCausalLM.from_pretrained(self.model_name, **load_kwargs)
            except torch.cuda.OutOfMemoryError:
                print("⚠️ 显存不足，尝试使用 8-bit 量化加载...")
                load_kwargs["load_in_8bit"] = True
                load_kwargs.pop("torch_dtype", None)
                self.model = AutoModelForCausalLM.from_pretrained(self.model_name, **load_kwargs)
        else:
            self.model = AutoModelForCausalLM.from_pretrained(self.model_name, **load_kwargs)
            self.model = self.model.to("cpu")

        self.model.eval()
        print(f"✅ 模型 {config['name']} 加载完成")

    def generate(self, prompt: str, max_new_tokens: int = 2048, temperature: float = 0.6) -> str:
        messages = [
            {"role": "system", "content": self.SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ]

        text = self.tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = self.tokenizer(text, return_tensors="pt").to(self.device)

        with torch.no_grad():
            outputs = self.model.generate(
                **inputs, max_new_tokens=max_new_tokens,
                temperature=temperature, do_sample=True, top_p=0.9,
                pad_token_id=self.tokenizer.eos_token_id
            )

        response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        if "assistant" in response:
            response = response.split("assistant")[-1].strip()
        return response

    def generate_stream(self, prompt: str, max_new_tokens: int = 2048, temperature: float = 0.6) -> Generator[str, None, None]:
        messages = [
            {"role": "system", "content": self.SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ]

        text = self.tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = self.tokenizer(text, return_tensors="pt").to(self.device)

        streamer = TextIteratorStreamer(self.tokenizer, skip_prompt=True, skip_special_tokens=True)
        generation_kwargs = dict(
            inputs, streamer=streamer, max_new_tokens=max_new_tokens,
            temperature=temperature, do_sample=True, top_p=0.9,
            pad_token_id=self.tokenizer.eos_token_id
        )

        thread = Thread(target=self.model.generate, kwargs=generation_kwargs)
        thread.start()

        for text in streamer:
            yield text


class OpenClaw:
    """OpenClaw 主控制器"""

    def __init__(self, model_key: str = "deepseek-r1-14b"):
        print("🦀 启动 OpenClaw...")
        self.engine = DeepSeekEngine(model_key)
        self.pm = ProjectManager()
        self.executor = CodeExecutor(self.pm)
        self.history: List[Message] = []
        self.current_project: Optional[str] = None

    def create_project(self, name: str) -> str:
        path = self.pm.create_project(name)
        self.current_project = name
        return f"✅ 创建项目: {name}\n📁 路径: {path}"

    def load_project(self, name: str) -> str:
        path = self.pm.load_project(name)
        self.current_project = name
        return f"✅ 加载项目: {name}\n📁 路径: {path}\n📄 文件: {', '.join(self.pm.list_files())}"

    def list_projects(self) -> str:
        projects = self.pm.list_projects()
        return "📁 项目列表:\n" + "\n".join(f"  - {p}" for p in projects) if projects else "暂无项目"

    def list_files(self) -> str:
        files = self.pm.list_files()
        return "📄 文件列表:\n" + "\n".join(f"  - {f}" for f in files) if files else "当前项目为空"

    def read_file(self, filename: str) -> str:
        try:
            content = self.pm.read_file(filename)
            return f"📖 {filename}:\n```\n{content}\n```"
        except Exception as e:
            return f"❌ 错误: {e}"

    def delete_file(self, filename: str) -> str:
        try:
            self.pm.delete_file(filename)
            return f"🗑️ 已删除: {filename}"
        except Exception as e:
            return f"❌ 错误: {e}"

    def extract_code_blocks(self, text: str) -> List[CodeBlock]:
        blocks = []
        pattern = r'```(\w+)(?::([^\n]+))?\n(.*?)```'
        matches = re.findall(pattern, text, re.DOTALL)

        for lang, filename, code in matches:
            blocks.append(CodeBlock(
                filename=filename.strip() if filename else None,
                language=lang.strip(), code=code.strip()
            ))

        if not blocks:
            pattern2 = r'```(\w+)?\n(.*?)```'
            matches2 = re.findall(pattern2, text, re.DOTALL)
            for lang, code in matches2:
                blocks.append(CodeBlock(
                    filename=None,
                    language=lang.strip() if lang else "python",
                    code=code.strip()
                ))
        return blocks

    def extract_file_operations(self, text: str) -> List[Tuple[str, str, Optional[str]]]:
        operations = []
        for match in re.finditer(r'\[READ:([^\]]+)\]', text):
            operations.append(("read", match.group(1), None))
        for match in re.finditer(r'\[EDIT:([^\]]+)\]\n```(\w+)?\n(.*?)```', text, re.DOTALL):
            operations.append(("edit", match.group(1), match.group(3)))
        return operations

    def process_response(self, response: str) -> Tuple[str, List[ExecutionResult]]:
        file_ops = self.extract_file_operations(response)
        for op, filename, content in file_ops:
            if op == "read":
                try:
                    file_content = self.pm.read_file(filename)
                    response += f"\n\n[文件 {filename} 内容]:\n```\n{file_content}\n```"
                except:
                    response += f"\n\n[错误: 无法读取 {filename}]"
            elif op == "edit" and content:
                self.pm.save_file(filename, content)
                response += f"\n\n[已更新: {filename}]"

        code_blocks = self.extract_code_blocks(response)
        executions = []

        for block in code_blocks:
            if block.filename:
                self.pm.save_file(block.filename, block.code)
            result = self.executor.execute(block)
            executions.append(result)

        return response, executions

    def chat(self, user_input: str) -> Dict[str, Any]:
        context = self._build_context()
        full_prompt = f"{context}\n\n用户: {user_input}"

        response = self.engine.generate(full_prompt)
        processed_response, executions = self.process_response(response)

        exec_report = ""
        for i, ex in enumerate(executions, 1):
            exec_report += f"\n{'─'*40}\n"
            exec_report += f"🔧 执行 [{ex.language}] {ex.filename or f'代码块{i}'}\n"
            if ex.stdout:
                exec_report += f"📤 输出:\n{ex.stdout}\n"
            if ex.stderr:
                exec_report += f"⚠️ 错误:\n{ex.stderr}\n"
            exec_report += f"返回码: {ex.returncode} {'✅' if ex.success else '❌'}"

        self.history.append(Message(role="user", content=user_input))
        self.history.append(Message(role="assistant", content=processed_response, executions=executions))

        return {
            "response": processed_response,
            "executions": executions,
            "exec_report": exec_report,
            "files": self.pm.list_files()
        }

    def chat_stream(self, user_input: str) -> Generator[str, None, None]:
        context = self._build_context()
        full_prompt = f"{context}\n\n用户: {user_input}"

        full_response = ""
        for token in self.engine.generate_stream(full_prompt):
            full_response += token
            yield token

        processed_response, executions = self.process_response(full_response)

        self.history.append(Message(role="user", content=user_input))
        self.history.append(Message(role="assistant", content=processed_response, executions=executions))

        exec_report = ""
        for ex in executions:
            exec_report += f"\n{'─'*40}\n"
            exec_report += f"🔧 [{ex.language}] {ex.filename or '代码块'}\n"
            if ex.stdout:
                exec_report += f"输出: {ex.stdout[:500]}\n"
            if ex.stderr:
                exec_report += f"错误: {ex.stderr[:500]}\n"

        yield f"\n\n[EXEC_REPORT]{exec_report}[END_REPORT]"

    def _build_context(self) -> str:
        context = []
        for msg in self.history[-20:]:
            prefix = "用户" if msg.role == "user" else "助手"
            context.append(f"{prefix}: {msg.content}")
            for ex in msg.executions:
                if ex.stdout:
                    context.append(f"[执行结果]: {ex.stdout[:200]}")
        return "\n".join(context)

    def get_history(self) -> List[Message]:
        return self.history

    def clear_history(self):
        self.history.clear()
        return "🧹 对话历史已清空"

    def cleanup(self):
        self.executor.cleanup()


def select_model() -> str:
    """交互式模型选择"""
    print("\n" + "="*60)
    print("🦀 OpenClaw - 请选择要加载的模型")
    print("="*60 + "\n")

    for key, config in MODEL_CONFIGS.items():
        print(f"  [{key}]")
        print(f"    名称: {config['name']}")
        print(f"    说明: {config['description']}")
        print(f"    大小: ~{config['size_gb']}GB")
        print(f"    最低显存: {config['min_vram_gb']}GB")
        print()

    while True:
        choice = input("请输入模型编号 (deepseek-r1-14b / deepseek-r1-7b): ").strip().lower()
        if choice in MODEL_CONFIGS:
            return choice
        print("❌ 无效选择，请重新输入")


def cli_mode():
    """命令行模式"""
    model_key = select_model()
    claw = OpenClaw(model_key)

    print(f"""
╔══════════════════════════════════════════════════════════════╗
║                    🦀 OpenClaw 代码助手                       ║
║         模型: {MODEL_CONFIGS[model_key]['name']:<30}      ║
╚══════════════════════════════════════════════════════════════╝

命令:
  /project <name>     创建/切换项目
  /projects           列出所有项目
  /files              列出当前项目文件
  /read <file>        读取文件
  /delete <file>      删除文件
  /model              查看当前模型信息
  /clear              清空对话历史
  /exit               退出
""")

    while True:
        try:
            user_input = input("\n🧑 > ").strip()
            if not user_input:
                continue

            if user_input.startswith("/"):
                parts = user_input.split(maxsplit=1)
                cmd = parts[0].lower()
                arg = parts[1] if len(parts) > 1 else ""

                if cmd == "/exit":
                    print("👋 再见！")
                    break
                elif cmd == "/clear":
                    print(claw.clear_history())
                elif cmd == "/project":
                    print(claw.create_project(arg) if arg else "请指定项目名")
                elif cmd == "/projects":
                    print(claw.list_projects())
                elif cmd == "/files":
                    print(claw.list_files())
                elif cmd == "/read":
                    print(claw.read_file(arg) if arg else "请指定文件名")
                elif cmd == "/delete":
                    print(claw.delete_file(arg) if arg else "请指定文件名")
                elif cmd == "/model":
                    config = MODEL_CONFIGS[claw.engine.model_key]
                    print(f"当前模型: {config['name']}")
                    print(f"仓库: {config['repo']}")
                    print(f"设备: {claw.engine.device}")
                else:
                    print("未知命令")
                continue

            print("\n🤖 思考中...")
            result = claw.chat(user_input)

            print(f"\n📝 回复:\n{result['response']}")
            if result['exec_report']:
                print(f"\n{result['exec_report']}")
            if result['files']:
                print(f"\n📁 项目文件: {', '.join(result['files'])}")

        except KeyboardInterrupt:
            print("\n👋 再见！")
            break
        except Exception as e:
            print(f"❌ 错误: {e}")

    claw.cleanup()


if __name__ == "__main__":
    cli_mode()