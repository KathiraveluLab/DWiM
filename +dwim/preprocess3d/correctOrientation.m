function [correctedVolume, transformMatrix] = correctOrientation(volume, dicomInfo, varargin)
%CORRECTORIENTATION Correct 3D volume orientation using DICOM tags
%
%   [correctedVolume, transformMatrix] = correctOrientation(volume, dicomInfo)
%       Corrects volume orientation to standard anatomical position using
%       DICOM orientation tags from the first slice
%
%   [correctedVolume, transformMatrix] = correctOrientation(volume, dicomInfoArray)
%       Uses array of DICOM info structures for more robust orientation detection
%
%   Inputs:
%       volume - 3D numeric array representing medical volume
%       dicomInfo - DICOM info structure or array of structures
%
%   Name-Value Arguments:
%       TargetOrientation - Target orientation code (default: 'RAS')
%       Method - Resampling method for rotation (default: 'linear')
%       Verbose - Display orientation information (default: true)
%
%   Outputs:
%       correctedVolume - Orientation-corrected 3D volume
%       transformMatrix - 4x4 transformation matrix applied
%
%   DICOM Orientation Tags Used:
%       ImagePositionPatient - [x,y,z] position of first voxel in mm
%       ImageOrientationPatient - [6 values] direction cosines for row/col
%       SliceThickness - Distance between slices in mm
%
%   Standard Orientations:
%       RAS - Right-Anterior-Superior (radiological standard)
%       LPS - Left-Posterior-Superior (DICOM standard)
%       LAS - Left-Anterior-Superior
%
%   Example:
%       info = dicominfo('slice001.dcm');
%       volume = assembleVolume('dicom_folder/');
%       [corrected, T] = dwim.preprocess3d.correctOrientation(volume, info);

    arguments
        volume {mustBeNumeric}
        dicomInfo
        varargin
    end
    
    % Parse arguments
    p = inputParser;
    addParameter(p, 'TargetOrientation', 'RAS', @(x) ismember(x, {'RAS', 'LPS', 'LAS', 'RPI', 'LPI'}));
    addParameter(p, 'Method', 'linear', @(x) ismember(x, {'linear', 'cubic', 'nearest'}));
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;
    
    if params.Verbose
        fprintf('DWiM Volume Orientation Correction\n');
        fprintf('=================================\n');
    end
    
    % Extract orientation information from DICOM
    orientInfo = extractOrientationInfo(dicomInfo, params.Verbose);
    
    % Determine current orientation
    currentOrientation = determineCurrentOrientation(orientInfo, params.Verbose);
    
    % Calculate transformation matrix
    transformMatrix = calculateTransformMatrix(currentOrientation, params.TargetOrientation, orientInfo);
    
    % Apply transformation
    correctedVolume = applyOrientationTransform(volume, transformMatrix, params.Method, params.Verbose);
    
    if params.Verbose
        fprintf('Orientation correction completed\n');
        fprintf('=================================\n');
    end
end

function orientInfo = extractOrientationInfo(dicomInfo, verbose)
%EXTRACTORIENTATIONINFO Extract orientation tags from DICOM info
    
    % Handle array of DICOM info structures
    if iscell(dicomInfo) || (isstruct(dicomInfo) && length(dicomInfo) > 1)
        firstInfo = dicomInfo(1);
        if iscell(dicomInfo)
            firstInfo = dicomInfo{1};
        end
    else
        firstInfo = dicomInfo;
    end
    
    orientInfo = struct();
    
    % Extract ImagePositionPatient [x, y, z] in mm
    if isfield(firstInfo, 'ImagePositionPatient')
        orientInfo.imagePosition = firstInfo.ImagePositionPatient;
    else
        orientInfo.imagePosition = [0, 0, 0];
        if verbose
            warning('ImagePositionPatient not found, using [0,0,0]');
        end
    end
    
    % Extract ImageOrientationPatient [row_x, row_y, row_z, col_x, col_y, col_z]
    if isfield(firstInfo, 'ImageOrientationPatient')
        orientInfo.imageOrientation = firstInfo.ImageOrientationPatient;
    else
        orientInfo.imageOrientation = [1, 0, 0, 0, 1, 0]; % Default axial
        if verbose
            warning('ImageOrientationPatient not found, assuming axial orientation');
        end
    end
    
    % Extract SliceThickness
    if isfield(firstInfo, 'SliceThickness')
        orientInfo.sliceThickness = firstInfo.SliceThickness;
    elseif isfield(firstInfo, 'SpacingBetweenSlices')
        orientInfo.sliceThickness = firstInfo.SpacingBetweenSlices;
    else
        orientInfo.sliceThickness = 1.0;
        if verbose
            warning('SliceThickness not found, using 1.0mm');
        end
    end
    
    % Extract PixelSpacing [row_spacing, col_spacing]
    if isfield(firstInfo, 'PixelSpacing')
        orientInfo.pixelSpacing = firstInfo.PixelSpacing;
    else
        orientInfo.pixelSpacing = [1.0, 1.0];
        if verbose
            warning('PixelSpacing not found, using [1.0, 1.0]mm');
        end
    end
    
    if verbose
        fprintf('DICOM Orientation Information:\n');
        fprintf('  ImagePositionPatient: [%.2f, %.2f, %.2f]\n', orientInfo.imagePosition);
        fprintf('  ImageOrientationPatient: [%.3f, %.3f, %.3f, %.3f, %.3f, %.3f]\n', orientInfo.imageOrientation);
        fprintf('  SliceThickness: %.2f mm\n', orientInfo.sliceThickness);
        fprintf('  PixelSpacing: [%.2f, %.2f] mm\n', orientInfo.pixelSpacing);
    end
end

