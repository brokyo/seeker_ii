local GridConstants = include('lib/grid_constants')

local GridLayers = {
  -- Import constants
  GRID_WIDTH = GridConstants.GRID_WIDTH,
  GRID_HEIGHT = GridConstants.GRID_HEIGHT,
  PRIORITY = GridConstants.LAYER_PRIORITY
}

-- Create a new empty matrix
local function create_matrix()
  local matrix = {}
  for x = 1, GridLayers.GRID_WIDTH do
    matrix[x] = {}
    for y = 1, GridLayers.GRID_HEIGHT do
      matrix[x][y] = 0
    end
  end
  return matrix
end

-- Initialize layers
function GridLayers.init()
  return {
    background = create_matrix(),
    ui = create_matrix(),
    response = create_matrix(),
    composite = create_matrix()
  }
end

-- Set a value in a layer
function GridLayers.set(matrix, x, y, value)
  if x >= 1 and x <= GridLayers.GRID_WIDTH and
     y >= 1 and y <= GridLayers.GRID_HEIGHT then
    matrix[x][y] = value
  end
end

-- Get a value from a layer
function GridLayers.get(matrix, x, y)
  if x >= 1 and x <= GridLayers.GRID_WIDTH and
     y >= 1 and y <= GridLayers.GRID_HEIGHT then
    return matrix[x][y]
  end
  return 0
end

-- Composite all layers into final output
function GridLayers.composite(layers)  
  if not layers.background or not layers.ui or not layers.response or not layers.composite then
    return create_matrix()
  end
  
  for x = 1, GridLayers.GRID_WIDTH do
    for y = 1, GridLayers.GRID_HEIGHT do
      -- Start with background (lowest priority)
      if layers.ui[x][y] == nil then
        print(string.format("Found nil at ui[%d,%d]", x, y))
        -- Also check the table itself
        if layers.ui[x] == nil then
          print(string.format("  ui[%d] table is nil", x))
        end
      end
      
      local final = layers.background[x][y] or 0
      
      -- UI layer takes precedence if it has any value
      if layers.ui[x][y] and layers.ui[x][y] > 0 then
        final = layers.ui[x][y]
      end
      
      -- Response layer has highest priority if it has any value
      if layers.response[x][y] and layers.response[x][y] > 0 then
        final = layers.response[x][y]
      end
      
      layers.composite[x][y] = final
    end
  end
  return layers.composite
end

-- Clear a specific layer
function GridLayers.clear_layer(matrix)
  if not matrix then
    print("⚠ Attempted to clear nil matrix")
    return
  end
  
  for x = 1, GridLayers.GRID_WIDTH do
    if not matrix[x] then
      print(string.format("⚠ Row %d is nil during clear", x))
      matrix[x] = {}
    end
    for y = 1, GridLayers.GRID_HEIGHT do
      matrix[x][y] = 0
    end
  end
end

-- Apply the composite to the grid
function GridLayers.apply_to_grid(grid_device, layers)
  local composite = GridLayers.composite(layers)
  for x = 1, GridLayers.GRID_WIDTH do
    for y = 1, GridLayers.GRID_HEIGHT do
      grid_device:led(x, y, composite[x][y])
    end
  end
  grid_device:refresh()
end

return GridLayers 