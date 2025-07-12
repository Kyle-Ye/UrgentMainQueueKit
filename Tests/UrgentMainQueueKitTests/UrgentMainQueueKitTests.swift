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
}