function orientation = determineCurrentOrientation(orientInfo, verbose)
%DETERMINECURRENTORIENTATION Determine current volume orientation from DICOM tags
    
    % Extract direction vectors from ImageOrientationPatient
    rowDir = orientInfo.imageOrientation(1:3);
    colDir = orientInfo.imageOrientation(4:6);
    
    % Check orthogonality (for oblique slices)
    ORTHOGONALITY_THRESHOLD = 0.01;  % Configurable threshold
    dotProduct = abs(dot(rowDir, colDir));
    if dotProduct > ORTHOGONALITY_THRESHOLD
        if verbose
            warning('dwim:correctOrientation:ObliqueSlice', ...
                'Row and column directions are not orthogonal (dot product = %.4f). Results may be incorrect for oblique acquisitions.', dotProduct);
        end
    end
    
    % Calculate slice direction (cross product)
    sliceDir = cross(rowDir, colDir);
    
    % Determine primary axes
    rowAxis = findPrimaryAxis(rowDir);
    colAxis = findPrimaryAxis(colDir);
    sliceAxis = findPrimaryAxis(sliceDir);
    
    % Build orientation string
    orientation = [rowAxis, colAxis, sliceAxis];
    
    if verbose
        fprintf('Current Orientation Analysis:\n');
        fprintf('  Row direction: [%.3f, %.3f, %.3f] -> %s\n', rowDir, rowAxis);
        fprintf('  Column direction: [%.3f, %.3f, %.3f] -> %s\n', colDir, colAxis);
        fprintf('  Slice direction: [%.3f, %.3f, %.3f] -> %s\n', sliceDir, sliceAxis);
        fprintf('  Current orientation: %s\n', orientation);
    end
end

function axis = findPrimaryAxis(direction)
%FINDPRIMARYAXIS Find primary anatomical axis from direction vector
    
    [~, maxIdx] = max(abs(direction));
    
    switch maxIdx
        case 1 % X axis
            if direction(1) > 0
                axis = 'L'; % Left
            else
                axis = 'R'; % Right
            end
        case 2 % Y axis
            if direction(2) > 0
                axis = 'P'; % Posterior
            else
                axis = 'A'; % Anterior
            end
        case 3 % Z axis
            if direction(3) > 0
                axis = 'S'; % Superior
            else
                axis = 'I'; % Inferior
            end
    end
end

function T = calculateTransformMatrix(currentOrient, targetOrient, orientInfo)
%CALCULATETRANSFORMMATRIX Calculate 4x4 affine transformation matrix including translation
    
    if strcmp(currentOrient, targetOrient)
        T = eye(4);
        return;
    end
    
    % Define axis mappings for common orientations
    orientMap = containers.Map();
    orientMap('RAS') = [1, 2, 3];   % Right, Anterior, Superior
    orientMap('LPS') = [-1, -2, 3]; % Left, Posterior, Superior  
    orientMap('LAS') = [-1, 2, 3];  % Left, Anterior, Superior
    orientMap('RPI') = [1, -2, -3]; % Right, Posterior, Inferior
    orientMap('LPI') = [-1, -2, -3]; % Left, Posterior, Inferior
    
    % Get axis mappings
    if ~isKey(orientMap, currentOrient)
        error('dwim:correctOrientation:UnsupportedOrientation', ...
              'Unsupported current orientation: %s. Supported: RAS, LPS, LAS, RPI, LPI', currentOrient);
    end
    if ~isKey(orientMap, targetOrient)
        error('dwim:correctOrientation:UnsupportedOrientation', ...
              'Unsupported target orientation: %s. Supported: RAS, LPS, LAS, RPI, LPI', targetOrient);
    end
    
    currentAxes = orientMap(currentOrient);
    targetAxes = orientMap(targetOrient);
    
    % Build rotation/reflection matrix
    R = eye(4);
    
    % Map axes and handle flips
    for i = 1:3
        targetAxis = targetAxes(i);
        
        % Find which current axis maps to this target axis (exact match)
        axisIdx = find(abs(currentAxes) == abs(targetAxis));
        
        % Set transformation element
        R(i, axisIdx) = sign(targetAxis) * sign(currentAxes(axisIdx));
    end
    
    % For pure reorientation within the volume, we only need the rotation/reflection matrix.
    % Translation is not applied here as we're operating in voxel space, not patient space.
    % The ImagePositionPatient is preserved in the metadata for downstream spatial alignment.
    T = R;
end

function correctedVolume = applyOrientationTransform(volume, T, method, verbose)
%APPLYORIENTATIONTRANSFORM Apply transformation to volume
    
    if verbose
        fprintf('Applying orientation transformation...\n');
    end
    
    % If identity matrix, no transformation needed
    if isequal(T, eye(4))
        correctedVolume = volume;
        if verbose
            fprintf('No transformation needed\n');
        end
        return;
    end
    
    [rows, cols, slices] = size(volume);
    
    % Create coordinate grids
    [X, Y, Z] = meshgrid(1:cols, 1:rows, 1:slices);
    
    % Convert to homogeneous coordinates
    coords = [X(:)'; Y(:)'; Z(:)'; ones(1, numel(X))];
    
    % Apply transformation
    newCoords = T \ coords; % Inverse transform for resampling
    
    % Reshape back to grid
    Xnew = reshape(newCoords(1,:), size(X));
    Ynew = reshape(newCoords(2,:), size(Y));
    Znew = reshape(newCoords(3,:), size(Z));
    
    % Interpolate volume at new coordinates
    correctedVolume = interp3(double(volume), Xnew, Ynew, Znew, method, 0);
    
    % Convert back to original data type
    correctedVolume = cast(correctedVolume, class(volume));
    
    if verbose
        fprintf('Transformation applied using %s interpolation\n', method);
    end
end
