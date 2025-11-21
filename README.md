# lldb-testing

This repo provides a basic infra to run verify LLDB against Android devices. 

## Goals

The core goals of this test infra are:

1. Detect LLDB issues early

This repo has a `llvm-project` git submodule that is updated nightly so that tests always run against the latest `llvm-project`.
This means that it can detect LLDB problems that started within the last 24 hours.

2. Run against physical devices

This repo runs GitHub actions on self-hosted GitHub runners that have physical Android devices connected to them.
When a test is picked up by a runner, it runs the tests against the physical device on that runner.
This means that tests can run against phsyical ARM64 (most modern Android devices) and ARM32 devices (e.g., an old
Android device that has dual-abi).


## Tests

Currently, this repo tests the following:

1. Attach to an Android app.

2. Set a breakpoint and hit the breakpoint.

3. Display stack trace at the breakpoint.


## Next steps

1. Add more tests.
2. Add more devices.
