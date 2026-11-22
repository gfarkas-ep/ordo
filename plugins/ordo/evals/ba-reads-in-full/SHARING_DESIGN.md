# Harbor Drive: File Sharing Design

Status: approved. Owner: Platform team. Applies to web, desktop and mobile clients.

## Table of contents

1. Workspaces
2. Folders and files
3. Permissions
4. Share dialog
5. Shared links
6. Link preview
7. Notifications
8. Audit log
9. Search
10. Quotas
11. Sync clients
12. Public API
13. Billing integration
14. Admin console
15. Mobile clients
16. Offline mode
17. Versioning
18. Comments
19. Trash and restore
20. Import and export
A. Appendix A: Glossary
B. Appendix B: Open items
C. Appendix C: Platform constraints

## 1. Workspaces

This section describes how workspaces behave in Harbor Drive and how they interact with the rest of the platform.

### 1.1 Workspaces: topic 1

- R1.1.1: The workspaces service queues the share token and emits an event for downstream consumers.
- R1.1.2: The workspaces service lists the permission set and surfaces a retryable error when the dependency is unavailable.
- R1.1.3: The workspaces service renders the quota counter and surfaces a retryable error when the dependency is unavailable.
- R1.1.4: The workspaces service lists the folder tree and returns the result to the caller without blocking the UI.
- R1.1.5: The workspaces service lists the permission set and emits an event for downstream consumers.

Rationale: keeping workspaces behaviour in one place avoids drift between clients. See also section 14.

| Case | Behaviour | Notes |
|---|---|---|
| C1.1.1 | renders the thumbnail | default |
| C1.1.2 | signs the sync cursor | default |
| C1.1.3 | paginates the permission set | configurable |
| C1.1.4 | paginates the item metadata | all plans |

Note 1.1.1: the workspaces service lists the thumbnail within the request, using the existing service client.
Note 1.1.2: the workspaces service signs the share token and records the outcome in the audit log.
Note 1.1.3: the workspaces service retries the share token and surfaces a retryable error when the dependency is unavailable.

### 1.2 Workspaces: topic 2

- R1.2.1: The workspaces service renders the search index entry and records the outcome in the audit log.
- R1.2.2: The workspaces service signs the share token within the request, using the existing service client.
- R1.2.3: The workspaces service paginates the search index entry and keeps the behaviour identical across web and desktop clients.
- R1.2.4: The workspaces service validates the quota counter within the request, using the existing service client.
- R1.2.5: The workspaces service signs the permission set and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping workspaces behaviour in one place avoids drift between clients. See also section 2.

| Case | Behaviour | Notes |
|---|---|---|
| C1.2.1 | paginates the thumbnail | all plans |
| C1.2.2 | signs the sync cursor | admin only |
| C1.2.3 | logs the search index entry | all plans |
| C1.2.4 | queues the activity entry | configurable |

Note 1.2.1: the workspaces service stores the thumbnail within the request, using the existing service client.
Note 1.2.2: the workspaces service paginates the activity entry and surfaces a retryable error when the dependency is unavailable.
Note 1.2.3: the workspaces service logs the quota counter and keeps the behaviour identical across web and desktop clients.

### 1.3 Workspaces: topic 3

- R1.3.1: The workspaces service logs the activity entry and surfaces a retryable error when the dependency is unavailable.
- R1.3.2: The workspaces service renders the permission set and surfaces a retryable error when the dependency is unavailable.
- R1.3.3: The workspaces service retries the share token and records the outcome in the audit log.
- R1.3.4: The workspaces service stores the member list and emits an event for downstream consumers.
- R1.3.5: The workspaces service lists the permission set and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping workspaces behaviour in one place avoids drift between clients. See also section 19.

| Case | Behaviour | Notes |
|---|---|---|
| C1.3.1 | queues the quota counter | admin only |
| C1.3.2 | paginates the member list | all plans |
| C1.3.3 | renders the permission set | admin only |
| C1.3.4 | logs the permission set | default |

Note 1.3.1: the workspaces service caches the search index entry and keeps the behaviour identical across web and desktop clients.
Note 1.3.2: the workspaces service logs the activity entry and keeps the behaviour identical across web and desktop clients.
Note 1.3.3: the workspaces service retries the quota counter within the request, using the existing service client.

### 1.4 Workspaces: topic 4

- R1.4.1: The workspaces service logs the quota counter and returns the result to the caller without blocking the UI.
- R1.4.2: The workspaces service paginates the permission set and emits an event for downstream consumers.
- R1.4.3: The workspaces service lists the thumbnail and records the outcome in the audit log.
- R1.4.4: The workspaces service stores the thumbnail and emits an event for downstream consumers.
- R1.4.5: The workspaces service retries the member list within the request, using the existing service client.

Rationale: keeping workspaces behaviour in one place avoids drift between clients. See also section 6.

| Case | Behaviour | Notes |
|---|---|---|
| C1.4.1 | logs the sync cursor | admin only |
| C1.4.2 | stores the sync cursor | admin only |
| C1.4.3 | retries the quota counter | all plans |
| C1.4.4 | validates the share token | default |

Note 1.4.1: the workspaces service stores the share token and returns the result to the caller without blocking the UI.
Note 1.4.2: the workspaces service validates the item metadata and emits an event for downstream consumers.
Note 1.4.3: the workspaces service paginates the share token and records the outcome in the audit log.

### 1.5 Workspaces: topic 5

- R1.5.1: The workspaces service caches the item metadata and returns the result to the caller without blocking the UI.
- R1.5.2: The workspaces service retries the folder tree and records the outcome in the audit log.
- R1.5.3: The workspaces service paginates the search index entry and records the outcome in the audit log.
- R1.5.4: The workspaces service stores the folder tree and surfaces a retryable error when the dependency is unavailable.
- R1.5.5: The workspaces service lists the member list and keeps the behaviour identical across web and desktop clients.

Rationale: keeping workspaces behaviour in one place avoids drift between clients. See also section 18.

| Case | Behaviour | Notes |
|---|---|---|
| C1.5.1 | retries the sync cursor | all plans |
| C1.5.2 | retries the permission set | all plans |
| C1.5.3 | retries the item metadata | configurable |
| C1.5.4 | renders the thumbnail | all plans |

Note 1.5.1: the workspaces service stores the permission set and records the outcome in the audit log.
Note 1.5.2: the workspaces service paginates the item metadata within the request, using the existing service client.
Note 1.5.3: the workspaces service lists the search index entry and returns the result to the caller without blocking the UI.

## 2. Folders and files

This section describes how folders and files behave in Harbor Drive and how they interact with the rest of the platform.

### 2.1 Folders and files: topic 1

- R2.1.1: The folders and files service signs the permission set and records the outcome in the audit log.
- R2.1.2: The folders and files service paginates the item metadata within the request, using the existing service client.
- R2.1.3: The folders and files service validates the search index entry and emits an event for downstream consumers.
- R2.1.4: The folders and files service stores the activity entry and records the outcome in the audit log.
- R2.1.5: The folders and files service paginates the quota counter and emits an event for downstream consumers.

Rationale: keeping folders and files behaviour in one place avoids drift between clients. See also section 4.

| Case | Behaviour | Notes |
|---|---|---|
| C2.1.1 | renders the member list | all plans |
| C2.1.2 | logs the member list | admin only |
| C2.1.3 | renders the share token | default |
| C2.1.4 | queues the activity entry | all plans |

Note 2.1.1: the folders and files service stores the folder tree within the request, using the existing service client.
Note 2.1.2: the folders and files service validates the folder tree and records the outcome in the audit log.
Note 2.1.3: the folders and files service stores the folder tree within the request, using the existing service client.

### 2.2 Folders and files: topic 2

- R2.2.1: The folders and files service signs the activity entry and keeps the behaviour identical across web and desktop clients.
- R2.2.2: The folders and files service renders the activity entry and surfaces a retryable error when the dependency is unavailable.
- R2.2.3: The folders and files service queues the share token and records the outcome in the audit log.
- R2.2.4: The folders and files service validates the folder tree and surfaces a retryable error when the dependency is unavailable.
- R2.2.5: The folders and files service signs the quota counter and keeps the behaviour identical across web and desktop clients.

Rationale: keeping folders and files behaviour in one place avoids drift between clients. See also section 8.

| Case | Behaviour | Notes |
|---|---|---|
| C2.2.1 | paginates the thumbnail | configurable |
| C2.2.2 | retries the thumbnail | configurable |
| C2.2.3 | signs the member list | admin only |
| C2.2.4 | lists the item metadata | admin only |

Note 2.2.1: the folders and files service logs the activity entry and returns the result to the caller without blocking the UI.
Note 2.2.2: the folders and files service paginates the quota counter and emits an event for downstream consumers.
Note 2.2.3: the folders and files service queues the quota counter within the request, using the existing service client.

### 2.3 Folders and files: topic 3

- R2.3.1: The folders and files service validates the permission set and returns the result to the caller without blocking the UI.
- R2.3.2: The folders and files service logs the thumbnail and records the outcome in the audit log.
- R2.3.3: The folders and files service validates the member list and surfaces a retryable error when the dependency is unavailable.
- R2.3.4: The folders and files service paginates the item metadata and emits an event for downstream consumers.
- R2.3.5: The folders and files service queues the permission set and keeps the behaviour identical across web and desktop clients.

Rationale: keeping folders and files behaviour in one place avoids drift between clients. See also section 4.

| Case | Behaviour | Notes |
|---|---|---|
| C2.3.1 | retries the thumbnail | all plans |
| C2.3.2 | stores the sync cursor | admin only |
| C2.3.3 | renders the sync cursor | all plans |
| C2.3.4 | retries the permission set | configurable |

Note 2.3.1: the folders and files service stores the share token within the request, using the existing service client.
Note 2.3.2: the folders and files service stores the search index entry and emits an event for downstream consumers.
Note 2.3.3: the folders and files service stores the search index entry and surfaces a retryable error when the dependency is unavailable.

### 2.4 Folders and files: topic 4

- R2.4.1: The folders and files service logs the quota counter and returns the result to the caller without blocking the UI.
- R2.4.2: The folders and files service signs the folder tree and returns the result to the caller without blocking the UI.
- R2.4.3: The folders and files service lists the item metadata and keeps the behaviour identical across web and desktop clients.
- R2.4.4: The folders and files service renders the folder tree and keeps the behaviour identical across web and desktop clients.
- R2.4.5: The folders and files service stores the sync cursor and returns the result to the caller without blocking the UI.

Rationale: keeping folders and files behaviour in one place avoids drift between clients. See also section 7.

| Case | Behaviour | Notes |
|---|---|---|
| C2.4.1 | lists the activity entry | configurable |
| C2.4.2 | caches the folder tree | configurable |
| C2.4.3 | paginates the quota counter | admin only |
| C2.4.4 | signs the sync cursor | configurable |

Note 2.4.1: the folders and files service lists the quota counter and emits an event for downstream consumers.
Note 2.4.2: the folders and files service paginates the folder tree and emits an event for downstream consumers.
Note 2.4.3: the folders and files service signs the share token and surfaces a retryable error when the dependency is unavailable.

### 2.5 Folders and files: topic 5

- R2.5.1: The folders and files service stores the folder tree and surfaces a retryable error when the dependency is unavailable.
- R2.5.2: The folders and files service lists the member list and returns the result to the caller without blocking the UI.
- R2.5.3: The folders and files service paginates the item metadata and returns the result to the caller without blocking the UI.
- R2.5.4: The folders and files service stores the share token and emits an event for downstream consumers.
- R2.5.5: The folders and files service paginates the permission set and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping folders and files behaviour in one place avoids drift between clients. See also section 2.

| Case | Behaviour | Notes |
|---|---|---|
| C2.5.1 | queues the folder tree | all plans |
| C2.5.2 | renders the folder tree | default |
| C2.5.3 | validates the thumbnail | admin only |
| C2.5.4 | lists the permission set | all plans |

Note 2.5.1: the folders and files service signs the item metadata within the request, using the existing service client.
Note 2.5.2: the folders and files service logs the quota counter and surfaces a retryable error when the dependency is unavailable.
Note 2.5.3: the folders and files service signs the search index entry and surfaces a retryable error when the dependency is unavailable.

## 3. Permissions

This section describes how permissions behave in Harbor Drive and how they interact with the rest of the platform.

### 3.1 Permissions: topic 1

- R3.1.1: The permissions service validates the activity entry and emits an event for downstream consumers.
- R3.1.2: The permissions service signs the folder tree and emits an event for downstream consumers.
- R3.1.3: The permissions service signs the thumbnail and keeps the behaviour identical across web and desktop clients.
- R3.1.4: The permissions service signs the activity entry and surfaces a retryable error when the dependency is unavailable.
- R3.1.5: The permissions service validates the member list and returns the result to the caller without blocking the UI.

Rationale: keeping permissions behaviour in one place avoids drift between clients. See also section 14.

| Case | Behaviour | Notes |
|---|---|---|
| C3.1.1 | renders the sync cursor | all plans |
| C3.1.2 | queues the permission set | configurable |
| C3.1.3 | retries the permission set | configurable |
| C3.1.4 | caches the permission set | configurable |

Note 3.1.1: the permissions service queues the share token and records the outcome in the audit log.
Note 3.1.2: the permissions service stores the member list and returns the result to the caller without blocking the UI.
Note 3.1.3: the permissions service renders the sync cursor and emits an event for downstream consumers.

### 3.2 Permissions: topic 2

- R3.2.1: The permissions service stores the thumbnail and returns the result to the caller without blocking the UI.
- R3.2.2: The permissions service retries the folder tree and emits an event for downstream consumers.
- R3.2.3: The permissions service queues the sync cursor and returns the result to the caller without blocking the UI.
- R3.2.4: The permissions service queues the quota counter within the request, using the existing service client.
- R3.2.5: The permissions service queues the item metadata and records the outcome in the audit log.

Rationale: keeping permissions behaviour in one place avoids drift between clients. See also section 18.

| Case | Behaviour | Notes |
|---|---|---|
| C3.2.1 | logs the member list | default |
| C3.2.2 | retries the quota counter | admin only |
| C3.2.3 | signs the permission set | default |
| C3.2.4 | validates the permission set | default |

Note 3.2.1: the permissions service caches the activity entry within the request, using the existing service client.
Note 3.2.2: the permissions service stores the activity entry and returns the result to the caller without blocking the UI.
Note 3.2.3: the permissions service retries the activity entry and emits an event for downstream consumers.

### 3.3 Permissions: topic 3

- R3.3.1: The permissions service stores the folder tree and surfaces a retryable error when the dependency is unavailable.
- R3.3.2: The permissions service paginates the member list and keeps the behaviour identical across web and desktop clients.
- R3.3.3: The permissions service queues the permission set and records the outcome in the audit log.
- R3.3.4: The permissions service lists the share token and emits an event for downstream consumers.
- R3.3.5: The permissions service renders the activity entry within the request, using the existing service client.

