# ML Preprocessing Roadmap & Design Decisions

> **Document Purpose**: This document outlines the architectural vision, design principles, and implementation roadmap for the ML preprocessing components of DWiM (DICOM Workflows in MATLAB).

---

## 1. Project Overview

**DWiM** is a MATLAB-based toolkit designed to bridge the gap between raw medical imaging data (DICOM/NIfTI) and ML-ready datasets. The core philosophy is **"Validate Early, Fail Fast"** — ensuring data quality and consistency before expensive model training begins.

### Target Users
- Medical imaging researchers
- ML engineers working with clinical data
- Radiologists building automated analysis pipelines

### Key Differentiators
- **Data-First Validation**: Standalone dataset auditing before training
- **Configuration-Driven**: Reproducible pipelines via structured config files
- **Multi-Format Support**: Unified interface for `.mat`, `.nii`, `.h5` formats

---

## 2. Architectural Decisions

### 2.1 MATLAB Package Structure (`+dwim`)

**Rationale**: MATLAB's package system (`+` prefix) provides namespace isolation and logical grouping.

```
+dwim/
├── +ml/                    # ML-specific utilities
│   ├── DatasetValidator.m
│   └── DatasetBuilder.m (future)
├── +preprocess3d/          # 3D volume operations
│   ├── resampleVolume.m
│   ├── assembleVolume.m
│   └── correctOrientation.m
└── +utils/                 # Shared utilities
    └── connectToOrthanc.m
```

**Benefits**:
- Prevents function name collisions
- Clear intent through module names (`dwim.ml.DatasetValidator` vs generic `DatasetValidator`)
- Enables selective imports

### 2.2 Object-Oriented Design with `handle` Classes

**Example**: `DatasetValidator` uses MATLAB's `handle` class for state management.

```matlab
classdef DatasetValidator < handle
    properties
        DatasetPath
        ValidationResults  % Persistent across method calls
        Verbose = true
    end
end
```

**Key Advantages**:
1. **Memory Efficiency**: Pass-by-reference semantics avoid data duplication
2. **State Encapsulation**: Validation results persist across workflow steps
3. **Extensibility**: Subclassing enables domain-specific validators (e.g., `LungCTValidator`)

### 2.3 Configuration-Driven Pipelines

**Philosophy**: Separate *what to do* (code) from *how to configure* (parameters).

**Implementation**: `preprocessPipeline_config.m` provides reusable templates:
```matlab
config_3d_volume = struct(...
    'steps', {{'orient', 'resample', 'validate_volume'}}, ...
    'parameters', struct(...
        'orient', struct('targetOrientation', 'RAS'), ...
        'resample', struct('targetSpacing', 1.0) ...
    ) ...
);
```

**Benefits**:
- **Reproducibility**: Share configs as `.mat` or JSON files
- **A/B Testing**: Compare normalization strategies by swapping configs
- **Version Control**: Track parameter evolution alongside code

### 2.4 Lazy Loading & Memory Optimization

**Challenge**: Medical datasets can exceed RAM (e.g., 512³ float32 = 512 MB per volume).

**Strategies Implemented**:

1. **Selective Variable Loading**:
    ```matlab
    % Load only 'labels', not entire file
    data = load(filePath, 'labels');
    ```
2. **Metadata-First Inspection**: Use `whos('-file', path)` to check dimensions before loading:
    ```matlab
    % Get info about variables in a MAT-file without loading it
    info = whos('-file', filePath);
    % Example: Check if a variable is too large before loading
    idx = strcmp({info.name}, 'largeVolume');
    if any(idx) && info(idx).bytes > availableMemory
         error('Not enough memory to load largeVolume.');
    end
    ```
3. **Pre-Allocation**: Pre-size arrays in contamination checks to avoid repeated memory reallocation

**Future**: HDF5 memory-mapped arrays for out-of-core processing.

---

## 3. Current Implementation Status

### ✅ Phase 1: Dataset Integrity (Completed - Jan 2026)

**Component**: `DatasetValidator` class

**Capabilities**:
- **File Integrity**: Detects corrupt/missing files across splits
- **Shape Consistency**: Enforces uniform tensor dimensions (e.g., `128×128×64`)
- **Cross-Split Contamination**: Identifies patient ID leakage between Train/Val/Test
- **Label Distribution**: Analyzes class balance with configurable imbalance thresholds
- **Normalization Verification**: Validates MinMax/Z-Score normalization ranges
- **Disk Usage Estimation**: Reports storage in GiB (binary prefixes)

**Design Highlights**:
- **Verbosity Control**: `Verbose` property enables silent execution in batch scripts
- **Format Agnostic**: Handles MAT, NIfTI, HDF5 via polymorphic `loadDatasetFile()` helper
- **Robust Error Handling**: `onCleanup` ensures file handles close even on crashes

