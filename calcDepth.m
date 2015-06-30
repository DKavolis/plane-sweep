function depthmap = calcDepth(depths, K, Rrel, trel, nreference, nsensor, Winsize)

n = gpuArray([0 0 1]');

depthmap = gpuArray(ones(size(nreference)));
depthmap = bsxfun(@times, depthmap, depths(1));
bestncc = gpuArray(zeros(size(nreference)));
bestncc = bsxfun(@minus, bestncc, 3);

% image x and y pixel coordinates
X1 = gpuArray(repmat([1:640],480,1));
Y1 = gpuArray(repmat([1:480]',1,640));

% summation kernel
g = gpuArray(ones(Winsize,1) ./ Winsize);

ns = gpuArray(nsensor);
nr = gpuArray(nreference);
   
for d = depths
    H = K * (Rrel + trel * n' ./ d) \ K; % homography
    
    % calculate new pixel positions in sensor image
    x2 = bsxfun(@plus, bsxfun(@plus, bsxfun(@times, H(1,1), X1), bsxfun(@times, H(1,2), Y1)), H(1,3));
    y2 = bsxfun(@plus, bsxfun(@plus, bsxfun(@times, H(2,2), Y1), bsxfun(@times, H(2,1), X1)), H(2,3));
%     w = bsxfun(@plus, bsxfun(@plus, bsxfun(@times, H(3,1), X1), bsxfun(@times, H(3,2), Y1)), H(3,3));
%     x2 = bsxfun(@rdivide, x2, w);
%     y2 = bsxfun(@rdivide, y2, w);

    % interpolate pixel values in transformed image
    warped = interp2(ns, x2, y2, 'linear', 0);
    
    % normalize
    warped = (warped - mean2(warped)) ./ std2(warped);
    
    % multiply reference and transformed images element-wise and sum
    % elements over a specified window (2 1D convolutions)
    ccr = bsxfun(@times, nr, warped);
    ncc = colfilter(colfilter(ccr,g).',g).';
    
    % find better NCC values and update depthmap and best NCC
    greater = bsxfun(@gt, ncc, bestncc);
    less = bsxfun(@minus, 1, greater);
    depthmap = bsxfun(@plus, bsxfun(@times, greater, d), bsxfun(@times, depthmap, less));
    bestncc = bsxfun(@plus, bsxfun(@times, greater, ncc), bsxfun(@times, less, bestncc));
end