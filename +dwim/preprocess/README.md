# DWiM Preprocessing Module

This module provides ML-ready preprocessing utilities for DICOM medical images, with a focus on CT scan normalization and windowing.

## Functions

### `normalizeHU`
Normalize CT images using Hounsfield Unit (HU) windowing.

```matlab
% Custom windowing
normalized = dwim.preprocess.normalizeHU(ctImage, windowCenter, windowWidth);

% Example: Lung window
lungImage = dwim.preprocess.normalizeHU(ctImage, -600, 1500);
```

### `applyWindowPreset`
Apply standard anatomical windowing presets.

```matlab
% Available presets: 'lung', 'brain', 'abdomen', 'bone', 'mediastinum'
lungView = dwim.preprocess.applyWindowPreset(ctImage, 'lung');
brainView = dwim.preprocess.applyWindowPreset(ctImage, 'brain');
```

## Standard Windowing Presets

| Preset | Center (HU) | Width (HU) | Use Case |
|--------|-------------|------------|----------|
| Lung | -600 | 1500 | Lung parenchyma visualization |
| Brain | 40 | 80 | Brain tissue differentiation |
| Abdomen | 40 | 400 | Abdominal soft tissue |
| Bone | 400 | 1800 | Skeletal structures |
| Mediastinum | 50 | 350 | Chest mediastinal structures |

## Usage in ML Pipelines

These functions prepare CT images for machine learning workflows:

```matlab
% Load DICOM
info = dicominfo('ct_scan.dcm');
image = dicomread(info);

% Apply lung windowing for lung nodule detection
preprocessed = dwim.preprocess.applyWindowPreset(image, 'lung');

% Now ready for ML model input
```

## Future Extensions

- Volume resampling to isotropic spacing
- Multi-slice 3D volume assembly
- Intensity normalization across scanners
- Automatic orientation correction
