local FactorOracle = {}

function FactorOracle.create()
  return {
    num_states = 1,
    transitions = {[1] = {}},
    suffix_link = {[1] = 0},
    lrs = {[1] = 0},
    sequence = {}
  }
end

function FactorOracle.add_symbol(oracle, symbol)
  local new_state = oracle.num_states + 1
  oracle.num_states = new_state

  oracle.transitions[new_state] = {}
  oracle.suffix_link[new_state] = 1
  oracle.lrs[new_state] = 0
  oracle.sequence[#oracle.sequence + 1] = symbol

  oracle.transitions[new_state - 1][symbol] = new_state

  local k = oracle.suffix_link[new_state - 1]

  while k > 0 and oracle.transitions[k][symbol] == nil do
    oracle.transitions[k][symbol] = new_state
    k = oracle.suffix_link[k]
  end

  if k == 0 then
    oracle.suffix_link[new_state] = 1
    oracle.lrs[new_state] = 0
  else
    local target = oracle.transitions[k][symbol]
    oracle.suffix_link[new_state] = target
    oracle.lrs[new_state] = math.min(oracle.lrs[k] + 1, oracle.lrs[target] + 1)
  end

  return new_state
end

function FactorOracle.generate(oracle, num_steps, fidelity, constraints)
  constraints = constraints or {}
  local output = {}
  local current = 1
  local max_attempts = num_steps * 4

  for _ = 1, max_attempts do
    if #output >= num_steps then break end

    local trans = oracle.transitions[current]
    local symbols = {}
    for sym, _ in pairs(trans) do
      symbols[#symbols + 1] = sym
    end

    if #symbols == 0 then
      local sl = oracle.suffix_link[current]
      current = (sl > 1) and sl or 1
    else
      local jumped = false

      if math.random() < fidelity and oracle.suffix_link[current] > 1 then
        local st = oracle.suffix_link[current]
        local st_trans = oracle.transitions[st]
        local st_syms = {}
        for sym, _ in pairs(st_trans) do
          st_syms[#st_syms + 1] = sym
        end
        if #st_syms > 0 then
          current = st
          trans = st_trans
          symbols = st_syms
          jumped = true
        end
      end

      local chosen = symbols[math.random(#symbols)]
      current = trans[chosen]

      output[#output + 1] = {
        state = current,
        symbol = chosen,
        jumped = jumped
      }
    end
  end

  return output
end

function FactorOracle.get_suffix_chain(oracle, state)
  local chain = {state}
  local current = state
  while oracle.suffix_link[current] > 1 do
    current = oracle.suffix_link[current]
    chain[#chain + 1] = current
  end
  return chain
end

return FactorOracle
