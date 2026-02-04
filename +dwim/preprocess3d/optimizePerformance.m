function results = optimizePerformance(volume, varargin)
%OPTIMIZEPERFORMANCE Analyze and optimize 3D preprocessing performance
%
%   results = optimizePerformance(volume)
%       Analyzes performance characteristics for the given volume
%
%   results = optimizePerformance(volume, 'TargetSpacing', spacing)
%       Tests performance with specific target spacing
%
%   Inputs:
%       volume - 3D volume for performance testing
%
%   Name-Value Arguments:
%       TargetSpacing - Target spacing for testing (default: 1.0)
%       TestGPU - Test GPU performance if available (default: true)
%       TestMethods - Test different interpolation methods (default: true)
%       Verbose - Display detailed results (default: true)
%
%   Outputs:
%       results - Structure with performance analysis results
%
%   Example:
%       volume = rand(128, 128, 64);
%       results = dwim.preprocess3d.optimizePerformance(volume);

    arguments
        volume {mustBeNumeric}
        varargin
    end
    
    % Parse arguments
    p = inputParser;
    addParameter(p, 'TargetSpacing', 1.0, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'TestGPU', true, @islogical);
    addParameter(p, 'TestMethods', true, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;
    
    % Get actual memory size
    volumeInfo = whos('volume');
    memSizeMB = volumeInfo.bytes / 1024^2;
    
    if params.Verbose
        fprintf('DWiM 3D Preprocessing Performance Analysis\n');
        fprintf('=========================================\n');
        fprintf('Volume size: [%d %d %d]\n', size(volume));
        fprintf('Data type: %s\n', class(volume));
        fprintf('Memory size: %.1f MB\n', memSizeMB);
    end
    
    results = struct();
    results.volumeSize = size(volume);
    results.dataType = class(volume);
    results.memorySizeMB = memSizeMB;
    
    % Test 1: Baseline performance
    if params.Verbose
        fprintf('\nBaseline Performance Test:\n');
    end
    
    tic;
    [~, metadata] = dwim.preprocess3d.resampleVolume(volume, ...
        'TargetSpacing', params.TargetSpacing, 'UseGPU', false, 'Verbose', false);
    baselineTime = toc;
    
    results.baseline.time = baselineTime;
    results.baseline.rate = prod(size(volume)) / baselineTime / 1e6;  % MVoxels/sec
    
    if params.Verbose
        fprintf('  CPU processing: %.3f seconds (%.1f MVox/s)\n', ...
                baselineTime, results.baseline.rate);
    end
    
    % Test 2: GPU performance (if available and requested)
    if params.TestGPU
        if params.Verbose
            fprintf('\nGPU Performance Test:\n');
        end
        
        try
            tic;
            [~, gpuMetadata] = dwim.preprocess3d.resampleVolume(volume, ...
                'TargetSpacing', params.TargetSpacing, 'UseGPU', true, 'Verbose', false);
            gpuTime = toc;
            
            results.gpu.available = gpuMetadata.usedGPU;
            results.gpu.time = gpuTime;
            results.gpu.rate = prod(size(volume)) / gpuTime / 1e6;
            results.gpu.speedup = baselineTime / gpuTime;
            
            if params.Verbose
                if gpuMetadata.usedGPU
                    fprintf('  GPU processing: %.3f seconds (%.1f MVox/s, %.1fx speedup)\n', ...
                            gpuTime, results.gpu.rate, results.gpu.speedup);
                else
                    fprintf('  GPU not available\n');
                end
            end
            
        catch ME
            results.gpu.available = false;
            results.gpu.error = ME.message;
            if params.Verbose
                fprintf('  GPU test failed: %s\n', ME.message);
            end
        end
    end
    
    % Test 3: Different interpolation methods
    if params.TestMethods
        if params.Verbose
            fprintf('\nInterpolation Method Comparison:\n');
        end
        
        methods = {'linear', 'cubic', 'nearest'};
        results.methods = struct();
        
        for i = 1:length(methods)
            method = methods{i};
            
            try
                tic;
                dwim.preprocess3d.resampleVolume(volume, ...
                    'TargetSpacing', params.TargetSpacing, 'Method', method, ...
                    'UseGPU', false, 'Verbose', false);
                methodTime = toc;
                
                results.methods.(method).time = methodTime;
                results.methods.(method).rate = prod(size(volume)) / methodTime / 1e6;
                results.methods.(method).relativeSpeed = baselineTime / methodTime;
                
                if params.Verbose
                    fprintf('  %-8s: %.3f seconds (%.1f MVox/s, %.2fx relative)\n', ...
                            method, methodTime, results.methods.(method).rate, ...
                            results.methods.(method).relativeSpeed);
                end
                
            catch ME
                results.methods.(method).error = ME.message;
                if params.Verbose
                    fprintf('  %-8s: FAILED - %s\n', method, ME.message);
                end
            end
        end
    end
    
    % Test 4: Memory usage analysis
    if params.Verbose
        fprintf('\nMemory Usage Analysis:\n');
    end
    
    % Get actual element size from whos
    volumeInfo = whos('volume');
    elementBytes = volumeInfo.bytes / numel(volume);
    
    inputMemory = prod(size(volume)) * elementBytes / 1024^3;  % GB
    scaleFactor = 1 / params.TargetSpacing;  % Assuming 1mm original spacing
    outputSize = round(size(volume) * scaleFactor);
    outputMemory = prod(outputSize) * elementBytes / 1024^3;  % GB (assume same type)
    totalMemory = inputMemory + outputMemory;
    
    results.memory.inputGB = inputMemory;
    results.memory.outputGB = outputMemory;
    results.memory.totalGB = totalMemory;
    results.memory.peakGB = max(inputMemory, outputMemory) * 2;  % Estimate peak usage
    
    if params.Verbose
        fprintf('  Input volume: %.2f GB\n', inputMemory);
        fprintf('  Output volume: %.2f GB\n', outputMemory);
        fprintf('  Total memory: %.2f GB\n', totalMemory);
        fprintf('  Peak estimate: %.2f GB\n', results.memory.peakGB);
    end
    
    % Test 5: Scaling analysis
    if params.Verbose
        fprintf('\nScaling Factor Analysis:\n');
    end
    
    spacings = [2.0, 1.0, 0.5, 0.25];  % Different target spacings
    results.scaling = struct();
    
    for i = 1:length(spacings)
        spacing = spacings(i);
        
        try
            tic;
            [resampled, ~] = dwim.preprocess3d.resampleVolume(volume, ...
                'TargetSpacing', spacing, 'UseGPU', false, 'Verbose', false);
            scalingTime = toc;
            
            volumeRatio = prod(size(resampled)) / prod(size(volume));
            
            results.scaling.(sprintf('spacing_%.2f', spacing)).time = scalingTime;
            results.scaling.(sprintf('spacing_%.2f', spacing)).volumeRatio = volumeRatio;
            results.scaling.(sprintf('spacing_%.2f', spacing)).outputSize = size(resampled);
            
            if params.Verbose
                fprintf('  %.2f mm: %.3f sec, %.1fx volume, [%d %d %d]\n', ...
                        spacing, scalingTime, volumeRatio, size(resampled));
            end
            
        catch ME
            if params.Verbose
                fprintf('  %.2f mm: FAILED - %s\n', spacing, ME.message);
            end
        end
    end
    
    % Generate recommendations
    results.recommendations = generateRecommendations(results, params);
    
    if params.Verbose
        fprintf('\nPerformance Recommendations:\n');
        for i = 1:length(results.recommendations)
            fprintf('  %d. %s\n', i, results.recommendations{i});
        end
        fprintf('=========================================\n');
    end
end

function recommendations = generateRecommendations(results, params)
%GENERATERECOMMENDATIONS Generate performance optimization recommendations
    recommendations = {};
    
    % Memory recommendations
    if results.memory.peakGB > 8
        recommendations{end+1} = 'Consider using chunked processing for large volumes (>8GB peak memory)';
    end
    
    if results.memory.peakGB > 16
        recommendations{end+1} = 'Use single precision data type to reduce memory usage by 50%';
    end
    
    % GPU recommendations
    if isfield(results, 'gpu') && results.gpu.available
        if results.gpu.speedup > 2
            recommendations{end+1} = sprintf('GPU provides %.1fx speedup - recommended for this volume size', results.gpu.speedup);
        elseif results.gpu.speedup < 1.2
            recommendations{end+1} = 'GPU overhead exceeds benefits for this volume size - use CPU';
        end
    elseif params.TestGPU
        recommendations{end+1} = 'Consider GPU acceleration for larger volumes if available';
    end
    
    % Method recommendations
    if isfield(results, 'methods')
        if isfield(results.methods, 'linear') && isfield(results.methods, 'cubic')
            if results.methods.cubic.time / results.methods.linear.time > 3
                recommendations{end+1} = 'Linear interpolation recommended for speed (cubic is 3x slower)';
            elseif results.methods.cubic.time / results.methods.linear.time < 1.5
                recommendations{end+1} = 'Cubic interpolation provides better quality with minimal speed penalty';
            end
        end
        
        if isfield(results.methods, 'nearest')
            recommendations{end+1} = 'Use nearest neighbor interpolation for segmentation masks';
        end
    end
    
    % Performance recommendations
    if results.baseline.rate < 1.0  % Less than 1 MVoxel/sec
        recommendations{end+1} = 'Performance is below optimal - consider smaller target spacing or GPU acceleration';
    elseif results.baseline.rate > 10.0  % More than 10 MVoxel/sec
        recommendations{end+1} = 'Excellent performance - current settings are well-optimized';
    end
    
    % Scaling recommendations
    if isfield(results, 'scaling')
        scalingFields = fieldnames(results.scaling);
        for i = 1:length(scalingFields)
            field = scalingFields{i};
            if isfield(results.scaling.(field), 'volumeRatio')
                ratio = results.scaling.(field).volumeRatio;
                if ratio > 100
                    recommendations{end+1} = 'Very large upsampling detected - verify target spacing is appropriate';
                elseif ratio < 0.01
                    recommendations{end+1} = 'Very large downsampling detected - may lose important details';
                end
            end
        end
    end
    
    if isempty(recommendations)
        recommendations{1} = 'Current configuration appears optimal for this volume';
    end
end