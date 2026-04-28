#ifndef PROOT_QUEUE_COMPAT_H
#define PROOT_QUEUE_COMPAT_H

#if defined(__has_include)
#    if __has_include(<sys/queue.h>)
#        include <sys/queue.h>
#    elif __has_include(<bsd/sys/queue.h>)
#        include <bsd/sys/queue.h>
#    else
#        error "No sys/queue.h-compatible header found"
#    endif
#else
#    include <sys/queue.h>
#endif

#endif /* PROOT_QUEUE_COMPAT_H */
