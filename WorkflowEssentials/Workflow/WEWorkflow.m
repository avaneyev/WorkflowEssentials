//
//  WEWorkflow.m
//  Workflow Essentials
//
//  Created by Anton Vaneev.
//  Copyright (c) 2016-present, Anton Vaneev. All rights reserved.
//
//  Distributed under BSD license. See LICENSE for details.
//

#import <WorkflowEssentials/WEWorkflow.h>

#import <WorkflowEssentials/WEDependencyDescription.h>
#import <WorkflowEssentials/WEOperation.h>
#import <WorkflowEssentials/WESegueDescription.h>
#import <WorkflowEssentials/WEWorkflowContext.h>

#import <pthread.h>
#import "WETools.h"
#import "WEWorkflowContext+Private.h"

typedef enum
{
    WEWorkflowInactive,
    WEWorkflowActive,
    WEWorkflowComplete
} WEWorkflowState;

NSString *const _Nonnull WEWorkflowErrorDomain = @"WEWorkflowErrorDomain";
NSInteger const WEWorkflowInvalidDependency = -10001;
NSInteger const WEWorkflowDependencyCycle = -10002;
NSInteger const WEWorkflowDeadlocked = -10003;
NSInteger const WEWorkflowDuplicateNames = -10004;
NSInteger const WEWorkflowInvalidSegue = -10005;

@class _WEOperationState;

@interface _WEOutgoingSegue : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSegue:(nonnull WESegueDescription *)segue targetState:(nonnull _WEOperationState *)targetState;
@end

@implementation _WEOutgoingSegue
{
@package
    __unsafe_unretained _WEOperationState *_targetState;
    WESegueDescription *_segue;
}

- (instancetype)initWithSegue:(WESegueDescription *)segue targetState:(_WEOperationState *)targetState
{
    WEAssert(segue != nil);
    WEAssert(targetState != nil);
    
    if (self = [super init])
    {
        _targetState = targetState;
        _segue = segue;
    }
    return self;
}

@end

@interface _WEOperationState : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithOperation:(nonnull WEOperation *)operation NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, assign, nonnull) WEOperation *operation;

@end

@implementation _WEOperationState
{
@package
    __unsafe_unretained WEOperation *_operation;
    
    // Dependencies are unordered, all dependencies need to be fulfilled before their target can execute.
    NSHashTable<_WEOperationState *> *_dependsOn;
    NSHashTable<_WEOperationState *> *_dependents;
    NSUInteger _completedDependsOnOperations;
    
    // Segues are ordered.
    // Outgoing segues fire in the order they were added, except for segues targeting operations that have
    // unfulfilled dependencies.
    // Incoming segues fire immediately if the operation does not have unfulfilled dependencies, otherwise
    // they fire in the order they were activated (in the order their sources completed).
    NSMutableArray<_WEOutgoingSegue *> *_outgoingSegues;
    BOOL _hasIncomingSegues;
    NSMutableArray<WESegueDescription *> *_activatedIncomingSegues;
}

@synthesize operation = _operation;

- (instancetype)initWithOperation:(WEOperation *)operation
{
    WEAssert(operation != nil);
    
    if (self = [super init])
    {
        _operation = operation;
    }
    return self;
}

@end

@implementation WEWorkflow
{
    WEWorkflowContext *_context;
    NSUInteger _maximumConcurrentOperations;
    
    __weak id<WEWorkflowDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    
    pthread_mutex_t _operationMutex;
    WEWorkflowState _state;
    NSError *_error;
    NSMutableArray<WEOperation *> *_operations;
    NSMutableArray<WEDependencyDescription *> *_dependencies;
    NSMutableArray<WESegueDescription *> *_segues;

    // Internal queue and state that is only accessed on that queue
    dispatch_queue_t _workflowInternalQueue;
    BOOL _isFailedInternal;
    NSArray<_WEOperationState *> *_allOperationStates;
    NSUInteger _totalCompletedOperations;
    NSMutableOrderedSet<_WEOperationState *> *_operationsReadyToExecute;
    NSMutableSet<_WEOperationState *> *_activeOperations;
    BOOL _hasSeguesInternal;
}

- (instancetype)init
{
    return [self initWithContextClass:nil maximumConcurrentOperations:0];
}

- (instancetype)initWithContextClass:(Class)contextClass
         maximumConcurrentOperations:(NSUInteger)maximumConcurrentOperations
{
    return [self initWithContextClass:contextClass maximumConcurrentOperations:maximumConcurrentOperations delegate:nil delegateQueue:nil];
}

