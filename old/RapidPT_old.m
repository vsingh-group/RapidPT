%% Efficient permutation testing using Matrix completion
% % the following function computes the max Null statistic distribution 
% % in its current format, the code only uses t-statistics

%%% Corresponding paper :
% % Speeding up Permutation Testing in Neuroimaging 
% % C Hinrichs, VK Ithapu, Q Sun, SC Johnson, V Singh
% % NIPS 2013

%%% Arguments    
% % 
% %     %%% INPUTS
% %     A structure filed with following arguments
% %     inputs.datapath    :       path to mat file containing the data matrix 
% %                                (REQUIRED) Two fields : data and labeling
% %                                data - a matrix of size N X V
% %                                labels - a vector of length N (2 groups)
% %                                CONTENTS SHOULD BE NAMED "data" and "labels"                                
% %                                (N : number of instances , V : data dimension) 
% %     inputs.sub         :       sub-sampling rate (0 to 1) (DEFAULT = 0.05)
% %     inputs.T           :       number of permutations (DEFAULT = 10^4)
% %     inputs.maxrank     :       rank for estimating the low rank subspace (DEFAULT = N)
% %     inputs.traintime   :       number of permutations for training (DEFAULT = 100)
% %     inputs.maxCycles   :       number of cycles for training (DEFAULT = 3)
% %     inputs.iter        :       number of iterations for matrix completion (DEFAULT = 30)  
% %     inputs.writing     :       if 0 - outputs only maxnull (SEE BELOW) 
% %                                if 1 - outputs maxnull, U and W (DEFAULT = 0)
% %     inputs.save        :       path to save the outputs (DEFAULT : working folder)  
% % 
% %     %%% OUTPUTS
% %     outputs.maxnull     :       estimated distribution of max Null statistic
% %     outputs.U           :       orthogonal matrix spanning low rank subspace
% %                                 (dimension : V X maxrank) 
% %                                 optional output (DEFAULT : No)

%%% Support codes for matrix completion
% % GRASTA : https://sites.google.com/site/hejunzz/grasta
% % Codes already included in the package

%%% Usage 
% %     inputs.data = '/home/user/mydata/pt_data.mat';
% %     inputs.maxrank = 30; input.T = 1000; input.traintime = 50; 
% %     inputs.display = 1;
% %     outputs = Efficient_PT(inputs);

function [ outputs, timings ] = RapidPT( inputs, rapidPTLibraryPath )
% RapidPermutationTesting 
%   Modified permutation testing algorithm described in the following paper
%   Speeding up Permutation Testing in Neuroimaging  C Hinrichs, VK Ithapu, Q Sun, SC Johnson, V Singh, NIPS 2013
    
    fprintf('Starting RapidPermutationTesting...\n');
    tTotal = tic;
    fprintf('Adding Paths...\n');
    AddPaths(rapidPTLibraryPath);
    fprintf('\nStarting Preprocessing...\n');
    fprintf('Validate Required Inputs...\n');
    ValidateInputs(inputs);
    data = inputs.data;
    dataSquared = data.*data;
    %labels = inputs.labels;
    nGroup1 = inputs.nGroup1;
    

    
    fprintf('Processing Input Parameters...\n');
    N = size(data,1); % N: number of instances/subjects (rows in data matrix)
    V = size(data,2); % V: Number of statistics/voxel measurements (cols) 
%     uniqueLabels = unique(labels); % Unihttps://github.com/felipegb94/RapidPermTest.gitque labels
%     nGroup1 = length(find(labels==uniqueLabels(1))); % Number of patients in group 1
    nGroup2 = N - nGroup1;
    [sub, numPermutations, maxRank, trainNum, maxCycles, iter, write] = ProcessInput(inputs, N);

    fprintf('Initializing matrix completion parameters (GRASTA parameters) \n');
    [ options, opts, opts2, status ] = InitGrastaParams(maxRank, iter, V);
    
    fprintf('Initializing permutation matrices... \n');
    % indexMatrix is what indexMatrix used to be..
    [indexMatrix, permutationMatrix1, permutationMatrix2] = TwoSampleGetPermutationMatrices(numPermutations, N, nGroup1);
   
    binRes = 0.05; 
    maxnullBins = -9:binRes:9; %% bin resolution in maxnull histogram computation
    subV = round(sub*V); %% number of samples used per permutation
    subBatch = trainNum; %% number of permutations handled at once -- for commputational ease
    batches = ceil(numPermutations/subBatch); %% number of such batches
    maxTStatistics = zeros(1, numPermutations); %% estimated max statistics for all permutations

