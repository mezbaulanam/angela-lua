--
-- angela/context.lua — Core Game Context and Sub-APIs for Angela Lua cartridges
--
local models = require("angela.models")
local canvas_mod = require("angela.canvas")

local context = {}

-- ==================== EconomyContext ====================
local EconomyContext = {}
EconomyContext.__index = EconomyContext

function EconomyContext.new(ctx)
  local self = setmetatable({}, EconomyContext)
  self._ctx = ctx
  return self
end

local function apply_currency(intent, currency)
  if currency ~= nil and tostring(currency) ~= "" then
    intent.currency = tostring(currency)
  end
end

function EconomyContext:get_balance(user_id, currency)
  local intent = {
    op = "ECONOMY_MUTATE",
    action = "GET_BALANCE",
    user_id = math.floor(tonumber(user_id) or 0),
  }
  apply_currency(intent, currency)
  self._ctx:add_intent(intent)
  return intent
end

function EconomyContext:take(user_id, amount, reason, currency)
  local intent = {
    op = "ECONOMY_MUTATE",
    action = "TAKE",
    user_id = math.floor(tonumber(user_id) or 0),
    amount = math.floor(tonumber(amount) or 0),
    reason = tostring(reason or ""),
  }
  apply_currency(intent, currency)
  self._ctx:add_intent(intent)
  return intent
end

function EconomyContext:give(user_id, amount, reason, clamp_min, clamp_max, currency)
  local intent = {
    op = "ECONOMY_MUTATE",
    action = "GIVE",
    user_id = math.floor(tonumber(user_id) or 0),
    amount = math.floor(tonumber(amount) or 0),
    reason = tostring(reason or ""),
  }
  if clamp_min ~= nil then
    intent.clamp_min = math.floor(tonumber(clamp_min) or 0)
  end
  if clamp_max ~= nil then
    intent.clamp_max = math.floor(tonumber(clamp_max) or 0)
  end
  apply_currency(intent, currency)
  self._ctx:add_intent(intent)
  return intent
end

function EconomyContext:escrow_lock(user_id, amount, reason, currency)
  local intent = {
    op = "ECONOMY_MUTATE",
    action = "ESCROW_LOCK",
    user_id = math.floor(tonumber(user_id) or 0),
    amount = math.floor(tonumber(amount) or 0),
    reason = tostring(reason or ""),
  }
  apply_currency(intent, currency)
  self._ctx:add_intent(intent)
  return intent
end

function EconomyContext:escrow_release(user_id, amount, reason, currency)
  local intent = {
    op = "ECONOMY_MUTATE",
    action = "ESCROW_RELEASE",
    user_id = math.floor(tonumber(user_id) or 0),
    amount = math.floor(tonumber(amount) or 0),
    reason = tostring(reason or ""),
  }
  apply_currency(intent, currency)
  self._ctx:add_intent(intent)
  return intent
end

function EconomyContext:escrow_refund(user_id, amount, reason, currency)
  local intent = {
    op = "ECONOMY_MUTATE",
    action = "ESCROW_REFUND",
    user_id = math.floor(tonumber(user_id) or 0),
    amount = math.floor(tonumber(amount) or 0),
    reason = tostring(reason or ""),
  }
  apply_currency(intent, currency)
  self._ctx:add_intent(intent)
  return intent
end

function EconomyContext:auto_buy(user_id, item_ids, quantity)
  local intent = {
    op = "ECONOMY_MUTATE",
    action = "AUTO_BUY",
    user_id = math.floor(tonumber(user_id) or 0),
    item_ids = item_ids or {},
    quantity = math.floor(tonumber(quantity) or 10),
  }
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== InventoryContext ====================
local InventoryContext = {}
InventoryContext.__index = InventoryContext

function InventoryContext.new(ctx)
  local self = setmetatable({}, InventoryContext)
  self._ctx = ctx
  return self
end

function InventoryContext:get_server_items(user_id)
  local intent = {
    op = "INVENTORY_MUTATE",
    action = "GET_SERVER_ITEMS",
    user_id = math.floor(tonumber(user_id) or 0),
  }
  self._ctx:add_intent(intent)
  return intent
end

function InventoryContext:consume_server_item(user_id, item_id, qty)
  local intent = {
    op = "INVENTORY_MUTATE",
    action = "CONSUME_SERVER_ITEM",
    user_id = math.floor(tonumber(user_id) or 0),
    item_id = tostring(item_id or ""),
    quantity = math.floor(tonumber(qty) or 1),
  }
  self._ctx:add_intent(intent)
  return intent