- (instancetype)initWithContextClass:(Class)contextClass
         maximumConcurrentOperations:(NSUInteger)maximumConcurrentOperations
                            delegate:(id<WEWorkflowDelegate>)delegate
                       delegateQueue:(dispatch_queue_t)delegateQueue
{
    Class defaultClass = [WEWorkflowContext class];
    if (contextClass != nil && contextClass != defaultClass && ![contextClass isSubclassOfClass:defaultClass])
    {
        THROW_INVALID_PARAM(contextClass, nil);
    }
    
    if ((delegate != nil) ^ (delegateQueue != nil))
    {
        THROW_INVALID_PARAMS( @{ NSLocalizedDescriptionKey: @"Must provide both delegate and queue, or neither delegate nor queue" });
    }
    
    if (self = [super init])
    {
        if (contextClass == nil) contextClass = defaultClass;
        _context = [[contextClass alloc] initWithWorkflow:self];
        
        _maximumConcurrentOperations = (maximumConcurrentOperations > 0) ? maximumConcurrentOperations : INT32_MAX;
        
        _delegate = delegate;
        _delegateQueue = delegateQueue;
        
        pthread_mutex_init(&_operationMutex, NULL);
        _operations = [NSMutableArray new];
        _dependencies = [NSMutableArray new];
        _segues = [NSMutableArray new];
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_operationMutex);
}


#pragma mark - Properties

@synthesize context = _context;

- (BOOL)isActive
{
    BOOL isActive = NO;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    isActive = _state == WEWorkflowActive;
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return isActive;
}

- (BOOL)isCompleted
{
    BOOL isCompleted = NO;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    isCompleted = _state == WEWorkflowComplete;
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return isCompleted;
}

- (BOOL)isFailed
{
    BOOL isFailed = NO;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    isFailed = _state == WEWorkflowComplete && _error != nil;
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return isFailed;
}

- (NSError *)error
{
    NSError *error;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    error = _error;
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return error;
}

- (NSArray<WEOperation *> *)operations
{
    NSArray *operationsCopy;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
        operationsCopy = [_operations copy];
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return operationsCopy;
}

- (NSUInteger)operationCount
{
    NSUInteger count = 0;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
        count = _operations.count;
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    return count;
}


#pragma mark - Operation Management

- (void)addOperation:(WEOperation *)operation
{
    // Never allow adding an operation as stand-alone while workflow is in progress, because it may be
    // picked up and start before any connections are added. Other means of adding operations should be used then.
    ENTER_CRITICAL_SECTION(self, _operationMutex)
   
    if (_state != WEWorkflowInactive)
    {
        THROW_INCONSISTENCY(@{ NSLocalizedDescriptionKey: @"Cannot directly add an operation after the workflow had started." });
    }
    
    if ([_operations containsObject:operation])
    {
        THROW_INVALID_PARAM(operation, @{ NSLocalizedDescriptionKey: @"Duplicate operation" });
    }
    
    [_operations addObject:operation];
    
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
}

- (void)_verifyConnectionBeforeAdding:(WEConnectionDescription *)connection
{
    if (_state != WEWorkflowInactive)
    {
        THROW_INCONSISTENCY(@{ NSLocalizedDescriptionKey: @"Cannot directly add a dependency after the workflow had started." });
    }
    
    // Verify that explicitly specified operations belong to the workflow
    WEOperation *sourceOperation = connection.sourceOperation;
    if (sourceOperation != nil && ![_operations containsObject:sourceOperation])
    {
        THROW_INVALID_PARAM(dependency, @{ NSLocalizedDescriptionKey: @"Source operation does not belong to the workflow" });
    }
    WEOperation *targetOperation = connection.targetOperation;
    if (targetOperation != nil && ![_operations containsObject:targetOperation])
    {
        THROW_INVALID_PARAM(dependency, @{ NSLocalizedDescriptionKey: @"Target operation does not belong to the workflow" });
    }
}

