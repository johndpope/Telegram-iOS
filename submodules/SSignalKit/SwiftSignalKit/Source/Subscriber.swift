import Foundation

public final class Subscriber<T, E> {
    var subscription: Timelane.Subscription
    private var next: ((T) -> Void)!
    private var error: ((E) -> Void)!
    private var completed: (() -> Void)!
    
    private var lock = pthread_mutex_t()
    private var terminated = false
    internal var disposable: Disposable!
    
    public init(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) {
        self.subscription = Timelane.Subscription(name: String(describing: T.self), logger: Timelane.defaultLogger)
     
        self.subscription.begin()
        self.next = next
        self.error = error
        self.completed = completed
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
//        self.subscription.end(state: .completed)
        var freeDisposable: Disposable?
        pthread_mutex_lock(&self.lock)
        if let disposable = self.disposable {
            freeDisposable = disposable
            self.disposable = nil
        }
        pthread_mutex_unlock(&self.lock)
        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }
        
        pthread_mutex_destroy(&self.lock)
    }
    
    internal func assignDisposable(_ disposable: Disposable) {
        self.subscription.event(value: .value("start -> assignDisposable"))
        var dispose = false
        pthread_mutex_lock(&self.lock)
        if self.terminated {
            dispose = true
        } else {
            self.disposable = disposable
        }
        pthread_mutex_unlock(&self.lock)
        
        if dispose {
            disposable.dispose()
            self.subscription.end(state: .completed)
        }
    }
    
    internal func markTerminatedWithoutDisposal() {
        self.subscription.event(value: .value("markTerminatedWithoutDisposal"))
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            self.terminated = true
            self.next = nil
            self.error = nil
            self.completed = nil
        }
        pthread_mutex_unlock(&self.lock)
    }
    
    public func putNext(_ next: T) {
        self.subscription.event(value: .value("putNext"))
        
        var action: ((T) -> Void)! = nil
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.next
        }
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action(next)
        }
    }
    
    public func putError(_ error: E) {
        self.subscription.event(value: .value("putError"))
        
        var action: ((E) -> Void)! = nil
        
        var disposeDisposable: Disposable?
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.error
            self.next = nil
            self.error = nil
            self.completed = nil;
            self.terminated = true
            disposeDisposable = self.disposable
            self.disposable = nil
            
        }
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action(error)
        }
        
        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
            self.subscription.end(state: .completed)
        }
    }
    
    public func putCompletion() {
        self.subscription.event(value: .value("putCompletion"))
        var action: (() -> Void)! = nil
        
        var disposeDisposable: Disposable? = nil
        
        var next: ((T) -> Void)?
        var error: ((E) -> Void)?
        var completed: (() -> Void)?
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.completed
            next = self.next
            self.next = nil
            error = self.error
            self.error = nil
            completed = self.completed
            self.completed = nil
            self.terminated = true
            
            disposeDisposable = self.disposable
            self.disposable = nil
        }
        pthread_mutex_unlock(&self.lock)
        
        if let next = next {
            withExtendedLifetime(next, {})
        }
        if let error = error {
            withExtendedLifetime(error, {})
        }
        if let completed = completed {
            withExtendedLifetime(completed, {})
        }
        
        if action != nil {
            action()
        }
        
        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
            self.subscription.end(state: .completed)
        }
    }
}
