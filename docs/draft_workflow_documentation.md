# DWiM Workflow Documentation (Draft)

## Introduction

DWiM (DICOM Workflows in MATLAB) provides a comprehensive framework for processing medical imaging data from DICOM format through to machine learning-ready 3D volumes. This document outlines the complete workflow and best practices.

## Quick Start

### One-Line Processing
```matlab
% Process entire DICOM series to ML-ready volume
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries('path/to/dicom/');
```

### Step-by-Step Processing
```matlab
% Alternative: modular approach
dicomPath = 'path/to/dicom/';

% Step 1: Assemble volume
[rawVolume, info] = dwim.preprocess3d.assembleVolume(dicomPath);

% Step 2: Correct orientation
[orientedVolume, ~] = dwim.preprocess3d.correctOrientation(rawVolume, info);

% Step 3: Resample to isotropic
[finalVolume, ~] = dwim.preprocess3d.resampleVolume(orientedVolume);

% Step 4: Validate
[isValid, validation] = dwim.preprocess3d.validateVolumeForML(finalVolume);
```

## Detailed Workflow

### Phase 1: Data Ingestion
**Goal:** Load and organize DICOM data
**Components:**
- File discovery across multiple formats
- Metadata extraction and validation
- Series grouping and sorting

**Key Function:** `buildVolumeFromSeries()` handles this automatically

### Phase 2: Preprocessing
**Goal:** Prepare individual slices for 3D reconstruction
**Components:**
- Image validation (`validateImageForML`)
- Window/level adjustment (`applyWindowPreset`)
- Value normalization (`normalizeHU`)

**When to Use:** Applied per-slice before volume assembly

### Phase 3: Volume Construction
**Goal:** Create consistent 3D volumes
**Components:**
- Slice ordering by anatomical position
- Volume assembly with error handling
- Initial quality validation

**Key Function:** `assembleVolume()`

### Phase 4: Volume Optimization
**Goal:** Standardize volumes for analysis
**Components:**
- Orientation correction (`correctOrientation`)
- Isotropic resampling (`resampleVolume`)
- Final validation (`validateVolumeForML`)

**Key Function:** `buildVolumeFromSeries()` integrates all steps

### Phase 5: ML Integration
**Goal:** Feed processed data into ML pipelines
**Components:**
- Standardized data format
- Metadata preservation
- Quality assurance

## Configuration Options

### buildVolumeFromSeries Parameters

| Parameter           | Default | Description                             |
|---------------------|---------|-----------------------------------------|
| `CorrectOrientation`| `true`  | Apply anatomical orientation correction |
| `TargetOrientation` | `'RAS'` | Target orientation (RAS/LPS/LAS)        |
| `Resample`          | `true`  | Apply isotropic resampling              |
| `TargetSpacing`     | `auto`  | Target voxel spacing in mm              |
| `Validate`          | `true`  | Run quality validation                  |
| `Verbose`           | `true`  | Display progress information            |

### Example Configurations

```matlab
% Minimal processing (assembly only)
[vol, sp, meta] = dwim.preprocess3d.buildVolumeFromSeries(path, ...
    'CorrectOrientation', false, 'Resample', false, 'Validate', false);

% High-quality processing
[vol, sp, meta] = dwim.preprocess3d.buildVolumeFromSeries(path, ...
    'TargetOrientation', 'LPS', 'TargetSpacing', 0.5, 'Validate', true);

% Fast processing for preview
[vol, sp, meta] = dwim.preprocess3d.buildVolumeFromSeries(path, ...
    'Resample', false, 'Verbose', false);
```

## Output Data Structure

### Volume
- **Type:** MATLAB numeric array
- **Dimensions:** `[rows, cols, slices]`
- **Data Type:** Preserves original (typically int16 for CT)
- **Orientation:** RAS anatomical standard (when corrected)

### Spacing
- **Format:** `[x_spacing, y_spacing, z_spacing]` in mm
- **Isotropic:** When resampled, all values equal
- **Original:** Preserved in metadata for reference

