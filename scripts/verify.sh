#!/bin/bash

# List of JavaScript files to run
js_files=("./scripts/merkle1.js" "./scripts/merkle2.js" "./scripts/merkle3.js" "./scripts/fri1.js" "./scripts/fri2.js" "./scripts/fri3.js" "./scripts/fri4.js" "./scripts/fri5.js" "./scripts/fri6.js" "./scripts/gps.js")

# Loop through the array and execute each JavaScript file
for file in "${js_files[@]}"
do
    node "$file"
done