# DWiM
DICOM Workflows in MATLAB

## Features

### 3D Volume Processing Pipeline
DWiM provides a complete pipeline for processing DICOM series into analysis-ready 3D volumes:

- **Automatic DICOM Discovery**: Finds and validates DICOM files in directories
- **Intelligent Slice Sorting**: Orders slices using `ImagePositionPatient` for accurate 3D reconstruction
- **Volume Assembly**: Combines 2D slices into consistent 3D volumes
- **Orientation Correction**: Standardizes anatomical orientation (RAS, LPS, LAS)
- **Isotropic Resampling**: Creates uniform voxel spacing for analysis
- **Quality Validation**: Checks volume integrity and provides preprocessing recommendations

### Quick Start

#### Unified Pipeline (Recommended)
```matlab
% DICOM folder to ML-ready volume in one call
config = dwim.preprocessPipeline_config('inputType', 'dicomdir', 'steps', {'assemble', 'orient', 'resample'});
[volume, metadata] = dwim.preprocessPipeline('dicom_folder/', config);
```

#### Direct Volume Processing
```matlab
% Process a DICOM series with full pipeline
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries('dicom_folder/');

% Custom preprocessing options
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries('dicom_folder/', ...
    'TargetOrientation', 'RAS', ...
    'TargetSpacing', 1.0, ...
    'Validate', true);
```

### Examples
See the `examples/` directory for detailed usage examples:
- `01_basic_connection/`: DICOM server connections
- `02_ml_preprocessing/`: 2D image preprocessing for ML
- `03_volume_pipeline/`: Complete 3D volume processing pipeline
- `04_ml_dataset_builder/`: ML dataset preparation with train/val/test splits
- `05_end_to_end_complete/`: **Complete architecture demonstration** (all 5 layers)
- `06_dataset_validation/`: **Dataset validation and integrity checks**
- `QUICK_START_GUIDE.m`: Quick reference for common workflows

**Comprehensive Guides:**
- `docs/DICOM_TO_ML_WORKFLOW.md`: **Complete DICOM to ML workflow tutorial** with best practices

## Installation
Clone the repository and add to MATLAB path:
```matlab
addpath('path/to/DWiM');
```

## Requirements
- MATLAB R2020a or later
- Image Processing Toolbox
- Medical Imaging Toolbox (recommended)
