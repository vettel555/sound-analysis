

% Code:
% a. computes short-time frames (20 msec)
% b. computes source-filter LP decomposition
% c. recosntruct each frame using computed and white noise excitation
% d. does overlap-add synthesis  
% d. outputs: xola (original signal), rsig (reconstructed), wsig (whispered) 
% Last edit 5 June 2019, by Neeraj Sharma (CMU)

clc; clear all; close all;
addpath('utilities')

global params
data_path = '../sound/';

fnames = dir([data_path '*.wav']);
for i = 1:1%length(fnames)
    % ----- read the file
    [x,Fs] = audioread([data_path fnames(i).name]); % Open file for reading
    len = length(x);
    dur = len*1/Fs;
    t = 0:1/Fs:dur-1/Fs;
    Ts = 1/Fs;
    % ----- shifting OLA window analysis 
    wtype = 'hanning';
    wmsec = 20e-3;
    hop_frac = 2;
    wlen = fix(wmsec*Fs)+1;
    switch(wtype)
        case 'hanning'
            win = hanning(wlen);
            % ----- induce symmetry
            if mod(wlen,2) % odd
                win = win-min(win);
                win(1) = win(1)/2;
                win(end) = win(end)/2;
            else
                win = hanning(wlen+1);
                win = win(1:wlen);
                win = win-min(win);
            end
        case 'hamming'
            win = hamming(wlen);
            % ----- induce symmetry
            if mod(wlen,2) % odd
                win = win-min(win);
                win(1) = win(1)/2;
                win(end) = win(end)/2;
            else
                win = hamming(wlen+1);
                win = win(1:wlen);
                win = win-min(win);
            end
        case 'rect'
            win = ones(wlen,1);
            % ----- null last sample
            win(end) = 0;
    end
    win = sqrt(win);
    
    % ----- hop and overlap
    hop  = fix((wlen-1)/hop_frac);
    ovlp = wlen-hop;

    tpad = [(t(1)-(wlen:-1:1)*Ts) t (t(end)+(1:wlen)*Ts)]; % pad to
    T = buffer(tpad,wlen,ovlp);
    % first p samples are zero by default
    nframes = size(T,2);
    hwin = win; % column vector

    Hw = repmat(hwin,1,nframes);
    xpad = [zeros(1,wlen) x' zeros(1,wlen)]; % pad to
    X = buffer(xpad,wlen,ovlp);
    X = X.*Hw;

    wpad = [zeros(1,wlen) ones(len,1)' zeros(1,wlen)]; % pad to
    W = buffer(wpad,wlen,ovlp);
    W = W.*Hw.*Hw;

    nframes = size(X,2);
    % ----- set the LP computation params

    if Fs == 16e3
        params.pAR = 12;
    end
    params.Fs = Fs;
    params.hop_frac = hop_frac;
    params.wmsec = wmsec;
    params.wlen = wlen;                    % 20msec window    
    params.hop = hop;     % 10msec shift
    params.wtype = wtype;
    params.nframes = nframes;
        
    Y = zeros(size(X));
    Wh = zeros(size(X));
    for frmindx = 1:params.nframes
        % ----- keep frame
        s = X(:,frmindx);
        % ----- process if energy more than threshold
        if norm(s)>5e-3 
            % ----- estimate LPC
            Ak = estimateLPCoeff(s);
            h = InvFilImpResp(Ak,params.wlen,params.pAR); 
            %Ht=gallery('circul',[1 ; ht(end:-1:2)]);
            %Ht= Ht(1:params.windsiz,:);     
            H = convmtx(flipud(h)',params.wlen);
            H = H(:,length(h):end);

            % ----- get the residual
            Ak = Ak(:);
            temp = zeros(params.wlen,params.pAR);
            for j = 1:params.wlen
                for k = 1:params.pAR
                    if(j-k <= 0)
                        temp(j,k) = 0;
                    else
                        temp(j,k) = s(j-k);
                    end
                end
            end
            res = (s+temp*Ak(2:end));   
            Y(:,frmindx) = H*res;
            nz = randn(size(res));
            nz = nz/norm(nz)*norm(res);
            Wh(:,frmindx) = H*nz;
        end
    end
    
    % ----- ola the frames
    % create the window normalization signal
    wola = do_ola_frames(W,len,wlen,ovlp,hop);
    % ola the original signal frames
    xola = do_ola_frames(X.*Hw,len,wlen,ovlp,hop)./wola;
    % ola the reconstructed signal frames
    rsig = do_ola_frames(Y.*Hw,len,wlen,ovlp,hop)./wola;
    % ola the whishpered signal frames
    wsig = do_ola_frames(Wh.*Hw,len,wlen,ovlp,hop)./wola;

    % ----- write wave files
    store_path = ['./data/samples/recons/'];

    if ~isdir(store_path)
        mkdir(store_path);
    end
    
    audiowrite([store_path 'orig_' fnames(i).name],xola./max(abs(xola)),Fs);
    audiowrite([store_path 'rsig_' fnames(i).name],rsig./max(abs(rsig)),Fs);
    audiowrite([store_path 'wsig_' fnames(i).name],wsig./max(abs(wsig)),Fs);
end
    
    
    

