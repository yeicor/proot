#ifdef __ANDROID__

#include <pthread.h>

/*
 * Newer NDK static libc archives reference pthread_atfork without
 * shipping a matching static definition. Provide a no-op fallback so
 * fully static release builds can still link.
 */
int pthread_atfork(void (*prepare)(void), void (*parent)(void), void (*child)(void))
{
	(void) prepare;
	(void) parent;
	(void) child;
	return 0;
}

#endif
