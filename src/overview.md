src/Perl6/World.nqp
    - introduce $\*DISTRIBUTION into every UNIT. - add World.current_distribution()
    - introduce a cache for World.current_file()
    - change World.load_module() to use CU::RR.NEED($module_name, %opts) instead of CU:RR.head.need($spec);      # That's the switch that changes to the new logic.

src/Perl6/Grammar.nqp
    - rule package_def    # package construction
        - guard against package version retrieval in SETTING
        - add $\*VER, $\*API and $\*AUTH fallbacks via World.current_distribution()

src/Perl6/Actions.nqp
    - sub make_variable_from_parts()    # code generation for variable accesses
        - remove code to process `$?DISTRIBUTION`                                                                # are we dropping support for $?DISTRIBUTION?

src/core.c/Exception.pm6
    - add X::CompUnit::META::DependencySyntax

src/Perl6/Metamodel/PackageHOW.nqp
    - add `$api` arg to `method new_type()`                                                                      # $auth and $ver were already there. Was this missing?

src/core.c/Distribution/Utils.pm6
    - system-collapse() copied from Zef                                                                          # validate if this is still identical to zef upsteam
        - resolves declarative `if` statements in `depends` (e.g. `by-distro.name`)

src/core.c/CompUnit/Repository/Distribution.pm6
    - from-precomp() is now guarding against Distribution.repo and Distribution.repo-name not being set.         # when would this trigger? -> If it should never trigger, then die instead.

src/core.c/CompUnit/Repository/FileSystem.pm6
    - add alternative to `candidates` multi with `file, name, auth, ver, api`. There already is a DependencySpecification candidate. That's equivalent to `Name, auth, ver, api`.
      The candidate basically does a post filter whether the found distro contains a file at that path (only `bin/` and `resources/`).
                                                                                                                 # The function is identical to the existing `.files()`. Difference: `.files() returns the %meta of the Distribution, `.candidates()` returns the Distribution itself.
    - Add another similar candiatate that uses `file` for the `short-name` also.                                 # When would a short name ever match a bin/ or resource/ file?
                                                                                                                 # Why are there slight differences in the implementation of the two candidates?

src/core.c/CompUnit/Repository/Installation.pm6
    - again, add `.candidates()` variants that filter for the file. Identical to CURFS. Again a direct copy of `.files()` only returning a Distribution object instead of the meta.
    - make `.candidates(DepSpec)` return a CURD wrapping a LazyDistribution instead of a LazyDistribution directly.

src/core.c/CompUnit/Repository/Locally.pm6
    - make the instance cache in `.new()` use not only absolute but also resolved paths in the cache key.
    - add a `.normalize-path()` method. Only used once in `CU/RepositoryRegistry.distribution-for-file()`.

src/core.c/CompUnit/Loader.pm6
    - in `.load-source()` do a `.rethrow` instead of a `.throw` to repropagate the exception after a failure to load the source. That seems sensible but is independent of the other changes.
      Already in main.

src/core.c/CompUnit/PrecompilationRepository.pm6
    - In `CompUnit::PrecompilationRepository::Default.try-load()` don't provide module name in `source-name` passed to `.precompile()`    # This seems to be purely for information to the user? Why downgrade here?

src/core.c/CompUnit/RepositoryRegistry.pm6
    - `NEED()` this is the actual resolution logic.


meta<files> is an internal META field populated in `CURFS!distribution` and `core.c/Distribution/Path.TWEAK` that contains the paths of files in `bin/` and `resources/`. It does NOT contain `lib/` stuff.

Key Behaviors

1. Find distribution for a dependency (either distro or module name)
Either we directly find the dependency in our META or we try to find a distro containing that module which is then found in our META deps.
Implemented in DistributionUtils.module-dependency(). Uses CURR.candidates($module-name);

2. Determine distro of current comp unit
Usually trivial.
Happens in Perl6/World.nqp `current-distribution()` which in turn is used in `comp_unit_stage0()`.
Now added support for filenames in CURR.distribution-for-file(). Uses CURI/CURFS.candidates(:file);


Questions to answer:

- What's the reason `load` (== `require`?) is not adapted in the same way `need` (== `use`) is?
- 
