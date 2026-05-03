/* ============================================================================
 * Resurgam OS - Virtual File System Header
 * ============================================================================ */

#ifndef VFS_H
#define VFS_H

#include "kernel.h"

#define VFS_NAME_MAX    64
#define VFS_PATH_MAX    256
#define VFS_MAX_FILES   128
#define VFS_MAX_OPEN    32

/* File types */
#define VFS_FILE        1
#define VFS_DIRECTORY   2
#define VFS_DEVICE      3
#define VFS_SYMLINK     4

/* File permissions */
#define VFS_PERM_READ   0x01
#define VFS_PERM_WRITE  0x02
#define VFS_PERM_EXEC   0x04

/* VFS node */
typedef struct vfs_node {
    char name[VFS_NAME_MAX];
    uint32_t type;
    uint32_t size;
    uint32_t permissions;
    uint32_t created;
    uint32_t modified;
    uint32_t parent;
    uint32_t first_child;
    uint32_t next_sibling;
    uint8_t* data;
} vfs_node_t;

/* File descriptor */
typedef struct {
    int used;
    uint32_t node_idx;
    uint32_t position;
    uint32_t mode;
} vfs_fd_t;

/* Functions */
void init_vfs(void);
int vfs_create(const char* path, uint32_t type);
int vfs_delete(const char* path);
int vfs_open(const char* path, uint32_t mode);
int vfs_close(int fd);
int vfs_read(int fd, void* buf, uint32_t size);
int vfs_write(int fd, const void* buf, uint32_t size);
int vfs_seek(int fd, uint32_t offset);
int vfs_mkdir(const char* path);
int vfs_list(const char* path, char* buf, uint32_t size);
vfs_node_t* vfs_find(const char* path);

#endif
