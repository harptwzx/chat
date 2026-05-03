/* ============================================================================
 * Resurgam OS - Shell/Command Line Interface Header
 * ============================================================================ */

#ifndef SHELL_H
#define SHELL_H

#include "kernel.h"

#define SHELL_BUFFER_SIZE   256
#define SHELL_HISTORY_SIZE  16
#define SHELL_MAX_ARGS      16

/* Shell state */
typedef struct {
    char buffer[SHELL_BUFFER_SIZE];
    int buffer_pos;
    int buffer_len;

    char history[SHELL_HISTORY_SIZE][SHELL_BUFFER_SIZE];
    int history_pos;
    int history_count;

    char cwd[256];
    char prompt[32];

    window_t* window;
    int cursor_x;
    int cursor_y;

    uint32_t text_color;
    uint32_t bg_color;
    uint32_t prompt_color;
} shell_state_t;

extern shell_state_t shell;

/* Commands */
typedef struct {
    const char* name;
    const char* description;
    int (*func)(int argc, char** argv);
} shell_cmd_t;

/* Functions */
void init_shell(void);
void shell_create_window(void);
void shell_input(char c);
void shell_arrow_key(uint8_t scancode);
void shell_execute(void);
void shell_print(const char* str);
void shell_println(const char* str);
void shell_clear(void);
void shell_prompt(void);
void shell_scroll(void);
void paint_shell_window(window_t* w);

/* Built-in commands */
int cmd_help(int argc, char** argv);
int cmd_clear(int argc, char** argv);
int cmd_echo(int argc, char** argv);
int cmd_ls(int argc, char** argv);
int cmd_cd(int argc, char** argv);
int cmd_pwd(int argc, char** argv);
int cmd_cat(int argc, char** argv);
int cmd_mkdir(int argc, char** argv);
int cmd_rm(int argc, char** argv);
int cmd_cp(int argc, char** argv);
int cmd_mv(int argc, char** argv);
int cmd_ps(int argc, char** argv);
int cmd_kill(int argc, char** argv);
int cmd_mem(int argc, char** argv);
int cmd_time(int argc, char** argv);
int cmd_reboot(int argc, char** argv);
int cmd_shutdown(int argc, char** argv);
int cmd_about(int argc, char** argv);
int cmd_ver(int argc, char** argv);
int cmd_color(int argc, char** argv);
int cmd_exit(int argc, char** argv);

#endif