end

function InventoryContext:give_server_item(user_id, item_id, qty)
  local intent = {
    op = "INVENTORY_MUTATE",
    action = "GIVE_SERVER_ITEM",
    user_id = math.floor(tonumber(user_id) or 0),
    item_id = tostring(item_id or ""),
    quantity = math.floor(tonumber(qty) or 1),
  }
  self._ctx:add_intent(intent)
  return intent
end

function InventoryContext:roll_break(user_id, item_id, probability)
  local intent = {
    op = "INVENTORY_MUTATE",
    action = "ROLL_BREAK",
    user_id = math.floor(tonumber(user_id) or 0),
    item_id = tostring(item_id or ""),
    break_chance = tonumber(probability) or 0.05,
  }
  self._ctx:add_intent(intent)
  return intent
end

function InventoryContext:add_sub_item(user_id, item_id, qty)
  local intent = {
    op = "INVENTORY_MUTATE",
    action = "ADD_SUB_ITEM",
    user_id = math.floor(tonumber(user_id) or 0),
    item_id = tostring(item_id or ""),
    quantity = math.floor(tonumber(qty) or 1),
  }
  self._ctx:add_intent(intent)
  return intent
end

function InventoryContext:remove_sub_item(user_id, item_id, qty)
  local intent = {
    op = "INVENTORY_MUTATE",
    action = "REMOVE_SUB_ITEM",
    user_id = math.floor(tonumber(user_id) or 0),
    item_id = tostring(item_id or ""),
    quantity = math.floor(tonumber(qty) or 1),
  }
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== UIContext ====================
local UIContext = {}
UIContext.__index = UIContext

function UIContext.new(ctx)
  local self = setmetatable({}, UIContext)
  self._ctx = ctx
  return self
end

function UIContext:render(opts)
  opts = opts or {}
  local layout = {}
  if opts.title then layout.title = tostring(opts.title) end
  if opts.subtitle then layout.subtitle = tostring(opts.subtitle) end
  if opts.body_lines then
    if type(opts.body_lines) == "string" then
      layout.body_lines = { opts.body_lines }
    else
      layout.body_lines = opts.body_lines
    end
  end
  if opts.thumbnail then layout.thumbnail = tostring(opts.thumbnail) end
  if opts.accent_color then
    local c = opts.accent_color
    if type(c) == "string" and c:sub(1, 1) == "#" then
      layout.accent_color = tonumber(c:sub(2), 16)
    else
      layout.accent_color = tonumber(c)
    end
  end
  if opts.buttons then
    local btn_list = {}
    for i, b in ipairs(opts.buttons) do
      btn_list[i] = b.to_dict and b:to_dict() or b
    end
    layout.buttons = btn_list
  end
  if opts.selects then
    local sel_list = {}
    for i, s in ipairs(opts.selects) do
      sel_list[i] = s.to_dict and s:to_dict() or s
    end
    layout.selects = sel_list
  end

  local canvas_payload = nil
  if opts.image then
    if type(opts.image) == "table" and opts.image.to_dict then
      canvas_payload = opts.image:to_dict()
      layout.image = "attachment://" .. (opts.image.filename or "scene.png")
    else
      layout.image = tostring(opts.image)
    end
  end

  local intent = {
    op = "UI_RENDER",
    target = opts.target or "EDIT_MAIN",
    ephemeral = opts.ephemeral == true,
    mode = opts.mode or "AUTO",
    layout = layout,
  }
  if canvas_payload then
    intent.canvas_scene = canvas_payload
  end
  self._ctx:add_intent(intent)
  return intent
end

function UIContext:render_cv2(container, ephemeral, target, canvas_scene)
  local layout = container.to_dict and container:to_dict() or container
  local intent = {
    op = "UI_RENDER",
    target = target or "EDIT_MAIN",
    ephemeral = ephemeral == true,
    mode = "CV2",
    layout = layout,
  }
  if canvas_scene then
    intent.canvas_scene = canvas_scene.to_dict and canvas_scene:to_dict() or canvas_scene
  end
  self._ctx:add_intent(intent)
  return intent
end

function UIContext:render_embed(embed, components, ephemeral, target, canvas_scene)
  local embed_dict = embed.to_dict and embed:to_dict() or embed
  local layout = { embed = embed_dict }
  if components then
    local comps = {}
    for i, c in ipairs(components) do
      comps[i] = c.to_dict and c:to_dict() or c
    end
    layout.components = comps
  end
  local intent = {
    op = "UI_RENDER",
    target = target or "EDIT_MAIN",
    ephemeral = ephemeral == true,
    mode = "CLASSIC_EMBED",
    layout = layout,
  }
  if canvas_scene then
    intent.canvas_scene = canvas_scene.to_dict and canvas_scene:to_dict() or canvas_scene
  end
  self._ctx:add_intent(intent)
  return intent