- (void)addDependency:(WEDependencyDescription *)dependency
{
    if (dependency == nil) THROW_INVALID_PARAM(dependency, @{ NSLocalizedDescriptionKey: @"Dependency not specified" });
    if (dependency.sourceOperation == nil && dependency.sourceOperationName == nil) THROW_INVALID_PARAM(dependency, @{ NSLocalizedDescriptionKey: @"Source operation not specified" });
    if (dependency.targetOperation == nil && dependency.targetOperationName == nil) THROW_INVALID_PARAM(dependency, @{ NSLocalizedDescriptionKey: @"Target operation not specified" });
    if (dependency.targetOperation != nil && dependency.targetOperation == dependency.sourceOperation) THROW_INVALID_PARAM(dependency, @{ NSLocalizedDescriptionKey: @"Source and target are the same" });
    if (dependency.targetOperationName != nil && dependency.targetOperationName == dependency.sourceOperationName) THROW_INVALID_PARAM(dependency, @{ NSLocalizedDescriptionKey: @"Source and target are the same" });
    
    ENTER_CRITICAL_SECTION(self, _operationMutex)

    [self _verifyConnectionBeforeAdding:dependency];
    [_dependencies addObject:[dependency copy]];

    LEAVE_CRITICAL_SECTION(self, _operationMutex)
}

- (void)addSegue:(nonnull WESegueDescription *)segue
{
    if (segue == nil) THROW_INVALID_PARAM(segue, @{ NSLocalizedDescriptionKey: @"Segue not specified" });
    if (segue.sourceOperation == nil && segue.sourceOperationName == nil) THROW_INVALID_PARAM(segue, @{ NSLocalizedDescriptionKey: @"Source operation not specified" });
    if (segue.targetOperation == nil && segue.targetOperationName == nil) THROW_INVALID_PARAM(dependency, @{ NSLocalizedDescriptionKey: @"Target operation not specified" });
    if (segue.targetOperation != nil && segue.targetOperation == segue.sourceOperation) THROW_INVALID_PARAM(segue, @{ NSLocalizedDescriptionKey: @"Source and target are the same" });
    if (segue.targetOperationName != nil && segue.targetOperationName == segue.sourceOperationName) THROW_INVALID_PARAM(segue, @{ NSLocalizedDescriptionKey: @"Source and target are the same" });

    ENTER_CRITICAL_SECTION(self, _operationMutex)
    
    [self _verifyConnectionBeforeAdding:segue];
    [_segues addObject:[segue copy]];
    
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
}


#pragma mark - Running the workflow

- (void)start
{
    BOOL start = NO;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    if (_state == WEWorkflowInactive)
    {
        _workflowInternalQueue = dispatch_queue_create("we-workflow.queue", DISPATCH_QUEUE_SERIAL);
        _state = WEWorkflowActive;
        start = YES;
    }
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    
    // dispatch outside of a critical section to avoid possible contention over the lock if queue qob is picked up quickly.
    if (start)
    {
        dispatch_async(_workflowInternalQueue, ^{
            [self _prepareAndStartWorkflow];
        });
    }
}

#pragma mark - Workflow internals

- (void)_prepareAndStartWorkflow
{
    // Very first version - just perform operations in order they were added.
    // Will change later.
    
    NSArray<WEOperation *> *operations;
    NSArray<WEDependencyDescription *> *dependencies;
    NSArray<WESegueDescription *> *segues;
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    
    WEAssert(_state == WEWorkflowActive);
    
    operations = [_operations copy];
    dependencies = [_dependencies copy];
    segues = [_segues copy];
    LEAVE_CRITICAL_SECTION(self, _operationMutex)
    
    if (operations.count == 0)
    {
        [self _completeWorkflow];
    }
    else
    {
        _isFailedInternal = NO;
        NSError *error = [self _buildDependencyGraphWithOperations:operations dependencies:dependencies segues:segues];
        if (error == nil)
        {
            _totalCompletedOperations = 0;
            _activeOperations = [[NSMutableSet alloc] initWithCapacity:_maximumConcurrentOperations];
            [self _checkAndStartReadyOperation];
        }
        else
        {
            [self _completeWorkflowWithError:error];
        }
    }
}

static _WEOperationState *_FindOperationState(
                                              NSMutableArray<_WEOperationState *> *operationStates,
                                              NSMutableDictionary<NSString *, _WEOperationState *> *namedOperations,
                                              WEOperation *operation,
                                              NSString *operationName
                                              )
{
    _WEOperationState *state;
    if (operation == nil)
    {
        state = [namedOperations objectForKey:operationName];
    }
    else
    {
        for (_WEOperationState *otherState in operationStates)
        {
            if (otherState->_operation == operation)
            {
                state = otherState;
                break;
            }
        }
    }
    return state;
}