**Example Usage**:
```matlab
validator = dwim.ml.DatasetValidator('path/to/dataset');
validator.Verbose = false;  % Silent mode for automation
report = validator.runAllChecks();

if ~report.contamination.passed
    error('Data leakage detected! Check report.contamination.duplicates');
end
```

### 🚧 Phase 2: 3D Preprocessing Primitives (In Progress)

**Module**: `+dwim/+preprocess3d/`

**Implemented Functions**:
1. **`resampleVolume.m`**:
   - Isotropic resampling to target spacing (e.g., `1.0mm³`)
   - Supports `linear`, `cubic`, `nearest` interpolation
   - GPU acceleration (when available)
   - Automatic target spacing selection (minimum of current spacings)

2. **`assembleVolume.m`**:
   - Constructs 3D volumes from DICOM series
   - Slice sorting via `SliceLocation` or `InstanceNumber`
   - Gap detection for missing slices
   - Metadata extraction (voxel spacing, orientation)

3. **`correctOrientation.m`**:
   - Standardizes anatomical orientation (RAS/LPS/LAS)
   - Parses `ImageOrientationPatient` DICOM tags
   - Computes transformation matrices for rotation

**Pending**:
- Integration of orientation correction into `assembleVolume`
- Chunk-based processing for volumes >16GB
- Oblique slice handling

---

## 4. Design Patterns & Best Practices

### 4.1 "Data-First" Validation Philosophy

**Traditional Workflow** (Problematic):
```
Load Data → Train Model → Discover Issues → Restart
```

**DWiM Workflow** (Proactive):
```
Validate Dataset → Load Data → Train Model
```

**Implementation**:
- Standalone `DatasetValidator` runs *before* any training code
- Generates human-readable reports (`generateReport()`) for quick debugging
- Configurable thresholds (e.g., `ImbalanceWarningThreshold = 10`) adapt to domain needs

### 4.2 Multi-Format Abstraction

**Problem**: ML workflows use mixed formats (`.mat` for MATLAB, `.h5` for Python interop, `.nii` for neuroimaging).


**Solution**: Unified `loadDatasetFile()` private method using name-value pairs for format-specific arguments:
```matlab
function data = loadDatasetFile(obj, filePath, varargin)
    % Convert name-value pairs to a struct for easy access
    opts = struct(varargin{:});
    switch obj.Format
        case 'mat'
            tmp = load(filePath, opts.VarName);
            data = tmp.(opts.VarName);
        case 'hdf5'
            data = h5read(filePath, opts.H5Path);
        case 'nifti'
            data = niftiread(filePath);
    end
end
```

**Benefits**:
- Single call site (`loadDatasetFile`) for all format logic
- Easy to extend (e.g., add DICOM support)
- Format-specific edge cases isolated

### 4.3 Performance: Pre-Allocation Over Growth

**Anti-Pattern** (Slow):
```matlab
for i = 1:N
    ids = [ids, newID{i}];  % Grows array N times
end
```

**Best Practice** (Fast):
```matlab
ids_cell = cell(1, N);  % Pre-allocate
for i = 1:N
    ids_cell{i} = extractIDs(file(i));
end
ids = [ids_cell{:}];  % Single concatenation
```

**Applied In**: `checkCrossSplitContamination()` method (commit `0646768`).

---

## 5. Roadmap

### Q1 2026: Unified Pipeline Builder ✅ (Completed)

**Goal**: Chain preprocessing steps via config files.

**Delivered**: `preprocessPipeline_config.m` templates for:
- 2D slice processing
- 3D volume assembly + resampling
- Full DICOM → ML-ready pipeline

**Example**:
```matlab
config = config_full_pipeline;  % From config file
[volume, metadata] = dwim.preprocessPipeline('dicom_dir/', config);
```

### Q2 2026: Deep Learning Integration (Planned)

**Goal**: Native MATLAB Deep Learning Toolbox integration.

**Planned Features**:
1. **Custom `ImageDatastore`**:
   ```matlab
   ds = dwim.ml.DWiMDatastore('dataset/', config);
   net = trainNetwork(ds, layers, options);
   ```
2. **On-The-Fly Augmentation**:
   - Random rotation/flips during training
   - Elastic deformations for medical images
3. **Parallel Data Loading**: Multi-worker `parfor` support

### Q3 2026: Performance & Scalability (Planned)

**Goal**: Handle terabyte-scale datasets.

**Optimization Targets**:
1. **Parallel Validation**: `parfor` loops in `DatasetValidator` methods
2. **HDF5 Chunking**: Memory-mapped I/O for large `.h5` files
3. **GPU Resampling**: Extend `resampleVolume` GPU mode to full pipeline

