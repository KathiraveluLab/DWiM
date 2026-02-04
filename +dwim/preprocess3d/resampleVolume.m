function [resampled, metadata] = resampleVolume(volume, varargin)
%RESAMPLEVOLUME Resample 3D medical volume to isotropic spacing
%
%   [resampled, metadata] = resampleVolume(volume)
%       Resamples volume to isotropic spacing using minimum current spacing
%
%   [resampled, metadata] = resampleVolume(volume, 'TargetSpacing', spacing)
%       Resamples to specified isotropic spacing in mm
%
%   Inputs:
%       volume - 3D numeric array representing medical volume
%
%   Name-Value Arguments:
%       TargetSpacing - Target isotropic spacing in mm (default: auto-detect)
%       VoxelSpacing - Original voxel spacing [x,y,z] in mm (default: [1,1,1])
%       Method - Interpolation method (default: 'linear')
%                Options: 'linear', 'cubic', 'nearest'
%       UseGPU - Use GPU acceleration if available (default: true)
%       MaxMemoryGB - Maximum memory for processing (default: 8.0)
%       Verbose - Display progress information (default: true)
%
%   Outputs:
%       resampled - Resampled 3D volume with isotropic spacing
%       metadata - Structure with processing information
%
%   Example:
%       % Basic usage with auto spacing
%       [vol, info] = dwim.preprocess3d.resampleVolume(volume);
%
%       % Custom target spacing
%       [vol, info] = dwim.preprocess3d.resampleVolume(volume, ...
%           'VoxelSpacing', [0.5, 0.5, 2.0], 'TargetSpacing', 1.0);

    arguments
        volume {mustBeNumeric}
        varargin
    end
    
    % Parse arguments
    p = inputParser;
    addParameter(p, 'TargetSpacing', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    addParameter(p, 'VoxelSpacing', [1.0, 1.0, 1.0], @(x) isnumeric(x) && numel(x) == 3 && all(x > 0));
    addParameter(p, 'Method', 'linear', @(x) ismember(x, {'linear', 'cubic', 'nearest'}));
    addParameter(p, 'UseGPU', true, @islogical);
    addParameter(p, 'MaxMemoryGB', 8.0, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;
    
    % Validate input volume
    if ndims(volume) ~= 3
        error('dwim:resampleVolume:InvalidVolume', ...
              'Input must be a 3D volume, got %dD array', ndims(volume));
    end
    
    % Store original properties
    originalSize = size(volume);
    originalClass = class(volume);
    originalSpacing = params.VoxelSpacing(:)';
    
    % Determine target spacing
    if isempty(params.TargetSpacing)
        targetSpacing = min(originalSpacing);
    else
        targetSpacing = params.TargetSpacing;
    end
    
    % Validate spacing
    if targetSpacing < 0.01 || targetSpacing > 100
        warning('dwim:resampleVolume:UnusualSpacing', ...
                'Target spacing %.3f mm seems unusual (expected 0.01-100 mm)', targetSpacing);
    end
    
    if params.Verbose
        fprintf('DWiM Volume Resampling\n');
        fprintf('======================\n');
        fprintf('Original size: [%d %d %d]\n', originalSize);
        fprintf('Original spacing: [%.2f %.2f %.2f] mm\n', originalSpacing);
        fprintf('Target spacing: %.2f mm (isotropic)\n', targetSpacing);
    end
    
    % Calculate scale factors and output size
    scaleFactor = originalSpacing / targetSpacing;
    outputSize = round(originalSize .* scaleFactor);
    
    if params.Verbose
        fprintf('Scale factors: [%.2f %.2f %.2f]\n', scaleFactor);
        fprintf('Output size: [%d %d %d]\n', outputSize);
    end
    
    % Memory estimation
    inputMemoryGB = prod(originalSize) * 8 / 1e9;
    outputMemoryGB = prod(outputSize) * 8 / 1e9;
    totalMemoryGB = inputMemoryGB + outputMemoryGB;
    
    if params.Verbose
        fprintf('Memory estimate: %.2f GB (input) + %.2f GB (output) = %.2f GB\n', ...
                inputMemoryGB, outputMemoryGB, totalMemoryGB);
    end
    
    % Check if chunked processing is needed
    usedChunkedProcessing = totalMemoryGB > params.MaxMemoryGB;
    if usedChunkedProcessing && params.Verbose
        fprintf('Using chunked processing (total memory %.2f GB > limit %.2f GB)\n', ...
                totalMemoryGB, params.MaxMemoryGB);
    end
    
    % Start timing
    tic;
    
    % GPU setup
    usedGPU = false;
    if params.UseGPU
        try
            gpuDevice;
            volume = gpuArray(double(volume));
            usedGPU = true;
            if params.Verbose
                fprintf('Using GPU acceleration\n');
            end
        catch
            if params.Verbose
                fprintf('GPU not available, using CPU\n');
            end
        end
    end
    
    % Perform resampling
    if params.Verbose
        fprintf('Resampling with %s interpolation...\n', params.Method);
    end
    
    try
        if usedChunkedProcessing
            % Chunked processing for large volumes
            resampled = resampleChunked(volume, outputSize, params.Method);
        else
            % Direct resampling
            resampled = imresize3(volume, outputSize, params.Method);
        end
    catch ME
        % Fallback to CPU if GPU fails
        if usedGPU
            warning('dwim:resampleVolume:GPUFallback', ...
                    'GPU processing failed, falling back to CPU: %s', ME.message);
            volume = gather(volume);
            usedGPU = false;
            if usedChunkedProcessing
                resampled = resampleChunked(volume, outputSize, params.Method);
            else
                resampled = imresize3(volume, outputSize, params.Method);
            end
        else
            rethrow(ME);
        end
    end
    
    % Gather from GPU if used
    if usedGPU
        resampled = gather(resampled);
    end
    
    % Restore original data type
    resampled = cast(resampled, originalClass);
    
    % Calculate processing time
    processingTime = toc;
    
    if params.Verbose
        fprintf('Resampling completed in %.2f seconds\n', processingTime);
        fprintf('Volume ratio: %.2fx\n', prod(outputSize) / prod(originalSize));
        fprintf('======================\n');
    end
    
    % Generate metadata
    metadata = struct();
    metadata.originalSize = originalSize;
    metadata.resampledSize = size(resampled);
    metadata.originalSpacing = originalSpacing;
    metadata.targetSpacing = targetSpacing;
    metadata.scaleFactor = scaleFactor;
    metadata.method = params.Method;
    metadata.processingTime = processingTime;
    metadata.usedGPU = usedGPU;
    metadata.usedChunkedProcessing = usedChunkedProcessing;
    metadata.volumeRatio = prod(outputSize) / prod(originalSize);
    metadata.dataType = originalClass;
end

function resampled = resampleChunked(volume, outputSize, method)
%RESAMPLECHUNKED Resample large volume in chunks to manage memory
    
    % For now, use a simple chunked approach along Z-axis
    % This is a placeholder for more sophisticated chunking
    numChunks = 4;
    chunkSize = ceil(size(volume, 3) / numChunks);
    outputChunkSize = ceil(outputSize(3) / numChunks);
    
    resampled = zeros(outputSize, class(volume));
    
    for i = 1:numChunks
        startIdx = (i-1) * chunkSize + 1;
        endIdx = min(i * chunkSize, size(volume, 3));
        
        outStartIdx = (i-1) * outputChunkSize + 1;
        outEndIdx = min(i * outputChunkSize, outputSize(3));
        
        chunk = volume(:, :, startIdx:endIdx);
        chunkOutputSize = [outputSize(1), outputSize(2), outEndIdx - outStartIdx + 1];
        
        resampledChunk = imresize3(chunk, chunkOutputSize, method);
        resampled(:, :, outStartIdx:outEndIdx) = resampledChunk;
    end
end
