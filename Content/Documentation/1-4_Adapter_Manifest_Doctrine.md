# 📦 Adapter Manifest Doctrine

## 📖 Title
**Adapter Manifest Doctrine 1.1**

## 🌟 Purpose
Defines rules for adapter resolution, virtual path usage, manifest hydration, and secure signal-based instantiation in the SovereignTrust system.

---

## I. Every Adapter Has a VirtualPath

- Each adapter must declare a `VirtualPath`, retrievable using `Resolve-PathFromDictionary`.
- This path identifies where the adapter's Manifest file resides (local or mapped storage).
- Used by `Resolve-PathGraph` and `Resolve-PathGraphForConduction`.

---

## II. Manifests Hold Structured Metadata

- Adapter Manifests are JSON documents structured as memory jackets.
- Each Manifest may include:
  - `Module.Name`
  - `RelativeFilePath`
  - `Classes[]` with `.Name`, `.Source`
  - Optional: `Adapter`, `ConductionPlan`, `HydrationSignal`
- Manifests are always loaded into a Graph using signalized access methods.

---

## III. Hydration Creates Sovereign Instances

- After loading, adapters must be instantiated using sovereign routines:
  - Use `New-Object` or signalized constructor wrappers.
  - Prefer use of `HydrationIntentCondenser` where available.
  - Call `.Construct()` method if defined.

---

## IV. Adapters Must Be Signalized and Traceable

- All adapters are stored in memory using `Signal` objects.
- Placement rules:
  - `Adapters.<Name>` or `Mapped<Kind>.<Slot>`
  - All entries must be added using `Add-PathToDictionary`.
  - ReversePointer may optionally link to the resolving graph or conductor.

---

## V. Adapters Must Be Verified Post-Hydration

- After hydration, adapters must expose `.Test()` or `.Verify()` for integrity checks.
- Signals used for verification must call `.LogInformation()` on pass or `.LogCritical()` on fail.
- Adapters without verification methods must be treated as suspect.

---

## 🧠 Summary

Adapters are execution surfaces of SovereignTrust. No external capability may be used unless declared, hydrated, and tracked through sovereign signals and memory-safe manifests.

Last Updated: 2025-05-07
