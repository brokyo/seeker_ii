-- disting_nt/chains.lua
-- Chain presets: single algorithms and multi-algorithm combinations
--
-- All options in one selector - single algorithms and chains alike.
-- Future: Activating a chain could trigger algorithm creation on NT via i2c.

local chains = {}

------------------------------------------------------------
-- Chain Definitions
------------------------------------------------------------

-- Each chain has:
--   id: internal key
--   name: display name
--   algorithms: ordered list of algorithm ids (signal flow order)
--   slots: number of NT slots this chain occupies
--   is_single: true if this is a single-algorithm preset
--   default_routing: optional routing defaults for multi-algo chains
--                    { algo_index, param_id, default_value }
--                    Uses OUTPUT_OPTIONS indices: 22-29 = Aux 1-8 (internal buses)

chains.DEFINITIONS = {
  ------------------------------------------------------------
  -- Single Algorithm Presets (one algorithm each)
  ------------------------------------------------------------
  {
    id = "poly_fm",
    name = "Poly FM",
    algorithms = {"poly_fm"},
    slots = 1,
    is_single = true,
  },
  {
    id = "plaits",
    name = "Poly Plaits",
    algorithms = {"plaits"},
    slots = 1,
    is_single = true,
  },
  {
    id = "poly_multisample",
    name = "Poly Multisample",
    algorithms = {"poly_multisample"},
    slots = 1,
    is_single = true,
  },
  {
    id = "poly_resonator",
    name = "Poly Resonator",
    algorithms = {"poly_resonator"},
    slots = 1,
    is_single = true,
  },
  {
    id = "poly_wavetable",
    name = "Poly Wavetable",
    algorithms = {"poly_wavetable"},
    slots = 1,
    is_single = true,
  },
  {
    id = "seaside_jawari",
    name = "Seaside Jawari",
    algorithms = {"seaside_jawari"},
    slots = 1,
    is_single = true,
  },
  {
    id = "vco_pulsar",
    name = "VCO Pulsar",
    algorithms = {"vco_pulsar"},
    slots = 1,
    is_single = true,
  },
  {
    id = "vco_waveshaping",
    name = "VCO Waveshaping",
    algorithms = {"vco_waveshaping"},
    slots = 1,
    is_single = true,
  },
  {
    id = "vco_wavetable",
    name = "VCO Wavetable",
    algorithms = {"vco_wavetable"},
    slots = 1,
    is_single = true,
  },

  ------------------------------------------------------------
  -- Multi-Algorithm Chains
  ------------------------------------------------------------
  {
    id = "vco_filter",
    name = "Chain: VCO + Filter",
    algorithms = {"vco_wavetable", "vcf_svf"},
    slots = 2,
    is_single = false,
    -- Default routing: VCO → Aux 1 → VCF → Output 3
    default_routing = {
      { algo_index = 1, param_id = "output", value = 22 },         -- VCO output to Aux 1
      { algo_index = 2, param_id = "input", value = 22 },          -- VCF input from Aux 1
      { algo_index = 2, param_id = "blended_output", value = 16 }, -- VCF output to Output 3
    },
  },

  -- Future chain presets
  -- {
  --   id = "warm_pad",
  --   name = "Chain: Warm Pad",
  --   algorithms = {"poly_wavetable", "vcf_svf"},
  --   slots = 2,
  --   is_single = false,
  -- },
}

------------------------------------------------------------
-- Chain Names (for UI dropdown)
------------------------------------------------------------

chains.CHAIN_NAMES = {}
for _, chain in ipairs(chains.DEFINITIONS) do
  table.insert(chains.CHAIN_NAMES, chain.name)
end

------------------------------------------------------------
-- Lookup Helpers
------------------------------------------------------------

-- Get chain by index (1-based)
function chains.get_by_index(index)
  return chains.DEFINITIONS[index]
end

-- Get chain by id
function chains.get_by_id(id)
  for _, chain in ipairs(chains.DEFINITIONS) do
    if chain.id == id then
      return chain
    end
  end
  return nil
end

-- Get number of algorithms in a chain
function chains.get_algorithm_count(chain_index)
  local chain = chains.get_by_index(chain_index)
  if not chain or not chain.algorithms then
    return 1
  end
  return #chain.algorithms
end

-- Check if chain is single-algorithm mode
function chains.is_single_mode(chain_index)
  local chain = chains.get_by_index(chain_index)
  return chain and chain.is_single == true
end

return chains
