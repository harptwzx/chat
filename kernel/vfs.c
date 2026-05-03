/* ============================================================================
 * Resurgam OS - Virtual File System
 * In-memory filesystem for the OS
 * ============================================================================ */

#include "kernel.h"
#include "vfs.h"

/* VFS data */
static vfs_node_t nodes[VFS_MAX_FILES];
static vfs_fd_t fds[VFS_MAX_OPEN];
static uint32_t node_count = 0;
static uint32_t next_node = 1; /* 0 is root */

/* ============================================================================
 * Initialize VFS
 * ============================================================================ */
void init_vfs(void) {
    memset(nodes, 0, sizeof(nodes));
    memset(fds, 0, sizeof(fds));

    /* Create root directory */
    strcpy(nodes[0].name, "/");
    nodes[0].type = VFS_DIRECTORY;
    nodes[0].permissions = VFS_PERM_READ | VFS_PERM_WRITE | VFS_PERM_EXEC;
    node_count = 1;

    /* Create some default directories and files */
    vfs_mkdir("/documents");
    vfs_mkdir("/system");
    vfs_mkdir("/bin");
    vfs_mkdir("/dev");
    vfs_mkdir("/tmp");

    /* Create sample files */
    int fd = vfs_create("/readme.txt", VFS_FILE);
    if (fd >= 0) {
        vfs_write(fd, "Welcome to Resurgam OS!\n", 24);
        vfs_close(fd);
    }

    fd = vfs_create("/config.ini", VFS_FILE);
    if (fd >= 0) {
        vfs_write(fd, "[system]\nname=Resurgam\nversion=1.0\n", 38);
        vfs_close(fd);
    }
}

/* ============================================================================
 * Find Node by Path
 * ============================================================================ */
vfs_node_t* vfs_find(const char* path) {
    if (strcmp(path, "/") == 0) return &nodes[0];

    /* Simple path parsing */
    uint32_t current = 0;
    char temp[VFS_PATH_MAX];
    strcpy(temp, path);

    char* token = temp;
    if (*token == '/') token++;

    while (*token) {
        char* end = token;
        while (*end && *end != '/') end++;
        char saved = *end;
        *end = '\0';

        /* Search children */
        uint32_t child = nodes[current].first_child;
        int found = 0;
        while (child != 0) {
            if (strcmp(nodes[child].name, token) == 0) {
                current = child;
                found = 1;
                break;
            }
            child = nodes[child].next_sibling;
        }

        *end = saved;
        if (!found) return 0;

        token = end;
        if (*token == '/') token++;
    }

    return &nodes[current];
}

/* ============================================================================
 * Create File/Directory
 * ============================================================================ */
int vfs_create(const char* path, uint32_t type) {
    if (node_count >= VFS_MAX_FILES) return -1;

    /* Find parent directory */
    char parent_path[VFS_PATH_MAX];
    strcpy(parent_path, path);

    char* last_slash = parent_path;
    char* p = parent_path;
    while (*p) {
        if (*p == '/') last_slash = p;
        p++;
    }

    char name[VFS_NAME_MAX];
    strcpy(name, last_slash + 1);
    *last_slash = '\0';

    if (strlen(parent_path) == 0) strcpy(parent_path, "/");

    vfs_node_t* parent = vfs_find(parent_path);
    if (!parent || parent->type != VFS_DIRECTORY) return -1;

    /* Create node */
    uint32_t idx = next_node++;
    while (idx < VFS_MAX_FILES && nodes[idx].type != 0) idx++;
    if (idx >= VFS_MAX_FILES) return -1;

    memset(&nodes[idx], 0, sizeof(vfs_node_t));
    strcpy(nodes[idx].name, name);
    nodes[idx].type = type;
    nodes[idx].permissions = VFS_PERM_READ | VFS_PERM_WRITE;
    nodes[idx].parent = parent - nodes;
    nodes[idx].next_sibling = parent->first_child;
    parent->first_child = idx;
    node_count++;

    /* Allocate data for files */
    if (type == VFS_FILE) {
        nodes[idx].data = (uint8_t*)kmalloc(4096);
        nodes[idx].size = 0;
    }

    return vfs_open(path, VFS_PERM_WRITE);
}

