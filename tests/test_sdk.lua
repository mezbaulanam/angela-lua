--
-- tests/test_sdk.lua — Comprehensive test suite for Angela Lua SDK
--
-- Set package.path so require("angela") works from the repository root
package.path = "./?.lua;./?/init.lua;" .. package.path

local angela = require("angela")
local json = angela.json

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("Assertion failed: expected '%s', got '%s'. %s",
      tostring(expected), tostring(actual), tostring(msg or "")))
  end
end

local function assert_true(val, msg)
  if not val then
    error("Assertion failed: expected truthy value. " .. tostring(msg or ""))
  end
end

local SAMPLE_EVENT = {
  event_type = "COMMAND",
  event_id = "start",
  guild_id = 905194979650052208,
  channel_id = 1321720365189300234,
  user = {
    id = 496644923601453076,
    name = "Ray_quaza",
    avatar_url = "https://cdn.discordapp.com/avatars/496644923601453076/abc.png",
  },
  args = {
    subcommand = nil,
    raw_args = "all",
    target_user_id = 112233445566778899,
    modal_inputs = { secret_number = "42" },
    select_values = { "moon_talisman", "aqua_lens" },
    message_content = "42",
    callback_data = {},
  },
  session = {
    session_id = "sess_a1b2c3d4",
    round = 2,
    participants = { 496644923601453076, 112233445566778899 },
    status = "ACTIVE",
    state = {
      rod_col = 2,
      rod_row = 1,
      fish_spots = { { col = 1, row = 0, fish_id = "sapphire_sardine" } },
    },
  },
  config = {
    ui_theme = "CV2",
    currency_name = "Shells",
    cooldown_seconds = 20,
  },
  secrets = {
    admin_key = "private_val",
  },
}

local tests_passed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    tests_passed = tests_passed + 1
    print("✔ " .. name)
  else
    print("✘ " .. name)
    error(err)
  end
end

