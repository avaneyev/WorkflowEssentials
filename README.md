# Workflow Essentials
*Under construction*
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
