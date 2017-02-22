# This file is a part of Julia. License is MIT: https://julialang.org/license

# Parse "GIT URLs" syntax (URLs and a scp-like syntax). For details see:
# https://git-scm.com/docs/git-clone#_git_urls_a_id_urls_a
const URL_REGEX = r"""
^(?:(?<scheme>ssh|git|https?)://)?
(?:
    (?<user>.*?)
    (?:\:(?<password>.*?))?@
)?
(?<host>[A-Za-z0-9\-\.]+)
(?(<scheme>)
    (?:\:(?<port>\d+))?  # only parse port when not using SCP-like syntax
    |
    :?
)
(?<path>.*?)$
"""x

function version()
    major = Ref{Cint}(0)
    minor = Ref{Cint}(0)
    patch = Ref{Cint}(0)
    ccall((:git_libgit2_version, :libgit2), Void,
          (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), major, minor, patch)
    return VersionNumber(major[], minor[], patch[])
end
const VERSION = version()

isset(val::Integer, flag::Integer) = (val & flag == flag)
reset(val::Integer, flag::Integer) = (val &= ~flag)
toggle(val::Integer, flag::Integer) = (val |= flag)

function prompt(msg::AbstractString; default::AbstractString="", password::Bool=false)
    if Sys.iswindows() && password
        error("Command line prompt not supported for password entry on windows. Use winprompt instead")
    end
    msg = !isempty(default) ? msg*" [$default]:" : msg*":"
    uinput = if password
        Base.getpass(msg)
    else
        print(msg)
        readline()
    end
    isempty(uinput) ? default : uinput
end

function features()
    feat = ccall((:git_libgit2_features, :libgit2), Cint, ())
    res = Consts.GIT_FEATURE[]
    for f in instances(Consts.GIT_FEATURE)
        isset(feat, Cuint(f)) && push!(res, f)
    end
    return res
end

"""
    LibGit2.posixpath(path)

Standardise the path string `path` to use POSIX separators.
"""
function posixpath end
if Sys.iswindows()
    posixpath(path) = replace(path,'\\','/')
else Sys.isunix()
    posixpath(path) = path
end

function git_url(;
        scheme::AbstractString="",
        username::AbstractString="",
        password::AbstractString="",
        host::AbstractString="",
        port::Union{AbstractString,Integer}="",
        path::AbstractString="")

    port_str = string(port)
    scp_syntax = isempty(scheme)

    isempty(host) && throw(ArgumentError("A host needs to be specified"))
    scp_syntax && !isempty(port_str) && throw(ArgumentError("Port cannot be specified when using scp-like syntax"))

    io = IOBuffer()
    !isempty(scheme) && print(io, scheme, "://")

    if !isempty(username) || !isempty(password)
        print(io, username)
        !isempty(password) && print(io, ':', password)
        print(io, '@')
    end

    print(io, host)
    !isempty(port_str) && print(io, ':', port_str)

    if !isempty(path)
        if scp_syntax
            print(io, ':')
        elseif !startswith(path, '/')
            print(io, '/')
        end
        print(io, path)
    end

    return String(take!(io))
end
