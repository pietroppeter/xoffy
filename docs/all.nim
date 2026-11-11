## Builds every page in one program: `nim r -d:release docs/all.nim`.
## A page is a nimib notebook in docs/ or docs/devlog/; each renders when its module is initialised,
## in import order.
{.warning[UnusedImport]: off.}
import index
import devlog/[inside_pptx, designing_0_1, tabelline_api, roadmap, index as devlogIndex]
