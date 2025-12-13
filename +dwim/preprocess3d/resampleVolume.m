function [resampled, metadata] = resampleVolume(volume, varargin)
%RESAMPLEVOLUME Resample 3D medical volume to isotropic spacing
%
%   [resampled, metadata] = resampleVolume(volume)
%       Resamples volume to isotropic spacing using minimum current spacing
%
%   [resampled, metadata] = resampleVolume(volume, 'TargetSpacing', spacing)
%       Resamples to specified isotropic spacing in mm
%
%   [resampled, metadata] = resampleVolume(volume, 'Method', method)
%       Uses specified interpolation method ('linear', 'cubic', 'nearest')
%
%   Inputs:
%       volume - 3D numeric array representing medical volume
%
%   Name-Value Arguments:
%       TargetSpacing - Target isotropic spacing in mm (default: auto)
%       Method - Interpolation method (default: 'linear')
%       VoxelSpacing - Original voxel spacing [x,y,z] in mm (default: [1,1,1])
%       UseGPU - Use GPU acceleration if available (default: true)
%       MaxMemoryGB - Maximum memory usage in GB (default: 4)
%       Verbose - Display progress information (default: true)
%
%   Outputs:
%       resampled - Resampled 3D volume
%       metadata - Structure with resampling information
%
%   Example:
%       % Basic isotropic resampling
%       resampled = dwim.preprocess3d.resampleVolume(volume);
%
%       % Custom target spacing
%       resampled = dwim.preprocess3d.resampleVolume(volume, 'TargetSpacing', 1.0);
%
%       % High quality resampling
%       [resampled, info] = dwim.preprocess3d.resampleVolume(volume, ...
%           'Method', 'cubic', 'VoxelSpacing', [0.5, 0.5, 2.0]);

    % Start timing
    processingTimer = tic;
    
    % Input validation and argument parsing
    [volume, params] = validateAndParseInputs(volume, varargin{:});
    
    % Display initial information
    if params.Verbose
        fprintf('DWiM 3D Volume Resampling\n');
        fprintf('========================\n');
        fprintf('Input volume size: [%d %d %d]\n', size(volume));
        fprintf('Input data type: %s\n', class(volume));
        fprintf('Original voxel spacing: [%.3f %.3f %.3f] mm\n', params.VoxelSpacing);
    end
    
    % Determine target spacing
    if isempty(params.TargetSpacing)
        targetSpacing = min(params.VoxelSpacing);
        if params.Verbose
            fprintf('Auto-selected target spacing: %.3f mm (isotropic)\n', targetSpacing);
        end
    else
        targetSpacing = params.TargetSpacing;
        if params.Verbose
            fprintf('Target spacing: %.3f mm (isotropic)\n', targetSpacing);
        end
    end
    
    % Calculate scale factors and output size
    scaleFactor = params.VoxelSpacing / targetSpacing;
    inputSize = size(volume);
    outputSize = round(inputSize .* scaleFactor);
    
    if params.Verbose
        fprintf('Scale factors: [%.3f %.3f %.3f]\n', scaleFactor);
        fprintf('Output volume size: [%d %d %d]\n', outputSize);
    end
    
    % Memory management assessment
    inputMemoryGB = prod(inputSize) * 8 / 1e9;  % 8 bytes per double
    outputMemoryGB = prod(outputSize) * 8 / 1e9;
    totalMemoryGB = inputMemoryGB + outputMemoryGB;
    
    if params.Verbose
        fprintf('Memory estimate: Input=%.1fGB, Output=%.1fGB, Total=%.1fGB\n', ...
                inputMemoryGB, outputMemoryGB, totalMemoryGB);
    end
    
    useChunkedProcessing = totalMemoryGB > params.MaxMemoryGB;
    if useChunkedProcessing && params.Verbose
        fprintf('Using chunked processing (memory limit: %.1fGB)\n', params.MaxMemoryGB);
    end
    
    % GPU setup
    useGPU = params.UseGPU && canUseGPU();
    if useGPU && params.Verbose
        gpuInfo = gpuDevice();
        fprintf('Using GPU: %s\n', gpuInfo.Name);
    elseif params.UseGPU && ~useGPU && params.Verbose
        fprintf('GPU requested but not available, using CPU\n');
    end
    
    % Preprocessing
    originalClass = class(volume);
    volume = double(volume);  % Convert to double for processing
    
    if useGPU && ~useChunkedProcessing
        volume = gpuArray(volume);
    end
    
    % Execute resampling
    try
        if useChunkedProcessing
            if params.Verbose
                fprintf('Processing volume in chunks...\n');
            end
            resampled = resampleVolumeChunked(volume, outputSize, params.Method, params.Verbose);
        else
            if params.Verbose
                fprintf('Resampling volume using %s interpolation...\n', params.Method);
            end
            resampled = imresize3(volume, outputSize, params.Method);
        end
    catch ME
        resampled = handleResamplingError(ME, volume, outputSize, params);
    end
    
    % Post-processing
    if useGPU && ~useChunkedProcessing
        resampled = gather(resampled);
    end
    
    % Restore original data type if not double
    if ~strcmp(originalClass, 'double')
        resampled = cast(resampled, originalClass);
    end
    
    % Generate metadata
    processingTime = toc(processingTimer);
    metadata = generateMetadata(inputSize, outputSize, scaleFactor, targetSpacing, ...
                               params, processingTime, useGPU, useChunkedProcessing);
    
    % Final validation and reporting
    validateOutput(resampled, outputSize, params.Verbose);
    
    if params.Verbose
        fprintf('Resampling completed in %.2f seconds\n', processingTime);
        fprintf('========================\n');
    end
    
    % Clean up GPU memory if used
    if useGPU
        reset(gpuDevice());
    end
