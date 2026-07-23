--[[
ask_pane_mapping_coverage
Purpose: Record behavior-sensitive ask mapping and command coverage by matrix row.
Does: Links behavior/mapping matrix rows to registration, direct policy/state,
fed-key, or explicit no-fed-key coverage.
Architecture: Test fixture only; it keeps callback-only exceptions visible
without affecting runtime code.
]]

local commandline_fed = "ask pane fed command-line lifecycle covers q w and wq user paths"
local policy = "ask action policy classifies command lines plain quit mappings and lifecycle plans"
local registration = "ask mapping zone matrix matches active maps by user location"
local submit_command = "submit question command without active ask draft warns and keeps state"
local submit_fed = "ask pane submit mapping sends modified prompt from normal and insert modes"
local send_fed = "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts"
local non_ask_fed = "personal normal quit mappings do not close markdown or terminal side panes"
local non_ask_command = "personal quit mapping in terminal pane follows q command path with plain quit guard"
local typed_qbang = "ask pane typed q bang cancels without closing the side pane"
local ready_submit = "ask pane empty ready draft writes then submit cancels without sending"
local failed_send = "pane-mode ask preserves prompt when target terminal fails to open"
local model_picker = "ask pane target picker mapping updates target and winbar"
local navigation = "ask pane navigation mappings move between context headers and source jump opens citation"
local undo_refresh = "ask session refreshes draft state after undo through adapter facts"
local undo_reset = "ask pane focus mapping preserves modified drafts and clears unmodified drafts with undo"
local version_command = "command registration invokes facade callbacks"

