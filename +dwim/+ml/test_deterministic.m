function test_deterministic()
%TEST_DETERMINISTIC Test deterministic output for ML preprocessing pipeline
%
%   Validates that same input produces same output across multiple runs

    fprintf('Testing Deterministic Behavior\n');
    fprintf('==============================\n');
    
    % Test 1: Preprocessing determinism
    fprintf('Test 1: Preprocessing determinism... ');
    try
        % Create test data
        testData = rand(256, 256, 'single');
        
        % Run preprocessing twice
        result1 = preprocessTestData(testData);
        result2 = preprocessTestData(testData);
        
        % Compare outputs
        assert(isequal(result1, result2), 'Preprocessing should be deterministic');
        assert(isequal(size(result1), size(result2)), 'Output sizes should match');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 2: Normalization determinism
    fprintf('Test 2: Normalization determinism... ');
    try
        testData = rand(100, 100, 'single') * 1000;
        
        norm1 = normalizeData(testData);
        norm2 = normalizeData(testData);
        
        assert(isequal(norm1, norm2), 'Normalization should be deterministic');
        maxDiff = max(abs(norm1(:) - norm2(:)));
        assert(maxDiff == 0, 'Normalized values should be identical');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 3: Resizing determinism
    fprintf('Test 3: Resizing determinism... ');
    try
        testData = rand(512, 512, 'single');
        targetSize = [256, 256];
        
        resized1 = imresize(testData, targetSize);
        resized2 = imresize(testData, targetSize);
        
        assert(isequal(resized1, resized2), 'Resizing should be deterministic');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 4: Hash consistency
    fprintf('Test 4: Hash consistency... ');
    try
        testData = rand(128, 128, 'single');
        
        hash1 = computeDataHash(testData);
        hash2 = computeDataHash(testData);
        
        assert(strcmp(hash1, hash2), 'Hash should be consistent for same data');
        
        % Different data should produce different hash
        testData2 = testData + 0.001;
        hash3 = computeDataHash(testData2);
        assert(~strcmp(hash1, hash3), 'Different data should produce different hash');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 5: Random seed reproducibility
    fprintf('Test 5: Random seed reproducibility... ');
    try
        % Set seed and generate random data
        rng(42, 'twister');
        data1 = rand(100, 100);
        
        % Reset seed and generate again
        rng(42, 'twister');
        data2 = rand(100, 100);
        
        assert(isequal(data1, data2), 'Random generation should be reproducible with same seed');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 6: Dataset split reproducibility
    fprintf('Test 6: Dataset split reproducibility... ');
    try
        nSamples = 100;
        indices = 1:nSamples;
        
        % Split with fixed seed
        rng(123, 'twister');
        [train1, val1, test1] = splitDataset(indices, 0.7, 0.15, 0.15);
        
        % Split again with same seed
        rng(123, 'twister');
        [train2, val2, test2] = splitDataset(indices, 0.7, 0.15, 0.15);
        
        assert(isequal(train1, train2), 'Train split should be reproducible');
        assert(isequal(val1, val2), 'Validation split should be reproducible');
        assert(isequal(test1, test2), 'Test split should be reproducible');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    fprintf('==============================\n');
    fprintf('Deterministic testing completed\n');
end

function result = preprocessTestData(data)
%PREPROCESSTESTDATA Simple preprocessing for testing
    result = double(data);
    result = (result - mean(result(:))) / std(result(:));
end

function normalized = normalizeData(data)
%NORMALIZEDATA Normalize data to [0, 1] range
    minVal = min(data(:));
    maxVal = max(data(:));
    if maxVal > minVal
        normalized = (data - minVal) / (maxVal - minVal);
    else
        normalized = zeros(size(data), 'like', data);
    end
end

function hash = computeDataHash(data)
%COMPUTEDATAHASH Compute MD5 hash of data
    dataBytes = typecast(data(:), 'uint8');
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(dataBytes);
    hashBytes = md.digest();
    hash = sprintf('%02x', typecast(hashBytes, 'uint8'));
end

function [trainIdx, valIdx, testIdx] = splitDataset(indices, trainRatio, valRatio, testRatio)
%SPLITDATASET Split dataset indices into train/val/test sets
    n = length(indices);
    shuffled = indices(randperm(n));
    
    nTrain = round(n * trainRatio);
    nVal = round(n * valRatio);
    
    trainIdx = shuffled(1:nTrain);
    valIdx = shuffled(nTrain+1:nTrain+nVal);
    testIdx = shuffled(nTrain+nVal+1:end);
end
