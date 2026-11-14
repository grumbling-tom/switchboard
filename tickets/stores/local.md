# Store: local

Tickets stay as files in the chain folder, in the plugin's data folder. Nothing to connect,
and nothing in the user's repo. They are on this machine only, so this store suits work
nobody else needs to see.

## First use

Nothing to set up.

## create

The ticket's body file is the stored ticket. Write each `[[T<n>]]` as a Markdown link to
that ticket's body file, titled with its id and title: `[T2 Manager prompt](T2-manager-prompt.md)`.
Set `key` to the ticket's id and `url` to the body file's absolute path. A ticket that
already has a `url` is stored; skip it.

## update

Edit the body file at the ticket's `url`.

## deliver

map.md is the project. Set `project_url` to its absolute path.

## fetch

A key is `<slug>/T3`, or a bare `T3` when only one chain in this repo's folder has it.
Find the ticket in that chain's `tickets.toml` and read the file at its `url`.

## start

Add `state = "started"` and `assignee = "<git user.name>"` to the ticket's table in
`tickets.toml`.
