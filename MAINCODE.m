p1=genpath('FxNLMS files');addpath(p1);
Sde=load('DE_System.mat');Sae=load('AE_System.mat');
load('speech.mat');
load('whiteno.mat','exwhite');load('pinkno.mat','expink');load('brownno.mat','exbrown');load('cityno.mat','excity');
%%
d2e=sysBlock(Sde.Am,Sde.Bm); % Create parallel 2nd order IIR sections for modelling the physical AE and DE paths.
a2e=sysBlock(Sae.Am,Sae.Bm);

answ=inputparametersGUI(); % GUI for selecting the simulation parameters (adapation step, filter length, type of noise to be used).

if strcmp(answ.noiseType,'white')
    exnoise=0.14835*exwhite;
elseif strcmp(answ.noiseType,'pink')
    exnoise=2.5585*expink;
elseif strcmp(answ.noiseType,'brown')
    exnoise=8.92*exbrown;
else 
    exnoise=excity;
end


control=fxNLMS(answ.adaptationStep,answ.filterLength);% Initializing NLMS controller with the chosen parameters.
L=length(exnoise);
Fs=44100;

for ii=1:44100
    c=control.generatenoise; % Off-line Secondary Path (DE) modelling. The proccess utilizes the same NLMS controller used for the ANC 
    e=d2e.calculateBlk(c);   % to adjust the coefficients of a 1024-tap FIR filter(DEbar) that models the actual DE path. This is achieved
    control.updateDEbar(e);  % by minimizing the error between a random noise signal generated by the controller arriving at the error mic 
end                          % through the secondary path and the same signal proccessed by the filter to be adjusted.                           

d2e.reset;

y=zeros(1,L);
d=y;
ybar=y;
e=y;

d(1)=a2e.calculateBlk(exnoise(1));     % primary noise arriving at ear.
exbar=control.debarfilt(exnoise(1));   % primary noise filtered by the DE approximation filter.
y(1)=control.Wfilt(exnoise(1));        % control signal sample y(n) produced by the adaptive filter W.
ybar(1)=d2e.calculateBlk(-y(1));       % control signal arriving at the ear.
e(1)=d(1)+ybar(1);                     % residual noise captured by the error microphone.
control.updateW(0,exbar);              % adapting the filter weights by the NLMS algorithm.
for ii=2:L
    d(ii)=a2e.calculateBlk(exnoise(ii));
    y(ii)=control.Wfilt(exnoise(ii));
    exbar=control.debarfilt(exnoise(ii));
    ybar(ii)=d2e.calculateBlk(-y(ii));
    e(ii)=d(ii)+ybar(ii);
    control.updateW(e(ii-1),exbar);
end

d2e.reset;

% Calculate power spectrum of noise signals.
[dbEX,F]=psdb(exnoise,Fs); % power spectrum in dB scale of the external noise signal exnoise arriving at the reference microphone.
[dbD,~]=psdb(d,Fs); % power spectrum in dB scale of the primary noise signal d at the error microphone.
[dbE,~]=psdb(e,Fs); % power spectrum in dB scale of the residual noise signal e at the error microphone.

% Calculate Cummulative Mean Average.
cma=CMA();
mse=zeros(1,L);
for ii=1:L
    mse(ii)=cma.calculate(e(ii)^2);
end
msedb=pow2db(mse);

simulationCompletedGUI(F,dbEX,dbD,dbE,procspeech,e,d,answ,msedb);



