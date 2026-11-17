# Script Doctor

A Roblox Studio plugin that checks every script in your place for unsafe RemoteEvent
handlers, bugs that lose player data, backdoor patterns and deprecated API. Click a finding
to open the script at that line; simple cases can be fixed with a button.

It is made for code you did not write yourself: free models from the Creator Store, old
scripts, and code written by AI assistants.

## What it checks

**Security**

| Rule | What it finds |
|---|---|
| `remote-client-value` | A number sent by the client is written into a `.Value` (coins, stats) without an upper limit |
| `remote-unvalidated-args` | A value sent by the client is used on health, position, cloning, saving… without any check |
| `require-by-id` | `require(123456)`: code downloaded from an asset you cannot see |
| `loadstring` | Text run as code |
| `environment-access` | `getfenv` / `setfenv` |
| `insert-asset` | `InsertService:LoadAsset` at runtime |
| `obfuscated-code` | Text hidden as character codes, `string.char(…)` chains, reversed string literals |

**Bugs**

| Rule | What it finds |
|---|---|
| `datastore-no-pcall` | A DataStore request outside `pcall`: an outage stops the script |
| `memorystore-no-pcall` | The same for MemoryStore |
| `datastore-save-after-failed-load` | A failed load is forgotten, so the later save overwrites the player's real data with defaults |
| `datastore-no-bindtoclose` | Data is saved on `PlayerRemoving` but not when the server shuts down |
| `bindtoclose-fixed-wait` | `BindToClose` waits a fixed time instead of waiting for the saves |
| `findfirstchild-unchecked` | `FindFirstChild(…)` result used directly: errors when the object is missing |
| `playeradded-no-existing-players` | `PlayerAdded` is connected but players already in the game are not handled. A bug when the connection runs late (after a wait, inside a function, in a ModuleScript); advice otherwise |

**Deprecated API and advice**

| Rule | What it finds | Fix button |
|---|---|---|
| `deprecated-global` | `wait`, `spawn`, `delay` | `task.wait`, `task.defer`, `task.delay` |
| `deprecated-connect` | `:connect`, `:disconnect` | `:Connect`, `:Disconnect` |
| `deprecated-method` | camelCase aliases: `:findFirstChild`, `:clone`, `:destroy`, `:isA`… | the PascalCase name |
| `deprecated-remove` | `:Remove()` | no: `:Destroy()` is not the same if the object is put back later |
| `deprecated-joints` | `MakeJoints` / `BreakJoints` in any spelling | no |
| `deprecated-loadanimation` | `Humanoid:LoadAnimation` | no |
| `deprecated-raycast` | `FindPartOnRay…` | no |
| `deprecated-body-mover` | `BodyVelocity`, `BodyGyro`, … | no |
| `instance-new-parent` | `Instance.new(class, parent)` | no |

`spawn` becomes `task.defer`, not `task.spawn`: like the old `spawn`, `task.defer` runs the
function a moment later, while `task.spawn` runs it right away and changes the order of
the code around it.

## What the Fix buttons change

- **Fix** on a finding replaces the one word it points at.
- **Fix N safe** asks first, then applies every fix in the place. Only the renames in the
  table above are applied; everything else needs a person.
- A lowercase method is **not** renamed when any script of the place defines a method with
  that name (`function Enemy:takeDamage()`, `Maid.destroy = Maid.clean`): then the call may
  be your own class, and `e:TakeDamage()` would break it.
- **Ctrl+Z does not undo plugin edits.** Use **Undo fixes** in the panel: each press takes
  back one fix step (up to 20). A script you edited after the fix is left alone. The undo
  history is kept until Studio is closed.
- Fixes are off while the game is running (Play / Run): changes made there are thrown away
  on Stop.

## Limits

Script Doctor reads the text of each script; it does not run the game and does not know
variable types. It looks for common patterns, so it can miss a problem written in an unusual
way, and a finding is a reason to look, not proof.

## Install

Not on the Creator Store yet. From the source (needs [Rojo](https://rojo.space)):

```sh
rojo build default.project.json -o ScriptDoctor.rbxm
```

Copy `ScriptDoctor.rbxm` to the local plugins folder (Studio: Plugins tab → Plugins Folder)
and restart Studio.

## Development

The checker core (`src/core`) is plain Luau with no Roblox API, tested with
[Lune](https://lune-org.github.io/docs):

```sh
lune run tests/run.luau            # fixtures, fix/undo, sample snapshots, hand labels
lune run tests/run.luau update     # rewrite snapshots after reviewing the difference
stylua src tests
selene src/core tests/run.luau
selene generate-roblox-std         # once: writes roblox.yml for the next line
selene --config selene-plugin.toml src/plugin tests/studio
```

The plugin shell (`src/plugin`) is tested in Studio: build with
`rojo build test.project.json -o build/ScriptDoctor.rbxm` (adds the automation hook in
`tests/studio/TestHooks.luau`) and run `tests/studio/e2e.luau`; see the comment at its top.