static inline NSHashTable<_WEOperationState *> *_CreateDependencyHashTable()
{
    NSPointerFunctionsOptions options = NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality;
    return [[NSHashTable alloc] initWithOptions:options capacity:1];
}

- (NSError *)_buildDependencyGraphWithOperations:(NSArray<WEOperation *> *)operations dependencies:(NSArray<WEDependencyDescription *> *)dependencies segues:(NSArray<WESegueDescription *> *)segues
{
    NSError *error = nil;
    NSMutableArray<_WEOperationState *> *operationStates = [[NSMutableArray alloc] initWithCapacity:operations.count];
    NSMutableDictionary<NSString *, _WEOperationState *> *namedOperations = [NSMutableDictionary new];
    NSString *name;
    NSMutableOrderedSet<_WEOperationState *> *independentOperations;
    
    // Process operations, make vertices
    for (WEOperation *operation in operations)
    {
        _WEOperationState *state = [[_WEOperationState alloc] initWithOperation:operation];
        [operationStates addObject:state];
        
        name = operation.name;
        if (name != nil)
        {
            if ([namedOperations objectForKey:name] != nil)
            {
                NSString *reason = [NSString stringWithFormat:@"Duplicate operation name \"%@\": operations [%@, %@]", name, operation, [namedOperations objectForKey:name]];
                error = [NSError errorWithDomain:WEWorkflowErrorDomain code:WEWorkflowDuplicateNames userInfo:@{ NSLocalizedDescriptionKey: reason }];
                break;
            }
            [namedOperations setObject:state forKey:name];
        }
    }
    
    // Process dependencies, first kind of nodes.
    // See note next to ivar declaration describing dependency data structure.
    if (error == nil)
    {
        _allOperationStates = [operationStates copy];
        independentOperations = [[NSMutableOrderedSet alloc] initWithArray:operationStates];
        
        for (WEDependencyDescription *dependency in dependencies)
        {
            _WEOperationState *fromState = _FindOperationState(operationStates, namedOperations, dependency.sourceOperation, dependency.sourceOperationName);
            _WEOperationState *toState = _FindOperationState(operationStates, namedOperations, dependency.targetOperation, dependency.targetOperationName);
            
            if (fromState == nil || toState == nil || fromState == toState)
            {
                NSString *reason = [NSString stringWithFormat:@"Invalid dependency %@: from %@ to %@.", dependency, fromState ? @"valid" : @"invalid", toState ? @"valid" : @"invalid"];
                error = [NSError errorWithDomain:WEWorkflowErrorDomain code:WEWorkflowInvalidDependency userInfo:@{ NSLocalizedDescriptionKey: reason }];
                break;
            }
            
            // Check if dependency is not a duplicate, if it is - ignore
            if (![fromState->_dependents containsObject:toState])
            {
                if ([toState->_dependents containsObject:fromState])
                {
                    // Deadlock, create an error and stop
                    NSString *reason = [NSString stringWithFormat:@"Dependency %@ will introduce a deadlock because reverse dependency is already defined.", dependency];
                    error = [NSError errorWithDomain:WEWorkflowErrorDomain code:WEWorkflowDependencyCycle userInfo:@{ NSLocalizedDescriptionKey: reason }];
                    break;
                }
                
                if (fromState->_dependents == nil) fromState->_dependents = _CreateDependencyHashTable();
                if (toState->_dependsOn == nil) toState->_dependsOn = _CreateDependencyHashTable();
                
                [toState->_dependsOn addObject:fromState];
                [fromState->_dependents addObject:toState];
                [independentOperations removeObject:toState];
            }
        }
    }
    
    // Process segues, second kind of nodes
    // See note next to ivar declaration describing segue data structure and how they are activated.
    if (error == nil && segues.count > 0)
    {
        _hasSeguesInternal = YES;
        for (WESegueDescription *segue in segues)
        {
            _WEOperationState *fromState = _FindOperationState(operationStates, namedOperations, segue.sourceOperation, segue.sourceOperationName);
            _WEOperationState *toState = _FindOperationState(operationStates, namedOperations, segue.targetOperation, segue.targetOperationName);
            
            if (fromState == nil || toState == nil || fromState == toState)
            {
                NSString *reason = [NSString stringWithFormat:@"Invalid segue %@: from %@ to %@.", segue, fromState ? @"valid" : @"invalid", toState ? @"valid" : @"invalid"];
                error = [NSError errorWithDomain:WEWorkflowErrorDomain code:WEWorkflowInvalidDependency userInfo:@{ NSLocalizedDescriptionKey: reason }];
                break;
            }
            
            if (!toState->_hasIncomingSegues)
            {
                toState->_activatedIncomingSegues = [NSMutableArray new];
                toState->_hasIncomingSegues = YES;
            }
            if (fromState->_outgoingSegues == nil) fromState->_outgoingSegues = [NSMutableArray new];
            _WEOutgoingSegue *outgoingSegue = [[_WEOutgoingSegue alloc] initWithSegue:segue targetState:toState];
            [fromState->_outgoingSegues addObject:outgoingSegue];
            
            [independentOperations removeObject:toState];
        }
    }
    
    if (error == nil)
    {
        if (independentOperations.count == 0)
        {
            // No independent operations means that each operation depends on at least another one, and nothing can start.
            NSString *reason = @"Every operation in the workflow depends on at least one other operation. No operations are ready to start.";
            error = [NSError errorWithDomain:WEWorkflowErrorDomain code:WEWorkflowDependencyCycle userInfo:@{ NSLocalizedDescriptionKey: reason }];
        }
        else
        {
            // TODO: Perform a more complex check for cycles
            _operationsReadyToExecute = independentOperations;
        }
    }
    
    return error;
}