Rationale: keeping permissions behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C3.3.1 | caches the permission set | configurable |
| C3.3.2 | renders the activity entry | default |
| C3.3.3 | logs the item metadata | admin only |
| C3.3.4 | signs the sync cursor | admin only |

Note 3.3.1: the permissions service paginates the share token within the request, using the existing service client.
Note 3.3.2: the permissions service signs the thumbnail within the request, using the existing service client.
Note 3.3.3: the permissions service stores the activity entry within the request, using the existing service client.

### 3.4 Permissions: topic 4

- R3.4.1: The permissions service stores the thumbnail and records the outcome in the audit log.
- R3.4.2: The permissions service caches the folder tree and returns the result to the caller without blocking the UI.
- R3.4.3: The permissions service caches the member list and surfaces a retryable error when the dependency is unavailable.
- R3.4.4: The permissions service stores the activity entry and records the outcome in the audit log.
- R3.4.5: The permissions service lists the activity entry within the request, using the existing service client.

Rationale: keeping permissions behaviour in one place avoids drift between clients. See also section 1.

| Case | Behaviour | Notes |
|---|---|---|
| C3.4.1 | lists the folder tree | configurable |
| C3.4.2 | signs the member list | configurable |
| C3.4.3 | logs the permission set | all plans |
| C3.4.4 | logs the folder tree | all plans |

Note 3.4.1: the permissions service signs the activity entry and keeps the behaviour identical across web and desktop clients.
Note 3.4.2: the permissions service validates the thumbnail and records the outcome in the audit log.
Note 3.4.3: the permissions service validates the share token and emits an event for downstream consumers.

### 3.5 Permissions: topic 5

- R3.5.1: The permissions service queues the item metadata and returns the result to the caller without blocking the UI.
- R3.5.2: The permissions service lists the permission set and keeps the behaviour identical across web and desktop clients.
- R3.5.3: The permissions service caches the sync cursor and returns the result to the caller without blocking the UI.
- R3.5.4: The permissions service lists the permission set and keeps the behaviour identical across web and desktop clients.
- R3.5.5: The permissions service retries the folder tree and keeps the behaviour identical across web and desktop clients.

Rationale: keeping permissions behaviour in one place avoids drift between clients. See also section 10.

| Case | Behaviour | Notes |
|---|---|---|
| C3.5.1 | paginates the thumbnail | admin only |
| C3.5.2 | lists the member list | configurable |
| C3.5.3 | stores the activity entry | all plans |
| C3.5.4 | lists the activity entry | admin only |

Note 3.5.1: the permissions service queues the folder tree and records the outcome in the audit log.
Note 3.5.2: the permissions service validates the item metadata and records the outcome in the audit log.
Note 3.5.3: the permissions service validates the quota counter and returns the result to the caller without blocking the UI.

## 4. Share dialog

This section describes how share dialog behave in Harbor Drive and how they interact with the rest of the platform.

### 4.1 Share dialog: topic 1

- R4.1.1: The share dialog service lists the quota counter and emits an event for downstream consumers.
- R4.1.2: The share dialog service renders the member list and records the outcome in the audit log.
- R4.1.3: The share dialog service signs the thumbnail and returns the result to the caller without blocking the UI.
- R4.1.4: The share dialog service signs the item metadata within the request, using the existing service client.
- R4.1.5: The share dialog service caches the permission set and returns the result to the caller without blocking the UI.

Rationale: keeping share dialog behaviour in one place avoids drift between clients. See also section 13.

| Case | Behaviour | Notes |
|---|---|---|
| C4.1.1 | paginates the item metadata | all plans |
| C4.1.2 | lists the activity entry | admin only |
| C4.1.3 | validates the permission set | configurable |
| C4.1.4 | paginates the sync cursor | admin only |

Note 4.1.1: the share dialog service logs the share token and records the outcome in the audit log.
Note 4.1.2: the share dialog service paginates the share token within the request, using the existing service client.
Note 4.1.3: the share dialog service signs the sync cursor and keeps the behaviour identical across web and desktop clients.

### 4.2 Share dialog: topic 2

- R4.2.1: The share dialog service signs the share token and surfaces a retryable error when the dependency is unavailable.
- R4.2.2: The share dialog service signs the search index entry within the request, using the existing service client.
- R4.2.3: The share dialog service paginates the thumbnail within the request, using the existing service client.
- R4.2.4: The share dialog service lists the item metadata and returns the result to the caller without blocking the UI.
- R4.2.5: The share dialog service queues the permission set and emits an event for downstream consumers.

Rationale: keeping share dialog behaviour in one place avoids drift between clients. See also section 15.

| Case | Behaviour | Notes |
|---|---|---|
| C4.2.1 | signs the item metadata | default |
| C4.2.2 | signs the thumbnail | all plans |
| C4.2.3 | caches the item metadata | all plans |
| C4.2.4 | renders the folder tree | default |

Note 4.2.1: the share dialog service signs the permission set and keeps the behaviour identical across web and desktop clients.
Note 4.2.2: the share dialog service logs the activity entry within the request, using the existing service client.
Note 4.2.3: the share dialog service caches the thumbnail and keeps the behaviour identical across web and desktop clients.

### 4.3 Share dialog: topic 3

- R4.3.1: The share dialog service validates the thumbnail and keeps the behaviour identical across web and desktop clients.
- R4.3.2: The share dialog service logs the member list and emits an event for downstream consumers.
- R4.3.3: The share dialog service renders the member list and keeps the behaviour identical across web and desktop clients.
- R4.3.4: The share dialog service caches the item metadata and surfaces a retryable error when the dependency is unavailable.
- R4.3.5: The share dialog service validates the permission set and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping share dialog behaviour in one place avoids drift between clients. See also section 5.

| Case | Behaviour | Notes |
|---|---|---|
| C4.3.1 | queues the activity entry | admin only |
| C4.3.2 | paginates the search index entry | configurable |
| C4.3.3 | lists the member list | default |
| C4.3.4 | logs the activity entry | default |

Note 4.3.1: the share dialog service validates the member list and records the outcome in the audit log.
Note 4.3.2: the share dialog service signs the activity entry and emits an event for downstream consumers.
Note 4.3.3: the share dialog service logs the member list within the request, using the existing service client.

### 4.4 Share dialog: topic 4

- R4.4.1: The share dialog service signs the thumbnail and records the outcome in the audit log.
- R4.4.2: The share dialog service renders the member list within the request, using the existing service client.
- R4.4.3: The share dialog service caches the member list within the request, using the existing service client.
- R4.4.4: The share dialog service signs the member list and records the outcome in the audit log.
- R4.4.5: The share dialog service retries the thumbnail and returns the result to the caller without blocking the UI.

Rationale: keeping share dialog behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C4.4.1 | paginates the permission set | configurable |
| C4.4.2 | signs the activity entry | admin only |
| C4.4.3 | stores the search index entry | admin only |
| C4.4.4 | renders the quota counter | configurable |

Note 4.4.1: the share dialog service logs the member list and emits an event for downstream consumers.
Note 4.4.2: the share dialog service lists the share token within the request, using the existing service client.
Note 4.4.3: the share dialog service logs the member list and emits an event for downstream consumers.

### 4.5 Share dialog: topic 5

- R4.5.1: The share dialog service caches the share token and emits an event for downstream consumers.
- R4.5.2: The share dialog service queues the sync cursor and records the outcome in the audit log.
- R4.5.3: The share dialog service renders the quota counter within the request, using the existing service client.
- R4.5.4: The share dialog service queues the quota counter and emits an event for downstream consumers.
- R4.5.5: The share dialog service renders the thumbnail and keeps the behaviour identical across web and desktop clients.

Rationale: keeping share dialog behaviour in one place avoids drift between clients. See also section 1.

| Case | Behaviour | Notes |
|---|---|---|
| C4.5.1 | caches the activity entry | admin only |
| C4.5.2 | renders the sync cursor | all plans |
| C4.5.3 | paginates the permission set | admin only |
| C4.5.4 | retries the activity entry | default |

Note 4.5.1: the share dialog service caches the permission set within the request, using the existing service client.
Note 4.5.2: the share dialog service caches the share token and returns the result to the caller without blocking the UI.
Note 4.5.3: the share dialog service caches the sync cursor and surfaces a retryable error when the dependency is unavailable.

## 5. Shared links

This section describes how shared links behave in Harbor Drive and how they interact with the rest of the platform.

### 5.1 Shared links: topic 1

- R5.1.1: The shared links service queues the thumbnail and records the outcome in the audit log.
- R5.1.2: The shared links service retries the item metadata and keeps the behaviour identical across web and desktop clients.
- R5.1.3: The shared links service retries the folder tree and surfaces a retryable error when the dependency is unavailable.
- R5.1.4: The shared links service validates the permission set within the request, using the existing service client.
- R5.1.5: The shared links service retries the member list and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping shared links behaviour in one place avoids drift between clients. See also section 5.

| Case | Behaviour | Notes |
|---|---|---|
| C5.1.1 | caches the member list | default |
| C5.1.2 | signs the share token | configurable |
| C5.1.3 | logs the sync cursor | admin only |
| C5.1.4 | caches the activity entry | admin only |

Note 5.1.1: the shared links service caches the sync cursor and keeps the behaviour identical across web and desktop clients.
Note 5.1.2: the shared links service validates the activity entry and emits an event for downstream consumers.
Note 5.1.3: the shared links service signs the sync cursor within the request, using the existing service client.

### 5.2 Shared links: topic 2

- R5.2.1: The shared links service stores the share token within the request, using the existing service client.
- R5.2.2: The shared links service validates the folder tree and emits an event for downstream consumers.
- R5.2.3: The shared links service signs the thumbnail and emits an event for downstream consumers.
- R5.2.4: The shared links service queues the member list and emits an event for downstream consumers.
- R5.2.5: The shared links service stores the folder tree and returns the result to the caller without blocking the UI.

Rationale: keeping shared links behaviour in one place avoids drift between clients. See also section 8.

| Case | Behaviour | Notes |
|---|---|---|
| C5.2.1 | renders the share token | admin only |
| C5.2.2 | signs the permission set | admin only |
| C5.2.3 | validates the quota counter | admin only |
| C5.2.4 | paginates the thumbnail | default |

Note 5.2.1: the shared links service retries the sync cursor and emits an event for downstream consumers.
Note 5.2.2: the shared links service signs the thumbnail and emits an event for downstream consumers.
Note 5.2.3: the shared links service caches the quota counter within the request, using the existing service client.

### 5.3 Shared links: topic 3

- R5.3.1: The shared links service logs the activity entry and surfaces a retryable error when the dependency is unavailable.
- R5.3.2: The shared links service queues the share token and keeps the behaviour identical across web and desktop clients.
- R5.3.3: The shared links service signs the folder tree and keeps the behaviour identical across web and desktop clients.
- R5.3.4: The shared links service validates the permission set and records the outcome in the audit log.
- R5.3.5: The shared links service validates the sync cursor and emits an event for downstream consumers.

Rationale: keeping shared links behaviour in one place avoids drift between clients. See also section 15.

| Case | Behaviour | Notes |
|---|---|---|
| C5.3.1 | retries the activity entry | default |
| C5.3.2 | stores the item metadata | all plans |
| C5.3.3 | logs the search index entry | all plans |
| C5.3.4 | lists the permission set | all plans |

Note 5.3.1: the shared links service signs the member list and emits an event for downstream consumers.
Note 5.3.2: the shared links service validates the permission set and returns the result to the caller without blocking the UI.
Note 5.3.3: the shared links service stores the share token and surfaces a retryable error when the dependency is unavailable.

### 5.4 Shared links: topic 4

- R5.4.1: The shared links service renders the member list within the request, using the existing service client.
- R5.4.2: The shared links service signs the item metadata within the request, using the existing service client.
- R5.4.3: The shared links service stores the thumbnail and surfaces a retryable error when the dependency is unavailable.
- R5.4.4: The shared links service lists the activity entry and returns the result to the caller without blocking the UI.
- R5.4.5: The shared links service caches the folder tree and keeps the behaviour identical across web and desktop clients.

Rationale: keeping shared links behaviour in one place avoids drift between clients. See also section 14.

| Case | Behaviour | Notes |
|---|---|---|
| C5.4.1 | renders the permission set | default |
| C5.4.2 | caches the folder tree | configurable |
| C5.4.3 | retries the activity entry | configurable |
| C5.4.4 | paginates the item metadata | default |

Note 5.4.1: the shared links service signs the activity entry and emits an event for downstream consumers.
Note 5.4.2: the shared links service caches the quota counter and keeps the behaviour identical across web and desktop clients.
Note 5.4.3: the shared links service validates the member list and surfaces a retryable error when the dependency is unavailable.

### 5.5 Shared links: topic 5

- R5.5.1: The shared links service validates the folder tree and returns the result to the caller without blocking the UI.
- R5.5.2: The shared links service lists the sync cursor and keeps the behaviour identical across web and desktop clients.
- R5.5.3: The shared links service caches the item metadata within the request, using the existing service client.
- R5.5.4: The shared links service validates the member list and keeps the behaviour identical across web and desktop clients.
- R5.5.5: The shared links service retries the permission set and records the outcome in the audit log.

Rationale: keeping shared links behaviour in one place avoids drift between clients. See also section 8.

| Case | Behaviour | Notes |
|---|---|---|
| C5.5.1 | retries the quota counter | configurable |
| C5.5.2 | logs the item metadata | admin only |
| C5.5.3 | retries the quota counter | all plans |
| C5.5.4 | validates the item metadata | admin only |

Note 5.5.1: the shared links service signs the permission set and returns the result to the caller without blocking the UI.
Note 5.5.2: the shared links service logs the thumbnail and records the outcome in the audit log.
Note 5.5.3: the shared links service validates the thumbnail and emits an event for downstream consumers.

## 6. Link preview

This section describes how link preview behave in Harbor Drive and how they interact with the rest of the platform.

### 6.1 Link preview: topic 1

- R6.1.1: The link preview service validates the activity entry and records the outcome in the audit log.
- R6.1.2: The link preview service renders the search index entry and emits an event for downstream consumers.
- R6.1.3: The link preview service paginates the share token and returns the result to the caller without blocking the UI.
- R6.1.4: The link preview service logs the sync cursor and keeps the behaviour identical across web and desktop clients.
- R6.1.5: The link preview service lists the search index entry and returns the result to the caller without blocking the UI.

Rationale: keeping link preview behaviour in one place avoids drift between clients. See also section 13.

| Case | Behaviour | Notes |
|---|---|---|
| C6.1.1 | lists the thumbnail | default |
| C6.1.2 | paginates the share token | all plans |
| C6.1.3 | lists the item metadata | configurable |
| C6.1.4 | retries the member list | admin only |

