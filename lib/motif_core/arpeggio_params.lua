-- arpeggio_params.lua
-- Consolidated parameter creation for arpeggio sequencer system
-- Includes both lane-level (genesis) and stage-level (regeneration) parameters

local arpeggio_params = {}

-- Create all arpeggio-related parameters for a single lane
local function create_arpeggio_params(lane_id)
    -- All arpeggio params in one group (lane-level genesis + stage-level regeneration)
    params:add_group("lane_" .. lane_id .. "_arpeggio", "ARPEGGIO", 58)

    -- Lane-level params (sequence structure)
    params:add_number("lane_" .. lane_id .. "_arpeggio_num_steps", "Number of Steps", 4, 24, 4)
    params:add_option("lane_" .. lane_id .. "_arpeggio_step_length", "Step Length",
        {"1/32", "1/24", "1/16", "1/12", "1/11", "1/10", "1/9", "1/8", "1/7", "1/6", "1/5", "1/4", "1/3", "1/2", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "16", "24", "32"}, 14)

    -- Stage-level params (musical parameters per stage)

    for stage_idx = 1, 4 do
        -- Chord Definition
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_chord_root", "Chord Root", {"I", "ii", "iii", "IV", "V", "vi", "vii°"}, 1)
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_chord_type", "Chord Type", {"Diatonic", "Major", "Minor", "Sus2", "Sus4", "Maj7", "Min7", "Dom7", "Dim", "Aug"}, 1)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_chord_length", "Chord Length", 1, 12, 3)
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_chord_inversion", "Chord Inversion", {"Root", "1st", "2nd"}, 1)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_octave", "Octave", 1, 7, 3)
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_chord_phasing", "Chord Phasing", {"Off", "On"}, 1)

        -- Pattern
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_pattern", "Pattern", {"All", "Odds", "Evens", "Downbeats", "Upbeats", "Sparse"}, 1)

        -- Performance Parameters
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_note_duration", "Note Duration", 1, 250, 50, function(param) return param.value .. "%" end)

        -- Velocity Curve
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_velocity_curve", "Velocity Curve",
            {"Flat", "Crescendo", "Decrescendo", "Wave", "Alternating", "Accent First", "Accent Last", "Random"}, 1)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_velocity_min", "Velocity Min", 1, 127, 60)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_velocity_max", "Velocity Max", 1, 127, 100)

        -- Strum Parameters
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_strum_curve", "Strum Curve",
            {"None", "Linear", "Accelerating", "Decelerating", "Sweep"}, 1)
        params:add_number("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_strum_amount", "Strum Amount", 0, 100, 0, function(param) return param.value .. "%" end)
        params:add_option("lane_" .. lane_id .. "_stage_" .. stage_idx .. "_arpeggio_strum_shape", "Strum Shape",
            {"Forward", "Reverse", "Center Out", "Edges In", "Alternating", "Random"}, 1)
    end
end

-- Initialize arpeggio params for all lanes
function arpeggio_params.init()
    for i = 1, 8 do
        create_arpeggio_params(i)
    end
end

return arpeggio_params
