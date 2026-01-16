# End-to-End DWiM Pipeline Example

## Overview

This comprehensive example demonstrates the complete **DWiM (DICOM Workflows in MATLAB)** pipeline from raw DICOM files to ML-ready datasets. It showcases all five layers of the architecture working together in a unified workflow.

## Architecture Layers

### Layer 1: Acquisition
**Purpose:** Discover and validate DICOM files

- Discover DICOM files in various formats (.dcm, .dicom, extensionless)
- Extract metadata (PatientID, Modality, Spacing, Orientation)
- Validate DICOM integrity
- Group slices into series

**Functions:**
- dwim.io.* (conceptual)
- dwim.dicom.* (conceptual)
- dicominfo() (MATLAB built-in)

---

### Layer 2: Preprocessing (2D)
**Purpose:** Make individual slices ML-safe

- Normalize Hounsfield Units (HU)
- Apply windowing presets (lung, bone, brain, etc.)
- Validate image quality
- Detect and flag problematic slices

**Functions:**
- dwim.preprocess.normalizeHU(image, windowCenter, windowWidth)
- dwim.preprocess.applyWindowPreset(image, preset)
- dwim.preprocess.validateImageForML(image)

**Key Properties:**
- Operates on 2D images
- Stateless and deterministic
- Reusable for both 2D and 3D workflows

---

### Layer 3: Volume Construction (3D)
**Purpose:** Convert DICOM slices to coherent 3D volume

**Sub-steps:**

1. **Slice Ordering**
   - Extract `ImagePositionPatient` from each DICOM
   - Sort by Z-coordinate
   - Validate consistent spacing

2. **Volume Assembly**
   - Stack sorted slices into 3D array
   - Verify dimensions: [rows, cols, slices]
   - Extract voxel spacing

3. **Orientation Correction**
   - Detect current orientation (LPS, RAS, LAS, etc.)
   - Reorient to standard frame (typically RAS)
   - Preserve spatial relationships

4. **Isotropic Resampling**
   - Detect original voxel spacing
   - Resample to uniform spacing (e.g., 1.0 mm³)
   - Use appropriate interpolation

5. **Volume Validation**
   - Check 3D integrity
   - Verify orientation transformation
   - Ensure ML readiness

**Functions:**
- dwim.preprocess3d.buildVolumeFromSeries(dicomDir)
- dwim.preprocess3d.assembleVolume()
- dwim.preprocess3d.correctOrientation(volume, orientation)
- dwim.preprocess3d.resampleVolume(volume, spacing)
- dwim.preprocess3d.validateVolumeForML(volume)

---

### Layer 4: Pipeline Orchestration
**Purpose:** Provide unified, configuration-driven API

Single entry point for the entire pipeline:

```matlab
config = struct();
config.inputType = 'dicomdir';
config.steps = {'assemble', 'orient', 'resample', 'validate_volume'};
config.parameters.orient.targetOrientation = 'RAS';
config.parameters.resample.targetSpacing = 1.0;
config.validation.enabled = true;
config.verbose = true;

[volume, metadata] = dwim.preprocessPipeline(dicomPath, config);
```

**Benefits:**
- Hides internal complexity
- Provides consistent interface
- Enables configuration reuse
- Tracks complete metadata

**Functions:**
- `dwim.preprocessPipeline(input, config)`
- `dwim.preprocessPipeline_config()` (template generation)

---

### Layer 5: ML Preparation (Future)
**Purpose:** Convert volumes to ML-ready datasets

**Planned Responsibilities:**

1. **Batch Organization**
   - Organize volumes into train/validation/test sets
   - Create standardized directory structure
   - Generate manifests

2. **Volume Resizing**
   - Resize to fixed ML input dimensions
   - Options: center crop, padding, interpolation
   - Preserve spatial information

3. **Intensity Normalization**
   - Standardize intensity distributions
   - Z-score or per-volume normalization
   - Handle outliers

4. **Metadata Linkage**
   - Create JSON/CSV metadata sidecars
   - Link to original DICOM
   - Track provenance
   - Store all preprocessing parameters

5. **Integrity Checks**
   - Verify all volumes
   - Check consistency
   - Detect corrupted files
   - Generate QA reports

**Planned Dataset Structure:**
```
dataset/
├── train/
│   ├── volume_001.nii.gz
│   ├── volume_001.json (metadata)
│   └── ...
├── validation/
│   └── ...
├── test/
│   └── ...
├── manifest.csv
└── dataset_stats.json
```

**Planned Functions:**
- `dwim.ml.buildDataset(volumes, config)`
- `dwim.ml.validateDataset(datasetDir)`
- `dwim.ml.generateMetadataJson(volume, metadata)`
- `dwim.ml.createManifest(datasetDir)`

---

## Running the Example

### Prerequisites
```matlab
% MATLAB R2020a or later
% Image Processing Toolbox
% Medical Imaging Toolbox (recommended)
% DWiM toolbox added to path
addpath(genpath('/path/to/DWiM'));
```

### Basic Usage
```matlab
% Run the complete example
cd examples/05_end_to_end_complete/
example_end_to_end
```

### With Real DICOM Data
```matlab
% Edit the script to set your DICOM path
dicomSourcePath = '/path/to/your/dicom/series/';

% Run the example
example_end_to_end
```

### Output
The script generates:
- Pipeline configuration (saved as text file)
- Dataset directory structure (train/validation/test)
- Metadata template (JSON format)
- Pipeline metrics (timing and status)
- Execution logs

