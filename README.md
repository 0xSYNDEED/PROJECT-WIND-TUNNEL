# Miniature Open-Circuit Subsonic Wind Tunnel

**ME 366 (Electromechanical System Design) project, Group A13, Department of Mechanical Engineering, BUET, 2026**

This repository has the CAD, firmware, data-reduction scripts, experimental data and CFD setup files for a low-cost miniature wind tunnel. The tunnel was built, instrumented, and validated against Ansys Fluent simulations of its own test section. Everything needed to rebuild the tunnel or reproduce the report's plots is here. The only exceptions are the large solver outputs, which are listed under [What is not included](#what-is-not-included).

| | |
|---|---|
| Type | Open-circuit, induced-draft (fan at the exit) |
| Test section | 160 × 160 × 340 mm (6 mm plywood + 6 mm acrylic window) |
| Contraction | 6.25 : 1 (400 × 400 → 160 × 160 mm), fifth-order polynomial, 370 mm long |
| Settling chamber | 400 × 400 mm, 208 mm long, 70 mm straw honeycomb, 3 screens |
| Diffuser | 160 × 160 → 250 × 250 mm, 695 mm long (3.7° wall half-angle) |
| Fan | 14 in, 350 W drum fan with an SCR speed regulator |
| Speed | 16–18 m/s with model (Re ≈ 1.2 × 10⁵ on a 100 mm chord) |
| Instruments | Dual-lever load-cell balance (lift + drag), surface pressure taps, Pitot-static probe, smoke rake |
| Test models | NACA 4418 airfoil (−5° to +10°), 25° slant Ahmed body |

**Authors:** Ahnaf Masud Syndeed, Hasibul Karim Ratul, Mubasshira, Bivashindhu Datta Badhon

---

## Repository layout

```
PROJECT WIND TUNNEL/
├── [CAD] Wind Tunnel/          SolidWorks models, assemblies and laser-cutting DXFs
├── [CFD] Wind Tunnel/          Ansys Fluent projects, meshing workflows, monitor logs
└── [Codes] Wind Tunnel/        Arduino firmware + MATLAB data reduction and plotting
```

### `[CAD] Wind Tunnel/`

| Path | Contents |
|---|---|
| `Wind Tunnel w NACA 4418.SLDASM` | Full tunnel assembly with the airfoil and balance installed |
| `Wind Tunnel w Ahmed Body.SLDASM` | Same assembly with the Ahmed body |
| `Wind Tunnel Drawing.SLDDRW` | Dimensioned general-arrangement drawing |
| `Tunnel Sections/` | Settling chamber, contraction cone, test section, diffuser, platform (`.SLDPRT`) |
| `2D CAD for Laser Cutting/` | Plywood panels, square flanges (settling chamber + diffuser) and the acrylic test-section window, each as `.DXF` (ready to cut) plus the source `.SLDPRT` |
| `Models, Lever, Smoke Rake/` | NACA 4418 model (with internal tap channels), `NACA 4418 coordinates.txt`, Pitot stand, smoke rake, manual tap selector |
| `Models, Lever, Smoke Rake/Ahmed Body v2/` | Ahmed body (the tested version) and its side cover |
| `Models, Lever, Smoke Rake/Load Cell Lever/` | Dual-lever force balance: `Lever system 2.SLDASM` and all its parts (drag lever/stand, lift lever, load-cell supports, pins, base) |
| `(Obsolete) Rotating Selector for Pressure Taps/` | Stepper-driven tap selector. It was abandoned, and taps were switched manually. |

Files marked `(Obsolete)` / `(obsolete)` (the first Ahmed body, the NACA 0012 model and the rotating selector) were not used for the final results. They are kept for reference only.

All models and levers were printed in PLA on a Bambu Lab A1. Print files (STL/3MF) are not included, so export them from the `.SLDPRT` files.

### `[CFD] Wind Tunnel/`

Steady RANS, k-ω SST, energy on, velocity inlet (17.5 m/s NACA / 16 m/s Ahmed), 0 Pa gauge pressure outlet, no-slip walls. The domain is the 340 mm test section, meshed with 15–18 prism layers (y⁺ ≈ 1.7).

