#!/bin/bash

# Empty slot in the bar; the SketchySpectrum service draws its own window on top of it
# and sets the width from its config.
spectrum=(
  width=300
  icon.drawing=off
  label.drawing=off
  background.drawing=off
)

sketchybar --add item spectrum center \
           --set spectrum "${spectrum[@]}"
