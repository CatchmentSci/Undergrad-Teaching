function [timestamp, normalisedQ, ssc] = HMS_ratingCurve_time(riverId)

% Usage:  [timestamp, normalisedQ, ssc] = HMS_ratingCurve_time({'1001','9004'});

% Required input:
% riverId: The riverId of interest. This corresponds to the monitoring
% codes for each HMS within the database. This should be input as a text
% e.g. {'6009'} (including the brackets and quotation marks)

% Outputs:
% timestamp = time of the sample taking place
% normalisedQ = the normalised discharge estimate for each measurement
% ssc = suspended sediment concentrations

% Load the datasets
outfilename = websave('FlowSed.csv','https://github.com/CatchmentSci/Teaching-2016-17/raw/master/Flow_Sed_Trimmed.csv');
websave('readtext.m', 'https://raw.githubusercontent.com/CatchmentSci/Glaisdale-Beck-diversion-scheme/master/readtext.m'); % Download dependancy
websave('replace.m', 'https://raw.githubusercontent.com/CatchmentSci/Glaisdale-Beck-diversion-scheme/master/replace.m'); % Download dependancy
[data_text,~] = readtext(outfilename, ',', '','','textual'); % read in the comma delimeted data
sample_id = str2double(data_text(1:end,1));
det = str2double(data_text(1:end,2));
result = str2double(data_text(1:end,3));

outfilename2 = websave('tblSample.csv','https://github.com/CatchmentSci/Teaching-2016-17/raw/master/tblSample.csv');
[data_text2,~] = readtext(outfilename2, ',', '','','textual'); % read in the comma delimeted data
data_text2(:,3) = cellfun(@(x) x(1:10), data_text2(1:end,3),'UniformOutput', false); % Extract the dates from the third column
data_text2(:,4) = cellfun(@(x) x(12:end), data_text2(1:end,4),'UniformOutput', false); % Extract the times from the forth column
data_text2(:,5) = strcat(data_text2(:,3), {' '}, data_text2(:,4)); % merge the dates and times

