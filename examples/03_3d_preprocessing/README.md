# Example 3: 3D Volume Preprocessing

## Purpose
Complete 3D volume preprocessing workflow from DICOM series to ML-ready volumes.

## Prerequisites
- MATLAB R2025a with Medical Imaging Toolbox
- DICOM CT series directory
- DWiM 3D preprocessing module

## Basic Usage

### Assemble and Resample Volume
```matlab
% Assemble 3D volume from DICOM series
[volume, metadata] = dwim.preprocess3d.assembleVolume('path/to/dicom/');

% Resample to isotropic spacing
[resampled, resampleInfo] = dwim.preprocess3d.resampleVolume(volume, ...
    'VoxelSpacing', metadata.voxelSpacing, 'TargetSpacing', 1.0);

fprintf('Original: [%d %d %d] -> Resampled: [%d %d %d]\n', ...
        size(volume), size(resampled));
```

### CT Lung Processing
```matlab
% Lung-specific preprocessing
lungVolume = dwim.preprocess3d.assembleVolume('lung_ct_series/');
[lungResampled, ~] = dwim.preprocess3d.resampleVolume(lungVolume, ...
    'VoxelSpacing', [0.7, 0.7, 1.25], 'TargetSpacing', 1.0, 'Method', 'linear');

% Apply lung windowing to each slice
for i = 1:size(lungResampled, 3)
    lungResampled(:,:,i) = dwim.preprocess.applyWindowPreset(lungResampled(:,:,i), 'lung');
end
```

## Performance Optimization
```matlab
% Analyze and optimize performance
dwim.preprocess3d.optimizePerformance(volume, 'VoxelSpacing', [1,1,2]);
```