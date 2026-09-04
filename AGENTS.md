# Delivery Policy

Work on the iOS project only unless the user explicitly requests another scope.

The user has authorized automatic delivery after each requested change:

- Run checks appropriate to the changed code and data.
- Commit the task's changes and push without waiting for another user command.
- Preserve unrelated work and integrate remote updates without force-pushing.
- Deploy affected backend services and database rules after checks pass, when
  authenticated access and the intended production project are verified.
- Never guess a production project, bypass authentication, or claim that a Git
  push also deployed Firebase or released an iOS binary.
- Do not deploy unrelated functions, delete production resources, or enable paid
  services merely to complete delivery without appropriate authorization.
- If credentials, project selection, platform permissions, or required checks
  block deployment, report the exact blocker and the minimum user action needed.
- Verify remote delivery and distinguish repository push, backend deployment,
  and App Store release in the completion report.

This policy does not schedule recurring work. Follow it during requested tasks.
