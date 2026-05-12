# Volume Pipeline Example

This example demonstrates the complete 3D volume processing pipeline using `buildVolumeFromSeries`.

## Overview

The `dwim.preprocess3d.buildVolumeFromSeries` function provides an end-to-end solution for processing DICOM series into ready-to-use 3D volumes for medical imaging applications.

## Features Demonstrated

- **Automatic DICOM Discovery**: Finds and validates DICOM files in a directory
- **Slice Sorting**: Properly orders slices using `ImagePositionPatient`
- **Volume Assembly**: Combines 2D slices into a 3D volume
- **Orientation Correction**: Standardizes anatomical orientation (RAS, LPS, LAS)
- **Isotropic Resampling**: Creates consistent voxel spacing
- **Validation**: Checks volume quality and provides recommendations

## Usage

```matlab
% Basic usage - all preprocessing steps
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries('dicom_folder/');

% Custom settings
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries('dicom_folder/', ...
    'TargetOrientation', 'LPS', ...
    'TargetSpacing', 1.0, ...
    'Validate', true);
```

## Parameters

- `CorrectOrientation`: Apply orientation correction (default: true)
- `TargetOrientation`: Target anatomical orientation ('RAS', 'LPS', 'LAS')
- `Resample`: Apply isotropic resampling (default: true)
- `TargetSpacing`: Target voxel spacing in mm (default: auto)
- `Validate`: Run quality validation (default: true)
- `Verbose`: Display progress information (default: true)

## Outputs

- `volume`: Processed 3D volume array
- `spacing`: Final voxel spacing [x,y,z] in mm
- `metadata`: Comprehensive processing information

## Running the Example

1. Place DICOM files in a directory
2. Update the `dicomPath` variable in `example_volume_pipeline.m`
3. Run the script in MATLAB

## Expected Output

```
DWiM Volume Builder
==================
Processing DICOM series: path/to/dicom/
Options: Orientation=1, Resample=1, Validate=1
Discovering DICOM files...
Found 150 potential DICOM files
Successfully loaded metadata from 150 DICOM files
Sorting slices by position...
Slices sorted from -75.00 to 75.00 mm
Assembling volume from 150 slices...
Applying orientation correction...
Applying isotropic resampling...
Running final validation...
Volume building completed: [256 256 150] at [1.00 1.00 1.00] mm
Total processing time: 12.34 seconds
==================
```

## Applications

This pipeline is suitable for:
- Medical image analysis
- Deep learning preprocessing
- 3D visualization
- Multi-modal image registration
- Research workflows