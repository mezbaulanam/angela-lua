--
-- angela/game.lua — Central application and event router for Angela Lua cartridges
--
local json = require("angela.json")
local context_mod = require("angela.context")
local Context = context_mod.Context

local game_mod = {}

local Game = {}
Game.__index = Game

function Game.new(name)
  local self = setmetatable({}, Game)
  self.name = tostring(name or "angela_game")
  self._command_handlers = {}
  self._button_handlers = {}
  self._select_handlers = {}
  self._modal_handlers = {}
  self._message_handlers = {}
  self._timer_wake_handlers = {}
  self._callback_handlers = {}
  self._default_handler = nil
  return self
end

function Game:on_command(subcommand_or_fn, maybe_fn)
  if type(subcommand_or_fn) == "function" then
    self._command_handlers["__default__"] = subcommand_or_fn
    return subcommand_or_fn
  elseif type(subcommand_or_fn) == "string" and type(maybe_fn) == "function" then
    self._command_handlers[subcommand_or_fn] = maybe_fn
    return maybe_fn
  else
    local sub = subcommand_or_fn
    return function(fn)
      self._command_handlers[sub or "__default__"] = fn
      return fn
    end
  end
end

function Game:on_button(custom_id, maybe_fn)
  if type(maybe_fn) == "function" then
    self._button_handlers[custom_id] = maybe_fn
    return maybe_fn
  end
  return function(fn)
    self._button_handlers[custom_id] = fn
    return fn
  end
end

function Game:on_select(custom_id, maybe_fn)
  if type(maybe_fn) == "function" then
    self._select_handlers[custom_id] = maybe_fn
    return maybe_fn
  end
  return function(fn)
    self._select_handlers[custom_id] = fn
    return fn
  end
end

function Game:on_modal(callback_id, maybe_fn)
  if type(maybe_fn) == "function" then
    self._modal_handlers[callback_id] = maybe_fn
    return maybe_fn
  end
  return function(fn)
    self._modal_handlers[callback_id] = fn
    return fn
  end
end

function Game:on_message(fn)
  table.insert(self._message_handlers, fn)
  return fn
end

function Game:on_wake(callback_id, maybe_fn)
  local id = callback_id or "on_sleep_complete"
  if type(maybe_fn) == "function" then
    self._timer_wake_handlers[id] = maybe_fn
    return maybe_fn
  end
  return function(fn)
    self._timer_wake_handlers[id] = fn
    return fn
  end
end

function Game:on_callback(callback_id, maybe_fn)
  if type(maybe_fn) == "function" then
    self._callback_handlers[callback_id] = maybe_fn
    return maybe_fn
  end
  return function(fn)
    self._callback_handlers[callback_id] = fn
    return fn
  end
end

function Game:default(fn)
  self._default_handler = fn
  return fn
end

function Game:handle(event)
  local ctx
  if type(event) == "string" then
    local ok, parsed = pcall(json.decode, event)
    if not ok then
      error("Failed to parse event JSON: " .. tostring(parsed))
    end
    ctx = Context.new(parsed)
  elseif type(event) == "table" then
    if event.to_response then
      ctx = event
    else
      ctx = Context.new(event)
    end
  else
    error("Expected string or table event, got " .. type(event))
  end

  local event_type = string.upper(ctx.event_type or "COMMAND")
  local event_id = ctx.event_id or ""
  local handler = nil

  if event_type == "COMMAND" then
    local sub = ctx.args.subcommand
    if sub and self._command_handlers[sub] then
      handler = self._command_handlers[sub]
    else
      handler = self._command_handlers["__default__"]
    end
  elseif event_type == "BUTTON" then
    handler = self._button_handlers[event_id]
  elseif event_type == "SELECT" then
    handler = self._select_handlers[event_id]
  elseif event_type == "MODAL" then
    handler = self._modal_handlers[event_id]
  elseif event_type == "MESSAGE" then
    handler = self._message_handlers[1]
  elseif event_type == "TIMER_WAKE" then
    handler = self._timer_wake_handlers[event_id] or self._timer_wake_handlers["on_sleep_complete"]
  elseif event_type == "CALLBACK" then
    handler = self._callback_handlers[event_id]
  end

  if not handler then
    handler = self._default_handler
  end

  if handler then
    handler(ctx)
  end

  return ctx:to_response()
end

function Game:handle_string(event_str)
  local res = self:handle(event_str)
  return json.encode(res)
end

local function dispatch(handler, event)
  local ctx
  if type(event) == "string" then
    local ok, parsed = pcall(json.decode, event)
    if not ok then error("Invalid JSON event: " .. tostring(parsed)) end
    ctx = Context.new(parsed)
  elseif type(event) == "table" then
    if event.to_response then
      ctx = event
    else
      ctx = Context.new(event)
    end
  else
    error("Expected table or string event, got " .. type(event))
  end

  local res = handler(ctx)
  if type(res) == "table" and res.status and res.intents then
    return res
  end
  return ctx:to_response()
end

game_mod.Game = Game
game_mod.dispatch = dispatch

return game_mod