for iter = 1:length(riverId) % loop through each of the stations
    
    cell_id = double(find(strcmp(data_text2(:,2),char(riverId(iter))) == 1)); % Find the measurement associated with the Coquet
    meas_id = str2double(data_text2(cell_id,1)); % Extract the measurement identifier
    [~,idx]=ismember(meas_id,sample_id); % Find the locations of each coquet sample id within the main dataet
    timestamp = data_text2(cell_id,5);
    
    Out = cell(1, numel(meas_id));
    X = [];
    for iA = 1:numel(meas_id)
        Out{iA} = find(sample_id == meas_id(iA));
        splitOut = Out{iA};
        for a = 1:length(splitOut)
            tempDet = det(splitOut(a));
            if isempty(X)
                X(1,1:3) = NaN;
            elseif length(X(:,1)) < iA
                X(iA,1:3) = NaN;
            end
            
            if tempDet == 107
                X(length(X(:,1)),1) = result(splitOut(a)); % average flow in first column
            elseif tempDet == 108
                X(length(X(:,1)),2) = result(splitOut(a)); % instantaneous flow in second column
            elseif tempDet == 114
                X(length(X(:,1)),3) = result(splitOut(a)); % suspended sediment concentration in third column
            end
        end
    end
    
    X = replace(X,0,NaN);
    indUse = find(~isnan(X(:,2))); % Find existing instantaneous Q measurements
    tempQ(1:length(X),1) = NaN;
    tempQ(indUse) = X(indUse,2); % add these measurements to the temporary array
    for a = 1:length(X)
        if isnan(tempQ(a)) && ~isnan(X(a,1)) % If there are no instantaneous measurements, only averaged, use the average ones
            tempQ(a) = X(a,1);
        end
    end
    
    indUse2 = find(~isnan(tempQ(:,1))); % Find Q measurements
    geoMeanQ = geomean(tempQ(indUse2,1));
    normalisedQ = tempQ(:,1)./geoMeanQ(:,1);
    ssc = X(:,3);
    Tnum = datenum(timestamp,'dd/mm/yyyy HH:MM:SS');
    [~,ind] = sort(Tnum); % sort the numeric timestamp by date
    timestamp = timestamp(ind); % sort the timestamp by date
    normalisedQ = normalisedQ(ind); % sort the Q by date
    ssc = ssc(ind); % sort the ssc by date
    ssc = replace(ssc,0,NaN);
    normalisedQ = replace(normalisedQ,0,NaN);
    
    partitionTime = datenum({'01/01/1974 00:00:00', '31/12/1983 23:59:59','01/01/1984 00:00:00', '31/12/1993 23:59:59', '01/01/1994 00:00:00', '31/12/2003 23:59:59', '01/01/2004 00:00:00', '31/12/2014 23:59:59'},'dd/mm/yyyy HH:MM:SS');
    looper = 1;
    graphInd = 1;
    graphtext = [-1.27786498973865 2.21749818912531; 1.34065932572959 2.22046554885796;...
        0.0251177331861926 2.23530234411019; 0.0219780157815545 0.852512973618054];
    while looper < length(partitionTime)+1
        
        ind2use = find(Tnum > partitionTime(looper,1) & Tnum < partitionTime(looper+1,1));
        
        if looper == 1
            h = figure();
            set(h,'units','normalized','outerposition',[0 0 1 1]) % set full screen mode
            set(h,'DefaultTextFontname', 'cmr12');
            set(h,'DefaultAxesFontName', 'cmr12');
            set(h,'DefaultAxesFontSize',14);
        end
        
        log10x = log10(normalisedQ(ind2use)); % Assign the x and y data
        log10x = replace(log10x,0,NaN);
        log10y = log10(ssc(ind2use));
        log10y = replace(log10y,0,NaN);
        log10x1 = log10x;
        length(log10x1);
        log10x1(1:ans,2) = 1; % Prep the data for regression
        [b,bint,r,rint,stats] = regress(log10y,log10x1); % Run the regression
        OriginalLog_r2 = stats(1,1); % Pull out the R2 value
        OriginalLog_p = stats(1,3); % Pull out the p value
        OriginalLog_p = sprintf('%.4f ', [OriginalLog_p]);
        log10a = b(2,1); % Pull out the a coefficient in log
        log10b = b(1,1); % Pull out the b coefficient in log
        a = 10^log10a; % Convert from log10 to exp
        
        % & plot ratig curve data
        larger = normalisedQ(ind2use).*1000;
        maxi = max(larger);
        xvalues = 1:0.5:max(larger);
        xvalues = xvalues./1000;
        i1 = min(normalisedQ(ind2use));
        i2 = dsearchn(xvalues',i1);
        xvalues1 = xvalues(i2:end);
        xvalues = log10(xvalues1);
        curvefit1 = log10b.*xvalues+log10a; % Produce data for regular power fit

        subplot(2,2,graphInd);
        graphInd = graphInd + 1;
        grid on
        scatter(log10x,log10y,'b+'); hold on
        plot(xvalues,curvefit1, 'color', 'r', 'linestyle','-','linewidth',2);
        xlabel('Log_{10} (Normalised Discharge)');
        ylabel('Log_{10} (Suspended Sediment Concentration)');
        titleYear = {'1974-83', '1984-93', '1994-2003', '2004-2013'};
        titleStr = [strcat('Station Number=' , riverId(iter))...
            strcat('Time Period=',titleYear(graphInd-1))];
        hTitle = title (titleStr);
        set(hTitle,'FontWeight', 'normal');
        grid on
        
        % Display the best-fit statistics
        strIn1 = ['$$SSC = ' num2str(log10b) '\hat{Q}+{' num2str(log10a) '}$$'];
        strIn2 = ['$$R^2 = ' num2str(stats(1,1)) '$$'];
        strIn3 = ['$$p = ' OriginalLog_p '$$'];
        nIn = find(~isnan(log10x)&~isnan(log10y));
        strIn4 = ['$$n = ' num2str(length(nIn)) '$$'];
        text(0.020989010989011, 0.818991097922849, {strIn1, strIn2, strIn3, strIn4},...
            'Interpreter','latex', ...
            'FontSize',14, 'Units',...
            'Normalized', 'BackgroundColor', [1 1 1],...
            'LineStyle', '-',...
            'EdgeColor', [0 0 0])
        set (gca, 'TickDir', 'out')
        looper = looper + 2;
    end
        clearvars -except ssc normalisedQ data_text sample_id det result outfilename2 data_text2 iter riverId timestamp
    
end


