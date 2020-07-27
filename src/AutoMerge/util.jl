function checkout_branch(dir::AbstractString,
                         branch::AbstractString;
                         git_command::AbstractString = "git")
    original_working_directory = pwd()
    cd(dir)
    Base.run(`$(git_command) checkout $(branch)`)
    cd(original_working_directory)
end

clone_repo(repo::GitHub.Repo) = clone_repo(repo_url(repo))

function clone_repo(url::AbstractString)
    parent_dir = mktempdir()
    atexit(() -> rm(parent_dir; force = true, recursive = true))
    repo_dir = joinpath(parent_dir, "REPO")
    my_retry(() -> _clone_repo_into_dir(url, repo_dir))
    @info("Clone was successful")
    return repo_dir
end

function _clone_repo_into_dir(url::AbstractString, repo_dir)
    @info("Attempting to clone...")
    rm(repo_dir; force = true, recursive = true)
    mkpath(repo_dir)
    LibGit2.clone(url, repo_dir)
    return repo_dir
end

function _comment_disclaimer()
    result = string("\n\n",
                    "Note that the guidelines are only required for the pull request ",
                    "to be merged automatically. However, it is **strongly recommended** ",
                    "to follow them, since otherwise the pull request needs to be ",
                    "manually reviewed and merged by a human.")
    return result
end

function _comment_noblock()
    result = string("\n\n---\n",
                    "If you want to prevent this pull request from ",
                    "being auto-merged, simply leave a comment. ",
                    "If you want to post a comment without blocking ",
                    "auto-merging, you must include the text ",
                    "`[noblock]` in your comment.")
    return result
end

function comment_text_pass(::NewVersion,
                           suggest_onepointzero::Bool,
                           version::VersionNumber)
    result = string("Your `new version` pull request met all of the ",
                    "guidelines for auto-merging and is scheduled to ",
                    "be merged in the next round.",
                    _comment_noblock(),
                    _onepointzero_suggestion(suggest_onepointzero, version),
                    "\n<!-- [noblock] -->")
    return result
end

function comment_text_pass(::NewPackage,
                           suggest_onepointzero::Bool,
                           version::VersionNumber)
    result = string("Your `new package` pull request met all of the ",
                    "guidelines for auto-merging and is scheduled to ",
                    "be merged when the mandatory waiting period (3 days) has elapsed.",
                    "\n\n",
                    "Since you are registering a new package, ",
                    "please make sure that you have read the ",
                    "package naming guidelines: ",
                    "https://julialang.github.io/Pkg.jl/dev/creating-packages/#Package-naming-guidelines-1",
                    "\n\n",
                    _comment_noblock(),
                    _onepointzero_suggestion(suggest_onepointzero, version),
                    "\n<!-- [noblock] -->")
    return result
end

function comment_text_fail(::NewPackage,
                           reasons::Vector{String},
                           suggest_onepointzero::Bool,
                           version::VersionNumber)
    reasons_formatted = join(string.("- ", reasons), "\n")
    result = string("Your `new package` pull request does not meet ",
                    "the guidelines for auto-merging. ",
                    "Please make sure that you have read the ",
                    "[General registry README](https://github.com/JuliaRegistries/General/blob/master/README.md). ",
                    "The following guidelines were not met:\n\n",
                    reasons_formatted,
                    _comment_disclaimer(),
                    "\n\n",
                    "Since you are registering a new package, ",
                    "please make sure that you have also read the ",
                    "package naming guidelines: ",
                    "https://julialang.github.io/Pkg.jl/dev/creating-packages/#Package-naming-guidelines-1",
                    "\n\n",
                    _comment_noblock(),
                    _onepointzero_suggestion(suggest_onepointzero, version),
                    "\n<!-- [noblock] -->")
    return result
end

function comment_text_fail(::NewVersion,
                           reasons::Vector{String},
                           suggest_onepointzero::Bool,
                           version::VersionNumber)
    reasons_formatted = join(string.("- ", reasons), "\n")
    result = string("Your `new version` pull request does not meet ",
                    "the guidelines for auto-merging. ",
                    "Please make sure that you have read the ",
                    "[General registry README](https://github.com/JuliaRegistries/General/blob/master/README.md). ",
                    "The following guidelines were not met:\n\n",
                    reasons_formatted,
                    _comment_disclaimer(),
                    _comment_noblock(),
                    _onepointzero_suggestion(suggest_onepointzero, version),
                    "\n<!-- [noblock] -->")
    return result
end

function comment_text_merge_now()
    result = string("The mandatory waiting period has elapsed.\n\n",
                    "Your pull request is ready to merge.\n\n",
                    "I will now merge this pull request.",
                    "\n<!-- [noblock] -->")
    return result
end

is_julia_stdlib(name) = name in julia_stdlib_list()

function julia_stdlib_list()
    return readdir(Pkg.Types.stdlib_dir())
end

function now_utc()
    utc = TimeZones.tz"UTC"
    return Dates.now(utc)
end

function _onepointzero_suggestion(suggest_onepointzero::Bool,
                                  version::VersionNumber)
    if suggest_onepointzero && version < v"1.0.0"
        result = string("\n\n---\n",
                        "On a separate note, I see that you are registering ",
                        "a release with a version number of the form ",
                        "`v0.X.Y`.\n\n",
                        "Does your package have a stable public API? ",
                        "If so, then it's time for you to register version ",
                        "`v1.0.0` of your package. ",
                        "(This is not a requirement. ",
                        "It's just a recommendation.)\n\n",
                        "If your package does not yet have a stable public ",
                        "API, then of course you are not yet ready to ",
                        "release version `v1.0.0`.")
        return result
    else
        return ""
    end
end

function time_is_already_in_utc(dt::Dates.DateTime)
    utc = TimeZones.tz"UTC"
    return TimeZones.ZonedDateTime(dt, utc; from_utc = true)
end
