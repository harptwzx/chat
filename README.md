# Resurgam OS v1.0

## 概述

Resurgam OS 是一个 32 位图形化操作系统，使用 C 语言和 x86 汇编语言编写。系统名称 "Resurgam" 源自拉丁语，意为 "我将再起"。

## 特性

### 核心功能
- **32位保护模式**：完整的 x86 保护模式支持
- **抢占式多任务**：支持多进程调度和上下文切换
- **内存分页**：虚拟内存管理，支持 4KB 页面
- **中断处理**：完整的 IDT 和 PIC 中断管理

### 图形界面
- **窗口管理器**：支持多窗口、拖拽、最小化/最大化
- **桌面环境**：美观的桌面背景、图标、任务栏
- **视觉效果**：渐变、阴影、圆角、透明混合
- **鼠标光标**：自定义鼠标指针

### 输入设备
- **键盘支持**：完整的 PS/2 键盘驱动，支持快捷键
- **鼠标支持**：PS/2 鼠标驱动，支持三键和滚轮

### 命令行
- **Shell**：功能完整的命令行解释器
- **命令历史**：支持上下键浏览历史命令
- **内置命令**：help, ls, cd, cat, ps, mem, time 等 20+ 命令

### 文件系统
- **虚拟文件系统**：内存中的 VFS 实现
- **文件操作**：创建、删除、读取、写入、复制、移动

## 系统要求

- x86 兼容处理器（386 或更高）
- 至少 16MB RAM
- VGA 兼容显卡
- PS/2 键盘和鼠标（或 USB 兼容）

## 构建

### 工具链
需要安装 i686-elf 交叉编译工具链：
```bash
# Ubuntu/Debian
sudo apt-get install gcc make nasm qemu-system-x86 grub-common xorriso

# 或使用 Docker
# docker run -it -v $(pwd):/src joshwyant/cross-cc
```

### 编译
```bash
make all        # 构建完整系统
make run        # 在 QEMU 中运行
make run-serial # 带串口调试输出运行
make clean      # 清理构建文件
```

## 目录结构

```
resurgam_os/
├── boot/           # 引导程序
│   ├── boot.asm    # 主引导扇区
│   └── stage2.asm  # 二级引导加载器
├── kernel/         # 内核源码
│   ├── kernel.asm  # 内核汇编入口
│   ├── kernel.c    # 内核主程序
│   ├── kernel.h    # 内核头文件
│   ├── vga.c/h     # 图形驱动
│   ├── console.c/h # 文本控制台
│   ├── keyboard.c/h# 键盘驱动
│   ├── mouse.c/h   # 鼠标驱动
│   ├── idt.c/h     # 中断描述符表
│   ├── gdt.c/h     # 全局描述符表
│   ├── timer.c/h   # 定时器
│   ├── paging.c/h  # 内存分页
│   ├── task.c/h    # 任务管理
│   ├── vfs.c/h     # 虚拟文件系统
│   ├── shell.c/h   # 命令行解释器
│   ├── window.c/h  # 窗口管理器
│   ├── desktop.c/h # 桌面环境
│   └── font8x16.h  # 字体数据
├── Makefile        # 构建脚本
├── linker.ld       # 链接器脚本
└── README.md       # 本文件
```

## 启动画面

系统启动时显示 Resurgam OS Logo 和加载进度条，背景为渐变蓝色。

## 桌面环境

- **壁纸**：动态生成的渐变图案
- **图标**：终端、文件管理器、设置、计算器、关于
- **任务栏**：开始按钮、窗口列表、系统托盘、时钟
- **开始菜单**：应用程序列表

## 命令列表

| 命令 | 描述 |
|------|------|
| help | 显示可用命令 |
| clear | 清屏 |
| echo | 显示文本 |
| ls | 列出目录内容 |
| cd | 切换目录 |
| pwd | 显示当前路径 |
| cat | 显示文件内容 |
| mkdir | 创建目录 |
| rm | 删除文件 |
| cp | 复制文件 |
| mv | 移动文件 |
| ps | 显示进程列表 |
| kill | 终止进程 |
| mem | 显示内存使用 |
| time | 显示系统时间 |
| reboot | 重启系统 |
| shutdown | 关闭系统 |
| about | 关于系统 |
| ver | 显示版本 |
| color | 更改颜色 |
| exit | 关闭终端 |

## 技术细节

### 内存布局
- 0x00000000 - 0x000FFFFF：低 1MB（保留）
- 0x00100000 - 0x00FFFFFF：内核代码和数据
- 0x01000000 - 0x0FFFFFFF：堆和动态分配
- 0xC0000000 - 0xCFFFFFFF：内核虚拟地址空间

### 中断向量
- 0x00-0x1F：CPU 异常
- 0x20-0x2F：硬件中断（PIC）
- 0x80：系统调用

### 图形模式
- 分辨率：640x480
- 颜色深度：32位（RGB）
- 帧缓冲：软件渲染

## 许可证

Resurgam OS 是开源项目，遵循 MIT 许可证。

## 作者

Resurgam Project Team

## 版本历史

- v1.0 (2026-04-29)：初始版本，包含基本 GUI、Shell 和文件系统
