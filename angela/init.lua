--
-- angela/init.lua — Main module export for the Angela Lua SDK
--
local models = require("angela.models")
local canvas = require("angela.canvas")
local context = require("angela.context")
local game = require("angela.game")
local json = require("angela.json")

local angela = {
  _VERSION = "0.2.0",

  -- Core Application & Routing
  Game = game.Game,
  dispatch = game.dispatch,

  -- Context
  Context = context.Context,
  GameContext = context.Context,

  -- UI Components
  Button = models.Button,
  Select = models.Select,
  SelectOption = models.SelectOption,
  TextInput = models.TextInput,
  TextDisplay = models.TextDisplay,
  Thumbnail = models.Thumbnail,
  MediaGallery = models.MediaGallery,
  Separator = models.Separator,
  ActionRow = models.ActionRow,
  Section = models.Section,
  Container = models.Container,
  Embed = models.Embed,

  -- 2D Canvas
  CanvasScene = canvas.CanvasScene,
  CanvasLayer = canvas.CanvasLayer,
  CanvasContext = canvas.CanvasContext,

  -- Models
  User = models.User,
  Args = models.Args,
  Session = models.Session,

  -- JSON Helper
  json = json,
}

return angela

