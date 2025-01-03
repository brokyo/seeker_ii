-- Default parameters for all channels

local default_channel_params = {
    -- MAJOR CONFIG: Voice
    -- voice_player = {},                -- Options: Available N.B Player
    
    -- MAJOR CONFIG: Duration
    duration_mode = "Fixed",           -- Options: "Fixed", "Pattern", "Aleatoric"
    duration_base = 9,                -- Index into note_lengths (9 = "1" beat)
    duration_variance = 0,            -- Percentage of variance (0-100)
    duration_variance_style = "Random", -- Options: "Random", "Locked Random", "Drift", "Breathe"
    duration_min = 5,                 -- Index into note_lengths (5 = "1/4" beat)
    duration_max = 13,                -- Index into note_lengths (13 = "2" beats)
    duration_pattern = {1},           -- Pattern of duration multipliers
    duration_pattern_length = 1,      -- Length of duration pattern
    duration_locked_length = 16,      -- Length of locked random sequence
    
    -- MAJOR CONFIG: Rhythm
    clock_source = 1,                   -- Internal clock source
    clock_mod = 7,                      -- Clock division (1/4 note by default)
    clock_pulse_behavior = 1,           -- Pulse behavior (1=pulse, 2=strum, 3=burst)
    clock_pulse_length = 50,           -- Percentage (0 to 99)
    
    -- -- Burst Configuration
    -- burst_count = 3,                                -- Integer (2 to 12)
    -- burst_trigger_interval = 1,                     -- Integer (1/32 to 4 bars)
    -- burst_randomization_amount = 0,                 -- Percentage (0 to 10)
    -- burst_rhythm = "Even",                          -- Options: "Even", "Dotted", "Triplet", "Swing"
    
    -- -- Strum Configuration
    -- strum_duration = 1,                             -- Integer (1 to 4; represents 1/32 to *4)
    -- strum_pulse_count = 3,                           -- Integer (2 to 12)
    -- strum_clustering_percent = 33,                   -- Percentage (0 to 100)
    -- strum_clustering_variation = 0,                 -- Percentage (0 to 100)
    -- strum_rhythm = "Even",                           -- Options: "Even", "Dotted", "Triplet", "Swing"
    
    -- -- MAJOR CONFIG: Tones
    -- arpeggiator_type = "Chord",                      -- Options: "Chord", "Cluster"
    -- arpeggiator_root_note = 60,                       -- MIDI Value (0 to 127)
    -- arpeggiator_style = "Up",                         -- Options: "Up", "Down", "Ping Pong", "Random", "Looping Random"
    -- arpeggiator_step = 1,                             -- Integer (-5 to 5)
    -- looping_random_length = 8,                        -- Integer (0 to 16)
    
    -- -- Chord Configuration (Applicable if arpeggiator_type == "Chord")
    -- chord_root = "C",                                 -- Root note (as string, e.g., "C", "C#", ...)
    -- chord_root_octave = 4,                            -- Integer (1 to 7)
    -- chord_root_inversion = 0,                         -- Integer (0 to 3)
    -- note_count = 3,                                   -- Integer (1 to 12)
    
    -- -- Cluster Configuration (Applicable if arpeggiator_type == "Cluster")
    -- cluster_root = "C",                               -- Root note (as string)
    -- cluster_root_octave = 4,                          -- Integer (1 to 7)
    -- cluster_interval_length = 0,                      -- Integer (0 to 16)
    
    -- -- MAJOR CONFIG: Expression
    -- velocity_type = "Alternate",                      -- Options: "Alternate", "Ramp Up", "Ramp Down", "Sine", "Flat"
    -- max_velocity = 115,                               -- MIDI Value (0 to 127)
    -- min_velocity = 90,                                -- MIDI Value (0 to 127)
    -- humanize = false,                                 -- Boolean (true or false)
    
    -- -- Expression > Duration Config
    -- duration_type = "Pulse Length",                   -- Options: "Pulse Length", "Aleatoric"
    
    -- -- Aleatoric Configuration (Applicable if duration_type == "Aleatoric")
    -- aleatoric_chance_1_8 = 0,                         -- Integer (0 to 10)
    -- aleatoric_chance_1_4 = 0,                         -- Integer (0 to 10)
    -- aleatoric_chance_1_2 = 10,                         -- Integer (0 to 10)
    -- aleatoric_chance_1 = 10,                           -- Integer (0 to 10)
    -- aleatoric_chance_2 = 10,                           -- Integer (0 to 10)
    -- aleatoric_chance_4 = 0,                           -- Integer (0 to 10)
    -- aleatoric_chance_8 = 0,                           -- Integer (0 to 10)
    -- aleatoric_chance_12 = 0,                           -- Integer (0 to 10)
    -- aleatoric_chance_16 = 0,                           -- Integer (0 to 10)
    
    -- -- MAJOR CONFIG: Paramquencer
    -- paramquencer_active = false,                      -- Boolean (true or false)
    -- paramquencer_lane = 1,                            -- Integer (1 to 4)
    -- pulses_per_step = 1,                              -- Integer (1 to 64)
    
    -- -- Additional Params (R>B: Burst Params, R>S: Strum Params, T>A: Arp Params, etc.)
    -- -- Define any additional parameters required for specific configurations here
}

return default_channel_params