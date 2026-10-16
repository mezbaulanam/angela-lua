--
-- angela/canvas.lua — Declarative 2D Canvas scene graph builder for Angela Lua cartridges
--
local canvas = {}

-- ==================== CanvasLayer ====================
local CanvasLayer = {}
CanvasLayer.__index = CanvasLayer

function CanvasLayer.new(layer_id, cache_key)
  local self = setmetatable({}, CanvasLayer)
  self.id = tostring(layer_id or "layer")
  self.cache_key = cache_key
  self.ops = {}
  return self
end

function CanvasLayer:linear_gradient(rect, start_rgb, end_rgb, gamma)
  table.insert(self.ops, {
    type = "linear_gradient",
    rect = rect,
    start_rgb = start_rgb,
    end_rgb = end_rgb,
    gamma = tonumber(gamma) or 1.0,
  })
  return self
end

function CanvasLayer:celestial_body(x, y, radius, glow_radius, color, glow_color)
  table.insert(self.ops, {
    type = "celestial_body",
    x = math.floor(tonumber(x) or 0),
    y = math.floor(tonumber(y) or 0),
    radius = math.floor(tonumber(radius) or 10),
    glow_radius = math.floor(tonumber(glow_radius) or 20),
    color = color,
    glow_color = glow_color,
  })
  return self
end

function CanvasLayer:sine_waves(y_start, y_end, count, color)
  table.insert(self.ops, {
    type = "sine_waves",
    y_start = math.floor(tonumber(y_start) or 0),
    y_end = math.floor(tonumber(y_end) or 0),
    count = math.floor(tonumber(count) or 1),
    color = color,
  })
  return self
end

function CanvasLayer:procedural_palm(x, y_bottom, y_top, seed)
  table.insert(self.ops, {
    type = "procedural_palm",
    x = math.floor(tonumber(x) or 0),
    y_bottom = math.floor(tonumber(y_bottom) or 0),
    y_top = math.floor(tonumber(y_top) or 0),
    seed = math.floor(tonumber(seed) or 0),
  })
  return self
end

function CanvasLayer:vignette(depth, intensity)
  table.insert(self.ops, {
    type = "vignette",
    depth = math.floor(tonumber(depth) or 0),
    intensity = tonumber(intensity) or 1.0,
  })
  return self
end

function CanvasLayer:radial_glow(x, y, radius, color, max_alpha)
  table.insert(self.ops, {
    type = "radial_glow",
    x = math.floor(tonumber(x) or 0),
    y = math.floor(tonumber(y) or 0),
    radius = math.floor(tonumber(radius) or 10),
    color = color,
    max_alpha = math.floor(tonumber(max_alpha) or 255),
  })
  return self
end

function CanvasLayer:sprite(asset_key, x, y, max_w, max_h, anchor, flip_x, rotation)
  local op = {
    type = "sprite",
    asset_key = tostring(asset_key or ""),
    x = math.floor(tonumber(x) or 0),
    y = math.floor(tonumber(y) or 0),
    anchor = anchor or "center",
    flip_x = flip_x == true,
    rotation = math.floor(tonumber(rotation) or 0),
  }
  if max_w then op.max_w = math.floor(tonumber(max_w)) end
  if max_h then op.max_h = math.floor(tonumber(max_h)) end
  table.insert(self.ops, op)
  return self
end

function CanvasLayer:avatar(user_id, x, y, size, circular, border_color, border_width)
  local op = {
    type = "avatar",
    user_id = math.floor(tonumber(user_id) or 0),
    x = math.floor(tonumber(x) or 0),
    y = math.floor(tonumber(y) or 0),
    size = math.floor(tonumber(size) or 80),
    circular = circular ~= false,
    border_width = math.floor(tonumber(border_width) or 0),
  }
  if border_color then op.border_color = border_color end
  table.insert(self.ops, op)
  return self
end

function CanvasLayer:polygon(points, fill, outline)
  local op = {
    type = "polygon",
    points = points or {},
  }
  if fill then op.fill = fill end
  if outline then op.outline = outline end
  table.insert(self.ops, op)
  return self
