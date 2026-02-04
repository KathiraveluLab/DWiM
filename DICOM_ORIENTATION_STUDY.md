# DICOM Orientation Tags Study

## Day 6 - Dec 16: DICOM Orientation Analysis

### Key DICOM Tags for Orientation

#### 1. ImagePositionPatient (0020,0032)
- **Format**: [x, y, z] coordinates in mm
- **Description**: Position of the first voxel (top-left corner) in patient coordinate system
- **Usage**: Defines the origin point of the image slice
- **Example**: [-125.0, -125.0, -75.0]

#### 2. ImageOrientationPatient (0020,0037)  
- **Format**: [row_x, row_y, row_z, col_x, col_y, col_z]
- **Description**: Direction cosines for image rows and columns relative to patient axes
- **Usage**: Defines how image pixels map to anatomical directions
- **Example**: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0] (axial slice)

#### 3. SliceThickness (0018,0050)
- **Format**: Decimal number in mm
- **Description**: Nominal thickness of each slice
- **Usage**: Z-spacing for 3D volume reconstruction
- **Alternative**: SpacingBetweenSlices (0018,0088)

### Anatomical Coordinate Systems

#### Patient Coordinate System (DICOM Standard)
- **X-axis**: Right (-) to Left (+)
- **Y-axis**: Posterior (-) to Anterior (+)
- **Z-axis**: Inferior (-) to Superior (+)

#### Common Orientation Codes
- **RAS**: Right-Anterior-Superior (radiological standard)
- **LPS**: Left-Posterior-Superior (DICOM standard)  
- **LAS**: Left-Anterior-Superior

### Orientation Detection Algorithm

1. **Extract Direction Vectors**:
   ```matlab
   rowDir = imageOrientation(1:3);    % First 3 values
   colDir = imageOrientation(4:6);    % Last 3 values
   sliceDir = cross(rowDir, colDir);  % Cross product
   ```

2. **Determine Primary Axes**:
   - Find dominant component in each direction vector
   - Map to anatomical axis (L/R, A/P, S/I)

3. **Build Orientation String**:
   - Combine row, column, slice axes
   - Example: "RAS", "LPS", etc.

### Implementation Outline

#### correctOrientation.m Structure
```matlab
function [correctedVolume, transformMatrix] = correctOrientation(volume, dicomInfo, options)
    % 1. Extract DICOM orientation tags
    % 2. Determine current orientation 
    % 3. Calculate transformation matrix
    % 4. Apply orientation correction
    % 5. Return corrected volume and transform
end
```

#### Key Functions
- `extractOrientationInfo()` - Parse DICOM tags
- `determineCurrentOrientation()` - Analyze direction vectors
- `calculateTransformMatrix()` - Build transformation
- `applyOrientationTransform()` - Execute correction

### Next Steps (Future Implementation)
1. Complete transformation matrix calculation
2. Implement volume resampling with transforms
3. Add support for oblique orientations
4. Validate with clinical DICOM data
5. Integration with assembleVolume workflow

### Clinical Relevance
- Ensures consistent anatomical orientation across datasets
- Critical for multi-modal image registration
- Required for accurate 3D visualization and analysis
- Enables proper left/right anatomical labeling