return {
    rows = {
        {
            id = "ask-q-ready",
            behavior_row = "ask-q-ready",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = policy,
            fed_key = commandline_fed,
        },
        {
            id = "ask-q-modified",
            behavior_row = "ask-q-modified",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = policy,
            fed_key = commandline_fed,
        },
        {
            id = "ask-q-written",
            behavior_row = "ask-q-written",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = policy,
            fed_key = commandline_fed,
        },
        {
            id = "ask-q-failed-send",
            behavior_row = "ask-q-failed-send",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = failed_send,
            fed_key = failed_send,
        },
        {
            id = "ask-qbang-any",
            behavior_row = "ask-qbang-any",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = policy,
            fed_key = typed_qbang,
        },
        {
            id = "ask-write-ready",
            behavior_row = "ask-write-ready",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = ready_submit,
            fed_key = commandline_fed,
        },
        {
            id = "ask-write-draft",
            behavior_row = "ask-write-draft",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = "pane-mode ask write then quit sends accumulated prompt",
            fed_key = commandline_fed,
        },
        {
            id = "ask-write-quit-ready",
            behavior_row = "ask-write-quit-ready",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = ready_submit,
            fed_key = commandline_fed,
        },
        {
            id = "ask-write-quit-draft",
            behavior_row = "ask-write-quit-draft",
            zone_rows = { "ask-pane-command-line" },
            registration = registration,
            direct = policy,
            fed_key = commandline_fed,
        },
        {
            id = "ask-send-shortcut-unwritten",
            behavior_row = "ask-send-shortcut-unwritten",
            zone_rows = { "ask-pane-submit-and-send" },
            registration = registration,
            direct = policy,
            fed_key = send_fed,
        },
        {
            id = "ask-send-shortcut-written",
            behavior_row = "ask-send-shortcut-written",
            zone_rows = { "ask-pane-submit-and-send" },
            registration = registration,
            direct = policy,
            fed_key = send_fed,
        },
        {
            id = "ask-send-alt-shortcut",
            behavior_row = "ask-send-alt-shortcut",
            zone_rows = { "ask-pane-submit-and-send" },
            registration = registration,
            direct = policy,
            fed_key = send_fed,
        },
        {
            id = "non-ask-quit-command",
            behavior_row = "non-ask-quit-command",
            zone_rows = { "terminal-pane-quit-command" },
            registration = registration,
            direct = policy,
            fed_key = non_ask_command,
        },
        {
            id = "ask-submit-ready",
            behavior_row = "ask-submit-ready",
            zone_rows = { "ask-pane-submit-and-send" },
            registration = registration,
            direct = ready_submit,
            fed_key = submit_fed,
        },
        {
            id = "ask-submit-draft",
            behavior_row = "ask-submit-draft",
            zone_rows = { "ask-pane-submit-and-send" },
            registration = registration,
            direct = policy,
            fed_key = submit_fed,
        },
        {
            id = "submit-command-no-draft",
            behavior_row = "submit-command-no-draft",
            zone_rows = { "ask-zone-commands" },
            registration = registration,
            direct = submit_command,
            no_fed_key_reason = "Command behavior is exercised through :SidepanesSubmitQuestion, not a key mapping.",
        },
        {
            id = "submit-command-active-draft",
            behavior_row = "submit-command-active-draft",
            zone_rows = { "ask-zone-commands" },
            registration = registration,
            direct = "pane-mode ask write then quit sends accumulated prompt",
            no_fed_key_reason = "Command behavior is exercised through :SidepanesSubmitQuestion, not a key mapping.",
        },
        {
            id = "non-ask-command-line",
            behavior_row = "non-ask-command-line",
            zone_rows = { "terminal-pane-quit-command" },
            registration = registration,
            direct = policy,
            fed_key = non_ask_fed,
        },
        {
            id = "project-global-normal-ask-pane",
            zone_rows = { "project-global-normal-ask-pane" },
            registration = registration,
            direct = "global map registration invokes facade callbacks",
            no_fed_key_reason = "Registration-only global facade path; ask lifecycle is covered in pane-local fed-key rows.",
        },
        {
            id = "project-global-visual-ask",
            zone_rows = { "project-global-visual-ask" },
            registration = registration,
            direct = "global map registration invokes facade callbacks",
            no_fed_key_reason = "Visual capture behavior is not ask lifecycle key handling; selection capture has direct prompt tests.",
        },
        {
            id = "project-global-visual-ask-shortcuts",
            zone_rows = { "project-global-visual-ask-shortcuts" },
            registration = registration,
            direct = "global map registration invokes facade callbacks",
            no_fed_key_reason = "Visual capture behavior is not ask lifecycle key handling; selection capture has direct prompt tests.",
        },
        {
            id = "markdown-pane-heading-and-ask",
            zone_rows = { "markdown-pane-heading-and-ask" },
            registration = registration,
            direct = "pane-local slot maps exist on markdown and terminal panes",
            no_fed_key_reason = "Registration and facade delegation only; no ask lifecycle state transition is decided here.",
        },
        {
            id = "markdown-pane-visual-ask",
            zone_rows = { "markdown-pane-visual-ask" },
            registration = registration,
            direct = "pane-local mappings are configurable",
            no_fed_key_reason = "Visual capture behavior is not ask lifecycle key handling; selection capture has direct prompt tests.",
        },
        {
            id = "markdown-pane-terminal-toggles",
            zone_rows = { "markdown-pane-terminal-toggles" },
            registration = registration,
            direct = "pane-local slot maps exist on markdown and terminal panes",
            no_fed_key_reason = "Terminal toggle behavior is not ask lifecycle behavior for this slice.",
        },
        {
            id = "terminal-pane-ask-and-toggles",
            zone_rows = { "terminal-pane-ask-and-toggles" },
            registration = registration,
            direct = "pane-local slot maps exist on markdown and terminal panes",
            no_fed_key_reason = "Ask-pane open/toggle registration is covered; lifecycle behavior begins inside ask-pane rows.",
        },
        {
            id = "terminal-pane-terminal-mode-toggles",
            zone_rows = { "terminal-pane-terminal-mode-toggles" },
            registration = registration,
            direct = "pane-local slot maps exist on markdown and terminal panes",
            no_fed_key_reason = "Terminal-mode toggle behavior is outside ask lifecycle state transitions.",
        },
        {
            id = "ask-pane-target-picker",
            zone_rows = { "ask-pane-target-picker" },
            registration = registration,
            direct = model_picker,
            fed_key = model_picker,
        },
        {
            id = "ask-pane-context-navigation",
            zone_rows = { "ask-pane-context-navigation" },
            registration = registration,
            direct = navigation,
            no_fed_key_reason = "Navigation/source-jump mappings are behavior-sensitive but not lifecycle-changing; callback coverage keeps cursor/source assertions deterministic.",
        },
        {
            id = "ask-pane-undo",
            zone_rows = { "ask-pane-undo" },
            registration = registration,
            direct = undo_refresh,
            fed_key = undo_reset,
        },
        {
            id = "version-command",
            zone_rows = { "ask-zone-commands" },
            registration = registration,
            direct = version_command,
            no_fed_key_reason = "Command behavior is exercised through :SidepanesVersion and :Sidepanes version, not a key mapping.",
        },
    },
}
