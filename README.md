# Workflow Essentials
Basic components to build workflows.

## Why?
Most mobile applications need workflows. Some need to log users in, others ask their users for information spanning multiple screens.
Even simple workflow may include quite a few steps and quickly become hard to maintain. For example, login flow might include:
- Checking the keychain for existing login information such as authentication token;
- Presenting login screen itself;
- Presenting sign-up screen for new users;
- Sending a data requests (login request with user name and password, authentication token validation request, sign up requests, and so on);
- Processing errors - retrying, constraining retry count for failed logins but not network problems, and so on;
- Performing two-factor authentication steps;
- and there may be more steps involved.

These individual steps may be connected in many different ways (different errors in the same step lead to different subsequent steps for example).

**Workflow Essentials** aims to simplify the implementation of workflows by providing basic classes for a workflow, individual steps and transitions.

#### How is it different from `NSOperationQueue`?
In a few ways:
- Operations are not thread- or queue-bound, and can execute on different threads based on what operation requests.
- In addition to dependencies there are other types of connections that make it possible to express more complex processes.
- Connections may refer to operations by reference or by name which makes it easier to write modular, loosely coupled code.
- Operations are much easier to implement (no KVO involved, just do the work and invoke completion when done).

## Getting Started
Starting with Workflow Essentials:
- Include a precompiled framework OR add individual files to your project.
- Add `-ObjC` linker flag.

**Workflow Essentials** only depend on `Foundation` framework which should already be included.

## Definitions
**Workflow Essentials** define **workflow** as a set of operations that execute in an order defined by connections.
A workflow consists of:
- **Operations** - individual work items. Operations may be synchronous or asynchronous and can request to be executed on the main thread or in the background. An operation must produce a result in the end (which may be empty).
- **Connections** - either dependencies or segues. 
 - A dependency defines that one operation (source) must complete before another (target) can start. When a dependency target has multiple dependencies, all its dependency sources must complete before the target can start. Dependencies are good for defining prerequisites - for example, data must be loaded before its processing can start.
 - A segue defines that a completion of one operation (source) leads to another operation (target). Segue is different from a dependency in two ways: first, it may have a condition; and second, when multiple segues lead to the same target, one or more need to be activated (source completed and condition evaluated to `YES`) for target to start. A condition is a predicate evaluated with operation result as an argument. If a condition is not defined, it is the equivalent of a predicate that always evaluates to `YES`. Segues are good for defining sequences and conditional paths - for example, uniform error handler for a number of different operations.

## Performing a Workflow
To perform a workflow, create a workflow instance, add operations and connections to it, and start the workflow.

### Note on Thread Safety
Workflow and Operations are thread safe, which means:
- operations and connections can be added to a workflow from any thread or from multiple threads;
- workflow can be started from any thread;
- workflow properties can be added from any thread;
- operations can invoke completion method (subclass) or block (block operation) on any thread;
- operation properties (name, state, result) can be accessed from any thread;
- workflow context is also thread-safe with regards to storing and accessing values and reading operation results.

*Caution I:* connection descriptions are not thread safe, and should not be shared between threads. Workflow will copy all connections that are added to it to avoid modifications and thread issues.

*Caution II:* operation code (anything implemented in a subclass, or block code for block operations) must be written with thread safety in mind.

### Create Workflow
Make an instance of a workflow by providing:
- Optional context class, which must be a subclass of `WEWorkflowContext`. Custom subclass may be used by the operations to store and access more specific information than just key-value store provided by the default context class. If context class is not provided, default context will be created.
- Maximum number of concurrent operations. Value of `0` means no limit.
- Optional delegate and delegate dispatch queue. If delegate and queue are provided, workflow will notify delegate of various events, such as workflow completion or failure, dispatching them to the specified queue.

``` Objective-C
WEWorkflow *workflow = [[WEWorkflow alloc] initWithContextClass:nil maximumConcurrentOperations:3];
```

### Add operations
An operation can be created by either subclassing `WEOperation` class, or using a provided convenience subclass `WEBlockOperation`.

#### Subclassing `WEOperation`
At a minimum, an operation subclass must override the `start` method, which will be invoked when a workflow starts the operation. It also must call `completeWithResult:` when the operation work is done - synchronously or asynchronously.

In addition, an operation can override `requiresMainThread` method and declare if it requires to be run on the main thread. Default return value is `NO` which makes the operation run in the background.

Example:

``` Objective-C
@interface WEOperationSimpleSubclass : WEOperation<NSString *>
@end

@implementation WEOperationSimpleSubclass

- (void)start
{
    dispatch_async(dispatch_get_main_queue(), ^{
        WEOperationResult<NSString *> *result = [[WEOperationResult alloc] initWithResult:@"Some result"];
        [self completeWithResult:result];
    });
}

@end
```

#### Using block operation
Block operation covers most simple cases of operations where work can be expressed as a block that invokes a callback when the work is complete. It eliminates the need for many trivial operation subclasses.

Block operation takes in an optional operation name, a boolean value indicating if an operation should run on the main thread, and the block itself.

Note that block can invoke completion synchronously or asynchronously, and on any thread. 

Example:
``` Objective-C
WEBlockOperation<NSString *> *blockOperation = [[WEBlockOperation alloc] initWithName:nil requiresMainThread:YES block:^(void (^ _Nonnull completion)(WEOperationResult<NSString *> * _Nonnull)) {
    // DO WORK
    WEOperationResult<NSString *> *result = ...;
    completion(result);
}];
```

### Add connections
Dependency:
``` Objective-C
WEDependencyDescription *firstDependency = [[WEDependencyDescription alloc] init];
firstDependency.sourceOperationName = @"firstName";
firstDependency.targetOperationName = @"secondName";
[workflow addDependency:firstDependency];

WEOperation *o1 = ..., *o2 = ...; 
WEDependencyDescription *secondDependency = [[WEDependencyDescription alloc] init];
secondDependency.sourceOperation = o1;
secondDependency.targetOperation = o2;
[workflow addDependency:secondDependency];
```

Segue:
``` Objective-C
WESegueDescription *errorSegue = [[WESegueDescription alloc] init];
errorSegue.condition = [NSPredicate predicateWithBlock:^BOOL(WEOperationResult * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
    return evaluatedObject.isFailed;
}];
errorSegue.sourceOperationName = @"firstName";
errorSegue.targetOperationName = @"secondName";

[workflow addSegue:errorSegue];
```

### Start a Workflow

``` Objective-C
WEWorkflow *workflow = ...; 
[workflow start];
```

## Plans for future versions:
- Add more types of connections. Specifically, plan to add a semaphore, which will prevent an operation from running when certain condition is met - for example, another operation is running (can be used for UI operations that ar mutually exclusive) or another operation had failed (don't attempt to run more operations if it's known that workflow as a whole failed).
- Improve error checks, like loop detection, inside a workflow.
- Implement resettable operations, which could be re-run, allowing the workflow to define a loop.
- Implement sequential workflow, which would implement operations one by one and will be able to go back to any point in that flow. Represents, for example, a sequence of dialogs with a submission in the end, where submission failure would send a user back to the incorrectly filled page.
- Add an ability for an operation to stack up work items in front of itself during preparation.
- ... and more.

## Credits
**Workflow Essentials** uses [OCMock](http://ocmock.org), a great framework for creating mocks in all kinds of tests.

## License
Workflow Essentials are released under the BSD license. See LICENSE for details.
