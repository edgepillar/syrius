# Source744: retain actual generated localization output

[Source743 full Linux 43525669493](https://github.com/edgepillar/syrius/actions/runs/43525669493)
passes analysis, every early gate and the complete non-chain directory:
5,080 tests pass, zero fail and one is skipped. The pixel-ratio/resource and
independent color-envelope cases pass. Only the final generated-file check
fails, with zero artifacts.

The retained hosted `git diff` changes five locale artifacts. Its only
operation wraps the same plural `other` string onto the next line. This
revision applies that exact generated output. English wording, singular and
plural values, the ARB, base localization interface, handwritten code and
tests remain unchanged. No local SDK regeneration is claimed.

The existing early Ready/entry gate now also runs
`test/shaders/entry_field_test.dart`. This exposes future field, pixel-ratio
and image-lifetime failures before the complete directory. The complete
directory and final generated-file check remain mandatory. Test
registrations, selected Windows counts, command caps and the `dev` PR filter
are unchanged.

The original Source743 run remains failed. Fresh full Linux must pass every
step before native image/timing qualification. Previous Windows failures,
Source738's failed performance comparison and the two accepted Source730
Ready pairs keep their original sources. No new image or performance pass is
projected. Accepted scope remains 76/80 and accepted pairs 2/94; V01, V02, V05
and V06 stay open. F06 retains Source722 and the original Docker/WSL route
remains unqualified.
