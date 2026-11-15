# Dispose sender semantics before test completion

[Source784 Linux 43687397653](https://github.com/edgepillar/syrius/actions/runs/43687397653)
passes 1226 Python controls with seventeen skips, patched/application analysis,
286-file strict analysis and the early Ready/Lock gates. The compact gate has
one widget exception: the sender-header test still holds a SemanticsHandle at
the framework's completion check. Full tests and tracked generation are skipped.

Source785 disposes that handle in try/finally inside the test body, following
the existing neighboring semantics cases. Disposal occurs on both success and
assertion failure. Grouping, hit-testing, privacy semantics and restoration
expectations retain their exact expressions. No case, production code, workflow,
selection or command limit changes.

The original failed job and complete 454900-byte log are retained. Its owned
storage task closes successfully, registered scratch is removed and all outputs
are consumed. Source783's actual hosted localization result and Source784's exact
seven-file generated delta remain unchanged. No local SDK execution is claimed.

Fresh full Linux precedes grouped native/image qualification. Source780 remains
the latest qualified Windows/image source. Accepted scope stays 76/80 and
Source730 Ready pairs stay 2/94. V01/V06 remain in review; V02/V05 remain blocked.
The comparison refusal remains in force. No current native, new image match or
performance pass is projected; the original Docker/WSL route remains unqualified.