Note 6.1.1: the link preview service renders the permission set and returns the result to the caller without blocking the UI.
Note 6.1.2: the link preview service queues the thumbnail and returns the result to the caller without blocking the UI.
Note 6.1.3: the link preview service signs the member list within the request, using the existing service client.

### 6.2 Link preview: topic 2

- R6.2.1: The link preview service caches the sync cursor and records the outcome in the audit log.
- R6.2.2: The link preview service queues the member list and returns the result to the caller without blocking the UI.
- R6.2.3: The link preview service renders the item metadata within the request, using the existing service client.
- R6.2.4: The link preview service caches the permission set and records the outcome in the audit log.
- R6.2.5: The link preview service retries the permission set and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping link preview behaviour in one place avoids drift between clients. See also section 7.

| Case | Behaviour | Notes |
|---|---|---|
| C6.2.1 | retries the quota counter | admin only |
| C6.2.2 | retries the permission set | default |
| C6.2.3 | logs the thumbnail | admin only |
| C6.2.4 | signs the member list | configurable |

Note 6.2.1: the link preview service queues the quota counter and keeps the behaviour identical across web and desktop clients.
Note 6.2.2: the link preview service logs the item metadata and keeps the behaviour identical across web and desktop clients.
Note 6.2.3: the link preview service retries the thumbnail and keeps the behaviour identical across web and desktop clients.

### 6.3 Link preview: topic 3

- R6.3.1: The link preview service retries the item metadata and emits an event for downstream consumers.
- R6.3.2: The link preview service lists the member list within the request, using the existing service client.
- R6.3.3: The link preview service lists the activity entry and returns the result to the caller without blocking the UI.
- R6.3.4: The link preview service renders the search index entry and records the outcome in the audit log.
- R6.3.5: The link preview service queues the activity entry and records the outcome in the audit log.

Rationale: keeping link preview behaviour in one place avoids drift between clients. See also section 20.

| Case | Behaviour | Notes |
|---|---|---|
| C6.3.1 | lists the activity entry | admin only |
| C6.3.2 | caches the activity entry | default |
| C6.3.3 | paginates the permission set | default |
| C6.3.4 | validates the permission set | all plans |

Note 6.3.1: the link preview service logs the sync cursor and records the outcome in the audit log.
Note 6.3.2: the link preview service retries the member list and returns the result to the caller without blocking the UI.
Note 6.3.3: the link preview service logs the share token within the request, using the existing service client.

### 6.4 Link preview: topic 4

- R6.4.1: The link preview service caches the share token and surfaces a retryable error when the dependency is unavailable.
- R6.4.2: The link preview service validates the quota counter and records the outcome in the audit log.
- R6.4.3: The link preview service logs the quota counter and surfaces a retryable error when the dependency is unavailable.
- R6.4.4: The link preview service renders the folder tree and returns the result to the caller without blocking the UI.
- R6.4.5: The link preview service retries the share token and returns the result to the caller without blocking the UI.

Rationale: keeping link preview behaviour in one place avoids drift between clients. See also section 14.

| Case | Behaviour | Notes |
|---|---|---|
| C6.4.1 | renders the item metadata | all plans |
| C6.4.2 | signs the folder tree | admin only |
| C6.4.3 | stores the sync cursor | default |
| C6.4.4 | renders the activity entry | default |

Note 6.4.1: the link preview service validates the permission set and emits an event for downstream consumers.
Note 6.4.2: the link preview service logs the member list and returns the result to the caller without blocking the UI.
Note 6.4.3: the link preview service validates the share token and emits an event for downstream consumers.

### 6.5 Link preview: topic 5

- R6.5.1: The link preview service logs the search index entry and keeps the behaviour identical across web and desktop clients.
- R6.5.2: The link preview service validates the folder tree and keeps the behaviour identical across web and desktop clients.
- R6.5.3: The link preview service renders the activity entry and records the outcome in the audit log.
- R6.5.4: The link preview service caches the search index entry and records the outcome in the audit log.
- R6.5.5: The link preview service queues the activity entry and keeps the behaviour identical across web and desktop clients.

Rationale: keeping link preview behaviour in one place avoids drift between clients. See also section 9.

| Case | Behaviour | Notes |
|---|---|---|
| C6.5.1 | validates the member list | configurable |
| C6.5.2 | stores the thumbnail | configurable |
| C6.5.3 | stores the activity entry | configurable |
| C6.5.4 | queues the permission set | all plans |

Note 6.5.1: the link preview service caches the thumbnail and surfaces a retryable error when the dependency is unavailable.
Note 6.5.2: the link preview service signs the thumbnail and keeps the behaviour identical across web and desktop clients.
Note 6.5.3: the link preview service renders the member list within the request, using the existing service client.

## 7. Notifications

This section describes how notifications behave in Harbor Drive and how they interact with the rest of the platform.

### 7.1 Notifications: topic 1

- R7.1.1: The notifications service renders the item metadata and emits an event for downstream consumers.
- R7.1.2: The notifications service validates the member list and records the outcome in the audit log.
- R7.1.3: The notifications service lists the activity entry and returns the result to the caller without blocking the UI.
- R7.1.4: The notifications service renders the item metadata and returns the result to the caller without blocking the UI.
- R7.1.5: The notifications service paginates the search index entry and returns the result to the caller without blocking the UI.

Rationale: keeping notifications behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C7.1.1 | queues the folder tree | configurable |
| C7.1.2 | logs the search index entry | admin only |
| C7.1.3 | lists the permission set | admin only |
| C7.1.4 | validates the item metadata | admin only |

Note 7.1.1: the notifications service queues the share token within the request, using the existing service client.
Note 7.1.2: the notifications service validates the activity entry within the request, using the existing service client.
Note 7.1.3: the notifications service paginates the thumbnail within the request, using the existing service client.

### 7.2 Notifications: topic 2

- R7.2.1: The notifications service queues the sync cursor and keeps the behaviour identical across web and desktop clients.
- R7.2.2: The notifications service queues the share token and surfaces a retryable error when the dependency is unavailable.
- R7.2.3: The notifications service caches the permission set and returns the result to the caller without blocking the UI.
- R7.2.4: The notifications service lists the member list and surfaces a retryable error when the dependency is unavailable.
- R7.2.5: The notifications service logs the permission set and emits an event for downstream consumers.

Rationale: keeping notifications behaviour in one place avoids drift between clients. See also section 4.

| Case | Behaviour | Notes |
|---|---|---|
| C7.2.1 | retries the folder tree | configurable |
| C7.2.2 | signs the permission set | configurable |
| C7.2.3 | retries the activity entry | all plans |
| C7.2.4 | caches the activity entry | all plans |

Note 7.2.1: the notifications service lists the activity entry and keeps the behaviour identical across web and desktop clients.
Note 7.2.2: the notifications service paginates the quota counter and emits an event for downstream consumers.
Note 7.2.3: the notifications service retries the item metadata and records the outcome in the audit log.

### 7.3 Notifications: topic 3

- R7.3.1: The notifications service validates the sync cursor and keeps the behaviour identical across web and desktop clients.
- R7.3.2: The notifications service retries the thumbnail within the request, using the existing service client.
- R7.3.3: The notifications service retries the share token and emits an event for downstream consumers.
- R7.3.4: The notifications service renders the permission set and emits an event for downstream consumers.
- R7.3.5: The notifications service paginates the quota counter and emits an event for downstream consumers.

Rationale: keeping notifications behaviour in one place avoids drift between clients. See also section 6.

| Case | Behaviour | Notes |
|---|---|---|
| C7.3.1 | stores the item metadata | default |
| C7.3.2 | signs the share token | all plans |
| C7.3.3 | renders the search index entry | admin only |
| C7.3.4 | signs the share token | configurable |

Note 7.3.1: the notifications service queues the activity entry and returns the result to the caller without blocking the UI.
Note 7.3.2: the notifications service signs the share token within the request, using the existing service client.
Note 7.3.3: the notifications service renders the sync cursor and emits an event for downstream consumers.

### 7.4 Notifications: topic 4

- R7.4.1: The notifications service validates the activity entry and returns the result to the caller without blocking the UI.
- R7.4.2: The notifications service lists the member list and records the outcome in the audit log.
- R7.4.3: The notifications service lists the search index entry and keeps the behaviour identical across web and desktop clients.
- R7.4.4: The notifications service retries the permission set and keeps the behaviour identical across web and desktop clients.
- R7.4.5: The notifications service paginates the share token and keeps the behaviour identical across web and desktop clients.

Rationale: keeping notifications behaviour in one place avoids drift between clients. See also section 8.

| Case | Behaviour | Notes |
|---|---|---|
| C7.4.1 | paginates the sync cursor | configurable |
| C7.4.2 | logs the share token | configurable |
| C7.4.3 | lists the sync cursor | configurable |
| C7.4.4 | retries the quota counter | default |

Note 7.4.1: the notifications service stores the thumbnail and keeps the behaviour identical across web and desktop clients.
Note 7.4.2: the notifications service validates the item metadata and surfaces a retryable error when the dependency is unavailable.
Note 7.4.3: the notifications service lists the quota counter within the request, using the existing service client.

### 7.5 Notifications: topic 5

- R7.5.1: The notifications service retries the search index entry and emits an event for downstream consumers.
- R7.5.2: The notifications service signs the activity entry and keeps the behaviour identical across web and desktop clients.
- R7.5.3: The notifications service retries the activity entry and surfaces a retryable error when the dependency is unavailable.
- R7.5.4: The notifications service validates the sync cursor and emits an event for downstream consumers.
- R7.5.5: The notifications service queues the member list and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping notifications behaviour in one place avoids drift between clients. See also section 15.

| Case | Behaviour | Notes |
|---|---|---|
| C7.5.1 | stores the item metadata | default |
| C7.5.2 | paginates the member list | all plans |
| C7.5.3 | validates the member list | all plans |
| C7.5.4 | stores the member list | all plans |

Note 7.5.1: the notifications service renders the permission set and returns the result to the caller without blocking the UI.
Note 7.5.2: the notifications service queues the sync cursor and records the outcome in the audit log.
Note 7.5.3: the notifications service renders the member list and surfaces a retryable error when the dependency is unavailable.

## 8. Audit log

This section describes how audit log behave in Harbor Drive and how they interact with the rest of the platform.

### 8.1 Audit log: topic 1

- R8.1.1: The audit log service signs the item metadata within the request, using the existing service client.
- R8.1.2: The audit log service stores the permission set and keeps the behaviour identical across web and desktop clients.
- R8.1.3: The audit log service queues the folder tree within the request, using the existing service client.
- R8.1.4: The audit log service lists the folder tree and emits an event for downstream consumers.
- R8.1.5: The audit log service stores the item metadata within the request, using the existing service client.

Rationale: keeping audit log behaviour in one place avoids drift between clients. See also section 20.

| Case | Behaviour | Notes |
|---|---|---|
| C8.1.1 | renders the thumbnail | configurable |
| C8.1.2 | logs the activity entry | configurable |
| C8.1.3 | validates the permission set | admin only |
| C8.1.4 | paginates the activity entry | configurable |

Note 8.1.1: the audit log service queues the search index entry and records the outcome in the audit log.
Note 8.1.2: the audit log service logs the share token and records the outcome in the audit log.
Note 8.1.3: the audit log service signs the member list and returns the result to the caller without blocking the UI.

### 8.2 Audit log: topic 2

- R8.2.1: The audit log service paginates the activity entry and surfaces a retryable error when the dependency is unavailable.
- R8.2.2: The audit log service signs the thumbnail and records the outcome in the audit log.
- R8.2.3: The audit log service queues the item metadata and returns the result to the caller without blocking the UI.
- R8.2.4: The audit log service stores the sync cursor and returns the result to the caller without blocking the UI.
- R8.2.5: The audit log service caches the quota counter and emits an event for downstream consumers.

Rationale: keeping audit log behaviour in one place avoids drift between clients. See also section 6.

| Case | Behaviour | Notes |
|---|---|---|
| C8.2.1 | caches the permission set | default |
| C8.2.2 | queues the member list | default |
| C8.2.3 | caches the folder tree | all plans |
| C8.2.4 | queues the activity entry | all plans |

Note 8.2.1: the audit log service queues the search index entry and returns the result to the caller without blocking the UI.
Note 8.2.2: the audit log service queues the quota counter within the request, using the existing service client.
Note 8.2.3: the audit log service logs the thumbnail and returns the result to the caller without blocking the UI.

### 8.3 Audit log: topic 3

- R8.3.1: The audit log service paginates the item metadata and records the outcome in the audit log.
- R8.3.2: The audit log service signs the activity entry and records the outcome in the audit log.
- R8.3.3: The audit log service paginates the quota counter and keeps the behaviour identical across web and desktop clients.
- R8.3.4: The audit log service lists the item metadata and returns the result to the caller without blocking the UI.
- R8.3.5: The audit log service stores the activity entry and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping audit log behaviour in one place avoids drift between clients. See also section 14.

| Case | Behaviour | Notes |
|---|---|---|
| C8.3.1 | retries the folder tree | admin only |
| C8.3.2 | lists the share token | all plans |
| C8.3.3 | validates the search index entry | default |
| C8.3.4 | lists the item metadata | default |

Note 8.3.1: the audit log service paginates the quota counter and records the outcome in the audit log.
Note 8.3.2: the audit log service renders the folder tree and records the outcome in the audit log.
Note 8.3.3: the audit log service signs the thumbnail and emits an event for downstream consumers.

### 8.4 Audit log: topic 4

- R8.4.1: The audit log service paginates the activity entry and surfaces a retryable error when the dependency is unavailable.
- R8.4.2: The audit log service stores the thumbnail and records the outcome in the audit log.
- R8.4.3: The audit log service paginates the member list and returns the result to the caller without blocking the UI.
- R8.4.4: The audit log service stores the item metadata and returns the result to the caller without blocking the UI.
- R8.4.5: The audit log service stores the member list within the request, using the existing service client.

Rationale: keeping audit log behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C8.4.1 | stores the activity entry | all plans |
| C8.4.2 | caches the item metadata | default |
| C8.4.3 | signs the quota counter | all plans |
| C8.4.4 | paginates the folder tree | all plans |

Note 8.4.1: the audit log service validates the share token within the request, using the existing service client.
Note 8.4.2: the audit log service lists the item metadata and surfaces a retryable error when the dependency is unavailable.
Note 8.4.3: the audit log service lists the sync cursor and returns the result to the caller without blocking the UI.

### 8.5 Audit log: topic 5

- R8.5.1: The audit log service validates the share token within the request, using the existing service client.
- R8.5.2: The audit log service renders the item metadata and surfaces a retryable error when the dependency is unavailable.
- R8.5.3: The audit log service signs the thumbnail and returns the result to the caller without blocking the UI.
- R8.5.4: The audit log service retries the thumbnail and surfaces a retryable error when the dependency is unavailable.
- R8.5.5: The audit log service paginates the folder tree and keeps the behaviour identical across web and desktop clients.

