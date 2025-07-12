//
//  UMQ_ObserverHook.mm
//  UrgentMainQueueKit
//
//  Created by Kyle on 2025/07/12.
//

#import "UMQ_ObserverHook.h"
#import <pthread/pthread_spis.h>
#include <queue>

__attribute__((always_inline))
BOOL umq_dispatch_is_main_queue();
__attribute__((always_inline))
void umq_dispatch_async_on_main_queue(dispatch_block_t block);

// from https://github.com/apple-oss-distributions/libdispatch/blob/bd82a60ee6a73b4eca50af028b48643d51aaf1ea/src/queue_internal.h#L704
typedef struct dispatch_pthread_root_queue_observer_hooks_s {
    void (*queue_will_execute)(dispatch_queue_t queue);
    void (*queue_did_execute)(dispatch_queue_t queue);
} dispatch_pthread_root_queue_observer_hooks_s;

typedef dispatch_pthread_root_queue_observer_hooks_s *dispatch_pthread_root_queue_observer_hooks_t;

// from https://github.com/apple/darwin-xnu/blob/main/libsyscall/os/tsd.h

#if defined(__arm__) || defined(__arm64__)

#if !TARGET_OS_SIMULATOR
__attribute__((always_inline, pure))
static __inline__ void**
_os_tsd_get_base(void)
{
#if defined(__arm__)
    uintptr_t tsd;
    __asm__("mrc p15, 0, %0, c13, c0, 3\n"
                "bic %0, %0, #0x3\n" : "=r" (tsd));
    /* lower 2-bits contain CPU number */
#elif defined(__arm64__)
    uint64_t tsd;
    __asm__("mrs %0, TPIDRRO_EL0\n"
                "bic %0, %0, #0x7\n" : "=r" (tsd));
    /* lower 3-bits contain CPU number */
#endif
    return (void**)(uintptr_t)tsd;
}
#define _os_tsd_get_base()  _os_tsd_get_base()

__attribute__((always_inline))
static __inline__ void*
_os_tsd_get_direct(unsigned long slot)
{
    return _os_tsd_get_base()[slot];
}

__attribute__((always_inline))
static __inline__ int
_os_tsd_set_direct(unsigned long slot, void *val)
{
    _os_tsd_get_base()[slot] = val;
    return 0;
}

#endif

#endif

// from https://github.com/rweichler/substrate/blob/master/include/pthread_machdep.h#L93C1-L93C35
// static const unsigned long dispatch_pthread_root_queue_observer_hooks_key = __PTK_LIBDISPATCH_KEY4;
#define __PTK_LIBDISPATCH_KEY4                24

// avoid static initializers
static std::atomic<BOOL>& getFeatureOpened() {
    static std::atomic<BOOL> open(false);
    return open;
}

#define fastpath(x) (__builtin_expect(bool(x), 1))
#define slowpath(x) (__builtin_expect(bool(x), 0))

static std::queue<dispatch_block_t> *gWaitingQueue = nil;

// A secondary lock for performance considerations
static pthread_mutex_t sWaitingArrayMutex = PTHREAD_MUTEX_INITIALIZER;

// warning: must use __unsafe_unretained to annotate that ARC shouldn't retain queue
void (umq_main_queue_will_execute)(__attribute__((unused)) __unsafe_unretained dispatch_queue_t queue) {
    // do nothing
}

void (umq_main_queue_did_execute)(__attribute__((unused)) __unsafe_unretained dispatch_queue_t queue) {
    
    static std::queue<dispatch_block_t> *gLastWaitingQueue = nil;
    
    // Check if the waiting queue has changed and is not nil (low probability event)
    // This optimization avoids unnecessary locking when no urgent tasks are pending
    if (slowpath(gLastWaitingQueue != gWaitingQueue && gWaitingQueue != nil)) {
        // Queue state has changed, this is a low probability event
        pthread_mutex_lock(&sWaitingArrayMutex);
        
        // Execute one urgent block per regular block execution
        if (!gWaitingQueue->empty()) {
            // Get and execute the next urgent block
            dispatch_block_t block = gWaitingQueue->front();
            block();
            gWaitingQueue->pop();
            
            // Create a new queue instance to avoid potential memory corruption
            // This pattern ensures thread safety by creating a fresh queue copy
            std::queue<dispatch_block_t> *oldWaitingQueue = gWaitingQueue;
            std::queue<dispatch_block_t> *newWaitingQueue = nil;
            
            if (oldWaitingQueue) {
                // Queue is not empty, need to create a copy and deallocate old one
                // Using copy constructor to preserve remaining blocks
                newWaitingQueue = new std::queue<dispatch_block_t>(*oldWaitingQueue);
                delete oldWaitingQueue;
            } else {
                // Create a new empty queue
                newWaitingQueue = new std::queue<dispatch_block_t>();
            }
            
            // Update the global queue pointer
            gWaitingQueue = newWaitingQueue;
            
            // Update the cache tracking to optimize future checks
            if (gWaitingQueue->empty()) {
                // If there are no more blocks to consume, update cache to avoid re-entering
                gLastWaitingQueue = gWaitingQueue;
            } else {
                // Still have blocks pending, keep the old pointer to trigger next execution
                gLastWaitingQueue = oldWaitingQueue;
            }
        } else {
            // Queue is empty, update cache to match current state
            gLastWaitingQueue = gWaitingQueue;
        }
        
        pthread_mutex_unlock(&sWaitingArrayMutex);
    }
}

