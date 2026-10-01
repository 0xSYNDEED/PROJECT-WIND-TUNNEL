# Miniature Open-Circuit Subsonic Wind Tunnel

ME 366 (Electromechanical System Design) project, Group A13, Department of Mechanical Engineering, BUET, 2026.

A low-cost wind tunnel with a 160 × 160 × 340 mm test section (16–18 m/s, Re ≈ 1.2 × 10⁵), a dual-lever load-cell balance, surface-pressure taps and a Pitot probe. It was validated against Ansys Fluent simulations of its own test section, with and without the model's support stand. Test models: NACA 4418 airfoil (−5° to +10°) and a 25° Ahmed body.

**Read the report first:** [`[Docs] Wind Tunnel/Wind Tunnel Report - Group A13.pdf`](<[Docs] Wind Tunnel/Wind Tunnel Report - Group A13.pdf>). The poster is in the same folder.

**Authors:** Ahnaf Masud Syndeed, Hasibul Karim Ratul, Mubasshira, Bivashindhu Datta Badhon

## What's where

| Folder | Contents |
|---|---|
| `[Docs] Wind Tunnel/` | Final report (PDF) and poster |
| `[CAD] Wind Tunnel/` | SolidWorks parts and assemblies of the tunnel, balance, models, Pitot stand and smoke rake; DXF files for laser cutting. Parts marked *(Obsolete)* were not used in the final tests |
| `[CFD] Wind Tunnel/` | For every case, with and without the stand: Ansys Discovery geometry prepared for meshing, with named selections (`.dsco`); Fluent project files (`.flprj`); monitor histories (`.out`); simulated geometry (`.STEP`); and Cp exports |
| `[Codes] Wind Tunnel/` | Arduino sketches and MATLAB scripts (below) |

**Arduino** (Mega 2560):

- `LiftDrag_V2` reads the force balance and the Pitot probe.
- `PressureReadings` was used for all reported pressure data.
- `PressureSurvey` is a later, unused rewrite, kept for future surveys.
- `LiftDrag_V1` is the superseded first version of the force sketch.

**MATLAB** (`# MATLAB Scripts/`): all measured data are in `Wind_Tunnel_Experimental_Coefficients.xlsx`. The `[NACA]` and `[Ahmed]` folders hold the scripts that produce the report's comparison plots. `Misc/` holds the averaging script for the oscillating CFD case. Keep the folder structure as it is, because the scripts find their inputs by relative path.

## Software

- **SolidWorks 2026** for the CAD. Use the STEP/DXF files with older versions.
- **Ansys Student 2026 R1**: Discovery for geometry preparation (`.dsco`), and Fluent in Meshing mode (mesh) and Solution mode (solver).
- **MATLAB R2020b or newer.** MATLAB Online works, and no toolboxes are needed.
- **Arduino IDE 2.x** with the `HX711` library by bogde.

## Not included

- **Fluent mesh files** (`.msh.h5`, about 100 MB each), which hold both the mesh and the meshing workflow and open in Fluent's Meshing mode. Most of them exceed GitHub's 100 MB file limit.
- **Fluent case and data files** (`.cas.h5`, `.dat.h5`). With the mesh files, they total about 12 GB.
- **Report source:** only the report PDF is included.
- **3D-print files (STL/3MF):** export them from the SolidWorks parts.
- **Temporary and log files.**

To regenerate the mesh, case and data files, import the `.dsco` geometry in Fluent's Meshing mode and use the settings in the report (Table 2.3).

## Citation

A. M. Syndeed, H. K. Ratul, Mubasshira, B. D. Badhon, *Design, Instrumentation and CFD Validation of a Miniature Open-Circuit Subsonic Wind Tunnel for Low-Reynolds-Number Aerodynamics*, ME 366 Project Report, BUET, 2026.

Supervised by Dr. Kazi Arafat Rahman, Md Moyeenul Hossain Ratul, Rafiul Haq and Dilshad Jahan Ritu.