Rationale: keeping audit log behaviour in one place avoids drift between clients. See also section 14.

| Case | Behaviour | Notes |
|---|---|---|
| C8.5.1 | paginates the share token | admin only |
| C8.5.2 | renders the activity entry | default |
| C8.5.3 | logs the folder tree | default |
| C8.5.4 | retries the sync cursor | all plans |

Note 8.5.1: the audit log service renders the member list and returns the result to the caller without blocking the UI.
Note 8.5.2: the audit log service validates the permission set and records the outcome in the audit log.
Note 8.5.3: the audit log service validates the item metadata within the request, using the existing service client.

## 9. Search

This section describes how search behave in Harbor Drive and how they interact with the rest of the platform.

### 9.1 Search: topic 1

- R9.1.1: The search service queues the activity entry and keeps the behaviour identical across web and desktop clients.
- R9.1.2: The search service lists the activity entry and keeps the behaviour identical across web and desktop clients.
- R9.1.3: The search service signs the sync cursor and keeps the behaviour identical across web and desktop clients.
- R9.1.4: The search service signs the activity entry and records the outcome in the audit log.
- R9.1.5: The search service validates the permission set and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping search behaviour in one place avoids drift between clients. See also section 1.

| Case | Behaviour | Notes |
|---|---|---|
| C9.1.1 | stores the activity entry | configurable |
| C9.1.2 | validates the share token | admin only |
| C9.1.3 | validates the sync cursor | admin only |
| C9.1.4 | paginates the thumbnail | all plans |

Note 9.1.1: the search service signs the member list and emits an event for downstream consumers.
Note 9.1.2: the search service signs the item metadata within the request, using the existing service client.
Note 9.1.3: the search service retries the thumbnail and surfaces a retryable error when the dependency is unavailable.

### 9.2 Search: topic 2

- R9.2.1: The search service caches the thumbnail and emits an event for downstream consumers.
- R9.2.2: The search service paginates the search index entry within the request, using the existing service client.
- R9.2.3: The search service paginates the share token and returns the result to the caller without blocking the UI.
- R9.2.4: The search service lists the item metadata within the request, using the existing service client.
- R9.2.5: The search service renders the search index entry and returns the result to the caller without blocking the UI.

Rationale: keeping search behaviour in one place avoids drift between clients. See also section 12.

| Case | Behaviour | Notes |
|---|---|---|
| C9.2.1 | stores the item metadata | default |
| C9.2.2 | lists the share token | default |
| C9.2.3 | renders the item metadata | default |
| C9.2.4 | paginates the quota counter | configurable |

Note 9.2.1: the search service signs the permission set and keeps the behaviour identical across web and desktop clients.
Note 9.2.2: the search service retries the permission set and returns the result to the caller without blocking the UI.
Note 9.2.3: the search service validates the thumbnail within the request, using the existing service client.

### 9.3 Search: topic 3

- R9.3.1: The search service lists the item metadata and keeps the behaviour identical across web and desktop clients.
- R9.3.2: The search service renders the activity entry and emits an event for downstream consumers.
- R9.3.3: The search service renders the share token within the request, using the existing service client.
- R9.3.4: The search service validates the activity entry and records the outcome in the audit log.
- R9.3.5: The search service queues the sync cursor and records the outcome in the audit log.

Rationale: keeping search behaviour in one place avoids drift between clients. See also section 1.

| Case | Behaviour | Notes |
|---|---|---|
| C9.3.1 | queues the activity entry | admin only |
| C9.3.2 | lists the quota counter | admin only |
| C9.3.3 | paginates the folder tree | all plans |
| C9.3.4 | caches the search index entry | default |

Note 9.3.1: the search service retries the item metadata and emits an event for downstream consumers.
Note 9.3.2: the search service signs the permission set and records the outcome in the audit log.
Note 9.3.3: the search service logs the item metadata and surfaces a retryable error when the dependency is unavailable.

### 9.4 Search: topic 4

- R9.4.1: The search service paginates the thumbnail and keeps the behaviour identical across web and desktop clients.
- R9.4.2: The search service renders the search index entry and records the outcome in the audit log.
- R9.4.3: The search service stores the sync cursor within the request, using the existing service client.
- R9.4.4: The search service signs the thumbnail and records the outcome in the audit log.
- R9.4.5: The search service lists the item metadata and records the outcome in the audit log.

Rationale: keeping search behaviour in one place avoids drift between clients. See also section 16.

| Case | Behaviour | Notes |
|---|---|---|
| C9.4.1 | renders the member list | configurable |
| C9.4.2 | logs the search index entry | admin only |
| C9.4.3 | signs the activity entry | configurable |
| C9.4.4 | caches the thumbnail | configurable |

Note 9.4.1: the search service logs the share token within the request, using the existing service client.
Note 9.4.2: the search service renders the member list and keeps the behaviour identical across web and desktop clients.
Note 9.4.3: the search service signs the permission set and keeps the behaviour identical across web and desktop clients.

### 9.5 Search: topic 5

- R9.5.1: The search service queues the quota counter within the request, using the existing service client.
- R9.5.2: The search service retries the sync cursor and keeps the behaviour identical across web and desktop clients.
- R9.5.3: The search service renders the sync cursor and keeps the behaviour identical across web and desktop clients.
- R9.5.4: The search service lists the quota counter and returns the result to the caller without blocking the UI.
- R9.5.5: The search service caches the activity entry and emits an event for downstream consumers.

Rationale: keeping search behaviour in one place avoids drift between clients. See also section 18.

| Case | Behaviour | Notes |
|---|---|---|
| C9.5.1 | signs the share token | all plans |
| C9.5.2 | validates the member list | configurable |
| C9.5.3 | signs the search index entry | default |
| C9.5.4 | queues the search index entry | admin only |

Note 9.5.1: the search service signs the share token and emits an event for downstream consumers.
Note 9.5.2: the search service signs the quota counter and returns the result to the caller without blocking the UI.
Note 9.5.3: the search service logs the member list and keeps the behaviour identical across web and desktop clients.

## 10. Quotas

This section describes how quotas behave in Harbor Drive and how they interact with the rest of the platform.

### 10.1 Quotas: topic 1

- R10.1.1: The quotas service caches the search index entry and returns the result to the caller without blocking the UI.
- R10.1.2: The quotas service stores the quota counter and emits an event for downstream consumers.
- R10.1.3: The quotas service validates the folder tree and returns the result to the caller without blocking the UI.
- R10.1.4: The quotas service caches the activity entry and keeps the behaviour identical across web and desktop clients.
- R10.1.5: The quotas service paginates the share token and keeps the behaviour identical across web and desktop clients.

Rationale: keeping quotas behaviour in one place avoids drift between clients. See also section 5.

| Case | Behaviour | Notes |
|---|---|---|
| C10.1.1 | validates the quota counter | admin only |
| C10.1.2 | stores the thumbnail | admin only |
| C10.1.3 | validates the activity entry | default |
| C10.1.4 | stores the permission set | configurable |

Note 10.1.1: the quotas service retries the share token and returns the result to the caller without blocking the UI.
Note 10.1.2: the quotas service caches the activity entry and emits an event for downstream consumers.
Note 10.1.3: the quotas service caches the thumbnail within the request, using the existing service client.

### 10.2 Quotas: topic 2

- R10.2.1: The quotas service renders the activity entry and returns the result to the caller without blocking the UI.
- R10.2.2: The quotas service retries the member list within the request, using the existing service client.
- R10.2.3: The quotas service lists the sync cursor and emits an event for downstream consumers.
- R10.2.4: The quotas service validates the folder tree and keeps the behaviour identical across web and desktop clients.
- R10.2.5: The quotas service caches the member list within the request, using the existing service client.

Rationale: keeping quotas behaviour in one place avoids drift between clients. See also section 5.

| Case | Behaviour | Notes |
|---|---|---|
| C10.2.1 | caches the search index entry | all plans |
| C10.2.2 | lists the thumbnail | all plans |
| C10.2.3 | paginates the search index entry | all plans |
| C10.2.4 | validates the search index entry | configurable |

Note 10.2.1: the quotas service stores the permission set and emits an event for downstream consumers.
Note 10.2.2: the quotas service retries the quota counter and records the outcome in the audit log.
Note 10.2.3: the quotas service renders the sync cursor and returns the result to the caller without blocking the UI.

### 10.3 Quotas: topic 3

- R10.3.1: The quotas service retries the share token and records the outcome in the audit log.
- R10.3.2: The quotas service retries the member list and emits an event for downstream consumers.
- R10.3.3: The quotas service lists the search index entry and emits an event for downstream consumers.
- R10.3.4: The quotas service signs the share token and keeps the behaviour identical across web and desktop clients.
- R10.3.5: The quotas service queues the item metadata and emits an event for downstream consumers.

Rationale: keeping quotas behaviour in one place avoids drift between clients. See also section 16.

| Case | Behaviour | Notes |
|---|---|---|
| C10.3.1 | renders the item metadata | admin only |
| C10.3.2 | signs the thumbnail | configurable |
| C10.3.3 | validates the folder tree | admin only |
| C10.3.4 | renders the search index entry | all plans |

Note 10.3.1: the quotas service signs the thumbnail and keeps the behaviour identical across web and desktop clients.
Note 10.3.2: the quotas service logs the folder tree within the request, using the existing service client.
Note 10.3.3: the quotas service queues the folder tree and records the outcome in the audit log.

### 10.4 Quotas: topic 4

- R10.4.1: The quotas service retries the member list and returns the result to the caller without blocking the UI.
- R10.4.2: The quotas service stores the sync cursor and surfaces a retryable error when the dependency is unavailable.
- R10.4.3: The quotas service renders the search index entry and records the outcome in the audit log.
- R10.4.4: The quotas service lists the activity entry and records the outcome in the audit log.
- R10.4.5: The quotas service retries the sync cursor within the request, using the existing service client.

Rationale: keeping quotas behaviour in one place avoids drift between clients. See also section 1.

| Case | Behaviour | Notes |
|---|---|---|
| C10.4.1 | renders the sync cursor | all plans |
| C10.4.2 | queues the search index entry | admin only |
| C10.4.3 | renders the thumbnail | admin only |
| C10.4.4 | retries the folder tree | configurable |

Note 10.4.1: the quotas service retries the member list and returns the result to the caller without blocking the UI.
Note 10.4.2: the quotas service stores the share token within the request, using the existing service client.
Note 10.4.3: the quotas service validates the member list and keeps the behaviour identical across web and desktop clients.

### 10.5 Quotas: topic 5

- R10.5.1: The quotas service signs the thumbnail and returns the result to the caller without blocking the UI.
- R10.5.2: The quotas service queues the sync cursor and emits an event for downstream consumers.
- R10.5.3: The quotas service caches the folder tree and keeps the behaviour identical across web and desktop clients.
- R10.5.4: The quotas service stores the member list and records the outcome in the audit log.
- R10.5.5: The quotas service validates the activity entry and keeps the behaviour identical across web and desktop clients.

Rationale: keeping quotas behaviour in one place avoids drift between clients. See also section 13.

| Case | Behaviour | Notes |
|---|---|---|
| C10.5.1 | caches the sync cursor | configurable |
| C10.5.2 | logs the item metadata | admin only |
| C10.5.3 | queues the thumbnail | admin only |
| C10.5.4 | queues the member list | all plans |

Note 10.5.1: the quotas service retries the search index entry and keeps the behaviour identical across web and desktop clients.
Note 10.5.2: the quotas service renders the quota counter and returns the result to the caller without blocking the UI.
Note 10.5.3: the quotas service caches the sync cursor within the request, using the existing service client.

## 11. Sync clients

This section describes how sync clients behave in Harbor Drive and how they interact with the rest of the platform.

### 11.1 Sync clients: topic 1

- R11.1.1: The sync clients service renders the search index entry and records the outcome in the audit log.
- R11.1.2: The sync clients service stores the folder tree and records the outcome in the audit log.
- R11.1.3: The sync clients service paginates the item metadata and keeps the behaviour identical across web and desktop clients.
- R11.1.4: The sync clients service lists the thumbnail within the request, using the existing service client.
- R11.1.5: The sync clients service caches the activity entry and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping sync clients behaviour in one place avoids drift between clients. See also section 4.

| Case | Behaviour | Notes |
|---|---|---|
| C11.1.1 | paginates the share token | configurable |
| C11.1.2 | stores the member list | admin only |
| C11.1.3 | stores the thumbnail | all plans |
| C11.1.4 | signs the share token | default |

Note 11.1.1: the sync clients service signs the activity entry and returns the result to the caller without blocking the UI.
Note 11.1.2: the sync clients service logs the thumbnail and surfaces a retryable error when the dependency is unavailable.
Note 11.1.3: the sync clients service renders the member list and keeps the behaviour identical across web and desktop clients.

### 11.2 Sync clients: topic 2

- R11.2.1: The sync clients service renders the folder tree within the request, using the existing service client.
- R11.2.2: The sync clients service caches the sync cursor and returns the result to the caller without blocking the UI.
- R11.2.3: The sync clients service stores the member list and emits an event for downstream consumers.
- R11.2.4: The sync clients service signs the item metadata and emits an event for downstream consumers.
- R11.2.5: The sync clients service logs the share token and keeps the behaviour identical across web and desktop clients.

Rationale: keeping sync clients behaviour in one place avoids drift between clients. See also section 16.

| Case | Behaviour | Notes |
|---|---|---|
| C11.2.1 | validates the member list | configurable |
| C11.2.2 | signs the search index entry | default |
| C11.2.3 | stores the quota counter | all plans |
| C11.2.4 | paginates the member list | admin only |

Note 11.2.1: the sync clients service logs the quota counter and emits an event for downstream consumers.
Note 11.2.2: the sync clients service retries the permission set and returns the result to the caller without blocking the UI.
Note 11.2.3: the sync clients service queues the item metadata within the request, using the existing service client.

### 11.3 Sync clients: topic 3

- R11.3.1: The sync clients service paginates the item metadata and keeps the behaviour identical across web and desktop clients.
- R11.3.2: The sync clients service queues the permission set and surfaces a retryable error when the dependency is unavailable.
- R11.3.3: The sync clients service logs the member list and returns the result to the caller without blocking the UI.
- R11.3.4: The sync clients service lists the thumbnail and keeps the behaviour identical across web and desktop clients.
- R11.3.5: The sync clients service retries the share token and records the outcome in the audit log.

Rationale: keeping sync clients behaviour in one place avoids drift between clients. See also section 4.

| Case | Behaviour | Notes |
|---|---|---|
| C11.3.1 | queues the quota counter | all plans |
| C11.3.2 | signs the folder tree | configurable |
| C11.3.3 | caches the sync cursor | admin only |
| C11.3.4 | retries the activity entry | default |

