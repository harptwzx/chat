#!/usr/bin/env python3
"""
OpenClaw Web UI - Gradio 界面
支持模型选择、项目管理、代码执行
"""

import gradio as gr
import re
from openclaw import OpenClaw, MODEL_CONFIGS


class WebInterface:
    def __init__(self):
        self.claw = None
        self.current_model = None

    def load_model(self, model_key: str):
        """加载选定的模型"""
        if self.claw is not None:
            return "⚠️ 模型已加载，请重启应用切换模型", gr.update()

        try:
            self.claw = OpenClaw(model_key)
            self.current_model = model_key
            config = MODEL_CONFIGS[model_key]
            return (
                f"✅ 模型加载成功: {config['name']}\n"
                f"📦 大小: ~{config['size_gb']}GB\n"
                f"🖥️ 设备: {self.claw.engine.device}",
                gr.update(visible=True)
            )
        except Exception as e:
            return f"❌ 模型加载失败: {e}", gr.update(visible=False)

    def create_ui(self):
        with gr.Blocks(title="🦀 OpenClaw - AI 编程助手", theme=gr.themes.Soft()) as demo:
            gr.Markdown("""
            # 🦀 OpenClaw
            ### 基于 DeepSeek-R1-Distill-Qwen 的 AI 编程助手
            支持 Python、C++、JavaScript 等语言，自动执行代码，管理多文件项目。
            """)

            # ========== 模型选择区域 ==========
            with gr.Row():
                with gr.Column(scale=1):
                    gr.Markdown("## 🚀 模型选择")
                    model_choice = gr.Dropdown(
                        label="选择模型",
                        choices=[
                            ("DeepSeek-R1-Distill-Qwen-14B (推荐，需 16GB+ 显存)", "deepseek-r1-14b"),
                            ("DeepSeek-R1-Distill-Qwen-7B (轻量，需 8GB+ 显存)", "deepseek-r1-7b"),
                        ],
                        value="deepseek-r1-14b"
                    )
                    load_model_btn = gr.Button("📥 加载模型", variant="primary")
                    model_status = gr.Textbox(
                        label="模型状态",
                        value="请选择模型并点击加载",
                        interactive=False,
                        lines=3
                    )

                with gr.Column(scale=2):
                    gr.Markdown("## 📋 模型信息")
                    model_info = gr.Dataframe(
                        headers=["模型", "参数", "大小", "最低显存", "说明"],
                        value=[
                            ["14B", "140亿", "~28GB", "16GB", "推理能力强，推荐 RTX 3090/4090"],
                            ["7B", "70亿", "~15GB", "8GB", "速度快，推荐 RTX 3060 12GB"],
                        ],
                        interactive=False
                    )

            gr.Markdown("---")

            # ========== 主界面（初始隐藏） ==========
            with gr.Column(visible=False) as main_interface:
                with gr.Row():
                    # 左侧：项目管理
                    with gr.Column(scale=1):
                        gr.Markdown("## 📁 项目管理")

                        project_name = gr.Textbox(
                            label="项目名称",
                            placeholder="输入项目名称",
                            value="default"
                        )

                        with gr.Row():
                            create_btn = gr.Button("创建项目", variant="primary")
                            load_btn = gr.Button("加载项目")

                        project_list = gr.Dropdown(
                            label="已有项目",
                            choices=[],
                            interactive=True
                        )

                        refresh_projects_btn = gr.Button("🔄 刷新项目列表")

                        file_list = gr.Dropdown(
                            label="项目文件",
                            choices=[],
                            interactive=True
                        )

                        refresh_files_btn = gr.Button("🔄 刷新文件列表")

                        file_content = gr.Code(
                            label="文件内容",
                            language="python",
                            interactive=True,
                            lines=15
                        )

                        with gr.Row():
                            save_file_btn = gr.Button("💾 保存文件")
                            read_file_btn = gr.Button("📖 读取文件")
                            delete_file_btn = gr.Button("🗑️ 删除")

                        new_filename = gr.Textbox(
                            label="新文件名",
                            placeholder="例如: main.py"
                        )

                        gr.Markdown("---")
                        gr.Markdown("## ⚙️ 生成设置")
                        temperature = gr.Slider(
                            minimum=0.1, maximum=1.0, value=0.6, step=0.1,
                            label="Temperature"
                        )
                        max_tokens = gr.Slider(
                            minimum=256, maximum=4096, value=2048, step=256,
                            label="Max Tokens"
                        )

                    # 右侧：对话区域
                    with gr.Column(scale=2):
                        gr.Markdown("## 💬 对话")

                        chatbot = gr.Chatbot(
                            height=500,
                            bubble_full_width=False,
                            show_copy_button=True
                        )

                        with gr.Row():
                            msg_input = gr.Textbox(
                                label="输入消息",
                                placeholder="描述你想写的代码...",
                                scale=4,
                                lines=2
                            )
                            send_btn = gr.Button("发送", variant="primary", scale=1)

                        with gr.Row():
                            clear_btn = gr.Button("🧹 清空历史")
                            stop_btn = gr.Button("⏹️ 停止生成")

                        gr.Markdown("## 📊 执行结果")
                        exec_output = gr.Code(
                            label="最近执行输出",
                            language="bash",
                            interactive=False,
                            lines=10
                        )

            # ========== 事件处理 ==========

            def on_load_model(model_key):
                status, visibility = self.load_model(model_key)
                return status, visibility

            def on_create_project(name):
                if not name or self.claw is None:
                    return "请输入项目名", gr.update(), gr.update()
                result = self.claw.create_project(name)
                files = self.claw.pm.list_files()
                return result, gr.update(choices=self.claw.pm.list_projects()), gr.update(choices=files)

            def on_load_project(name):
                if not name or self.claw is None:
                    return "请选择项目", gr.update(), gr.update()
                result = self.claw.load_project(name)
                files = self.claw.pm.list_files()
                return result, gr.update(choices=self.claw.pm.list_projects()), gr.update(choices=files)

            def on_refresh_projects():
                if self.claw is None:
                    return gr.update()
                return gr.update(choices=self.claw.pm.list_projects())

            def on_refresh_files():
                if self.claw is None:
                    return gr.update()
                return gr.update(choices=self.claw.pm.list_files())

            def on_read_file(filename):
                if not filename or self.claw is None:
                    return ""
                try:
                    return self.claw.pm.read_file(filename)
                except Exception as e:
                    return str(e)

            def on_save_file(filename, content):
                if not filename or self.claw is None:
                    return "请输入文件名"
                self.claw.pm.save_file(filename, content)
                return f"已保存: {filename}"

            def on_delete_file(filename):
                if not filename or self.claw is None:
                    return "请选择文件", gr.update()
                self.claw.pm.delete_file(filename)
                return f"已删除: {filename}", gr.update(choices=self.claw.pm.list_files())

            def on_send(message, history):
                if not message.strip() or self.claw is None:
                    return "", history, ""

                history = history + [[message, ""]]
                yield "", history, ""

                full_response = ""
                exec_report = ""

                for token in self.claw.chat_stream(message):
                    if "[EXEC_REPORT]" in token:
                        parts = token.split("[EXEC_REPORT]")
                        full_response += parts[0]
                        exec_report = parts[1].replace("[END_REPORT]", "")
                        history[-1][1] = full_response
                        yield "", history, exec_report
                        return

                    full_response += token
                    history[-1][1] = full_response
                    yield "", history, ""

                yield "", history, exec_report

            def on_clear():
                if self.claw:
                    self.claw.clear_history()
                return [], ""

            # 绑定事件
            load_model_btn.click(
                on_load_model,
                inputs=model_choice,
                outputs=[model_status, main_interface]
            )

            create_btn.click(
                on_create_project,
                inputs=project_name,
                outputs=[gr.Textbox(visible=False), project_list, file_list]
            )

            load_btn.click(
                on_load_project,
                inputs=project_list,
                outputs=[gr.Textbox(visible=False), project_list, file_list]
            )

            refresh_projects_btn.click(on_refresh_projects, outputs=project_list)
            refresh_files_btn.click(on_refresh_files, outputs=file_list)

            read_file_btn.click(on_read_file, inputs=file_list, outputs=file_content)
            save_file_btn.click(on_save_file, inputs=[new_filename, file_content], outputs=gr.Textbox(visible=False))
            delete_file_btn.click(on_delete_file, inputs=file_list, outputs=[gr.Textbox(visible=False), file_list])

            send_btn.click(
                on_send,
                inputs=[msg_input, chatbot],
                outputs=[msg_input, chatbot, exec_output]
            )

            msg_input.submit(
                on_send,
                inputs=[msg_input, chatbot],
                outputs=[msg_input, chatbot, exec_output]
            )

            clear_btn.click(on_clear, outputs=[chatbot, exec_output])

        return demo

    def launch(self, **kwargs):
        demo = self.create_ui()
        demo.launch(**kwargs)


if __name__ == "__main__":
    ui = WebInterface()
    ui.launch(server_name="0.0.0.0", server_port=7860, share=False)