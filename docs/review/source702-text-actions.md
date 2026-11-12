# Readable neutral text actions

The four [Source699 Staking/Token captures](https://github.com/edgepillar/syrius/actions/runs/43252347402)
were independently [verified](https://github.com/edgepillar/syrius/actions/runs/43256566119)
and individually viewed against their references. The secondary fills and
populated-list end notices are gone. In Token, Max, This address and Send
remain too faint; the light actions are almost white on their light surfaces.
Material's default text-button foreground takes the existing surface-valued
primary color after the background becomes transparent.

Both themes now resolve ordinary text-action ink from their semantic dim
color, with foreground ink for hover, focus and press. Disabled controls keep
the faint ink. The existing transparent background remains. Token amount-unit
suffixes use faint ink rather than a token accent. Values, recipients and
original action owners are preserved.

The existing theme case now checks a minimum 4.5:1 luminance ratio for normal,
hovered, focused and pressed text actions over four surfaces in both themes.
It adds no registered test case. Hosted qualification of this revision is
pending.

## Retained visual findings

X685-X688 record the four refreshed Staking/Token mismatches. Staking still
needs the reference strip composition and table typography. Token still has
different filter/table bands, column geometry and detail placement. Original
chain values are preserved. The genuine receive toast in dark Staking is
recorded rather than replaced with illustrated state.

The six [Source701 Lock captures](source701-entry-surfaces.md) were also
actually reviewed. Their normal and error-card positions now agree with the
reference, while the expanded picker still differs. X689-X694 preserve each
pair's findings. The approved archive is retained once; its temporary PNG
copies were reviewed while owned and then removed through normal task closure.
No old evidence or storage policy changed.

Source701's failed Ready producer remains a failed original result, with no
images and an unestablished inner cause. Its successful independent reader
does not turn that run into native success. Full acceptance remains 73/80,
with zero accepted whole-image matches.