BOOL UMQ_AddMainQueueObserverHook() {
    // Should in Main Queue(Main Thread)
#if TARGET_OS_SIMULATOR
    if (pthread_getspecific(__PTK_LIBDISPATCH_KEY4) != nil) {
        // Main Thread's GCD Observer shouldn't have any impl
        return NO;
    }
    
    dispatch_pthread_root_queue_observer_hooks_t observer = (dispatch_pthread_root_queue_observer_hooks_t)malloc(sizeof(dispatch_pthread_root_queue_observer_hooks_s));
    observer->queue_did_execute = &umq_main_queue_did_execute;
    observer->queue_will_execute = &umq_main_queue_will_execute;
    
    pthread_setspecific(__PTK_LIBDISPATCH_KEY4, observer);
#else
    if (_os_tsd_get_direct(__PTK_LIBDISPATCH_KEY4) != nil) {
        // Main Thread's GCD Observer shouldn't have any impl
        return NO;
    }
    
    dispatch_pthread_root_queue_observer_hooks_t observer = (dispatch_pthread_root_queue_observer_hooks_t)malloc(sizeof(dispatch_pthread_root_queue_observer_hooks_s));
    observer->queue_did_execute = &umq_main_queue_did_execute;
    observer->queue_will_execute = &umq_main_queue_will_execute;
    
    _os_tsd_set_direct(__PTK_LIBDISPATCH_KEY4, observer);
#endif
    
    std::atomic_store_explicit(&getFeatureOpened(), YES, std::memory_order_release);

    return YES;
}

void UMQ_RemoveMainQueueObserverHook() {
    dispatch_pthread_root_queue_observer_hooks_t observer = nil;
    
#if TARGET_OS_SIMULATOR
    observer = (dispatch_pthread_root_queue_observer_hooks_t)pthread_getspecific(__PTK_LIBDISPATCH_KEY4);
    pthread_setspecific(__PTK_LIBDISPATCH_KEY4, nil);
#else
    observer = (dispatch_pthread_root_queue_observer_hooks_t)_os_tsd_get_direct(__PTK_LIBDISPATCH_KEY4);
    _os_tsd_set_direct(__PTK_LIBDISPATCH_KEY4, nil);
#endif
    if (observer) {
        delete observer;
    }
    std::atomic_store_explicit(&getFeatureOpened(), NO, std::memory_order_release);
}


BOOL UMQ_AddUrgentMainQueueTasks(dispatch_block_t block) {
    // Fast path: if we're already on the main queue, execute immediately
    if (umq_dispatch_is_main_queue()) {
        block();
        return YES;
    }
    
    // Check if the urgent queue feature is enabled
    if (std::atomic_load_explicit(&getFeatureOpened(), std::memory_order_acquire)) {
        // Feature is enabled - use the urgent queue mechanism
        
        // Handle two scenarios:
        // 1. Main thread is busy executing blocks - our urgent block will be inserted 
        //    and executed after the current block finishes via the observer hook
        // 2. Main thread is idle - we need to manually trigger execution by dispatching
        //    to main queue. The first execution wins, subsequent ones return early.
        __block BOOL isFinished = NO;
        dispatch_block_t newBlock = ^() {
            // Race condition guard: only execute once even if called multiple times
            if (isFinished) {
                return;
            }
            isFinished = YES;
            block();
        };
        
        // Critical section: safely update the waiting queue
        pthread_mutex_lock(&sWaitingArrayMutex);
        
        // Save reference to current queue for cleanup
        std::queue<dispatch_block_t> *oldWaitingQueue = gWaitingQueue;
        
        // Create new queue instance to maintain thread safety
        std::queue<dispatch_block_t> *newWaitingQueue = nil;
        if (oldWaitingQueue) {
            // Queue exists, create a copy with existing blocks and cleanup old one
            // Using copy constructor to preserve all pending blocks
            newWaitingQueue = new std::queue<dispatch_block_t>(*oldWaitingQueue);
            delete oldWaitingQueue;
        } else {
            // No existing queue, create a fresh empty one
            newWaitingQueue = new std::queue<dispatch_block_t>();
        }
        
        // Update global queue pointer and add our urgent block
        gWaitingQueue = newWaitingQueue;
        gWaitingQueue->push(newBlock);
        
        pthread_mutex_unlock(&sWaitingArrayMutex);
        
        // Dispatch to main queue as fallback - ensures execution even if main thread is idle
        // If main thread is busy, the observer hook will execute it first
        umq_dispatch_async_on_main_queue(newBlock);
    } else {
        // Feature is disabled, fall back to regular main queue dispatch
        umq_dispatch_async_on_main_queue(block);
    }
    return YES;
}

__attribute__((always_inline))
bool umq_dispatch_is_main_queue() {
    return pthread_main_np() != 0;
}

__attribute__((always_inline))
void umq_dispatch_async_on_main_queue(dispatch_block_t block) {
    if (umq_dispatch_is_main_queue()) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}
