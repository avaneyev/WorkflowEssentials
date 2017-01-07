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

## License
Workflow Essentials are released under the BSD license. See LICENSE for details.
