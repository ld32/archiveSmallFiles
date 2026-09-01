#!/usr/bin/env bash
#
# Convert between O2 local paths, Starfish volume paths, and Starfish URLs.
# Supports bidirectional conversion between multiple storage systems.
#

# O2 login-node prefix -> Starfish volume mapping
declare -A O2_TO_STARFISH=(
  ["/n/no_backup/"]="Active-NoBackup:" 
  ["/n/data1/"]="Active-Compute-Data1:"
  ["/n/data2/"]="Active-Compute-Data2:"
  ["/n/groups/"]="Active-Compute-Groups:"
  ["/n/scratch/"]="Active-Scratch:"
  ["/home/"]="o2_home:"
  ["/n/data3_vast/"]="VAST_DATA3:"
  ['/n/standby']="Standby-Standard:"
  ['/n/files/']="Active-Collaborations:"
)

# Build reverse mapping: Starfish volume -> O2 prefix
declare -A STARFISH_TO_O2=()
for prefix in "${!O2_TO_STARFISH[@]}"; do
  vol="${O2_TO_STARFISH[$prefix]}"
  STARFISH_TO_O2["$vol"]="$prefix"
done

# Find the longest matching prefix for a given path
find_best_prefix() {
  local path="$1"
  local -n array_ref="$2"
  local best_prefix=""
  
  for prefix in "${!array_ref[@]}"; do
    if [[ "$path" == "$prefix"* ]]; then
      if (( ${#prefix} > ${#best_prefix} )); then
        best_prefix="$prefix"
      fi
    fi
  done
  
  echo "$best_prefix"
}

# Convert O2 local path to Starfish volume path and URL
fromO2Path() {
  local local_path="$1"
  
  if [[ -z "$local_path" ]]; then
    echo "usage: fromO2Path /n/..." >&2
    return 1
  fi

  local best_prefix=$(find_best_prefix "$local_path" O2_TO_STARFISH)
  
  if [[ -z "$best_prefix" ]]; then
    echo "No Starfish mapping for $local_path" >&2
    return 1
  fi

  local volume="${O2_TO_STARFISH[$best_prefix]}"
  local rel="${local_path#$best_prefix}"

  if [[ "$volume" == "Standby-Standard:" ]]; then
    rel="data${rel}"
  fi
  
  printf '%s%s\n' "$volume" "$rel"
  printf '%s\n' "https://starfish.med.harvard.edu/#/overview?volume=${volume%:}&path=$rel"
}

# Convert Starfish volume path to O2 local path
fromStarfish() {
  local sf_path="$1"
  local suppress_url="$2"
  
  if [[ -z "$sf_path" || "$sf_path" != *:* ]]; then
    echo "usage: fromStarfish Volume:relative/path" >&2
    return 1
  fi

  local best_prefix=$(find_best_prefix "$sf_path" STARFISH_TO_O2)
  
  if [[ -z "$best_prefix" ]]; then
    echo "No local path mapping for $sf_path" >&2
    return 1
  fi

  local volume="${STARFISH_TO_O2[$best_prefix]}"
  local rel="${sf_path#$best_prefix}"
  

  # Print Starfish URL unless suppressed
  [[ -z "$suppress_url" ]] && printf '%s%s\n' "https://starfish.med.harvard.edu/#/overview?volume=${best_prefix}&path=$rel"
  
  
  if [[ "$volume" == /n/standby* ]]; then
    rel="${rel#data}"
  fi
  
  # Print O2 local path
  printf '%s%s\n' "$volume" "$rel"
}


# Convert Starfish URL to O2 local path
fromURL() {
  local url="$1"
  
  if [[ -z "$url" || "$url" != https://starfish.med.harvard.edu/* ]]; then
    echo "usage: fromURL https://starfish.med.harvard.edu/#/overview?volume=Volume&path=relative/path" >&2
    return 1
  fi

  local volume="${url#*volume=}"
  volume="${volume%%&path=*}"
  local rel="${url#*path=}"

  if [[ -z "$volume" || -z "$rel" ]]; then
    echo "Invalid Starfish URL: $url" >&2
    return 1
  fi

  local sf_path="${volume}:${rel}"
  printf '%s\n' "$sf_path"
  
  # Also print O2 local path (suppress URL output)
  fromStarfish "$sf_path" 1
}

# Main script entry point
path="$1"

if [[ "$path" == /* ]]; then
  fromO2Path "$path"
elif [[ "$path" == https* ]]; then
  if [[ "$path" == *"?"* && "$path" != *"&"* ]]; then
    echo "Error: The URL appears truncated at an unquoted '&'." >&2
    echo "Please use quotes around the URL to avoid shell interpretation." >&2
    exit 1
  fi
  fromURL "$path"
else 
  fromStarfish "$path"
fi
