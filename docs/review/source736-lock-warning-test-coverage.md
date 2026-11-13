# Original Lock warning and early coverage

Source735 (`9867769c059749e09b31d894e0625421190833f9`) passed strict selected
analysis and every early interface gate, but its [full Linux run](https://github.com/edgepillar/syrius/actions/runs/43471504753)
reported 5,078 passed, two failed and one skipped Dart cases. Generation was
skipped. Both failures were the existing wrong-password cases, one per theme:
their finder still requested the former Material warning icon after the
presentation changed to the original reference SVG.

Those cases now use the existing reference-symbol helper to verify the actual
warning path, explicit 14 px size and error ink. The global attempt limit,
truthful reset message, password clearing and field-border assertions remain.
No production behavior, reference artwork, test registration or assertion
about authentication policy changes. The shared helper is unchanged.

The early Lock step now includes the existing Lock card file alongside picker
tests. This puts both warning themes before the full non-chain directory;
the complete directory and generation check remain required. Source735's
failed execution is preserved. Fresh CI must qualify this correction before
new Windows captures are admitted.

Owner-accepted scope remains 76/80 with V01, V02, V05 and V06 open. The original
Docker/WSL route stays unqualified. Accepted visual pairs remain 2/94 at
Source730. No new whole-image, timing or release result is claimed.