end

function CanvasLayer:line(points, color, width)
  table.insert(self.ops, {
    type = "line",
    points = points or {},
    color = color,
    width = math.floor(tonumber(width) or 1),
  })
  return self
end

function CanvasLayer:arc(bbox, start_deg, end_deg, color, width)
  table.insert(self.ops, {
    type = "arc",
    bbox = bbox or {},
    start_deg = math.floor(tonumber(start_deg) or 0),
    end_deg = math.floor(tonumber(end_deg) or 360),
    color = color,
    width = math.floor(tonumber(width) or 1),
  })
  return self
end

function CanvasLayer:rounded_rect(rect, radius, fill, outline, width)
  local op = {
    type = "rounded_rect",
    rect = rect or {},
    radius = math.floor(tonumber(radius) or 0),
    width = math.floor(tonumber(width) or 1),
  }
  if fill then op.fill = fill end
  if outline then op.outline = outline end
  table.insert(self.ops, op)
  return self
end

function CanvasLayer:progress_bar(rect, value, max_value, bg_color, fill_color, radius)
  table.insert(self.ops, {
    type = "progress_bar",
    rect = rect or {},
    value = tonumber(value) or 0,
    max_value = tonumber(max_value) or 100,
    bg_color = bg_color,
    fill_color = fill_color,
    radius = math.floor(tonumber(radius) or 0),
  })
  return self
end

function CanvasLayer:text_box(rect, text, font, size, color, max_lines, line_height)
  local op = {
    type = "text_box",
    rect = rect or {},
    text = tostring(text or ""),
    font = font or "regular",
    size = math.floor(tonumber(size) or 13),
    color = color or { 255, 255, 255 },
    max_lines = math.floor(tonumber(max_lines) or 1),
  }
  if line_height then op.line_height = math.floor(tonumber(line_height)) end
  table.insert(self.ops, op)
  return self
end

function CanvasLayer:to_dict()
  local d = {
    id = self.id,
    ops = self.ops,
  }
  if self.cache_key then d.cache_key = self.cache_key end
  return d
end

canvas.CanvasLayer = CanvasLayer

-- ==================== CanvasScene ====================
local CanvasScene = {}
CanvasScene.__index = CanvasScene

function CanvasScene.new(opts)
  local self = setmetatable({}, CanvasScene)
  opts = opts or {}
  self.width = math.min(math.floor(tonumber(opts.width) or 640), 1280)
  self.height = math.min(math.floor(tonumber(opts.height) or 360), 720)
  self.animated = opts.animated == true
  self.frame_duration_ms = math.floor(tonumber(opts.frame_duration_ms) or 80)
  self.filename = tostring(opts.filename or "scene.png")
  self.layers = {}
  return self
end

function CanvasScene:layer(layer_id, cache_key)
  local lyr = CanvasLayer.new(layer_id, cache_key)
  table.insert(self.layers, lyr)
  return lyr
end

function CanvasScene:to_dict()
  local serialized_layers = {}
  for i, lyr in ipairs(self.layers) do
    serialized_layers[i] = lyr:to_dict()
  end
  return {
    width = self.width,
    height = self.height,
    animated = self.animated,
    frame_duration_ms = self.frame_duration_ms,
    filename = self.filename,
    layers = serialized_layers,
  }
end

canvas.CanvasScene = CanvasScene

-- ==================== CanvasContext ====================
local CanvasContext = {}
CanvasContext.__index = CanvasContext

function CanvasContext.new()
  return setmetatable({}, CanvasContext)
end

function CanvasContext:create(opts)
  if type(opts) == "number" then
    -- positional: create(width, height, animated, frame_duration_ms, filename)
    local width = opts
    -- we can handle varargs if called as method with multiple params
    return function(height, animated, frame_duration_ms, filename)
      return CanvasScene.new({
        width = width,
        height = height,
        animated = animated,
        frame_duration_ms = frame_duration_ms,
        filename = filename,
      })
    end
  end
  return CanvasScene.new(opts)
end

canvas.CanvasContext = CanvasContext

return canvas

