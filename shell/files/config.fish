# ~/.config/fish/config.fish — AtivOS default (copied from /etc/skel for
# every new user)

if status is-interactive
    # Skip fish's default multi-line welcome message.
    set fish_greeting

    # A couple of quality-of-life aliases if the modern replacements are
    # installed (they are, by default, on AtivOS) — fall back silently
    # otherwise so this file still works if someone removes them.
    if type -q eza
        alias ls 'eza --group-directories-first'
        alias ll 'eza -l --group-directories-first'
        alias la 'eza -la --group-directories-first'
    end
    if type -q bat
        alias cat 'bat --paging=never'
    end

    alias ativ 'sudo ativ'
end

# Starship prompt
if type -q starship
    starship init fish | source
end