| Path | Contents |
|---|---|
| `CFD WITH Stand/NACA4418 @ {-5, 0, +5, +10} deg AoA/` | Airfoil **with** its support stand (the cases used for validation) |
| `CFD WITH Stand/Ahmed Body/` | Ahmed body with stand |
| `CFD WITH Stand/# Pressure Plots/` | Surface-pressure exports from Fluent (x, y, z, Cp) used by the MATLAB Cp scripts |
| `CFD Without Stand/NACA 4418 AoA={-5, 0, +5, +10, +15}/` | Stand-free airfoil runs (used for the stand-drag comparison) |
| `CFD Without Stand/Ahmed Body/` | Stand-free Ahmed body |

Each case folder holds:

- `*.flprj`: the Fluent project file.
- `*.dsco`: the Fluent Meshing watertight-workflow file (regenerates the mesh).
- `*.out`: report-definition monitor histories (Cl, Cd, Cp vs iteration).
- `CAD Model/`: the simulated geometry as `.STEP` + SolidWorks source.

To rerun a case, open the `.dsco` in Fluent Meshing, regenerate the mesh, switch to the solver, apply the settings above, and iterate. The oscillating cases (stand-free NACA +10°, Ahmed) were averaged, not taken at the last iteration. See the MATLAB scripts below.

### `[Codes] Wind Tunnel/`

**Arduino (Arduino Mega 2560, 9600 baud)**

| Sketch | Purpose |
|---|---|
| `LiftDrag_V2/LiftDrag_V2.ino` | **Main force sketch.** Reads the two load cells (HX711) and the Pitot (MPXV7002DP), runs the two-point calibration (stored in EEPROM), tares, and streams lift, drag and airspeed |
| `LiftDrag_V1/LiftDrag_V1.ino` | First version of the force sketch (superseded by V2) |
| `PressureReadings/PressureReadings.ino` | **Surface-pressure sketch used for all reported Cp data.** Zeroes the MPXV7002DP with the fan off (mean of 100 samples), measures a reference Pitot pressure, then streams the tap pressure (mean of 20 samples per line) as each tap is connected by hand. The reported Cp values are the tap pressure divided by the dynamic pressure at the nominal test speed; the sketch's own printed Cp column (ratio to the start-of-run Pitot reading) was not used |
| `PressureSurvey/PressureSurvey.ino` | Later rewrite of the survey sketch (guided tap-by-tap sequence, 1000-sample averages, CSV row per tap). It was **never used** for the reported data, but is kept as the recommended version for future surveys |

**MATLAB (`# MATLAB Scripts/`)**

| Path | Produces |
|---|---|
| `Wind_Tunnel_Experimental_Coefficients.xlsx` | **All measured data.** Sheets `NACA_Forces`, `NACA_Cp`, `Ahmed_Forces`, `Ahmed_Cp` |
| `[NACA] CFD vs WT Plots/NACA_Force_Plots.m` | Cl, Cd and L/D vs AoA (tunnel vs CFD with/without stand), with the error table |
| `[NACA] CFD vs WT Plots/NACA_Cp_Plots.m` | NACA 4418 Cp distributions, tunnel taps vs CFD |
| `[NACA] CFD vs WT Plots/NACA_CFD_Pressure_Plotter.m` | Quick plot of a single Fluent Cp export |
| `[NACA] CFD vs WT Plots/CFD_Results.xlsx` | CFD force coefficients (with / without stand) |
| `[Ahmed] CFD vs WT Plots/Ahmed_Plots.m` | Ahmed body Cp and Cd, tunnel vs CFD (speed uncertainty ±1.25 m/s for Cp, taken at nominal speed; ±0.5 m/s for the Pitot-measured Cd) |
| `[Ahmed] CFD vs WT Plots/Ahmed_CFD_Oscillation_Handling.m` | Fixed-window averaging of the Ahmed monitor history → `ahmed_cfd_stats.csv` |
| `Misc/NACA AoA=10 CFD Oscillating Data Analysis/AoA10_OscillationAverage.m` | Limit-cycle averaging (4 full cycles) of the stand-free +10° case |
| `Misc/PressureAnalysis.m` | Early pressure-data processing script |

