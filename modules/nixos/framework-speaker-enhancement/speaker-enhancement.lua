local cutils = require ("common-utils")
local graph = Conf.get_section_as_json ("framework-speaker-enhancement.graph"):to_string ()
local graph_param = "audioconvert.filter-graph.0"
local enabled = {}
local route_props = {}

local nodes = ObjectManager {
  Interest {
    type = "node",
    Constraint { "framework.speaker-enhancement", "=", "true", type = "pw" },
  },
}
local devices = ObjectManager {
  Interest { type = "device", Constraint { "device.api", "=", "alsa", type = "pw" } },
}

local function is_speaker (route)
  local info = route.info or {}
  if info["port.type"] then
    return info["port.type"] == "speaker"
  end
  for i = 2, #info, 2 do
    if info[i] == "port.type" then
      return info[i + 1] == "speaker"
    end
  end
  return route.name == "analog-output-speaker" or route.name == "[Out] Speaker"
end

local function active_route (node, device)
  if not device then
    return nil
  end
  local profile_device = tonumber (node.properties["card.profile.device"])
  local routes = {}
  for param in device:iterate_params ("EnumRoute") do
    local route = cutils.parseParam (param, "EnumRoute")
    if route then
      routes[route.index] = route
    end
  end
  for param in device:iterate_params ("Route") do
    local active = cutils.parseParam (param, "Route")
    if active and active.device == profile_device then
      local route = routes[active.index] or active
      if route and route.direction == "Output" then
        return { speaker = is_speaker (route), props = active.props.properties }
      end
    end
  end
  return nil
end

local function float_array (values)
  local array = { "Spa:Float" }
  for _, value in ipairs (values) do
    table.insert (array, value)
  end
  return Pod.Array (array)
end

local function update (node)
  local device_id = tonumber (node.properties["device.id"])
  local device = device_id and devices:lookup {
    Constraint { "bound-id", "=", device_id, type = "gobject" },
  }
  local route = active_route (node, device)
  local use_graph = route ~= nil and route.speaker
  local id = node.id
  if route then
    route_props[id] = route.props
  end
  if use_graph == (enabled[id] or false) then
    return
  end

  node:set_params ("Props", Pod.Object {
    "Spa:Pod:Object:Param:Props", "Props",
    params = Pod.Struct { graph_param, use_graph and graph or Pod.None () },
  })
  local props = route_props[id]
  if props then
    node:set_params ("Props", Pod.Object {
      "Spa:Pod:Object:Param:Props", "Props",
      channelVolumes = float_array (props.channelVolumes),
      softVolumes = float_array (props.softVolumes),
      mute = props.mute,
    })
  end
  enabled[id] = use_graph
end

local function update_all ()
  for node in nodes:iterate () do
    update (node)
  end
end

nodes:connect ("object-added", function (_, node) update (node) end)
nodes:connect ("object-removed", function (_, node)
  enabled[node.id] = nil
  route_props[node.id] = nil
end)
devices:connect ("object-added", function (_, device)
  device:connect ("params-changed", function (_, param)
    if param == "Route" or param == "EnumRoute" then
      update_all ()
    end
  end)
  update_all ()
end)
devices:connect ("object-removed", update_all)
devices:activate ()
nodes:activate ()
