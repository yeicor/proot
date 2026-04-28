#ifndef PROOT_ASHMEM_COMPAT_H
#define PROOT_ASHMEM_COMPAT_H

#if defined(__has_include)
#    if __has_include(<linux/ashmem.h>)
#        include <linux/ashmem.h>
#    endif
#endif

#ifndef ASHMEM_NAME_LEN
#    include <sys/ioctl.h>

#    define ASHMEM_NAME_LEN 256
#    define ASHMEM_SET_NAME _IOW('a', 1, char[ASHMEM_NAME_LEN])
#    define ASHMEM_SET_SIZE _IOW('a', 3, size_t)
#    define ASHMEM_GET_SIZE _IO('a', 4)
#endif

#endif /* PROOT_ASHMEM_COMPAT_H */
