# Section Testing Checklist

## Config
- [x] CONFIG

## Motif Mode
- [x] MOTIF_CONFIG
- [x] LANE_CONFIG

## Tape Type
- [x] TAPE_CREATE
- [x] TAPE_PLAYBACK
- [x] TAPE_STAGE_CONFIG
- [x] TAPE_CLEAR
- [x] TAPE_PERFORM
- [x] TAPE_VELOCITY
- [x] DUAL_TAPE_KEYBOARD
- [x] TAPE_STAGE_NAV (dispatcher)
- [x] TAPE_KEYBOARD (dispatcher)

## Sampler Type
- [x] SAMPLER_CREATE
- [ ] SAMPLER_CHOP_CONFIG
- [x] SAMPLER_PLAYBACK
- [ ] SAMPLER_STAGE_CONFIG
- [x] SAMPLER_CLEAR
- [x] SAMPLER_PERFORM
- [x] SAMPLER_VELOCITY
- [x] SAMPLER_KEYBOARD
- [x] SAMPLER_STAGE_NAV (dispatcher)

## Composer Type
- [ ] COMPOSER_CREATE
- [x] COMPOSER_PLAYBACK
- [x] COMPOSER_CLEAR
- [x] COMPOSER_PERFORM
- [ ] COMPOSER_HARMONIC_STAGES
- [ ] COMPOSER_EXPRESSION_STAGES
- [ ] COMPOSER_KEYBOARD

## Eurorack Mode
- [ ] EURORACK_CONFIG
- [ ] CROW_OUTPUT
- [ ] TXO_TR_OUTPUT
- [ ] TXO_CV_OUTPUT

## OSC Mode
- [ ] OSC_CONFIG
- [ ] OSC_FLOAT
- [ ] OSC_LFO
- [ ] OSC_TRIGGER

## W/Tape Mode
- [ ] WTAPE
- [ ] WTAPE_PLAYBACK
- [ ] WTAPE_RECORD
- [ ] WTAPE_FF
- [ ] WTAPE_REWIND
- [ ] WTAPE_LOOP_START
- [ ] WTAPE_LOOP_END
- [ ] WTAPE_LOOP_ACTIVE
- [ ] WTAPE_REVERSE

## Voices (LANE_CONFIG)
- [x] MX Samples
- [x] Eurorack
- [x] Just Friends
- [x] W/
- [x] Disting
- [ ] OSC (with TouchDesigner)

## Deferred Tasks
- [ ] W/Syn Voice: Set attenuators
- [ ] W/Syn Voice: Default to init config from params