end

function UIContext:reply_ephemeral(text, embed, container)
  if container then
    return self:render_cv2(container, true, "REPLY_EPHEMERAL")
  end
  if embed then
    return self:render_embed(embed, nil, true, "REPLY_EPHEMERAL")
  end
  return self:render({
    body_lines = { tostring(text or "") },
    ephemeral = true,
    target = "REPLY_EPHEMERAL",
  })
end

function UIContext:open_modal(title, inputs, callback_id)
  local serialized = {}
  if inputs then
    for i, inp in ipairs(inputs) do
      serialized[i] = inp.to_dict and inp:to_dict() or inp
    end
  end
  local intent = {
    op = "UI_MODAL",
    title = tostring(title or ""),
    callback_id = tostring(callback_id or ""),
    inputs = serialized,
  }
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== LobbyContext ====================
local LobbyContext = {}
LobbyContext.__index = LobbyContext

function LobbyContext.new(ctx)
  local self = setmetatable({}, LobbyContext)
  self._ctx = ctx
  return self
end

function LobbyContext:create_join_lobby(max_players, duration, on_start)
  local intent = {
    op = "LOBBY_OP",
    action = "CREATE_JOIN_LOBBY",
    max_players = math.floor(tonumber(max_players) or 25),
    duration = math.floor(tonumber(duration) or 120),
    callback_event_id = tostring(on_start or "on_lobby_start"),
  }
  self._ctx:add_intent(intent)
  return intent
end

function LobbyContext:create_duo_invite(partner_id, entry_fee, loadout_shop, on_accept)
  local intent = {
    op = "LOBBY_OP",
    action = "CREATE_DUO_INVITE",
    partner_id = math.floor(tonumber(partner_id) or 0),
    entry_fee = math.floor(tonumber(entry_fee) or 10),
    callback_event_id = tostring(on_accept or "on_invite_accept"),
  }
  if loadout_shop ~= nil then
    intent.loadout_shop = loadout_shop
  end
  self._ctx:add_intent(intent)
  return intent
end

function LobbyContext:exclusive_claim_grid(count, eligible_users, timeout, on_resolve)
  local users = {}
  if eligible_users then
    for i, u in ipairs(eligible_users) do
      users[i] = math.floor(tonumber(u) or 0)
    end
  end
  local intent = {
    op = "LOBBY_OP",
    action = "EXCLUSIVE_CLAIM_GRID",
    count = math.floor(tonumber(count) or 1),
    eligible_users = users,
    timeout = math.floor(tonumber(timeout) or 20),
    callback_event_id = tostring(on_resolve or "on_claim_resolve"),
  }
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== AIContext ====================
local AIContext = {}
AIContext.__index = AIContext

function AIContext.new(ctx)
  local self = setmetatable({}, AIContext)
  self._ctx = ctx
  return self
end

function AIContext:generate_json(system_prompt, user_prompt, tier, temperature, max_tokens, callback)
  local intent = {
    op = "AI_GENERATE",
    tier = tostring(tier or "ai_low"),
    system_prompt = tostring(system_prompt or ""),
    user_prompt = tostring(user_prompt or ""),
    temperature = tonumber(temperature) or 1.0,
    max_tokens = math.floor(tonumber(max_tokens) or 400),
    callback_event_id = tostring(callback or "on_ai_ready"),
  }
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== MediaContext ====================
local MediaContext = {}
MediaContext.__index = MediaContext

function MediaContext.new(ctx)
  local self = setmetatable({}, MediaContext)
  self._ctx = ctx
  return self
end

function MediaContext:search_gif(query, callback)
  local intent = {
    op = "MEDIA_SEARCH_GIF",
    query = tostring(query or ""),
    callback_event_id = tostring(callback or "on_gif_ready"),
  }
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== HTTPContext ====================
local HTTPContext = {}
HTTPContext.__index = HTTPContext

function HTTPContext.new(ctx)
  local self = setmetatable({}, HTTPContext)
  self._ctx = ctx
  return self
end

function HTTPContext:get(url, headers, callback)
  return self:request(url, "GET", headers, nil, callback)
end

