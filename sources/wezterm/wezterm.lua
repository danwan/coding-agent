-- WezTerm config — Matrix theme ported from Ghostty
-- Source: ~/Library/Application Support/com.mitchellh.ghostty/config
-- Goal: same look & feel as Ghostty, without the DEC 2026 sync-output render bug.

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- ── GPU renderer ──────────────────────────────────────────────────────────
-- The reason we left Ghostty. WebGpu (Metal backend on macOS) is the renderer
-- cited as avoiding the flicker/corruption. If it ever misbehaves, swap the
-- next line for: config.front_end = "OpenGL"  (rock-solid fallback).
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"

-- ── Font ──────────────────────────────────────────────────────────────────
-- Ghostty used its bundled default (JetBrains Mono). WezTerm bundles the same
-- typeface, so this is a 1:1 match.
config.font = wezterm.font("JetBrains Mono")
config.font_size = 18.0

-- ── Matrix colors — green on black (ported from Ghostty) ───────────────────
config.colors = {
  background = "#000000",
  foreground = "#00FF00",
  cursor_bg = "#00FF00",
  cursor_fg = "#000000",
  cursor_border = "#00FF00",
  selection_bg = "#003300",
  selection_fg = "#00FF00",
}
-- NOTE: Ghostty's `bold-color = #33FF33` (all bold text in brighter green) has
-- no direct WezTerm equivalent — bold renders in the green foreground with bold
-- weight instead. The 16-color ANSI palette is left at WezTerm defaults, exactly
-- like your Ghostty config (which only overrode default fg/bg). So Claude Code's
-- colored UI (purple/yellow/etc.) looks the same as before.

config.default_cursor_style = "SteadyBlock"
config.scrollback_lines = 10000

-- ── Keybindings: match Ghostty muscle memory ──────────────────────────────
config.keys = {
  -- Splits  (Ghostty: cmd+d = right, cmd+shift+d = down)
  { key = "d", mods = "CMD", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

  -- Navigate between splits  (Ghostty: cmd+alt+arrow)
  { key = "LeftArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Left") },
  { key = "RightArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Right") },
  { key = "UpArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Up") },
  { key = "DownArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Down") },

  -- Zoom current split fullscreen  (Ghostty: cmd+shift+enter)
  { key = "Enter", mods = "CMD|SHIFT", action = act.TogglePaneZoomState },

  -- Close current split/pane (confirms — protects a running scan)
  { key = "w", mods = "CMD", action = act.CloseCurrentPane({ confirm = true }) },

  -- Rename the current tab
  {
    key = "r",
    mods = "CMD|SHIFT",
    action = act.PromptInputLine({
      description = "Rename tab:",
      action = wezterm.action_callback(function(window, _, line)
        if line and #line > 0 then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },
}

-- ── Tabs ──────────────────────────────────────────────────────────────────
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false -- keep renamed single tabs visible

return config