end

function [volume, params] = validateAndParseInputs(volume, varargin)
%VALIDATEANDPARSEINPUTS Validate inputs and parse parameters
    
    % Create input parser
    p = inputParser;
    
    % Required input validation
    addRequired(p, 'volume', @validateVolumeInput);
    
    % Optional parameters with validation
    addParameter(p, 'TargetSpacing', [], @validateTargetSpacing);
    addParameter(p, 'Method', 'linear', @validateMethod);
    addParameter(p, 'VoxelSpacing', [1, 1, 1], @validateVoxelSpacing);
    addParameter(p, 'UseGPU', true, @validateLogical);
    addParameter(p, 'MaxMemoryGB', 4, @validateMaxMemory);
    addParameter(p, 'Verbose', true, @validateLogical);
    
    % Parse inputs
    parse(p, volume, varargin{:});
    params = p.Results;
    
    % Additional validation
    validateToolboxes();
    validateVolumeSize(volume);
end

function isValid = validateVolumeInput(volume)
%VALIDATEVOLUMEINPUT Validate input volume
    isValid = isnumeric(volume) && ndims(volume) == 3 && all(size(volume) > 0);
    if ~isValid
        error('dwim:resampleVolume:InvalidVolume', ...
              'Input must be a 3D numeric array with positive dimensions');
    end
end

function isValid = validateTargetSpacing(spacing)
%VALIDATETARGETSPACING Validate target spacing parameter
    isValid = isempty(spacing) || (isscalar(spacing) && isnumeric(spacing) && spacing > 0);
    if ~isValid
        error('dwim:resampleVolume:InvalidTargetSpacing', ...
              'TargetSpacing must be empty or a positive scalar');
    end
end

function isValid = validateMethod(method)
%VALIDATEMETHOD Validate interpolation method
    validMethods = {'linear', 'cubic', 'nearest'};
    isValid = ischar(method) || isstring(method);
    if isValid
        isValid = ismember(lower(method), validMethods);
    end
    if ~isValid
        error('dwim:resampleVolume:InvalidMethod', ...
              'Method must be one of: %s', strjoin(validMethods, ', '));
    end
end

function isValid = validateVoxelSpacing(spacing)
%VALIDATEVOXELSPACING Validate voxel spacing parameter
    isValid = isnumeric(spacing) && length(spacing) == 3 && all(spacing > 0);
    if ~isValid
        error('dwim:resampleVolume:InvalidVoxelSpacing', ...
              'VoxelSpacing must be a 3-element vector of positive numbers');
    end
