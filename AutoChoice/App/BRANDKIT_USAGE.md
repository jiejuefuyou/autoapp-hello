---
id: brandkit-usage-autochoice
title: "BrandKit Usage: AutoChoice"
category: design-system
priority: p2
---

# BrandKit Usage — AutoChoice

AutoChoice brand: pink `#F72585` / blue `#3366F2` / purple `#7C3AED`

## Colors

```swift
// Brand accent
Text("Spin!").foregroundStyle(Color.brandPrimary)
Circle().fill(Color.brandSecondary)
Image(systemName: "star").foregroundStyle(Color.brandTint)

// Semantic surfaces
RoundedRectangle(cornerRadius: Radius.md).fill(Color.surface)
Text("Secondary info").foregroundStyle(Color.onSurfaceSecondary)

// Status
Text("Saved").foregroundStyle(Color.success)
Text("Watch out").foregroundStyle(Color.warning)
Text("Error occurred").foregroundStyle(Color.error)
```

## Typography

```swift
Text("AutoChoice").font(Typography.h1)         // largeTitle rounded heavy
Text("Pick your item").font(Typography.h2)     // title rounded bold
Text("Section header").font(Typography.h3)     // title3 semibold
Text("Explanation").font(Typography.body)
Text("Important").font(Typography.bodyEmphasis)
Text("Hint text").font(Typography.caption)
Text("42").font(Typography.displayNumber)      // 56pt heavy rounded — score / count
Text("00:12").font(Typography.tabularBody)     // monospaced digits
```

## Spacing

```swift
VStack(spacing: Spacing.md) { ... }            // 16 pt gap
.padding(.horizontal, Spacing.lg)              // 24 pt side padding
.padding(.vertical, Spacing.sm)                // 8 pt vertical
HStack(spacing: Spacing.xs) { ... }            // 4 pt tight gap
```

## Corner radius

```swift
.cornerRadius(Radius.sm)                       // 6 — small chips
.cornerRadius(Radius.md)                       // 12 — cards, buttons
.cornerRadius(Radius.lg)                       // 20 — sheets, modals
Capsule() // or .cornerRadius(Radius.pill)     // 999 — pill badges
```

## Shadow / elevation

```swift
CardView()
    .brandCardShadow()                         // Elevation.card default
    .brandCardShadow(Elevation.hover)          // hover / focused state
```

## Migration guide

Replace scattered magic values with BrandKit tokens:

| Before | After |
|--------|-------|
| `Color(red: 0.97, green: 0.14, blue: 0.52)` | `Color.brandPrimary` |
| `Color.red.opacity(0.1)` (error bg) | `Color.error.opacity(0.1)` |
| `Font.system(.title)` | `Typography.h2` |
| `Font.system(.largeTitle, weight: .heavy)` | `Typography.h1` |
| `padding(16)` | `padding(Spacing.md)` |
| `.cornerRadius(12)` | `.cornerRadius(Radius.md)` |
| `shadow(radius: 6)` | `.brandCardShadow()` |

**Rule: no new magic values in new code. Use BrandKit semantic tokens.**
