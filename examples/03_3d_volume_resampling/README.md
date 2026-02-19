# Example 3: 3D Volume Resampling

## Purpose

This example demonstrates 3D volume resampling using DWiM's 3D preprocessing module, showing how to convert anisotropic medical volumes to isotropic spacing for ML applications.

## Prerequisites

- MATLAB R2025a with Image Processing Toolbox
- DWiM preprocessing and preprocess3d modules
- Sample 3D medical volume data

## Basic Usage

### Step 1: Create or Load 3D Volume
```matlab
% Create synthetic 3D volume (for demonstration)
volume = rand(128, 128, 64) * 1000;  % Simulate CT data
fprintf('Original volume size: [%d %d %d]\n', size(volume));
```

### Step 2: Basic Isotropic Resampling
```matlab
% Automatic isotropic resampling (uses minimum spacing)
[resampled, metadata] = dwim.preprocess3d.resampleVolume(volume);

fprintf('Resampled volume size: [%d %d %d]\n', size(resampled));
fprintf('Processing time: %.2f seconds\n', metadata.processingTime);
```

### Step 3: Custom Target Spacing
```matlab
% Resample to specific isotropic spacing (1mm)
[resampled_1mm, metadata] = dwim.preprocess3d.resampleVolume(volume, ...
    'TargetSpacing', 1.0, ...
    'VoxelSpacing', [0.5, 0.5, 2.0]);  % Original spacing

fprintf('Scale factors: [%.2f %.2f %.2f]\n', metadata.scaleFactor);
```

## Integration with 2D Preprocessing
```matlab
% Complete workflow: 3D resampling + 2D preprocessing
volume = rand(128, 128, 64) * 1000;  % Simulate CT data

% Step 1: Resample to isotropic spacing
resampled = dwim.preprocess3d.resampleVolume(volume, 'TargetSpacing', 1.0);

% Step 2: Apply 2D preprocessing to each slice
processed = zeros(size(resampled));
for slice = 1:size(resampled, 3)
    processed(:,:,slice) = dwim.preprocess.applyWindowPreset(resampled(:,:,slice), 'lung');
end
```