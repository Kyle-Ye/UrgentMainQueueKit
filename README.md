# UrgentMainQueueKit

A Swift Package Manager wrapper for high-priority main queue task execution on iOS/macOS.

## Overview

UrgentMainQueueKit provides a mechanism to execute tasks on the main queue with higher priority than regular `dispatch_async` calls. This is achieved by hooking into GCD's internal observer system to intercept and prioritize urgent tasks.

## Features

- **Priority Execution**: Urgent tasks are executed before regular main queue tasks
- **Thread Safety**: Uses proper synchronization mechanisms to ensure thread safety
- **Automatic Fallback**: Falls back to regular main queue dispatch when hooks are not available
- **Performance Optimized**: Minimal overhead when no urgent tasks are pending

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/Kyle-Ye/UrgentMainQueueKit.git", from: "1.0.0"),
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "UrgentMainQueueKit", package: "UrgentMainQueueKit"),
    ]
),
```

## Usage

### Basic Usage

```swift
import UrgentMainQueueKit

// Enable the urgent queue system
UMQ_AddMainQueueObserverHook()

// Execute urgent tasks
UMQ_AddUrgentMainQueueTasks {
    // Your urgent UI update code here
    print("Urgent task executed!")
}

// Disable when no longer needed
UMQ_RemoveMainQueueObserverHook()
```

### Use Cases

- **Critical UI Updates**: When you need to ensure UI updates happen immediately
- **User Input Response**: Prioritizing user interaction responses
- **Animation Smoothness**: Ensuring animation frames are processed with high priority
- **Real-time Data Updates**: When displaying time-sensitive information

## How It Works

The library works by:

1. **Hook Installation**: Installs observer hooks into GCD's internal dispatch system
2. **Task Queuing**: Maintains a queue of urgent tasks that need priority execution
3. **Priority Execution**: When the main queue finishes executing a regular task, urgent tasks are processed first
4. **Automatic Cleanup**: Properly manages memory and thread safety

## Performance

- **Minimal Overhead**: Near-zero cost when no urgent tasks are pending
- **Optimized Checks**: Uses fast-path optimizations to avoid unnecessary work
- **Memory Efficient**: Proper cleanup and memory management

## Credits

The core dispatch hook implementation is from [ChengzhiHuang](https://github.com/ChengzhiHuang). This project serves as a Swift Package Manager wrapper for easy integration.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

