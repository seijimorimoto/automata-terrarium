# merge-settings.jq — deep-merge a preset ($p) into a user/accumulator ($u).
#
# Locked rules:
#   - arrays of strings: union + dedupe + sort alphabetically (jq's `unique` does this)
#   - arrays of objects: union + dedupe by deep equality, preserve order
#   - objects: recursive merge per child key
#   - scalars: preserve user's value if set (treat null as missing)

def deep_merge($u; $p):
  if   $u == null and $p == null then null
  elif $u == null then $p
  elif $p == null then $u
  elif ($u | type) != ($p | type) then $u
  elif ($u | type) == "object" then
    reduce ((($u | keys) + ($p | keys)) | unique | .[]) as $k
      ({}; .[$k] = deep_merge($u[$k]; $p[$k]))
  elif ($u | type) == "array" then
    (($u + $p) as $combined |
     if ($combined | length) == 0 then []
     elif ($combined | all(type == "string")) then ($combined | unique)
     else
       reduce $combined[] as $x
         ([]; if (any(.[]; . == $x)) then . else . + [$x] end)
     end)
  else
    $u
  end;

deep_merge($u; $p)
