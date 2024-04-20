#!/bin/bash

# Define an array to store package lists from files
declare -a package_lists

# Loop through each list file provided as arguments
for file in "$@"
do
  # Read packages from the file and store them in the array
  while IFS= read -r package; do
    package_lists+=("$package")
  done < "$file"
done

# Get list of installed packages using pacman
installed_packages=$(pacman -Qtq)

# Find packages installed that are not in any list file
unlisted_packages=()
for package in $installed_packages; do
  # Check if package exists in the array (any list file)
  if [[ ! "${package_lists[@]}" =~ "$package" ]]; then
    unlisted_packages+=("$package")
  fi
done

# Print unlisted packages if there are any
if [[ ${#unlisted_packages[@]} -gt 0 ]]; then
  echo "Following packages are installed but not present in any list file:"
  echo "${unlisted_packages[@]}"
else
  echo "All installed packages are present in at least one list file."
fi
