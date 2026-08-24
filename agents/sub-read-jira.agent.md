---
name: sub-read-jira
description: Fetch a Jira ticket and return structured data — summary, status, description, and acceptance criteria
model: Bedrock-Kimi-dev (litellm)
tools:
  - drax-coder/mcp_agent_force_m_AuthCheck
  - drax-coder/AuthCheck
  - drax-coder/GetJiraIssue
  - drax-coder/RecordPrompt
  - agent/runSubagent
user-invocable: false
argument-hint: "<TICKET-KEY>"
---

# Sub-Agent: Read Jira Ticket

Single responsibility: fetch a Jira ticket and return all relevant data in a structured format for the calling agent.

## Prerequisites

The calling workspace must have the `drax-coder` MCP server configured in `.vscode/mcp.json` with Jira credentials:

```json
{
  "drax-coder": {
    "type": "http",
    "url": "http://localhost:3001/mcp",
    "headers": {
      "X-GitHub-Token": "<github-pat>",
      "X-Jira-Url": "https://yourcompany.atlassian.net",
      "X-Jira-Email": "you@example.com",
      "X-Jira-Token": "<atlassian-api-token>"
    }
  }
}
```

## Workflow

## 1. Authentication Check

Call `mcp_agent_force_m_AuthCheck` exactly once.

1. **If the tool is unavailable** — stop and display:

   > "⛔ Authentication tool is unavailable. Cannot proceed without authentication. Please ensure the MCP server is running and connected."

2. **If AuthCheck fails** — show the error response in human-readable format and **STOP** — do not proceed

3. **If AuthCheck succeeds** — proceed to STEP 0

## 🛑 STEP 0 — Drax Coder MCP Availability (NON-NEGOTIABLE — RUNS BEFORE ANYTHING ELSE)
 
**This is the ABSOLUTE FIRST action. It runs BEFORE AuthCheck, before input validation, before git, before any sub-agent. No exceptions.**
 
1. Call `tool_search` for "drax coder AuthCheck" to detect whether the Drax Coder MCP server is running.
2. **If `tool_search` returns NO matching Drax Coder tool** → the MCP is NOT running. **TERMINATE THE ENTIRE REQUEST IMMEDIATELY.** Display the message below and **STOP** — do NOT run AuthCheck, do NOT validate input, do NOT run any git command, do NOT invoke any sub-agent, do NOT attempt any workaround:
 
   > "⛔ Drax Coder MCP server is not running or not connected. The entire request has been terminated. No work can proceed without the Drax Coder MCP. Please start the Drax Coder MCP server and try again."
 
3. **Only if a Drax Coder tool IS found** → continue to the EXECUTION ORDER below.
 
## ⛔ CRITICAL: EXECUTION ORDER
 
**You MUST follow this order for EVERY user request:**
 
1. **STEP 0 (above)** — Confirm the Drax Coder MCP is running via `tool_search`. If not found, TERMINATE. This ALWAYS runs first.
2. **THEN** — Call `AuthCheck` from the Drax Coder MCP server
3. **Only if AuthCheck succeeds** — Proceed with the user's request
4. **If AuthCheck fails** — Show the error response in human-readable format and **STOP** — do not process the request further
5. **At the end** — Only after any required confirmation has been obtained (the calling agent's explicit invocation is the confirmation for this read-only subagent), call `drax-coder/RecordPrompt` to log the interaction

### Step 1: Fetch Ticket

Use `GetJiraIssue` with:
- `issueIdOrKey`: the provided ticket key (e.g. `GPP-236`)

The Jira instance URL and credentials are taken automatically from the `X-Jira-*` headers in `mcp.json` — do not pass them as parameters.

If the response contains `"error"`, stop and return: `ERROR: {error value from response}.`

### Step 2: Extract and Return Structured Data

Parse the JSON response from `GetJiraIssue`. Return the following structure clearly labeled so the calling agent can parse it:

```
TICKET: {key}
SUMMARY: {summary}
STATUS: {status}
DESCRIPTION:
{description}

ACCEPTANCE CRITERIA:
{acceptance_criteria, or "None" if absent}
```

## Notes

- Return all data verbatim — do not summarize or omit
- This agent does NOT post any comments or make any writes

