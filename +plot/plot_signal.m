function fig = plot_signal(signal_delta, ops)
    % Function to plot signals with given parameters
    arguments
        signal_delta % matrix of signal data
        ops.spacing = 0.1 % spacing between signals
        ops.frame_rate = 1 % frame rate for time calculation
        ops.scalebar_signal = 1 % scale bar for signal
        ops.scalebar_time = 50 % scale bar for time
        ops.color_map = 'turbo' % colormap choice or hex color code starting with '#'
        ops.plot_scale_bar_time = false % boolean to plot time scale bar
        ops.signal_type = 'ΔF/F' % type of signal
        ops.selected_roi_str = '' % string of selected ROIs
        ops.roi_prefix = 'c' % prefix for ROI labels
        ops.xlim = '0:end' % x-axis limits in seconds, can be a string like '0:end', '1:10' or a numeric array [start, end]
        ops.xtick_interval = [] % interval for x-axis ticks in seconds
        ops.event = struct('start', 0, 'end', 0, 'name', '', 'color', '#000000') % event details in seconds
        ops.roi_interval = 1 % interval for displaying ROI labels
        ops.original_indices = [] % original indices for sorted signals
        ops.sort = false % whether to sort the signals
        ops.fig = [] % figure handle for plotting
    end
    
    [numNeurons, n_frame] = size(signal_delta);
    
    % Sort the signals if required
    original_indices = ops.original_indices;
    if ops.sort
        % Sort the signals by their average values
        distance_matrix = pdist(signal_delta, 'euclidean');
        % Perform hierarchical clustering
        linkage_tree = linkage(distance_matrix, 'average');
        % Determine the order of rows based on clustering
        cluster_order = optimalleaforder(linkage_tree, distance_matrix);
        % Reverse the cluster order
        cluster_order = flip(cluster_order);
        % Sort the matrix data based on clustering
        signal_delta = signal_delta(cluster_order, :);
        
        % Store original indices for labeling
        if isempty(original_indices)
            original_indices = cluster_order;
        else
            original_indices = original_indices(cluster_order);
        end
    end
    
    time = (1:n_frame) / ops.frame_rate;
    
    % Determine selected ROIs
    if isempty(ops.selected_roi_str)
        roi_indexs = 1:numNeurons;
    else
        specified_roi = sort(str2num(ops.selected_roi_str));
        % 去重
        specified_roi = unique(specified_roi);
        index_filter = (specified_roi >= 1) & (specified_roi <= numNeurons);
        roi_indexs = specified_roi(index_filter);
    end
    roi_indexs = flip(roi_indexs);
    selected_roi_num = length(roi_indexs);
    y_ticks = zeros(1, selected_roi_num);
    
    % Create a figure and axes
    figure_size = [20, selected_roi_num];
    if isempty(ops.fig)
        fig = figure('Units', 'centimeters');
        fig.Position(3:4) = figure_size;
    else
        fig = ops.fig;
        figure(fig); % 激活传入的figure对象
        clf(fig); % 清除当前figure的内容
        fig.Units = 'centimeters';
        % fig.Position(3:4) = figure_size;
    end
    ax = gca;
    hold(ax, 'on');
    ax.TickDir = 'out';
    
    % Plot each neuron's activity
    for i = 1:selected_roi_num
        i_roi = roi_indexs(i);
        i_delta_signal = signal_delta(i_roi, :);
        
        if i == 1
            signal_1_min = min(i_delta_signal);
            signal_1_max = max(i_delta_signal);
        end
        
        % Determine color
        if ischar(ops.color_map) && startsWith(ops.color_map, '#')
            % Use hex color for all signals
            roi_color = hex2matrix(ops.color_map)/255;
        elseif ischar(ops.color_map) && strcmpi(ops.color_map, 'random')
            % Use random colormap
            colormaps = create_random_colormap(selected_roi_num);
            roi_color = colormaps(i, :) / 255;  % 转换为 0-1 范围
        else
            % Use colormap as before
            colormaps = feval(ops.color_map, selected_roi_num);
            roi_color = colormaps(i, :);
        end
        
        % Plot signal
        
        if i > 1
            i_roi_height = y_ticks(i-1) +max(signal_delta(:, :),[],"all")*0.5;
        else
            i_roi_height = 0;
        end
        plot(ax, time, i_roi_height + i_delta_signal, 'Color', roi_color, 'LineWidth', 1.5);
        y_ticks(i) = i_roi_height+i_delta_signal(1,1);
        
        if i == selected_roi_num
            last_signal_height = max(i_delta_signal);
        end
    end
    % 处理 xlim 参数
    if ischar(ops.xlim) || isstring(ops.xlim)
        if strcmpi(ops.xlim, '0:end') || strcmpi(ops.xlim, '') || strcmpi(ops.xlim, '0')
            % 默认情况：显示全部范围
            ax.XLim = [0, time(end)];
        else
            % 尝试解析字符串格式的范围，如 '1:10'
            try
                parts = split(ops.xlim, ':');
                if length(parts) == 2
                    xlim_start = str2double(parts{1});
                    if strcmpi(parts{2}, 'end')
                        xlim_end = time(end);
                    else
                        xlim_end = str2double(parts{2});
                    end
                    
                    % 确保范围有效
                    xlim_start = max(0, xlim_start);
                    xlim_end = min(time(end), xlim_end);
                    if xlim_start < xlim_end
                        ax.XLim = [xlim_start, xlim_end];
                    else
                        ax.XLim = [0, time(end)];
                    end
                else
                    ax.XLim = [0, time(end)];
                end
            catch
                ax.XLim = [0, time(end)];
            end
        end
    elseif isnumeric(ops.xlim) && length(ops.xlim) == 2
        % 数值型 xlim [start, end]
        xlim_start = max(0, ops.xlim(1));
        xlim_end = min(time(end), ops.xlim(2));
        if xlim_start < xlim_end
            ax.XLim = [xlim_start, xlim_end];
        else
            ax.XLim = [0, time(end)];
        end
    else
        % 默认情况
        ax.XLim = [0, time(end)];
    end


    % Add scale bars
    scalebar_position_x = ax.XLim(2) * 0.90;
    scalebar_position_y = i_roi_height + last_signal_height + 0.5 * ops.scalebar_signal;
    
    if ops.plot_scale_bar_time
        plot(ax, [scalebar_position_x - ops.scalebar_time, scalebar_position_x, scalebar_position_x], ...
            [scalebar_position_y + ops.scalebar_signal, scalebar_position_y + ops.scalebar_signal, scalebar_position_y], ...
            'k-', 'linewidth', 2);
        text(ax, scalebar_position_x - ops.scalebar_time / 2, scalebar_position_y + ops.scalebar_signal, sprintf('%d s', ops.scalebar_time), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12);
    else
        plot(ax, [scalebar_position_x, scalebar_position_x], [scalebar_position_y + ops.scalebar_signal, scalebar_position_y], 'k-', 'linewidth', 2);
    end
    
    % Add signal label
    switch ops.signal_type
        case 'ΔF/F'
            text(ax, scalebar_position_x + time(end) * 0.005, scalebar_position_y + ops.scalebar_signal / 2, strcat('\Delta',sprintf('F/F=%g%%', ops.scalebar_signal * 100)), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 12);
        case 'zscore'
            text(ax, scalebar_position_x + time(end) * 0.005, scalebar_position_y + ops.scalebar_signal / 2, sprintf('%g\\sigma', ops.scalebar_signal), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 12);
    end
    
    % Add ROI index labels with interval
    if isempty(original_indices)
        roi_names = strcat(ops.roi_prefix, {'{'}, arrayfun(@num2str, roi_indexs, 'UniformOutput', false), {'}'});
    else
        % Use original indices for sorted signals
        original_roi_names = strcat(ops.roi_prefix, {'{'}, arrayfun(@num2str, original_indices(roi_indexs), 'UniformOutput', false), {'}'});
        roi_names = original_roi_names;
    end
    ax.YTick = y_ticks(1:ops.roi_interval:end);
    ax.YTickLabel = roi_names(1:ops.roi_interval:end);
    
    % Beautify plot
    if ops.plot_scale_bar_time
        ax.XAxis.Visible = 'off';
    else
        ax.XAxis.Visible = 'on';
        xlabel(ax, 'Time(s)');
        
        % Set X-axis tick marks if interval is specified
        if (~isempty(ops.xtick_interval) && ops.xtick_interval > 0)
            xtick = 0:ops.xtick_interval:time(end);
            ax.XTick = xtick;
        end
    end
    
    ax.YAxis.Visible = 'on';
    ax.YAxis.TickLength = [0, 0];
    pause(0.5);
    try
        ax.YRuler.Axle.Visible = 'off';
    catch
    end
    
    ax.YLim(2) = scalebar_position_y + ops.scalebar_signal;
    ax.YLim(1) = signal_1_min - ops.spacing;
    
    

    
    % Plot event region
    y_max = ax.YLim(2);
    y_min = ax.YLim(1);
    if ops.event.start > 0 && ops.event.end > 0
        patch(ax, [ops.event.start, ops.event.start, ops.event.end, ops.event.end], ...
            [y_min, y_max, y_max, y_min], utils.hex2matrix(ops.event.color) / 255, ...
            'FaceAlpha', 0.2, 'EdgeColor', 'none', 'DisplayName', ops.event.name);
        
        if ~isempty(ops.event.name)
            text_x = (ops.event.start + ops.event.end) / 2;
            text_y = y_max;
            text(ax, text_x, text_y, ops.event.name, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', 'Color', '#000', 'FontSize', 12);
        end
        
    elseif ops.event.start > 0 && ops.event.end == 0
        plot(ax, [ops.event.start, ops.event.start], [y_min, y_max], '--', 'LineWidth', 1.5, 'Color', ops.event.color);
        
        if ~isempty(ops.event.name)
            text(ax, ops.event.start, y_max, ops.event.name, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', 'Color', '#000', 'FontSize', 12);
        end
    end
    hold off;
end



function rgb = hex2matrix(hexColor)
    % 去掉 '#' 符号
    hexColor = hexColor(2:end);
    % 分割为三个颜色通道，并转换为十进制数
    r = hex2dec(hexColor(1:2));
    g = hex2dec(hexColor(3:4));
    b = hex2dec(hexColor(5:6));
    % 组合为 RGB 数组
    rgb = [r g b];  % 返回 0-255 范围的值
end



function colors = create_random_colormap(numColors)
    % 创建具有美观随机颜色的 colormap
    % numColors: 需要的颜色数量
    goldenRatio = 0.618033988749895; % 黄金分割比例，用于打乱色调
    h = mod((0:numColors - 1) * goldenRatio, 1); % 色调（Hue）均匀分布并打乱
    s = ones(1, numColors) * 0.8; % 饱和度（Saturation）
    v = ones(1, numColors) * 0.95; % 明度（Value）高，保证明亮
    hsvColors = [h; s; v]'; % [numColors x 3]
    colors = hsv2rgb(hsvColors) * 255; % 输出 [numColors x 3] 的RGB颜色矩阵
end