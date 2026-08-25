// lpc-source.mjs — Shared LPC constants from upstream sources/state/constants.ts
// These are the canonical values extracted from the Universal LPC Spritesheet
// Character Generator repository (commit 538641d9e).

export const FRAME_SIZE = 64;

export const DIRECTIONS = ["up", "left", "down", "right"];

export const BODY_TYPES = ["male", "female", "teen", "child", "muscular", "pregnant"];

// Row offset (Y position) for each animation within a full sprite sheet.
// Each row = one animation, each row has FRAMES_PER_ROW columns.
export const ANIMATION_OFFSETS = {
  spellcast: 0,
  thrust: 4,
  walk: 8,
  slash: 12,
  shoot: 16,
  hurt: 20,
  climb: 21,
  idle: 22,
  jump: 26,
  sit: 30,
  emote: 34,
  run: 38,
  combat_idle: 42,
  backslash: 46,
  halfslash: 50,
};

export const FRAMES_PER_ROW = 13;

// Custom (oversize) animations — frames larger than 64x64
export const CUSTOM_ANIMATIONS = {
  slash_oversize:       { frameSize: 192, frames: 6, directions: 4 },
  slash_reverse_oversize: { frameSize: 192, frames: 6, directions: 4 },
  thrust_oversize:      { frameSize: 192, frames: 8, directions: 4 },
  walk_128:             { frameSize: 128, frames: 13, directions: 4 },
  slash_128:            { frameSize: 128, frames: 6, directions: 4 },
  backslash_128:        { frameSize: 128, frames: 6, directions: 4 },
  halfslash_128:        { frameSize: 128, frames: 6, directions: 4 },
};

// Animation name mapping: upstream animation names in sheet definitions
// that differ from the canonical animation names used in sprite files.
export const ANIMATION_NAME_MAP = {
  combat: "combat_idle",
  "1h_slash": "backslash",
  "1h_backslash": "backslash",
  "1h_halfslash": "halfslash",
};

// Offset to center a 64px body in a 192px oversize frame
export const OVERSIZE_OFFSET_192 = 64;
// Offset to center a 64px body in a 128px frame
export const OVERSIZE_OFFSET_128 = 32;

// Standard animations for a complete character sheet
export const STANDARD_ANIMATIONS = [
  "spellcast", "thrust", "walk", "slash", "shoot",
  "hurt", "idle", "jump", "sit", "emote",
  "run", "combat_idle", "backslash", "halfslash",
];

// Minimal animation set for testing
export const MINIMAL_ANIMATIONS = ["idle", "walk"];

// Resolve an animation name through the mapping
export function resolveAnimName(anim) {
  return ANIMATION_NAME_MAP[anim] || anim;
}

// Check if an animation is a custom (oversize) animation
export function isCustomAnim(anim) {
  return anim in CUSTOM_ANIMATIONS;
}

// Get the frame size for an animation (64 for standard, larger for custom)
export function getFrameSize(anim) {
  if (isCustomAnim(anim)) {
    return CUSTOM_ANIMATIONS[anim].frameSize;
  }
  return FRAME_SIZE;
}

// Get the number of frames for an animation
export function getFrameCount(anim) {
  if (isCustomAnim(anim)) {
    return CUSTOM_ANIMATIONS[anim].frames;
  }
  return FRAMES_PER_ROW;
}

// Get the offset to center a standard frame in an oversize frame
export function getOversizeOffset(anim) {
  const size = getFrameSize(anim);
  if (size === 192) return OVERSIZE_OFFSET_192;
  if (size === 128) return OVERSIZE_OFFSET_128;
  return 0;
}
