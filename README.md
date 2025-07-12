# UrgentMainQueueKit

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKyle-Ye%2FUrgentMainQueueKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Kyle-Ye/UrgentMainQueueKit) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FKyle-Ye%2FUrgentMainQueueKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Kyle-Ye/UrgentMainQueueKit)

## Overview

UrgentMainQueueKit provides a mechanism to execute tasks on the main queue with higher priority than regular `dispatch_async` calls. This is achieved by hooking into GCD's internal observer system to intercept and prioritize urgent tasks.

> ⚠️ **Important**: This library uses private GCD APIs and may be subject to changes in future iOS/macOS versions. Use with caution in production applications.

## Background

In large-scale applications, it's common for developers to accumulate numerous low-priority tasks on the main queue. When a critical network request completes and you need to deliver results to the UI thread using `DispatchQueue.main.async`, you may experience noticeable latency due to previously queued non-essential operations waiting in the FIFO queue.

UrgentMainQueueKit solves this problem by providing a GCD hook mechanism that breaks the traditional first-in-first-out execution order. It allows your high-priority tasks to "cut in line" and execute immediately, ensuring responsive user interfaces even when the main queue is congested with background work.

## Features

- Priority Execution: Urgent tasks are executed before regular main queue tasks
- Thread Safety: Uses proper synchronization mechanisms to ensure thread safety
- Automatic Fallback: Falls back to regular main queue dispatch when hooks are not available
- Performance Optimized: Minimal overhead when no urgent tasks are pending

## Requirements

- Swift 6.0+
- Xcode 16.0+

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

### Xcode

1. Open your project in Xcode
2. Go to File → Add Package Dependencies
3. Enter the repository URL: `https://github.com/Kyle-Ye/UrgentMainQueueKit.git`
4. Select your desired version and add to your target

## Usage

### Basic Usage

```swift
import UrgentMainQueueKit

class MyViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Enable the urgent queue system (typically in app launch)
        let success = UMQ_AddMainQueueObserverHook()
        guard success else {
            print("Failed to install main queue observer hook")
            return
        }
    }
    
    func handleNetworkResponse() {
        // Execute urgent UI updates
        UMQ_AddUrgentMainQueueTasks { [weak self] in
            self?.updateCriticalUI()
        }
    }
    
    func updateCriticalUI() {
        // Your urgent UI update code here
        print("Urgent task executed!")
    }
    
    deinit {
        // Clean up when appropriate (typically in app termination)
        UMQ_RemoveMainQueueObserverHook()
    }
}
```

### Advanced Usage

```swift
import UrgentMainQueueKit

class UrgentTaskManager {
    private var isHookInstalled = false
    
    func setupUrgentQueue() {
        guard !isHookInstalled else { return }
        
        if UMQ_AddMainQueueObserverHook() {
            isHookInstalled = true
            print("Urgent queue system enabled")
        } else {
            print("Warning: Failed to install urgent queue hooks")
        }
    }
    
    func executeUrgentTask(_ task: @escaping () -> Void) {
        guard isHookInstalled else {
            // Fallback to regular dispatch
            DispatchQueue.main.async(execute: task)
            return
        }
        
        UMQ_AddUrgentMainQueueTasks(task)
    }
    
    func cleanup() {
        guard isHookInstalled else { return }
        
        UMQ_RemoveMainQueueObserverHook()
        isHookInstalled = false
    }
}
```

### Use Cases

- Critical UI Updates: When you need to ensure UI updates happen immediately
- User Input Response: Prioritizing user interaction responses
- Animation Smoothness: Ensuring animation frames are processed with high priority
- Real-time Data Updates: When displaying time-sensitive information
- Network Response Handling: Prioritizing UI updates from important network requests

## How It Works

The library works by:

1. Hook Installation: Installs observer hooks into GCD's internal dispatch system
2. Task Queuing: Maintains a queue of urgent tasks that need priority execution
3. Priority Execution: When the main queue finishes executing a regular task, urgent tasks are processed first
4. Automatic Cleanup: Properly manages memory and thread safety

## Performance

- Minimal Overhead: Near-zero cost when no urgent tasks are pending
- Optimized Checks: Uses fast-path optimizations to avoid unnecessary work
- Memory Efficient: Proper cleanup and memory management

## Important Considerations

### ⚠️ Limitations and Warnings

- Private API Usage: This library relies on GCD internals that may change
- iOS/macOS Only: Does not work on other platforms
- Main Thread Only: Hook installation must happen on the main thread
- Production Use: Test thoroughly before using in production applications
- Memory Management: Always call `UMQ_RemoveMainQueueObserverHook()` during cleanup

### Best Practices

1. Sparing Use: Only use for truly urgent tasks to avoid performance degradation
2. Error Handling: Always check the return value of `UMQ_AddMainQueueObserverHook()`
3. Cleanup: Properly remove hooks when they're no longer needed
4. Testing: Test on actual devices, not just simulators

## Troubleshooting

### Hook Installation Fails

```swift
if !UMQ_AddMainQueueObserverHook() {
    // Handle gracefully - fall back to regular dispatch
    print("Urgent queue hooks not available, using fallback")
}
```

### Memory Issues

Ensure you're calling `UMQ_RemoveMainQueueObserverHook()` during app termination or when the feature is no longer needed.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## Credits

The core dispatch hook implementation is from [ChengzhiHuang](https://github.com/ChengzhiHuang). This project serves as a Swift Package Manager wrapper for easy integration.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

