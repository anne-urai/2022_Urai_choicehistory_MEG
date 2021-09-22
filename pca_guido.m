function [datac, P, A] = pca_guido(dat, fsample)
%
% cross-spectrum at 50 Hz
% this is a complex matrix, so takes first PCA component (eigenvector).
% This is a real and imaginary part. 
% Two dimensional space, with real and imaginary dimensions. In a normal PCA, 
% you'd use the covariance and not the cross spectrum.
% So then, there would be no complex numbers. 
%
% keep the P (projection matrix), then once we generate leadfield matrix
% apply P there as well. 
%
% singular value decomposition on the cross-spectrum at 50 Hz. The singular
% vectors are complex, and take the one with the largest signular value (first
% one). THe imaginary part of this vector because the 50Hz may contain one
% topography as well as a phase delayed second topography. Both the real
% and imaginary parts span a two-dimensional space, this is projected out
% from the data. This projection takes out the artefact as good as we
% think, but it might also affect topographies of real signals. THe forward
% calc (leadfield matrix) is affected so this two-dimensional space is also
% projected out there. 
%
% check the topographies of some clean data with and without PCA!
%
% Guido Nolte, UKE
% Adapted by Anne Urai, UKE, 29 June 2015

f = 50; % we look at 50 Hz

% ==================================================================
% APPLY GUIDOS PCA
% ==================================================================

disp('preparing out MEG data');
dat             = detrend(dat,'constant'); % only demean
fs              = fsample; % sampling rate
segleng         = fs; % 1 Hz frequency resolution
[n, nchan]      = size(dat);
epleng          = n; % entire data is one epoch
segshift        = segleng/2; % segments have 50% overlap;

disp('computing cross spectral density matrix at 50 Hz');
cs = data2cs_wavelet(dat, segleng, segshift, epleng, f, fs);

disp('singular value decomposition');
[u,~,~]         = svd(cs); % u, s, v
A               = [real(u(:,1)), imag(u(:,1))];

disp('projecting 1st component out of the data');
P               = eye(nchan)-A*inv(A'*A)*A'; % projection matrix
datac           = dat*P; % apply

end

function [cs, coh, ssout]=data2cs_wavelet(data,segleng,segshift,epleng,f,fsample)
% calculates cross-spectrum and coherence based on a wavelet using
% a Hanning window for given frequeny
%
% usage:
% [cs coh]= data2cs_wavelet (data,segleng,segshift,epleng,f,fsample);
% input:
% data:   NxM matrix for N time points and M channels
% segleng:  length of segment (in samples)
% segshift:  shift of segments (in samples)
% epleng: length of epoch (or trial) (in samples)
% f:   frequency of interest (in Hz)
% fsample: sampling frequeny (in Hz)
%
% outpot:
% cs: cross-spectrum
% coh: coherency (complex)
% ss: the complex wavelet

nn=(1:segleng)'-segleng/2;
mywin=hanning(segleng);
s1=cos(nn*f*2*pi/fsample).*mywin;
s2=sin(nn*f*2*pi/fsample).*mywin;
ss=s1-sqrt(-1)*s2;
ssout=ss;

[n, nchan]=size(data);
ss=repmat(ss,1,nchan);

nep=floor(n/epleng);
nseg=(epleng-segleng)/segshift+1;

cs=zeros(nchan,nchan);
coh=cs;

kk=0;
for i=1:nep;
    dloc=data((i-1)*epleng+1:i*epleng,:);
    for j=1:nseg
        kk=kk+1;
        dloc2=dloc((j-1)*segshift+1:(j-1)*segshift+segleng,:);
        dataf=transpose(sum(dloc2.*ss));
        if kk==1;
            cs=dataf*dataf';
        else
            cs=cs+dataf*dataf';
        end
    end
end

cs=cs/kk;
coh=cs./sqrt(diag(cs)*diag(cs)');

end