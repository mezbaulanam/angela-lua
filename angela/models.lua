--
-- angela/models.lua — Data models and UI component builders for Angela Lua cartridges
--
local models = {}

-- ==================== User ====================
local User = {}
User.__index = User

function User.new(data)
  data = data or {}
  local self = setmetatable({}, User)
  self.id = math.floor(tonumber(data.id) or 0)
  self.name = tostring(data.name or "")
  self.avatar_url = tostring(data.avatar_url or "")
  return self
end

models.User = User

-- ==================== Args ====================
local Args = {}
Args.__index = Args

function Args.new(data)
  data = data or {}
  local self = setmetatable({}, Args)
  self.subcommand = data.subcommand
  self.raw_args = data.raw_args
  self.target_user_id = data.target_user_id and math.floor(tonumber(data.target_user_id)) or nil
  self.modal_inputs = data.modal_inputs or {}
  self.select_values = data.select_values or {}
  self.message_content = data.message_content
  self.callback_data = data.callback_data or {}
  return self
end

models.Args = Args

-- ==================== Session ====================
local Session = {}
Session.__index = Session

function Session.new(data)
  data = data or {}
  local self = setmetatable({}, Session)
  self.session_id = tostring(data.session_id or "")
  self.round = math.floor(tonumber(data.round) or 1)
  self.status = tostring(data.status or "ACTIVE")
  self.participants = {}
  if data.participants then
    for i, p in ipairs(data.participants) do
      self.participants[i] = math.floor(tonumber(p) or 0)
    end
  end
  self.state = {}
  if data.state and type(data.state) == "table" then
    for k, v in pairs(data.state) do
      self.state[k] = v
    end
  end
  return self
end

models.Session = Session

-- ==================== Button ====================
local Button = {}
Button.__index = Button

function Button.new(opts)
  local self = setmetatable({}, Button)
  if type(opts) == "string" then
    self.custom_id = opts
    self.label = ""
    self.style = "primary"
  else
    opts = opts or {}
    self.custom_id = tostring(opts.custom_id or opts[1] or "")
    self.label = tostring(opts.label or "")
    self.style = string.lower(tostring(opts.style or "primary"))
    self.emoji = opts.emoji
    self.disabled = opts.disabled == true
    self.url = opts.url
  end
  return self
end

function Button:to_dict()
  local d = {
    type = 2,
    custom_id = self.custom_id,
    label = self.label,
    style = self.style,
    disabled = self.disabled or false,
  }
  if self.emoji then d.emoji = self.emoji end
  if self.url then d.url = self.url end
  return d
end

models.Button = Button

-- ==================== SelectOption ====================
local SelectOption = {}
SelectOption.__index = SelectOption

function SelectOption.new(opts)
  local self = setmetatable({}, SelectOption)
  opts = opts or {}
  self.label = tostring(opts.label or opts[1] or "")
  self.value = tostring(opts.value or opts[2] or self.label)
  self.description = opts.description
  self.emoji = opts.emoji
  self.default = opts.default == true
  return self
end

function SelectOption:to_dict()
  local d = {
    label = self.label,
    value = self.value,
    default = self.default or false,
  }
  if self.description then d.description = self.description end
  if self.emoji then d.emoji = self.emoji end
  return d
end

models.SelectOption = SelectOption

-- ==================== Select ====================
local Select = {}
Select.__index = Select

function Select.new(opts)
  local self = setmetatable({}, Select)
  opts = opts or {}
  self.custom_id = tostring(opts.custom_id or opts[1] or "")
  self.placeholder = opts.placeholder
  self.min_values = math.floor(tonumber(opts.min_values) or 1)
  self.max_values = math.floor(tonumber(opts.max_values) or 1)
  self.disabled = opts.disabled == true
  self.options = {}
  if opts.options then
    for i, opt in ipairs(opts.options) do
      if opt.to_dict then
        self.options[i] = opt
      else
        self.options[i] = SelectOption.new(opt)
      end
    end
  end
  return self
end

function Select:to_dict()
  local serialized = {}
  for i, opt in ipairs(self.options) do
    serialized[i] = opt:to_dict()
  end
  local d = {
    type = 3,
    custom_id = self.custom_id,
    options = serialized,
    min_values = self.min_values,
    max_values = self.max_values,
    disabled = self.disabled or false,
  }
  if self.placeholder then d.placeholder = self.placeholder end
  return d
end

models.Select = Select

-- ==================== TextInput ====================
local TextInput = {}
TextInput.__index = TextInput

function TextInput.new(opts)
  local self = setmetatable({}, TextInput)
  opts = opts or {}
  self.custom_id = tostring(opts.custom_id or opts[1] or "")
  self.label = tostring(opts.label or opts[2] or "")
  self.placeholder = opts.placeholder
  self.default = opts.default or opts.value
  self.min_length = opts.min_length and math.floor(tonumber(opts.min_length)) or nil
  self.max_length = opts.max_length and math.floor(tonumber(opts.max_length)) or nil
  self.required = opts.required ~= false
  self.style = tostring(opts.style or "short")
  return self
end

