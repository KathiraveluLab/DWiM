# DWiM 3D Volume Preprocessing Module

## Overview
This module extends DWiM's preprocessing capabilities to handle 3D/4D medical volumes with focus on:
- Isotropic resampling with GPU acceleration
- Volume assembly from DICOM series
- Performance optimization and analysis
- Comprehensive testing and validation

## Available Functions

### Core Functions
- `resampleVolume.m` - Isotropic resampling of 3D volumes with GPU support
- `assembleVolume.m` - Build 3D volumes from DICOM series
- `optimizePerformance.m` - Performance analysis and optimization

### Testing Functions
- `test_resampleVolume.m` - Unit tests for resampling function
- `test_integration.m` - Integration tests for complete workflows

### Research Files
- `resampleVolume_pseudocode.m` - Implementation pseudo-code and documentation

## Quick Start

### Basic Volume Resampling
```matlab
% Load or create 3D volume
volume = rand(128, 128, 64) * 1000;  % Synthetic CT data

% Resample to isotropic 1mm spacing
[resampled, metadata] = dwim.preprocess3d.resampleVolume(volume, ...
    'TargetSpacing', 1.0, 'VoxelSpacing', [0.5, 0.5, 2.0]);

fprintf('Processing time: %.2f seconds\n', metadata.processingTime);
```

### Volume Assembly from DICOM
```matlab
% Assemble 3D volume from DICOM series
[volume, metadata] = dwim.preprocess3d.assembleVolume('path/to/dicom/');

% Then resample to isotropic spacing
resampled = dwim.preprocess3d.resampleVolume(volume, 'TargetSpacing', 1.0);
```

### Performance Optimization
```matlab
% Analyze performance characteristics
volume = rand(256, 256, 128, 'single');
results = dwim.preprocess3d.optimizePerformance(volume);

% View recommendations
for i = 1:length(results.recommendations)
    fprintf('%d. %s\n', i, results.recommendations{i});
end
```

## Complete Workflow Example
```matlab
% Step 1: Assemble volume from DICOM series
[volume, assemblyMeta] = dwim.preprocess3d.assembleVolume('dicom_path/');

% Step 2: Resample to isotropic spacing
[resampled, resampleMeta] = dwim.preprocess3d.resampleVolume(volume, ...
    'TargetSpacing', 1.0, 'UseGPU', true);

% Step 3: Apply 2D preprocessing to each slice
processed = zeros(size(resampled));
for slice = 1:size(resampled, 3)
    processed(:,:,slice) = dwim.preprocess.applyWindowPreset(...
        resampled(:,:,slice), 'lung');
end

% Step 4: Prepare for ML model
mlReady = imresize3(processed, [224, 224, 112]);  % Standard ML input size
```

## Key Features

### Advanced Resampling
- **GPU Acceleration**: Automatic GPU detection and usage
- **Memory Management**: Chunked processing for large volumes
- **Multiple Methods**: Linear, cubic, and nearest neighbor interpolation
- **Data Type Preservation**: Maintains original data types
- **Comprehensive Validation**: Input validation and error handling

### Volume Assembly
- **Flexible Sorting**: By slice location or instance number
- **Spacing Validation**: Detects inconsistent slice spacing
- **Gap Detection**: Identifies missing slices
- **Metadata Extraction**: Comprehensive DICOM metadata handling

### Performance Analysis
- **Benchmarking**: CPU vs GPU performance comparison
- **Method Comparison**: Speed/quality tradeoffs for interpolation methods
- **Memory Analysis**: Memory usage estimation and optimization
- **Scaling Analysis**: Performance across different volume sizes
- **Recommendations**: Automated optimization suggestions

## Testing and Validation

### Run Unit Tests
```matlab
% Test individual functions
dwim.preprocess3d.test_resampleVolume();

% Test complete workflows
dwim.preprocess3d.test_integration();
```

### Performance Benchmarking
```matlab
% Quick performance test
volume = rand(128, 128, 64);
results = dwim.preprocess3d.optimizePerformance(volume, 'Verbose', true);
```

## Integration with Existing Preprocessing
- **Seamless Integration**: Works with existing `+dwim/preprocess/` functions
- **ML Pipeline Ready**: Outputs compatible with 2D preprocessing
- **Consistent API**: Similar parameter structure across modules
- **Metadata Preservation**: Maintains spatial and acquisition information

## Performance Characteristics

### Typical Processing Rates
- **Small volumes** (64³): ~50-100 MVoxels/second
- **Medium volumes** (128³): ~20-50 MVoxels/second  
- **Large volumes** (256³): ~5-20 MVoxels/second
- **GPU acceleration**: 2-10x speedup depending on volume size

### Memory Requirements
- **Peak usage**: ~2x input volume size during processing
- **Chunked processing**: Automatic for volumes >4GB
- **Data type optimization**: Use single precision to reduce memory by 50%

## Future Extensions
- Orientation correction and standardization
- Advanced interpolation methods
- Multi-resolution processing
- Cloud-based batch processing integration