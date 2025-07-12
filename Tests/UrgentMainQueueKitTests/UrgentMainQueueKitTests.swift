import Testing
import UrgentMainQueueKit

@MainActor
struct UrgentMainQueueKitTests {
    @Test
    func withoutHook() {
        for index in 0 ..< 500 {
            DispatchQueue.main.async {
                print("Greeting from \(index)")
            }
        }
        DispatchQueue.main.async {
            print("Urgent task")
        }
        // Expected output
        // Greeting from 0
        // ...
        // Greeting from 499
        // Urgent task
    }
    
    
    @Test
    func withHookInMainThread() {
        UMQ_AddMainQueueObserverHook()
        for index in 0 ..< 500 {
            DispatchQueue.main.async {
                print("Greeting from \(index)")
            }
        }
        UMQ_AddUrgentMainQueueTasks {
            print("Urgent task")
        }
        UMQ_RemoveMainQueueObserverHook()
        // Expected output
        // Urgent task
        // Greeting from 0
        // ...
        // Greeting from 499
    }

    @Test
    func withHookInMainThread2() {
        UMQ_AddMainQueueObserverHook()
        DispatchQueue.main.async {
            print("1: Current main queue task begin")
            DispatchQueue.main.async {
                print("3: Non-Urgent task execute")
            }
            // cut in line and execute first after the current main queue task if it is not main thread otherwise execute immediately
            UMQ_AddUrgentMainQueueTasks {
                print("4: Urgent task execute")
            }
            print("1. Current main queue task end")
        }
        DispatchQueue.main.async {
            print("2: Normal task")
        }

        UMQ_RemoveMainQueueObserverHook()
        // Expected output
        // 1. Current main queue task begin
        // 4. Urgent task execute
        // 1. Current main queue task end
        // 2. Normal task
        // 3. Non-Urgent task execute

        // If we replace `UMQ_AddUrgentMainQueueTasks` with `DispatchQueue.main.async`, the output will be:
        // 1 2 3 4
    }
}