function TextInput:to_dict()
  local d = {
    type = 4,
    custom_id = self.custom_id,
    label = self.label,
    required = self.required,
    style = self.style,
  }
  if self.placeholder then d.placeholder = self.placeholder end
  if self.default then d.value = self.default end
  if self.min_length then d.min_length = self.min_length end
  if self.max_length then d.max_length = self.max_length end
  return d
end

models.TextInput = TextInput

-- ==================== TextDisplay ====================
local TextDisplay = {}
TextDisplay.__index = TextDisplay

function TextDisplay.new(content)
  local self = setmetatable({}, TextDisplay)
  self.content = tostring(content or "")
  return self
end

function TextDisplay:to_dict()
  return { type = 10, content = self.content }
end

models.TextDisplay = TextDisplay

-- ==================== Thumbnail ====================
local Thumbnail = {}
Thumbnail.__index = Thumbnail

function Thumbnail.new(url)
  local self = setmetatable({}, Thumbnail)
  self.url = tostring(url or "")
  return self
end

function Thumbnail:to_dict()
  return { type = 11, url = self.url }
end

models.Thumbnail = Thumbnail

-- ==================== MediaGallery ====================
local MediaGallery = {}
MediaGallery.__index = MediaGallery

function MediaGallery.new(items)
  local self = setmetatable({}, MediaGallery)
  if type(items) == "string" then
    self.items = { items }
  elseif type(items) == "table" then
    self.items = items
  else
    self.items = {}
  end
  return self
end

function MediaGallery:to_dict()
  local list = {}
  for i, url in ipairs(self.items) do
    list[i] = { url = tostring(url) }
  end
  return { type = 12, items = list }
end

models.MediaGallery = MediaGallery

-- ==================== Separator ====================
local Separator = {}
Separator.__index = Separator

function Separator.new(opts)
  local self = setmetatable({}, Separator)
  opts = opts or {}
  self.divider = opts.divider ~= false
  self.spacing = math.floor(tonumber(opts.spacing) or 1)
  return self
end

function Separator:to_dict()
  return { type = 14, divider = self.divider, spacing = self.spacing }
end

models.Separator = Separator

-- ==================== ActionRow ====================
local ActionRow = {}
ActionRow.__index = ActionRow

function ActionRow.new(components)
  local self = setmetatable({}, ActionRow)
  self.components = components or {}
  return self
end

function ActionRow:to_dict()
  local list = {}
  for i, c in ipairs(self.components) do
    if c.to_dict then
      list[i] = c:to_dict()
    else
      list[i] = c
    end
  end
  return { type = 1, components = list }
end

models.ActionRow = ActionRow

-- ==================== Section ====================
local Section = {}
Section.__index = Section

function Section.new(opts)
  local self = setmetatable({}, Section)
  opts = opts or {}
  self.text_displays = opts.text_displays or {}
  self.accessory = opts.accessory
  return self
end

function Section:to_dict()
  local texts = {}
  for i, t in ipairs(self.text_displays) do
    if type(t) == "string" then
      texts[i] = { type = 10, content = t }
    elseif t.to_dict then
      texts[i] = t:to_dict()
    else
      texts[i] = t
    end
  end
  local d = { type = 9, components = texts }
  if self.accessory then
    if self.accessory.to_dict then
      d.accessory = self.accessory:to_dict()
    else
      d.accessory = self.accessory
    end
  end
  return d
end

models.Section = Section

-- ==================== Container ====================
local Container = {}
Container.__index = Container

function Container.new(opts)
  local self = setmetatable({}, Container)
  opts = opts or {}
  self.accent_color = opts.accent_color
  self.components = opts.components or {}
  return self
end

function Container:add(component)
  table.insert(self.components, component)
  return self
end

local function parse_color(color)
  if type(color) == "string" and color:sub(1, 1) == "#" then
    return tonumber(color:sub(2), 16)
  end
  return tonumber(color)
end

function Container:to_dict()
  local list = {}
  for i, c in ipairs(self.components) do
    if c.to_dict then
      list[i] = c:to_dict()
    else
      list[i] = c
    end
  end
  local d = { type = 17, components = list }
  if self.accent_color then
    d.accent_color = parse_color(self.accent_color)
  end
  return d
end

models.Container = Container

-- ==================== Embed ====================
local Embed = {}
Embed.__index = Embed

function Embed.new(opts)
  local self = setmetatable({}, Embed)
  opts = opts or {}
  self.title = opts.title
  self.description = opts.description
  self.color = opts.color
  self.fields = opts.fields or {}
  self.footer = opts.footer
  self.thumbnail = opts.thumbnail
  self.image = opts.image
  return self
end

function Embed:add_field(name, value, inline)
  table.insert(self.fields, {
    name = tostring(name or ""),
    value = tostring(value or ""),
    inline = inline == true,
  })
  return self
end

function Embed:to_dict()
  local d = {}
  if self.title then d.title = tostring(self.title) end
  if self.description then d.description = tostring(self.description) end
  if self.color then d.color = parse_color(self.color) end
  if #self.fields > 0 then d.fields = self.fields end
  if self.footer then d.footer = self.footer end
  if self.thumbnail then d.thumbnail = { url = tostring(self.thumbnail) } end
  if self.image then d.image = { url = tostring(self.image) } end
  return d
end

models.Embed = Embed

return models