function HTTPContext:request(url, method, headers, body, callback)
  local intent = {
    op = "HTTP_REQUEST",
    method = string.upper(tostring(method or "GET")),
    url = tostring(url or ""),
    headers = headers or {},
    body = body,
    callback_event_id = tostring(callback or "on_http_response"),
  }
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== DiscordContext ====================
local DiscordContext = {}
DiscordContext.__index = DiscordContext

function DiscordContext.new(ctx)
  local self = setmetatable({}, DiscordContext)
  self._ctx = ctx
  return self
end

function DiscordContext:lock_channel(duration_seconds)
  local intent = {
    op = "CHANNEL_LOCK",
    duration_seconds = math.floor(tonumber(duration_seconds) or 20),
  }
  self._ctx:add_intent(intent)
  return intent
end

function DiscordContext:listen_messages(exact_match, regex, callback, enabled)
  local intent = {
    op = "LISTEN_MESSAGES",
    enabled = enabled ~= false,
    callback_event_id = tostring(callback or "on_message"),
  }
  if exact_match then intent.exact_match = tostring(exact_match) end
  if regex then intent.regex = tostring(regex) end
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== StorageContext ====================
local StorageContext = {}
StorageContext.__index = StorageContext

function StorageContext.new(ctx)
  local self = setmetatable({}, StorageContext)
  self._ctx = ctx
  return self
end

function StorageContext:get(key, default_val)
  local val = self._ctx.state[key]
  if val == nil then return default_val end
  return val
end

function StorageContext:set(key, value)
  self._ctx.state[key] = value
end

function StorageContext:set_cooldown(user_id, seconds)
  local intent = {
    op = "STORAGE_MUTATE",
    action = "SET_COOLDOWN",
    user_id = math.floor(tonumber(user_id) or 0),
    seconds = math.floor(tonumber(seconds) or 0),
  }
  self._ctx:add_intent(intent)
  return intent
end

-- ==================== Context ====================
local Context = {}
Context.__index = Context

function Context.new(raw_event)
  raw_event = raw_event or {}
  local self = setmetatable({}, Context)

  self.raw_event = raw_event
  self.event_type = tostring(raw_event.event_type or "COMMAND")
  self.event_id = tostring(raw_event.event_id or "")
  self.guild_id = math.floor(tonumber(raw_event.guild_id) or 0)
  self.channel_id = math.floor(tonumber(raw_event.channel_id) or 0)
  self.user = models.User.new(raw_event.user)
  self.args = models.Args.new(raw_event.args)
  self.session = models.Session.new(raw_event.session)

  self.status = self.session.status
  self.round = self.session.round
  self.state = self.session.state

  self.config = raw_event.config or {}
  self.secrets = raw_event.secrets or {}

  self._intents = {}

  -- Sub-APIs
  self.economy = EconomyContext.new(self)
  self.inventory = InventoryContext.new(self)
  self.ui = UIContext.new(self)
  self.canvas = canvas_mod.CanvasContext.new()
  self.lobby = LobbyContext.new(self)
  self.ai = AIContext.new(self)
  self.media = MediaContext.new(self)
  self.http = HTTPContext.new(self)
  self.discord = DiscordContext.new(self)
  self.storage = StorageContext.new(self)

  -- host_id property
  if #self.session.participants > 0 then
    self.host_id = self.session.participants[1]
  else
    self.host_id = self.user.id
  end

  return self
end

function Context:add_intent(intent)
  table.insert(self._intents, intent)
end

function Context:finish()
  self.status = "FINISHED"
end

function Context:pause()
  self.status = "PAUSED"
end

function Context:next_round()
  self.round = self.round + 1
  return self.round
end

function Context:schedule(delay_seconds, callback)
  local intent = {
    op = "SCHEDULE_WAKE",
    delay_seconds = math.floor(tonumber(delay_seconds) or 0),
    callback_event_id = tostring(callback or "on_sleep_complete"),
  }
  self:add_intent(intent)
  return intent
end

function Context:sleep(seconds, callback)
  local s = tonumber(seconds) or 0
  if s > 3 then
    self.status = "SLEEPING"
  end
  return self:schedule(s, callback)
end

function Context:to_response()
  return {
    status = self.status,
    round = self.round,
    updated_state = self.state,
    intents = self._intents,
  }
end

context.Context = Context
context.EconomyContext = EconomyContext
context.InventoryContext = InventoryContext
context.UIContext = UIContext
context.LobbyContext = LobbyContext
context.AIContext = AIContext
context.MediaContext = MediaContext
context.HTTPContext = HTTPContext
context.DiscordContext = DiscordContext
context.StorageContext = StorageContext

return context

