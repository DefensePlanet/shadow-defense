# Menu Design Reference — Key Values from Research

## Typography Scale (4-Level System)
| Level | Size | Use |
|---|---|---|
| Display | 28-32px | Screen titles, hero numbers |
| Heading | 20-24px | Section headers |
| Body | 14-16px | Descriptions, card text |
| Label | 11-12px | Tags, captions, minimum readable |

## Spacing (8px Base Grid)
- Tight: 8px
- Moderate: 12-16px
- Section break: 24px
- Major division: 32px

## Card Standards
- Corner radius: 16px (cards), 8px (buttons), 24px (modals)
- Shadow: y:4 blur:12 rgba(0,0,0,0.35)
- Inner padding: 16px all sides
- Grid gap: 12-16px

## Touch Targets
- Minimum: 48x48px for ALL interactive elements
- Spacing between targets: minimum 8px, preferred 12-16px

## Animation Timing
| Action | Duration | Easing |
|---|---|---|
| Button press down | 80ms | EASE_OUT |
| Button release up | 120ms | TRANS_BACK EASE_OUT |
| Screen enter | 280ms | EASE_OUT_CUBIC |
| Screen exit | 200ms | EASE_IN |
| Card reveal | 300ms | EASE_IN_OUT |
| Reward pop | 400ms | TRANS_BACK EASE_OUT |
| Tab cross-fade | 150ms | EASE_IN_OUT |
| Idle CTA pulse | 1800ms loop | TRANS_SINE |

## Color (60-30-10 Rule)
- 60% Base: near-black with tint (#0C0D14)
- 30% Panel: 20-40% lighter (#1C2033)
- 10% Accent: high saturation (gold #FFB800)

## Gradient Overlay Shader (for art cards)
```glsl
shader_type canvas_item;
void fragment() {
    float alpha = smoothstep(0.3, 1.0, UV.y);
    COLOR = vec4(0.0, 0.0, 0.0, alpha * 0.7);
}
```

## Bottom Nav Bar
- Height: 64-80px
- Icon: 24-28px
- Label: 11-12px
- Bottom safe area: +34px for iPhone