static inline dispatch_queue_t _WEQueueForOperation(__unsafe_unretained WEOperation *operation)
{
    if (operation.requiresMainThread) return dispatch_get_main_queue();
    
    // TODO: make priority-based decision
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

- (void)_checkAndStartReadyOperation
{
    // If the workflow has failed already, do nothing. The ivar is safe to access on the private queue.
    if (_isFailedInternal) return;
    
    // There may not be any operations ready to execute - all operations that are not running are waiting,
    // or there are just running operations that are left.
    if (_operationsReadyToExecute.count == 0)
    {
        // If there are no operations ready and no operations active, either workflow is complete,
        // or it had gotten to a buggy state when it is not doing anything and cannot proceed.
        WEAssert(_activeOperations.count > 0);
        return;
    }
    
    // Only proceed if had not reached maximum number of operations allowed.
    if (_maximumConcurrentOperations > 0 && _activeOperations.count >= _maximumConcurrentOperations) return;
    
    _WEOperationState *firstReadyOperation = _operationsReadyToExecute.firstObject;
    [_operationsReadyToExecute removeObject:firstReadyOperation];
    WEAssert(firstReadyOperation != nil);
    
    WEOperation *operation = firstReadyOperation->_operation;
    WEAssert(!operation.active && !operation.finished && !operation.cancelled);
    
    [_activeOperations addObject:firstReadyOperation];
    
    dispatch_queue_t operationQueue = _WEQueueForOperation(operation);
    
    dispatch_async(operationQueue, ^{
        // TODO: pass explicit builder as the only facility an operation can amend the workflow.
        [operation prepareForExecutionWithContext:self->_context];
        dispatch_async(self->_workflowInternalQueue, ^{
            [self _runOperationIfStillPossible:firstReadyOperation onQueue:operationQueue];
        });
    });
    
    // Start operations until reached the maximum concurrent count.
    if (_operationsReadyToExecute.count > 0)
    {
        [self _checkAndStartReadyOperation];
    }
}

- (void)_runOperationIfStillPossible:(_WEOperationState *)operationState onQueue:(dispatch_queue_t)queue
{
    // If the workflow has failed already, do nothing. The ivar is safe to access on the private queue.
    if (_isFailedInternal) return;
    
    WEAssert(operationState != nil);
    WEAssert([_activeOperations containsObject:operationState]);
    
    // TODO: if an operation cannot run after preparation, remove it from the list of active
    
    // clear the activated segue list (TODO: in the future may add a block to run when segue-activated operation starts)
    [operationState->_activatedIncomingSegues removeAllObjects];
    
    // dispatch operation execution on a queue that it requested.
    dispatch_async(queue, ^{
        [operationState->_operation startWithCompletion:^(WEOperationResult * _Nullable result) {
            [self _completeOperation:operationState withResult:result];
        } completionQueue:self->_workflowInternalQueue];
    });
}

- (void)_completeOperation:(_WEOperationState *)operationState withResult:(WEOperationResult *)result
{
    // If the workflow has failed already, do nothing. The ivar is safe to access on the private queue.
    if (_isFailedInternal) return;

    WEAssert(operationState != nil);
    _totalCompletedOperations++;
    
    WEAssert([_activeOperations containsObject:operationState]);

    [_activeOperations removeObject:operationState];
    NSString *operationName = operationState->_operation.name;
    if (operationName != nil)
    {
        [_context _setOperationResult:result forOperationName:operationName];
    }

    // check if any operations depending on the one just completed can now run
    for (_WEOperationState *dependent in operationState->_dependents)
    {
        NSUInteger completed = ++(dependent->_completedDependsOnOperations);
        NSUInteger totalDependsOn = dependent->_dependsOn.count;
        WEAssert(completed <= totalDependsOn);
        if (completed == totalDependsOn && (!dependent->_hasIncomingSegues || dependent->_activatedIncomingSegues.count > 0))
        {
            [_operationsReadyToExecute addObject:dependent];
        }
    }
    
    // activate outgoing segues
    if (operationState->_outgoingSegues != nil)
    {
        for (_WEOutgoingSegue *segue in operationState->_outgoingSegues)
        {
            // evaluate the segue condition
            WESegueDescription *segueDescription = segue->_segue;
            NSPredicate *condition = segueDescription.condition;
            if (condition != nil && ![condition evaluateWithObject:result])
            {
                continue;
            }
            
            _WEOperationState *targetState = segue->_targetState;
            WEAssert(targetState->_hasIncomingSegues);

            [targetState->_activatedIncomingSegues addObject:segueDescription];
            
            if (targetState->_completedDependsOnOperations == targetState->_dependsOn.count)
            {
                BOOL alreadyExecutes = [_operationsReadyToExecute containsObject:targetState];
                if (!alreadyExecutes)
                {
                    WEOperation *targetOperation = targetState->_operation;
                    alreadyExecutes = targetOperation.active || targetOperation.finished;
                }
                if (!alreadyExecutes)
                {
                    [_operationsReadyToExecute addObject:targetState];
                }
            }
        }
    }
    
    // check if workflow is complete.
    if (_activeOperations.count == 0 && _operationsReadyToExecute.count == 0)
    {
        if (!_hasSeguesInternal && _totalCompletedOperations < _allOperationStates.count)
        {
            // TODO: improve the check, maybe find a way to validate a workflow with segues.
            NSString *reason = [NSString stringWithFormat:@"Workflow %@ cannot proceed: completed %li of %li operations, but no operations are ready for execution or active.", self, (long)_totalCompletedOperations, (long)_allOperationStates.count];
            NSError *error = [NSError errorWithDomain:WEWorkflowErrorDomain code:WEWorkflowDeadlocked userInfo:@{ NSLocalizedDescriptionKey: reason }];
            [self _completeWorkflowWithError:error];
        }
        else
        {
            [self _completeWorkflow];
        }
    }
    else if (_operationsReadyToExecute.count > 0)
    {
        [self _checkAndStartReadyOperation];
    }
}

- (void)_commonCompletion
{
    _allOperationStates = nil;
    _totalCompletedOperations = 0;
    _operationsReadyToExecute = nil;
    _activeOperations = nil;
}

- (void)_completeWorkflow
{
    WEAssert(_activeOperations.count == 0);
    WEAssert(_operationsReadyToExecute.count == 0);
    WEAssert(!_isFailedInternal);
    
    [self _commonCompletion];
    
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    
    WEAssert(_state == WEWorkflowActive);
    _state = WEWorkflowComplete;
    
    LEAVE_CRITICAL_SECTION(self, _operationMutex)

    id<WEWorkflowDelegate> delegate = _delegate;
    if (delegate)
    {
        dispatch_async(_delegateQueue, ^{
            [delegate workflowDidComplete:self];
        });
    }
}

- (void)_completeWorkflowWithError:(NSError *)error
{
    WEAssert(error != nil);
    WEAssert(!_isFailedInternal);
    
    _isFailedInternal = YES;
    [self _commonCompletion];
    
    ENTER_CRITICAL_SECTION(self, _operationMutex)
    
    WEAssert(_state != WEWorkflowComplete);
    _state = WEWorkflowComplete;
    _error = error;
    
    LEAVE_CRITICAL_SECTION(self, _operationMutex)

    id<WEWorkflowDelegate> delegate = _delegate;
    if (delegate)
    {
        dispatch_async(_delegateQueue, ^{
            [delegate workflow:self didFailWithError:error];
        });
    }
}

@end
