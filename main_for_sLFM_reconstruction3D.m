% 3D reconstruciton for sLFM
% The Code is created based on the method described in the following paper 
%        ZHI LU, SIQING ZUO, MINGHUI SHI etc.
%        High-fidelity long-term intravital subcellular imaging with confocal scanning light-field microscopy
%        in submission, 2023.
% 
%    Contact: ZHI LU (luzhi@tsinghua.edu.cn)
%    Date  : 08/01/2023

clear;

addpath('./Solver/');
addpath('./utils/');

% Preparameters
GPUcompute=1;        %% GPU accelerator (on/off)
Nnum=13;             %% the number of sensor pixels after each microlens, equivalent to the number of angles in one dimension
Nshift=3;            %% the sampling points of a single scanning period
DAO = 1;             %% digital adaptive optics (on/off)
Nb=1;                %% number of blocks for multi-site AO in one dimension
maxIter=3;           %% the maximum iteration number of single frame

% Load PSF
load('PSF/sLFM_CalibratedPSF_M63_NA1.4_zmin-10u_zmax10u.mat','psf');
weight=squeeze(sum(sum(sum(psf,1),2),5))./sum(psf(:));
weight=weight-min(weight(:));
weight=weight./max(weight(:)).*0.8;
for u=1:Nnum
    for v=1:Nnum
        if (u-round(Nnum/2))^2+(v-round(Nnum/2))^2>(round(Nnum/3))^2 
            weight(u,v)=0;
        end
    end
end

% Load spatial angular components
WDF=zeros(459,459,Nnum,Nnum,'single'); %% 4D spatial-angular measurements (Wigner Distribution Function)
for u=1:Nnum
    for v=1:Nnum
        WDF(:,:,u,v)=single(imread(['Data/sLFM_WDF.tif'],(u-1)*Nnum+v));
    end
end

% Initialization
WDF=imresize(WDF,[size(WDF,1)*Nnum/Nshift,size(WDF,2)*Nnum/Nshift]);
Xguess=ones(size(WDF,1),size(WDF,2),size(psf,5));
Xguess=Xguess./sum(Xguess(:)).*sum(WDF(:))./(size(WDF,3)*size(WDF,4));

% 3D Reconstruction
Xguess = deconvRL(maxIter, Xguess,WDF, psf, weight, DAO, Nb, GPUcompute);

% Save the reconstructed volume
savepath = ['Data/sLFM_Reconstruction.tif'];
imwriteTFSK(single(gather(Xguess(101:1900,101:1700,31:81))),savepath);  %% crop volume edge and save it