Note 11.3.1: the sync clients service caches the activity entry and records the outcome in the audit log.
Note 11.3.2: the sync clients service logs the sync cursor and records the outcome in the audit log.
Note 11.3.3: the sync clients service signs the activity entry and surfaces a retryable error when the dependency is unavailable.

### 11.4 Sync clients: topic 4

- R11.4.1: The sync clients service queues the thumbnail and keeps the behaviour identical across web and desktop clients.
- R11.4.2: The sync clients service logs the permission set and records the outcome in the audit log.
- R11.4.3: The sync clients service validates the quota counter and keeps the behaviour identical across web and desktop clients.
- R11.4.4: The sync clients service caches the share token and surfaces a retryable error when the dependency is unavailable.
- R11.4.5: The sync clients service renders the item metadata and emits an event for downstream consumers.

Rationale: keeping sync clients behaviour in one place avoids drift between clients. See also section 18.

| Case | Behaviour | Notes |
|---|---|---|
| C11.4.1 | retries the folder tree | default |
| C11.4.2 | retries the activity entry | default |
| C11.4.3 | lists the item metadata | configurable |
| C11.4.4 | logs the search index entry | default |

Note 11.4.1: the sync clients service signs the folder tree and surfaces a retryable error when the dependency is unavailable.
Note 11.4.2: the sync clients service retries the search index entry and returns the result to the caller without blocking the UI.
Note 11.4.3: the sync clients service paginates the permission set and returns the result to the caller without blocking the UI.

### 11.5 Sync clients: topic 5

- R11.5.1: The sync clients service lists the member list and keeps the behaviour identical across web and desktop clients.
- R11.5.2: The sync clients service stores the permission set and keeps the behaviour identical across web and desktop clients.
- R11.5.3: The sync clients service stores the item metadata and emits an event for downstream consumers.
- R11.5.4: The sync clients service renders the item metadata and records the outcome in the audit log.
- R11.5.5: The sync clients service stores the activity entry and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping sync clients behaviour in one place avoids drift between clients. See also section 9.

| Case | Behaviour | Notes |
|---|---|---|
| C11.5.1 | caches the share token | all plans |
| C11.5.2 | lists the quota counter | default |
| C11.5.3 | retries the search index entry | default |
| C11.5.4 | logs the search index entry | default |

Note 11.5.1: the sync clients service renders the sync cursor and surfaces a retryable error when the dependency is unavailable.
Note 11.5.2: the sync clients service retries the member list within the request, using the existing service client.
Note 11.5.3: the sync clients service lists the sync cursor and surfaces a retryable error when the dependency is unavailable.

## 12. Public API

This section describes how public api behave in Harbor Drive and how they interact with the rest of the platform.

### 12.1 Public API: topic 1

- R12.1.1: The public api service paginates the share token and emits an event for downstream consumers.
- R12.1.2: The public api service retries the folder tree within the request, using the existing service client.
- R12.1.3: The public api service renders the member list and returns the result to the caller without blocking the UI.
- R12.1.4: The public api service stores the item metadata and emits an event for downstream consumers.
- R12.1.5: The public api service lists the item metadata and keeps the behaviour identical across web and desktop clients.

Rationale: keeping public api behaviour in one place avoids drift between clients. See also section 4.

| Case | Behaviour | Notes |
|---|---|---|
| C12.1.1 | renders the thumbnail | default |
| C12.1.2 | stores the member list | default |
| C12.1.3 | caches the search index entry | configurable |
| C12.1.4 | logs the share token | default |

Note 12.1.1: the public api service queues the share token and keeps the behaviour identical across web and desktop clients.
Note 12.1.2: the public api service renders the activity entry and keeps the behaviour identical across web and desktop clients.
Note 12.1.3: the public api service signs the member list and emits an event for downstream consumers.

### 12.2 Public API: topic 2

- R12.2.1: The public api service caches the item metadata and keeps the behaviour identical across web and desktop clients.
- R12.2.2: The public api service lists the item metadata within the request, using the existing service client.
- R12.2.3: The public api service lists the search index entry within the request, using the existing service client.
- R12.2.4: The public api service retries the activity entry and records the outcome in the audit log.
- R12.2.5: The public api service paginates the share token and emits an event for downstream consumers.

Rationale: keeping public api behaviour in one place avoids drift between clients. See also section 20.

| Case | Behaviour | Notes |
|---|---|---|
| C12.2.1 | lists the quota counter | admin only |
| C12.2.2 | paginates the member list | all plans |
| C12.2.3 | stores the share token | default |
| C12.2.4 | queues the share token | all plans |

Note 12.2.1: the public api service logs the sync cursor and emits an event for downstream consumers.
Note 12.2.2: the public api service caches the search index entry and records the outcome in the audit log.
Note 12.2.3: the public api service caches the activity entry within the request, using the existing service client.

### 12.3 Public API: topic 3

- R12.3.1: The public api service paginates the search index entry and records the outcome in the audit log.
- R12.3.2: The public api service paginates the item metadata and returns the result to the caller without blocking the UI.
- R12.3.3: The public api service paginates the activity entry and surfaces a retryable error when the dependency is unavailable.
- R12.3.4: The public api service retries the thumbnail and emits an event for downstream consumers.
- R12.3.5: The public api service retries the sync cursor and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping public api behaviour in one place avoids drift between clients. See also section 8.

| Case | Behaviour | Notes |
|---|---|---|
| C12.3.1 | logs the activity entry | default |
| C12.3.2 | queues the activity entry | admin only |
| C12.3.3 | retries the share token | default |
| C12.3.4 | caches the share token | configurable |

Note 12.3.1: the public api service caches the folder tree and keeps the behaviour identical across web and desktop clients.
Note 12.3.2: the public api service logs the quota counter and surfaces a retryable error when the dependency is unavailable.
Note 12.3.3: the public api service renders the folder tree and surfaces a retryable error when the dependency is unavailable.

### 12.4 Public API: topic 4

- R12.4.1: The public api service logs the sync cursor and returns the result to the caller without blocking the UI.
- R12.4.2: The public api service validates the activity entry and surfaces a retryable error when the dependency is unavailable.
- R12.4.3: The public api service lists the sync cursor and emits an event for downstream consumers.
- R12.4.4: The public api service validates the activity entry and surfaces a retryable error when the dependency is unavailable.
- R12.4.5: The public api service lists the sync cursor and emits an event for downstream consumers.

Rationale: keeping public api behaviour in one place avoids drift between clients. See also section 18.

| Case | Behaviour | Notes |
|---|---|---|
| C12.4.1 | renders the folder tree | admin only |
| C12.4.2 | renders the thumbnail | all plans |
| C12.4.3 | paginates the folder tree | admin only |
| C12.4.4 | signs the quota counter | all plans |

Note 12.4.1: the public api service signs the search index entry and returns the result to the caller without blocking the UI.
Note 12.4.2: the public api service validates the thumbnail and returns the result to the caller without blocking the UI.
Note 12.4.3: the public api service renders the share token and keeps the behaviour identical across web and desktop clients.

### 12.5 Public API: topic 5

- R12.5.1: The public api service caches the quota counter and surfaces a retryable error when the dependency is unavailable.
- R12.5.2: The public api service paginates the quota counter and emits an event for downstream consumers.
- R12.5.3: The public api service signs the share token and returns the result to the caller without blocking the UI.
- R12.5.4: The public api service lists the member list and records the outcome in the audit log.
- R12.5.5: The public api service renders the quota counter and keeps the behaviour identical across web and desktop clients.

Rationale: keeping public api behaviour in one place avoids drift between clients. See also section 15.

| Case | Behaviour | Notes |
|---|---|---|
| C12.5.1 | renders the share token | admin only |
| C12.5.2 | paginates the item metadata | admin only |
| C12.5.3 | caches the folder tree | default |
| C12.5.4 | renders the item metadata | configurable |

Note 12.5.1: the public api service paginates the member list and surfaces a retryable error when the dependency is unavailable.
Note 12.5.2: the public api service paginates the thumbnail and records the outcome in the audit log.
Note 12.5.3: the public api service caches the sync cursor within the request, using the existing service client.

## 13. Billing integration

This section describes how billing integration behave in Harbor Drive and how they interact with the rest of the platform.

### 13.1 Billing integration: topic 1

- R13.1.1: The billing integration service logs the search index entry and surfaces a retryable error when the dependency is unavailable.
- R13.1.2: The billing integration service stores the activity entry within the request, using the existing service client.
- R13.1.3: The billing integration service queues the thumbnail and returns the result to the caller without blocking the UI.
- R13.1.4: The billing integration service retries the permission set within the request, using the existing service client.
- R13.1.5: The billing integration service lists the item metadata and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping billing integration behaviour in one place avoids drift between clients. See also section 12.

| Case | Behaviour | Notes |
|---|---|---|
| C13.1.1 | logs the member list | default |
| C13.1.2 | paginates the sync cursor | default |
| C13.1.3 | renders the activity entry | admin only |
| C13.1.4 | paginates the thumbnail | default |

Note 13.1.1: the billing integration service signs the sync cursor and returns the result to the caller without blocking the UI.
Note 13.1.2: the billing integration service logs the share token and records the outcome in the audit log.
Note 13.1.3: the billing integration service validates the thumbnail and returns the result to the caller without blocking the UI.

### 13.2 Billing integration: topic 2

- R13.2.1: The billing integration service lists the activity entry and records the outcome in the audit log.
- R13.2.2: The billing integration service lists the folder tree within the request, using the existing service client.
- R13.2.3: The billing integration service lists the activity entry and surfaces a retryable error when the dependency is unavailable.
- R13.2.4: The billing integration service logs the item metadata within the request, using the existing service client.
- R13.2.5: The billing integration service stores the quota counter within the request, using the existing service client.

Rationale: keeping billing integration behaviour in one place avoids drift between clients. See also section 7.

| Case | Behaviour | Notes |
|---|---|---|
| C13.2.1 | caches the search index entry | all plans |
| C13.2.2 | renders the member list | admin only |
| C13.2.3 | queues the activity entry | all plans |
| C13.2.4 | renders the quota counter | all plans |

Note 13.2.1: the billing integration service retries the share token and emits an event for downstream consumers.
Note 13.2.2: the billing integration service validates the share token and keeps the behaviour identical across web and desktop clients.
Note 13.2.3: the billing integration service lists the member list and keeps the behaviour identical across web and desktop clients.

### 13.3 Billing integration: topic 3

- R13.3.1: The billing integration service validates the item metadata and returns the result to the caller without blocking the UI.
- R13.3.2: The billing integration service validates the permission set and surfaces a retryable error when the dependency is unavailable.
- R13.3.3: The billing integration service queues the share token and emits an event for downstream consumers.
- R13.3.4: The billing integration service renders the sync cursor within the request, using the existing service client.
- R13.3.5: The billing integration service renders the member list and records the outcome in the audit log.

Rationale: keeping billing integration behaviour in one place avoids drift between clients. See also section 11.

| Case | Behaviour | Notes |
|---|---|---|
| C13.3.1 | validates the member list | default |
| C13.3.2 | queues the share token | admin only |
| C13.3.3 | validates the item metadata | configurable |
| C13.3.4 | logs the folder tree | configurable |

Note 13.3.1: the billing integration service logs the share token and records the outcome in the audit log.
Note 13.3.2: the billing integration service retries the sync cursor and returns the result to the caller without blocking the UI.
Note 13.3.3: the billing integration service stores the item metadata and records the outcome in the audit log.

### 13.4 Billing integration: topic 4

- R13.4.1: The billing integration service paginates the activity entry and records the outcome in the audit log.
- R13.4.2: The billing integration service stores the activity entry and emits an event for downstream consumers.
- R13.4.3: The billing integration service renders the quota counter and emits an event for downstream consumers.
- R13.4.4: The billing integration service logs the permission set and returns the result to the caller without blocking the UI.
- R13.4.5: The billing integration service signs the item metadata and keeps the behaviour identical across web and desktop clients.

Rationale: keeping billing integration behaviour in one place avoids drift between clients. See also section 7.

| Case | Behaviour | Notes |
|---|---|---|
| C13.4.1 | signs the member list | admin only |
| C13.4.2 | renders the activity entry | configurable |
| C13.4.3 | queues the sync cursor | admin only |
| C13.4.4 | validates the thumbnail | default |

Note 13.4.1: the billing integration service retries the activity entry and emits an event for downstream consumers.
Note 13.4.2: the billing integration service stores the item metadata and keeps the behaviour identical across web and desktop clients.
Note 13.4.3: the billing integration service caches the share token and keeps the behaviour identical across web and desktop clients.

### 13.5 Billing integration: topic 5

- R13.5.1: The billing integration service lists the member list and surfaces a retryable error when the dependency is unavailable.
- R13.5.2: The billing integration service queues the folder tree and returns the result to the caller without blocking the UI.
- R13.5.3: The billing integration service logs the item metadata and surfaces a retryable error when the dependency is unavailable.
- R13.5.4: The billing integration service caches the share token and records the outcome in the audit log.
- R13.5.5: The billing integration service retries the item metadata and emits an event for downstream consumers.

Rationale: keeping billing integration behaviour in one place avoids drift between clients. See also section 7.

| Case | Behaviour | Notes |
|---|---|---|
| C13.5.1 | caches the search index entry | configurable |
| C13.5.2 | stores the share token | configurable |
| C13.5.3 | stores the thumbnail | default |
| C13.5.4 | renders the search index entry | all plans |

Note 13.5.1: the billing integration service caches the share token and returns the result to the caller without blocking the UI.
Note 13.5.2: the billing integration service stores the search index entry and keeps the behaviour identical across web and desktop clients.
Note 13.5.3: the billing integration service validates the search index entry and records the outcome in the audit log.

## 14. Admin console

This section describes how admin console behave in Harbor Drive and how they interact with the rest of the platform.

### 14.1 Admin console: topic 1

- R14.1.1: The admin console service validates the item metadata within the request, using the existing service client.
- R14.1.2: The admin console service signs the sync cursor and keeps the behaviour identical across web and desktop clients.
- R14.1.3: The admin console service lists the folder tree and records the outcome in the audit log.
- R14.1.4: The admin console service queues the activity entry and keeps the behaviour identical across web and desktop clients.
- R14.1.5: The admin console service logs the permission set within the request, using the existing service client.

Rationale: keeping admin console behaviour in one place avoids drift between clients. See also section 14.

| Case | Behaviour | Notes |
|---|---|---|
| C14.1.1 | logs the share token | admin only |
| C14.1.2 | validates the share token | admin only |
| C14.1.3 | lists the share token | admin only |
| C14.1.4 | paginates the search index entry | default |

