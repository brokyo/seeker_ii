-- Seeker
-- 
-- Textural generation channels
-- awakening.systems

------------------------
-- External Libraries --
------------------------
-- local nb = require("circuits/lib/nb/lib/nb")
-- local nb_voices = {}

------------------------
-- Internal Libraries --
------------------------
-- local clock_utils = require('lib/clock_utils')
-- local paramquencer = require('lib/paramquenver')
local Channel = include('lib/channel')

-----------------
-- Core Config --
-----------------
SEEKER_DEBUG = true -- N.B: This is global and should be turned off when not developing 
local NUM_CHANNELS = 4

local channels = {}
local selected_channel = 1

function init()
    init_header()
    init_channels(NUM_CHANNELS)
    redraw()
end

function init_header()
    params:add_separator("seeker_app_header", "Seeker")
end

function init_channels(channel_count)
    for i = 1, channel_count do
        channels[i] = Channel.new(i)
        channels[i]:add_params(i)
    end
end

function enc(n, d)
    if n == 1 then
        -- Change selected channel
        selected_channel = util.clamp(selected_channel + d, 1, NUM_CHANNELS)
        redraw()
    end
end

function key(n, z)
    if n == 2 and z == 1 then
        -- Toggle channel state
        if channels[selected_channel].running then
            channels[selected_channel]:stop_channel(selected_channel)
        else
            channels[selected_channel]:start(selected_channel)
        end
        redraw()
    end
end

function redraw()
    screen.clear()
    
    -- Draw channel info
    screen.move(64, 32)
    screen.level(15)
    screen.text_center("Channel " .. selected_channel)
    
    -- Draw status
    screen.move(64, 42)
    screen.level(channels[selected_channel].running and 15 or 3)
    screen.text_center(channels[selected_channel].running and "Running" or "Stopped")
    
    screen.update()
end

-- Create Config Params & Load Into Norns UI

-- MAJOR CONFIG: Global Settings
-- Global: Scale
-- Global: Key

-- MAJOR CONFIG: Voice
-- Voice: N.B Player

-- MAJOR CONFIG: Rhythm
-- Clock Source: Internal, Crow Port 1, Crow Port 2
-- Clock Mod; /16 > *16
-- Clock Pulse Behavior: Pulse, Burst, Strum
-- Clock Pulse Length: 0% > 95%
-- Rhythm > Bust Config Section [Only If Burst Selected]
-- Burst Count: 0 > 12
-- Burst Trigger Interval: 1/32 > *4
-- Burst Randomization Amount: 0% > 10%
-- Burst Rhythm: Even, Dotted, Triplet, Swing
-- Rhythm > Strum Config Section [Only if Config Selected]
-- Strum Duration: 1/32 > *4
-- Strum Pulse Count: 0 > 12
-- Strum Clustering Percent: 0% > 100%
-- Strum Clustering Variation: 0% > 100%
-- Burst Rhythm: Even, Dotted, Triplet, Swing 

-- MAJOR CONFIG: Tones
-- Arpeggiator Type: Chord, Cluster
-- Arpeggiator Root Note: MIDI Value 0 > 127 [Show as (Note)(Octave)] 
-- Arpeggiator Style: Up, Down, Ping Pong, Random, Looping Random
-- Arpeggiator Step: - 5 > 5
-- Looping Random Length: 0 > 16 [Only If Selected]
-- Tones > Chord Config [Only If Selected]
-- Chord Root: [In Scale Notes]
-- Chord Root Octave: [1 > 7]
-- Chord Root Inversion: 0 > 3
-- Note Count: 1 > 12
-- Tones > Cluster Config
-- Cluster Root: [In Scale Notes]
-- Cluster Root Octave: 1 > 7
-- Cluster Interval Length: 0 > 16

-- MAJOR CONFIG: Expression
-- Expression > Velocity Config
-- Velocity Type: Alternate, Ramp Up, Ramp Down, Sine, Flat
-- Max Velocity: 0 > 127
-- Min Velocity: 0 > 127
-- Humanize: true > false
-- Expression > Duration Config
-- Duration Type: Pulse Length, Aleatoric
-- Aleatoric Config: Chance
-- Aleatoric 1/8 Chance: 0 > 10
-- Aleatoric 1/4 Chance: 0 > 10
-- Aleatoric 1/2 Chance: 0 > 10
-- Aleatoric 1 Chance: 0 > 10
-- Aleatoric 2 Chance: 0 > 10
-- Aleatoric 4 Chance: 0 > 10

-- MAJOR CONFIG: Paramquencer
-- Paramquencer Active: True > False
-- Paramquencer Lane: 1 > 4
-- Pulses Per Step: 1 > 64
-- Param: [R>B: Burst Count, R>B: Trigger Interval, R>B: Rhythm, R>S: Pulse Count, R>S: Clustering Percentage, R>S: Clustering Variation, R>S: Rhythm, T>A: Arp Style, T>A: Arp Step, T>A: T>Ch: Root Note, T>Ch: Root Octave, T>Ch: Chord Inversion, T>Ch: Note Count. T>Cl: Root Note, T>Cl: Root Octave, T>Cl: Interval Length]

