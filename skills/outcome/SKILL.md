---
name: outcome
description: Record the outcome a thread is aiming for and the design chosen to reach it, in a short note the Claude sessions picker (prefix + j) shows above the pane capture. Writes it from the conversation straight away and shows it in chat, so the user can correct it afterwards. Use when the user says "/outcome", "write the outcome", "capture the design", "record what we decided", or when a settled design has changed.
---

# Outcome

Keep the reason for a thread where the user will see it when they come back to it. The note
holds why the thread exists and how it gets there, never its status or progress: the picker
shows those already.

A background hook (the plugin's `hooks/updateThreadNote.py`) already creates and revises this note
after finished turns. Run this skill to write it now, or to fix what the hook wrote. Everyday
progress is not a reason to rerun it.

## Steps

1. **Find the note.** Run `git branch --show-current`. On a feature branch the key is the
   branch with every `/` replaced by `-`. On `main` or `master`, or outside a repo, sessions
   share the branch, so the key is `session-<id>`, where `<id>` comes from
   `tmux display -p -t "$TMUX_PANE" '#{@claude_session}'`; if that prints nothing, say the
   picker cannot show a note for this session and stop. The note is
   `~/.local/state/claude-sessions/threads/<key>.md`.

2. **Read any existing note.** If one exists, revise it rather than starting again, and say
   what changed and why.

3. **Write the note** to the path from step 1, creating the directory if needed, in this format:

   ```
   <thread name>

   OUTCOME
   <What is true for the user or the system when this works, in one or two lines.>
   Done when <the observable check>.

   DESIGN
   - <Core decision, as the rule the system follows, with its reason.>
   - <As many as the design needs.>

   NOT DOING
   - <Something a reader might assume is in scope.>
   ```

   Write only what was agreed in the conversation. List every core decision, however many
   there are; leave out implementation detail the code will show. If something is not
   settled, leave it out and name it to the user as an open question.

4. **Show it.** Print the saved note in chat and say it shows on the next prefix + j. Do not
   ask for approval; the user corrects it afterwards if they want to.
