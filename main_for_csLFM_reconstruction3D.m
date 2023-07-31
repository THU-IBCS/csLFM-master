% 3D reconstruciton for csLFM
% The Code is created based on the method described in the following paper 
%        ZHI LU, SIQING ZUO, MINGHUI SHI etc.
%        Confocal scanning light-field microscopy
%        in submission, 2023.
% 
%    Contact: ZHI LU (luzhi@tsinghua.edu.cn)
%    Date  : 08/01/2023

clear;

addpath('./Solver/');
addpath('./utils/');

% Preparameters
GPUcompute=1;        %% GPU accelerator (on/off)
Nnum=13;             %% the number of sensor pixels after each microlens/ the number of angles in one dimension
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

% Convert sLFM PSF into csLFM PSF according to the optical parameters
slit_width=50;       %% Number of pixels at the object plane corresponding to the width of the illumination slit
row_height=50;       %% Number of pixels at the image plane corresponding to the row height of rolling shutter
illumination_slit=zeros(size(psf,1),size(psf,2),'single');
illumination_slit(round(size(illumination_slit,1)/2-slit_width/2):round(size(illumination_slit,1)/2+slit_width/2),:)=1;
rolling_window=zeros(size(psf,1),size(psf,2),'single');
rolling_window(round(size(rolling_window,1)/2-row_height/2):round(size(rolling_window,1)/2+row_height/2),:)=1;
modulation_function=zeros(size(psf,1),size(psf,2),'single');
for j=1:size(modulation_function,2)
    modulation_function(:,j)=conv(illumination_slit(:,j),rolling_window(:,j),'same');
end
modulation_function=modulation_function./max(modulation_function(:)); %% g_p in equation (6)
for u=1:size(psf,3)
    for v=1:size(psf,4)
        for z=1:size(psf,5)
            psf(:,:,u,v,z)=psf(:,:,u,v,z).*modulation_function;
        end
    end
end

% Load spatial angular components
WDF=zeros(459,459,Nnum,Nnum,'single'); %% 4D spatial-angular measurements (Wigner Distribution Function)
for u=1:Nnum
    for v=1:Nnum
        WDF(:,:,u,v)=single(imread(['Data/csLFM_WDF.tif'],(u-1)*Nnum+v));
    end
end

% Initialization
WDF=imresize(WDF,[size(WDF,1)*Nnum/Nshift,size(WDF,2)*Nnum/Nshift]);
Xguess=ones(size(WDF,1),size(WDF,2),size(psf,5));
Xguess=Xguess./sum(Xguess(:)).*sum(WDF(:))./(size(WDF,3)*size(WDF,4));

% 3D Reconstruction
Xguess = deconvRL(maxIter, Xguess,WDF, psf, weight, DAO, Nb, GPUcompute);

% Save the reconstructed volume
savepath = ['Data/csLFM_Reconstruction.tif'];
imwriteTFSK(single(gather(Xguess(101:1900,101:1700,31:81))),savepath);  %% crop volume edge and save it
