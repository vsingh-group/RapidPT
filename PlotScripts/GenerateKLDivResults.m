addpath('functions')
clear;

% Parameters
permutations = [2000,5000,10000,20000,40000]%,80000,160000];
numPerms = size(permutations,2);
N = 400;
dataset = strcat(num2str(N),'_',num2str(N/2),'_',num2str(N/2));
prefix = strcat('../../outputs_parallel/',dataset,'/');

% Get SnPM output data
snpmPath = strcat(prefix,'snpm/outputs_',dataset,'_320000.mat');
load(snpmPath);
MaxTsnpm = snpmOutputs.MaxT(:,1);

% RapidPT parameters
rapidptPathPrefix = strcat(prefix,'rapidpt/outputs_');
subVs = {'0.001','0.0035','0.005','0.007','0.01','0.05'};
numSubVs = size(subVs,2);
trainNums = {num2str(floor(N/2)),num2str(floor(3*N/4)),num2str(N),num2str(2*N)};
numTrainNums = size(trainNums,2);

kldivs_snpm = zeros(numTrainNums,numSubVs,numPerms);


for i=1:numSubVs
    subV = subVs{i};
    for j = 1:numTrainNums
        trainNum = trainNums{j};
        description = strcat('160000_',subV,'_',trainNum);
        load(strcat(rapidptPathPrefix,description,'.mat'));
        MaxTrapidpt = outputs.MaxT;
        for k = 1:numPerms
            perm = permutations(k);
            kldiv_snpm = CompareHistograms(MaxTrapidpt(1:perm),MaxTsnpm(1:perm));
            kldiv_naivept = CompareHistograms(MaxTrapidpt(1:perm),MaxTnaivept(1:perm));
            kldivs_snpm(j,i,k) = kldiv_snpm;
        end
    end
end
KlDivsResults.kldivs_snpm= kldivs_snpm;
KlDivsResults.permutations = permutations;
KlDivsResults.subVs = subVs;
KlDivsResults.trainNums = trainNums;

save(strcat(prefix,'KLDivs_',dataset,'.mat'), 'KlDivsResults');









