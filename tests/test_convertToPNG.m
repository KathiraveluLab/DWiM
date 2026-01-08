classdef test_convertToPNG < matlab.unittest.TestCase
%test_convertToPNG Unit tests for dwim.convertToPNG
%   Run with: runtests('tests/test_convertToPNG.m')

    properties
        TestDir
        TestDicomPath
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            % Create test output directory
            testCase.TestDir = fullfile(pwd, 'test_output_convertToPNG');
            if ~exist(testCase.TestDir, 'dir')
                mkdir(testCase.TestDir);
            end
            
            % Locate test DICOM file
            testCase.TestDicomPath = fullfile(pwd, 'tests', 'image01.dcm');
            if ~exist(testCase.TestDicomPath, 'file')
                testCase.TestDicomPath = fullfile(pwd, 'image01.dcm');
            end
            testCase.assumeTrue(exist(testCase.TestDicomPath, 'file') == 2, ...
                'Test DICOM file must exist to run these tests.');
        end
    end

    methods (TestClassTeardown)
        function teardownOnce(testCase)
            % Clean up test output directory
            if exist(testCase.TestDir, 'dir')
                rmdir(testCase.TestDir, 's');
            end
        end
    end

    methods (Test)
        function testBasicConversion(testCase)
            %testBasicConversion Verify basic PNG conversion works
            outputPath = dwim.convertToPNG(testCase.TestDicomPath, testCase.TestDir);
            
            testCase.verifyTrue(isfile(outputPath), 'Output PNG file should exist');
            testCase.verifyTrue(endsWith(outputPath, '.png'), 'Output should be a .png file');
            
            imgOut = imread(outputPath);
            testCase.verifyNotEmpty(imgOut, 'Output image should not be empty');
        end

        function test16BitOutput(testCase)
            %test16BitOutput Verify 16-bit PNG output
            outputPath = dwim.convertToPNG(testCase.TestDicomPath, testCase.TestDir, ...
                BitDepth=16, OutputName='test_16bit');
            
            info = imfinfo(outputPath);
            testCase.verifyEqual(info.BitDepth, 16, 'Output should be 16-bit');
        end

        function testCustomWindowing(testCase)
            %testCustomWindowing Verify custom window/level parameters
            outputPath = dwim.convertToPNG(testCase.TestDicomPath, testCase.TestDir, ...
                WindowCenter=128, WindowWidth=256, OutputName='test_windowed');
            
            testCase.verifyTrue(isfile(outputPath), 'Windowed PNG should exist');
        end

        function testZeroWindowWidth(testCase)
            %testZeroWindowWidth Verify zero window width triggers thresholding
            outputPath = dwim.convertToPNG(testCase.TestDicomPath, testCase.TestDir, ...
                WindowCenter=128, WindowWidth=0, OutputName='test_threshold');
            
            testCase.verifyTrue(isfile(outputPath), 'Thresholded PNG should exist');
            
            % Verify output is binary (only 0 or max values)
            imgOut = imread(outputPath);
            uniqueVals = unique(imgOut(:));
            testCase.verifyLessThanOrEqual(numel(uniqueVals), 2, ...
                'Zero window width should produce binary output');
        end

        function testMissingFileError(testCase)
            %testMissingFileError Verify error thrown for non-existent file
            testCase.verifyError(...
                @() dwim.convertToPNG('nonexistent_file.dcm', testCase.TestDir), ...
                'dwim:convertToPNG:FileNotFound');
        end

        function testAutoCreateOutputDirectory(testCase)
            %testAutoCreateOutputDirectory Verify output directory is auto-created
            newDir = fullfile(testCase.TestDir, 'auto_created_dir');
            if exist(newDir, 'dir')
                rmdir(newDir, 's');
            end
            
            outputPath = dwim.convertToPNG(testCase.TestDicomPath, newDir, ...
                OutputName='auto_test');
            
            testCase.verifyTrue(isfolder(newDir), 'Directory should be auto-created');
            testCase.verifyTrue(isfile(outputPath), 'PNG should exist in new directory');
        end

        function testCustomOutputName(testCase)
            %testCustomOutputName Verify custom output filename
            customName = 'my_custom_name';
            outputPath = dwim.convertToPNG(testCase.TestDicomPath, testCase.TestDir, ...
                OutputName=customName);
            
            [~, actualName, ~] = fileparts(outputPath);
            testCase.verifyEqual(actualName, customName, 'Output should use custom name');
        end
    end
end
