# Syrius lab

A go-zenon devnet of this repository's own, chain 321. Every harnessed run
that sends a block goes here, never to a public devnet: a spork activated from
a wallet as a test stopped a public devnet on 2026-10-11.

```sh
tools/devnet/lab/lab.sh up       # fetches go-zenon, builds the image and the assets on first use
tools/devnet/lab/lab.sh status   # containers, and whether momentums are being produced
tools/devnet/lab/lab.sh down     # stop, chain kept
tools/devnet/lab/lab.sh wipe     # stop, delete the chain and the assets
```

Needs bash (Git Bash on Windows), git, Docker and Node. Nothing outside this
repository: `lab.sh` fetches go-zenon from GitHub at one pinned commit into
`.build/` (`GO_ZENON_REV` and `GO_ZENON_URL` override it) and builds the image
from an export of that commit.

## What it is

go-zenon's five-node devnet (three pillars, an RPC node, an observer) under
names of its own, so it shares nothing with any other devnet on the machine:

| | The lab |
|---|---|
| Compose project | `syrius-lab` |
| Containers | `syrius-lab-*` |
| Network | `syrius-lab`, 172.37.0.0/24 |
| RPC on the host | `127.0.0.1:45997` HTTP, `127.0.0.1:45998` WS |
| Chain identifier | 321 |
| Restart policy | none: it stays down until `up` |

The chain identifier is the one change to go-zenon's devnet genesis
(`make-assets.js`). It is signed into every block and is the p2p network id,
so a block signed for the lab is worth nothing on any other chain.

Everything else is go-zenon's committed devnet, so its accounts hold: the
devnet mnemonic's index 1 (`z1qq6eg8n43g032hanpsfp02qcdmv7zfj3y2lt5d`) has
10,000 ZNN and 100,000 QSR and owns pillar `dev1`, index 0 produces for it and
is the spork address, and the genesis carries three fuses of 10,000 QSR owned
by index 1. The devnet mnemonic is public, in go-zenon's repository:

```
abstract affair idle position alien fluid board ordinary exist afraid chapter wood wood guide sun walnut crew perfect place firm poverty model side million
```

## Pointing the harness at it

```sh
harness/h start --fresh
harness/h import --mnemonic "<the devnet mnemonic>" --password '<password>' --node ws://127.0.0.1:45998 --chain 321
harness/h chain 321
```

The wallet signs with its own client chain identifier, default 1, and does not
follow the node: a send fails with "different network Id (1)" until `chain 321`.
Then add a second address in Settings and select it: index 1 is the funded
one. Check `lab.sh status` says "producing" before the first send: a stopped
chain accepts blocks into its pool and looks alive.

For an account that pays with proof of work, send ZNN from index 1 to another
index through the wallet and select that index.

## Limits

- The three genesis fuses cannot be cancelled: the plasma contract answers
  CancelFuse for one with an error (its receive block carries code 2 and sends
  nothing back), seen 2026-10-11 at momentum 33; the reason was not found. A
  fuse made on the lab can be cancelled only after 3,600 momentums
  (`FuseExpiration`, about 15 hours here), so a batch cancel needs a lab that
  has been left running.
- Momentums take about 15 s on Docker Desktop, not 10. The first momentum of
  a new chain comes about 90 s after the nodes start.
- The bridge contract is not usable: the `bridge-liq` spork is inactive in the
  devnet genesis and the bridge administrator is an address compiled into
  znnd that no devnet key holds.
- The Sporks page is read-only here: the wallet knows the spork administrator
  of chains 1 and 69 only. Do not activate a spork as a test on any chain.