**Expected Gains**:
- 10x speedup for multi-core validation
- Process 1TB datasets on 32GB RAM machines

### Q4 2026: Advanced Validation (Research)

**Experimental Features**:
1. **Anomaly Detection**: Flag statistical outliers in intensities
2. **Anatomical Consistency**: Verify organ positions (e.g., liver should be in upper abdomen)
3. **Inter-Rater Agreement**: Validate multi-annotator segmentation masks

---

## 6. Technical Debt & Known Limitations

### 6.1 Incomplete Orientation Support
- **Status**: `correctOrientation.m` implemented but not integrated into `assembleVolume`
- **Impact**: Users must manually call orientation correction
- **Fix**: Auto-detect orientation during assembly (Q2 2026)

### 6.2 No Automated Testing
- **Status**: Manual test scripts exist (`test_resampleVolume.m`)
- **Impact**: Refactoring risk, regression potential
- **Fix**: Implement MATLAB Unit Testing Framework (Q2 2026)

### 6.3 Limited Documentation
- **Status**: Code comments exist, but no user guide
- **Impact**: Steep learning curve for new users
- **Fix**: Sphinx/MkDocs documentation site (Q3 2026)

---

## 7. Lessons Learned

### 7.1 MATLAB `load()` Behavior
**Initial Misunderstanding**: Code reviewer flagged `data = load(file)` as "polluting workspace."
**Correction**: With output assignment, `load()` returns a struct — safe and idiomatic.
**Takeaway**: Automated review tools can misinterpret MATLAB semantics.

### 7.2 Binary vs Decimal Units
**Issue**: Initially used `GB` (10⁹ bytes) for disk usage.
**Fix**: Switched to `GiB` (1024³ bytes) to match OS/filesystem conventions.
**Takeaway**: Precision matters in scientific computing.

### 7.3 Performance of Array Growth
**Discovery**: Contamination check was slow (2 min for 1000 files).
**Root Cause**: Repeated array concatenation (`ids = [ids, new]`).
**Solution**: Pre-allocate cell array → 20x speedup.
**Takeaway**: Profile before optimizing (MATLAB Profiler is gold).

---

## 8. Contributing Guidelines

### Adding New Validation Checks
1. Add method to `DatasetValidator` class
2. Return struct with `.passed` field and `.warnings`/`.issues` arrays
3. Call from `runAllChecks()` and add to `ValidationResults`
4. Update `generateReport()` to display new results

### Code Style
- **Functions**: `camelCase` (e.g., `resampleVolume`)
- **Classes**: `PascalCase` (e.g., `DatasetValidator`)
- **Properties**: `PascalCase` (e.g., `Verbose`)
- **Comments**: Use MATLAB doc format (`% FUNCTIONNAME Description`)

### Testing Protocol
1. Create synthetic test data
2. Run manual test scripts (`test_*.m`)
3. Verify edge cases (empty datasets, 1-slice volumes, etc.)

---

## 9. References

### DICOM Standards
- [DICOM PS3.3: Image Orientation](https://dicom.nema.org/medical/dicom/current/output/chtml/part03/sect_C.7.6.2.html)
- [RAS/LPS Coordinate Systems](https://nipy.org/nibabel/coordinate_systems.html)

### MATLAB Documentation
- [Package Folders](https://www.mathworks.com/help/matlab/matlab_oop/scoping-classes-with-packages.html)
- [Handle Classes](https://www.mathworks.com/help/matlab/matlab_oop/comparing-handle-and-value-classes.html)
- [HDF5 File Access](https://www.mathworks.com/help/matlab/hdf5-files.html)

### Related Projects
- [MONAI (Python)](https://monai.io/) - Medical imaging ML framework
- [SimpleITK](https://simpleitk.org/) - Cross-language medical image processing

---

## 10. Conclusion

The ML preprocessing module of DWiM represents a **production-grade** approach to medical imaging workflows:
- **Validated**: Comprehensive checks prevent silent data issues
- **Configurable**: Parameter files enable reproducibility
- **Scalable**: Optimized for large datasets

**Current State**: Phase 1 (Validation) complete, Phase 2 (3D Processing) in progress.

**Next Milestone**: Q2 2026 — Deep Learning Toolbox integration.

**Long-Term Vision**: Industry-standard MATLAB toolkit for medical ML, comparable to Python's MONAI.

---

*Document Version*: 1.0  
*Last Updated*: January 30, 2026  
*Author*: DWiM Development Team  
*Contact*: [Repository Issues](https://github.com/KathiraveluLab/DWiM/issues)
