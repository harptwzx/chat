/* ============================================================================
 * Resurgam OS - Task Manager Header
 * ============================================================================ */

#ifndef TASK_H
#define TASK_H

#include "kernel.h"

#define MAX_TASKS       32
#define TASK_STACK_SIZE 8192
#define TASK_NAME_LEN   32

/* Task states */
#define TASK_READY      0
#define TASK_RUNNING    1
#define TASK_BLOCKED    2
#define TASK_SLEEPING   3
#define TASK_ZOMBIE     4

/* Task structure */
typedef struct task {
    uint32_t id;
    char name[TASK_NAME_LEN];
    uint32_t state;
    uint32_t esp;
    uint32_t ebp;
    uint32_t eip;
    uint32_t cr3;
    uint32_t stack[TASK_STACK_SIZE / 4];
    uint32_t priority;
    uint32_t time_slice;
    uint32_t sleep_ticks;
    struct task* next;
} task_t;

/* Task manager state */
extern task_t* current_task;
extern task_t* task_list;
extern uint32_t task_count;
extern uint32_t next_task_id;

/* Functions */
void init_tasking(void);
task_t* create_task(void (*entry)(void), const char* name, uint32_t priority);
void destroy_task(task_t* task);
void schedule(void);
void yield(void);
void sleep_task(uint32_t ms);
void block_task(task_t* task);
void unblock_task(task_t* task);
void switch_task(task_t* from, task_t* to);
task_t* get_task_by_id(uint32_t id);
void list_tasks(void);

#endif