%% Training for low rank subsapace and residual priors

    fprintf('\nStarting Algorithm...\n');
    fprintf('Training for low rank subspace and residual priors \n');
    tTraining = tic;

    permutationMatrix1Current = permutationMatrix1(1:1:trainNum,:);
    permutationMatrix2Current = permutationMatrix2(1:1:trainNum,:);
    % Calculate some full permutations for training U (A good number would be the number of labels).
    [dummyMaxT, TCurrent] = TwoSamplePermTest(data, dataSquared, permutationMatrix1Current, permutationMatrix2Current, nGroup1, nGroup2 );
    
    framesOrder = zeros(trainNum, maxCycles);
    for m = 1:1:maxCycles
        framesOrder(:,m) = randperm(trainNum);
    end
    
    % Estimate U using subsample matrix completion methods
    UHat = orth(randn(V,options.RANK)); 
    
    for m = 1:1:maxCycles
        for f = 1:1:trainNum
            inds = randperm(V,subV); 
            I_inds = TCurrent(framesOrder(f,m),inds)';
            [UHat, status, opts] = grasta_stream(I_inds, inds, UHat, status, options, opts);
            fprintf('Subspace estimation on %s cycle with %s frame \n',num2str(m),num2str(f));
        end
    end 
    
    diffForNormal = zeros(trainNum,maxCycles);
    for m = 1:1:maxCycles
        Ts_ac = zeros(V,trainNum); 
        Ts_tr = zeros(V,trainNum);
        for f = 1:1:trainNum
            Ts_ac(:,f) = TCurrent(framesOrder(f,m),:)';
            inds = randperm(V,subV); 

            I_inds = Ts_ac(inds,f);
            % Time srp function
            [s, w, jnk] = admm_srp(UHat(inds,:), I_inds, opts2); 
            sall = zeros(V,1); 
            sall(inds) = s; 
            Ts_tr(:,f) = (UHat*w + sall)';
            fprintf('Training done on %s cycle with %s frame \n',num2str(m),num2str(f));
        end
        max_Ts_ac = max(Ts_ac,[],1); 
        max_Ts_tr = max(Ts_tr,[],1);
        diffForNormal(:,m) = max_Ts_ac - max_Ts_tr;
    end

    [muFit,varFit] = normfit(diffForNormal(:));

    tTraining = toc(tTraining);
    timings.tTraining = tTraining;

%% Recovery : Filling in W and residuals for all numPermutations
    fprintf('\n Recovering the subspace coefficients and residuals for all permutations \n');
    tRecovery = tic;    
    
    W = cell(numPermutations,1); 
    % Calculate small portion of the permutation matrix
    parfor i = 1:numPermutations
        inds = randperm(V,subV)'; 
        [dummyMaxT, TCurrent] = TwoSamplePermTest(data(:,inds),...
                                                  dataSquared(:,inds),...
                                                  permutationMatrix1(i,:),...
                                                  permutationMatrix2(i,:),...
                                                  nGroup1,...
                                                  nGroup2);
        U_inds = UHat(inds,:);  
        [s, w, jnk] = admm_srp(U_inds, TCurrent', opts2);
        W{i,1} = w; 
        sAll = zeros(V,1); 
        sAll(inds) = sAll(inds) + s; 
        TRec = UHat*w + sAll + muFit;
        maxTStatistics(1,i) = max(TRec);
        fprintf('Completion done on trial %d/%d (block %d) \n',i,numPermutations,ceil(i/subBatch));  
    end

    % Save timings
    timings.tRecovery = toc(tRecovery);
    
    outputs.MaxNull = gen_hist(maxTStatistics,maxnullBins); 
    outputs.MaxT = maxTStatistics;

    if write == 1 
        outputs.U = UHat; 
        outputs.W = W; 
    end
    
    fprintf('TwoSampleRapidPT Done...');
    timings.tTotal = toc(tTotal);

end

function [ MaxT, tStatMatrix ] = TwoSamplePermTest(data, dataSquared, permutationMatrix1, permutationMatrix2, nGroup1, nGroup2)
    
    numPermutations = size(permutationMatrix1, 1);
    MaxT = zeros(numPermutations,1);
    
    g1Mean = (permutationMatrix1 * data)/nGroup1;
    g2Mean = (permutationMatrix2 * data)/nGroup2;
    g1Var = (permutationMatrix1 * dataSquared)/(nGroup1) - (g1Mean.*g1Mean);
    g2Var = (permutationMatrix2 * dataSquared)/(nGroup2) - (g2Mean.*g2Mean);
    tStatMatrix = (g1Mean - g2Mean) ./ (sqrt((g1Var./(nGroup1-1)) + (g2Var./(nGroup2-1))));
    MaxT(:,1) = max(tStatMatrix,[],2);        

end

