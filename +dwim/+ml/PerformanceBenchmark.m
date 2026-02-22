classdef PerformanceBenchmark < handle
%PERFORMANCEBENCHMARK Lightweight benchmarking hooks for the DWiM ML pipeline
%
%   Records wall-clock time and peak memory for named pipeline operations,
%   then produces a formatted summary report.
%
%   Usage:
%       bm = dwim.ml.PerformanceBenchmark();
%       bm.start('assemble');
%       [vol, ~] = dwim.preprocess3d.assembleVolume(dicomDir);
%       bm.stop('assemble');
%
%       bm.timeit('resample', @() dwim.preprocess3d.resampleVolume(vol));
%
%       bm.report();
%
%   See also: dwim.preprocessPipeline

    properties (Access = private)
        Records     % struct array: label, elapsed, memoryDeltaMB, calls
        ActiveLabel % label currently being timed (or empty)
        ActiveTimer % tic handle for the currently active measurement
        ActiveMemMB % memory at start of active measurement
    end

    methods
        function obj = PerformanceBenchmark()
            %PERFORMANCEBENCHMARK Construct benchmark instance
            obj.Records     = struct('label', {}, 'elapsed', {}, ...
                                     'memoryDeltaMB', {}, 'calls', {});
            obj.ActiveLabel = '';
            obj.ActiveTimer = [];
            obj.ActiveMemMB = 0;
        end

        function start(obj, label)
            %START Begin timing a named operation
            %   bm.start('myStep') must be paired with bm.stop('myStep')
            arguments
                obj   (1,1) dwim.ml.PerformanceBenchmark
                label (1,1) string
            end
            if ~isempty(obj.ActiveLabel)
                warning('PerformanceBenchmark:AlreadyRunning', ...
                        'Benchmark ''%s'' is already running. Stop it first.', ...
                        obj.ActiveLabel);
            end
            obj.ActiveLabel = label;
            obj.ActiveMemMB = PerformanceBenchmark.currentMemoryMB();
            obj.ActiveTimer = tic;
        end

        function stop(obj, label)
            %STOP End timing the named operation and record results
            arguments
                obj   (1,1) dwim.ml.PerformanceBenchmark
                label (1,1) string
            end
            if isempty(obj.ActiveTimer)
                warning('PerformanceBenchmark:StopWithoutStart', ...
                        'stop(''%s'') called without a running timer.', label);
                return;
            end
            
            elapsed = toc(obj.ActiveTimer);
            memDelta = PerformanceBenchmark.currentMemoryMB() - obj.ActiveMemMB;

            if ~strcmp(obj.ActiveLabel, label)
                warning('PerformanceBenchmark:LabelMismatch', ...
                        'stop(''%s'') called but ''%s'' was started.', ...
                        label, obj.ActiveLabel);
            end
            obj.ActiveLabel = '';
            obj.record(label, elapsed, memDelta);
        end

        function result = timeit(obj, label, func)
            %TIMEIT Time an anonymous function and return its output
            %
            %   result = bm.timeit('normalize', @() normalizeHU(img, 40, 80));
            arguments
                obj   (1,1) dwim.ml.PerformanceBenchmark
                label (1,1) string
                func  (1,1) {mustBeA(func, 'function_handle')}
            end
            memBefore = PerformanceBenchmark.currentMemoryMB();
            t = tic;
            result = func();
            elapsed  = toc(t);
            memDelta = PerformanceBenchmark.currentMemoryMB() - memBefore;
            obj.record(label, elapsed, memDelta);
        end

        function report(obj)
            %REPORT Print a formatted summary of all recorded benchmarks
            if isempty(obj.Records)
                fprintf('PerformanceBenchmark: no results recorded.\n');
                return;
            end

            fprintf('\n%-30s %10s %12s %8s\n', 'Operation', 'Time (s)', ...
                    'Mem delta (MB)', 'Calls');
            fprintf('%s\n', repmat('-', 1, 65));
            for i = 1:numel(obj.Records)
                r = obj.Records(i);
                fprintf('%-30s %10.4f %+12.1f %8d\n', ...
                        r.label, r.elapsed, r.memoryDeltaMB, r.calls);
            end
            fprintf('%s\n', repmat('-', 1, 65));

            totalTime = sum([obj.Records.elapsed]);
            fprintf('%-30s %10.4f\n', 'TOTAL', totalTime);
        end

        function reset(obj)
            %RESET Clear all recorded benchmarks
            obj.Records     = struct('label', {}, 'elapsed', {}, ...
                                     'memoryDeltaMB', {}, 'calls', {});
            obj.ActiveLabel = '';
        end

        function tbl = toTable(obj)
            %TOTABLE Return results as a MATLAB table
            if isempty(obj.Records)
                tbl = table();
                return;
            end
            labels   = {obj.Records.label}';
            elapsed  = [obj.Records.elapsed]';
            memDelta = [obj.Records.memoryDeltaMB]';
            calls    = [obj.Records.calls]';
            tbl = table(labels, elapsed, memDelta, calls, ...
                        'VariableNames', {'Operation','ElapsedSec', ...
                                          'MemDeltaMB','Calls'});
        end
    end

    methods (Access = private)
        function record(obj, label, elapsed, memDelta)
            %RECORD Store a timing result, aggregating repeated calls
            idx = find(strcmp({obj.Records.label}, label), 1);
            if isempty(idx)
                obj.Records(end+1) = struct('label', label, ...
                                            'elapsed', elapsed, ...
                                            'memoryDeltaMB', memDelta, ...
                                            'calls', 1);
            else
                obj.Records(idx).elapsed       = obj.Records(idx).elapsed + elapsed;
                obj.Records(idx).memoryDeltaMB = obj.Records(idx).memoryDeltaMB + memDelta;
                obj.Records(idx).calls         = obj.Records(idx).calls + 1;
            end
        end
    end

    methods (Static)
        function mb = currentMemoryMB()
            %CURRENTMEMORYMB Return current MATLAB memory usage in MB
            try
                info = memory();
                mb = (info.MemUsedMATLAB) / 1e6;
            catch
                mb = 0;  % memory() not available on all platforms
            end
        end
    end
end
