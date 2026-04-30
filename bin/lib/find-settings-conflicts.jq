# find-settings-conflicts.jq — emit one warning string per scalar/type conflict
# between user accumulator ($u) and preset ($p). Caller passes $name = preset filename.
#
# Mirrors merge-settings.jq's traversal: warns on type mismatches (everywhere)
# and on scalar conflicts (where user's value differs from preset's). Arrays
# never warn — they always union+dedupe.

def find_conflicts($u; $p; $path):
  if $u == null or $p == null then empty
  elif ($u | type) != ($p | type) then
    "[\($name)] type mismatch at '\($path)': user=\($u | type), preset=\($p | type); preserving user value"
  elif ($u | type) == "object" then
    ((($u | keys) + ($p | keys)) | unique | .[]) as $k |
    find_conflicts(
      $u[$k];
      $p[$k];
      (if $path == "" then $k else "\($path).\($k)" end)
    )
  elif ($u | type) == "array" then
    empty
  elif $u != $p then
    "[\($name)] scalar conflict at '\($path)': user=\($u | tojson), preset would set \($p | tojson); preserving user value"
  else
    empty
  end;

find_conflicts($u; $p; "")
