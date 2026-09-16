# Smooth Battery Droplet for Droppy

A smooth battery indicator with live percentage and charging metrics for [Droppy](https://getdroppy.app).

## Features

- **Smooth Battery Gauge**: Continuous rounded battery body, animated liquid fill level, and adaptive state tints (Green, Low Power Yellow, Critical Red).
- **Zero-Jitter Percentage**: Monospaced digit layout preventing width jumps during percentage changes.
- **Shelf Widget**:
  - **Solo**: Detailed view with big battery gauge, large percentage, charging status, time remaining, power source state, and health condition.
  - **Paired**: Compact horizontal battery bar + percentage + state subtitle.
- **Live Activity**: Compact battery glyph + live percentage in the notch or Dynamic Island wings.
- **Settings Pane**: Integrated directly in Droppy Settings with customizable toggles.

## Building

```bash
# Build the .droplet bundle
../droppykit/Scripts/build-droplet.sh --arch arm64

# Validate
../droppykit/Scripts/validate-droplet.sh
```
