//
//  UMQ_ObserverHook.h
//  UrgentMainQueueKit
//
//  Created by Kyle on 2025/07/12.
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

CF_ASSUME_NONNULL_BEGIN
CF_EXTERN_C_BEGIN

// NOTE: The following method should be called in main thread
BOOL UMQ_AddMainQueueObserverHook() NS_SWIFT_UI_ACTOR;
void UMQ_RemoveMainQueueObserverHook() NS_SWIFT_UI_ACTOR;

/**
 * Executes a block on the main queue with high priority.
 *
 * @discussion This function provides an optimized way to execute blocks on the main queue:
 * - If called from the main queue, the block is executed synchronously
 * - If called from another queue, the block will be executed after the current main queue block.
 *
 * @param block The block to be executed on the main queue
 * @return YES if the block was successfully added to the queue, NO otherwise
 */
BOOL UMQ_AddUrgentMainQueueTasks(dispatch_block_t NS_SWIFT_UI_ACTOR block);

CF_EXTERN_C_END
CF_ASSUME_NONNULL_END