end

function isValid = validateLogical(value)
%VALIDATELOGICAL Validate logical parameter
    isValid = islogical(value) || (isnumeric(value) && (value == 0 || value == 1));
    if ~isValid
        error('dwim:resampleVolume:InvalidLogical', ...
              'Parameter must be logical (true/false)');
    end
end

function isValid = validateMaxMemory(memory)
%VALIDATEMAXMEMORY Validate maximum memory parameter
    isValid = isnumeric(memory) && isscalar(memory) && memory > 0;
    if ~isValid
        error('dwim:resampleVolume:InvalidMaxMemory', ...
              'MaxMemoryGB must be a positive scalar');
    end
end

function validateToolboxes()
%VALIDATETOOLBOXES Check for required toolboxes
    if ~license('test', 'Image_Toolbox')
        error('dwim:resampleVolume:MissingToolbox', ...
              'Image Processing Toolbox is required');
    end
end

function validateVolumeSize(volume)
%VALIDATEVOLUMESIZE Additional volume size validation
    volumeSize = size(volume);
    
    % Check for reasonable dimensions
    if any(volumeSize > 4096)
        warning('dwim:resampleVolume:LargeVolume', ...
                'Very large volume detected: [%d %d %d]. Processing may be slow.', ...
                volumeSize);
    end
    
    if any(volumeSize < 8)
        warning('dwim:resampleVolume:SmallVolume', ...
                'Very small volume detected: [%d %d %d]. Results may be poor.', ...
                volumeSize);
    end
end

function available = canUseGPU()
%CANUSEGPU Check if GPU is available and suitable
    try
        gpuDevice();
        available = true;
    catch
        available = false;
    end
end

function resampled = resampleVolumeChunked(volume, outputSize, method, verbose)
%RESAMPLEVOLUMEchunked Process large volumes in chunks
    % This is a placeholder for chunked processing implementation
    % For now, fall back to regular processing with warning
    if verbose
        fprintf('Warning: Chunked processing not yet implemented, using regular processing\n');
    end
    resampled = imresize3(volume, outputSize, method);
end

function resampled = handleResamplingError(ME, volume, outputSize, params)
%HANDLERESAMPLINGERROR Handle resampling errors with fallback strategies
    if contains(ME.message, 'memory') || contains(ME.message, 'Out of memory')
        warning('dwim:resampleVolume:MemoryError', ...
                'Memory error occurred, trying chunked processing');
        resampled = resampleVolumeChunked(volume, outputSize, params.Method, params.Verbose);
    elseif strcmp(params.Method, 'cubic')
        warning('dwim:resampleVolume:CubicFallback', ...
                'Cubic interpolation failed, falling back to linear');
        resampled = imresize3(volume, outputSize, 'linear');
    else
        rethrow(ME);
    end
end

function metadata = generateMetadata(inputSize, outputSize, scaleFactor, targetSpacing, ...
                                   params, processingTime, useGPU, useChunkedProcessing)
%GENERATEMETADATA Create comprehensive metadata structure
    metadata = struct();
    metadata.originalSize = inputSize;
    metadata.resampledSize = outputSize;
    metadata.originalSpacing = params.VoxelSpacing;
    metadata.targetSpacing = targetSpacing;
    metadata.scaleFactor = scaleFactor;
    metadata.method = params.Method;
    metadata.processingTime = processingTime;
    metadata.usedGPU = useGPU;
    metadata.usedChunkedProcessing = useChunkedProcessing;
    metadata.volumeRatio = prod(outputSize) / prod(inputSize);
end

