#ifdef __ANDROID__

/*
 * pthread_atfork compatibility for old Android NDK versions.
 * Modern NDK (r21+) provides pthread_atfork, so we skip this to avoid conflicts.
 * This stub is only needed for very old NDK versions.
 */
#if 0  /* Disabled for modern NDK - prevents duplicate symbol conflicts */

#include <pthread.h>

int pthread_atfork(void (*prepare)(void), void (*parent)(void), void (*child)(void))
{
	(void) prepare;
	(void) parent;
	(void) child;
	return 0;
}

#endif /* Disabled for modern NDK */

#endif