Note 14.1.1: the admin console service queues the folder tree and emits an event for downstream consumers.
Note 14.1.2: the admin console service signs the permission set within the request, using the existing service client.
Note 14.1.3: the admin console service queues the thumbnail and records the outcome in the audit log.

### 14.2 Admin console: topic 2

- R14.2.1: The admin console service retries the search index entry within the request, using the existing service client.
- R14.2.2: The admin console service caches the permission set and keeps the behaviour identical across web and desktop clients.
- R14.2.3: The admin console service logs the member list and surfaces a retryable error when the dependency is unavailable.
- R14.2.4: The admin console service lists the folder tree and surfaces a retryable error when the dependency is unavailable.
- R14.2.5: The admin console service stores the item metadata and returns the result to the caller without blocking the UI.

Rationale: keeping admin console behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C14.2.1 | validates the search index entry | configurable |
| C14.2.2 | stores the permission set | admin only |
| C14.2.3 | caches the folder tree | default |
| C14.2.4 | lists the permission set | configurable |

Note 14.2.1: the admin console service caches the item metadata and surfaces a retryable error when the dependency is unavailable.
Note 14.2.2: the admin console service paginates the member list and surfaces a retryable error when the dependency is unavailable.
Note 14.2.3: the admin console service validates the member list within the request, using the existing service client.

### 14.3 Admin console: topic 3

- R14.3.1: The admin console service queues the permission set and keeps the behaviour identical across web and desktop clients.
- R14.3.2: The admin console service stores the item metadata and records the outcome in the audit log.
- R14.3.3: The admin console service renders the member list and emits an event for downstream consumers.
- R14.3.4: The admin console service paginates the folder tree and records the outcome in the audit log.
- R14.3.5: The admin console service renders the permission set within the request, using the existing service client.

Rationale: keeping admin console behaviour in one place avoids drift between clients. See also section 13.

| Case | Behaviour | Notes |
|---|---|---|
| C14.3.1 | stores the folder tree | configurable |
| C14.3.2 | validates the share token | all plans |
| C14.3.3 | retries the share token | default |
| C14.3.4 | retries the sync cursor | default |

Note 14.3.1: the admin console service retries the item metadata and records the outcome in the audit log.
Note 14.3.2: the admin console service queues the sync cursor and returns the result to the caller without blocking the UI.
Note 14.3.3: the admin console service queues the sync cursor and surfaces a retryable error when the dependency is unavailable.

### 14.4 Admin console: topic 4

- R14.4.1: The admin console service queues the sync cursor and surfaces a retryable error when the dependency is unavailable.
- R14.4.2: The admin console service lists the quota counter and surfaces a retryable error when the dependency is unavailable.
- R14.4.3: The admin console service stores the quota counter and returns the result to the caller without blocking the UI.
- R14.4.4: The admin console service retries the item metadata and records the outcome in the audit log.
- R14.4.5: The admin console service renders the folder tree and returns the result to the caller without blocking the UI.

Rationale: keeping admin console behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C14.4.1 | queues the sync cursor | configurable |
| C14.4.2 | signs the item metadata | configurable |
| C14.4.3 | stores the sync cursor | all plans |
| C14.4.4 | logs the item metadata | default |

Note 14.4.1: the admin console service lists the search index entry and records the outcome in the audit log.
Note 14.4.2: the admin console service paginates the activity entry and keeps the behaviour identical across web and desktop clients.
Note 14.4.3: the admin console service signs the item metadata and surfaces a retryable error when the dependency is unavailable.

### 14.5 Admin console: topic 5

- R14.5.1: The admin console service renders the activity entry within the request, using the existing service client.
- R14.5.2: The admin console service signs the item metadata and emits an event for downstream consumers.
- R14.5.3: The admin console service validates the item metadata and records the outcome in the audit log.
- R14.5.4: The admin console service renders the activity entry and records the outcome in the audit log.
- R14.5.5: The admin console service stores the permission set within the request, using the existing service client.

Rationale: keeping admin console behaviour in one place avoids drift between clients. See also section 20.

| Case | Behaviour | Notes |
|---|---|---|
| C14.5.1 | signs the activity entry | default |
| C14.5.2 | logs the search index entry | configurable |
| C14.5.3 | logs the permission set | configurable |
| C14.5.4 | caches the sync cursor | admin only |

Note 14.5.1: the admin console service caches the thumbnail and keeps the behaviour identical across web and desktop clients.
Note 14.5.2: the admin console service renders the folder tree and records the outcome in the audit log.
Note 14.5.3: the admin console service logs the search index entry and keeps the behaviour identical across web and desktop clients.

## 15. Mobile clients

This section describes how mobile clients behave in Harbor Drive and how they interact with the rest of the platform.

### 15.1 Mobile clients: topic 1

- R15.1.1: The mobile clients service paginates the thumbnail and keeps the behaviour identical across web and desktop clients.
- R15.1.2: The mobile clients service retries the thumbnail and surfaces a retryable error when the dependency is unavailable.
- R15.1.3: The mobile clients service queues the member list and surfaces a retryable error when the dependency is unavailable.
- R15.1.4: The mobile clients service caches the search index entry and emits an event for downstream consumers.
- R15.1.5: The mobile clients service logs the activity entry within the request, using the existing service client.

Rationale: keeping mobile clients behaviour in one place avoids drift between clients. See also section 8.

| Case | Behaviour | Notes |
|---|---|---|
| C15.1.1 | queues the thumbnail | configurable |
| C15.1.2 | signs the folder tree | all plans |
| C15.1.3 | paginates the sync cursor | default |
| C15.1.4 | queues the share token | configurable |

Note 15.1.1: the mobile clients service queues the folder tree and records the outcome in the audit log.
Note 15.1.2: the mobile clients service logs the activity entry and records the outcome in the audit log.
Note 15.1.3: the mobile clients service validates the activity entry within the request, using the existing service client.

### 15.2 Mobile clients: topic 2

- R15.2.1: The mobile clients service lists the share token and surfaces a retryable error when the dependency is unavailable.
- R15.2.2: The mobile clients service renders the search index entry and records the outcome in the audit log.
- R15.2.3: The mobile clients service logs the item metadata and surfaces a retryable error when the dependency is unavailable.
- R15.2.4: The mobile clients service retries the member list and records the outcome in the audit log.
- R15.2.5: The mobile clients service renders the folder tree and returns the result to the caller without blocking the UI.

Rationale: keeping mobile clients behaviour in one place avoids drift between clients. See also section 5.

| Case | Behaviour | Notes |
|---|---|---|
| C15.2.1 | retries the quota counter | admin only |
| C15.2.2 | stores the thumbnail | admin only |
| C15.2.3 | signs the permission set | all plans |
| C15.2.4 | caches the share token | all plans |

Note 15.2.1: the mobile clients service renders the item metadata and emits an event for downstream consumers.
Note 15.2.2: the mobile clients service signs the search index entry within the request, using the existing service client.
Note 15.2.3: the mobile clients service logs the sync cursor and surfaces a retryable error when the dependency is unavailable.

### 15.3 Mobile clients: topic 3

- R15.3.1: The mobile clients service stores the sync cursor and records the outcome in the audit log.
- R15.3.2: The mobile clients service paginates the search index entry within the request, using the existing service client.
- R15.3.3: The mobile clients service retries the member list and keeps the behaviour identical across web and desktop clients.
- R15.3.4: The mobile clients service logs the activity entry and keeps the behaviour identical across web and desktop clients.
- R15.3.5: The mobile clients service queues the activity entry and records the outcome in the audit log.

Rationale: keeping mobile clients behaviour in one place avoids drift between clients. See also section 13.

| Case | Behaviour | Notes |
|---|---|---|
| C15.3.1 | signs the folder tree | all plans |
| C15.3.2 | queues the item metadata | all plans |
| C15.3.3 | retries the member list | admin only |
| C15.3.4 | stores the folder tree | admin only |

Note 15.3.1: the mobile clients service stores the sync cursor and surfaces a retryable error when the dependency is unavailable.
Note 15.3.2: the mobile clients service retries the search index entry and returns the result to the caller without blocking the UI.
Note 15.3.3: the mobile clients service renders the quota counter and records the outcome in the audit log.

### 15.4 Mobile clients: topic 4

- R15.4.1: The mobile clients service paginates the thumbnail and records the outcome in the audit log.
- R15.4.2: The mobile clients service validates the sync cursor within the request, using the existing service client.
- R15.4.3: The mobile clients service lists the item metadata and records the outcome in the audit log.
- R15.4.4: The mobile clients service paginates the member list and records the outcome in the audit log.
- R15.4.5: The mobile clients service signs the activity entry and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping mobile clients behaviour in one place avoids drift between clients. See also section 20.

| Case | Behaviour | Notes |
|---|---|---|
| C15.4.1 | retries the folder tree | all plans |
| C15.4.2 | retries the member list | admin only |
| C15.4.3 | lists the search index entry | admin only |
| C15.4.4 | logs the item metadata | default |

Note 15.4.1: the mobile clients service signs the thumbnail within the request, using the existing service client.
Note 15.4.2: the mobile clients service retries the quota counter and surfaces a retryable error when the dependency is unavailable.
Note 15.4.3: the mobile clients service retries the folder tree and surfaces a retryable error when the dependency is unavailable.

### 15.5 Mobile clients: topic 5

- R15.5.1: The mobile clients service stores the thumbnail and emits an event for downstream consumers.
- R15.5.2: The mobile clients service logs the sync cursor and emits an event for downstream consumers.
- R15.5.3: The mobile clients service paginates the search index entry and records the outcome in the audit log.
- R15.5.4: The mobile clients service signs the permission set and returns the result to the caller without blocking the UI.
- R15.5.5: The mobile clients service queues the quota counter and records the outcome in the audit log.

Rationale: keeping mobile clients behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C15.5.1 | caches the folder tree | configurable |
| C15.5.2 | renders the activity entry | admin only |
| C15.5.3 | signs the sync cursor | configurable |
| C15.5.4 | signs the activity entry | configurable |

Note 15.5.1: the mobile clients service signs the thumbnail and emits an event for downstream consumers.
Note 15.5.2: the mobile clients service stores the item metadata and keeps the behaviour identical across web and desktop clients.
Note 15.5.3: the mobile clients service paginates the search index entry within the request, using the existing service client.

## 16. Offline mode

This section describes how offline mode behave in Harbor Drive and how they interact with the rest of the platform.

### 16.1 Offline mode: topic 1

- R16.1.1: The offline mode service queues the search index entry and keeps the behaviour identical across web and desktop clients.
- R16.1.2: The offline mode service lists the sync cursor within the request, using the existing service client.
- R16.1.3: The offline mode service lists the activity entry and keeps the behaviour identical across web and desktop clients.
- R16.1.4: The offline mode service signs the item metadata and records the outcome in the audit log.
- R16.1.5: The offline mode service retries the permission set and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping offline mode behaviour in one place avoids drift between clients. See also section 1.

| Case | Behaviour | Notes |
|---|---|---|
| C16.1.1 | lists the thumbnail | configurable |
| C16.1.2 | logs the folder tree | admin only |
| C16.1.3 | signs the folder tree | configurable |
| C16.1.4 | paginates the thumbnail | all plans |

Note 16.1.1: the offline mode service paginates the permission set and returns the result to the caller without blocking the UI.
Note 16.1.2: the offline mode service stores the folder tree and surfaces a retryable error when the dependency is unavailable.
Note 16.1.3: the offline mode service renders the item metadata within the request, using the existing service client.

### 16.2 Offline mode: topic 2

- R16.2.1: The offline mode service renders the share token and surfaces a retryable error when the dependency is unavailable.
- R16.2.2: The offline mode service logs the member list and surfaces a retryable error when the dependency is unavailable.
- R16.2.3: The offline mode service retries the item metadata and keeps the behaviour identical across web and desktop clients.
- R16.2.4: The offline mode service lists the search index entry and records the outcome in the audit log.
- R16.2.5: The offline mode service stores the thumbnail and records the outcome in the audit log.

Rationale: keeping offline mode behaviour in one place avoids drift between clients. See also section 9.

| Case | Behaviour | Notes |
|---|---|---|
| C16.2.1 | stores the item metadata | admin only |
| C16.2.2 | renders the search index entry | default |
| C16.2.3 | queues the thumbnail | all plans |
| C16.2.4 | paginates the sync cursor | default |

Note 16.2.1: the offline mode service lists the thumbnail and emits an event for downstream consumers.
Note 16.2.2: the offline mode service paginates the item metadata and emits an event for downstream consumers.
Note 16.2.3: the offline mode service lists the search index entry and returns the result to the caller without blocking the UI.

### 16.3 Offline mode: topic 3

- R16.3.1: The offline mode service validates the thumbnail within the request, using the existing service client.
- R16.3.2: The offline mode service stores the search index entry and returns the result to the caller without blocking the UI.
- R16.3.3: The offline mode service queues the item metadata and emits an event for downstream consumers.
- R16.3.4: The offline mode service caches the sync cursor and surfaces a retryable error when the dependency is unavailable.
- R16.3.5: The offline mode service caches the member list within the request, using the existing service client.

Rationale: keeping offline mode behaviour in one place avoids drift between clients. See also section 8.

| Case | Behaviour | Notes |
|---|---|---|
| C16.3.1 | retries the search index entry | configurable |
| C16.3.2 | retries the activity entry | all plans |
| C16.3.3 | logs the item metadata | configurable |
| C16.3.4 | renders the share token | configurable |

Note 16.3.1: the offline mode service queues the sync cursor and returns the result to the caller without blocking the UI.
Note 16.3.2: the offline mode service lists the activity entry and emits an event for downstream consumers.
Note 16.3.3: the offline mode service signs the quota counter within the request, using the existing service client.

### 16.4 Offline mode: topic 4

- R16.4.1: The offline mode service queues the folder tree and emits an event for downstream consumers.
- R16.4.2: The offline mode service queues the sync cursor and keeps the behaviour identical across web and desktop clients.
- R16.4.3: The offline mode service renders the permission set and emits an event for downstream consumers.
- R16.4.4: The offline mode service queues the folder tree and returns the result to the caller without blocking the UI.
- R16.4.5: The offline mode service retries the thumbnail and emits an event for downstream consumers.

Rationale: keeping offline mode behaviour in one place avoids drift between clients. See also section 10.

| Case | Behaviour | Notes |
|---|---|---|
| C16.4.1 | queues the thumbnail | all plans |
| C16.4.2 | lists the activity entry | default |
| C16.4.3 | queues the share token | configurable |
| C16.4.4 | stores the permission set | configurable |

Note 16.4.1: the offline mode service caches the folder tree and returns the result to the caller without blocking the UI.
Note 16.4.2: the offline mode service signs the member list and emits an event for downstream consumers.
Note 16.4.3: the offline mode service validates the share token and records the outcome in the audit log.

### 16.5 Offline mode: topic 5