function validateOutput(resampled, expectedSize, verbose)
%VALIDATEOUTPUT Perform final validation on output
    % Check output dimensions
    if ~isequal(size(resampled), expectedSize)
        error('dwim:resampleVolume:OutputSizeMismatch', ...
              'Output size mismatch: expected [%d %d %d], got [%d %d %d]', ...
              expectedSize, size(resampled));
    end
    
    % Check for non-finite values
    if any(~isfinite(resampled(:)))
        warning('dwim:resampleVolume:NonFiniteValues', ...
                'Non-finite values detected in output');
    end
    
    % Volume ratio warnings
    volumeRatio = prod(size(resampled)) / prod(expectedSize);
    if volumeRatio > 8 && verbose
        warning('dwim:resampleVolume:LargeIncrease', ...
                'Volume increased by %.1fx - verify target spacing', volumeRatio);
    elseif volumeRatio < 0.125 && verbose
        warning('dwim:resampleVolume:LargeDecrease', ...
                'Volume decreased by %.1fx - possible information loss', 1/volumeRatio);
    end
                volumeSize);
    end
    
    if any(volumeSize < 8)
        warning('dwim:resampleVolume:SmallVolume', ...
                'Very small volume detected: [%d %d %d]. Results may be poor.', ...
                volumeSize);
    end
end

function available = canUseGPU()
%CANUSEGPU Check if GPU is available and suitable
    try
        gpuDevice();
        available = true;
    catch
        available = false;
    end
end

function resampled = resampleVolumeChunked(volume, outputSize, method, verbose)
%RESAMPLEVOLUMEchunked Process large volumes in chunks
    % This is a placeholder for chunked processing implementation
    % For now, fall back to regular processing with warning
    if verbose
        fprintf('Warning: Chunked processing not yet implemented, using regular processing\n');
    end
    resampled = imresize3(volume, outputSize, method);
end

function resampled = handleResamplingError(ME, volume, outputSize, params)
%HANDLERESAMPLINGERROR Handle resampling errors with fallback strategies
    if contains(ME.message, 'memory') || contains(ME.message, 'Out of memory')
        warning('dwim:resampleVolume:MemoryError', ...
                'Memory error occurred, trying chunked processing');
        resampled = resampleVolumeChunked(volume, outputSize, params.Method, params.Verbose);
    elseif strcmp(params.Method, 'cubic')
        warning('dwim:resampleVolume:CubicFallback', ...
                'Cubic interpolation failed, falling back to linear');
        resampled = imresize3(volume, outputSize, 'linear');
    else
        rethrow(ME);
    end
end

function metadata = generateMetadata(inputSize, outputSize, scaleFactor, targetSpacing, ...
                                   params, processingTime, useGPU, useChunkedProcessing)
%GENERATEMETADATA Create comprehensive metadata structure
    metadata = struct();
    metadata.originalSize = inputSize;
    metadata.resampledSize = outputSize;
    metadata.originalSpacing = params.VoxelSpacing;
    metadata.targetSpacing = targetSpacing;
    metadata.scaleFactor = scaleFactor;
    metadata.method = params.Method;
    metadata.processingTime = processingTime;
    metadata.usedGPU = useGPU;
    metadata.usedChunkedProcessing = useChunkedProcessing;
    metadata.volumeRatio = prod(outputSize) / prod(inputSize);
end

function validateOutput(resampled, expectedSize, verbose)
%VALIDATEOUTPUT Perform final validation on output
    % Check output dimensions
    if ~isequal(size(resampled), expectedSize)
        error('dwim:resampleVolume:OutputSizeMismatch', ...
              'Output size mismatch: expected [%d %d %d], got [%d %d %d]', ...
              expectedSize, size(resampled));
    end
    
    % Check for non-finite values
    if any(~isfinite(resampled(:)))
        warning('dwim:resampleVolume:NonFiniteValues', ...
                'Non-finite values detected in output');
    end
    
    % Volume ratio warnings
    volumeRatio = prod(size(resampled)) / prod(expectedSize);
    if volumeRatio > 8 && verbose
        warning('dwim:resampleVolume:LargeIncrease', ...
                'Volume increased by %.1fx - verify target spacing', volumeRatio);
    elseif volumeRatio < 0.125 && verbose
        warning('dwim:resampleVolume:LargeDecrease', ...
                'Volume decreased by %.1fx - possible information loss', 1/volumeRatio);
    end
end