# Store: linear

Tickets become issues in a Linear team, through the Linear MCP server. Once stored, Linear
holds every ticket and the map; the chain folder is deleted.

## First use

Run this once per team, before the first `create`:

1. List the team's issue statuses. If the Linear tools don't answer, ask the user to
   connect them (`claude mcp add --transport http linear-server https://mcp.linear.app/mcp`,
   then sign in) and stop.
2. Find the team's status whose type is `started`. Statuses are named per team ("In
   Progress", "Execution"), so `start` always looks one up by type.
3. Prove the round trip: create an issue titled "switchboard setup test, safe to delete",
   fetch it back, move it to the started status, then to the team's `canceled` status.
   Give the user its url.

## create

Before the first ticket: when `source` isn't a Linear project, create one in the team named
after the chain's title, and set `source` to it.

1. **Skip what's already stored.** List the issues in the project (else the team),
   archived ones included, with their descriptions. An issue whose description's first
   four lines include `switchboard: <slug>/T3` is this ticket from an earlier run: record
   its identifier and url and go on to the next ticket. Match that line yourself, since
   the list's `query` is a fuzzy word search.
2. **Save the issue** in the team and the `source` project, with the ticket's title and
   `labels`. The description is the body, with the line `switchboard: <slug>/T3` straight
   after its callout: list results cut long descriptions short, so the line goes near the
   top. A reference to an earlier ticket is its bare key, `ENGH-1134`, which Linear links
   itself. Pass the `after` keys as `blockedBy`.
3. **Confirm the relations** by getting the issue with its relations: the save's response
   leaves them out.
4. Set `key` to the issue's identifier and `url` to its url, then delete the body file in
   a command of its own.

## update

Get the issue, then save it with a `patch` rather than a whole new description, so edits
people made in Linear survive. Anchor each patch on text the description actually holds:
Linear rewrites keys into `<issue>` tags and escapes some characters, so anchor on plain
words near them. Linear doesn't render HTML, so a table stays plain Markdown.

## deliver

Append map.md's sections to the `source` project's description, after the existing text,
which stays as it is. A section that only points to one already in the description adds
nothing. Set `project_url`, then delete the chain folder in a command of its
own.

## fetch

A project: get it with its resources, and read every linked document. An issue: get it by
key, then list its comments, since the issue alone leaves them out. Its `gitBranchName` is
the branch name to use for it.

## start

Save the issue with assignee `me` and the team's `started`-type status, looked up by type.
Read the state back from the response: a wrong name fails without an error.