/* ============================================================================
 * Make Directory
 * ============================================================================ */
int vfs_mkdir(const char* path) {
    return vfs_create(path, VFS_DIRECTORY);
}

/* ============================================================================
 * Delete File/Directory
 * ============================================================================ */
int vfs_delete(const char* path) {
    vfs_node_t* node = vfs_find(path);
    if (!node) return -1;

    uint32_t idx = node - nodes;

    /* Remove from parent's child list */
    vfs_node_t* parent = &nodes[node->parent];
    uint32_t* current = &parent->first_child;
    while (*current != 0) {
        if (*current == idx) {
            *current = node->next_sibling;
            break;
        }
        current = &nodes[*current].next_sibling;
    }

    if (node->data) kfree(node->data);
    memset(node, 0, sizeof(vfs_node_t));
    node_count--;
    return 0;
}

/* ============================================================================
 * Open File
 * ============================================================================ */
int vfs_open(const char* path, uint32_t mode) {
    vfs_node_t* node = vfs_find(path);
    if (!node || node->type != VFS_FILE) return -1;

    /* Find free fd */
    for (int i = 0; i < VFS_MAX_OPEN; i++) {
        if (!fds[i].used) {
            fds[i].used = 1;
            fds[i].node_idx = node - nodes;
            fds[i].position = 0;
            fds[i].mode = mode;
            return i;
        }
    }
    return -1;
}

/* ============================================================================
 * Close File
 * ============================================================================ */
int vfs_close(int fd) {
    if (fd < 0 || fd >= VFS_MAX_OPEN || !fds[fd].used) return -1;
    fds[fd].used = 0;
    return 0;
}

/* ============================================================================
 * Read File
 * ============================================================================ */
int vfs_read(int fd, void* buf, uint32_t size) {
    if (fd < 0 || fd >= VFS_MAX_OPEN || !fds[fd].used) return -1;

    vfs_node_t* node = &nodes[fds[fd].node_idx];
    if (!node->data) return -1;

    uint32_t remaining = node->size - fds[fd].position;
    if (size > remaining) size = remaining;

    memcpy(buf, node->data + fds[fd].position, size);
    fds[fd].position += size;
    return size;
}

/* ============================================================================
 * Write File
 * ============================================================================ */
int vfs_write(int fd, const void* buf, uint32_t size) {
    if (fd < 0 || fd >= VFS_MAX_OPEN || !fds[fd].used) return -1;

    vfs_node_t* node = &nodes[fds[fd].node_idx];
    if (!node->data) return -1;

    if (fds[fd].position + size > 4096) size = 4096 - fds[fd].position;

    memcpy(node->data + fds[fd].position, buf, size);
    fds[fd].position += size;
    if (fds[fd].position > node->size) node->size = fds[fd].position;
    return size;
}

/* ============================================================================
 * Seek File
 * ============================================================================ */
int vfs_seek(int fd, uint32_t offset) {
    if (fd < 0 || fd >= VFS_MAX_OPEN || !fds[fd].used) return -1;
    fds[fd].position = offset;
    return 0;
}

/* ============================================================================
 * List Directory
 * ============================================================================ */
int vfs_list(const char* path, char* buf, uint32_t size) {
    vfs_node_t* node = vfs_find(path);
    if (!node || node->type != VFS_DIRECTORY) return -1;

    uint32_t pos = 0;
    uint32_t child = node->first_child;

    while (child != 0 && pos < size - 64) {
        if (nodes[child].type == VFS_DIRECTORY) {
            pos += sprintf(buf + pos, "[DIR]  %s\n", nodes[child].name);
        } else {
            pos += sprintf(buf + pos, "[FILE] %s\n", nodes[child].name);
        }
        child = nodes[child].next_sibling;
    }

    return pos;
}