- R16.5.1: The offline mode service queues the thumbnail and keeps the behaviour identical across web and desktop clients.
- R16.5.2: The offline mode service retries the sync cursor and keeps the behaviour identical across web and desktop clients.
- R16.5.3: The offline mode service paginates the thumbnail and records the outcome in the audit log.
- R16.5.4: The offline mode service logs the folder tree and returns the result to the caller without blocking the UI.
- R16.5.5: The offline mode service validates the member list and keeps the behaviour identical across web and desktop clients.

Rationale: keeping offline mode behaviour in one place avoids drift between clients. See also section 5.

| Case | Behaviour | Notes |
|---|---|---|
| C16.5.1 | caches the search index entry | all plans |
| C16.5.2 | paginates the quota counter | configurable |
| C16.5.3 | retries the search index entry | configurable |
| C16.5.4 | stores the permission set | default |

Note 16.5.1: the offline mode service signs the activity entry and keeps the behaviour identical across web and desktop clients.
Note 16.5.2: the offline mode service retries the item metadata and keeps the behaviour identical across web and desktop clients.
Note 16.5.3: the offline mode service paginates the share token and records the outcome in the audit log.

## 17. Versioning

This section describes how versioning behave in Harbor Drive and how they interact with the rest of the platform.

### 17.1 Versioning: topic 1

- R17.1.1: The versioning service lists the sync cursor and keeps the behaviour identical across web and desktop clients.
- R17.1.2: The versioning service renders the share token and returns the result to the caller without blocking the UI.
- R17.1.3: The versioning service queues the thumbnail and keeps the behaviour identical across web and desktop clients.
- R17.1.4: The versioning service renders the permission set and surfaces a retryable error when the dependency is unavailable.
- R17.1.5: The versioning service queues the folder tree and records the outcome in the audit log.

Rationale: keeping versioning behaviour in one place avoids drift between clients. See also section 7.

| Case | Behaviour | Notes |
|---|---|---|
| C17.1.1 | renders the activity entry | default |
| C17.1.2 | validates the activity entry | configurable |
| C17.1.3 | retries the activity entry | admin only |
| C17.1.4 | retries the member list | configurable |

Note 17.1.1: the versioning service caches the share token within the request, using the existing service client.
Note 17.1.2: the versioning service queues the quota counter and emits an event for downstream consumers.
Note 17.1.3: the versioning service lists the member list and returns the result to the caller without blocking the UI.

### 17.2 Versioning: topic 2

- R17.2.1: The versioning service retries the quota counter and keeps the behaviour identical across web and desktop clients.
- R17.2.2: The versioning service renders the share token and records the outcome in the audit log.
- R17.2.3: The versioning service renders the activity entry and surfaces a retryable error when the dependency is unavailable.
- R17.2.4: The versioning service validates the item metadata and emits an event for downstream consumers.
- R17.2.5: The versioning service lists the search index entry and returns the result to the caller without blocking the UI.

Rationale: keeping versioning behaviour in one place avoids drift between clients. See also section 14.

| Case | Behaviour | Notes |
|---|---|---|
| C17.2.1 | validates the activity entry | configurable |
| C17.2.2 | retries the item metadata | admin only |
| C17.2.3 | stores the search index entry | configurable |
| C17.2.4 | paginates the member list | admin only |

Note 17.2.1: the versioning service retries the search index entry and records the outcome in the audit log.
Note 17.2.2: the versioning service lists the permission set and keeps the behaviour identical across web and desktop clients.
Note 17.2.3: the versioning service caches the item metadata and surfaces a retryable error when the dependency is unavailable.

### 17.3 Versioning: topic 3

- R17.3.1: The versioning service paginates the item metadata and returns the result to the caller without blocking the UI.
- R17.3.2: The versioning service renders the item metadata and records the outcome in the audit log.
- R17.3.3: The versioning service validates the quota counter and keeps the behaviour identical across web and desktop clients.
- R17.3.4: The versioning service renders the sync cursor and keeps the behaviour identical across web and desktop clients.
- R17.3.5: The versioning service retries the search index entry and returns the result to the caller without blocking the UI.

Rationale: keeping versioning behaviour in one place avoids drift between clients. See also section 9.

| Case | Behaviour | Notes |
|---|---|---|
| C17.3.1 | signs the permission set | admin only |
| C17.3.2 | retries the member list | admin only |
| C17.3.3 | signs the member list | default |
| C17.3.4 | validates the sync cursor | configurable |

Note 17.3.1: the versioning service logs the thumbnail within the request, using the existing service client.
Note 17.3.2: the versioning service signs the activity entry and returns the result to the caller without blocking the UI.
Note 17.3.3: the versioning service signs the share token and keeps the behaviour identical across web and desktop clients.

### 17.4 Versioning: topic 4

- R17.4.1: The versioning service validates the folder tree and records the outcome in the audit log.
- R17.4.2: The versioning service validates the item metadata and returns the result to the caller without blocking the UI.
- R17.4.3: The versioning service queues the quota counter and emits an event for downstream consumers.
- R17.4.4: The versioning service renders the thumbnail and keeps the behaviour identical across web and desktop clients.
- R17.4.5: The versioning service caches the share token and returns the result to the caller without blocking the UI.

Rationale: keeping versioning behaviour in one place avoids drift between clients. See also section 16.

| Case | Behaviour | Notes |
|---|---|---|
| C17.4.1 | logs the thumbnail | configurable |
| C17.4.2 | lists the folder tree | all plans |
| C17.4.3 | stores the quota counter | admin only |
| C17.4.4 | stores the share token | configurable |

Note 17.4.1: the versioning service queues the permission set and surfaces a retryable error when the dependency is unavailable.
Note 17.4.2: the versioning service retries the share token and keeps the behaviour identical across web and desktop clients.
Note 17.4.3: the versioning service stores the search index entry and emits an event for downstream consumers.

### 17.5 Versioning: topic 5

- R17.5.1: The versioning service retries the thumbnail within the request, using the existing service client.
- R17.5.2: The versioning service caches the item metadata and records the outcome in the audit log.
- R17.5.3: The versioning service logs the thumbnail within the request, using the existing service client.
- R17.5.4: The versioning service lists the activity entry and records the outcome in the audit log.
- R17.5.5: The versioning service validates the permission set and keeps the behaviour identical across web and desktop clients.

Rationale: keeping versioning behaviour in one place avoids drift between clients. See also section 10.

| Case | Behaviour | Notes |
|---|---|---|
| C17.5.1 | logs the permission set | configurable |
| C17.5.2 | queues the member list | all plans |
| C17.5.3 | paginates the quota counter | admin only |
| C17.5.4 | stores the folder tree | default |

Note 17.5.1: the versioning service lists the item metadata and emits an event for downstream consumers.
Note 17.5.2: the versioning service logs the permission set and keeps the behaviour identical across web and desktop clients.
Note 17.5.3: the versioning service queues the search index entry and records the outcome in the audit log.

## 18. Comments

This section describes how comments behave in Harbor Drive and how they interact with the rest of the platform.

### 18.1 Comments: topic 1

- R18.1.1: The comments service renders the member list and emits an event for downstream consumers.
- R18.1.2: The comments service logs the thumbnail and surfaces a retryable error when the dependency is unavailable.
- R18.1.3: The comments service queues the item metadata and records the outcome in the audit log.
- R18.1.4: The comments service renders the activity entry and keeps the behaviour identical across web and desktop clients.
- R18.1.5: The comments service paginates the activity entry and keeps the behaviour identical across web and desktop clients.

Rationale: keeping comments behaviour in one place avoids drift between clients. See also section 8.

| Case | Behaviour | Notes |
|---|---|---|
| C18.1.1 | renders the share token | default |
| C18.1.2 | lists the sync cursor | configurable |
| C18.1.3 | caches the quota counter | configurable |
| C18.1.4 | signs the share token | default |

Note 18.1.1: the comments service caches the search index entry and records the outcome in the audit log.
Note 18.1.2: the comments service retries the share token and keeps the behaviour identical across web and desktop clients.
Note 18.1.3: the comments service queues the quota counter and returns the result to the caller without blocking the UI.

### 18.2 Comments: topic 2

- R18.2.1: The comments service queues the share token and surfaces a retryable error when the dependency is unavailable.
- R18.2.2: The comments service queues the activity entry and returns the result to the caller without blocking the UI.
- R18.2.3: The comments service lists the item metadata within the request, using the existing service client.
- R18.2.4: The comments service paginates the sync cursor within the request, using the existing service client.
- R18.2.5: The comments service validates the member list and emits an event for downstream consumers.

Rationale: keeping comments behaviour in one place avoids drift between clients. See also section 16.

| Case | Behaviour | Notes |
|---|---|---|
| C18.2.1 | stores the activity entry | default |
| C18.2.2 | stores the thumbnail | configurable |
| C18.2.3 | stores the member list | all plans |
| C18.2.4 | renders the item metadata | all plans |

Note 18.2.1: the comments service logs the thumbnail and returns the result to the caller without blocking the UI.
Note 18.2.2: the comments service queues the item metadata within the request, using the existing service client.
Note 18.2.3: the comments service paginates the folder tree and emits an event for downstream consumers.

### 18.3 Comments: topic 3

- R18.3.1: The comments service stores the activity entry within the request, using the existing service client.
- R18.3.2: The comments service lists the folder tree and keeps the behaviour identical across web and desktop clients.
- R18.3.3: The comments service retries the quota counter within the request, using the existing service client.
- R18.3.4: The comments service logs the item metadata and keeps the behaviour identical across web and desktop clients.
- R18.3.5: The comments service stores the share token and emits an event for downstream consumers.

Rationale: keeping comments behaviour in one place avoids drift between clients. See also section 10.

| Case | Behaviour | Notes |
|---|---|---|
| C18.3.1 | lists the member list | admin only |
| C18.3.2 | paginates the thumbnail | all plans |
| C18.3.3 | renders the folder tree | admin only |
| C18.3.4 | signs the member list | all plans |

Note 18.3.1: the comments service signs the share token and emits an event for downstream consumers.
Note 18.3.2: the comments service paginates the search index entry within the request, using the existing service client.
Note 18.3.3: the comments service lists the quota counter and surfaces a retryable error when the dependency is unavailable.

### 18.4 Comments: topic 4

- R18.4.1: The comments service caches the search index entry and surfaces a retryable error when the dependency is unavailable.
- R18.4.2: The comments service retries the quota counter and emits an event for downstream consumers.
- R18.4.3: The comments service stores the activity entry and records the outcome in the audit log.
- R18.4.4: The comments service signs the item metadata and returns the result to the caller without blocking the UI.
- R18.4.5: The comments service validates the member list and keeps the behaviour identical across web and desktop clients.

Rationale: keeping comments behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C18.4.1 | stores the search index entry | admin only |
| C18.4.2 | signs the search index entry | all plans |
| C18.4.3 | queues the folder tree | configurable |
| C18.4.4 | paginates the member list | all plans |

Note 18.4.1: the comments service caches the permission set and returns the result to the caller without blocking the UI.
Note 18.4.2: the comments service stores the thumbnail and surfaces a retryable error when the dependency is unavailable.
Note 18.4.3: the comments service renders the thumbnail and records the outcome in the audit log.

### 18.5 Comments: topic 5

- R18.5.1: The comments service renders the thumbnail and surfaces a retryable error when the dependency is unavailable.
- R18.5.2: The comments service caches the member list and returns the result to the caller without blocking the UI.
- R18.5.3: The comments service signs the member list and returns the result to the caller without blocking the UI.
- R18.5.4: The comments service signs the search index entry and keeps the behaviour identical across web and desktop clients.
- R18.5.5: The comments service renders the folder tree and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping comments behaviour in one place avoids drift between clients. See also section 19.

| Case | Behaviour | Notes |
|---|---|---|
| C18.5.1 | renders the sync cursor | default |
| C18.5.2 | logs the share token | default |
| C18.5.3 | signs the permission set | all plans |
| C18.5.4 | retries the folder tree | configurable |

Note 18.5.1: the comments service validates the search index entry and emits an event for downstream consumers.
Note 18.5.2: the comments service renders the share token and records the outcome in the audit log.
Note 18.5.3: the comments service paginates the item metadata and emits an event for downstream consumers.

## 19. Trash and restore

This section describes how trash and restore behave in Harbor Drive and how they interact with the rest of the platform.

### 19.1 Trash and restore: topic 1

- R19.1.1: The trash and restore service validates the item metadata and records the outcome in the audit log.
- R19.1.2: The trash and restore service lists the item metadata and keeps the behaviour identical across web and desktop clients.
- R19.1.3: The trash and restore service paginates the thumbnail and emits an event for downstream consumers.
- R19.1.4: The trash and restore service caches the permission set and keeps the behaviour identical across web and desktop clients.
- R19.1.5: The trash and restore service stores the sync cursor within the request, using the existing service client.

Rationale: keeping trash and restore behaviour in one place avoids drift between clients. See also section 20.

| Case | Behaviour | Notes |
|---|---|---|
| C19.1.1 | validates the search index entry | default |
| C19.1.2 | queues the share token | admin only |
| C19.1.3 | queues the item metadata | admin only |
| C19.1.4 | renders the thumbnail | admin only |

Note 19.1.1: the trash and restore service signs the folder tree and records the outcome in the audit log.
Note 19.1.2: the trash and restore service logs the item metadata and surfaces a retryable error when the dependency is unavailable.
Note 19.1.3: the trash and restore service queues the permission set and records the outcome in the audit log.

### 19.2 Trash and restore: topic 2

- R19.2.1: The trash and restore service signs the quota counter and surfaces a retryable error when the dependency is unavailable.
- R19.2.2: The trash and restore service renders the item metadata and keeps the behaviour identical across web and desktop clients.
- R19.2.3: The trash and restore service validates the activity entry and records the outcome in the audit log.
- R19.2.4: The trash and restore service validates the member list within the request, using the existing service client.
- R19.2.5: The trash and restore service paginates the member list within the request, using the existing service client.

Rationale: keeping trash and restore behaviour in one place avoids drift between clients. See also section 1.

| Case | Behaviour | Notes |
|---|---|---|
| C19.2.1 | logs the permission set | default |
| C19.2.2 | caches the share token | configurable |
| C19.2.3 | signs the activity entry | all plans |
| C19.2.4 | stores the search index entry | admin only |

Note 19.2.1: the trash and restore service signs the activity entry and emits an event for downstream consumers.
Note 19.2.2: the trash and restore service lists the item metadata and records the outcome in the audit log.
Note 19.2.3: the trash and restore service stores the member list and surfaces a retryable error when the dependency is unavailable.

### 19.3 Trash and restore: topic 3

