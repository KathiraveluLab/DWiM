# Example 4: Unified Preprocessing Pipeline

## Purpose
Demonstrate the complete DWiM unified preprocessing pipeline for converting DICOM data into ML-ready volumes with a single function call.

## Overview

The `dwim.preprocessPipeline` function provides a unified interface for all DWiM preprocessing operations, supporting:

- **DICOM directories** → 3D volumes
- **Individual DICOM files** → 2D images
- **Pre-loaded arrays** → processed data
- **Flexible configuration** for different ML workflows

## Key Features

- **Single Function Call**: Complete preprocessing pipeline in one function
- **Multiple Input Types**: DICOM folders, individual files, or loaded arrays
- **Configurable Steps**: Assemble, orient, resample, window, normalize, validate
- **ML-Optimized**: Designed specifically for machine learning workflows
- **Comprehensive Metadata**: Detailed processing information and validation

## Basic Usage

### DICOM Folder to ML-Ready Volume

```matlab
% Configure pipeline
config = struct();
config.inputType = 'dicomdir';
config.steps = {'assemble', 'orient', 'resample', 'validate_volume'};
config.parameters.orient.targetOrientation = 'RAS';
config.parameters.resample.targetSpacing = 1.0;

% Process with single call
[volume, metadata] = dwim.preprocessPipeline('dicom_folder/', config);
```

### Single DICOM Slice Processing

```matlab
% Configure for 2D processing
config = struct();
config.inputType = 'filepath';
config.steps = {'validate', 'window', 'normalize'};
config.parameters.window.preset = 'lung';

% Process single slice
[image, metadata] = dwim.preprocessPipeline('slice.dcm', config);
```

## Configuration Options

### Input Types
- `'dicomdir'`: Directory containing DICOM series
- `'filepath'`: Single DICOM file path
- `'image'`: Pre-loaded 2D image array
- `'volume'`: Pre-loaded 3D volume array

### Processing Steps
- `'assemble'`: Assemble 3D volume from DICOM series
- `'orient'`: Correct anatomical orientation
- `'resample'`: Apply isotropic resampling
- `'window'`: Apply windowing presets (lung, soft tissue, bone)
- `'normalize'`: HU normalization to [0,1] range
- `'validate'`: Quality validation
- `'validate_volume'`: 3D volume validation

### Parameters
```matlab
config.parameters.orient.targetOrientation = 'RAS';  % or 'LPS', 'LAS'
config.parameters.resample.targetSpacing = 1.0;     % mm
config.parameters.window.preset = 'lung';           % or 'soft', 'bone'
config.parameters.normalize.windowCenter = -600;    % HU
config.parameters.normalize.windowWidth = 1500;     % HU
```

## Running the Example

1. Update the `dicomPath` variable in `example_unified_pipeline.m`
2. Run the script in MATLAB/Octave
3. The example demonstrates:
   - Full DICOM-to-volume pipeline
   - Custom ML preprocessing (lung CT)
   - Minimal processing for inspection
   - Single slice processing

## Expected Output

```
DWiM Unified Pipeline Example
=============================

Example 1: DICOM folder → ML-ready volume
DWiM Unified Preprocessing Pipeline
===================================
Input type: dicomdir
Steps: assemble → orient → resample → validate_volume
...
✓ Successfully processed DICOM series!
  Final dimensions: [256 256 150]
  Voxel spacing: [1.00 1.00 1.00] mm
  Orientation: RAS
  Total processing time: 8.45 seconds
  Validation: PASSED
```

## Applications

This unified pipeline is ideal for:

- **Deep Learning Preprocessing**: Consistent preprocessing for training/validation
- **Medical Image Analysis**: Standardized workflows across studies
- **Research Pipelines**: Reproducible preprocessing steps
- **Clinical Tools**: Fast processing of patient data
- **Batch Processing**: Automated processing of multiple studies

## Performance Notes

- Processing time depends on volume size and steps enabled
- GPU acceleration available for resampling (when supported)
- Memory usage scales with volume dimensions
- Validation adds ~10-20% processing time but ensures quality