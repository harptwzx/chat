/* ============================================================================
 * Resurgam OS - Task Manager
 * Cooperative multitasking with priority scheduling
 * ============================================================================ */

#include "kernel.h"
#include "task.h"
#include "timer.h"

/* Task manager state */
task_t* current_task = 0;
task_t* task_list = 0;
uint32_t task_count = 0;
uint32_t next_task_id = 1;

/* Idle task */
static task_t idle_task;

/* ============================================================================
 * Initialize Tasking
 * ============================================================================ */
void init_tasking(void) {
    /* Create idle task */
    memset(&idle_task, 0, sizeof(task_t));
    idle_task.id = 0;
    strcpy(idle_task.name, "idle");
    idle_task.state = TASK_READY;
    idle_task.priority = 0;
    idle_task.time_slice = 1;

    current_task = &idle_task;
    task_list = &idle_task;
    task_count = 1;
}

/* ============================================================================
 * Create Task
 * ============================================================================ */
task_t* create_task(void (*entry)(void), const char* name, uint32_t priority) {
    if (task_count >= MAX_TASKS) return 0;

    task_t* task = (task_t*)kmalloc(sizeof(task_t));
    if (!task) return 0;

    memset(task, 0, sizeof(task_t));

    task->id = next_task_id++;
    strncpy(task->name, name, TASK_NAME_LEN - 1);
    task->name[TASK_NAME_LEN - 1] = '\0';
    task->state = TASK_READY;
    task->priority = priority;
    task->time_slice = priority + 1;

    /* Setup stack */
    uint32_t* stack = &task->stack[TASK_STACK_SIZE / 4 - 1];

    /* Push initial register values */
    *stack-- = 0x202;           /* EFLAGS (interrupts enabled) */
    *stack-- = 0x08;            /* CS (kernel code segment) */
    *stack-- = (uint32_t)entry; /* EIP */
    *stack-- = 0;               /* EAX */
    *stack-- = 0;               /* ECX */
    *stack-- = 0;               /* EDX */
    *stack-- = 0;               /* EBX */
    *stack-- = 0;               /* ESP (will be set by iret) */
    *stack-- = 0;               /* EBP */
    *stack-- = 0;               /* ESI */
    *stack-- = 0;               /* EDI */

    task->esp = (uint32_t)(stack + 1);
    task->ebp = 0;
    task->eip = (uint32_t)entry;
    task->cr3 = read_cr3();

    /* Add to task list */
    task->next = task_list;
    task_list = task;
    task_count++;

    return task;
}

/* ============================================================================
 * Destroy Task
 * ============================================================================ */
void destroy_task(task_t* task) {
    if (!task || task->id == 0) return; /* Don't destroy idle task */

    /* Remove from list */
    task_t** current = &task_list;
    while (*current) {
        if (*current == task) {
            *current = task->next;
            break;
        }
        current = &(*current)->next;
    }

    kfree(task);
    task_count--;

    /* If current task was destroyed, reschedule */
    if (current_task == task) {
        current_task = task_list;
        schedule();
    }
}

/* ============================================================================
 * Scheduler
 * ============================================================================ */
void schedule(void) {
    if (!current_task) return;

    /* Find next ready task with highest priority */
    task_t* next = 0;
    uint32_t highest_priority = 0;

    task_t* t = task_list;
    while (t) {
        if (t->state == TASK_READY && t->priority >= highest_priority) {
            highest_priority = t->priority;
            next = t;
        }
        t = t->next;
    }

    if (!next) next = &idle_task;

    if (next != current_task) {
        task_t* prev = current_task;
        current_task = next;
        current_task->state = TASK_RUNNING;

        /* Context switch */
        switch_task(prev, next);
    }
}

/* ============================================================================
 * Yield CPU
 * ============================================================================ */
void yield(void) {
    if (current_task) {
        current_task->state = TASK_READY;
    }
    schedule();
}

/* ============================================================================
 * Sleep Task
 * ============================================================================ */
void sleep_task(uint32_t ms) {
    if (!current_task || current_task->id == 0) return;

    current_task->sleep_ticks = (ms * timer_frequency) / 1000;
    current_task->state = TASK_SLEEPING;
    schedule();
}

/* ============================================================================
 * Block/Unblock Task
 * ============================================================================ */
void block_task(task_t* task) {
    if (task) task->state = TASK_BLOCKED;
}

void unblock_task(task_t* task) {
    if (task) task->state = TASK_READY;
}

/* ============================================================================
 * Get Task by ID
 * ============================================================================ */
task_t* get_task_by_id(uint32_t id) {
    task_t* t = task_list;
    while (t) {
        if (t->id == id) return t;
        t = t->next;
    }
    return 0;
}

/* ============================================================================
 * List Tasks
 * ============================================================================ */
void list_tasks(void) {
    kprintf("Task List:\n");
    kprintf("ID  Name          State    Priority\n");
    kprintf("--  ----          -----    --------\n");

    task_t* t = task_list;
    while (t) {
        const char* state_str = "unknown";
        switch (t->state) {
            case TASK_READY:    state_str = "ready"; break;
            case TASK_RUNNING:  state_str = "running"; break;
            case TASK_BLOCKED:  state_str = "blocked"; break;
            case TASK_SLEEPING: state_str = "sleeping"; break;
            case TASK_ZOMBIE:   state_str = "zombie"; break;
        }

        kprintf("%-2d  %-12s  %-7s  %d\n", t->id, t->name, state_str, t->priority);
        t = t->next;
    }
}

/* ============================================================================
 * Context Switch (Assembly)
 * ============================================================================ */
void switch_task(task_t* from, task_t* to) {
    /* Save current context */
    uint32_t esp, ebp, eip;
    asm volatile("mov %%esp, %0" : "=r"(esp));
    asm volatile("mov %%ebp, %0" : "=r"(ebp));
    asm volatile("mov 4(%%esp), %0" : "=r"(eip));

    from->esp = esp;
    from->ebp = ebp;
    from->eip = eip;

    /* Restore new context */
    esp = to->esp;
    ebp = to->ebp;
    eip = to->eip;

    asm volatile("mov %0, %%esp" : : "r"(esp));
    asm volatile("mov %0, %%ebp" : : "r"(ebp));
    asm volatile("jmp *%0" : : "r"(eip));
}