- R19.3.1: The trash and restore service logs the item metadata within the request, using the existing service client.
- R19.3.2: The trash and restore service renders the share token and surfaces a retryable error when the dependency is unavailable.
- R19.3.3: The trash and restore service paginates the sync cursor and emits an event for downstream consumers.
- R19.3.4: The trash and restore service stores the member list and emits an event for downstream consumers.
- R19.3.5: The trash and restore service validates the search index entry and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping trash and restore behaviour in one place avoids drift between clients. See also section 3.

| Case | Behaviour | Notes |
|---|---|---|
| C19.3.1 | queues the quota counter | configurable |
| C19.3.2 | caches the share token | default |
| C19.3.3 | validates the share token | admin only |
| C19.3.4 | logs the quota counter | all plans |

Note 19.3.1: the trash and restore service retries the quota counter and records the outcome in the audit log.
Note 19.3.2: the trash and restore service lists the quota counter and surfaces a retryable error when the dependency is unavailable.
Note 19.3.3: the trash and restore service logs the quota counter and returns the result to the caller without blocking the UI.

### 19.4 Trash and restore: topic 4

- R19.4.1: The trash and restore service lists the thumbnail and emits an event for downstream consumers.
- R19.4.2: The trash and restore service paginates the item metadata and keeps the behaviour identical across web and desktop clients.
- R19.4.3: The trash and restore service stores the share token and records the outcome in the audit log.
- R19.4.4: The trash and restore service retries the activity entry within the request, using the existing service client.
- R19.4.5: The trash and restore service signs the activity entry and records the outcome in the audit log.

Rationale: keeping trash and restore behaviour in one place avoids drift between clients. See also section 19.

| Case | Behaviour | Notes |
|---|---|---|
| C19.4.1 | paginates the folder tree | configurable |
| C19.4.2 | lists the folder tree | default |
| C19.4.3 | validates the sync cursor | default |
| C19.4.4 | queues the activity entry | configurable |

Note 19.4.1: the trash and restore service stores the permission set and records the outcome in the audit log.
Note 19.4.2: the trash and restore service queues the quota counter and surfaces a retryable error when the dependency is unavailable.
Note 19.4.3: the trash and restore service validates the quota counter and surfaces a retryable error when the dependency is unavailable.

### 19.5 Trash and restore: topic 5

- R19.5.1: The trash and restore service retries the quota counter within the request, using the existing service client.
- R19.5.2: The trash and restore service queues the quota counter and emits an event for downstream consumers.
- R19.5.3: The trash and restore service signs the quota counter and returns the result to the caller without blocking the UI.
- R19.5.4: The trash and restore service validates the quota counter and returns the result to the caller without blocking the UI.
- R19.5.5: The trash and restore service stores the thumbnail within the request, using the existing service client.

Rationale: keeping trash and restore behaviour in one place avoids drift between clients. See also section 15.

| Case | Behaviour | Notes |
|---|---|---|
| C19.5.1 | retries the member list | all plans |
| C19.5.2 | paginates the activity entry | configurable |
| C19.5.3 | paginates the permission set | configurable |
| C19.5.4 | caches the activity entry | admin only |

Note 19.5.1: the trash and restore service paginates the folder tree and keeps the behaviour identical across web and desktop clients.
Note 19.5.2: the trash and restore service queues the permission set and returns the result to the caller without blocking the UI.
Note 19.5.3: the trash and restore service paginates the permission set and surfaces a retryable error when the dependency is unavailable.

## 20. Import and export

This section describes how import and export behave in Harbor Drive and how they interact with the rest of the platform.

### 20.1 Import and export: topic 1

- R20.1.1: The import and export service stores the activity entry and surfaces a retryable error when the dependency is unavailable.
- R20.1.2: The import and export service queues the member list and records the outcome in the audit log.
- R20.1.3: The import and export service retries the permission set and emits an event for downstream consumers.
- R20.1.4: The import and export service queues the share token and records the outcome in the audit log.
- R20.1.5: The import and export service caches the folder tree within the request, using the existing service client.

Rationale: keeping import and export behaviour in one place avoids drift between clients. See also section 6.

| Case | Behaviour | Notes |
|---|---|---|
| C20.1.1 | caches the thumbnail | default |
| C20.1.2 | validates the item metadata | all plans |
| C20.1.3 | logs the thumbnail | admin only |
| C20.1.4 | signs the permission set | configurable |

Note 20.1.1: the import and export service validates the item metadata and returns the result to the caller without blocking the UI.
Note 20.1.2: the import and export service paginates the item metadata within the request, using the existing service client.
Note 20.1.3: the import and export service renders the search index entry and records the outcome in the audit log.

### 20.2 Import and export: topic 2

- R20.2.1: The import and export service stores the item metadata and returns the result to the caller without blocking the UI.
- R20.2.2: The import and export service caches the folder tree and keeps the behaviour identical across web and desktop clients.
- R20.2.3: The import and export service lists the quota counter within the request, using the existing service client.
- R20.2.4: The import and export service validates the quota counter and records the outcome in the audit log.
- R20.2.5: The import and export service lists the member list and emits an event for downstream consumers.

Rationale: keeping import and export behaviour in one place avoids drift between clients. See also section 20.

| Case | Behaviour | Notes |
|---|---|---|
| C20.2.1 | queues the share token | default |
| C20.2.2 | retries the item metadata | default |
| C20.2.3 | paginates the quota counter | all plans |
| C20.2.4 | paginates the sync cursor | admin only |

Note 20.2.1: the import and export service logs the item metadata within the request, using the existing service client.
Note 20.2.2: the import and export service queues the search index entry and keeps the behaviour identical across web and desktop clients.
Note 20.2.3: the import and export service queues the item metadata and emits an event for downstream consumers.

### 20.3 Import and export: topic 3

- R20.3.1: The import and export service paginates the quota counter and returns the result to the caller without blocking the UI.
- R20.3.2: The import and export service renders the item metadata and returns the result to the caller without blocking the UI.
- R20.3.3: The import and export service validates the share token and surfaces a retryable error when the dependency is unavailable.
- R20.3.4: The import and export service renders the quota counter and records the outcome in the audit log.
- R20.3.5: The import and export service retries the quota counter and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping import and export behaviour in one place avoids drift between clients. See also section 19.

| Case | Behaviour | Notes |
|---|---|---|
| C20.3.1 | signs the share token | admin only |
| C20.3.2 | validates the search index entry | admin only |
| C20.3.3 | logs the item metadata | admin only |
| C20.3.4 | signs the member list | admin only |

Note 20.3.1: the import and export service queues the folder tree and surfaces a retryable error when the dependency is unavailable.
Note 20.3.2: the import and export service caches the share token and records the outcome in the audit log.
Note 20.3.3: the import and export service lists the folder tree and emits an event for downstream consumers.

### 20.4 Import and export: topic 4

- R20.4.1: The import and export service renders the quota counter and returns the result to the caller without blocking the UI.
- R20.4.2: The import and export service validates the sync cursor within the request, using the existing service client.
- R20.4.3: The import and export service lists the search index entry and returns the result to the caller without blocking the UI.
- R20.4.4: The import and export service renders the item metadata and surfaces a retryable error when the dependency is unavailable.
- R20.4.5: The import and export service signs the thumbnail and surfaces a retryable error when the dependency is unavailable.

Rationale: keeping import and export behaviour in one place avoids drift between clients. See also section 6.

| Case | Behaviour | Notes |
|---|---|---|
| C20.4.1 | caches the search index entry | admin only |
| C20.4.2 | stores the share token | configurable |
| C20.4.3 | signs the item metadata | admin only |
| C20.4.4 | validates the member list | all plans |

Note 20.4.1: the import and export service validates the quota counter and emits an event for downstream consumers.
Note 20.4.2: the import and export service logs the thumbnail and records the outcome in the audit log.
Note 20.4.3: the import and export service lists the permission set and keeps the behaviour identical across web and desktop clients.

### 20.5 Import and export: topic 5

- R20.5.1: The import and export service lists the permission set and keeps the behaviour identical across web and desktop clients.
- R20.5.2: The import and export service retries the quota counter within the request, using the existing service client.
- R20.5.3: The import and export service validates the search index entry and emits an event for downstream consumers.
- R20.5.4: The import and export service retries the sync cursor and keeps the behaviour identical across web and desktop clients.
- R20.5.5: The import and export service validates the item metadata and records the outcome in the audit log.

Rationale: keeping import and export behaviour in one place avoids drift between clients. See also section 1.

| Case | Behaviour | Notes |
|---|---|---|
| C20.5.1 | caches the sync cursor | configurable |
| C20.5.2 | validates the quota counter | configurable |
| C20.5.3 | queues the sync cursor | admin only |
| C20.5.4 | caches the member list | configurable |

Note 20.5.1: the import and export service paginates the share token and emits an event for downstream consumers.
Note 20.5.2: the import and export service caches the share token and records the outcome in the audit log.
Note 20.5.3: the import and export service caches the permission set and records the outcome in the audit log.

## Appendix A: Glossary

- **Workspace**: a core Harbor Drive concept used throughout this document.
- **Member**: a core Harbor Drive concept used throughout this document.
- **Share token**: a core Harbor Drive concept used throughout this document.
- **Quota**: a core Harbor Drive concept used throughout this document.
- **Cursor**: a core Harbor Drive concept used throughout this document.
- **Audit entry**: a core Harbor Drive concept used throughout this document.

## Appendix B: Open items

- B1: Follow-up on topic 1; owner to be assigned, no decision required for this release.
- B2: Follow-up on topic 2; owner to be assigned, no decision required for this release.
- B3: Follow-up on topic 3; owner to be assigned, no decision required for this release.
- B4: Follow-up on topic 4; owner to be assigned, no decision required for this release.
- B5: Follow-up on topic 5; owner to be assigned, no decision required for this release.
- B6: Follow-up on topic 6; owner to be assigned, no decision required for this release.
- B7: Follow-up on topic 7; owner to be assigned, no decision required for this release.
- B8: Follow-up on topic 8; owner to be assigned, no decision required for this release.
- B9: Follow-up on topic 9; owner to be assigned, no decision required for this release.
- B10: Follow-up on topic 10; owner to be assigned, no decision required for this release.
- B11: Follow-up on topic 11; owner to be assigned, no decision required for this release.
- B12: Follow-up on topic 12; owner to be assigned, no decision required for this release.
- B13: Follow-up on topic 13; owner to be assigned, no decision required for this release.
- B14: Follow-up on topic 14; owner to be assigned, no decision required for this release.
- B15: Follow-up on topic 15; owner to be assigned, no decision required for this release.
- B16: Follow-up on topic 16; owner to be assigned, no decision required for this release.
- B17: Follow-up on topic 17; owner to be assigned, no decision required for this release.
- B18: Follow-up on topic 18; owner to be assigned, no decision required for this release.
- B19: Follow-up on topic 19; owner to be assigned, no decision required for this release.
- B20: Follow-up on topic 20; owner to be assigned, no decision required for this release.
- B21: Follow-up on topic 21; owner to be assigned, no decision required for this release.
- B22: Follow-up on topic 22; owner to be assigned, no decision required for this release.
- B23: Follow-up on topic 23; owner to be assigned, no decision required for this release.
- B24: Follow-up on topic 24; owner to be assigned, no decision required for this release.
- B25: Follow-up on topic 25; owner to be assigned, no decision required for this release.
- B26: Follow-up on topic 26; owner to be assigned, no decision required for this release.
- B27: Follow-up on topic 27; owner to be assigned, no decision required for this release.
- B28: Follow-up on topic 28; owner to be assigned, no decision required for this release.
- B29: Follow-up on topic 29; owner to be assigned, no decision required for this release.
- B30: Follow-up on topic 30; owner to be assigned, no decision required for this release.
- B31: Follow-up on topic 31; owner to be assigned, no decision required for this release.
- B32: Follow-up on topic 32; owner to be assigned, no decision required for this release.
- B33: Follow-up on topic 33; owner to be assigned, no decision required for this release.
- B34: Follow-up on topic 34; owner to be assigned, no decision required for this release.
- B35: Follow-up on topic 35; owner to be assigned, no decision required for this release.
- B36: Follow-up on topic 36; owner to be assigned, no decision required for this release.
- B37: Follow-up on topic 37; owner to be assigned, no decision required for this release.
- B38: Follow-up on topic 38; owner to be assigned, no decision required for this release.
- B39: Follow-up on topic 39; owner to be assigned, no decision required for this release.
- B40: Follow-up on topic 40; owner to be assigned, no decision required for this release.

## Appendix C: Platform constraints

Constraints that apply to every feature in this document.

- C1: All timestamps are stored in UTC and shown in the viewer's time zone.
- C2: Every user-visible message is localised through the existing string catalogue.
- C3: Files that a workspace owner has placed under legal hold can never be shared through a link with a lifetime longer than 72 hours; the link picker must offer nothing beyond 72 hours for such files.
- C4: Every change to a constraint here needs sign-off from the Platform team.

- C5: Platform constraint 1 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C6: Platform constraint 2 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C7: Platform constraint 3 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C8: Platform constraint 4 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C9: Platform constraint 5 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C10: Platform constraint 6 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C11: Platform constraint 7 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C12: Platform constraint 8 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C13: Platform constraint 9 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C14: Platform constraint 10 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C15: Platform constraint 11 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C16: Platform constraint 12 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C17: Platform constraint 13 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C18: Platform constraint 14 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C19: Platform constraint 15 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C20: Platform constraint 16 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C21: Platform constraint 17 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C22: Platform constraint 18 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C23: Platform constraint 19 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C24: Platform constraint 20 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C25: Platform constraint 21 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C26: Platform constraint 22 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C27: Platform constraint 23 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C28: Platform constraint 24 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C29: Platform constraint 25 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C30: Platform constraint 26 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C31: Platform constraint 27 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C32: Platform constraint 28 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C33: Platform constraint 29 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C34: Platform constraint 30 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C35: Platform constraint 31 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C36: Platform constraint 32 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C37: Platform constraint 33 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C38: Platform constraint 34 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C39: Platform constraint 35 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C40: Platform constraint 36 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C41: Platform constraint 37 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C42: Platform constraint 38 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C43: Platform constraint 39 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C44: Platform constraint 40 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C45: Platform constraint 41 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C46: Platform constraint 42 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C47: Platform constraint 43 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C48: Platform constraint 44 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C49: Platform constraint 45 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C50: Platform constraint 46 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C51: Platform constraint 47 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C52: Platform constraint 48 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C53: Platform constraint 49 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C54: Platform constraint 50 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C55: Platform constraint 51 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C56: Platform constraint 52 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C57: Platform constraint 53 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C58: Platform constraint 54 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C59: Platform constraint 55 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C60: Platform constraint 56 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C61: Platform constraint 57 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C62: Platform constraint 58 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C63: Platform constraint 59 applies uniformly to all clients and plans and has no feature-specific exceptions.
- C64: Platform constraint 60 applies uniformly to all clients and plans and has no feature-specific exceptions.

End of document.
