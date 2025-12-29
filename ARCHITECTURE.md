# DWiM Architecture: Preprocessing → Volume → ML Flow

## Overview
DWiM provides a complete pipeline for processing DICOM medical imaging data into machine learning-ready 3D volumes. This document outlines the data flow and architectural components.

## Architecture Diagram

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DICOM Input   │ -> │  Preprocessing   │ -> │  Volume Stage   │ -> │     ML Ready    │
│                 │    │                  │    │                 │    │                 │
│ • File Discovery│    │ • Validation     │    │ • Assembly      │    │ • Training Data │
│ • Metadata Ext. │    │ • Windowing      │    │ • Orientation   │    │ • Inference     │
│ • Series Group  │    │ • Normalization  │    │ • Resampling    │    │ • Analysis      │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         ▼                       ▼                       ▼                       ▼
    Raw Files              Quality Checks           3D Volumes            ML Models
```

## Data Flow: DICOM → Volume → ML

```
DICOM Series → Preprocessing → 3D Volume → ML Pipeline
     ↓              ↓             ↓          ↓
  Raw Files    Validation    Assembly   Training
                    ↓             ↓          ↓
              Correction    Resampling  Inference
                    ↓             ↓
               Quality      Orientation
               Checks        Correction
```

## Detailed Workflow

### 1. DICOM Input Stage
**Input:** Directory containing DICOM series files
**Components:**
- File discovery (`.dcm`, `.dicom`, extensionless)
- Metadata extraction (`dicominfo`)
- Series validation and grouping

### 2. Preprocessing Stage
**Components:**
- **Validation:** `validateImageForML()` - 2D slice quality checks
- **Windowing:** `applyWindowPreset()` - HU windowing for CT
- **Normalization:** `normalizeHU()` - Value scaling

### 3. Volume Assembly Stage
**Components:**
- **Sorting:** Slice ordering by `ImagePositionPatient`
- **Assembly:** `assembleVolume()` - 3D reconstruction
- **Validation:** `validateVolumeForML()` - 3D volume quality checks

### 4. Volume Processing Stage
**Components:**
- **Orientation:** `correctOrientation()` - Anatomical standardization
- **Resampling:** `resampleVolume()` - Isotropic voxel spacing

### 5. ML Integration Stage
**Output:** Ready-to-use 3D volumes for:
- Deep learning model training
- Computer vision pipelines
- Medical image analysis workflows

## Key Functions

### High-Level API
- `buildVolumeFromSeries()` - Complete pipeline in one function

### Modular Components
- `assembleVolume()` - DICOM to 3D volume
- `correctOrientation()` - Anatomical reorientation
- `resampleVolume()` - Isotropic resampling
- `validateVolumeForML()` - Quality assurance

### Utilities
- `connectToOrthanc()` - PACS integration
- `extractMetadata()` - DICOM metadata processing
- `applyWindowPreset()` - CT windowing
- `normalizeHU()` - Value normalization

## Architecture Principles

### Modularity
Each processing step is a separate function, allowing flexible pipeline configuration.

### Error Handling
Comprehensive validation at each stage with informative error messages.

### Performance
GPU acceleration support where available, memory-efficient processing.

### Extensibility
Clean APIs for adding new preprocessing steps or ML integrations.

## Data Structures

### Volume Representation
- MATLAB arrays (double/single/int16)
- 3D matrices [rows, cols, slices]
- Voxel spacing metadata [x,y,z] in mm

### Metadata Structure
```matlab
metadata = struct(...
    'sourcePath', '...',           % Input directory
    'parameters', params,          % Processing settings
    'volumeInfo', volumeInfo,      % Dimensions, data type
    'orientationCorrection', orientInfo,  % Orientation changes
    'resampling', resampleInfo,    % Spacing changes
    'validation', validationInfo,  % Quality checks
    'totalTime', processingTime    % Performance metrics
);
```

## Quality Assurance

### Validation Points
1. **File Level:** DICOM integrity
2. **Series Level:** Slice consistency
3. **Volume Level:** 3D structure validation
4. **ML Level:** Training readiness checks

### Error Recovery
- Graceful handling of corrupted files
- Automatic fallback strategies
- Detailed logging for troubleshooting

## Integration Examples

### Basic Usage
```matlab
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries('dicom_folder/');
```

### Custom Pipeline
```matlab
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries('dicom_folder/', ...
    'TargetOrientation', 'RAS', ...
    'TargetSpacing', 1.0, ...
    'Validate', true);
```

### Modular Approach
```matlab
% Step-by-step processing
[volume, info] = dwim.preprocess3d.assembleVolume('dicom_folder/');
volume = dwim.preprocess3d.correctOrientation(volume, info);
[volume, ~] = dwim.preprocess3d.resampleVolume(volume);
```

## Performance Considerations

### Memory Management
- Streaming processing for large datasets
- Configurable memory limits
- GPU acceleration options

### Speed Optimizations
- Vectorized MATLAB operations
- Parallel processing where applicable
- Caching for repeated operations

## Future Extensions

### Planned Features
- Multi-modal image fusion
- Advanced artifact correction
- Automated quality assessment
- Cloud processing integration

### API Expansion
- Batch processing capabilities
- Real-time processing pipelines
- Web service interfaces