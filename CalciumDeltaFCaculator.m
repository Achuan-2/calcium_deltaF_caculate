classdef CalciumDeltaFCaculator < matlab.apps.AppBase
    
    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        FileOperationsPanel      matlab.ui.container.Panel
        FramerateHzLabel         matlab.ui.control.Label
        FramerateEditField       matlab.ui.control.NumericEditField
        LoadDataButton           matlab.ui.control.Button
        DeltaFOverFCalculatePanel matlab.ui.container.Panel
        CalculateZScoreCheckBox  matlab.ui.control.CheckBox
        BaselineMethodDropDownLabel matlab.ui.control.Label
        BaselineMethodDropDown    matlab.ui.control.DropDown
        PercentileEditFieldLabel matlab.ui.control.Label
        PercentileEditField      matlab.ui.control.EditField
        BaselineTimeLabel        matlab.ui.control.Label
        BaselineTimeEditField    matlab.ui.control.EditField
        PolynomialOrderLabel     matlab.ui.control.Label
        PolynomialOrderEditField matlab.ui.control.NumericEditField
        MovingWindowLabel        matlab.ui.control.Label
        MovingWindowEditField    matlab.ui.control.NumericEditField
        MovingPercentileLabel    matlab.ui.control.Label
        MovingPercentileEditField matlab.ui.control.NumericEditField
        RunAnalysisButton        matlab.ui.control.Button
        NeuronDisplayPanel       matlab.ui.container.Panel
        SelectNeuronLabel        matlab.ui.control.Label
        NeuronDropDown           matlab.ui.control.DropDown
        PreviousNeuronButton     matlab.ui.control.Button
        NextNeuronButton         matlab.ui.control.Button
        SaveResultsButton        matlab.ui.control.Button
        AllNeuronsDisplayPanel   matlab.ui.container.Panel
        ScalebarSignalLabel      matlab.ui.control.Label
        ScalebarSignalEditField  matlab.ui.control.NumericEditField
        PlotScaleBarTimeCheckBox matlab.ui.control.CheckBox
        ScalebarTimeLabel        matlab.ui.control.Label
        ScalebarTimeEditField    matlab.ui.control.NumericEditField
        SelectedROILabel         matlab.ui.control.Label
        SelectedROIEditField     matlab.ui.control.EditField
        ROIIntervalLabel         matlab.ui.control.Label
        ROIIntervalEditField     matlab.ui.control.NumericEditField
        ColorMapLabel            matlab.ui.control.Label
        ColorMapEditField        matlab.ui.control.EditField
        DisplayAllNeuronsButton  matlab.ui.control.Button
        UIAxes                   matlab.ui.control.UIAxes
        SignalTypeDropDown       matlab.ui.control.DropDown
    end
    
    % Properties that store app data
    properties (Access = public)
        fluo_data                % Loaded fluorescence data (rows=neurons, cols=frames)
        dff_data                 % Calculated ΔF/F data
        zscore_dff_data          % Calculated z-score ΔF/F data
        time_vector              % Time vector for plotting
        framerate = 30           % Default framerate (Hz)
        calculate_zscore = false % Flag to calculate z-score ΔF/F
        baseline_method = 'Percentile' % Default baseline method
        percentile_value = '10:20' % Default percentile
        baseline_time = 'all'    % Default baseline time range
        polynomial_order = 3      % Default polynomial order
        moving_window_sec = 20    % Default moving window size in seconds
        moving_percentile = 20    % Default moving percentile value
        current_neuron_id = 1     % ID of the currently displayed neuron
        display_all = false       % Flag to display all neurons
        results                  % Structure to store analysis results
        display_figure_handles   % Handle for the all neurons figure
        scalebar_signal = 1      % Default scalebar signal value
        plot_scale_bar_time = true % Default plot scale bar time
        scalebar_time = 10       % Default scalebar time length
        selected_roi_str = ''    % Default selected ROI string
        roi_interval = 1         % Default ROI interval
        color_map = 'turbo'      % Default color map
        signal_type = 'Raw Signal' % Current signal type to display
    end
    
    methods (Access = private)
        
        % Update plot display
        function UpdatePlot(app)
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');
            
            if isempty(app.fluo_data)
                title(app.UIAxes, 'No data to plot.');
                xlabel(app.UIAxes, 'Time (s)');
                ylabel(app.UIAxes, 'Signal');
                return;
            end
            
            ylabel_str = 'Raw Signal';
            if strcmp(app.signal_type, 'ΔF/F')
                ylabel_str = 'ΔF/F';
                if isempty(app.dff_data)
                    title(app.UIAxes, 'No ΔF/F data to plot.');
                    xlabel(app.UIAxes, 'Time (s)');
                    ylabel(app.UIAxes, 'ΔF/F');
                    return;
                end
            elseif strcmp(app.signal_type, 'z-score ΔF/F')
                ylabel_str = 'z-score ΔF/F';
                if isempty(app.zscore_dff_data)
                    title(app.UIAxes, 'No z-score ΔF/F data to plot.');
                    xlabel(app.UIAxes, 'Time (s)');
                    ylabel(app.UIAxes, 'z-score ΔF/F');
                    return;
                end
            end
            
            if app.display_all
                num_neurons = size(app.fluo_data, 1);
                for n = 1:num_neurons
                    if strcmp(app.signal_type, 'Raw Signal')
                        plot(app.UIAxes, app.time_vector, app.fluo_data(n, :), ...
                            'DisplayName', sprintf('Neuron %d', n));
                    elseif strcmp(app.signal_type, 'ΔF/F')
                        plot(app.UIAxes, app.time_vector, app.dff_data(n, :), ...
                            'DisplayName', sprintf('Neuron %d', n));
                    else
                        plot(app.UIAxes, app.time_vector, app.zscore_dff_data(n, :), ...
                            'DisplayName', sprintf('Neuron %d', n));
                    end
                end
                title(app.UIAxes, sprintf('%s for All %d Neurons', app.signal_type, num_neurons));
            else
                neuron_id = app.current_neuron_id;
                if neuron_id > size(app.fluo_data, 1)
                    title(app.UIAxes, 'Invalid neuron selected.');
                    return;
                end
                if strcmp(app.signal_type, 'Raw Signal')
                    trace = app.fluo_data(neuron_id, :);
                elseif strcmp(app.signal_type, 'ΔF/F')
                    trace = app.dff_data(neuron_id, :);
                else
                    trace = app.zscore_dff_data(neuron_id, :);
                end
                plot(app.UIAxes, app.time_vector, trace, 'b-', 'LineWidth', 1.5, ...
                    'DisplayName', sprintf('Neuron %d', neuron_id));
                title(app.UIAxes, sprintf('%s for Neuron %d', app.signal_type, neuron_id));
            end
            xlabel(app.UIAxes, 'Time (s)');
            ylabel(app.UIAxes, ylabel_str);
            grid(app.UIAxes, 'on');
            if app.display_all
                legend(app.UIAxes, 'show');
            end
            hold(app.UIAxes, 'off');
        end
        
        % Calculate baseline F0
        function F0 = CalculateBaseline(app, fluo_trace)
            if ~strcmpi(app.baseline_time, 'all')
                try
                    time_range = str2num(app.baseline_time);
                    if isempty(time_range)
                        error('Invalid time range format. Use "all" or range like "1:30".');
                    end
                    start_frame = max(1, round(time_range(1) * app.framerate) + 1);
                    if length(time_range) > 1
                        end_frame = min(length(fluo_trace), round(time_range(end) * app.framerate));
                    else
                        end_frame = min(length(fluo_trace), round(time_range * app.framerate));
                    end
                    baseline_trace = fluo_trace(start_frame:end_frame);
                catch
                    warning('Invalid time range specified. Using all data.');
                    baseline_trace = fluo_trace;
                end
            else
                baseline_trace = fluo_trace;
            end
            
            switch app.baseline_method
                case 'Percentile'
                    perc_str = app.percentile_value;
                    if contains(perc_str, ':')
                        range = str2num(perc_str);
                        if length(range) < 2 || any(isnan(range)) || any(range < 0) || any(range > 100)
                            error('Invalid percentile range. Use format "10:20" or single value like "20".');
                        end
                        F0 = mean(prctile(baseline_trace, range));
                    else
                        perc = str2double(perc_str);
                        if isnan(perc) || perc < 0 || perc > 100
                            error('Invalid percentile value. Must be between 0 and 100.');
                        end
                        F0 = prctile(baseline_trace, perc);
                    end
                case 'Polynomial'
                    t = (1:length(fluo_trace))';
                    p = polyfit(t, fluo_trace', app.polynomial_order);
                    F0 = polyval(p, t)';
                case 'Moving Percentile'
                    w_size = round(app.moving_window_sec * app.framerate);
                    q_value = app.moving_percentile;
                    x_w = floor(w_size/2);
                    F0 = arrayfun(@(x) prctile(fluo_trace(max(1,x-x_w):min(length(fluo_trace),x+x_w)), q_value), ...
                        1:length(fluo_trace));
                otherwise
                    error('Unknown baseline method.');
            end
        end
        
        % Update all neurons plot
        function UpdateAllNeuronsPlot(app)
            if isempty(app.dff_data)
                uialert(app.UIFigure, 'No ΔF/F data to display.', 'Display Error');
                return;
            end
            if ~isfield(app, 'display_figure_handles') || isempty(app.display_figure_handles) || ~isvalid(app.display_figure_handles)
                app.display_figure_handles = figure('Name', 'All Neurons ΔF/F');
            end
            plot_signal_data = app.dff_data;
            if strcmp(app.signal_type, 'z-score ΔF/F')
                plot_signal_data = app.zscore_dff_data;
            end
            plot.plot_signal(plot_signal_data, ...
                'frame_rate', app.framerate, ...
                'color_map', app.color_map, ...
                'signal_type', app.signal_type, ...
                'fig', app.display_figure_handles, ...
                'scalebar_signal', app.scalebar_signal, ...
                'plot_scale_bar_time', app.plot_scale_bar_time, ...
                'scalebar_time', app.scalebar_time, ...
                'selected_roi_str', app.selected_roi_str, ...
                'roi_interval', app.roi_interval);
        end
    end
    
    % Callbacks that handle component events
    methods (Access = private)
        
        % Startup function
        function startupFcn(app)
            assignin('base', 'app', app);
            app.RunAnalysisButton.Enable = 'off';
            app.NeuronDropDown.Enable = 'off';
            app.PreviousNeuronButton.Enable = 'off';
            app.NextNeuronButton.Enable = 'off';
            app.SaveResultsButton.Enable = 'off';
            app.DisplayAllNeuronsButton.Enable = 'off';
            app.NeuronDropDown.Items = {'N/A'};
            app.NeuronDropDown.Value = 'N/A';
            app.SignalTypeDropDown.Items = {'Raw Signal'};
            app.SignalTypeDropDown.Enable = 'off';
            title(app.UIAxes, 'Load Data to Begin');
            app.FramerateEditField.Value = app.framerate;
            app.CalculateZScoreCheckBox.Value = app.calculate_zscore;
            app.PercentileEditField.Value = app.percentile_value;
            app.BaselineTimeEditField.Value = app.baseline_time;
            app.PolynomialOrderEditField.Value = app.polynomial_order;
            app.MovingWindowEditField.Value = app.moving_window_sec;
            app.MovingPercentileEditField.Value = app.moving_percentile;
            app.BaselineMethodDropDown.Value = app.baseline_method;
            app.ScalebarSignalEditField.Value = app.scalebar_signal;
            app.PlotScaleBarTimeCheckBox.Value = app.plot_scale_bar_time;
            app.ScalebarTimeEditField.Value = app.scalebar_time;
            app.SelectedROIEditField.Value = app.selected_roi_str;
            app.ROIIntervalEditField.Value = app.roi_interval;
            app.ColorMapEditField.Value = app.color_map;
        end
        
        % Load data button pushed
        function LoadDataButtonPushed(app, event)
            f_dummy = figure('Position', [-100 -100 0 0],'CloseRequestFcn','');
            [fileName, filePath] = uigetfile({'*.mat';'*.xlsx;*.xls'}, 'Select Data File');
            delete(f_dummy);
            if isequal(fileName, 0) || isequal(filePath, 0)
                uialert(app.UIFigure, 'No file selected.', 'File Load');
                return;
            end
            fullPath = fullfile(filePath, fileName);
            [~, ~, ext] = fileparts(fileName);
            app.framerate = app.FramerateEditField.Value;
            try
                if strcmpi(ext, '.mat')
                    dataLoaded = load(fullPath);
                    varNames = fieldnames(dataLoaded);
                    if isempty(varNames)
                        uialert(app.UIFigure, 'MAT file is empty.', 'Load Error'); return;
                    end
                    if length(varNames) == 1
                        app.fluo_data = dataLoaded.(varNames{1});
                    else
                        f_dummy = figure('Position', [-100 -100 0 0],'CloseRequestFcn','');
                        [indx, tf] = listdlg('PromptString', {'Select fluorescence variable: (rows=neurons, cols=frames)'}, ...
                            'SelectionMode', 'single', 'ListString', varNames, ...
                            'Name', 'Select Variable', 'OKString', 'Select');
                        delete(f_dummy);
                        if tf
                            app.fluo_data = dataLoaded.(varNames{indx});
                        else
                            uialert(app.UIFigure, 'No variable selected.', 'Load Error'); return;
                        end
                    end
                elseif any(strcmpi(ext, {'.xlsx', '.xls'}))
                    sheetNames = sheetnames(fullPath);
                    if isempty(sheetNames)
                        uialert(app.UIFigure, 'Excel file has no sheets.', 'Load Error'); return;
                    end
                    if length(sheetNames) == 1
                        app.fluo_data = readmatrix(fullPath, 'Sheet', sheetNames{1});
                    else
                        f_dummy = figure('Position', [-100 -100 0 0],'CloseRequestFcn','');
                        [indx, tf] = listdlg('PromptString', {'Select sheet: (rows=neurons, cols=frames)'}, ...
                            'SelectionMode', 'single', 'ListString', sheetNames, ...
                            'Name', 'Select Sheet', 'OKString', 'Select');
                        delete(f_dummy);
                        if tf
                            app.fluo_data = readmatrix(fullPath, 'Sheet', sheetNames{indx});
                        else
                            uialert(app.UIFigure, 'No sheet selected.', 'Load Error'); return;
                        end
                    end
                else
                    uialert(app.UIFigure, 'Unsupported file type.', 'Load Error'); return;
                end
                if (~ismatrix(app.fluo_data) || isempty(app.fluo_data) || ~isnumeric(app.fluo_data))
                    uialert(app.UIFigure, 'Selected data is not a valid numeric matrix or is empty.', 'Data Error');
                    app.fluo_data = []; return;
                end
                [num_neurons, num_frames] = size(app.fluo_data);
                app.time_vector = (0:num_frames-1) / app.framerate;
                app.dff_data = [];
                app.zscore_dff_data = [];
                app.RunAnalysisButton.Enable = 'on';
                app.NeuronDropDown.Enable = 'on';
                app.PreviousNeuronButton.Enable = 'on';
                app.NextNeuronButton.Enable = 'on';
                app.DisplayAllNeuronsButton.Enable = 'on';
                app.NeuronDropDown.Items = arrayfun(@(x) sprintf('Neuron %d', x), 1:num_neurons, 'UniformOutput', false);
                app.NeuronDropDown.Value = 'Neuron 1';
                app.current_neuron_id = 1;
                app.signal_type = 'Raw Signal';
                app.SignalTypeDropDown.Items = {'Raw Signal'};
                app.SignalTypeDropDown.Value = 'Raw Signal';
                app.SignalTypeDropDown.Enable = 'on';
                UpdatePlot(app);
                uialert(app.UIFigure, sprintf('Data loaded: %d neurons, %d frames.', num_neurons, num_frames), ...
                    'Load Success', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ['Error loading data: ' ME.message], 'Load Error');
                app.fluo_data = [];
                app.dff_data = [];
                app.zscore_dff_data = [];
                app.RunAnalysisButton.Enable = 'off';
                app.SignalTypeDropDown.Enable = 'off';
            end
        end
        
        % Run analysis button pushed
        function RunAnalysisButtonPushed(app, event)
            if isempty(app.fluo_data)
                uialert(app.UIFigure, 'No data loaded to analyze.', 'Analysis Error');
                return;
            end
            app.calculate_zscore = app.CalculateZScoreCheckBox.Value;
            app.baseline_method = app.BaselineMethodDropDown.Value;
            app.percentile_value = app.PercentileEditField.Value;
            app.baseline_time = app.BaselineTimeEditField.Value;
            app.polynomial_order = app.PolynomialOrderEditField.Value;
            app.moving_window_sec = app.MovingWindowEditField.Value;
            app.moving_percentile = app.MovingPercentileEditField.Value;
            
            try
                if app.framerate <= 0
                    error('Framerate must be positive.');
                end
                if ~strcmpi(app.baseline_time, 'all')
                    time_range = str2num(app.baseline_time);
                        if isempty(time_range) || any(time_range < 0)
                            error('Invalid baseline time range. Use "all" or range like "1:30".');
                        end
                end
                if strcmp(app.baseline_method, 'Percentile')
                    perc_str = app.percentile_value;
                    if contains(perc_str, ':')
                        range = str2num(perc_str);
                        if length(range) < 2 || any(isnan(range)) || any(range < 0) || any(range > 100)
                            error('Invalid percentile range. Use format "10:20" or single value like "20".');
                        end
                    else
                        perc = str2double(perc_str);
                        if isnan(perc) || perc < 0 || perc > 100
                            error('Invalid percentile value. Must be between 0 and 100.');
                        end
                    end
                elseif strcmp(app.baseline_method, 'Polynomial')
                    if app.polynomial_order < 1 || mod(app.polynomial_order, 1) ~= 0
                        error('Polynomial order must be a positive integer.');
                    end
                elseif strcmp(app.baseline_method, 'Moving Percentile')
                    if app.moving_window_sec <= 0
                        error('Moving window size must be positive.');
                    end
                    if app.moving_percentile < 0 || app.moving_percentile > 100
                        error('Moving percentile must be between 0 and 100.');
                    end
                end
            catch ME
                uialert(app.UIFigure, ['Parameter error: ' ME.message], 'Parameter Error');
                return;
            end
            
            progDlg = uiprogressdlg(app.UIFigure, 'Title', 'Computing Signals', ...
                'Message', 'Initializing...', 'Cancelable', 'on');
            [num_neurons, num_frames] = size(app.fluo_data);
            app.dff_data = zeros(num_neurons, num_frames);
            if app.calculate_zscore
                app.zscore_dff_data = zeros(num_neurons, num_frames);
            else
                app.zscore_dff_data = [];
            end
            app.results = struct('neuron_id', {}, 'dff_trace', {}, 'zscore_dff_trace', {});
            cleanupObj = onCleanup(@() delete(progDlg));
            for n = 1:num_neurons
                if progDlg.CancelRequested
                    uialert(app.UIFigure, 'Analysis cancelled by user.', 'Analysis Cancelled');
                    app.dff_data = [];
                    app.zscore_dff_data = [];
                    app.results = [];
                    return;
                end
                progDlg.Message = sprintf('Processing Neuron %d/%d', n, num_neurons);
                progDlg.Value = n / num_neurons;
                fluo_trace = app.fluo_data(n, :);
                app.results(n).neuron_id = n;
                try
                    F0 = CalculateBaseline(app, fluo_trace);
                    dff_trace = (fluo_trace - F0) ./ F0;
                    app.dff_data(n, :) = dff_trace;
                    app.results(n).dff_trace = dff_trace;
                    if app.calculate_zscore
                        app.zscore_dff_data(n, :) = (dff_trace - mean(dff_trace)) / std(dff_trace);
                        app.results(n).zscore_dff_trace = app.zscore_dff_data(n, :);
                    else
                        app.results(n).zscore_dff_trace = [];
                    end
                catch ME
                    uialert(app.UIFigure, sprintf('Error computing signals for neuron %d: %s', n, ME.message), ...
                        'Computation Error');
                    app.dff_data = [];
                    app.zscore_dff_data = [];
                    app.results = [];
                    return;
                end
            end
            
            neuronItems = arrayfun(@(x) sprintf('Neuron %d', x), 1:num_neurons, 'UniformOutput', false);
            if isempty(neuronItems)
                neuronItems = {'N/A'};
                app.current_neuron_id = 0;
            else
                if strcmp(app.NeuronDropDown.Items{1}, 'N/A') || app.current_neuron_id > num_neurons
                    app.current_neuron_id = 1;
                end
            end
            
            app.NeuronDropDown.Items = neuronItems;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            app.NeuronDropDown.Enable = 'on';
            app.PreviousNeuronButton.Enable = 'on';
            app.NextNeuronButton.Enable = 'on';
            app.SaveResultsButton.Enable = 'on';
            app.DisplayAllNeuronsButton.Enable = 'on';
            app.SignalTypeDropDown.Items = {'Raw Signal', 'ΔF/F'};
            app.signal_type = 'ΔF/F';
            if app.calculate_zscore
                app.SignalTypeDropDown.Items = {'Raw Signal', 'ΔF/F', 'z-score ΔF/F'};
            end
            app.SignalTypeDropDown.Value = 'ΔF/F';
            UpdatePlot(app);
        end
        
        % Signal type dropdown value changed
        function SignalTypeDropDownValueChanged(app, event)
            app.signal_type = app.SignalTypeDropDown.Value;
            app.display_all = false;
            UpdatePlot(app);
        end
        
        % Neuron dropdown value changed
        function NeuronDropDownValueChanged(app, event)
            if strcmp(app.NeuronDropDown.Value, 'N/A')
                app.current_neuron_id = 0;
                UpdatePlot(app);
                return;
            end
            selectedNeuronStr = app.NeuronDropDown.Value;
            app.current_neuron_id = str2double(regexp(selectedNeuronStr, '\d+', 'match', 'once'));
            app.display_all = false;
            UpdatePlot(app);
        end
        
        % Previous neuron button pushed
        function PreviousNeuronButtonPushed(app, event)
            if isempty(app.fluo_data) || app.current_neuron_id <= 1
                return;
            end
            app.current_neuron_id = app.current_neuron_id - 1;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            app.display_all = false;
            UpdatePlot(app);
        end
        
        % Next neuron button pushed
        function NextNeuronButtonPushed(app, event)
            if isempty(app.fluo_data) || app.current_neuron_id >= size(app.fluo_data, 1)
                return;
            end
            app.current_neuron_id = app.current_neuron_id + 1;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            app.display_all = false;
            UpdatePlot(app);
        end
        
        % Update all neurons plot button pushed
        function DisplayAllNeuronsButtonPushed(app, event)
            app.scalebar_signal = app.ScalebarSignalEditField.Value;
            app.plot_scale_bar_time = app.PlotScaleBarTimeCheckBox.Value;
            app.scalebar_time = app.ScalebarTimeEditField.Value;
            app.selected_roi_str = app.SelectedROIEditField.Value;
            app.roi_interval = app.ROIIntervalEditField.Value;
            app.color_map = app.ColorMapEditField.Value;
            app.display_all = true;
            % UpdatePlot(app);
            UpdateAllNeuronsPlot(app);
        end
        
        % Save results button pushed
        function SaveResultsButtonPushed(app, event)
            if isempty(app.fluo_data)
                uialert(app.UIFigure, 'No results to save.', 'Save Error');
                return;
            end
            % 添加一个进度条
            [fileName, filePath] = uiputfile({'*.mat', 'MAT-file (*.mat)'}, 'Save Results');
            if isequal(fileName, 0) || isequal(filePath, 0)
                uialert(app.UIFigure, 'Save cancelled.', 'Save Operation');
                return;
            end
            progressDlg = uiprogressdlg(app.UIFigure,'Title','Saving Data','Indeterminate','on');
            drawnow
            [~, name, ~] = fileparts(fileName);
            matPath = fullfile(filePath, [name '.mat']);
            xlsxPath = fullfile(filePath, [name '.xlsx']);
            raw_sig = app.fluo_data;
            dff_sig = app.dff_data;
            zscore_dff_sig = app.zscore_dff_data;
            time_vector = app.time_vector;
            framerate = app.framerate;
            calculate_zscore = app.calculate_zscore;
            baseline_method = app.baseline_method;
            percentile_value = app.percentile_value;
            baseline_time = app.baseline_time;
            polynomial_order = app.polynomial_order;
            moving_window_sec = app.moving_window_sec;
            moving_percentile = app.moving_percentile;
            scalebar_signal = app.scalebar_signal;
            plot_scale_bar_time = app.plot_scale_bar_time;
            scalebar_time = app.scalebar_time;
            selected_roi_str = app.selected_roi_str;
            roi_interval = app.roi_interval;
            color_map = app.color_map;
            analysis_date = datestr(now);
            try
                % Create a struct with method-specific parameters to save
                saveParams = struct('raw_sig', raw_sig, 'dff_sig', dff_sig, ...
                    'time_vector', time_vector, 'framerate', framerate, ...
                    'calculate_zscore', calculate_zscore, 'baseline_method', baseline_method, ...
                    'scalebar_signal', scalebar_signal, 'plot_scale_bar_time', plot_scale_bar_time, ...
                    'scalebar_time', scalebar_time, 'selected_roi_str', selected_roi_str, ...
                    'roi_interval', roi_interval, 'color_map', color_map, 'analysis_date', analysis_date);
                
                % Add z-score data if calculated
                if app.calculate_zscore
                    saveParams.zscore_dff_sig = zscore_dff_sig;
                end
                
                % Add method-specific parameters
                if strcmp(baseline_method, 'Percentile')
                    saveParams.percentile_value = percentile_value;
                    saveParams.baseline_time = baseline_time;
                elseif strcmp(baseline_method, 'Polynomial')
                    saveParams.polynomial_order = polynomial_order;
                elseif strcmp(baseline_method, 'Moving Percentile')
                    saveParams.moving_window_sec = moving_window_sec;
                    saveParams.moving_percentile = moving_percentile;
                end
                
                % Save the parameters to MAT file
                save(matPath, '-struct', 'saveParams', '-v7.3');
                % Convert matrices to tables with time information for better Excel output
                
                % Create table for raw signals with neuron columns
                raw_sig_table = array2table(raw_sig');
                var_names = arrayfun(@(x) sprintf('Neuron_%d', x), 1:size(raw_sig,1), 'UniformOutput', false);
                raw_sig_table.Properties.VariableNames = var_names;
                
                % Create table for dff signals
                dff_sig_table = array2table(dff_sig');
                dff_sig_table.Properties.VariableNames = var_names;
                
                % Write tables to Excel file
                writetable(raw_sig_table, xlsxPath, 'Sheet', 'raw_sig',WriteMode='replacefile');
                writetable(dff_sig_table, xlsxPath, 'Sheet', 'dff_sig',WriteMode='inplace');
                
                % Write z-score data if available
                if app.calculate_zscore
                    zscore_sig_table = array2table(zscore_dff_sig');
                    zscore_sig_table.Properties.VariableNames = var_names;
                    writetable(zscore_sig_table, xlsxPath, 'Sheet', 'zscore_dff_sig',WriteMode='inplace');
                end
                
                % Create a parameters table for easy reference
                % Create parameters table based on selected baseline method
                params_headers = {'Framerate_Hz', 'Analysis_Date', 'Calculate_ZScore'};
                params_values = {framerate, analysis_date, calculate_zscore};
                
                % Add method-specific parameters
                params_headers = [params_headers, 'Baseline_Method'];
                params_values = [params_values, baseline_method];
                
                if strcmp(baseline_method, 'Percentile')
                    params_headers = [params_headers, 'Percentile_Value', 'Baseline_Time'];
                    params_values = [params_values, percentile_value, baseline_time];
                elseif strcmp(baseline_method, 'Polynomial')
                    params_headers = [params_headers, 'Polynomial_Order'];
                    params_values = [params_values, polynomial_order];
                elseif strcmp(baseline_method, 'Moving Percentile')
                    params_headers = [params_headers, 'Moving_Window_sec', 'Moving_Percentile'];
                    params_values = [params_values, moving_window_sec, moving_percentile];
                end
                
                params_table = array2table(params_values', 'VariableNames', {'Value'}, 'RowNames', params_headers');
                writetable(params_table, xlsxPath, 'Sheet', 'Parameters', 'WriteRowNames', true, WriteMode='inplace');
                close(progressDlg);
                uialert(app.UIFigure, sprintf('Results saved to:\n%s\n%s', matPath, xlsxPath), ...
                    'Save Success', 'Icon', 'success');
            catch ME
                close(progressDlg);
                uialert(app.UIFigure, ['Error saving results: ' ME.message], 'Save Error');
            end
        end
        
        % Baseline method dropdown value changed
        function BaselineMethodDropDownValueChanged(app, event)
            app.baseline_method = app.BaselineMethodDropDown.Value;
            app.PercentileEditField.Enable = strcmp(app.baseline_method, 'Percentile');
            app.BaselineTimeEditField.Enable = strcmp(app.baseline_method, 'Percentile');
            app.PolynomialOrderEditField.Enable = strcmp(app.baseline_method, 'Polynomial');
            app.MovingWindowEditField.Enable = strcmp(app.baseline_method, 'Moving Percentile');
            app.MovingPercentileEditField.Enable = strcmp(app.baseline_method, 'Moving Percentile');
        end
    end
    
    % Component initialization
    methods (Access = private)
        
        % Create UI components
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 750]; % Increased height from 700 to 750
            app.UIFigure.Name = 'Calcium ΔF/F Calculator';
            
            % File Operations Panel
            app.FileOperationsPanel = uipanel(app.UIFigure);
            app.FileOperationsPanel.Title = 'File Operations';
            app.FileOperationsPanel.Position = [20 620 300 100]; % Adjusted y-position
            app.FramerateHzLabel = uilabel(app.FileOperationsPanel);
            app.FramerateHzLabel.HorizontalAlignment = 'right';
            app.FramerateHzLabel.Position = [10 40 90 22];
            app.FramerateHzLabel.Text = 'Framerate (Hz):';
            app.FramerateEditField = uieditfield(app.FileOperationsPanel, 'numeric');
            app.FramerateEditField.ValueDisplayFormat = '%.2f';
            app.FramerateEditField.Position = [110 40 100 22];
            app.FramerateEditField.Value = app.framerate;
            app.LoadDataButton = uibutton(app.FileOperationsPanel, 'push');
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);
            app.LoadDataButton.Position = [10 10 100 22];
            app.LoadDataButton.Text = 'Load Data';
            
            % Delta F/F Calculate Panel
            app.DeltaFOverFCalculatePanel = uipanel(app.UIFigure);
            app.DeltaFOverFCalculatePanel.Title = 'ΔF/F Calculate';
            app.DeltaFOverFCalculatePanel.Position = [20 365 300 250]; % Increased height from 220 to 250
            app.CalculateZScoreCheckBox = uicheckbox(app.DeltaFOverFCalculatePanel);
            app.CalculateZScoreCheckBox.Text = 'Calculate z-score ΔF/F';
            app.CalculateZScoreCheckBox.Position = [10 205 150 22];
            app.CalculateZScoreCheckBox.Value = app.calculate_zscore;
            app.BaselineMethodDropDownLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.BaselineMethodDropDownLabel.HorizontalAlignment = 'right';
            app.BaselineMethodDropDownLabel.Position = [10 178 100 22];
            app.BaselineMethodDropDownLabel.Text = 'Baseline Method:';
            app.BaselineMethodDropDown = uidropdown(app.DeltaFOverFCalculatePanel);
            app.BaselineMethodDropDown.Items = {'Percentile', 'Polynomial', 'Moving Percentile'};
            app.BaselineMethodDropDown.ValueChangedFcn = createCallbackFcn(app, @BaselineMethodDropDownValueChanged, true);
            app.BaselineMethodDropDown.Position = [120 178 150 22];
            app.BaselineMethodDropDown.Value = app.baseline_method;
            app.PercentileEditFieldLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.PercentileEditFieldLabel.HorizontalAlignment = 'right';
            app.PercentileEditFieldLabel.Position = [10 150 100 22];
            app.PercentileEditFieldLabel.Text = 'Percentile';
            app.PercentileEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'text');
            app.PercentileEditField.Position = [120 150 150 22];
            app.PercentileEditField.Value = app.percentile_value;
            app.PercentileEditField.Placeholder = '10:20 or 20';
            app.BaselineTimeLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.BaselineTimeLabel.HorizontalAlignment = 'right';
            app.BaselineTimeLabel.Position = [10 122 100 22];
            app.BaselineTimeLabel.Text = 'Baseline Time(s):';
            app.BaselineTimeEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'text');
            app.BaselineTimeEditField.Position = [120 122 150 22];
            app.BaselineTimeEditField.Value = app.baseline_time;
            app.BaselineTimeEditField.Placeholder = 'all or 1:30';
            app.PolynomialOrderLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.PolynomialOrderLabel.HorizontalAlignment = 'right';
            app.PolynomialOrderLabel.Position = [10 94 100 22];
            app.PolynomialOrderLabel.Text = 'Polynomial Order:';
            app.PolynomialOrderEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'numeric');
            app.PolynomialOrderEditField.ValueDisplayFormat = '%d';
            app.PolynomialOrderEditField.Position = [120 94 150 22];
            app.PolynomialOrderEditField.Value = app.polynomial_order;
            app.PolynomialOrderEditField.Enable = 'off';
            app.MovingWindowLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.MovingWindowLabel.HorizontalAlignment = 'right';
            app.MovingWindowLabel.Position = [10 66 100 22];
            app.MovingWindowLabel.Text = 'Window Size (s):';
            app.MovingWindowEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'numeric');
            app.MovingWindowEditField.ValueDisplayFormat = '%.2f';
            app.MovingWindowEditField.Position = [120 66 150 22];
            app.MovingWindowEditField.Value = app.moving_window_sec;
            app.MovingWindowEditField.Enable = 'off';
            app.MovingPercentileLabel = uilabel(app.DeltaFOverFCalculatePanel);
            app.MovingPercentileLabel.HorizontalAlignment = 'right';
            app.MovingPercentileLabel.Position = [10 38 100 22];
            app.MovingPercentileLabel.Text = 'Moving Percentile:';
            app.MovingPercentileEditField = uieditfield(app.DeltaFOverFCalculatePanel, 'numeric');
            app.MovingPercentileEditField.ValueDisplayFormat = '%.2f';
            app.MovingPercentileEditField.Position = [120 38 150 22];
            app.MovingPercentileEditField.Value = app.moving_percentile;
            app.MovingPercentileEditField.Enable = 'off';
            app.RunAnalysisButton = uibutton(app.DeltaFOverFCalculatePanel, 'push');
            app.RunAnalysisButton.ButtonPushedFcn = createCallbackFcn(app, @RunAnalysisButtonPushed, true);
            app.RunAnalysisButton.Position = [10 10 100 22];
            app.RunAnalysisButton.Text = 'Run Analysis';
            app.SaveResultsButton = uibutton(app.DeltaFOverFCalculatePanel, 'push');
            app.SaveResultsButton.ButtonPushedFcn = createCallbackFcn(app, @SaveResultsButtonPushed, true);
            app.SaveResultsButton.Position = [115 10 100 22];
            app.SaveResultsButton.Text = 'Save Results';
            % Neuron Display Panel
            app.NeuronDisplayPanel = uipanel(app.UIFigure);
            app.NeuronDisplayPanel.Title = 'Neuron Display';
            app.NeuronDisplayPanel.Position = [20 245 300 110]; % Adjusted y-position
            app.SelectNeuronLabel = uilabel(app.NeuronDisplayPanel);
            app.SelectNeuronLabel.HorizontalAlignment = 'right';
            app.SelectNeuronLabel.Position = [10 65 85 22];
            app.SelectNeuronLabel.Text = 'Select Neuron:';
            app.NeuronDropDown = uidropdown(app.NeuronDisplayPanel);
            app.NeuronDropDown.ValueChangedFcn = createCallbackFcn(app, @NeuronDropDownValueChanged, true);
            app.NeuronDropDown.Position = [105 65 170 22];
            app.PreviousNeuronButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.PreviousNeuronButton.ButtonPushedFcn = createCallbackFcn(app, @PreviousNeuronButtonPushed, true);
            app.PreviousNeuronButton.Position = [10 35 85 22];
            app.PreviousNeuronButton.Text = 'Previous';
            app.NextNeuronButton = uibutton(app.NeuronDisplayPanel, 'push');
            app.NextNeuronButton.ButtonPushedFcn = createCallbackFcn(app, @NextNeuronButtonPushed, true);
            app.NextNeuronButton.Position = [105 35 85 22];
            app.NextNeuronButton.Text = 'Next';

            
            % All Neurons Display Panel
            app.AllNeuronsDisplayPanel = uipanel(app.UIFigure);
            app.AllNeuronsDisplayPanel.Title = 'All Neurons Display';
            app.AllNeuronsDisplayPanel.Position = [20 30 300 200];
            app.DisplayAllNeuronsButton = uibutton(app.AllNeuronsDisplayPanel, 'push');
            app.DisplayAllNeuronsButton.ButtonPushedFcn = createCallbackFcn(app, @DisplayAllNeuronsButtonPushed, true);
            app.DisplayAllNeuronsButton.Position = [10 155 140 22];
            app.DisplayAllNeuronsButton.Text = 'Display All Neurons';
            app.ScalebarSignalLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ScalebarSignalLabel.HorizontalAlignment = 'left';
            app.ScalebarSignalLabel.Position = [10 125 130 22];
            app.ScalebarSignalLabel.Text = 'Scalebar Signal:';
            app.ScalebarSignalEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ScalebarSignalEditField.Position = [170 125 100 22];
            app.ScalebarSignalEditField.Value = app.scalebar_signal;
            app.PlotScaleBarTimeCheckBox = uicheckbox(app.AllNeuronsDisplayPanel);
            app.PlotScaleBarTimeCheckBox.Text = 'Plot Time Scalebar';
            app.PlotScaleBarTimeCheckBox.Position = [10 95 120 22];
            app.PlotScaleBarTimeCheckBox.Value = app.plot_scale_bar_time;
            app.ScalebarTimeLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ScalebarTimeLabel.HorizontalAlignment = 'right';
            app.ScalebarTimeLabel.Position = [130 95 80 22];
            app.ScalebarTimeLabel.Text = 'Scalebar';
            app.ScalebarTimeEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ScalebarTimeEditField.Position = [220 95 50 22];
            app.ScalebarTimeEditField.Value = app.scalebar_time;
            app.SelectedROILabel = uilabel(app.AllNeuronsDisplayPanel);
            app.SelectedROILabel.HorizontalAlignment = 'right';
            app.SelectedROILabel.Position = [10 65 80 22];
            app.SelectedROILabel.Text = 'Selected ROI:';
            app.SelectedROIEditField = uieditfield(app.AllNeuronsDisplayPanel, 'text');
            app.SelectedROIEditField.Position = [100 65 170 22];
            app.SelectedROIEditField.Value = app.selected_roi_str;
            app.SelectedROIEditField.Placeholder = '1:5,7:9';
            app.ROIIntervalLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ROIIntervalLabel.HorizontalAlignment = 'right';
            app.ROIIntervalLabel.Position = [10 35 80 22];
            app.ROIIntervalLabel.Text = 'ROI Interval:';
            app.ROIIntervalEditField = uieditfield(app.AllNeuronsDisplayPanel, 'numeric');
            app.ROIIntervalEditField.Position = [100 35 170 22];
            app.ROIIntervalEditField.Value = app.roi_interval;
            app.ColorMapLabel = uilabel(app.AllNeuronsDisplayPanel);
            app.ColorMapLabel.HorizontalAlignment = 'right';
            app.ColorMapLabel.Position = [10 5 80 22];
            app.ColorMapLabel.Text = 'Color Map:';
            app.ColorMapEditField = uieditfield(app.AllNeuronsDisplayPanel, 'text');
            app.ColorMapEditField.Position = [100 5 170 22];
            app.ColorMapEditField.Value = app.color_map;
            app.ColorMapEditField.Placeholder = 'colormap(e.g.,turbo) or fixed(e.g., #ff0000)';
            
            % UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Signal')
            xlabel(app.UIAxes, 'Time (s)')
            ylabel(app.UIAxes, 'Raw Signal')
            app.UIAxes.Position = [350 50 800 650]; % Increased height from 600 to 650
            grid(app.UIAxes, 'on');
            
            % Signal Type Dropdown
            app.SignalTypeDropDown = uidropdown(app.UIFigure);
            app.SignalTypeDropDown.Items = {'Raw Signal'};
            app.SignalTypeDropDown.Value = 'Raw Signal';
            app.SignalTypeDropDown.ValueChangedFcn = createCallbackFcn(app, @SignalTypeDropDownValueChanged, true);
            app.SignalTypeDropDown.Position = [360 710 100 22]; % Adjusted y-position
            app.SignalTypeDropDown.Enable = 'off';
            
            app.UIFigure.Visible = 'on';
        end
    end
    
    % App creation and deletion
    methods (Access = public)
        function app = CalciumDeltaFCaculator
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            delete(app.UIFigure)
            if isfield(app, 'display_figure_handles') && isvalid(app.display_figure_handles)
                delete(app.display_figure_handles);
            end
        end
    end
end