source "$__fish_config_dir/functions/fish_greeting.fish"

function fish_greeting
end
set -U dangerous_nogreeting

if status is-interactive
    set -U fish_key_bindings fish_vi_key_bindings
    fish_vi_key_bindings
    source "$__fish_config_dir/functions/key_bindings.fish"
end