The Fluent Cp exports in the MATLAB folders have a `.crash` extension. They are plain comma-separated text, and the name is just how Fluent saved them.

**Running the scripts:** keep the folder structure as-is. The plot scripts find the workbook by relative path (`..\Wind_Tunnel_Experimental_Coefficients.xlsx`) and their other inputs in their own folder. Run any script from MATLAB, and it writes PNG (600 dpi) and PDF figures into a `figures/` subfolder next to it.

---

## Software needed

| Software | Version used | Needed for |
|---|---|---|
| SolidWorks | 2026 | `.SLDPRT` / `.SLDASM` / `.SLDDRW` (older versions cannot open 2026 files; use the `.STEP` / `.DXF` files instead) |
| Ansys Fluent + Fluent Meshing | 2026 R1 (Student) | `.flprj`, `.dsco`. The Student licence has a mesh-size limit, and the with-stand meshes were built within it |
| MATLAB | R2020b or newer (MATLAB Online works) | Data reduction and plots (uses `readtable`, `tiledlayout`, `exportgraphics`, `islocalmax`; no toolboxes required) |
| Arduino IDE | 2.x | Firmware; board **Arduino Mega 2560** |
| HX711 Arduino library | `HX711` by Bogdan Necula (bogde), via Library Manager | Load-cell amplifier (`EEPROM.h` ships with the IDE) |
| Any DXF viewer / laser-cutter software | – | `2D CAD for Laser Cutting/*.DXF` |
| Excel / LibreOffice Calc | – | Viewing the data workbooks |

## Hardware used

- **Controller:** Arduino Mega 2560.
- **Balance:** 2 × 1 kg bar load cells + 2 × HX711 (10 SPS), 4 × 624ZZ bearings, PLA levers (lift 1 : 4, drag 1 : 4.5).
- **Pressure:** 1 × NXP MPXV7002DP differential sensor (±2 kPa), shared between the Pitot and the taps.
- **Pitot:** APM/ArduPilot Pitot-static probe.
- **Tubing:** 2.5 × 5 mm silicone tubing (~6 m); 1 mm tap holes.
- **Fan:** 14 in, 350 W, 2800 rpm drum fan (2000+ CFM) + AC 220 V 2000 W SCR regulator.
- **Tunnel structure:** 6 mm plywood (laser-cut), 6 mm acrylic, PLA-printed contraction and parts.
- **Flow conditioning:** straw honeycomb (70 mm long), 3 screens; tarpaulin coupling between the diffuser and the fan.

---

## What is not included

| Omitted | Why |
|---|---|
| Fluent case / data / mesh files (`*.cas.h5`, `*.dat.h5`, `*.msh.h5`) | ~80–140 MB each, over 12 GB in total. Regenerate them from the `.dsco` + `.flprj` and the settings above |
| Fluent Meshing caches (`*_workflow_files/`, `FM_*/`), cleanup scripts (`*.bat`) | Machine-specific temporary files |
| Fluent transcripts (`*.trn`) | Console logs, not needed (the `.out` monitor files hold the results) |
| MATLAB autosaves (`*.asv`) | Temporary |
| 3D-print files (STL / 3MF) | Export from the SolidWorks parts if needed |
| `Documents/` (report source, poster, progress slides, photos, datasheets) | Course submission material. The final report is submitted separately |
| OS files (`.DS_Store`, `Icon?`, `desktop.ini`, `~$*`) | Not project files |

---

## Citing

If you use this work, please cite the project report:

> A. M. Syndeed, H. K. Ratul, Mubasshira, B. D. Badhon, *Design, Instrumentation and CFD Validation of a Miniature Open-Circuit Subsonic Wind Tunnel for Low-Reynolds-Number Aerodynamics*, ME 366 Project Report, Dept. of Mechanical Engineering, BUET, 2026. https://github.com/0xSYNDEED/PROJECT-WIND-TUNNEL

## Acknowledgements

Supervised by Dr. Kazi Arafat Rahman, Md Moyeenul Hossain Ratul, Rafiul Haq and Dilshad Jahan Ritu, Department of Mechanical Engineering, BUET.
