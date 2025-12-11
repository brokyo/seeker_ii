-- forms.lua
--
-- Musical pattern library for Seeker II
-- A collection of motifs and arrangements for users to build from
--------------------------------------------------

local forms = {}

-- Collection of preset motifs
forms.motifs = {
    -- Basic triad (C major)
    triad = {
        name = "Simple Triad",
        description = "Basic C major triad, good for testing harmonization",
        events = {
            {time = 0.0, type = "note_on",  note = 60, velocity = 100},
            {time = 0.2, type = "note_off", note = 60},
            {time = 0.25, type = "note_on", note = 64, velocity = 100},
            {time = 0.45, type = "note_off", note = 64},
            {time = 0.5, type = "note_on",  note = 67, velocity = 100},
            {time = 0.7, type = "note_off", note = 67}
        },
        duration = 1.0
    },

    -- Musical arpeggio progression (Cm7 - Ab - Bb - Eb)
    progression = {
        name = "Minor Progression",
        description = "Flowing minor progression with jazz harmony (Cm7-Ab-Bb-Eb)",
        events = {
            -- Cm7 (C Eb G Bb)
            {time = 0.0,  type = "note_on",  note = 60, velocity = 100},  -- C
            {time = 0.1,  type = "note_off", note = 60},
            {time = 0.125, type = "note_on", note = 63, velocity = 85},   -- Eb
            {time = 0.225, type = "note_off", note = 63},
            {time = 0.25, type = "note_on",  note = 67, velocity = 95},   -- G
            {time = 0.35, type = "note_off", note = 67},
            {time = 0.375, type = "note_on", note = 70, velocity = 90},   -- Bb
            {time = 0.475, type = "note_off", note = 70},
            -- ... rest of progression ...
        },
        duration = 2.0
    }
}

-- Collection of stage arrangements
-- Each arrangement must have exactly 4 stages to match system expectations
forms.arrangements = {
    -- Basic playback
    basic = {
        name = "Basic Playback",
        description = "Simple playback with no transformations",
        stages = {
            {
                id = 1,
                mute = false,
                reset_motif = false,
                loops = 1,
                transforms = {
                    {
                        name = "noop",
                        config = {}
                    }
                }
            },
            {
                id = 2,
                mute = false,
                reset_motif = false,
                loops = 1,
                transforms = {
                    {
                        name = "noop",
                        config = {}
                    }
                }
            },
            {
                id = 3,
                mute = false,
                reset_motif = false,
                loops = 1,
                transforms = {
                    {
                        name = "noop",
                        config = {}
                    }
                }
            },
            {
                id = 4,
                mute = false,
                reset_motif = false,
                loops = 1,
                transforms = {
                    {
                        name = "noop",
                        config = {}
                    }
                }
            }
        }
    },

    -- Octave dance (up then down)
    octaves = {
        name = "Octave Dance",
        description = "Alternates between octave up and down harmonies",
        stages = {
            {
                id = 1,
                mute = false,
                reset_motif = false,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = 12, probability = 1.0 }
                    }
                }
            },
            {
                id = 2,
                mute = false,
                reset_motif = true,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = -12, probability = 1.0 }
                    }
                }
            },
            {
                id = 3,
                mute = false,
                reset_motif = true,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = 12, probability = 1.0 }
                    }
                }
            },
            {
                id = 4,
                mute = false,
                reset_motif = true,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = -12, probability = 1.0 }
                    }
                }
            }
        }
    },

    -- Question and answer (forward then backward)
    call_response = {
        name = "Call and Response",
        description = "Creates a musical dialogue between original and transformed patterns",
        stages = {
            {
                id = 1,
                mute = false,
                reset_motif = false,
                loops = 1,
                transforms = {
                    {
                        name = "noop",
                        config = {}
                    }
                }
            },
            {
                id = 2,
                mute = false,
                reset_motif = true,
                loops = 1,
                transforms = {
                    {
                        name = "reverse",
                        config = {}
                    }
                }
            },
            {
                id = 3,
                mute = false,
                reset_motif = true,
                loops = 1,
                transforms = {
                    {
                        name = "noop",
                        config = {}
                    }
                }
            },
            {
                id = 4,
                mute = false,
                reset_motif = true,
                loops = 1,
                transforms = {
                    {
                        name = "reverse",
                        config = {}
                    }
                }
            }
        }
    },

    -- Building layers of harmony
    layers = {
        name = "Harmonic Layers",
        description = "Gradually builds up harmonic complexity across stages",
        stages = {
            {
                id = 1,
                mute = false,
                reset_motif = false,
                loops = 2,
                transforms = {
                    {
                        name = "noop",
                        config = {}
                    }
                }
            },
            {
                id = 2,
                mute = false,
                reset_motif = true,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = 7, probability = 0.7 }
                    }
                }
            },
            {
                id = 3,
                mute = false,
                reset_motif = true,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = 4, probability = 0.5 }
                    }
                }
            },
            {
                id = 4,
                mute = false,
                reset_motif = true,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = 12, probability = 0.3 }
                    }
                }
            }
        }
    },

    -- Sparse to dense texture
    build = {
        name = "Texture Build",
        description = "Evolves from sparse to dense texture through probability changes",
        stages = {
            {
                id = 1,
                mute = false,
                reset_motif = true,
                loops = 1,
                transforms = {
                    {
                        name = "noop",
                        config = {}
                    }
                }
            },
            {
                id = 2,
                mute = false,
                reset_motif = false,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = 12, probability = 0.3 }
                    }
                }
            },
            {
                id = 3,
                mute = false,
                reset_motif = false,
                loops = 2,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = 7, probability = 0.5 }
                    }
                }
            },
            {
                id = 4,
                mute = false,
                reset_motif = false,
                loops = 3,
                transforms = {
                    {
                        name = "harmonize",
                        config = { interval = 4, probability = 0.7 }
                    }
                }
            }
        }
    }
}

return forms 