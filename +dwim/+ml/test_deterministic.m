classdef test_deterministic < matlab.unittest.TestCase
%TEST_DETERMINISTIC Unit tests for deterministic ML preprocessing behavior
%
%   Validates that the same input produces the same output across multiple runs.
%   Run with: results = runtests('test_deterministic'); table(results)

    methods (Test)
        function testPreprocessingDeterminism(testCase)
            % Preprocessing determinism
            testData = rand(256, 256, 'single');
            result1 = test_deterministic.preprocessTestData(testData);
            result2 = test_deterministic.preprocessTestData(testData);
            testCase.verifyEqual(result1, result2, ...
                'Preprocessing should be deterministic');
            testCase.verifyEqual(size(result1), size(result2), ...
                'Output sizes should match');
        end

        function testNormalizationDeterminism(testCase)
            % Normalization determinism
            testData = rand(100, 100, 'single') * 1000;
            norm1 = test_deterministic.normalizeData(testData);
            norm2 = test_deterministic.normalizeData(testData);
            testCase.verifyEqual(norm1, norm2, ...
                'Normalization should be deterministic');
            maxDiff = max(abs(norm1(:) - norm2(:)));
            testCase.verifyEqual(maxDiff, 0, ...
                'Normalized values should be identical');
        end

        function testResizingDeterminism(testCase)
            % Resizing determinism
            testData = rand(512, 512, 'single');
            targetSize = [256, 256];
            resized1 = imresize(testData, targetSize);
            resized2 = imresize(testData, targetSize);
            testCase.verifyEqual(resized1, resized2, ...
                'Resizing should be deterministic');
        end

        function testHashConsistency(testCase)
            % Hash consistency
            testData = rand(128, 128, 'single');
            hash1 = dwim.ml.computeHash(testData);
            hash2 = dwim.ml.computeHash(testData);
            testCase.verifyEqual(hash1, hash2, ...
                'Hash should be consistent for same data');
            testData2 = testData + 0.001;
            hash3 = dwim.ml.computeHash(testData2);
            testCase.verifyNotEqual(hash1, hash3, ...
                'Different data should produce different hash');
        end

        function testRandomSeedReproducibility(testCase)
            % Random seed reproducibility
            rng(42, 'twister');
            data1 = rand(100, 100);
            rng(42, 'twister');
            data2 = rand(100, 100);
            testCase.verifyEqual(data1, data2, ...
                'Random generation should be reproducible with same seed');
        end

        function testDatasetSplitReproducibility(testCase)
            % Dataset split reproducibility
            indices = 1:100;
            rng(123, 'twister');
            [train1, val1, test1] = test_deterministic.splitDataset(indices, 0.7, 0.15, 0.15);
            rng(123, 'twister');
            [train2, val2, test2] = test_deterministic.splitDataset(indices, 0.7, 0.15, 0.15);
            testCase.verifyEqual(train1, train2, 'Train split should be reproducible');
            testCase.verifyEqual(val1, val2, 'Validation split should be reproducible');
            testCase.verifyEqual(test1, test2, 'Test split should be reproducible');
        end
    end

    methods (Static, Access = private)
        function result = preprocessTestData(data)
            %PREPROCESSTESTDATA Simple preprocessing for testing
            result = double(data);
            result = (result - mean(result(:))) / (std(result(:)) + eps);
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
    end
end