### Metadata Structure
```matlab
metadata = struct(...
    'sourcePath', 'input/directory/path',     % Source location
    'parameters', struct(...),                % Processing settings used
    'numFiles', 150,                          % Number of DICOM files processed
    'volumeInfo', struct(...),                % Volume dimensions, data type
    'orientationCorrection', struct(...),     % Orientation changes applied
    'resampling', struct(...),                % Resampling details
    'validation', struct(...),                % Quality check results
    'totalTime', 12.34,                       % Processing time in seconds
    % Optional DICOM patient/study fields (if available):
    'patientName', 'Patient^Name',            % Patient identifier
    'studyDescription', 'Study Description',  % Study description
    'modality', 'CT'                          % Imaging modality
);
```

## Quality Assurance

### Validation Checks
- **File Integrity:** DICOM format validation
- **Series Consistency:** Slice spacing and positioning
- **Volume Quality:** Data range, variance, artifacts
- **ML Readiness:** Memory requirements, data types

### Error Handling
- Graceful degradation for corrupted files
- Informative error messages
- Processing continues with valid data
- Detailed logging for troubleshooting

## Performance Considerations

### Memory Management
- Large volumes processed in chunks when possible
- GPU acceleration for resampling operations
- Memory usage estimation and warnings

### Speed Optimization
- Vectorized operations throughout
- Minimal data copying
- Parallel processing where applicable

### Hardware Requirements
- **Minimum:** 8GB RAM, modern CPU
- **Recommended:** 16GB+ RAM, GPU for acceleration
- **Storage:** 2-3x input data size for processing

## Best Practices

### Data Organization
- Keep DICOM series in separate directories
- Maintain consistent file naming
- Preserve original data integrity

### Processing Workflow
1. Start with validation enabled
2. Use appropriate target spacing for your application
3. Monitor memory usage for large datasets
4. Save intermediate results for debugging

### Quality Control
- Always validate output volumes
- Check metadata for processing details
- Verify anatomical orientation
- Test with subset before full processing

## Troubleshooting

### Common Issues

**"No DICOM files found"**
- Check file extensions (.dcm, .dicom, or none)
- Verify directory path
- Ensure files are not corrupted

**"Inconsistent slice spacing"**
- Check DICOM metadata for SliceThickness
- Verify series belongs to same acquisition
- Consider manual sorting if needed

**"Memory errors"**
- Reduce target volume size
- Process in smaller batches
- Use lower precision data types

**"Orientation correction failed"**
- Check DICOM ImageOrientationPatient tags
- Verify series is 3D anatomical data
- Skip correction for non-standard acquisitions

### Debug Mode
```matlab
% Enable verbose output for troubleshooting
[vol, sp, meta] = dwim.preprocess3d.buildVolumeFromSeries(path, 'Verbose', true);
```

## Integration Examples

### Deep Learning Pipeline
```matlab
% Process training data
trainingVolumes = {};
for i = 1:numSubjects
    [vol, sp, meta] = dwim.preprocess3d.buildVolumeFromSeries(subjectPaths{i});
    trainingVolumes{i} = vol;
end

% Normalize and augment
normalizedVolumes = cellfun(@(x) normalizeVolume(x), trainingVolumes, 'UniformOutput', false);
```

### Clinical Workflow
```matlab
% Process patient study
[volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries(studyPath);

% Extract patient info
if isfield(metadata, 'patientName')
    patientName = metadata.patientName;
end
if isfield(metadata, 'studyDescription')
    studyDescription = metadata.studyDescription;
end

% Quality check
if metadata.validation.performed && ~metadata.validation.results.isValid
    warning('Volume failed validation: %s', strjoin(metadata.validation.results.issues, '; '));
end
```

## Future Enhancements

### Planned Features
- Multi-modal image fusion
- Advanced artifact correction
- Automated parameter selection
- Real-time processing capabilities

### API Extensions
- Batch processing interfaces
- Streaming data pipelines
- Web service integration
- Cloud processing support

---

*This is a draft document. Please provide feedback on clarity, completeness, and additional topics to cover.*"" 