---

## Data Flow Visualization

```
DICOM Files
    ↓
[Layer 1: Acquisition]
  • Discover files
  • Extract metadata
  • Validate structure
    ↓
[Layer 2: Preprocessing (2D)]
  • Normalize HU values
  • Apply windowing
  • Validate slices
    ↓
[Layer 3: Volume Construction]
  • Order slices
  • Assemble volume
  • Correct orientation
  • Resample isotropically
  • Validate volume
    ↓
[Layer 4: Pipeline Orchestration]
  • Unify all steps
  • Configuration-driven
  • Track metadata
    ↓
[Layer 5: ML Preparation]
  • Organize batches
  • Resize volumes
  • Link metadata
  • Generate dataset
    ↓
ML-Ready Dataset
```

---

## Key Concepts

### Configuration-Driven Design
The entire pipeline is controlled by a single configuration structure:

```matlab
config = struct();
config.inputType = 'dicomdir';              % Input format
config.outputType = 'volume';               % Output format
config.steps = {'orient', 'resample'};      % Processing steps
config.parameters.orient.targetOrientation = 'RAS';
config.validation.enabled = true;
config.verbose = true;
```

### Metadata Tracking
All operations track metadata:
- Processing steps applied
- Transformation parameters
- Timing information
- Quality validation results
- Spatial referencing

### Modular Architecture
Each layer is:
- Independent and replaceable
- Single responsibility
- Testable in isolation
- Composable into workflows

### Data Consistency
- Linear data flow (no hidden coupling)
- No state mutations between steps
- Deterministic processing
- Full provenance tracking

---

## Advanced Usage

### Custom Processing Pipeline
```matlab
% Example: High-resolution lung preprocessing
config = struct();
config.inputType = 'dicomdir';
config.steps = {'assemble', 'orient', 'resample', 'normalize', 'validate_volume'};
config.parameters.orient.targetOrientation = 'RAS';
config.parameters.resample.targetSpacing = 0.5;  % High resolution
config.parameters.normalize.windowCenter = -600;
config.parameters.normalize.windowWidth = 1500;
config.validation.enabled = true;
config.verbose = true;

[volume, metadata] = dwim.preprocessPipeline(dicomPath, config);
```

### Batch Processing Multiple Series
```matlab
% Process multiple DICOM directories
dicomDirs = {...
    '/path/to/patient001/',
    '/path/to/patient002/',
    '/path/to/patient003/'
};

volumes = {};
metadatas = {};

for i = 1:length(dicomDirs)
    [volume, metadata] = dwim.preprocessPipeline(dicomDirs{i}, config);
    volumes{i} = volume;
    metadatas{i} = metadata;
end

% Later: Layer 5 would organize these into dataset
```

---

## Validation and Quality Assurance

### Layer-Specific Validation

| Layer | Validation |
|-------|------------|
| Acquisition | DICOM integrity, metadata completeness |
| Preprocessing (2D) | Image quality, value ranges, consistency |
| Volume Construction | 3D geometry, orientation, spacing uniformity |
| Orchestration | Configuration validity, step composition |
| ML Preparation | Dataset consistency, metadata alignment, completeness |

### Quality Checks
- Shape consistency across volumes
- Missing or corrupted files
- Metadata alignment
- Intensity distribution
- Spatial coherence

---

## Troubleshooting

### Common Issues

**"File not found: dicomDir"**
- Verify the DICOM directory path exists
- Check path separators match your OS

**"No valid DICOM data found"**
- Ensure directory contains actual DICOM files
- Check file permissions

**"Non-CT Modality"**
- Pipeline currently expects CT data
- Can be extended for MRI, PET, etc.

**"Empty volume after assembly"**
- Check if slices are properly sorted
- Verify consistent spacing between slices

### Debugging
```matlab
% Enable verbose output
config.verbose = true;

% Check metadata after each layer
[volume, metadata] = dwim.preprocessPipeline(dicomPath, config);
disp(metadata);  % View all processing information
```

---

## Next Steps

1. **Implement Layer 5:** Complete the ML Preparation layer with:
   - `dwim.ml.buildDataset()`
   - `dwim.ml.validateDataset()`
   - Metadata linking functions

2. **Add Support for More Modalities:**
   - MRI (different windowing, orientation)
   - PET
   - Ultrasound

3. **Extend Validation:**
   - Statistical quality metrics
   - Outlier detection
   - Anomaly flagging

4. **Performance Optimization:**
   - GPU acceleration for resampling
   - Parallel batch processing
   - Memory-efficient streaming

5. **Documentation:**
   - API reference
   - Troubleshooting guide
   - Scientific validation results

---

## References

- **Project:** https://github.com/KathiraveluLab/DWiM
- **Niffler (Python Alternative):** https://github.com/Emory-HITI/Niffler
- **TCIA (Test Data):** https://www.cancerimagingarchive.net/
- **Orthanc (PACS Server):** https://www.orthanc-server.com/

---

## Support

For questions, issues, or contributions:
- **GitHub Issues:** https://github.com/KathiraveluLab/DWiM/issues
- **Discussions:** https://github.com/KathiraveluLab/DWiM/discussions
- **Email:** pkathiravelu@alaska.edu

---

**Last Updated:** January 17, 2026  
**DWiM Version:** 1.0 (Research Phase)