-- 1. JSON Encoder and Decoder
test("JSON parser and serializer round-trip", function()
  local payload = {
    status = "ACTIVE",
    round = 1,
    nested = { score = 100, valid = true, empty = json.null },
    items = { "apple", "banana", "cherry" },
  }
  local encoded = json.encode(payload)
  assert_true(type(encoded) == "string", "encoded must be a string")
  local decoded = json.decode(encoded)
  assert_eq(decoded.status, "ACTIVE")
  assert_eq(decoded.round, 1)
  assert_eq(decoded.nested.score, 100)
  assert_eq(decoded.nested.valid, true)
  assert_eq(#decoded.items, 3)
  assert_eq(decoded.items[1], "apple")
end)

-- 2. Context parsing
test("Context parses event correctly", function()
  local ctx = angela.Context.new(SAMPLE_EVENT)
  assert_eq(ctx.event_type, "COMMAND")
  assert_eq(ctx.event_id, "start")
  assert_eq(ctx.guild_id, 905194979650052208)
  assert_eq(ctx.channel_id, 1321720365189300234)
  assert_eq(ctx.user.id, 496644923601453076)
  assert_eq(ctx.user.name, "Ray_quaza")
  assert_eq(ctx.host_id, 496644923601453076)
  assert_eq(ctx.args.target_user_id, 112233445566778899)
  assert_eq(ctx.args.modal_inputs.secret_number, "42")
  assert_eq(ctx.session.session_id, "sess_a1b2c3d4")
  assert_eq(ctx.round, 2)
  assert_eq(ctx.state.rod_col, 2)
  assert_eq(ctx.config.currency_name, "Shells")
  assert_eq(ctx.secrets.admin_key, "private_val")
end)

-- 3. Economy Intents & Multi-Currency
test("Economy context generates intents with currency support", function()
  local ctx = angela.Context.new(SAMPLE_EVENT)
  ctx.economy:get_balance(ctx.user.id)
  ctx.economy:give(ctx.user.id, 50, "Won prize", 0, 500, "Gold")
  ctx.economy:take(ctx.user.id, 20, "Fee")
  ctx.economy:escrow_lock(ctx.user.id, 100, "Bet", "Diamonds")
  ctx.economy:escrow_release(ctx.user.id, 100, "Paid out")
  ctx.economy:escrow_refund(ctx.user.id, 100, "Refunded")
  ctx.economy:auto_buy(ctx.user.id, { "rod", "bait" }, 5)

  local res = ctx:to_response()
  assert_eq(#res.intents, 7)
  assert_eq(res.intents[1].op, "ECONOMY_MUTATE")
  assert_eq(res.intents[1].action, "GET_BALANCE")
  assert_eq(res.intents[1].currency, nil)
  assert_eq(res.intents[2].action, "GIVE")
  assert_eq(res.intents[2].amount, 50)
  assert_eq(res.intents[2].clamp_max, 500)
  assert_eq(res.intents[2].currency, "Gold")
  assert_eq(res.intents[3].action, "TAKE")
  assert_eq(res.intents[3].currency, nil)
  assert_eq(res.intents[4].action, "ESCROW_LOCK")
  assert_eq(res.intents[4].currency, "Diamonds")
  assert_eq(res.intents[7].action, "AUTO_BUY")
end)

-- 4. Inventory Intents
test("Inventory context generates intents", function()
  local ctx = angela.Context.new(SAMPLE_EVENT)
  ctx.inventory:get_server_items(ctx.user.id)
  ctx.inventory:consume_server_item(ctx.user.id, "potion", 1)
  ctx.inventory:give_server_item(ctx.user.id, "potion", 2)
  ctx.inventory:roll_break(ctx.user.id, "fishing_rod", 0.075)
  ctx.inventory:add_sub_item(ctx.user.id, "sapphire_sardine", 1)
  ctx.inventory:remove_sub_item(ctx.user.id, "sapphire_sardine", 1)

  local res = ctx:to_response()
  assert_eq(#res.intents, 6)
  assert_eq(res.intents[1].op, "INVENTORY_MUTATE")
  assert_eq(res.intents[4].action, "ROLL_BREAK")
  assert_eq(res.intents[4].break_chance, 0.075)
end)

-- 5. UI Components & Render
test("UI context renders components, modals, and embeds", function()
  local ctx = angela.Context.new(SAMPLE_EVENT)
  local btn = angela.Button.new({ custom_id = "test_btn", label = "Click", emoji = "🚀" })
  local sel = angela.Select.new({
    custom_id = "test_sel",
    options = { { label = "A", value = "a" } },
  })

  -- Universal render
  ctx.ui:render({
    title = "Test",
    body_lines = { "Line 1", "Line 2" },
    buttons = { btn },
    selects = { sel },
  })

  -- Ephemeral reply
  ctx.ui:reply_ephemeral("Secret feedback")

  -- Modal
  local inp = angela.TextInput.new({ custom_id = "inp_1", label = "Name", required = true })
  ctx.ui:open_modal("Modal Title", { inp }, "cb_modal")

  -- Components V2 container
  local cont = angela.Container.new({ accent_color = "#5865F2" })
  cont:add(angela.Section.new({
    text_displays = { angela.TextDisplay.new("Section Text") },
    accessory = angela.Thumbnail.new("https://example.com/thumb.png"),
  }))
  cont:add(angela.Separator.new({ divider = true }))
  ctx.ui:render_cv2(cont)

  -- Classic embed
  local embed = angela.Embed.new({ title = "Embed Title", color = 0xFF0000 })
  embed:add_field("Field 1", "Val 1", true)
  ctx.ui:render_embed(embed)

  -- Public chat delivery (send_chat / NEW_MESSAGE)
  ctx.ui:send_chat("Public Chat Announcement")

  local res = ctx:to_response()
  assert_eq(#res.intents, 6)
  assert_eq(res.intents[1].op, "UI_RENDER")
  assert_eq(res.intents[1].mode, "AUTO")
  assert_eq(res.intents[2].target, "REPLY_EPHEMERAL")
  assert_eq(res.intents[3].op, "UI_MODAL")
  assert_eq(res.intents[4].mode, "CV2")
  assert_eq(res.intents[5].mode, "CLASSIC_EMBED")
  assert_eq(res.intents[6].op, "UI_RENDER")
  assert_eq(res.intents[6].target, "NEW_MESSAGE")
  assert_eq(res.intents[6].ephemeral, false)
end)

-- 6. Canvas Engine
test("Canvas fluent scene builder", function()
  local ctx = angela.Context.new(SAMPLE_EVENT)
  local scene = ctx.canvas:create({ width = 640, height = 360, filename = "test.png" })
  local bg = scene:layer("bg", "cache_bg_v1")
  bg:linear_gradient({ 0, 0, 640, 360 }, { 20, 30, 60 }, { 240, 140, 80 }, 1.2)
  bg:celestial_body(320, 140, 20, 70, { 255, 245, 210 }, { 255, 190, 80, 90 })
  bg:sine_waves(170, 260, 12, { 255, 255, 255, 60 })
  bg:procedural_palm(120, 345, 210, 23)
  bg:vignette(50, 1.1)

  local fg = scene:layer("fg")
  fg:radial_glow(300, 185, 38, { 255, 215, 0 }, 42)
  fg:sprite("fish.png", 300, 185, 62, 62)
  fg:avatar(496644923601453076, 200, 65, 80, true, { 255, 215, 0 }, 3)
  fg:polygon({ { 10, 10 }, { 50, 20 }, { 30, 60 } }, { 255, 0, 0 }, { 255, 255, 255 })
  fg:line({ { 0, 0 }, { 100, 100 } }, { 200, 200, 200 }, 2)
  fg:arc({ 50, 50, 100, 100 }, 0, 180, { 100, 100, 100 }, 1)
  fg:rounded_rect({ 10, 10, 100, 50 }, 8, { 10, 10, 10 }, { 255, 255, 255 }, 1)
  fg:progress_bar({ 20, 20, 200, 40 }, 50, 100, { 0, 0, 0 }, { 0, 255, 0 }, 4)
  fg:text_box({ 10, 10, 200, 50 }, "Hello Angela", "bold", 14, { 255, 255, 255 })

  local d = scene:to_dict()
  assert_eq(d.width, 640)
  assert_eq(d.height, 360)
  assert_eq(#d.layers, 2)
  assert_eq(d.layers[1].cache_key, "cache_bg_v1")
  assert_eq(#d.layers[1].ops, 5)
  assert_eq(#d.layers[2].ops, 9)
end)

-- 7. Sub-contexts & Life-cycle
test("Sub-contexts generate correct intents and manage lifecycle", function()
  local ctx = angela.Context.new(SAMPLE_EVENT)
  ctx.lobby:create_join_lobby(16, 60, "on_join_done")
  ctx.lobby:create_duo_invite(112233, 20, nil, "on_duo_accept")
  ctx.lobby:exclusive_claim_grid(3, { 1, 2, 3 }, 15, "on_claim")

  ctx.ai:generate_json("sys", "user", "ai_low", 1.0, 400, "on_ai")
  ctx.media:search_gif("win", "on_gif")
  ctx.http:get("https://api.example.com", nil, "on_http")
  ctx.discord:lock_channel(30)
  ctx.discord:listen_messages("42", nil, "on_msg")
  ctx.storage:set("test_key", "test_val")
  assert_eq(ctx.storage:get("test_key"), "test_val")
  ctx.storage:set_cooldown(ctx.user.id, 60)

  ctx:sleep(10, "on_wake_up")
  assert_eq(ctx.status, "SLEEPING")
  ctx:next_round()
  assert_eq(ctx.round, 3)

  local res = ctx:to_response()
  assert_eq(res.status, "SLEEPING")
  assert_eq(res.round, 3)
  assert_eq(res.updated_state.test_key, "test_val")
  assert_true(#res.intents >= 9, "must have collected sub-context intents")
end)

-- 8. Game Event Routing
test("Game routing works for command and button", function()
  local game = angela.Game.new("test_game")
  local command_called = false
  local button_called = false

  game:on_command(function(ctx)
    command_called = true
    ctx.state.step = "command_done"
  end)

  game:on_button("catch_btn", function(ctx)
    button_called = true
    ctx.state.step = "button_done"
  end)

  -- Dispatch command
  local res1 = game:handle(SAMPLE_EVENT)
  assert_true(command_called, "command handler should have fired")
  assert_eq(res1.updated_state.step, "command_done")

  -- Dispatch button
  local btn_event = {
    event_type = "BUTTON",
    event_id = "catch_btn",
    user = { id = 123 },
    session = { round = 1, state = {} },
  }
  local res2 = game:handle(btn_event)
  assert_true(button_called, "button handler should have fired")
  assert_eq(res2.updated_state.step, "button_done")
end)

print(string.format("\n==============================\nAll %d tests passed successfully!\n==============================", tests_passed))

