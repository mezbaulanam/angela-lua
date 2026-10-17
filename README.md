# Angela Lua SDK (`angela-lua`)

The official Lua SDK for building cartridges in the **Angela Games Ecosystem**.

Angela games run as deterministic WebAssembly cartridges in Discord servers. The Lua SDK provides an ergonomic framework for handling commands, button clicks, select menus, modals, timed wakes, and real-time multiplayer lobbies in pure Lua (5.1+ / 5.4).

---

## Table of Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Architecture & How It Works](#architecture--how-it-works)
4. [Application Lifecycle & Routing](#application-lifecycle--routing)
5. [The Game Context (`ctx`)](#the-game-context-ctx)
6. [Economy & Multi-Currency System](#economy--multi-currency-system)
7. [Inventory & Items](#inventory--items)
8. [UI Engine](#ui-engine)
   - [Universal Render (`ctx.ui:render`)](#universal-render)
   - [Components V2](#components-v2)
   - [Classic Embeds](#classic-embeds)
   - [Modals & Ephemeral Replies](#modals--ephemeral-replies)
9. [2D Canvas Graphics Engine](#2d-canvas-graphics-engine)
   - [Layers & Static Layer Caching](#layers--static-layer-caching)
   - [Complete Drawing API Reference](#complete-drawing-api-reference)
10. [Multiplayer & Lobbies](#multiplayer--lobbies)
11. [AI & Media Gateways](#ai--media-gateways)
12. [HTTP & Discord Utilities](#http--discord-utilities)
13. [Cartridge Project Layout & CLI](#cartridge-project-layout--cli)

---

## Installation

Using LuaRocks:

```bash
luarocks install angela
```

Or copy the `angela/` module directory into your cartridge project root:

```text
my_game/
├── angela/             # The angela-lua SDK module
│   ├── init.lua
│   ├── context.lua
│   ├── game.lua
│   ├── models.lua
│   ├── canvas.lua
│   └── json.lua
├── manifest.json
└── main.lua
```

Zero external runtime dependencies. Works with Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT.

---

## Quick Start

Create a minimal interactive game in `main.lua`:

```lua
local angela = require("angela")
local Game = angela.Game
local Button = angela.Button

local game = Game.new("dice_challenge")

game:on_command(function(ctx)
  ctx.state.rolls = ctx.state.rolls or 0

  ctx.ui:render({
    title = "🎲 Angela Dice Challenge",
    subtitle = "Host: " .. ctx.user.name,
    body_lines = {
      "Roll the dice to win server currency!",
      "You have rolled " .. tostring(ctx.state.rolls) .. " times so far."
    },
    buttons = {
      Button.new({ custom_id = "roll_btn", label = "Roll (5 Coins)", style = "primary", emoji = "🎲" }),
      Button.new({ custom_id = "cash_out", label = "Cash Out", style = "danger", emoji = "💰" }),
    }
  })
end)

game:on_button("roll_btn", function(ctx)
  local score = math.random(1, 6)
  ctx.state.rolls = (ctx.state.rolls or 0) + 1

  -- Award server's configured game currency
  local reward = score * 10
  ctx.economy:give(ctx.user.id, reward, "Rolled a " .. score .. "!")

  ctx.ui:render({
    title = "🎲 Nice Roll!",
    body_lines = {
      "You rolled a **" .. score .. "**!",
      "Earned: **+" .. reward .. " " .. (ctx.config.currency_name or "Coins") .. "**"
    },
    buttons = {
      Button.new({ custom_id = "roll_btn", label = "Roll Again", style = "primary", emoji = "🎲" }),
      Button.new({ custom_id = "cash_out", label = "Finish", style = "secondary" }),
    }
  })
end)

game:on_button("cash_out", function(ctx)
  ctx:finish()
  ctx.ui:render({
    title = "🏆 Game Over",
    body_lines = {
      "Thanks for playing, " .. ctx.user.name .. "!",
      "Total rolls: " .. tostring(ctx.state.rolls or 0)
    }
  })
end)

-- Angela invokes handle with either a table or JSON string
local function handle(event)
  return game:handle(event)
end

return { handle = handle }
```

---

## Architecture & How It Works

Angela games use a **declarative intent-based architecture**:

1. **Incoming Event**: When a player clicks a button, invokes a slash command, or submits a modal, Angela formats the interaction into an event and passes it to your cartridge's `handle(event)` function.
2. **Context Creation**: The SDK converts the raw payload into a rich `Context` (`ctx`) object containing player information, session state, user inputs, and server slot configuration.
3. **Intent Accumulation**: Your handlers mutate `ctx.state` and call sub-APIs (such as `ctx.economy:give()`, `ctx.ui:render()`, or `ctx.canvas:create()`). These calls record **intents** in an execution plan without making external network calls.
4. **Response Execution**: The SDK returns the final state and accumulated intents back to Angela. The host validates balances, draws graphics, commits database updates atomically, and renders the Discord response.

This ensures game cartridges remain fast, deterministic, sandboxed, and testable offline with `angela dev`.

---

## Application Lifecycle & Routing

### Event Listeners

Register event handlers on your `Game` instance:

```lua
local game = angela.Game.new("my_cartridge")

-- Primary slash command
game:on_command(function(ctx) ... end)

-- Subcommands: /game duel
game:on_command("duel", function(ctx) ... end)

-- Button clicks by custom_id
game:on_button("attack_btn", function(ctx) ... end)

-- Select menus by custom_id
game:on_select("class_picker", function(ctx) ... end)

-- Modal form submissions
game:on_modal("character_creation", function(ctx) ... end)

-- Chat message events
game:on_message(function(ctx) ... end)

-- Resumed session wake after hibernation
game:on_wake("boss_turn", function(ctx) ... end)

-- Asynchronous host callbacks (AI, HTTP, GIF search)
game:on_callback("on_story_ready", function(ctx) ... end)

-- Default fallback handler
game:default(function(ctx) ... end)
```

### Session States & Lifecycle Control

- `ctx.status`: Current session status (`"ACTIVE"`, `"SLEEPING"`, `"PAUSED"`, `"FINISHED"`).
- `ctx:finish()`: Completes the session. Angela archives session memory.
- `ctx:pause()`: Pauses player interaction until resumed.
- `ctx:next_round()`: Increments `ctx.round` and returns the new round number.
- `ctx:sleep(seconds, callback)`: Pauses session execution. Delays over 3 seconds hibernate the session; Angela schedules a timer and re-awakens your game at `game:on_wake(callback)`.

---

## The Game Context (`ctx`)

Passed as the primary argument to all registered handlers:

### Metadata & User Info

- `ctx.user.id`: Discord user ID (`number`).
- `ctx.user.name`: Discord username (`string`).
- `ctx.user.avatar_url`: Discord avatar URL (`string`).
- `ctx.host_id`: User ID of the session creator (`number`).
- `ctx.guild_id`: Server guild ID (`number`).
- `ctx.channel_id`: Channel ID (`number`).
- `ctx.event_type`: Event category (`"COMMAND"`, `"BUTTON"`, `"SELECT"`, `"MODAL"`, etc.).
- `ctx.event_id`: Component custom_id or subcommand name (`string`).

### User Arguments (`ctx.args`)

- `ctx.args.subcommand`: Subcommand string (if any).
- `ctx.args.raw_args`: Raw unparsed command arguments string.
- `ctx.args.target_user_id`: Mentioned user ID (`number | nil`).
- `ctx.args.select_values`: Table of selected menu values (`table`).
- `ctx.args.modal_inputs`: Key-value table of submitted modal inputs (`table`).
- `ctx.args.message_content`: Message text when listening to channel chat.
- `ctx.args.callback_data`: Payload returned by host callbacks.

### Session State (`ctx.state`)

`ctx.state` is a Lua table automatically saved and restored across turns:

```lua
ctx.state.score = (ctx.state.score or 0) + 10
ctx.state.inventory = { "iron_sword", "healing_herb" }
```

### Slot Configuration (`ctx.config`)

Read-only table containing server admin overrides merged with your cartridge's `manifest.json` schema:

```lua
local currency_name = ctx.config.currency_name or "Coins"
local currency_emoji = ctx.config.currency_emoji or "🪙"
local max_tries = tonumber(ctx.config.max_tries or 3)
```

### Slot Secrets (`ctx.secrets`)

Read-only table containing private slot credentials (such as API keys). Secrets are kept private to the host and never written to game state.

### Persistent Player Storage (`ctx.storage`)

Store game-scoped persistent player progress and manage cooldowns:

```lua
-- Read and write game-scoped player storage
local best_score = ctx.storage:get("best_score", 0)
ctx.storage:set("best_score", math.max(best_score, current_score))

-- Enforce a 60-second cooldown on the player
ctx.storage:set_cooldown(ctx.user.id, 60)
```

---

## Economy & Multi-Currency System

Angela provides a server-backed economy engine. Cartridges emit declarative intents; Angela safely executes balance deductions and credits.

### Server Currency Integration

Every Discord server chooses its preferred game currency on the game slot (e.g. `"Shells"`, `"Coins"`, `"Gems"`). By default, omitting `currency` automatically targets whichever currency the server administrator has chosen:

```lua
-- Query balance in the server's default currency
ctx.economy:get_balance(ctx.user.id)

-- Deduct entry fee
ctx.economy:take(ctx.user.id, 25, "Tournament entry fee")

-- Award rewards with optional safety bounds
ctx.economy:give(ctx.user.id, 100, "Victory prize", 0, 500)
```

### Explicit Multi-Currency

For trading games or multi-currency ecosystems, pass a specific currency name:

```lua
-- Target specific currency
ctx.economy:get_balance(ctx.user.id, "Gems")
ctx.economy:give(ctx.user.id, 10, "Daily bonus", nil, nil, "Gems")
ctx.economy:take(ctx.user.id, 50, "Market trade", "Gold")
```

### Escrow (Wagers & Duels)

Lock currency during matches. Angela holds the funds in escrow and refunds them automatically if an invitation expires or is declined:

```lua
-- Lock wager into escrow
ctx.economy:escrow_lock(ctx.user.id, 50, "Match wager")

-- Release funds to winner
ctx.economy:escrow_release(winner_id, 100, "Won wager match")

-- Refund participants on draw or cancellation
ctx.economy:escrow_refund(ctx.user.id, 50, "Match cancelled")
```

### Auto-Buy Items

Automatically deduct currency to purchase consumable items if a player is missing them:

```lua
ctx.economy:auto_buy(ctx.user.id, { "fishing_bait", "health_potion" }, 5)
```

---

## Inventory & Items

### Server Items

```lua
-- Query player inventory
ctx.inventory:get_server_items(ctx.user.id)

-- Consume a usable server item
ctx.inventory:consume_server_item(ctx.user.id, "potion_mana", 1)

-- Award a server item
ctx.inventory:give_server_item(ctx.user.id, "badge_champion", 1)

-- Roll item break / wear chance (e.g. 5% break chance)
ctx.inventory:roll_break(ctx.user.id, "fishing_rod", 0.05)
```

### Game-Scoped Sub-Inventory

Store game-specific loot (e.g. caught fish, crafted runes, collected cards) without cluttering the server's global item catalog:

```lua
ctx.inventory:add_sub_item(ctx.user.id, "sapphire_sardine", 1)
ctx.inventory:remove_sub_item(ctx.user.id, "sapphire_sardine", 1)
```

---

## UI Engine

### Universal Render

`ctx.ui:render()` compiles your layout automatically into the mode configured by the server (`AUTO`, `CV2`, or `CLASSIC_EMBED`):

```lua
local Button = angela.Button

ctx.ui:render({
  title = "⚔️ Boss Raid: Abyssal Hydra",
  subtitle = "Turn 3 — Party HP: 84%",
  body_lines = {
    "The Hydra prepares a toxic tidal wave!",
    "Select your tactical stance:"
  },
  thumbnail = "https://example.com/hydra.png",
  accent_color = 0x9B59B6,
  buttons = {
    Button.new({ custom_id = "shield", label = "Raise Shield", style = "primary", emoji = "🛡️" }),
    Button.new({ custom_id = "dodge", label = "Dodge", style = "secondary", emoji = "💨" }),
    Button.new({ custom_id = "heal", label = "Cast Heal", style = "success", emoji = "✨" }),
  }
})
```

### Components V2

Build modular layouts using modern Discord containers:

```lua
local Container = angela.Container
local Section = angela.Section
local TextDisplay = angela.TextDisplay
local Thumbnail = angela.Thumbnail
local Separator = angela.Separator
local ActionRow = angela.ActionRow
local Button = angela.Button

local container = Container.new({ accent_color = "#5865F2" })
  :add(
    Section.new({
      text_displays = {
        TextDisplay.new("## 🏆 Arena Leaderboard"),
        TextDisplay.new("Top contenders of the current season:")
      },
      accessory = Thumbnail.new("https://example.com/trophy.png")
    })
  )
  :add(Separator.new({ divider = true }))
  :add(
    ActionRow.new({
      Button.new({ custom_id = "prev", label = "Previous", style = "secondary" }),
      Button.new({ custom_id = "next", label = "Next", style = "primary" })
    })
  )

ctx.ui:render_cv2(container)
```

### Classic Embeds

```lua
local Embed = angela.Embed
local Button = angela.Button

local embed = Embed.new({
  title = "🎣 Catch of the Day",
  description = "Here is your haul from the reef:",
  color = 0x3498DB
})
  :add_field("Species", "Golden Dorado", true)
  :add_field("Weight", "7.8 kg", true)
  :add_field("Bounty", "80 Shells", true)

ctx.ui:render_embed(embed, {
  Button.new({ custom_id = "fish_again", label = "Cast Again", style = "primary", emoji = "🎣" })
})
```

### Modals & Ephemeral Replies

```lua
local TextInput = angela.TextInput

-- Open modal
game:on_button("open_wager", function(ctx)
  ctx.ui:open_modal("Place Wager", {
    TextInput.new({
      custom_id = "wager_val",
      label = "Wager Amount",
      placeholder = "e.g. 100",
      required = true,
      max_length = 6
    })
  }, "wager_submitted")
end)

-- Receive modal submission
game:on_modal("wager_submitted", function(ctx)
  local amount = tonumber(ctx.args.modal_inputs.wager_val or 0)
  ctx.economy:take(ctx.user.id, amount, "Wager placed")
  ctx.ui:reply_ephemeral("Locked in your wager of **" .. amount .. " coins**!")
end)
```

### Public Chat Delivery (`send_chat` vs `EDIT_MAIN`)

By default, games edit the existing game message (`target = "EDIT_MAIN"`). This keeps card tables, boards, and casino wheels compact without spamming Discord channels.

For games that announce new rounds, post trivia questions, or announce server-wide events, use `ctx.ui:send_chat(...)` or set `target = "NEW_MESSAGE"`:

```lua
-- Helper: sends a brand new public message to the channel
ctx.ui:send_chat({
  title = "🧠 Trivia Round 1",
  text = "What is the capital of Peru?",
  buttons = {
    Button.new({ custom_id = "ans_lima", label = "Lima", style = "primary" }),
    Button.new({ custom_id = "ans_bogota", label = "Bogota", style = "secondary" }),
  }
})

-- Or using string shorthand:
ctx.ui:send_chat("⚔️ The world boss has awakened! Click below to join the raid!")
```

| Method / Target | Visibility | Replaces Previous? | Best Used For |
|---|---|---|---|
| `target = "EDIT_MAIN"` (Default) | Public | Yes (Edits main message) | Lobbies, boards, scoreboards, casino wheels |
| `ctx.ui:send_chat(...)` / `target = "NEW_MESSAGE"` | Public | No (Sends new message) | Trivia rounds, event announcements, elimination logs |
| `ctx.ui:reply_ephemeral(...)` | Only Clicker | No (Private reply) | Secret hands, balance checks, validation errors |

---

## 2D Canvas Graphics Engine

Angela includes a declarative 2D graphics engine. You construct scenes with layers and primitives; Angela renders them into PNGs (or animated GIFs/WebPs) attached directly to your message.

### Creating a Scene

```lua
local scene = ctx.canvas:create({
  width = 640,
  height = 360,
  animated = false,
  filename = "game_screen.png"
})
```

### Layers & Static Layer Caching

Setting a `cache_key` on static background layers caches the rendered graphic on disk — future turns skip all background pixel rendering and composite dynamic elements directly on top:

```lua
local Button = angela.Button

-- Static background layer (cached on disk)
local bg = scene:layer("background", "ocean_base_v1")
bg:linear_gradient({ 0, 0, 640, 360 }, { 15, 25, 60 }, { 230, 120, 60 }, 1.2)
bg:celestial_body(320, 120, 22, 75, { 255, 240, 200 }, { 255, 180, 70, 80 })
bg:sine_waves(180, 280, 8, { 255, 255, 255, 50 })
bg:vignette(40, 1.1)

-- Dynamic entities layer (drawn fresh each turn)
local entities = scene:layer("dynamic_entities")
entities:radial_glow(300, 180, 35, { 255, 215, 0 }, 50)
entities:sprite("fish_gold.png", 300, 180, 64, 64)
entities:avatar(ctx.user.id, 40, 40, 64, true, { 255, 215, 0 }, 2)
entities:rounded_rect({ 20, 300, 620, 345 }, 8, { 15, 20, 35, 200 }, { 255, 255, 255, 60 })
entities:progress_bar({ 35, 312, 250, 332 }, 75, 100, { 30, 30, 45 }, { 87, 242, 135 }, 5)
entities:text_box({ 300, 310, 600, 340 }, "Reeling in catch...", "bold", 14, { 255, 255, 255 })

-- Attach canvas scene to UI render
ctx.ui:render({
  title = "Ocean Explorer",
  image = scene,
  buttons = { Button.new({ custom_id = "reel", label = "Reel!", style = "success" }) }
})
```

### Complete Drawing API Reference

| Method | Parameters | Description |
|--------|------------|-------------|
| `linear_gradient` | `rect, start_rgb, end_rgb, gamma` | Vertical linear color blend |
| `celestial_body` | `x, y, radius, glow_radius, color, glow_color` | Sun, moon, or glowing orb with smooth radial glow |
| `sine_waves` | `y_start, y_end, count, color` | Procedural ocean waves or stylized horizon curves |
| `procedural_palm` | `x, y_bottom, y_top, seed` | Procedural beach palm tree silhouette |
| `vignette` | `depth, intensity` | Smooth dark edges around canvas border |
| `radial_glow` | `x, y, radius, color, max_alpha` | Soft radial light halo |
| `sprite` | `asset_key, x, y, max_w, max_h, anchor, flip_x, rotation` | Draws a PNG image from your cartridge `./assets/` |
| `avatar` | `user_id, x, y, size, circular, border_color, border_width` | Draws any player's Discord avatar with optional border |
| `polygon` | `points, fill, outline` | Multi-point closed polygon |
| `line` | `points, color, width` | Multi-segment line stroke |
| `arc` | `bbox, start_deg, end_deg, color, width` | Elliptical or circular arc |
| `rounded_rect` | `rect, radius, fill, outline, width` | Smooth rounded box with optional stroke |
| `progress_bar` | `rect, value, max_value, bg_color, fill_color, radius` | Filled progress gauge for HP, XP, or timer |
| `text_box` | `rect, text, font, size, color, max_lines, line_height` | Text box with word wrapping |

---

## Multiplayer & Lobbies

### Turnkey Join Lobby

```lua
game:on_command(function(ctx)
  ctx.lobby:create_join_lobby(16, 60, "on_lobby_countdown_ended")
end)

game:on_wake("on_lobby_countdown_ended", function(ctx)
  local players = ctx.session.participants
  ctx.ui:render({
    title = "⚔️ Match Begun!",
    body_lines = { "Total players: " .. #players }
  })
end)
```

### Duo Invites with Escrow

```lua
game:on_command("duel", function(ctx)
  local target_id = ctx.args.target_user_id
  if not target_id then return end

  ctx.lobby:create_duo_invite(target_id, 25, nil, "on_duel_accepted")
end)
```

### Exclusive Atomic Claim Grid

Prevent race conditions in fast-reaction multiplayer games:

```lua
ctx.lobby:exclusive_claim_grid(3, ctx.session.participants, 15, "on_chests_opened")
```

---

## AI & Media Gateways

### Dynamic AI Generation

```lua
game:on_button("consult_oracle", function(ctx)
  ctx.ai:generate_json(
    "You are an eccentric fantasy merchant. Return JSON with 'quote' and 'specialOffer'.",
    "A player approaches looking for rare artifacts.",
    "ai_low",
    0.8,
    400,
    "on_oracle_response"
  )
end)

game:on_callback("on_oracle_response", function(ctx)
  local data = ctx.args.callback_data
  ctx.ui:render({
    title = "🔮 The Merchant Speaks",
    body_lines = { data.quote or "Welcome, traveler!" }
  })
end)
```

### GIF Search

```lua
ctx.media:search_gif("victory celebration", "on_gif_found")
```

---

## HTTP & Safe Network Access

### Safe Outbound HTTP (`ctx.http:get` / `ctx.http:post`)

Angela games execute inside a secure WebAssembly (WASM) sandbox. Because the sandbox **does not possess raw POSIX OS sockets**, synchronous network calls (such as `luasocket`, `socket.http`, or C-bindings) **cannot run** and will fail.

All network requests must be requested through Angela's host-mediated **two-phase HTTP gateway**:
1. **Phase 1 (Request)**: Your cartridge registers an intent via `ctx.http:get(url, headers, callback)`.
2. **Phase 2 (Callback)**: Angela's host verifies SSRF policy, queries the API safely, and delivers parsed data to `ctx.args.callback_data`.

```lua
game:on_command("trivia", function(ctx)
  -- Phase 1: Request data via host proxy
  ctx.http:get("https://the-trivia-api.com/v2/questions?limit=1", nil, "on_trivia_received")
end)

game:on_callback("on_trivia_received", function(ctx)
  -- Phase 2: Host delivers payload
  local questions = ctx.args.callback_data
  if questions and #questions > 0 then
    local q = questions[1]
    ctx.ui:send_chat({
      title = "🧠 Question Time!",
      text = q.question.text,
      buttons = {
        Button.new({ custom_id = "ans_correct", label = q.correctAnswer, style = "primary" }),
        Button.new({ custom_id = "ans_wrong", label = q.incorrectAnswers[1], style = "secondary" }),
      }
    })
  end
end)
```

---

## Sandboxing & Dependency Constraints

To guarantee zero latency spikes, airtight security, and deterministic runs across all Discord nodes:

1. **Pure Lua Only**: Cartridges must use standard Lua built-ins (`string`, `table`, `math`, `os.time`, `os.difftime`).
2. **No Native C/C++ Dynamic Libraries**: C-libraries (`.so` / `.dll`) or modules requiring system OS handles (`io.popen`, `os.execute`) are blocked in WASM.
3. **Official SDK Only**: Only import `angela` (`angela-lua`). All interactions with Discord, player balances, inventory, and network go through `ctx`.
4. **State Persistence**: Cartridges cannot write to local disk. State across turns is stored in `ctx.state` or `ctx.storage`.

---

## Discord Utilities

### Channel Management & Chat Listening

```lua
-- Lock channel during critical minigame phase
ctx.discord:lock_channel(30)

-- Listen for chat message answers
ctx.discord:listen_messages("42", nil, "on_correct_answer", true)
```

---

## Cartridge Project Layout & CLI

Use `angela-cli` to scaffold, test, and publish your cartridge.

### Standard File Layout

```text
my_game/
├── manifest.json       # Game metadata, config schema, target slot
├── main.lua            # Lua entry script exporting handle = game:handle
└── assets/             # Game sprites referenced by ctx.canvas:sprite()
    ├── boss.png
    └── coin.png
```

### `manifest.json` Specification

Angela cartridges require a valid `manifest.json` at project root matching the CLI and API specifications:

```json
{
  "package_id": "dice-master-lua",
  "name": "Dice Master Lua",
  "version": "0.1.0",
  "language": "lua",
  "entrypoint": "main.lua",
  "license": "proprietary",
  "public": false,
  "target_guild_id": "905194979650052208",
  "target_slot_id": 1,
  "default_command": "dice-master-lua",
  "default_ui_theme": "AUTO",
  "max_flux_per_tick": 5,
  "config_schema": {
    "currency_name": "Coins",
    "currency_emoji": "🪙",
    "cooldown_seconds": 30
  }
}
```

#### Manifest Fields Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `package_id` | `string` | **Yes** | 2–63 lowercase alphanumeric characters (`a-z0-9._-`). Unique cartridge identifier. |
| `name` | `string` | **Yes** | Human-readable cartridge display name. |
| `version` | `string` | **Yes** | Semantic version string (e.g. `"0.1.0"`). |
| `language` | `string` | **Yes** | Cartridge language: `"lua"`, `"python"`, `"typescript"`, or `"javascript"`. |
| `entrypoint` | `string` | **Yes** | Relative path to entry file matching language extension (`.lua`, `.py`, `.ts`, `.js`). |
| `license` | `string` | **Yes** | `"open"` (open source; authorized users can inspect) or `"proprietary"` (author-only code visibility). |
| `public` | `boolean` | **Yes** | Whether to list the cartridge publicly on the Angela marketplace. |
| `target_guild_id` | `string` | **Yes** | Target Discord server guild ID where this cartridge slot lives. |
| `target_slot_id` | `integer` | **Yes** | Target slot ID number on the server (e.g. `1`, `2`). |
| `default_command` | `string` | No | Slash command trigger for this game (defaults to `package_id`). |
| `default_ui_theme` | `string` | No | Default rendering mode: `"AUTO"`, `"CV2"`, or `"CLASSIC_EMBED"`. |
| `max_flux_per_tick` | `integer` | No | Compute Flux ceiling per interaction tick (1 to 100, defaults to 5). |
| `config_schema` | `object` | No | Default server configuration options merged into `ctx.config`. |

### CLI Workflow

```bash
# Initialize a new Lua cartridge
angela init

# Validate syntax, manifest, and dependencies
angela validate

# Run interactive simulation with simulated Discord events
angela dev

# Authenticate with Discord
angela login

# Upload and deploy cartridge to your server
angela push
```

---

## License

MIT License. Built for the Angela Games Ecosystem.

