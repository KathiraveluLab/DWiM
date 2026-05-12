# Example 2: ML Preprocessing Workflow

## Purpose

This example demonstrates the complete ML preprocessing workflow using DWiM's preprocessing module, from raw DICOM to ML-ready data.

## Prerequisites

- MATLAB R2025a with Medical Imaging Toolbox
- Sample DICOM CT files
- DWiM preprocessing module

## Workflow Steps

### Step 1: Load DICOM Image
```matlab
% Load DICOM metadata and image
info = dicominfo('sample_ct.dcm');
rawImage = dicomread(info);

% Display basic information
fprintf('Image size: %dx%d\n', size(rawImage, 1), size(rawImage, 2));
fprintf('Data type: %s\n', class(rawImage));
```

### Step 2: Validate for ML Processing
```matlab
% Check if image is suitable for ML
[isValid, validation] = dwim.preprocess.validateImageForML(rawImage);

if ~isValid
    fprintf('Validation failed:\n');
    for i = 1:length(validation.issues)
        fprintf('  - %s\n', validation.issues{i});
    end
    return;
end

fprintf('Validation: %s\n', validation.assessment);
```

### Step 3: Apply Preprocessing
```matlab
% Method 1: Use standard preset
lungView = dwim.preprocess.applyWindowPreset(rawImage, 'lung');
brainView = dwim.preprocess.applyWindowPreset(rawImage, 'brain');

% Method 2: Custom windowing
customView = dwim.preprocess.normalizeHU(rawImage, -600, 1500);
```

### Step 4: Prepare for ML Model
```matlab
% Resize for ML model (e.g., 224x224 for many CNNs)
mlReady = imresize(lungView, [224, 224]);

% Convert to format expected by ML frameworks
mlInput = repmat(mlReady, [1, 1, 3]); % Convert grayscale to RGB-like
```

## Expected Output

When you run this workflow, you should see:

1. **Validation Report**: Confirms image is suitable for ML
2. **Multiple Views**: Different windowing for various anatomical focuses  
3. **ML-Ready Data**: Normalized, resized, and formatted for model input

## Customization

### Different Anatomical Regions
```matlab
% Available presets
presets = {'lung', 'brain', 'abdomen', 'bone', 'mediastinum'};
for i = 1:length(presets)
    processed = dwim.preprocess.applyWindowPreset(rawImage, presets{i});
    % Process each view...
end
```